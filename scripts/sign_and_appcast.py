#!/usr/bin/env python3
"""Firma Marker.zip con la clave privada Ed25519 de Sparkle y emite el
appcast.xml correspondiente.

Inputs (variables de entorno):
    SPARKLE_PRIVATE_KEY   Clave privada Ed25519 en base64 (32 bytes).
    MARKER_ZIP            Ruta al .zip a firmar (default: Marker.zip).
    MARKER_VERSION        Version corta (CFBundleShortVersionString).
    MARKER_BUILD          Build number entero (CFBundleVersion).
    MARKER_DOWNLOAD_URL   URL absoluta donde Sparkle bajara el zip.
    APPCAST_PATH          Salida del appcast (default: appcast.xml).

El appcast resultante describe SOLO la version actual. Sparkle se
encarga de comparar con la version instalada y ofrecer la actualizacion.
"""
import base64
import os
import sys
from datetime import datetime, timezone
from email.utils import format_datetime
from pathlib import Path
from xml.sax.saxutils import escape

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey


def fail(msg):
    print(f"sign_and_appcast: {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    priv_b64 = os.environ.get("SPARKLE_PRIVATE_KEY")
    if not priv_b64:
        fail("Falta SPARKLE_PRIVATE_KEY en el entorno")

    zip_path = Path(os.environ.get("MARKER_ZIP", "Marker.zip"))
    if not zip_path.is_file():
        fail(f"No existe {zip_path}")

    version = os.environ.get("MARKER_VERSION") or fail("Falta MARKER_VERSION")
    build = os.environ.get("MARKER_BUILD") or fail("Falta MARKER_BUILD")
    download_url = os.environ.get("MARKER_DOWNLOAD_URL") or fail("Falta MARKER_DOWNLOAD_URL")
    appcast_path = Path(os.environ.get("APPCAST_PATH", "appcast.xml"))

    try:
        priv_bytes = base64.b64decode(priv_b64)
    except Exception as exc:
        fail(f"SPARKLE_PRIVATE_KEY no es base64 valido: {exc}")
    if len(priv_bytes) != 32:
        fail(f"La clave privada debe tener 32 bytes, son {len(priv_bytes)}")

    priv = Ed25519PrivateKey.from_private_bytes(priv_bytes)
    data = zip_path.read_bytes()
    signature_b64 = base64.b64encode(priv.sign(data)).decode("ascii")
    length = zip_path.stat().st_size
    pub_date = format_datetime(datetime.now(timezone.utc))

    appcast = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Marker</title>
        <link>https://github.com/DanielBCNA/Marker</link>
        <description>Actualizaciones automaticas de Marker.</description>
        <language>es</language>
        <item>
            <title>Marker {escape(version)}</title>
            <pubDate>{pub_date}</pubDate>
            <sparkle:version>{escape(build)}</sparkle:version>
            <sparkle:shortVersionString>{escape(version)}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure
                url="{escape(download_url)}"
                sparkle:edSignature="{signature_b64}"
                length="{length}"
                type="application/octet-stream" />
        </item>
    </channel>
</rss>
"""

    appcast_path.write_text(appcast, encoding="utf-8")
    print(f"Firma generada ({len(signature_b64)} chars b64)")
    print(f"Appcast escrito en {appcast_path} ({appcast_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
