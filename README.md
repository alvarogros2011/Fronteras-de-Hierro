# Fronteras de Hierro

Juego de estrategia 2D en tiempo real de conquista de territorios. Controlas una nación ficticia en un mapa dividido en provincias conectadas, mueves tropas, combates contra una facción enemiga controlada por IA e intentas ganar la guerra.

- **Motor:** Godot 4.7
- **Lenguaje:** GDScript
- **Plataforma:** PC con Windows
- **Estilo:** pixel art, mapa estratégico visto desde arriba
- **Inspiración:** los conceptos generales de OpenFront y Call of War. No se copian sus mapas, recursos, código, nombres ni interfaz.

## Estado actual

**Cimientos del proyecto.** Lo único implementado es:

- Configuración de Godot (`project.godot`): ventana de 1280x720, escalado 2D, renderizador Compatibility.
- Una escena de arranque (`scenes/main.tscn`) con el título y el subtítulo "Prototipo temprano".

**No hay jugabilidad todavía**: ni mapa, ni provincias, ni tropas, ni combate, ni IA.

> La escena no se ha ejecutado en Godot desde la nube (no había ejecutable disponible). Ábrela en tu PC para comprobarla. Ver `docs/TEST_PLAN.md`.

## Cómo abrir el proyecto

1. Instala Godot 4.7 (versión estándar, no .NET).
2. Clona este repositorio o descárgalo.
3. En el gestor de proyectos de Godot pulsa **Importar** y elige el archivo `project.godot`.
4. Pulsa **F5** (Ejecutar proyecto). Debe aparecer una pantalla oscura con el título del juego.

La primera vez Godot generará la carpeta `.godot/` (caché local, ignorada por git).

## Estructura

| Ruta | Contenido |
|---|---|
| `scenes/` | Escenas de Godot (`.tscn`) |
| `scripts/` | Scripts GDScript (aún vacío; se crea con el primer script) |
| `assets/` | Arte y sonido (aún vacío; se crea con el primer recurso) |
| `docs/` | Documentación del diseño y del desarrollo |

## Documentación

- [`docs/GDD.md`](docs/GDD.md): diseño del juego (decisiones confirmadas y suposiciones).
- [`docs/ROADMAP.md`](docs/ROADMAP.md): hitos de desarrollo con criterios de finalización.
- [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md): pruebas manuales y automáticas.
- [`CLAUDE.md`](CLAUDE.md): instrucciones persistentes para las sesiones de Claude Code.

## Proceso de desarrollo

- Trabajo por **hitos pequeños** en el orden de `docs/ROADMAP.md`; cada hito se pide y se revisa por separado.
- Cada hito se desarrolla en una rama propia y se revisa antes de fusionarse. Nunca se trabaja directamente sobre `main`.
- La lógica del juego (combate, propiedad, IA, victoria) se separa de la interfaz para poder probarla de forma automática.
- Todo hito se cierra con un informe honesto de qué se probó y qué no.
- La documentación y los comentarios están en español.
