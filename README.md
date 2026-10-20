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
- La población se reparte entre **trabajadores y soldados** con un control deslizante en el HUD (solo afecta a la población nueva); existe un **reclutamiento forzoso** (implementado como movilización progresiva, hito 7).
- Solo hay **dos recursos**: dinero (construcciones) y recursos (mantenimiento de trabajadores y soldados).
- Antes de atacar, el juego mostrará una previsión comprensible de ventaja y pérdidas.
- La mecánica diferenciadora definitiva, el modelo de ejércitos y muchos números siguen **sin decidir**. Ver `docs/GDD.md`.

## Estado real del proyecto

**Fase actual: construcción del sistema territorial nuevo. Hitos 3 (datos), 4 (vista pixelada e inspección), 5 (operación de conquista) y 5b (naciones y HUD) hechos: el propietario ejecutó en Godot 4.7.2 las cuatro suites (21 + 14 + 18 + 10 = 63 PASS) y comprobó que el clic en una celda muestra su información. Hito 6 (ciudades y economía básica) hecho: el propietario ejecutó sus 21 pruebas y comprobó que las ciudades aparecen y crecen. Hito 7 (población, trabajadores y mantenimiento) hecho: el propietario ejecutó sus 24 pruebas (en total 108 PASS en las seis suites). Hito 8 (organización militar: sectores y asignación de soldados) hecho: el propietario probó a mano la interfaz simplificada y confirmó que funciona (sus pruebas automáticas siguen sin confirmar). Hito 9 (ataques, combate determinista, invasiones progresivas, ocupación provisional y estado de guerra) implementado en la nube; el propietario ejecutó sus pruebas en Godot 4.7.2: 23 de 25 PASS (los dos fallos eran comparaciones de color demasiado estrictas en las propias pruebas). Hito 10 (guerra, diplomacia y jugabilidad simplificada: ataque en un paso, tratados de paz, treguas y pausa) implementado en la nube; sus pruebas están escritas pero sin ejecutar ni validar en Godot.**

**Sistema nuevo (hito 3):** `scripts/world/territory_grid.gd` guarda el territorio como una cuadrícula de 320x180 celdas (terreno agua/tierra y propietario por celda en dos `PackedByteArray`), con 4 naciones provisionales (jugador y 3 rivales) y un mapa inicial determinista: una masa de tierra con costa irregular, cuatro pequeños territorios conectados y tierra sin reclamar. Los valores de la cuadrícula son **provisionales**. Sus pruebas (`tests/test_territory_grid.gd`) fueron ejecutadas a mano por el propietario en Godot 4.7.2: 21 PASS, 0 FAIL.

**Hito 4 (implementado; sin validar en Godot):** `scripts/world/territory_map_view.gd` dibuja la cuadrícula en una `Image`/`ImageTexture` (1 píxel = 1 celda, filtro `nearest`, escala 3 → 960x540 centrada en 1280x720). Agua azul oscura, tierra sin reclamar gris, cuatro naciones de colores distintos y fronteras de 1 celda derivadas de la propiedad real de las celdas. Al pasar el ratón por tierra se resalta la celda; el clic izquierdo la selecciona y un panel compacto muestra coordenadas, terreno y propietario. Es solo inspección: no se puede cambiar ningún propietario. **F5 abre ahora esta escena** (`scenes/territory_main.tscn`, ver `project.godot`). Las pruebas del hito 4 (`tests/test_territory_map_view.gd`) están escritas pero **no se han ejecutado en Godot** (no hay Godot en la nube).

**Prototipo anterior de provincias (legado)**, intacto (sigue en `scenes/main.tscn`, que ya no es la escena principal; ábrelo y pulsa F6 para verlo):
- Pantalla inicial con el título y mapa estático de 14 provincias (7 del jugador, 7 del enemigo).
- Clic izquierdo para seleccionar una provincia y panel con su nombre, propietario y vecinas.
- El propietario validó a mano en Godot 4.7.2 la pantalla inicial, el mapa y la selección.
- Existen pruebas automáticas (`tests/`), pero **no están confirmadas como ejecutadas** en Godot.

Este prototipo **no se amplía**: no hay tropas, combate, captura, economía, ciudades ni IA. Se mantiene intacto y solo se retirará cuando el nuevo mapa visual y su interacción hayan sido validados manualmente en el PC del propietario.

