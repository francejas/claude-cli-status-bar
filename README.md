# Status Line para Claude Code

## Quick Start

> ✅ **Cross-platform:** `/statusline` funciona en macOS, Linux y Windows por igual. Claude genera el script en Bash o PowerShell según tu sistema — no tenés que hacer nada extra.

Simplemente escribí un comando `/statusline` describiendo qué querés:

```
/statusline muestra nombre del modelo y porcentaje de contexto con una barra de progreso
```

Claude genera el script, lo guarda y configura tu `settings.json` solo. Listo.

Más ejemplos:

```
/statusline muestra nombre del repo, rama de git, barra de contexto y modelo
/statusline muestra costo y duración de la sesión con nombre del modelo
/statusline muestra rama de git con conteo de archivos staged/modified coloreado
/statusline dos líneas: modelo y rama arriba, barra de contexto coloreada con costo abajo
```

Para quitarlo:

```
/statusline clear
```

## ¿Querés el mío?

Este es el status line exacto que uso todos los días. Coloreado por completo, con iconos y una barra de límite de uso en degradé.

Cómo se ve:

<img width="1209" height="56" alt="Ejemplo del status line en la terminal" src="https://github.com/user-attachments/assets/a6f9cc3f-d881-40f1-8f74-bb17216f0609" />

En texto plano:

```
claude-cli-status-bar | 🌿 (main) +2 ~3 | 🤖 Sonnet 5 (medium) | 5h ⚡ ████████████ 24% ↻ 3h12m | ctx 42% | $1.23 | +120 -34
```

| Elemento | Ejemplo | Color |
|---|---|---|
| Nombre de carpeta | `claude-cli-status-bar` | Amarillo bold |
| Rama | `🌿 (main)` | Cian bold |
| Estado sucio | `+2 ~3` | Verde (staged) / amarillo (modified) / gris (untracked) |
| Barra de límite de uso | `⚡ ████████████ 24%` | RGB truecolor degradé (verde → amarillo → rojo) + emoji dinámico |
| Emoji de uso | `🟢 → ⚡ → 🔥 → 🚨` | Cambia en 20% / 70% / 90% |
| Contexto | `ctx 42%` | Coloreado según nivel de uso |
| Costo | `$1.23` | Amarillo dorado |
| Velocidad de código | `+120 -34` | Verde agregados, rojo eliminados |
| Modelo | `🤖 Sonnet 5 (medium)` | Magenta |
| Separadores | `\|` | Gris tenue |

> El script también muestra un badge `[CAVEMAN]` si detecta el plugin [caveman](https://github.com/JuliusBrussee/caveman) activo. Si no lo tenés instalado, el badge simplemente no aparece.

### Un comando para conseguirlo

```
/statusline una sola línea, completamente coloreada con degradé RGB truecolor: nombre de carpeta en amarillo bold, icono de hoja 🌿 + rama de git en cian bold entre paréntesis con conteo de +staged ~modified ?untracked, barra de límite de uso de 12 bloques con degradé RGB de 24 bits de verde(0,200,80) pasando por amarillo(220,200,0) hasta rojo(220,40,20) con bloques vacíos en gris oscuro(60,60,60), emoji dinámico que cambia según uso (🟢 debajo de 20%, ⚡ 20-69%, 🔥 70-89%, 🚨 90%+), porcentaje coloreado según nivel de uso, tiempo hasta el reset, porcentaje de ventana de contexto coloreado igual, costo de sesión en amarillo dorado, líneas agregadas en verde y eliminadas en rojo, icono de robot 🤖 + nombre del modelo en magenta con el nivel de esfuerzo entre paréntesis, separadores en gris tenue entre todos los elementos
```

### O copiá el script directamente

Está en [`statusline.ps1`](./statusline.ps1) de este repo — PowerShell, pensado para Windows.

## Requisitos

- Windows con PowerShell (funciona con Windows PowerShell 5.1 y PowerShell 7+)
- Git (solo para el segmento de rama/estado sucio — sin git, el script sigue funcionando igual, sin ese segmento)

## Instalación manual

1. Copiá `statusline.ps1` a tu carpeta de configuración de Claude (normalmente `~/.claude/`):

   ```powershell
   Copy-Item statusline.ps1 "$HOME\.claude\statusline.ps1"
   ```

2. Agregá (o editá) el bloque `statusLine` en `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\<tu-usuario>\\.claude\\statusline.ps1\""
     }
   }
   ```

   Cambiá `<tu-usuario>` por tu usuario de Windows. Si usás Git Bash, ver las [notas de Claude Code para Windows](https://code.claude.com/docs/en/statusline#windows-configuration).

3. Reiniciá Claude Code (o abrí una sesión nueva) para que tome el `statusLine` nuevo.

## Notas

- **Los campos de límite de uso, costo y contexto solo aparecen después de la primera respuesta de API en la sesión.** Es comportamiento de la plataforma Claude Code (`rate_limits`, `cost` y `context_window` vienen `null`/ausentes hasta que termina el primer mensaje) — el script no puede mostrarlos antes porque Claude Code todavía no los envía.
- `effort` se lee de la sesión en vivo si está disponible, si no cae a `effortLevel` de `~/.claude/settings.json`.
- El script solo lee stdin y estado local de git — no hace llamadas de red.

## Personalización

El script es una lista plana de segmentos independientes (`$parts += ...`), cada uno envuelto en `try/catch`, cerca del final del archivo — comentá o reordená cualquiera de las 6 secciones numeradas para cambiar qué se muestra o en qué orden. Ver la [documentación de Claude Code sobre status line](https://code.claude.com/docs/en/statusline#available-data) para la lista completa de campos disponibles por stdin si querés agregar los tuyos.
