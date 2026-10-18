# Hoja de ruta — Fronteras de Hierro

Cada hito se pide y se revisa por separado. El orden respeta las dependencias técnicas y de diseño. Las decisiones abiertas (D1, D2…) están en `docs/GDD.md` §12 y el análisis técnico en `docs/REDESIGN_PLAN.md`.

> **El concepto cambió.** La arquitectura basada en **provincias** (hitos 0–2) es un **prototipo anterior (legado)**. **No debe ampliarse con nuevas mecánicas de provincias.** Los antiguos hitos 3–7 (combate, captura, IA y victoria sobre provincias) quedan **descartados**. El código antiguo se mantiene intacto mientras se construye el sistema nuevo; se retirará solo cuando el nuevo mapa visual y su interacción hayan sido validados manualmente en el PC del propietario (D16).

## Estado

| Hito | Nombre | Estado |
|---|---|---|
| 0 | Cimientos | Hecho; validado a mano por el propietario (Godot 4.7.2, Windows) |
| 1 | Mapa estático de provincias (legado) | Hecho; validado a mano visualmente |
| 2 | Selección e información de provincias (legado) | Hecho; validado a mano; pruebas automáticas sin confirmar |
| R | Rediseño: documentación y planificación | Hecho (este cambio; sin código) |
| 3 | Datos del territorio (cuadrícula) | Hecho; 21 PASS, 0 FAIL ejecutadas por el propietario en Godot 4.7.2 |
| 4 | Vista pixelada del territorio | Hecho; 14 PASS ejecutadas por el propietario en Godot 4.7.2; el propietario comprobó que el clic en una celda muestra su información (el aspecto general no se ha registrado como validado) |
| 5 | Fundamentos de la conquista territorial (operación `conquer_cells`) | Hecho; 18 PASS ejecutadas por el propietario en Godot 4.7.2 |
| 5b | Naciones y HUD base (antes «hito 5») | Hecho; 10 PASS ejecutadas por el propietario en Godot 4.7.2 (la validación visual detallada de la leyenda no se ha registrado) |
| 6 | **Ciudades y economía básica** (ciudades iniciales, fundación, crecimiento por niveles, dinero y recursos) | Hecho; 21 PASS ejecutadas por el propietario en Godot 4.7.2 (tras corregir una posición inválida en una prueba); el propietario comprobó que las ciudades iniciales aparecen y crecen visualmente y le gusta la dirección visual. Pendiente: fundación instantánea (ver «Pendientes registrados») |
| 7 | **Población, trabajadores y mantenimiento** (población por nación generada por las ciudades, reparto de la población nueva, prioridad de crecimiento, movilización progresiva, mantenimiento con déficit gradual) | Implementado; pruebas escritas, **pendientes de ejecutar y validar en Godot** |
| — | Simulación por pasos con pausa y reloj global (antes «hito 7») | **Pendiente de redefinición.** La parte de **expansión territorial automática queda descartada** (contradice la regla de conquista); pausa y velocidad (D10) siguen abiertas |
| 8 | ~~Población, trabajadores y crecimiento urbano~~ | **Absorbido por el hito 7** (el crecimiento decreciente por tamaño y la relación nivel↔población, D6, siguen abiertos) |
| 9 | Construcciones y producción según trabajadores (el mantenimiento ya está en el hito 7) | Pendiente; requiere D14 |
| 10 | Ejércitos, ataques y previsión de combate | Pendiente; requiere D7, D8, D12, D18 |
| 11 | ~~Reclutamiento forzoso~~ | **Absorbido por el hito 7** como movilización progresiva (porcentaje elegible, duración y penalizaciones definitivas, D13, siguen abiertos) |
| 12 | IA enemiga | Pendiente |
| 13 | Victoria, derrota y reinicio | Pendiente; requiere D11 |
| 14 | Pulido y cierre del MVP | Pendiente |

## Hitos 0–2 — Prototipo de provincias (legado, completado)
- Proyecto Godot 4.7, escena de arranque, mapa de 14 provincias con selección y panel de información.
- Se reutilizan de él la configuración del proyecto, la estructura de carpetas, el patrón de pruebas y la separación datos/presentación (`docs/REDESIGN_PLAN.md` §2).
- **Pendiente de confirmar:** ejecución en Godot de `tests/test_province_data.gd` y `tests/test_province_selection.gd`.

