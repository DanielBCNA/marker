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

```bash
cp .env.example .env
# Edita .env y pega tu GEMINI_API_KEY
```

En tiempo de ejecución la app busca la key en este orden:
1. Variable de entorno `GEMINI_API_KEY`
2. Archivo `~/.config/marker/api_key`
3. Archivo `.env` en el directorio del proyecto (sólo en desarrollo)

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

## Notas

- La conversión la hace `convert.py` con `google-genai`. Lleva fallback en
  cadena de modelos (Gemini 3.1 flash-lite preview → 2.5 flash-lite → 2.5
  flash → 3 flash) y reintentos con backoff `[8, 20, 45]` para errores
  transitorios.
- Salida: cada `Foo.pdf` produce `Foo.md` en su misma carpeta.
- La app no está sandboxed — necesita acceso libre al filesystem y a la
  red para hablar con la API de Gemini.
