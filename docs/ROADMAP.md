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
| 7 | **Población, trabajadores y mantenimiento** (población por nación generada por las ciudades, reparto de la población nueva, prioridad de crecimiento, movilización progresiva, mantenimiento con déficit gradual) | Hecho; 24 PASS ejecutadas por el propietario en Godot 4.7.2 (comunicado por el propietario al pedir el hito 8; la validación visual del panel no se ha registrado) |
| — | Simulación por pasos con pausa y reloj global (antes «hito 7») | **Pausa hecha en el hito 10** (reloj único con pausa en `CityManager`, modo individual). La **expansión territorial automática sigue descartada**; el control de velocidad (D10) sigue abierto |
| 8 | **Organización militar y asignación de soldados** (sectores de despliegue de una celda y cuatro direcciones, reserva de soldados, panel militar y marcadores en el mapa; sin combate) | Hecho; el propietario probó a mano la interfaz simplificada y confirmó que funciona; pruebas MI-01…MI-21 escritas, **ejecución en Godot sin confirmar** |
| 9 | **Ataques, combate determinista, invasiones progresivas, ocupación provisional y estado de guerra** (sobre los sectores del hito 8; absorbe el antiguo «hito 10») | Implementado; pruebas CB-01…CB-25 escritas, **pendientes de ejecutar y validar en Godot** |
| 10 | **Guerra, diplomacia y jugabilidad simplificada** (ataque en un paso, combate legible, paz con conquistas y paz blanca con pagos, respuesta y propuestas de la IA, treguas, pausa en el modo individual; corrige los dos fallos de color de las pruebas del hito 9) | Implementado; pruebas DI-01…DI-19 escritas y pruebas de interfaz de CB y MI reescritas, **pendientes de ejecutar y validar en Godot** |
| 11 | Construcciones y producción según trabajadores (antes «hito 10» y, antes, «hito 9»; el mantenimiento ya está en el hito 7) | Pendiente; requiere D14 |
| — | ~~Reclutamiento forzoso~~ (antes «hito 11») | **Absorbido por el hito 7** como movilización progresiva (porcentaje elegible, duración y penalizaciones definitivas, D13, siguen abiertos) |
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
- **Fuera de alcance (no implementado; la asignación de soldados a sectores llegó en el hito 8):** ataques y movimiento de ejércitos, ocupación militar provisional, fuerza militar y bajas por batalla, tratados y treguas, IA, multijugador, producción según trabajadores, construcciones, nuevos terrenos y **expansión territorial automática**. El crecimiento de ciudades, la población, la economía y el mantenimiento nunca modifican las fronteras: solo `conquer_cells`.
- **Dependencias futuras documentadas:** el efecto del déficit sobre la fuerza militar o la eficacia del ejército depende del combate (hito 9: hoy el déficit solo hace desertar soldados); los soldados son una cifra nacional y desde el hito 8 se reparten entre sectores (D7 queda provisional).

## Simulación por pasos, pausa y reloj global (pendiente de redefinición; antes «hito 7»)
- **Descartado:** la expansión territorial automática de fronteras. Contradice la regla confirmada de que el territorio solo cambia por una conquista explícita. Tampoco hace falta la comprobación de continuidad que se planeó para ella (puede volver con la conquista si se necesita).
- **Hecho en el hito 10:** la pausa en el modo individual. El reloj único con pasos fijos es `CityManager` (que población, ofensivas, guerras, treguas y diplomacia comparten mediante la señal `ticked`) y la pausa vive ahí. **Pendiente:** control de velocidad (D10).
- **Criterios (si se retoma):** mismas entradas y misma semilla dan el mismo estado tras N pasos; la pausa detiene toda la simulación; ningún paso cambia propietarios.

