#!/usr/bin/env python3
"""Convierte un PDF a Markdown usando Google Gemini.

Uso: convert.py <input.pdf> <output.md>

Requiere:
    pip3 install google-genai

La API key se lee del entorno (GEMINI_API_KEY).
"""
import os
import re
import socket
import ssl
import sys
import time

from google import genai

API_KEY = os.environ.get("GEMINI_API_KEY")

# Fallback chain ordered by RPD (Requests Per Day) descending — el primero
# es el que más cuota diaria tiene, así que lo gastamos primero. Si tus
# cuotas cambian (ai.google.dev → API → Quotas) reordena esta lista.
MODELS = [
    "gemini-3.1-flash-lite-preview",  # 500 RPD
    "gemini-2.5-flash-lite",          # 20 RPD
    "gemini-2.5-flash",               # 20 RPD
    "gemini-3-flash-preview",         # cuota desconocida, último recurso
]
MAX_RETRIES = 3
RETRY_DELAYS = [8, 20, 45]

PROMPT = """Convert this PDF (an earnings call transcript) to clean, well-structured Markdown.

Rules:
- Preserve all speaker names as bold headers: **SPEAKER NAME:**
- Remove page numbers, headers, footers, and legal disclaimers at the top/bottom of pages
- Remove repetitive copyright/confidentiality notices between pages
- Use proper Markdown: ## for main sections, ### for subsections
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


def strip_fences(text):
    s = text.strip()
    s = re.sub(r"^```[a-zA-Z]*\n?", "", s, count=1)
    s = re.sub(r"\n?```\s*$", "", s, count=1)
    return s


def try_generate(client, model, contents):
    for attempt in range(MAX_RETRIES):
        try:
            resp = client.models.generate_content(model=model, contents=contents)
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
            # TPM (tokens-por-minuto) se reinicia cada minuto; reintentar con
            # backoff ayuda. RPD (requests-por-día) no se reinicia hasta
            # mañana; no sirve reintentar pero el coste es bajo (73s) y luego
            # caemos al siguiente modelo igual.
            if is_quota:
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

    while uploaded.state.name == "PROCESSING":
        time.sleep(1)
        uploaded = with_network_retry(
            lambda: client.files.get(name=uploaded.name),
            "poll",
        )

    if uploaded.state.name != "ACTIVE":
        raise RuntimeError(f"Fallo al procesar en Gemini: {uploaded.state}")

    contents = [uploaded, PROMPT]
    last_error = None
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
        if error == "quota":
            last_error = f"Cuota agotada en {model}"
            continue
        last_error = error
        continue

    try:
        client.files.delete(name=uploaded.name)
    except Exception:
        pass

    raise RuntimeError(last_error or "Todos los modelos fallaron")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: convert.py <input.pdf> <output.md>", file=sys.stderr)
        sys.exit(1)
    try:
        convert(sys.argv[1], sys.argv[2])
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
