# CLAUDE.md — Instrucciones persistentes para Claude Code

## Proyecto

**Fronteras de Hierro**: juego 2D de estrategia territorial en tiempo real, fácil de aprender y de jugar, muy cercano a la experiencia general de OpenFront, con mecánicas propias y algo más de profundidad, sin ser un RTS táctico complejo. Godot 4.7, GDScript, Windows PC, pixel art, mapa cenital.
Inspirado en conceptos generales de OpenFront, **sin copiar** sus mapas, recursos, código, nombres, interfaz ni contenido protegido.

El propietario es **principiante**: toma decisiones técnicas sólidas, explica las importantes con claridad y no amplíes el alcance sin aprobación.

## Idioma

- Toda la documentación, comentarios de código, mensajes de commit, textos del juego e informes finales: **en español**.
- Identificadores de código (variables, funciones, clases, señales): **inglés** (`snake_case` en GDScript).

## Estado de la dirección del proyecto

El concepto cambió. El prototipo basado en **provincias** (hitos 0–2) es **legado**:
- **No se amplía** con nuevas mecánicas de provincias (ni combate, ni captura, ni IA, ni economía sobre provincias).
- **No se elimina** hasta que el nuevo mapa visual y su interacción hayan sido validados manualmente en el PC del propietario y este lo ordene.
- Estado del sustituto: el hito 3 creó la lógica de datos del territorio (`scripts/world/territory_grid.gd`) y el hito 4 su vista pixelada con resaltado y selección (`scripts/world/territory_map_view.gd`, escena principal `scenes/territory_main.tscn`). El hito 5 añadió `TerritoryGrid.conquer_cells` (conquista atómica y validada; es la vía del juego para cambiar propietarios) y `load_from_data`. La regla permanente: el territorio solo cambia de propietario por una conquista explícita. El hito 5b añadió la leyenda con celdas y porcentaje de tierra por nación (`scripts/ui/territory_legend.gd`, derivados de `TerritoryGrid.count_land_by_owner`), el resumen del jugador, el campo `controller` en `NATIONS` y la señal `ownership_changed`. **El propietario ejecutó en Godot 4.7.2 las cuatro suites de los hitos 3–5b (21 + 14 + 18 + 10 = 63 PASS) y comprobó que el clic en una celda muestra su información** (validación del propietario, no de Claude). El **hito 6** (ciudades y economía básica) añadió `scripts/world/city_manager.gd` (ciudades: el propietario se deriva de la celda central en la cuadrícula; fundación, crecimiento por ticks, producción), `scripts/world/economy.gd` (dinero y recursos por nación, nunca negativos), `scripts/world/city_layer_view.gd` (dibujo) y `scripts/data/economy_balance.gd` (todas las constantes de equilibrio, provisionales); sus 21 pruebas (`tests/city_economy_tests.gd`) las ejecutó el propietario en Godot 4.7.2 (21 PASS, tras corregir una posición inválida en la prueba de fundación), y el propietario comprobó que las ciudades iniciales aparecen y crecen visualmente. Pendiente registrado: la fundación es instantánea (el tiempo de fundación confirmado no está implementado). El **hito 7** (población, trabajadores y mantenimiento) añadió `scripts/world/population.gd` (población nacional de trabajadores y soldados generada por las ciudades, reparto de la población nueva, prioridad de crecimiento por ciudad, movilización progresiva y mantenimiento con déficit gradual), `scripts/data/population_balance.gd` (constantes provisionales), `scripts/ui/population_panel.gd` (HUD), `Economy.spend_resources` y la señal `CityManager.ticked` (reloj único); sus 24 pruebas (`tests/population_tests.gd`) las ejecutó el propietario en Godot 4.7.2 (24 PASS; las seis suites suman 108 PASS). El **hito 8** (organización militar) añadió `scripts/world/military.gd` (sectores de despliegue: origen propio, dirección ortogonal, celda objetivo contigua —tierra sin reclamar o de otra nación, nunca propia— y soldados asignados, creados y asignados en una sola operación atómica con un panel de un deslizador; los soldados totales salen siempre de `Population`, la reserva es total − asignados; no cambia fronteras ni crea combate), `scripts/ui/military_panel.gd` (HUD) y `scripts/world/sector_layer_view.gd` (marcadores); sus pruebas (`tests/military_tests.gd`) **no se han ejecutado en Godot**, aunque **el propietario probó a mano la interfaz simplificada y confirmó que funciona**. El **hito 9** (ataques, combate determinista, invasiones progresivas, ocupación provisional y estado de guerra) añadió `scripts/world/offensives.gd` (ofensivas sobre los sectores: avance de una celda por intervalo, previsión, bajas reales), `scripts/world/combat.gd` (fórmulas puras), `scripts/data/combat_balance.gd` (constantes provisionales), `scripts/world/occupation.gd` (ocupación **separada** de la propiedad: vencer en tierra de otra nación la ocupa sin cambiar su propietario) y `scripts/world/war_state.gd` (guerras explícitas); una ofensiva **conquista con `conquer_cells` solo la tierra sin reclamar** (decisión provisional D22, centralizada en `Offensives`); sus pruebas (`tests/combat_tests.gd`) **no se han ejecutado en Godot**. La secuencia de hitos cambió: la simulación/expansión (antiguo hito 7) queda pendiente de redefinición y **la expansión territorial automática está descartada**; los antiguos hitos 8 y 11 quedaron absorbidos por el 7 (ver `docs/ROADMAP.md`).
- La nueva hoja de ruta está en `docs/ROADMAP.md`; el análisis técnico en `docs/REDESIGN_PLAN.md`.