## Hito 8 — Organización militar y asignación de soldados
**Estado: hecho. El propietario probó a mano la interfaz simplificada (flujo «crear y asignar» con un solo deslizador) y confirmó que funciona; las pruebas MI-01…MI-21 están escritas pero su ejecución en Godot no está confirmada.** Antes de este hito el «hito 8» antiguo (población y crecimiento urbano) estaba absorbido por el 7; se reutiliza el número. Primera capa militar: **preparar** el despliegue, no combatir. Detalle del modelo y las reglas: `docs/GDD.md`, «Organización militar (hito 8)».
- **Sector militar** (`scripts/world/military.gd`): orden de despliegue con id estable, nación, celda de origen (propia), dirección ortogonal (norte, este, sur, oeste), celda objetivo contigua (tierra) y soldados asignados. Rechaza: nación o dirección inválidas, origen fuera del mapa o no propio, objetivo fuera del mapa, en agua o **en territorio propio** (debe ser tierra sin reclamar o de otra nación), duplicados (mismo origen y dirección) y cantidades inicial negativas o superiores a la reserva. Se pueden crear varios sectores a lo largo de una frontera. **Crear un sector no inicia ninguna guerra.** Crear y asignar es una sola operación atómica (`create_sector(..., soldiers)`): o se crea el sector ya con sus soldados o no cambia nada.
- **Asignación:** los soldados asignados siguen siendo parte de `Population.soldiers`; no hay contador nacional duplicado. Reserva disponible = soldados − asignados. Crear, asignar, aumentar, reducir y eliminar un sector son solo apuntes: no crean ni destruyen soldados, no tocan trabajadores, dinero ni recursos y no cambian fronteras. No se puede asignar más de lo disponible.
- **Coherencia:** si el total de soldados baja (deserción por déficit), el exceso asignado se quita de forma determinista empezando por el sector más nuevo; los sectores no se eliminan. Si el origen de un sector se conquista, el sector se elimina y sus soldados vuelven a la reserva.
- **Interfaz (simplificada):** panel «EJÉRCITO» en la columna izquierda. Resumen (soldados totales / asignados / disponibles). **Crear:** celda propia seleccionada en el mapa → botón N/E/S/O → **un deslizador** de soldados (1…disponibles) → «Crear sector y asignar»; el plan muestra origen, objetivo con su dirección y a quién pertenece. **Editar:** elegir un sector en la lista → detalle (origen, objetivo, dirección, soldados) → **el mismo tipo de deslizador** (0…reserva + lo que ya tiene) → «Aplicar», o «Liberar y eliminar». Se quitaron los botones +1/+5/−1/−5. Marcadores discretos en el mapa (`scripts/world/sector_layer_view.gd`): origen, línea con punta de flecha hasta el objetivo y la cifra de soldados; el sector elegido lleva recuadro y su cifra siempre se ve; las cifras no se solapan (si no caben, se omiten; el número exacto está en la lista). Sin soldados dibujados. Aspecto funcional, no pulido.
- **Criterios:** pruebas MI-01…MI-18 (`tests/test_military.gd`, ver `docs/TEST_PLAN.md`); las seis suites anteriores siguen presentes y sin cambios en sus aserciones.
- **Fuera de alcance (no implementado):** resolución de combates, probabilidades y bajas, avance automático, invasiones o cambios de propietario, ocupación militar provisional, declaración formal de guerra, negociaciones/tratados/treguas, IA militar, multijugador, nuevos terrenos y expansión territorial automática. Estas mecánicas se desarrollarán después manteniendo separada la propiedad territorial del control militar provisional.
- **Dejado preparado:** el sector guarda `target` aparte del origen y la dirección para poder ampliarlo a un frente de varias celdas; `Military` no sabe de combate ni de diplomacia, así que el hito 9 añadió los ataques sobre los sectores sin reescribirlos.

