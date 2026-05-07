# Marker

App macOS para convertir PDFs (transcripciones de earnings calls) a Markdown
limpio usando Google Gemini.

Reconstruido a partir del binario original — el código fuente se había
perdido. La app compilada que ya tenías en `~/Applications/Marker/Marker.app`
sigue funcionando; este repo es la fuente para poder iterar.

## Setup

### 1. Dependencias del sistema

```bash
brew install xcodegen
pip3 install google-genai
```

Para compilar y correr el .app necesitas Xcode (App Store).

### 2. API key

Forma recomendada: abre la app, ve a **Marker → Settings…** y pega tu key. Se
guarda en el Keychain del sistema.

Para desarrollo o headless:

```bash
cp .env.example .env
# Edita .env y pega tu GEMINI_API_KEY
```

En tiempo de ejecución la app busca la key en este orden:
1. Variable de entorno `GEMINI_API_KEY`
2. Keychain del sistema (lo que escribe la pantalla Settings)
3. Archivo `~/.config/marker/api_key`
4. Archivo `.env` en el directorio del proyecto (sólo en desarrollo)

### 3. Generar el proyecto Xcode y abrir

```bash
xcodegen generate
open Marker.xcodeproj
```

`Marker.xcodeproj/` está gitignored — se regenera con `xcodegen generate`
desde `project.yml`. Si añades archivos `.swift`, basta con regenerar.

## Estructura

```
Marker/
├── MarkerApp.swift          # @main App
├── ContentView.swift        # vista principal
├── Models/
│   ├── PDFItem.swift        # modelo + FileStatus
│   └── ConversionStore.swift # estado y orquestación
├── Views/
│   ├── DropZoneView.swift
│   └── FileRowView.swift
├── Services/
│   └── ScriptManager.swift  # lanza convert.py vía Process
└── Resources/
    └── convert.py           # script Python que llama a Gemini
```

## Quick Action en Finder

La app instala automáticamente la Quick Action "Convertir a Markdown con
Marker" en `~/Library/Services/` la primera vez que arranca, apuntando al
`marker-cli.py` empaquetado dentro del propio `.app`. No hay que pasar por
Automator.

Después de la primera ejecución de Marker, click derecho sobre uno o
varios PDFs en Finder → **Acciones rápidas → Convertir a Markdown con
Marker**. Notificación del sistema con el resumen al terminar.

La key se lee del Keychain (la misma que guarda la app), así que no hace
falta tenerla en otro sitio.

Si mueves Marker.app de carpeta, vuelve a abrirla — el instalador
detecta que la ruta ha cambiado y reescribe la Quick Action con la
nueva ubicación.

> **Nota — TCC y `~/Documents`:** macOS bloquea Quick Actions que ejecutan
> scripts desde `~/Documents` ("Operation not permitted"). Por eso
> `marker-cli.py` se distribuye dentro del `.app`, que vive en `/Applications`
> y está fuera del alcance de TCC.

## Notas

- La conversión la hace `convert.py` con `google-genai`. Lleva fallback en
  cadena de modelos (Gemini 3.1 flash-lite preview → 2.5 flash-lite → 2.5
  flash → 3 flash preview) y reintentos con backoff `[8, 20, 45]` para
  errores transitorios y de cuota.
- Salida: cada `Foo.pdf` produce `MD/Foo.md` (subcarpeta `MD/` junto al PDF).
- La app no está sandboxed — necesita acceso libre al filesystem y a la
  red para hablar con la API de Gemini.