## Hito R — Rediseño (documentación)
- Reescritura de GDD, ROADMAP, TEST_PLAN, README y CLAUDE.md; creación de `docs/REDESIGN_PLAN.md`.
- **Criterios:** los documentos son coherentes entre sí, distinguen confirmado/propuesto/abierto y no se modificó ningún script, escena ni prueba.

## Hito 3 — Datos del territorio (cuadrícula)
- Lógica pura (sin nodos, sin dibujo): `scripts/world/territory_grid.gd` con terreno y propietario por celda, naciones y mapa inicial determinista. Valores provisionales: 320x180, agua/tierra, 4 naciones.
- **Criterios (implementados; ejecución en Godot pendiente):**
  - El mapa mide 320x180 y los dos arrays tienen 57.600 elementos; conversión coordenadas ↔ índice correcta y límites rechazados.
  - Terreno solo agua/tierra; el agua nunca tiene propietario; no hay propietarios desconocidos.
  - 4 naciones con ID numérico, clave, nombre provisional y color contrastado.
  - Cada nación empieza con un territorio no vacío, conectado y separado de los demás; hay tierra sin reclamar y suficiente tierra y agua.
  - Dos instancias producen la misma configuración.
  - `try_set_owner` acepta casos válidos y rechaza nación inexistente, agua y coordenadas inválidas sin alterar el estado.
  - Pruebas automáticas en `tests/test_territory_grid.gd`.
- **Aplazado a otros hitos:** detección de fronteras (hito 4, cuando haya que dibujarlas) y comprobación reutilizable de continuidad del territorio (hito 7, con la expansión).

## Hito 4 — Vista pixelada del territorio
**Estado: implementado en la nube sin Godot; pendiente de pruebas y validación visual del propietario.** Se hizo una versión sin cámara (sin zoom ni desplazamiento): escala fija 3 (960x540) centrada en la ventana; D1 (cámara) sigue abierto. Incluye resaltado, selección y panel de información como herramientas de inspección; no se puede modificar el territorio. No se midió el tiempo de actualización (no hay Godot en la nube): sigue pendiente en el PC (ver `docs/REDESIGN_PLAN.md` §4).
- Dibujo del territorio con `Image`/`ImageTexture` escalada con filtro `nearest`; colores de nación y fronteras; conversión ratón → celda. La cámara (zoom y desplazamiento) se evalúa aquí (D1).
- **Criterios:**
  - El mapa de `TerritoryGrid` se ve pixelado, con fronteras derivadas de la diferencia de propietario entre celdas adyacentes, coherentes y sin provincias seleccionables (validación visual del propietario).
  - Existe una función `is_border` probada (una celda es de frontera si un vecino ortogonal tiene otro propietario o es agua).
  - Al cambiar el propietario de una celda solo se redibujan esa celda y sus vecinas (prueba automática sobre la imagen).
  - El clic sobre el mapa devuelve la celda correcta con el nodo movido o escalado (prueba automática).
  - Se mide el tiempo de actualización en el PC del propietario y se registra en la documentación.

## Hito 5 — Fundamentos de la conquista territorial
**Estado: implementado en la nube sin Godot; pruebas escritas, no ejecutadas.** Regla de diseño: el territorio solo cambia de propietario por una conquista explícita; nunca por el paso del tiempo, la economía, una ciudad ni por dibujar el mapa.
- `TerritoryGrid.conquer_cells(attacker_id, cells) -> Dictionary`: valida la operación completa y solo entonces cambia el propietario de las celdas pedidas. Si una celda es inválida no cambia ninguna. Rechaza: atacante inexistente, lista vacía o con elementos que no son `Vector2i`, coordenadas fuera del mapa, repetidas, agua, celdas ya del atacante, zona no contigua (vecinos ortogonales) y zona sin contacto ortogonal con el territorio del atacante. Devuelve `ok`, `changed`, `error`, `bad_index` y `changed_cells` (para que la vista haga `refresh_cell` solo de esas celdas).
- Acepta tierra de otra nación o sin reclamar. **No decide cuándo ni por qué** se conquista: autorización, combate, coste y resolución son de hitos posteriores (D3).
- Añade `load_from_data` para cargar mapas controlados en pruebas (y, más adelante, partidas guardadas).
- **Criterios:** pruebas C-01…C-18 (`tests/test_territory_conquest.gd`), ver `docs/TEST_PLAN.md`. Los tests de hitos anteriores no se tocan.
- **Fuera de alcance:** combate, bajas, ejércitos, dirección de ataque, economía, ciudades, expansión automática, IA, eliminación de naciones, otros terrenos, cámara.

