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
| 4 | Vista pixelada del territorio | Implementado (`territory_map_view.gd`, `scenes/territory_main.tscn`); pruebas escritas, **pendientes de ejecutar y validar visualmente en Godot** |
| 5 | Fundamentos de la conquista territorial (operación `conquer_cells`) | Implementado en `territory_grid.gd`; pruebas escritas, **pendientes de ejecutar en Godot** |
| 5b | Naciones y HUD base (antes «hito 5») | Pendiente; requiere D2 |
| 6 | Simulación por pasos y expansión territorial | Pendiente; requiere D3, D10 |
| 7 | Ciudades: fundación y representación | Pendiente; requiere D4, D6 |
| 8 | Población, trabajadores y crecimiento urbano | Pendiente; requiere D5, D6, D15, D19 |
| 9 | Dinero y recursos | Pendiente; requiere D14 |
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
- **Aplazado a otros hitos:** detección de fronteras (hito 4, cuando haya que dibujarlas) y comprobación reutilizable de continuidad del territorio (hito 6, con la expansión).

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
- Registro de naciones (id, nombre, color, quién la controla), territorios iniciales y HUD mínimo.
- **Criterios:**
  - Cada nación tiene un territorio inicial continuo (ya cubierto por las pruebas del hito 3).
  - El HUD muestra el nombre de la nación del jugador y el tamaño de su territorio, leídos del estado.
  - Sin selección de provincias ni botones de acciones inexistentes.

## Hito 6 — Simulación por pasos y expansión territorial
- Reloj de simulación con pasos fijos y pausa; expansión de fronteras según la regla decidida en D3, incluida una comprobación reutilizable de continuidad del territorio.
- **Criterios:**
  - Mismas entradas y misma semilla producen el mismo estado tras N pasos (prueba automática).
  - La expansión solo reclama celdas adyacentes y de tierra, no deja territorio desconectado y conserva el total de celdas (prueba automática, con la comprobación de continuidad).
  - La pausa detiene la simulación.
  - El resultado se ve fluido en el PC del propietario.

## Hito 7 — Ciudades: fundación y representación
- Capa de ciudades independiente del territorio: fundación por clic en una ubicación válida del propio territorio (cuesta dinero y tarda un breve tiempo), nivel inicial, dibujo como agrupación de píxeles que crece desde su centro.
- **Criterios:**
  - Fundar una ciudad solo funciona si se cumplen las condiciones de D4 (pruebas automáticas de casos válidos e inválidos).
  - La ciudad no modifica el propietario ni las fronteras del territorio y viceversa (prueba automática).
  - Una ciudad recién fundada ocupa el tamaño inicial acordado.

## Hito 8 — Población, trabajadores y crecimiento urbano
- Población trabajadora y de soldados, control deslizante en el HUD, prioridad de población por ciudad (D19), crecimiento decreciente de ciudades y subida de nivel por umbrales.
- **Criterios:**
  - Cambiar el control afecta solo a la población **nueva** (prueba automática).
  - El crecimiento por unidad de población es estrictamente decreciente con el tamaño (prueba automática).
  - Al cruzar un umbral la ciudad sube de nivel automáticamente; después sigue creciendo más despacio (prueba automática).
  - El total de población se conserva en las conversiones.

## Hito 9 — Dinero y recursos
- Los dos recursos confirmados, producción en ciudades, mantenimiento de trabajadores y soldados, y construcciones según D14.
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