**Hito 5 (implementado; pruebas sin ejecutar):** `TerritoryGrid.conquer_cells(attacker_id, cells)` cambia el propietario de un conjunto concreto de celdas de tierra solo si toda la operación es válida (nación existente, celdas dentro del mapa, sin repetidas ni agua ni propias, zona contigua y en contacto con el territorio del atacante); si no, no cambia nada y devuelve el motivo. El territorio solo cambia por una conquista explícita. **No hay todavía combate ni forma de lanzarla desde el juego**, así que F5 se ve igual que en el hito 4. Tras una conquista, la vista se refresca con `refresh_cell` sobre las celdas devueltas. Pruebas: `tests/test_territory_conquest.gd`.

**Hito 5b (implementado; pruebas sin ejecutar):** la leyenda de debajo del mapa muestra, por nación, las **celdas de tierra que controla y su porcentaje de la tierra total** (agua excluida; la tierra sin reclamar tiene su fila), y una etiqueta arriba a la derecha resume la nación del jugador (Confederación de Alba). Las cifras se calculan desde `TerritoryGrid` (`count_land_by_owner`) y se recalculan cuando la cuadrícula emite `ownership_changed`; son estadísticas de territorio, no de población, poder ni economía. Pruebas: `tests/test_territory_hud.gd`.

**Hito 6 (hecho; 21 PASS ejecutadas por el propietario):** cada nación empieza con una ciudad de nivel 1 y 50 de dinero. El botón **«Fundar ciudad»** (izquierda) activa un modo en el que el clic en tu territorio funda una ciudad (cuesta 100, distancia mínima de 9 celdas a cualquier ciudad; `Esc` cancela). Las ciudades crecen con el tiempo y suben de nivel (1–4) como una mancha de píxeles dentro de su territorio —**sin cambiar nunca el territorio**— y producen dinero y recursos. Arriba a la derecha se ve el dinero y los recursos del jugador con su ingreso por segundo; al seleccionar una ciudad, el panel inferior muestra propietario, nivel, producción y crecimiento. Todos los valores de equilibrio son **provisionales** y están en `scripts/data/economy_balance.gd`. Pruebas: `tests/test_city_economy.gd`. Pendiente: la fundación de ciudades es instantánea (el breve tiempo de fundación del diseño no está implementado).

**Hito 7 (hecho; 24 PASS ejecutadas por el propietario en Godot 4.7.2; el aspecto del panel no se ha registrado como validado):** cada nación tiene una población de **trabajadores y soldados** (36 al empezar: 30 y 6) que crece a través de sus ciudades hasta una capacidad que depende de su nivel. A la derecha del mapa, el panel «Población» muestra el resumen del jugador y permite: elegir qué porcentaje de la **población nueva** va a trabajadores y soldados (no reasigna a los existentes), **movilizar** un porcentaje de los trabajadores (se convierten en soldados durante 30 s, con progreso visible) y elegir qué grupo **cobra primero** el mantenimiento (economía o ejército). Trabajadores y soldados consumen **recursos** cada segundo; si no alcanzan, no hay crecimiento y, pasados unos segundos, el grupo sin pagar pierde un 1 % por segundo hasta saldar la deuda; el HUD lo avisa. Al seleccionar una ciudad propia, una casilla activa su **prioridad de población** (el doble de crecimiento de población en esa ciudad). Nada de esto cambia el territorio ni los niveles: las fronteras solo cambian por conquista. Los soldados son una cifra nacional; la producción de las ciudades aún no depende de los trabajadores. Valores **provisionales** en `scripts/data/population_balance.gd`. Pruebas: `tests/test_population.gd`.

**Hito 8 (implementado; pruebas sin ejecutar ni validar en Godot; la interfaz de crear sectores descrita aquí fue SUSTITUIDA en el hito 10 por el flujo «Atacar», ver abajo; el modelo de sectores sigue siendo el detalle interno de los frentes):** a la izquierda del mapa, el panel «EJÉRCITO» muestra los **soldados totales, asignados y disponibles** del jugador. Para **crear un sector militar**: se selecciona una celda propia en el mapa, se elige una dirección (N/E/S/O), se fija con **un deslizador** cuántos soldados asignar (como máximo los disponibles) y se pulsa «Crear sector y asignar». El objetivo (la celda contigua en esa dirección) debe ser tierra sin reclamar o de otra nación, nunca propia. Se pueden crear varios sectores en distintos puntos de una misma frontera; al elegir uno de la lista se cambia su cantidad con el mismo tipo de deslizador y «Aplicar», o se **liberan sus soldados eliminando el sector**. Los soldados asignados siguen siendo parte de la población militar (no se crean ni se pierden al asignar) y los sectores no cuestan dinero ni recursos. En el mapa cada sector es un marcador discreto (origen, línea con flecha al objetivo y cifra). **Crear sectores no inicia ninguna guerra ni cambia fronteras.** Pruebas: `tests/test_military.gd`.