## Hito 5b — Naciones y HUD base (antes numerado como hito 5)
**Estado: implementado en la nube sin Godot; pruebas escritas, no ejecutadas; validación visual pendiente.**
- Registro de naciones (id, clave, nombre, color y controlador `human`/`ai`, en `TerritoryGrid.NATIONS`; sin cambiar IDs, nombres ni colores) y HUD mínimo reutilizando la leyenda del hito 4.
- La leyenda muestra, por nación, **celdas de tierra controladas y porcentaje de la tierra total del mapa** (agua excluida; la tierra sin reclamar cuenta en el total y tiene su propia fila). Son estadísticas de territorio, no de población, poder ni economía. Una etiqueta arriba a la derecha resume la nación del jugador; su color lleva un recuadro blanco en la leyenda.
- Los datos salen de `TerritoryGrid.count_land_by_owner()` (una pasada sobre el mapa); no se guardan cifras aparte. `TerritoryGrid` emite `ownership_changed` al cambiar propietarios y la pantalla recalcula como mucho una vez por fotograma. El panel de celda seleccionada también se refresca.
- **Criterios:**
  - Cada nación tiene un territorio inicial continuo (ya cubierto por las pruebas del hito 3).
  - El HUD muestra el nombre de la nación del jugador y el tamaño de su territorio, leídos del estado (pruebas H-01…H-10).
  - Sin selección de provincias ni botones de acciones inexistentes.
- **Decisiones provisionales:** el porcentaje usa una decimal con coma; «controlador» provisional hasta decidir D2 (cuántas naciones y quién las controla).

## Hito 6 — Ciudades y economía básica
**Estado: hecho. El propietario ejecutó en Godot 4.7.2 las pruebas CE-01…CE-21 (21 PASS, después de corregir una posición inválida en la preparación de la prueba de fundación) y comprobó que las ciudades iniciales aparecen en el mapa y crecen visualmente; le gusta la dirección visual (sigue siendo un prototipo).** Pendiente registrado: la fundación es instantánea. Sustituye en la secuencia al antiguo «hito 6» (simulación y expansión), que pasa al hito 7, y absorbe el antiguo «hito 7» (ciudades) y la parte básica del hito 9 (los dos recursos). La decisión de diseño más reciente del propietario es empezar por ciudades y economía.
- **Ciudades** (`scripts/world/city_manager.gd`): id estable, centro en coordenadas de celda, nivel (1–4) y progreso de crecimiento. El propietario **no se guarda**: es el de la celda central en `TerritoryGrid`, así que cambia solo si esa celda se conquista y nunca puede desincronizarse. Una ciudad sin propietario queda inactiva (no se destruye).
- **Ciudades iniciales:** una de nivel 1 por nación con territorio, en el punto central de su territorio inicial (o, si no sirve, la primera celda válida de una búsqueda determinista por anillos). No son capitales ni tienen bonificaciones.
- **Fundación:** botón «Fundar ciudad» + clic en el mapa; `Esc` o el botón cancelan. Reglas: dentro del mapa, tierra, del jugador, sin ciudad ahí, distancia mínima (Chebyshev) a cualquier ciudad y dinero suficiente. Solo se cobra si todo se cumple; si no, mensaje breve y el modo sigue activo. La fundación es **inmediata**: el «breve tiempo de fundación» confirmado en el GDD **no está implementado** y sigue pendiente (ver «Pendientes registrados»).
- **Crecimiento:** por ticks fijos de tiempo de juego; al alcanzar un umbral (cada vez mayor) sube de nivel. Se dibuja como una mancha de píxeles (rombo) claros del color de la nación, siempre dentro de su territorio, en una capa aparte (`city_layer_view.gd`). Crecer **nunca** cambia propietarios.
- **Economía** (`scripts/world/economy.gd`): dinero y recursos por nación (solo esos dos; saldos enteros no negativos). Cada ciudad activa produce según su nivel en cada tick. El HUD muestra el dinero y los recursos del jugador con su ingreso por segundo; el panel de información muestra propietario, nivel, producción y crecimiento de la ciudad seleccionada.
- **Valores de equilibrio:** todos en `scripts/data/economy_balance.gd` y **provisionales** (ver `docs/GDD.md`).
- **Criterios:** pruebas CE-01…CE-21 (`tests/test_city_economy.gd`, ver `docs/TEST_PLAN.md`); las cuatro suites anteriores siguen presentes y sin cambios.
- **Fuera de alcance en ese hito (los cuatro primeros pasan al hito 7):** población, trabajadores y soldados, prioridad de población, reclutamiento, mantenimiento; siguen fuera: ejércitos, combate, ocupación, tratados, IA económica, otros terrenos, cámara y multijugador. Tampoco hay **expansión territorial automática**: el territorio solo cambia por `conquer_cells`.

