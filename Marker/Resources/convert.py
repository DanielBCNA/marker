#!/usr/bin/env python3
"""Convierte un PDF a Markdown usando Google Gemini.

Uso: convert.py <input.pdf> <output.md>

Requiere:
    pip3 install google-genai

La API key se lee del entorno (GEMINI_API_KEY).

Este módulo es importado tanto por la app (vía Process en
ScriptManager.swift) como por scripts/marker-cli, que reutiliza la
función convert() para la Quick Action de Finder.
"""
import os
import re
import socket
import ssl
import sys
import time

from google import genai
from google.genai import types

API_KEY = os.environ.get("GEMINI_API_KEY")

# Fallback chain ordered by RPD (Requests Per Day) descending — el primero
# es el que más cuota diaria tiene, así que lo gastamos primero. Si tus
# cuotas cambian (ai.google.dev → API → Quotas) reordena esta lista.
#
# Revisada 2026-10-23 contra client.models.list() de la cuenta real y con
# un PDF de prueba convertido por cada modelo (todos correctos). Retiradas
# anunciadas: gemini-3.1-flash-lite el 2027-05-07 (sustituto:
# gemini-3.5-flash-lite); gemini-3-flash-preview sin fecha, Google recomienda
# gemini-3.6-flash. gemini-3.8-flash existe pero tardó 37 s frente a 5-11 s
# del resto, así que no entra. Cuotas de 3.5-flash-lite, 3.6-flash y
# 3.5-flash sin confirmar: el orden asume que un flash-lite da más cuota
# diaria que un flash. Un modelo que falle por cualquier motivo se salta,
# así que un escalón muerto no rompe la conversión.
MODELS = [
    "gemini-3.1-flash-lite",          # 500 RPD (confirmado), se retira 2027-05-07
    "gemini-3.5-flash-lite",          # RPD sin confirmar, ~5 s
    "gemini-3.6-flash",               # RPD sin confirmar, ~10 s
    "gemini-3.5-flash",               # RPD sin confirmar, ~11 s
    "gemini-3-flash-preview",         # 20 RPD, último recurso
]
MAX_RETRIES = 3
RETRY_DELAYS = [8, 20, 45]

# Gemini puede tardar segundos en pasar el upload de PROCESSING a ACTIVE.
# Si excede este tope asumimos que se atascó y abortamos en vez de
# esperar indefinidamente.
MAX_UPLOAD_WAIT_SECONDS = 120

# Generación determinística (temperature=0). response_mime_type debe ser
# uno de los que acepta Gemini (text/plain, application/json, application/
# xml, application/yaml, text/x.enum). Markdown es text/plain: usábamos
# "text/markdown" pero la API empezó a rechazarlo con 400 INVALID_ARGUMENT
# (2026-05). strip_fences() limpia la valla ```markdown si el modelo la
# añade. max_output_tokens generoso para earnings calls largas (~50 págs).
GENERATION_CONFIG = types.GenerateContentConfig(
    response_mime_type="text/plain",
    temperature=0.0,
    max_output_tokens=32768,
)

PROMPT = """Convert this PDF (an earnings call transcript) to clean, well-structured Markdown.

Rules:
- Output must be in the same language as the input document. Do not translate.
- Preserve all speaker names as bold headers: **SPEAKER NAME:**
- Remove page numbers, headers, footers, and legal disclaimers at the top/bottom of pages
- Remove repetitive copyright/confidentiality notices between pages
- Use proper Markdown: ## for main sections, ### for subsections
- Render tables of financial data as Markdown tables
- Keep financial figures, dates, and proper nouns exactly as written
- Output only the Markdown content, no preamble or explanation"""

NETWORK_ERROR_MARKERS = (
    "_ssl.c",
    "ssl: ",
    "eof occurred",
    "connection reset",
    "connection aborted",
    "connection refused",
    "connection closed",
    "broken pipe",
    "timed out",
    "timeout",
    "remote disconnected",
    "server disconnected",
    "remote end closed",
    "incomplete read",
    "cannot connect",
    "name or service not known",
    "temporary failure in name resolution",
    "max retries exceeded",
    "remoteprotocolerror",
    "protocolerror",
    "transporterror",
)

try:
    import httpx as _httpx
    _HTTPX_TRANSPORT_ERROR = _httpx.TransportError
except Exception:
    _HTTPX_TRANSPORT_ERROR = ()


def is_transient_network_error(exc):
    if isinstance(exc, (socket.timeout, ssl.SSLError, ConnectionError, TimeoutError)):
        return True
    if _HTTPX_TRANSPORT_ERROR and isinstance(exc, _HTTPX_TRANSPORT_ERROR):
        return True
    err = str(exc).lower()
    return any(marker in err for marker in NETWORK_ERROR_MARKERS)