## Hito 9 — Ataques, combate e invasiones progresivas
**Estado: implementado en la nube sin Godot; pruebas CB-01…CB-25 escritas, no ejecutadas; validación local pendiente.** Antes de este hito el «hito 9» era Construcciones y el «hito 10» Ejércitos y combate; el combate pasó al 9 por petición del propietario y las construcciones al 10. Primera versión jugable de los ataques sobre los sectores del hito 8 (no los reemplaza). Detalle de las reglas y las fórmulas: `docs/GDD.md`, «Ataques, combate e invasiones progresivas (hito 9)».
- **Ofensiva** (`scripts/world/offensives.gd`): estado de ataque de un sector (preparado → atacando → detenido). Usa los soldados asignados al sector, como mucho una por sector, se puede detener y reanudar a mano, y un sector sin soldados no ataca. Avanza **una celda por intervalo** (`ADVANCE_INTERVAL_TICKS` = 3 ticks) en la dirección del sector desde un frente propio u ocupado; se detiene en el agua, en el borde del mapa, sin soldados, al perder un enfrentamiento, al perder el frente o si no puede reclamar. Reloj: `CityManager.ticked` (después de la población).
- **Combate determinista** (`scripts/world/combat.gd`, valores en `scripts/data/combat_balance.gd`, todos provisionales): defensa local = fondo común de soldados reales del defensor repartido entre sus tramos de frontera; el atacante vence si `A × 100 > D × 120`; bajas del vencedor 35 % de la fuerza del vencido, del vencido 70 % de la suya. **Previsión** (la misma función, sin cambiar nada) con atacantes, defensa estimada, relación, etiqueta (ventaja / equilibrado / defensa superior), resultado y bajas aproximadas; no se presenta como probabilidad.
- **Bajas reales** (`Military.apply_casualties`, `Population.remove_soldiers`): restan del sector y de la población; los trabajadores no se tocan; los sectores del defensor se reajustan de forma determinista.
- **Ocupación provisional** (`scripts/world/occupation.gd`): separada de la propiedad; vencer en tierra de otra nación la ocupa sin cambiar su propietario; vencer en tierra sin reclamar la conquista con `conquer_cells` (decisión provisional D22). El ocupante no cobra nada; no se funda sobre celdas ocupadas; una ciudad con el centro ocupado suspende su producción y la reanuda al terminar la ocupación.
- **Estado de guerra** (`scripts/world/war_state.gd`): explícito y consultable; empieza solo al atacar territorio oficial de otra nación (D21, provisional); no se puede terminar todavía.
- **Interfaz:** bloque «ATAQUE» en el panel militar (estado, previsión, confirmar / reanudar, detener, frente y bajas), línea de guerra y ocupaciones, marcadores del mapa (línea al frente, flecha o «alto», cifra junto al frente) y celdas ocupadas en tablero de ajedrez. El panel militar tiene ahora barra de desplazamiento.
- **Criterios:** pruebas CB-01…CB-25 (`tests/test_combat.gd`, ver `docs/TEST_PLAN.md`); las siete suites anteriores no se tocan.
- **Fuera de alcance (no implementado en el hito 9):** diplomacia (paz, treguas, indemnizaciones, transferencias por tratado, eliminación de naciones), IA militar, defensa activa, selección de zona con flecha (D18), frentes de varias celdas, azar, ataques por mar, pausa y producción según trabajadores. (La diplomacia, el fin de la guerra y la pausa llegaron en el hito 10.)