## Hito 7 — Población, trabajadores y mantenimiento
**Estado: implementado en la nube sin Godot; pruebas escritas, no ejecutadas; validación local pendiente.** Sustituye en la secuencia al antiguo «hito 7» (simulación y expansión) y absorbe el antiguo hito 8 (población), la parte de mantenimiento del antiguo hito 9 y el antiguo hito 11 (reclutamiento forzoso, como movilización progresiva). Detalle del modelo y de las reglas: `docs/GDD.md`, «Población, movilización y mantenimiento (hito 7)».
- **Población por nación** (`scripts/world/population.gd`): solo se guardan trabajadores y soldados de cada nación; total, disponibles, capacidad y crecimiento se derivan. Las ciudades no guardan población: contribuyen según su nivel al crecimiento y a la capacidad de su propietario (que sigue siendo el de la celda central en `TerritoryGrid`).
- **Población nueva** a través de las ciudades (crecimiento por tick con fracciones acumuladas, tope de capacidad), repartida entre trabajadores y soldados según un porcentaje (control en el HUD) que **solo afecta a la población nueva**; el resto del reparto se acumula, así que no se pierde ni se duplica a nadie.
- **Prioridad de crecimiento** por ciudad (casilla en el panel de información de las ciudades del jugador): multiplica por 2 el crecimiento de población de esa ciudad; varias a la vez son independientes. No toca territorio, dinero ni niveles.
- **Movilización progresiva**: un porcentaje de los trabajadores actuales se reserva y se convierte en soldados a ritmo constante durante `MOBILIZATION_TICKS`; una sola a la vez por nación; la población total no cambia; progreso y pendientes visibles.
- **Mantenimiento** de trabajadores y soldados con el recurso «recursos», con prioridad elegible (economía o ejército: quién cobra primero). **Déficit gradual:** lo no pagado queda como deuda del grupo; mientras haya deuda no hay crecimiento; tras un plazo de gracia el grupo en déficit pierde un 1 % (mín. 1 persona) por tick hasta saldar la deuda. Saldos nunca negativos. Aviso visible en el HUD.
- **Reloj único:** `CityManager` emite `ticked` tras cada tick y la población avanza en ese mismo paso. No se ha creado un reloj global (queda con la simulación pendiente de redefinir).
- **Valores:** todos en `scripts/data/population_balance.gd`, **provisionales**; con ellos el juego por defecto no entra en déficit (comprobado por prueba y por una réplica en Python) y un déficit provocado se corrige solo.
- **Criterios:** pruebas PO-01…PO-24 (`tests/test_population.gd`, ver `docs/TEST_PLAN.md`); las cinco suites anteriores siguen presentes y sin cambios en sus aserciones.
- **Fuera de alcance (no implementado):** ataques y movimiento de ejércitos, asignación de soldados a frentes, ocupación militar provisional, fuerza militar y bajas por batalla, tratados y treguas, IA, multijugador, producción según trabajadores, construcciones, nuevos terrenos y **expansión territorial automática**. El crecimiento de ciudades, la población, la economía y el mantenimiento nunca modifican las fronteras: solo `conquer_cells`.
- **Dependencias futuras documentadas:** el efecto del déficit sobre la fuerza militar o la eficacia del ejército depende del combate (hito 10); los soldados son una cifra nacional (D7 sigue abierta sobre su reparto por frente).

