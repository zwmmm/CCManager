# CCManager

> Herramienta de gestión de Provider en la barra de menús de macOS, para cambiar rápidamente la configuración de API entre Claude Code y Codex.

[![Release](https://img.shields.io/github/v/release/zwmmm/CCManager?style=flat-square)](https://github.com/zwmmm/CCManager/releases)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org/)
[![Homebrew](https://img.shields.io/badge/Homebrew-cask-FBB040?style=flat-square&logo=homebrew&logoColor=000)](https://brew.sh/)
[![XcodeGen](https://img.shields.io/badge/project-XcodeGen-blue?style=flat-square)](https://github.com/yonaskolb/XcodeGen)

<img width="1702" height="1228" alt="Interfaz principal de CCManager" src="https://github.com/user-attachments/assets/370eda37-0bff-46d8-95bb-346595eb58a5" />

## Descarga e instalación

### Homebrew

```bash
brew install --cask zwmmm/tap/ccmanager
```

Si ya has añadido el repositorio tap:

```bash
brew tap zwmmm/tap
brew install --cask ccmanager
```

Actualizar o desinstalar:

```bash
brew upgrade --cask ccmanager
brew uninstall --cask ccmanager
```

### GitHub Releases

También puedes descargar la última versión desde [Releases](https://github.com/zwmmm/CCManager/releases).

> Homebrew solo instala la aplicación gráfica `CCManager.app`; el comando CLI `ccmanager` debe instalarse desde el panel de configuración dentro de la aplicación.

## Uso rápido

1. Inicia CCManager y busca el icono de la aplicación en la barra de menús.
2. Añade un Provider de Claude Code o Codex.
3. Haz clic derecho en el icono de la barra de menús y selecciona el Provider que deseas activar.
4. CCManager escribirá el archivo de configuración correspondiente: `~/.claude/settings.json` o `~/.codex/config.toml`.

<img width="676" height="904" alt="Panel de cambio de Provider en la barra de menús" src="https://github.com/user-attachments/assets/956d9829-cc80-4056-8499-3c60dc5751a9" />

## Funciones principales

- **Gestión de Provider**: Compatible con Claude Code, Codex, y presets comunes como OpenAI, Anthropic, GLM, MiniMax, Kimi y OpenRouter.
- **Cambio con un clic**: Solo actualiza la URL del endpoint, la API Key y la configuración del modelo, sin sobrescribir otras configuraciones manuales.
- **Prueba de conexión**: Puedes probar directamente si la API está disponible al añadir o editar un Provider.
- **Edición de configuración**: Puedes abrir los archivos de configuración originales con editores externos como VS Code o Xcode.
- **Importar/Exportar**: Exporta la configuración del Provider como JSON, o restáurala desde un JSON.
- **Actualización automática**: Comprueba automáticamente si hay nuevas versiones al iniciar y durante su ejecución.

## Atajos de teclado comunes

| Atajo | Acción |
|-------|--------|
| `⌘T` | Añadir Provider |
| `⌘E` | Editar el Provider seleccionado actualmente |
| `⌘↩` | Aplicar la configuración del Provider seleccionado actualmente |
| `⌘,` | Abrir configuración |
| `⌘W` | Cerrar ventana |

## Configuración

El panel de configuración incluye:

- Apariencia: Oscuro/Claro/Seguir el sistema, con varios temas de color integrados.
- Editor: Selecciona el editor externo para abrir los archivos de configuración.
- Gestión de datos: Importar y exportar la configuración del Provider.
- Inicio automático: Iniciar automáticamente al iniciar sesión en macOS.
- CLI: Instalar o eliminar la herramienta de línea de comandos `ccmanager`.
- Acerca de: Ver la versión y comprobar manualmente si hay actualizaciones.

## Por qué se creó CCManager

Muchas herramientas de cambio接管an el archivo de configuración completo, lo que puede sobrescribir campos mantenidos manualmente. El principio de CCManager es más conservador:

> Solo modifica los campos necesarios para cambiar de Provider; el resto de la configuración se deja en manos del usuario.

Si necesitas modificar configuraciones avanzadas, simplemente abre el archivo de configuración original con un editor externo.

## Agradecimientos

CCManager se inspiró en [cc-switch](https://github.com/farion1231/cc-switch). Es una herramienta CLI de IA multiplataforma y completa, que abarca múltiples áreas como Provider, MCP, Skills y Prompts.

Este proyecto hace referencia y se inspira en cc-switch en su enfoque de diseño y en部分实现, pero con un enfoque más específico: conserva la capacidad de cambiar de Provider y escribir configuraciones, creando una herramienta ligera y nativa para la barra de menús de macOS.

## Requisitos del sistema

- macOS 13.0+

## Compilación local

```bash
xcodegen generate
xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release build
```

También puedes abrir `CCManager.xcodeproj` con Xcode y ejecutarlo directamente.