def with_network_retry(fn, label):
    """Ejecuta fn() con reintentos exponenciales para errores de red transitorios."""
    for attempt in range(MAX_RETRIES):
        try:
            return fn()
        except Exception as e:
            if is_transient_network_error(e) and attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAYS[attempt])
                continue
            raise


def classify_quota_error(err_text):
    """Distingue cuotas diarias (RPD, irrecuperables hoy) de las por minuto
    (TPM/RPM, que sí se reinician). Si el mensaje no es claro, se trata
    como TPM y se reintenta — es el caso conservador."""
    s = err_text.lower()
    if "per day" in s or "rpd" in s or "daily limit" in s or "perdayperproject" in s:
        return "rpd"
    return "tpm"


def strip_fences(text):
    s = text.strip()
    s = re.sub(r"^```[a-zA-Z]*\n?", "", s, count=1)
    s = re.sub(r"\n?```\s*$", "", s, count=1)
    return s


def try_generate(client, model, contents):
    for attempt in range(MAX_RETRIES):
        try:
            resp = client.models.generate_content(
                model=model,
                contents=contents,
                config=GENERATION_CONFIG,
            )
            if resp.text is None:
                if attempt < MAX_RETRIES - 1:
                    time.sleep(RETRY_DELAYS[attempt])
                    continue
                return None, "Respuesta vacia de Gemini"
            return resp.text, None
        except Exception as e:
            err = str(e)
            err_lower = err.lower()
            is_quota = "429" in err or "RESOURCE_EXHAUSTED" in err
            if is_quota:
                # RPD se reinicia a medianoche: no sirve reintentar, mejor
                # saltar al siguiente modelo de la cadena ahora mismo.
                # TPM se reinicia cada minuto: backoff sí ayuda.
                if classify_quota_error(err) == "rpd":
                    return None, "quota"
                if attempt < MAX_RETRIES - 1:
                    time.sleep(RETRY_DELAYS[attempt])
                    continue
                return None, "quota"
            if "503" in err or "UNAVAILABLE" in err or "overloaded" in err_lower:
                if attempt < MAX_RETRIES - 1:
                    time.sleep(RETRY_DELAYS[attempt])
                    continue
                return None, f"Modelo no disponible tras {MAX_RETRIES} intentos: {err[:80]}"
            if is_transient_network_error(e) and attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAYS[attempt])
                continue
            return None, str(e)
    return None, "Sin reintentos disponibles"


def convert(pdf_path, out_path):
    if not API_KEY:
        raise RuntimeError("Falta GEMINI_API_KEY en el entorno")

    client = genai.Client(api_key=API_KEY)
    uploaded = with_network_retry(
        lambda: client.files.upload(file=pdf_path),
        "upload",
    )

    upload_started = time.monotonic()
    while uploaded.state.name == "PROCESSING":
        if time.monotonic() - upload_started > MAX_UPLOAD_WAIT_SECONDS:
            try:
                client.files.delete(name=uploaded.name)
            except Exception:
                pass
            raise RuntimeError(
                f"Timeout esperando a Gemini ({MAX_UPLOAD_WAIT_SECONDS}s). "
                "El PDF se quedo en PROCESSING; reintenta mas tarde."
            )
        time.sleep(1)
        uploaded = with_network_retry(
            lambda: client.files.get(name=uploaded.name),
            "poll",
        )

    if uploaded.state.name != "ACTIVE":
        raise RuntimeError(f"Fallo al procesar en Gemini: {uploaded.state}")

    contents = [uploaded, PROMPT]
    failures = []
    for model in MODELS:
        text, error = try_generate(client, model, contents)
        if text is not None:
            try:
                client.files.delete(name=uploaded.name)
            except Exception:
                pass
            with open(out_path, "w", encoding="utf-8") as f:
                f.write(strip_fences(text))
            return
        reason = "cuota agotada" if error == "quota" else (error or "error desconocido")
        failures.append(f"{model}: {reason[:120]}")

    try:
        client.files.delete(name=uploaded.name)
    except Exception:
        pass

    # Un fallo por modelo, para saber si es cuota, un modelo retirado o la
    # red sin tener que reproducirlo.
    raise RuntimeError("Todos los modelos fallaron:\n" + "\n".join(failures))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: convert.py <input.pdf> <output.md>", file=sys.stderr)
        sys.exit(1)
    try:
        convert(sys.argv[1], sys.argv[2])
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