## Dirección de diseño permanente (confirmada por el propietario)

**Presentación**
- CLEAN, minimalista y legible. El mapa es el elemento principal.
- Territorio y fronteras pixelados, con un aspecto parecido al de OpenFront.
- Las fronteras **no** dividen el territorio en provincias seleccionables: cada nación es un territorio continuo formado por celdas o elementos territoriales.
- Puede haber varias naciones en el mapa.
- Las ciudades se muestran como agrupaciones de píxeles que crecen visualmente.
- Marcadores y controles sencillos; nunca cientos de soldados individuales; sin interfaces recargadas, exceso de animaciones ni microgestión innecesaria.

**Ciudades y población**
- El jugador funda una ciudad haciendo clic en una ubicación válida de su propio territorio; cuesta dinero y tarda un breve tiempo en fundarse. Condiciones, coste y tiempo exactos: sin definir.
- Una ciudad empieza ocupando muy poca superficie (unos pocos píxeles o celdas).
- Crece visualmente desde su centro con el tiempo según la población trabajadora asignada. El crecimiento se ralentiza al aumentar el tamaño, para evitar una única superficie urbana enorme.
- Al alcanzar umbrales sube de nivel automáticamente; tras subir, su expansión visual sigue siendo posible pero más lenta.
- Población dividida en **trabajadores** y **soldados**. Un control deslizante del HUD fija qué porcentaje de la **nueva** población va a cada grupo; cambiarlo **no reasigna** la población existente.
- El jugador puede activar una **prioridad de población** en una ciudad para favorecer su crecimiento poblacional (efecto y coste sin definir).
- Opción de **reclutamiento forzoso**: convierte un porcentaje de los trabajadores existentes en soldados durante un plazo corto, no instantáneamente.
- Cantidades, costes y equilibrio: sin definir.

**Recursos: solo dos**
1. **Dinero**: se genera en las ciudades; financia construcciones.
2. **Recursos**: se generan en las ciudades; mantienen a trabajadores y soldados.
- Prohibido añadir comida, combustible, munición, energía, materiales u otros recursos.

