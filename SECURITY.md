# Política de seguridad

## Reportar vulnerabilidades

Si encuentras un fallo de seguridad en Marker, **por favor no abras un issue público**. En su lugar:

1. Usa [GitHub Security Advisories](https://github.com/DanielBCNA/Marker/security/advisories/new) para reportarlo en privado.
2. O envía un email a la dirección de contacto del autor (perfil de GitHub: [@DanielBCNA](https://github.com/DanielBCNA)).

Intentaré responder en un plazo razonable (entiende que es un proyecto mantenido por una sola persona en su tiempo libre).

## Alcance

Marker es una aplicación nativa de macOS que envía PDFs a la API de Google Gemini. Considera _en alcance_ los siguientes vectores:

- Cualquier fallo que permita ejecución arbitraria de código en el Mac del usuario al abrir Marker.
- Cualquier fallo en la cadena de auto-update (Sparkle + Ed25519) que permita instalar un binario no firmado por el autor.
- Cualquier exposición no intencionada de la API key de Gemini del usuario.
- Cualquier fallo en el handler de Quick Action que permita ejecución arbitraria al hacer click derecho sobre un archivo malicioso.

Considera _fuera de alcance_:

- Vulnerabilidades en la API de Google Gemini o en SDKs de Google (repórtalas a Google).
- Vulnerabilidades en macOS, Sparkle, o cualquier otra dependencia upstream (repórtalas al proyecto correspondiente).
- Comportamiento esperado de la app (p. ej. que envíe el PDF a Google: es la única forma de convertirlo).

## Cadena criptográfica

- Cada release se firma con una clave Ed25519. La clave pública vive embebida en el `Info.plist` de la app; la privada vive en GitHub Secrets del repo.
- Sparkle 2 valida la firma antes de instalar cualquier update. Sin firma válida, rechaza.
- El feed de updates se sirve por HTTPS desde GitHub Releases.

Si la clave privada se viese comprometida, se rotaría: nueva clave en el secret + nueva clave pública en el Info.plist + nueva versión publicada. Los usuarios actuales tendrían que bajar manualmente esa nueva versión una vez (igual que hicieron la primera instalación).
