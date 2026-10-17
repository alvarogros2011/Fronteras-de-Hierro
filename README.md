# Fronteras de Hierro

Juego 2D de estrategia territorial en tiempo real, fácil de aprender y de jugar, muy cercano a la experiencia general de OpenFront pero con mecánicas propias y algo más de profundidad, sin ser un RTS táctico complejo.

- **Motor:** Godot 4.7 · **Lenguaje:** GDScript · **Plataforma:** PC con Windows
- **Estilo:** pixel art, mapa visto desde arriba, interfaz limpia y minimalista
- **Inspiración:** conceptos generales de OpenFront. No se copian sus mapas, recursos, código, nombres ni interfaz.

## Concepto actual (visión de diseño)

> Esta sección describe lo **planificado**, no lo implementado.

- El mapa es el elemento principal: territorio y fronteras pixeladas, con varias naciones.
- Cada nación es un territorio continuo formado por celdas; **no hay provincias seleccionables**.
- El jugador funda **ciudades**, que se ven como agrupaciones de píxeles y crecen con el tiempo (cada vez más despacio) y suben de nivel.
- La población se reparte entre **trabajadores y soldados** con un control deslizante en el HUD (solo afecta a la población nueva); existe un **reclutamiento forzoso**.
- Solo hay **dos recursos**: dinero (construcciones) y recursos (mantenimiento de trabajadores y soldados).
- Antes de atacar, el juego mostrará una previsión comprensible de ventaja y pérdidas.
- La mecánica diferenciadora definitiva, el modelo de ejércitos y muchos números siguen **sin decidir**. Ver `docs/GDD.md`.

## Estado real del proyecto

**Fase actual: construcción del sistema territorial nuevo. Hito 3 hecho (solo datos, sin dibujo).**

**Sistema nuevo (hito 3):** `scripts/world/territory_grid.gd` guarda el territorio como una cuadrícula de 320x180 celdas (terreno agua/tierra y propietario por celda en dos `PackedByteArray`), con 4 naciones provisionales (jugador y 3 rivales) y un mapa inicial determinista: una masa de tierra con costa irregular, cuatro pequeños territorios conectados y tierra sin reclamar. Los valores de la cuadrícula son **provisionales**. Aún **no se dibuja ni se puede interactuar con él**: al pulsar F5 sigue viéndose el prototipo anterior. Sus pruebas (`tests/test_territory_grid.gd`) están escritas pero **no se han ejecutado en Godot**.

**Prototipo anterior de provincias (legado)**, intacto:
- Pantalla inicial con el título y mapa estático de 14 provincias (7 del jugador, 7 del enemigo).
- Clic izquierdo para seleccionar una provincia y panel con su nombre, propietario y vecinas.
- El propietario validó a mano en Godot 4.7.2 la pantalla inicial, el mapa y la selección.
- Existen pruebas automáticas (`tests/`), pero **no están confirmadas como ejecutadas** en Godot.

Este prototipo **no se amplía**: no hay tropas, combate, captura, economía, ciudades ni IA. Se mantiene intacto y solo se retirará cuando el nuevo mapa visual y su interacción hayan sido validados manualmente en el PC del propietario.

No existen todavía ciudades, población, recursos, ejércitos, expansión, ataques ni IA. Siguiente paso: validar las pruebas del hito 3 en Godot y empezar el hito 4 (vista pixelada del territorio). Ver `docs/ROADMAP.md`.

## Cómo abrir el proyecto

1. Instala Godot 4.7 (versión estándar, no .NET).
2. Clona este repositorio o descárgalo.
3. En el gestor de proyectos de Godot pulsa **Importar** y elige `project.godot`.
4. Pulsa **F5**. Aparece el mapa de provincias del prototipo anterior.

La primera vez Godot genera la carpeta `.godot/` (caché local, ignorada por git).

## Pruebas automáticas

Desde la raíz del proyecto (sustituye `godot` por la ruta de tu ejecutable de Godot 4.7):

```
godot --headless --path . --script res://tests/test_territory_grid.gd
godot --headless --path . --script res://tests/test_province_data.gd
godot --headless --path . --script res://tests/test_province_selection.gd
```

Cada comando ejecuta un archivo; imprime `PASS`/`FAIL` y termina con código 0 si todo pasa o 1 si algo falla. También se pueden ejecutar desde el editor (abrir el script → **Archivo → Ejecutar**) y leer el panel **Salida**.

## Estructura

| Ruta | Contenido |
|---|---|
| `scenes/` | Escenas de Godot (`main.tscn`) |
| `scripts/world/` | Datos del territorio en cuadrícula (`territory_grid.gd`), sistema nuevo |
| `scripts/data/` | Datos del mapa de provincias (legado) |
| `scripts/map/` | Dibujo y selección del mapa de provincias (legado) |
| `scripts/ui/` | Panel de información de provincias (legado) |
| `tests/` | Pruebas automáticas sin plugins |
| `assets/` | Aún no existe; se creará con el primer recurso |
| `docs/` | Documentación |

## Documentación

- [`docs/GDD.md`](docs/GDD.md): diseño del juego (confirmado, propuesto y abierto) y decisiones abiertas.
- [`docs/REDESIGN_PLAN.md`](docs/REDESIGN_PLAN.md): evaluación del código, enfoques técnicos del territorio pixelado, arquitectura recomendada y riesgos.
- [`docs/ROADMAP.md`](docs/ROADMAP.md): hitos en orden de dependencia con criterios medibles.
- [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md): pruebas existentes y necesidades futuras.
- [`CLAUDE.md`](CLAUDE.md): instrucciones persistentes para las sesiones de Claude Code.

## Proceso de desarrollo

- Hitos pequeños en el orden de `docs/ROADMAP.md`; cada uno se pide y se revisa por separado, y no empieza hasta que sus decisiones abiertas estén respondidas.
- Desarrollo en una rama aislada; nunca se trabaja directamente sobre `main`.
- La lógica del juego se separa de la interfaz para poder probarla de forma automática.
- Cada hito termina con un informe honesto de qué se probó y qué no.
- Documentación, comentarios y textos del juego en español; identificadores de código en inglés.