**Combate y ejércitos**
- El jugador debe poder entender fácilmente si tiene ventaja antes de atacar: comparación de fuerzas clara y, cuando se defina el combate, previsión comprensible de probabilidades de victoria y pérdidas estimadas.
- Los ejércitos se representan inicialmente mediante una **cifra de soldados**; no hay regimientos ni soldados individuales simulados uno a uno. Dónde se guarda esa cifra (por nación, ciudad, zona de ataque…) sigue **pendiente de decisión**.
- En el futuro el jugador podrá concentrar un ataque en una zona concreta del mapa, con una flecha de dirección opcional (no implementado; método de selección sin definir).

**Mecánica diferenciadora**
- Las ciudades, el crecimiento urbano y la gestión sencilla de la población **podrían** ser parte de la identidad del juego. **No** presentarlo como decisión definitiva: la decide el propietario tras valorar alternativas.

## Alcance

- La fuente de verdad del alcance es `docs/GDD.md` (diseño) y `docs/ROADMAP.md` (orden de hitos). Las decisiones abiertas están numeradas (D1, D2…) en el GDD.
- Trabaja **solo en el hito que se pida**. No empieces el siguiente automáticamente.
- **No inventes respuestas a decisiones abiertas.** Si un hito depende de una, pregunta o detente.
- Cada sistema (ciudades, población, recursos, ejércitos, combate, IA, expansión) se implementa solo cuando su hito lo indique y se pida expresamente.
- Prohibido sin aprobación expresa: multijugador, guardado de partida, nuevos plugins, nuevos autoloads, nuevas dependencias, recursos económicos distintos de los dos confirmados.
- Si una tarea exige ampliar el alcance, **pregunta antes**.
- No descargues arte ni instales software ajeno al proyecto.

## Arquitectura

- Simple y nativa de Godot: escenas + scripts GDScript con tipado estático (`var x: int`, `func f() -> void`). Cuidado con `:=` cuando el valor es `Variant` (da error): declara el tipo explícitamente.
- **Separar lógica y presentación**: las reglas viven en scripts sin dependencia de nodos visuales (`RefCounted`/`Resource`) para poder probarlas sin interfaz. La presentación lee el estado; las órdenes del jugador llegan como llamadas a la lógica.
- **Capas conceptuales separadas** (ver `docs/REDESIGN_PLAN.md` §6): territorio, ciudades, población, recursos y ejército. El territorio no conoce las ciudades; el crecimiento urbano no debe confundirse con la expansión de fronteras.
- Territorio como **cuadrícula de celdas**, no como polígonos de provincias. Valores provisionales ya implementados en el hito 3 (propuestas técnicas, no preferencias confirmadas): 320x180 celdas, dos `PackedByteArray` (terreno y propietario) con índice `y * 320 + x`, terreno agua/tierra, propietarios `OWNER_NONE`…`OWNER_AI_3`, representación visual futura con `Image`/`ImageTexture` y filtro `nearest`.
- El propietario de una celda de agua es siempre `OWNER_NONE`. Los datos de cada celda viven solo en `TerritoryGrid`; nunca se duplican en otro sistema.
- Las fronteras no se almacenan: surgen de la diferencia de propietario entre celdas adyacentes.
- Simulación **determinista** y por pasos fijos (ticks). Si hay azar, con semilla inyectable. El combate debe ser comprobable (el del hito 9 es determinista, sin azar).
- **Ocupación ≠ propiedad:** la ocupación militar vive en `Occupation`, nunca en `TerritoryGrid`, y no cambia el propietario oficial; solo una conquista explícita (`conquer_cells`) lo cambia. Las ciudades, la economía y la población nunca mueven fronteras ni convierten una ocupación en propiedad.
- Datos declarativos (recurso o archivo de datos) para lo que sea contenido, no disperso en código.
- Comunicación entre nodos con **señales**; evita rutas de nodo frágiles.
- Sin autoloads, plugins, `class_name` innecesarios ni abstracciones "por si acaso". Se usa `preload()` en lugar de `class_name` para que las pruebas headless funcionen sin abrir el editor.
- Estructura: `scenes/`, `scripts/`, `tests/`, `docs/`, `assets/`. No crear carpetas vacías ni módulos sin uso inmediato.
- Ventana base 1280x720, stretch `canvas_items`, renderizador Compatibility, filtro de texturas `nearest`.
- Controles de UI: los nodos que no deban capturar clics usan `mouse_filter = Ignore`; los paneles de interfaz capturan el clic para no seleccionar el mapa por error.