## Hito 10 — Guerra, diplomacia y jugabilidad simplificada
**Estado: implementado en la nube sin Godot; pruebas DI-01…DI-19 escritas y pruebas de interfaz reescritas, no ejecutadas; validación local pendiente.** Detalle de las reglas, las fórmulas y la interfaz: `docs/GDD.md`, «Guerra, diplomacia y jugabilidad simplificada (hito 10)». Base: rama `claude/ecstatic-bardeen-1de9nl`, commit `827cafa` (hito 9).
- **Fallos del hito 9:** las dos pruebas visuales comparaban con `==` colores float contra píxeles RGBA8 (cuantización a 8 bits con truncado: diferencia de hasta 1/255); corregidas con una tolerancia justificada que sigue detectando colores incorrectos.
- **Ataque en un paso** (`Offensives.plan_attack` / `launch_attack`, `scripts/ui/military_panel.gd`): se pulsa la frontera o la celda enemiga, se elige la cantidad (deslizador o 25/50/75/100 %), se ve la previsión y un único botón «Atacar» / «Detener» / «Continuar» crea o reutiliza el frente interno y lanza la ofensiva de forma atómica. «Ajustar» y «Retirar frente» para los frentes existentes; sin la palabra «sector» en la interfaz.
- **Combate legible:** fórmula sin cambios de equilibrio; etiqueta «Combate equilibrado»; previsión compacta con «Victoria prevista» / «Derrota prevista» y bajas; estado con soldados restantes y último resultado.
- **Registro por guerra y tregua** (`WarState`): id, agresor, inicio, bajas y ocupaciones por bando; `end_war`; treguas en ticks que impiden atacar y declarar la guerra (también en la API militar).
- **Diplomacia** (`scripts/world/diplomacy.gd`, `diplomacy_balance.gd`, `diplomacy_panel.gd`): paz con conquistas y paz blanca, pago opcional en dinero, aplicación atómica, respuesta determinista de la IA (acepta, rechaza, contraoferta) y propuestas de paz de la IA con intervalo y caducidad.
- **Pausa:** botón y barra espaciadora; vive en el reloj único (`CityManager.set_paused`), detiene toda la simulación a la vez; la interfaz sigue respondiendo.
- **Criterios:** pruebas DI-01…DI-19 (`tests/test_diplomacy.gd`) y las suites anteriores (con las pruebas de interfaz de `combat_tests.gd` y `military_tests.gd` reescritas para el nuevo flujo; ver `docs/TEST_PLAN.md`).
- **Fuera de alcance (no implementado):** declaración formal de guerra, rendición, alianzas, IA estratégica, rotura de tregua, frentes de varias celdas, control de velocidad y diseño visual definitivo.

## Hito 11 — Construcciones y producción según trabajadores
- (Antes «hito 10» y, antes, «hito 9».) El mantenimiento de trabajadores y soldados **ya existe desde el hito 7**; la producción de las ciudades sigue dependiendo solo de su nivel (hito 6). Este hito añadiría construcciones según D14 y, si se decide, producción según trabajadores.
- **Criterios:**
  - Las construcciones se rechazan sin dinero suficiente (prueba automática).
  - Si la producción depende de los trabajadores, la prueba comprueba la relación sin romper el equilibrio inicial del hito 7.

## Reclutamiento forzoso (antes «hito 11», absorbido por el hito 7)
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
- **Control de velocidad** del tiempo de juego (D10; la pausa se hizo en el hito 10).
- **Producción según trabajadores** y construcciones (D14, hito 9): hoy la producción solo depende del nivel de la ciudad.
- **Tiempo de medición** de la vista pixelada en el PC (hito 4) y validación visual del panel de población (hito 7).
- **Diplomacia avanzada** (tras el hito 10): hoy solo hay paz con conquistas y paz blanca entre naciones en guerra; faltan declaración formal de guerra (D21, a confirmar), rendición, reparaciones, alianzas, rotura de tregua y una IA que negocie con criterios propios (D23–D25).
- **Mejoras a decidir (hitos 9–10):** suspender también el crecimiento de una ciudad ocupada (D26: mantenido), duración de la tregua (60 s provisional), defensa activa, frentes de varias celdas con flecha (D18), coste de atacar, resistencia de la tierra sin reclamar y medir el coste del recuento de celdas expuestas en el PC.

## Notas de orden
- El 3→4→5 es obligatorio. La secuencia vigente es 6 (ciudades) → 7 (población y mantenimiento) → 8 (organización militar) → 9 (ataques, combate y ocupación) → 10 (guerra, diplomacia y jugabilidad simplificada, con pausa) → 11 (construcciones); el antiguo 11 (reclutamiento) quedó dentro del 7 y la expansión territorial automática sigue descartada. Tras el 10 se recomienda validar el bucle de guerra a mano y equilibrarlo antes de la IA (hito 12).
- Un hito no empieza hasta que sus decisiones abiertas tengan respuesta.
- Más allá del MVP (sin planificar): mapas adicionales, más naciones, diplomacia, investigación, guardado de partida.
