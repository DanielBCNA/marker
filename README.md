# Marker

Convierte PDFs a Markdown limpio en tu Mac, usando Google Gemini.

Pensada originalmente para transcripciones de _earnings calls_, pero funciona con cualquier PDF de texto. Drag & drop, o click derecho en Finder.

> **Estado**: utilidad personal, mantenida por una sola persona. La uso a diario. Si te sirve, encantado de que la uses tú también.

---

## Características

- **Drag & drop o selector**: arrastra uno o varios PDFs (o una carpeta completa) a la ventana.
- **Quick Action de Finder**: click derecho sobre un PDF → **Acciones rápidas → Convertir a Markdown con Marker**. Sin abrir la app.
- **Conversión en paralelo**: hasta 3 PDFs simultáneos.
- **Cadena de fallback de modelos**: si la cuota gratuita del modelo más holgado se agota, salta automáticamente al siguiente.
- **Reintentos inteligentes**: distingue errores de cuota diaria (no merece la pena reintentar) de errores transitorios (sí).
- **Auto-actualización**: la propia app comprueba si hay versión nueva y se actualiza con un click. Verificación criptográfica con Ed25519.
- **API key local**: tu clave de Gemini se guarda en `~/Library/Application Support/Marker/`, con permisos restringidos a tu usuario. No sale de tu Mac salvo hacia la propia API de Gemini.
- **Output junto al PDF**: por cada `Foo.pdf` escribe `MD/Foo.md` en una subcarpeta `MD/` al lado del original.

## Requisitos

- macOS 14 Sonoma o superior.
- Una API key gratuita de Google Gemini: <https://aistudio.google.com/apikey>.

## Instalación

1. Descarga la última versión: <https://github.com/DanielBCNA/Marker/releases/latest> → `Marker.zip`.
2. Descomprime y arrastra `Marker.app` a `/Applications`.
3. **Primera apertura**: como la app no está firmada con un Apple Developer ID ($99/año), macOS la marca en cuarentena. Para autorizarla la primera vez, abre Terminal y ejecuta:
   ```bash
   xattr -cr /Applications/Marker.app
   ```
   A partir de ahí, doble click la abre normal.
4. Al arrancar te pedirá tu API key de Gemini. Pégala y se guarda en una carpeta protegida de tu Mac (`~/Library/Application Support/Marker/`).

A partir de la primera instalación, las futuras versiones se actualizan solas vía la app — no tienes que volver a bajar nada manualmente.

## Cómo se usa

### Desde la app

1. Abre Marker.
2. Arrastra uno o varios PDFs a la ventana, o pulsa "Selecciona PDFs o una carpeta".
3. Pulsa **Convertir** (o `⌘ Enter`).
4. Cuando termine, los `.md` están en una subcarpeta `MD/` al lado de cada PDF original.

### Desde Finder (sin abrir la app)

1. Click derecho sobre uno o varios PDFs.
2. **Acciones rápidas → Convertir a Markdown con Marker**.
3. Notificación del sistema cuando termine. Los `.md` aparecen en `MD/` al lado del PDF.

La Quick Action se instala automáticamente la primera vez que abres Marker.

## Privacidad

Marker envía el PDF entero a la API de Google Gemini para hacer la conversión. **No hace ningún parsing local**: tu Mac no procesa el contenido del documento.

Implicaciones:

- Los PDFs salen de tu Mac y pasan por servidores de Google. Si el documento contiene información confidencial (contratos, datos médicos, datos personales de terceros), considera si tu caso de uso lo permite.
- Google declara que los datos enviados vía el tier gratuito de Gemini pueden usarse para entrenar modelos. El tier de pago tiene política distinta. Consulta los términos actuales: <https://ai.google.dev/gemini-api/terms>.
- Marker borra el PDF subido a Gemini al terminar (best effort: si la app cierra inesperadamente, Gemini los limpia por sí mismo en 48 h).
- Marker no manda telemetría a ningún sitio. No tiene servidor propio. La única red que toca es la API de Gemini y el feed de updates de GitHub Releases.

## Cómo funciona por dentro

- App nativa SwiftUI; el motor de conversión es un script Python (`convert.py`) que llama al SDK `google-genai`.
- Cadena de modelos: Gemini 3.1 flash-lite → 2.5 flash-lite → 2.5 flash → 3 flash preview. Ordenada por RPD (requests per day) descendente para gastar primero la cuota gratuita más holgada.
- Generación determinística (`temperature=0`, `response_mime_type="text/markdown"`) para reproducibilidad.
- Auto-update vía [Sparkle 2](https://sparkle-project.org/) con firmas Ed25519. La app valida criptográficamente cada update antes de instalarlo.

## Compilar desde el código fuente

Si prefieres compilar tú la app en lugar de descargar el binario:

```bash
# Dependencias
brew install xcodegen
pip3 install 'google-genai==2.6.0'

# Clonar y generar proyecto Xcode
git clone https://github.com/DanielBCNA/Marker.git
cd Marker
xcodegen generate

# Abrir y compilar
open Marker.xcodeproj
```

El proyecto Xcode (`Marker.xcodeproj/`) se regenera siempre desde `project.yml` con XcodeGen. No lo edites a mano.

Si añades archivos `.swift` nuevos, vuelve a ejecutar `xcodegen generate` antes de compilar.

### CI / publicación

Cada push a `main` lanza el workflow `.github/workflows/build.yml`, que compila la app en un runner macOS, firma el zip con la clave privada Ed25519 (en GitHub Secrets), genera el `appcast.xml` y publica un nuevo Release. La app instalada lo detecta automáticamente vía Sparkle.

## Limitaciones conocidas

- Pensada para PDFs de texto. PDFs escaneados sin OCR pueden dar resultados pobres (depende de cómo los maneje Gemini multimodal).
- Solo macOS 14 Sonoma o superior.
- Requiere conexión a internet para cada conversión (no hay modo offline).
- Sin Developer ID de Apple, la primera apertura requiere el truco de `xattr -cr` arriba descrito.

## Contribuir

Issues y pull requests son bienvenidos. Para bugs, abre un issue con la versión de Marker (menú **Marker → Acerca de Marker**) y, si puedes, el log del error.

Si encuentras una vulnerabilidad de seguridad, consulta [`SECURITY.md`](SECURITY.md) para reportarla en privado en lugar de en un issue público.

## Licencia

[MIT](LICENSE). Úsala, modifícala, distribúyela. Sin garantía.

## Agradecimientos

- [Sparkle](https://sparkle-project.org/) — framework de auto-update.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — proyecto Xcode generado desde `project.yml`.
- [Google Gemini](https://ai.google.dev/) — modelo de conversión.
