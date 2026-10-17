# Fronteras de Hierro

Juego de estrategia 2D en tiempo real de conquista de territorios. Controlas una nación ficticia en un mapa dividido en provincias conectadas, mueves tropas, combates contra una facción enemiga controlada por IA e intentas ganar la guerra.

- **Motor:** Godot 4.7
- **Lenguaje:** GDScript
- **Plataforma:** PC con Windows
- **Estilo:** pixel art, mapa estratégico visto desde arriba
- **Inspiración:** los conceptos generales de OpenFront y Call of War. No se copian sus mapas, recursos, código, nombres ni interfaz.

## Estado actual

**Hito 1 (mapa y provincias) implementado; pendiente de validar en el PC del propietario.**

- Hito 0 (cimientos): validado manualmente en Godot 4.7.2 en Windows, según informó el propietario (importa, F5 arranca, sin errores).
- Hito 1: mapa **estático** de 14 provincias ficticias (7 del jugador, 7 del enemigo) con fronteras, nombres, leyenda y contador. Los datos están en `scripts/data/province_data.gd` y el dibujo en `scripts/map/province_map.gd`.
- Pruebas automáticas de los datos del mapa en `tests/test_province_data.gd`.

**Todavía no hay jugabilidad**: no se puede hacer clic en provincias, ni hay tropas, combate, captura ni IA.

> Desde la nube no hay ejecutable de Godot: ni las pruebas automáticas ni el dibujo del mapa se han ejecutado todavía. Ver `docs/TEST_PLAN.md`.

## Cómo abrir el proyecto

1. Instala Godot 4.7 (versión estándar, no .NET).
2. Clona este repositorio o descárgalo.
3. En el gestor de proyectos de Godot pulsa **Importar** y elige el archivo `project.godot`.
4. Pulsa **F5** (Ejecutar proyecto). Debe aparecer una pantalla oscura con el título del juego.

La primera vez Godot generará la carpeta `.godot/` (caché local, ignorada por git).

## Pruebas automáticas

Desde la raíz del proyecto (sustituye `godot` por la ruta de tu ejecutable de Godot 4.7):

```
godot --headless --path . --script res://tests/test_province_data.gd
```

Imprime `PASS`/`FAIL` por prueba y termina con código 0 si todo pasa o 1 si algo falla. Si es la primera vez que abres el proyecto, ábrelo antes una vez en el editor para que Godot genere la caché `.godot/`.

## Estructura

| Ruta | Contenido |
|---|---|
| `scenes/` | Escenas de Godot (`.tscn`) |
| `scripts/data/` | Datos autoritativos del mapa (`province_data.gd`) |
| `scripts/map/` | Dibujo del mapa (`province_map.gd`) |
| `tests/` | Pruebas automáticas (sin plugins) |
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
