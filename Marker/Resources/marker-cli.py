#!/usr/bin/env python3
"""Marker CLI — convierte uno o varios PDFs a Markdown desde la línea
de comandos. Pensado para usarse como Quick Action de Finder.

Uso: marker-cli <pdf> [<pdf>...]

- Lee la API key de Gemini del archivo que guarda la app
  (~/Library/Application Support/Marker/api_key), o de la variable de
  entorno GEMINI_API_KEY.
- Para cada PDF, crea una subcarpeta MD/ junto al PDF y escribe el
  archivo .md ahí.
- Muestra una notificación del sistema con el resumen al terminar.
"""
import os
import subprocess
import sys


def get_api_key():
    # 1. Variable de entorno (la app la inyecta; en Finder no suele estar).
    env = os.environ.get("GEMINI_API_KEY")
    if env and env.strip():
        return env.strip()

    # 2. Archivo gestionado por la app (mismo que lee el lado Swift).
    for path in (
        os.path.expanduser("~/Library/Application Support/Marker/api_key"),
        os.path.expanduser("~/.config/marker/api_key"),
    ):
        try:
            with open(path, "r", encoding="utf-8") as handle:
                value = handle.read().strip()
                if value:
                    return value
        except OSError:
            pass

    # 3. Último recurso: Keychain heredado de versiones antiguas. Puede
    #    pedir autorización; sólo se llega aquí si no hay archivo ni env.
    try:
        out = subprocess.check_output(
            [
                "security", "find-generic-password",
                "-s", "com.marker.app",
                "-a", "GEMINI_API_KEY",
                "-w",
            ],
            stderr=subprocess.DEVNULL,
        )
        value = out.decode().strip()
        if value:
            return value
    except subprocess.CalledProcessError:
        pass
    return None


def notify(title, message):
    # Escapa comillas dobles para AppleScript.
    safe = message.replace("\\", "\\\\").replace('"', '\\"')
    safe_title = title.replace("\\", "\\\\").replace('"', '\\"')
    subprocess.call([
        "osascript", "-e",
        f'display notification "{safe}" with title "{safe_title}"',
    ])


def fatal(message):
    notify("Marker", message)
    print(f"marker-cli: {message}", file=sys.stderr)
    sys.exit(1)


def locate_convert_py():
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # 1. Junto al script (caso bundle: marker-cli y convert.py viven en la
    #    misma carpeta Resources/ del .app, también si copias ambos a
    #    /usr/local/bin).
    sibling = os.path.join(script_dir, "convert.py")
    if os.path.isfile(sibling):
        return sibling

    # 2. Repo de desarrollo: <repo>/scripts/marker-cli → <repo>/Marker/Resources/convert.py
    repo_local = os.path.join(
        os.path.dirname(script_dir), "Marker", "Resources", "convert.py"
    )
    if os.path.isfile(repo_local):
        return repo_local

    # 3. App instalada en /Applications (cuando marker-cli vive fuera del
    #    bundle, p.ej. en /usr/local/bin).
    for app_path in (
        "/Applications/Marker.app",
        os.path.expanduser("~/Applications/Marker.app"),
    ):
        candidate = os.path.join(app_path, "Contents", "Resources", "convert.py")
        if os.path.isfile(candidate):
            return candidate
    return None


def main(argv):
    pdfs = [p for p in argv if p.lower().endswith(".pdf") and os.path.isfile(p)]
    if not pdfs:
        fatal("No se ha pasado ningún PDF válido.")

    key = get_api_key()
    if not key:
        fatal(
            "GEMINI_API_KEY no encontrada. "
            "Abre Marker.app → Settings y guarda tu key."
        )

    convert_py = locate_convert_py()
    if not convert_py:
        fatal(
            "convert.py no encontrado. Asegúrate de tener Marker.app en "
            "/Applications o el repo del proyecto disponible."
        )

    # Importamos convert dinámicamente desde la ruta resuelta.
    import importlib.util
    spec = importlib.util.spec_from_file_location("marker_convert", convert_py)
    module = importlib.util.module_from_spec(spec)
    os.environ["GEMINI_API_KEY"] = key
    os.environ.setdefault("PYTHONWARNINGS", "ignore")
    spec.loader.exec_module(module)

    succeeded, failed = 0, 0
    failures = []
    for pdf in pdfs:
        out_dir = os.path.join(os.path.dirname(pdf), "MD")
        os.makedirs(out_dir, exist_ok=True)
        name = os.path.splitext(os.path.basename(pdf))[0]
        out_path = os.path.join(out_dir, f"{name}.md")
        try:
            module.convert(pdf, out_path)
            succeeded += 1
            print(f"OK  {out_path}")
        except Exception as exc:
            failed += 1
            failures.append(f"{name}: {exc}")
            print(f"ERR {pdf}: {exc}", file=sys.stderr)

    if failed == 0:
        msg = f"{succeeded} PDF{'s' if succeeded != 1 else ''} convertido{'s' if succeeded != 1 else ''}"
    elif succeeded == 0:
        msg = f"{failed} PDF{'s' if failed != 1 else ''} falló"
    else:
        msg = f"{succeeded} convertidos · {failed} fallaron"
    notify("Marker", msg)


if __name__ == "__main__":
    main(sys.argv[1:])
