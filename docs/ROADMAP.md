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
| 6 | **Ciudades y economía básica** (ciudades iniciales, fundación, crecimiento por niveles, dinero y recursos) | Implementado; pruebas escritas, **pendientes de ejecutar y validar en Godot** |
| 7 | Simulación por pasos y expansión territorial (aplazado desde el antiguo hito 6) | Pendiente; requiere D3, D10. Sin expansión automática hasta decidirlo |
| 8 | Población, trabajadores y crecimiento urbano | Pendiente; requiere D5, D6, D15, D19 |
| 9 | Mantenimiento y construcciones (los dos recursos ya existen desde el hito 6) | Pendiente; requiere D14 |
| 10 | Ejércitos, ataques y previsión de combate | Pendiente; requiere D7, D8, D12, D18 |
| 11 | Reclutamiento forzoso | Pendiente; requiere D13 |
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
**Estado: implementado en la nube sin Godot; pruebas escritas, no ejecutadas; validación local pendiente.** Sustituye en la secuencia al antiguo «hito 6» (simulación y expansión), que pasa al hito 7, y absorbe el antiguo «hito 7» (ciudades) y la parte básica del hito 9 (los dos recursos). La decisión de diseño más reciente del propietario es empezar por ciudades y economía.
- **Ciudades** (`scripts/world/city_manager.gd`): id estable, centro en coordenadas de celda, nivel (1–4) y progreso de crecimiento. El propietario **no se guarda**: es el de la celda central en `TerritoryGrid`, así que cambia solo si esa celda se conquista y nunca puede desincronizarse. Una ciudad sin propietario queda inactiva (no se destruye).
- **Ciudades iniciales:** una de nivel 1 por nación con territorio, en el punto central de su territorio inicial (o, si no sirve, la primera celda válida de una búsqueda determinista por anillos). No son capitales ni tienen bonificaciones.
- **Fundación:** botón «Fundar ciudad» + clic en el mapa; `Esc` o el botón cancelan. Reglas: dentro del mapa, tierra, del jugador, sin ciudad ahí, distancia mínima (Chebyshev) a cualquier ciudad y dinero suficiente. Solo se cobra si todo se cumple; si no, mensaje breve y el modo sigue activo. La fundación es **inmediata** (el «breve tiempo de fundación» confirmado en el GDD queda para más adelante).
- **Crecimiento:** por ticks fijos de tiempo de juego; al alcanzar un umbral (cada vez mayor) sube de nivel. Se dibuja como una mancha de píxeles (rombo) claros del color de la nación, siempre dentro de su territorio, en una capa aparte (`city_layer_view.gd`). Crecer **nunca** cambia propietarios.
- **Economía** (`scripts/world/economy.gd`): dinero y recursos por nación (solo esos dos; saldos enteros no negativos). Cada ciudad activa produce según su nivel en cada tick. El HUD muestra el dinero y los recursos del jugador con su ingreso por segundo; el panel de información muestra propietario, nivel, producción y crecimiento de la ciudad seleccionada.
- **Valores de equilibrio:** todos en `scripts/data/economy_balance.gd` y **provisionales** (ver `docs/GDD.md`).
- **Criterios:** pruebas CE-01…CE-21 (`tests/test_city_economy.gd`, ver `docs/TEST_PLAN.md`); las cuatro suites anteriores siguen presentes y sin cambios.
- **Fuera de alcance (no implementado):** población, trabajadores y soldados, prioridad de población, reclutamiento, ejércitos, combate, ocupación, tratados, IA económica, mantenimiento, otros terrenos, cámara y multijugador. Tampoco hay **expansión territorial automática**: el territorio solo cambia por `conquer_cells`.

## Hito 7 — Simulación por pasos y expansión territorial (aplazado; antes «hito 6»)
- Reloj de simulación con pasos fijos y pausa; expansión de fronteras según la regla decidida en D3, incluida una comprobación reutilizable de continuidad del territorio. (El hito 6 ya tiene sus propios ticks fijos para ciudades y economía; este hito decidiría el reloj global, la pausa y la velocidad.)
- **No se implementa mientras D3 y D10 sigan abiertas.** Sigue vigente la regla: el territorio solo cambia por una conquista explícita, nunca por el tiempo ni por el crecimiento de ciudades.
- **Criterios:**
  - Mismas entradas y misma semilla producen el mismo estado tras N pasos (prueba automática).
  - La expansión solo reclama celdas adyacentes y de tierra, no deja territorio desconectado y conserva el total de celdas (prueba automática, con la comprobación de continuidad).
  - La pausa detiene la simulación.
  - El resultado se ve fluido en el PC del propietario.

## Hito 8 — Población, trabajadores y crecimiento urbano
- Población trabajadora y de soldados, control deslizante en el HUD, prioridad de población por ciudad (D19), crecimiento decreciente de ciudades y subida de nivel por umbrales.
- **Criterios:**
  - Cambiar el control afecta solo a la población **nueva** (prueba automática).
  - El crecimiento por unidad de población es estrictamente decreciente con el tamaño (prueba automática).
  - Al cruzar un umbral la ciudad sube de nivel automáticamente; después sigue creciendo más despacio (prueba automática).
  - El total de población se conserva en las conversiones.

## Hito 9 — Mantenimiento y construcciones
- Los dos recursos y la producción básica en ciudades **ya existen desde el hito 6**. Este hito añade el mantenimiento de trabajadores y soldados, la producción según trabajadores y las construcciones según D14.
- **Criterios:**
  - Existen exactamente dos recursos: dinero y recursos (prueba automática del modelo).
  - Los saldos no se vuelven negativos sin una regla explícita (prueba automática).
  - El comportamiento cuando no alcanzan los recursos está definido y probado.
  - El HUD muestra ambos saldos de forma discreta.

## Hito 10 — Ejércitos, ataques y previsión de combate
- Cifra de soldados según D7, ataques según D3/D8 (incluida la selección de la zona de ataque y su flecha opcional, D18) y previsión visible de ventaja, probabilidad de victoria y pérdidas estimadas.
- **Criterios:**
  - Los ataques inválidos se rechazan (pruebas automáticas).
  - La previsión se calcula con una función pura y coincide con el resultado cuando el combate es determinista, o con la distribución definida si hay azar (pruebas automáticas).
  - El jugador puede ver la previsión antes de confirmar un ataque (validación visual).
  - Está definido y probado el destino de las ciudades en territorio conquistado (D12).

## Hito 11 — Reclutamiento forzoso
- Conversión de un porcentaje de trabajadores existentes en soldados durante un plazo corto (no instantánea).
- **Criterios:**
  - Solo se convierte el porcentaje elegible y se conserva el total de población (pruebas automáticas).
  - Las consecuencias definidas en D13 se aplican y se prueban.

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

## Notas de orden
- Los hitos 7–9 pueden intercambiarse con el 6 si el propietario prefiere ver ciudades antes que expansión; el 3→4→5 es obligatorio.
- Un hito no empieza hasta que sus decisiones abiertas tengan respuesta.
- Más allá del MVP (sin planificar): mapas adicionales, más naciones, diplomacia, investigación, guardado de partida.