**Hito 9 (implementado; 23 de 25 pruebas PASS ejecutadas por el propietario; la interfaz con los botones «Confirmar ataque» y «Detener ataque» descrita aquí fue SUSTITUIDA en el hito 10, ver abajo):** al elegir un sector en el panel «EJÉRCITO» aparecía el bloque **«ATAQUE»**: estado (preparado, atacando o detenido y por qué), una **previsión** del siguiente avance (atacantes, defensa local estimada, relación de fuerzas, ventaja atacante / equilibrado / defensa superior, resultado previsto y bajas aproximadas; es una regla determinista, no una probabilidad) y los botones **«Confirmar ataque»** y **«Detener ataque»**. Una ofensiva usa los soldados asignados al sector y avanza **una celda cada 3 s** en la dirección del sector, desde el origen, hasta que se detiene (agua, borde del mapa, sin soldados, derrota o orden del jugador). Los combates son deterministas: la defensa de un punto es un fondo común de soldados reales del defensor repartido entre sus tramos de frontera, y las bajas son reales (restan del sector y de la población; los trabajadores no se tocan). En **tierra sin reclamar** la ofensiva la conquista celda a celda con la operación explícita de conquista; en **tierra de otra nación** solo la **ocupa**: el propietario oficial no cambia y la celda se ve en **tablero** con el color claro del ocupante. Atacar territorio de otra nación inicia un **estado de guerra** (provisional; se termina con un tratado desde el hito 10). El ocupante no cobra nada, no se funda sobre celdas ocupadas y una ciudad con el centro ocupado suspende su producción. Valores **provisionales** en `scripts/data/combat_balance.gd`; reglas y fórmulas en `docs/GDD.md`. Pruebas: `tests/test_combat.gd`. El panel militar tiene ahora barra de desplazamiento (el aspecto no está pulido). Con el mapa inicial las naciones empiezan separadas: para llegar a otra hay que conquistar tierra libre.

**Hito 10 (implementado; pruebas sin ejecutar ni validar en Godot):**
- **Ataque en un paso.** Ya no se crean «sectores». Pulsa en el mapa tu frontera o directamente la celda enemiga o libre que quieres atacar (el origen propio contiguo y la dirección se deducen), elige cuántos soldados con el deslizador o con **25 / 50 / 75 / 100 %**, mira la previsión (atacantes, defensa local estimada, «Ventaja atacante» / «Combate equilibrado» / «Defensa superior», qué pasa si vences, bajas aproximadas; es una regla determinista, no una probabilidad) y pulsa el único botón principal: **«Atacar»** (si no hay ofensiva), **«Detener»** (si está activa) o **«Continuar»** (si está detenida). El juego crea o reutiliza el frente interno y lanza la ofensiva en una sola operación: una orden inválida no gasta soldados ni deja nada a medias. Con un frente existente: «Ajustar a N» (refuerza o reduce) y «Retirar frente» (los soldados vuelven a la reserva). Se puede atacar desde varios puntos de una misma frontera.
- **Diplomacia.** Con una guerra abierta aparece el panel **«DIPLOMACIA»**: estado de la guerra (duración, celdas ocupadas por cada bando, bajas), tipo de paz (**paz con conquistas**: cada parte se queda lo que ocupa; **paz blanca**: se liberan las ocupaciones y nada cambia de dueño), quién paga y cuánto dinero (opcional) y «Proponer paz». La IA responde con una puntuación determinista: acepta, rechaza (con el motivo) o contraoferta (que aceptas o rechazas). Una IA cansada o que va perdiendo también te propone la paz sola (sin repetirse). El tratado se aplica de forma atómica (si el pago no es posible, no cambia nada) y empieza una **tregua de 60 s** durante la que ninguna de las dos naciones puede atacar a la otra (lo impone la lógica militar, no solo la interfaz). El panel muestra el tiempo que falta.
- **Pausa.** Botón **«Pausa»** (o barra espaciadora) arriba a la izquierda: detiene a la vez ciudades, población, producción, movilizaciones, ofensivas, guerras, treguas y propuestas de la IA. La interfaz sigue respondiendo; en pausa no se funda ni se negocia, pero se puede planificar un ataque (empieza al reanudar). Solo modo individual.
- **Pruebas del hito 9 corregidas.** Los dos fallos eran comparaciones con `==` entre un color float y un píxel `RGBA8` (8 bits por canal, truncado); ahora se compara con tolerancia de 1/255 y se siguen detectando colores incorrectos. El juego no tenía ese defecto. Valores **provisionales** en `scripts/data/diplomacy_balance.gd`; reglas y fórmulas en `docs/GDD.md`. Pruebas: `tests/test_diplomacy.gd` (19), más las pruebas de interfaz de `test_combat.gd` y `test_military.gd`, reescritas para el flujo nuevo.