## Pruebas

- Cada regla de juego nueva lleva pruebas automáticas, salvo que no sea viable (y se justifique en el informe).
- Pruebas propias, sin plugins: scripts `SceneTree` en `tests/`, ejecutables con `godot --headless --path . --script res://tests/<archivo>.gd`; imprimen PASS/FAIL y salen con código ≠ 0 si algo falla.
- Pruebas del territorio: comprobaciones en `tests/territory_grid_tests.gd`; ejecutor headless `tests/test_territory_grid.gd`; ejecutor visual en el editor (abrir `tests/run_territory_tests.tscn` y pulsar F6). Pruebas de naciones y HUD (hito 5b): `tests/territory_hud_tests.gd`, `tests/test_territory_hud.gd`, `tests/run_hud_tests.tscn`. Pruebas de conquista (hito 5): `tests/territory_conquest_tests.gd`, `tests/test_territory_conquest.gd`, `tests/run_conquest_tests.tscn`. Pruebas de la vista (hito 4): `tests/territory_map_view_tests.gd`, ejecutor headless `tests/test_territory_map_view.gd`, escena F6 `tests/run_view_tests.tscn`. Pruebas de ciudades y economía (hito 6): `tests/city_economy_tests.gd`, `tests/test_city_economy.gd`, `tests/run_city_tests.tscn`. Pruebas de población y mantenimiento (hito 7): `tests/population_tests.gd`, `tests/test_population.gd`, `tests/run_population_tests.tscn`. Pruebas de organización militar (hito 8): `tests/military_tests.gd`, `tests/test_military.gd`, `tests/run_military_tests.tscn`. Pruebas de ataques, combate y ocupación (hito 9): `tests/combat_tests.gd`, `tests/test_combat.gd`, `tests/run_combat_tests.tscn`. Pruebas del prototipo de provincias (legado): `tests/test_province_data.gd`, `tests/test_province_selection.gd`.
- Plan y casos en `docs/TEST_PLAN.md`; actualízalo en cada hito sin fingir que existen mecánicas que no existen.
- Si hay ejecutable de Godot en el entorno, valida con `godot --headless --path . --quit` y ejecuta las pruebas. Si no lo hay, **no lo instales**: haz comprobaciones estáticas e informa de lo no verificado.
- **Nunca afirmes** que el juego o las pruebas se han ejecutado, ni que algo se ve bien, si no ocurrió. Informa de los resultados reales, incluidos los fallos.
- Estado conocido: el propietario validó a mano en Godot 4.7.2 la pantalla inicial, el mapa y la selección de provincias, y ejecutó las suites de los hitos 3, 4, 5 y 5b (21, 14, 18 y 10 PASS). El propietario también ejecutó las 21 pruebas del hito 6 y las 24 del hito 7. Las del hito 8, las del hito 9 y las del prototipo de provincias **no** están confirmadas como ejecutadas en Godot.
- No se desactivan ni se saltan pruebas para que pasen.

## Flujo de trabajo

- Desarrolla solo en la rama que asigne la sesión. **Nunca fusiones ni empujes a `main`.** No crees pull requests salvo petición expresa. Nunca fuerces un push.
- Commits pequeños y descriptivos.
- Edita solo lo necesario para el hito; no refactorices por gusto.
- No despliegues ni publiques el juego.
- No afirmes conocer costes ni crédito restante salvo que el dato esté disponible.
- Cuando edites código, indica qué archivos cambiaron para que el propietario los actualice en su copia local.
- Al terminar, informe en español: archivos modificados, decisiones, pruebas ejecutadas y resultados, lo no verificado, decisiones que requieren revisión humana y siguiente hito recomendado.
- Mantén README, GDD, ROADMAP, TEST_PLAN y REDESIGN_PLAN coherentes entre sí; el README debe reflejar solo lo realmente implementado.