## Simulación por pasos, pausa y reloj global (pendiente de redefinición; antes «hito 7»)
- **Descartado:** la expansión territorial automática de fronteras. Contradice la regla confirmada de que el territorio solo cambia por una conquista explícita. Tampoco hace falta la comprobación de continuidad que se planeó para ella (puede volver con la conquista si se necesita).
- **Pendiente de redefinir:** reloj global con pasos fijos, pausa en el modo individual y control de velocidad (D10). Hoy cada sistema avanza con los ticks fijos de `CityManager` (que la población comparte mediante la señal `ticked`); no hay pausa.
- **Criterios (si se retoma):** mismas entradas y misma semilla dan el mismo estado tras N pasos; la pausa detiene toda la simulación; ningún paso cambia propietarios.

## Hito 8 — (absorbido por el hito 7)
Población, trabajadores, control de reparto y prioridad de crecimiento se implementaron en el hito 7. Quedan abiertas, sin implementar: la relación entre población y nivel/crecimiento visual de la ciudad (D6), el crecimiento por unidad de población estrictamente decreciente con el tamaño y qué trabajadores producen qué (D5).

## Hito 9 — Construcciones y producción según trabajadores
- El mantenimiento de trabajadores y soldados **ya existe desde el hito 7**; la producción de las ciudades sigue dependiendo solo de su nivel (hito 6). Este hito añadiría construcciones según D14 y, si se decide, producción según trabajadores.
- **Criterios:**
  - Las construcciones se rechazan sin dinero suficiente (prueba automática).
  - Si la producción depende de los trabajadores, la prueba comprueba la relación sin romper el equilibrio inicial del hito 7.

## Hito 10 — Ejércitos, ataques y previsión de combate
- Cifra de soldados según D7, ataques según D3/D8 (incluida la selección de la zona de ataque y su flecha opcional, D18) y previsión visible de ventaja, probabilidad de victoria y pérdidas estimadas.
- **Criterios:**
  - Los ataques inválidos se rechazan (pruebas automáticas).
  - La previsión se calcula con una función pura y coincide con el resultado cuando el combate es determinista, o con la distribución definida si hay azar (pruebas automáticas).
  - El jugador puede ver la previsión antes de confirmar un ataque (validación visual).
  - Está definido y probado el destino de las ciudades en territorio conquistado (D12).

## Hito 11 — (absorbido por el hito 7)
La conversión progresiva de un porcentaje de trabajadores en soldados se implementó en el hito 7 como «movilización». Siguen abiertas las cifras definitivas y las penalizaciones asociadas (D13).

## Hito 12 — IA enemiga
- IA simple que usa las mismas reglas y órdenes que el jugador.
- **Criterios:**
  - La IA solo emite órdenes válidas (prueba automática).
  - Mismo estado y misma semilla producen la misma decisión.
  - Una partida simulada sin intervención del jugador no produce errores.

## Hito 13 — Victoria, derrota y reinicio
- Condiciones D11, pantalla final y reinicio.
- **Criterios:**
  - Se detecta victoria y derrota según D11 (pruebas automáticas).
  - No se aceptan órdenes tras el final.
  - Reiniciar restaura el estado inicial exacto.

## Hito 14 — Pulido y cierre del MVP
- Corrección de errores, equilibrio básico, revisión de interfaz y documentación.
- **Criterios:** una partida completa jugable de principio a fin; todas las pruebas automáticas ejecutadas y pasadas en el PC; documentos coherentes con lo implementado.

## Pendientes registrados (no olvidados)
- **Fundación de ciudades instantánea** (hito 6): el diseño confirmado prevé un breve tiempo de fundación (D4). Hoy el clic funda y cobra en el acto. No se ha cambiado en el hito 7 para no alterar reglas sin pedirlo.
- **Pausa y velocidad** del tiempo de juego (D10).
- **Producción según trabajadores** y construcciones (D14, hito 9): hoy la producción solo depende del nivel de la ciudad.
- **Tiempo de medición** de la vista pixelada en el PC (hito 4) y validación visual del panel de población (hito 7).

## Notas de orden
- El 3→4→5 es obligatorio. La secuencia vigente es 6 (ciudades) → 7 (población y mantenimiento) → 9 (construcciones) → 10 (ejércitos y combate); los antiguos 8 y 11 quedaron dentro del 7.
- Un hito no empieza hasta que sus decisiones abiertas tengan respuesta.
- Más allá del MVP (sin planificar): mapas adicionales, más naciones, diplomacia, investigación, guardado de partida.