No existen todavía declaración formal de guerra, rendición, alianzas, IA estratégica, rotura de tregua, defensa activa, selección de zona con flecha, control de velocidad ni expansión automática de fronteras (descartada). Siguiente paso recomendado: ejecutar en Godot las pruebas del hito 10 (y repetir las anteriores), probar a mano el bucle de guerra (conquistar tierra libre hasta tocar a otra nación, atacar, negociar la paz) y ajustar los valores provisionales. Ver `docs/ROADMAP.md`.

## Cómo abrir el proyecto

1. Instala Godot 4.7 (versión estándar, no .NET).
2. Clona este repositorio o descárgalo.
3. En el gestor de proyectos de Godot pulsa **Importar** y elige `project.godot`.
4. Pulsa **F5**. Aparece el mapa pixelado de territorio del hito 4. (Para ver el prototipo de provincias, abre `scenes/main.tscn` y pulsa F6.)

La primera vez Godot genera la carpeta `.godot/` (caché local, ignorada por git).

## Pruebas automáticas

Desde la raíz del proyecto (sustituye `godot` por la ruta de tu ejecutable de Godot 4.7):

```
godot --headless --path . --script res://tests/test_territory_grid.gd
godot --headless --path . --script res://tests/test_territory_map_view.gd
godot --headless --path . --script res://tests/test_territory_conquest.gd
godot --headless --path . --script res://tests/test_territory_hud.gd
godot --headless --path . --script res://tests/test_city_economy.gd
godot --headless --path . --script res://tests/test_population.gd
godot --headless --path . --script res://tests/test_military.gd
godot --headless --path . --script res://tests/test_combat.gd
godot --headless --path . --script res://tests/test_diplomacy.gd
godot --headless --path . --script res://tests/test_province_data.gd
godot --headless --path . --script res://tests/test_province_selection.gd
```

Cada comando ejecuta un archivo; imprime `PASS`/`FAIL` y termina con código 0 si todo pasa o 1 si algo falla. También se pueden ejecutar desde el editor (abrir el script → **Archivo → Ejecutar**) y leer el panel **Salida**.

## Estructura

| Ruta | Contenido |
|---|---|
| `scenes/` | Escenas de Godot: `territory_main.tscn` (principal, hito 4) y `main.tscn` (prototipo de provincias, legado) |
| `scripts/world/` | Datos del territorio en cuadrícula (`territory_grid.gd`) y su vista pixelada (`territory_map_view.gd`); ciudades (`city_manager.gd`, `city_layer_view.gd`) y saldos (`economy.gd`) del hito 6; población, movilización y mantenimiento (`population.gd`, hito 7); sectores militares y asignación de soldados (`military.gd`, `sector_layer_view.gd`, hito 8); ataques, combate, ocupación y guerra (`offensives.gd`, `combat.gd`, `occupation.gd`, `war_state.gd`, hito 9; ataque en un paso, registro por guerra y treguas, hito 10); diplomacia y tratados de paz (`diplomacy.gd`, hito 10); el reloj único con pausa vive en `city_manager.gd` |
| `scripts/data/` | Valores de equilibrio de ciudades y economía (`economy_balance.gd`), de población y mantenimiento (`population_balance.gd`), de combate (`combat_balance.gd`) y de diplomacia y treguas (`diplomacy_balance.gd`); datos del mapa de provincias (legado) |
| `scripts/map/` | Dibujo y selección del mapa de provincias (legado) |
| `scripts/ui/` | Pantalla, panel de información y leyenda del hito 4 (`territory_*.gd`); panel de población del hito 7 (`population_panel.gd`); panel de ataque (`military_panel.gd`, reescrito en el hito 10) y panel de diplomacia (`diplomacy_panel.gd`, hito 10); panel de provincias (legado) |
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
