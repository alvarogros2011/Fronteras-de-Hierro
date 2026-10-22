# Plan de pruebas — Fronteras de Hierro

## Principios

- La lógica del juego se prueba **sin interfaz**, con scripts GDScript ejecutables en modo headless, sin plugins.
- Cada hito de `docs/ROADMAP.md` añade sus pruebas; un hito no se cierra con pruebas fallidas.
- Los informes distinguen siempre entre pruebas **ejecutadas** y **no verificadas**. Nunca se afirma que algo se ejecutó o se ve bien sin haberlo hecho.
- La simulación debe ser determinista: mismas entradas y misma semilla, mismo resultado.
- La parte visual solo la valida el propietario en su PC (la nube no puede ver el juego).

## Cómo ejecutar las pruebas

Desde la raíz del proyecto (sustituye `godot` por tu ejecutable de Godot 4.7):

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
godot --headless --path . --script res://tests/test_gameplay.gd
godot --headless --path . --script res://tests/test_province_data.gd
godot --headless --path . --script res://tests/test_province_selection.gd
```

Cada archivo imprime PASS/FAIL por prueba y termina con código 0 (todo bien) o 1 (algún fallo). Alternativa sin terminal (pruebas del territorio): abrir `res://tests/run_territory_tests.tscn` en el editor de Godot y pulsar **F6**; la pantalla muestra PASS/FAIL, el número de correctas y el de fallidas. Las comprobaciones viven en `tests/territory_grid_tests.gd` y las usan tanto esa escena como el ejecutor headless `tests/test_territory_grid.gd`. Las del hito 5b (naciones y HUD) siguen el mismo patrón: `tests/territory_hud_tests.gd`, `tests/test_territory_hud.gd` y `tests/run_hud_tests.tscn`. Las del hito 5 (conquista) siguen el mismo patrón: `tests/territory_conquest_tests.gd`, `tests/test_territory_conquest.gd` y `tests/run_conquest_tests.tscn`. Las del hito 4 siguen el mismo patrón: `tests/territory_map_view_tests.gd`, ejecutor headless `tests/test_territory_map_view.gd` y escena F6 `tests/run_view_tests.tscn`. Las del hito 6 (ciudades y economía): `tests/city_economy_tests.gd`, `tests/test_city_economy.gd` y `tests/run_city_tests.tscn`. Las del hito 7 (población y mantenimiento): `tests/population_tests.gd`, `tests/test_population.gd` y `tests/run_population_tests.tscn`. Las del hito 8 (organización militar): `tests/military_tests.gd`, `tests/test_military.gd` y `tests/run_military_tests.tscn`. Las del hito 9 (ataques, combate y ocupación): `tests/combat_tests.gd`, `tests/test_combat.gd` y `tests/run_combat_tests.tscn`. Las del hito 10 (guerra, diplomacia, treguas y pausa): `tests/diplomacy_tests.gd`, `tests/test_diplomacy.gd` y `tests/run_diplomacy_tests.tscn`. Las del hito 11 (reforma de jugabilidad): `tests/gameplay_tests.gd`, `tests/test_gameplay.gd` y `tests/run_gameplay_tests.tscn`.

## Estado actual

| Elemento | Estado |
|---|---|
| Pantalla inicial, mapa de provincias y selección (validación visual) | Validado a mano por el propietario en Godot 4.7.2 / Windows |
| `tests/territory_grid_tests.gd` + ejecutores `tests/test_territory_grid.gd` (headless) y `tests/run_territory_tests.tscn` (F6) (hito 3, sistema nuevo) | Ejecutados a mano por el propietario en Godot 4.7.2: **21 PASS, 0 FAIL** |
| `tests/territory_map_view_tests.gd` + `tests/test_territory_map_view.gd` + `tests/run_view_tests.tscn` (hito 4, 14 pruebas V-01…V-14) | Ejecutados a mano por el propietario en Godot 4.7.2: **14 PASS** (comunicado por el propietario; Claude no ejecutó Godot) |
| `tests/test_province_data.gd` | Escrito. **Ejecución en Godot sin confirmar** |
| `tests/test_province_selection.gd` | Escrito. **Ejecución en Godot sin confirmar** |
| Réplica en Python del algoritmo del mapa inicial (herramienta de diseño: tierra 27.324 celdas, 4 territorios de 441, sin adyacencias entre naciones, borde de agua) y de la lógica de provincias | Ejecutada en la nube; **no es una prueba de Godot ni la sustituye** |
| `tests/territory_conquest_tests.gd` + `tests/test_territory_conquest.gd` + `tests/run_conquest_tests.tscn` (hito 5, 18 pruebas C-01…C-18) | Ejecutados a mano por el propietario en Godot 4.7.2: **18 PASS** (comunicado por el propietario) |
| `tests/territory_hud_tests.gd` + `tests/test_territory_hud.gd` + `tests/run_hud_tests.tscn` (hito 5b, 10 pruebas H-01…H-10) | Ejecutados a mano por el propietario en Godot 4.7.2: **10 PASS** (comunicado por el propietario) |
| **Validación local de las cuatro suites de los hitos 3–5b** | El propietario comunicó 21 + 14 + 18 + 10 = **63 PASS, 0 FAIL** en Godot 4.7.2. Ejecutado por el propietario en su PC, **no por Claude**. Además abrió el mapa y comprobó que al hacer clic en una celda aparece su información |
| `tests/city_economy_tests.gd` + `tests/test_city_economy.gd` + `tests/run_city_tests.tscn` (hito 6, 21 pruebas CE-01…CE-21) | Ejecutados a mano por el propietario en Godot 4.7.2: **21 PASS** (tras corregir una posición inválida en la prueba de fundación; comunicado por el propietario) |
| `tests/population_tests.gd` + `tests/test_population.gd` + `tests/run_population_tests.tscn` (hito 7, 24 pruebas PO-01…PO-24) | Ejecutados a mano por el propietario en Godot 4.7.2: **24 PASS** (comunicado por el propietario; las seis suites suman 108 PASS) |
| `tests/military_tests.gd` + `tests/test_military.gd` + `tests/run_military_tests.tscn` (hito 8, 21 pruebas MI-01…MI-21) | Escritos. **Ejecución en Godot sin confirmar** (no hay Godot en la nube). El propietario probó a mano la interfaz militar simplificada y confirmó que funciona |
| `tests/combat_tests.gd` + `tests/test_combat.gd` + `tests/run_combat_tests.tscn` (hito 9, 25 pruebas CB-01…CB-25) | El propietario ejecutó el hito 9 en Godot 4.7.2: **23 PASS y 2 FAIL** (CB-20 y CB-23, ambos por comparar con `==` colores float contra píxeles `RGBA8`; no era un defecto del juego). En el hito 10 se corrigió la comparación (tolerancia de 1/255) y CB-23 se reescribió para el flujo nuevo: **nueva ejecución pendiente** |
| `tests/diplomacy_tests.gd` + `tests/test_diplomacy.gd` + `tests/run_diplomacy_tests.tscn` (hito 10, 19 pruebas DI-01…DI-19) | El propietario los ejecutó en Godot 4.7.2: **17 PASS y 2 FAIL** (GP-13 y GP-14, ambos por la preparación de la prueba; corregidos después: GP-13 avanzaba 1 tick, insuficiente para que el mantenimiento —acumulado en milésimas— genere deuda; GP-14 no respondía la paz blanca que la IA 1, derrotada, ya había propuesto sola). **Nueva ejecución pendiente** |
| `tests/gameplay_tests.gd` + `tests/test_gameplay.gd` + `tests/run_gameplay_tests.tscn` (hito 11, 19 pruebas GP-01…GP-19: economía, frente ancho, IA estratégica, tratados, pausa, determinismo) | Escritos. **Ejecución en Godot sin confirmar** (no hay Godot en la nube) |
| Pruebas de diplomacia avanzada | **No existen**: esas mecánicas no están implementadas |

## 1. Pruebas existentes del territorio (hito 3, sistema nuevo)

`tests/test_territory_grid.gd` (21 pruebas; parámetros provisionales 320x180, 4 naciones):

| ID | Qué comprueba |
|---|---|
| G-01 | El mapa mide 320x180 |
| G-02 | Los dos arrays (terreno y propietario) tienen exactamente 57.600 elementos |
| G-03 | Conversión coordenadas ↔ índice (`y * 320 + x`), ida y vuelta para todas las celdas |
| G-04 | Coordenadas e índices fuera de límites rechazados (`INVALID`, `Vector2i(-1,-1)`, `false`) |
| G-05 | El terreno solo contiene agua (0) o tierra (1) |
| G-06 | IDs de las 4 naciones únicos y coherentes (`OWNER_*` = 0…4) |
| G-07 | Metadatos: claves y nombres únicos y no vacíos, colores opacos y con distancia mínima entre sí |
| G-08 | Sin propietarios desconocidos |
| G-09 | El agua no tiene propietario; el borde del mapa es agua |
| G-10 | Cantidad mínima de tierra y de agua |
| G-11 | Cada nación tiene un territorio inicial no vacío |
| G-12 | Cada territorio inicial está conectado por adyacencia ortogonal (recorrido en anchura independiente del código del módulo) |
| G-13 | Los territorios iniciales no se tocan entre sí |
| G-14 | Hay tierra sin reclamar |
| G-15 | Determinismo: dos instancias producen terreno y propietarios idénticos |
| G-16 | Asignar un propietario válido a tierra sin reclamar funciona y actualiza los recuentos |
| G-17 | Una nación inexistente se rechaza sin alterar la celda |
| G-18 | Asignar propietario al agua se rechaza |
| G-19 | Una serie de operaciones inválidas no altera terreno ni propietarios ni tamaños; las copias son independientes |
| G-20 | Consulta de naciones por ID y por clave |
| G-21 | `reset_to_default` restaura el mapa inicial |

## 1b. Pruebas existentes (prototipo de provincias, legado)

Cubren código que no se amplía. Se conservarán hasta que el propietario decida el destino del prototipo (D16).

| ID | Archivo | Qué comprueba |
|---|---|---|
| A-01 | test_province_data | Exactamente 14 provincias |
| A-02 | test_province_data | Ids únicos y ASCII, nombres no vacíos, propietarios válidos 7-7, geometría renderizable |
| A-03 | test_province_data | Vecinos existentes, sin autovecinas ni duplicados, adyacencia simétrica |
| A-04 | test_province_data | Grafo conexo |
| A-05 | test_province_data | Vecinos declarados = provincias que comparten arista |
| A-06 | test_province_selection | Integridad de datos y etiquetas de propietario |
| A-07 | test_province_selection | Punto interior → provincia correcta |
| A-08 | test_province_selection | Puntos exteriores → ninguna |
| A-09 | test_province_selection | Cerca de fronteras y en la frontera exacta: resultado estable, nunca una tercera provincia |
| A-10 | test_province_selection | Cambio y limpieza de selección con señales |
| A-11 | test_province_selection | Mapa movido, escalado y rotado |
| A-12 | test_province_selection | Panel de información coincide con los datos; estado vacío |

Pruebas manuales ya realizadas por el propietario (validación visual): M-01 abrir el proyecto, M-02 F5 sin errores, M-03 mapa de 14 provincias legible, M-04 clic selecciona y resalta, M-05 panel de información, M-06 clic en vacío limpia la selección.

> Los antiguos casos A-09 a A-28 (ataques, combate, captura, IA y victoria sobre provincias) quedan **descartados** junto con los hitos 3–7 antiguos.

## 2. Pruebas futuras (no existen todavía)

Cada bloque se escribe en el hito indicado y **solo cuando exista la mecánica**. Los valores concretos dependen de las decisiones abiertas (GDD §12).

### Hito 4 — Vista pixelada (escritas, sin ejecutar en Godot)

Cubren los antiguos T-10…T-13 y T-15; se mantienen pendientes T-14 y M-10…M-14.

| ID | Qué comprueba |
|---|---|
| V-01 | La imagen mide 320x180 y cada píxel coincide con el color calculado de su celda; fuera de la imagen no hay píxel |
| V-02 | Colores: agua, tierra sin reclamar interior, costa sin reclamar, interior y borde de cada nación (el color de nación sale de `TerritoryGrid`) |
| V-03 | `is_border` coincide en las 57.600 celdas con una comprobación independiente sobre los arrays copiados; el agua nunca es frontera |
| V-04 | Dos naciones contiguas: cada lado tiene su propia línea de frontera, sin huecos; el límite con tierra sin reclamar también es frontera |
| V-05 | Celda ↔ posición visual: centros, esquinas y posiciones concretas con la posición y escala por defecto |
| V-06 | Bordes del mapa (0,0), (319,179) y coordenadas fuera de límites, locales y globales |
| V-07 | Cambio de posición y escala del nodo (también tras moverlo) y con un nodo padre desplazado y escalado |
| V-08 | Resaltado: solo tierra; agua y fuera del mapa no resaltan; mover el ratón no selecciona |
| V-09 | Selección: tierra sin reclamar y territorio nacional se seleccionan; clic en agua, fuera del mapa y `clear_selection` la vacían, sin errores si ya estaba vacía |
| V-10 | La señal `selection_changed` solo se emite al cambiar |
| V-11 | `set_grid` limpia selección y resaltado |
| V-12 | `refresh_cell` cambia solo la celda y sus 4 vecinas, la imagen no cambia sola, y lo incremental coincide con repintar todo |
| V-13 | El texto del panel coincide con `TerritoryGrid` (coordenadas, terreno, propietario) y sigue sus cambios |
| V-14 | Barrido de movimientos y clics por todo el mapa y fuera de él: terreno y propietarios idénticos antes y después |

| ID | Pendiente (manual en Godot) |
|---|---|
| T-14 | Medición del tiempo de arranque (`refresh_all`) y de `refresh_cell` en el PC; registrar números reales |
| M-10 | Visual: aspecto pixelado limpio, mapa centrado y suficientemente grande, sin HUD que lo oculte |
| M-11 | Visual: fronteras claras entre naciones y con la tierra sin reclamar, sin huecos ni diagonales; costas legibles |
| M-12 | Visual: resaltado del ratón discreto; la selección sigue visible; el panel muestra datos correctos |
| M-13 | El clic acierta con la celda bajo el cursor (probar cerca de bordes y esquinas del mapa y con la ventana redimensionada) |
| M-14 | Clic en agua o fuera del mapa limpia la selección sin errores; el panel inferior no deja pasar clics al mapa |

### Hito 5 — Conquista territorial (escritas, sin ejecutar en Godot)

Usan un mapa controlado cargado con `load_from_data` (tierra x 10..39, y 10..29; jugador x 10..14; IA 1 x 15..19; resto sin reclamar; una isla aparte), por lo que no dependen de la generación. Todas las de rechazo comprueban además que ni propietarios ni terreno cambian.

| ID | Qué comprueba |
|---|---|
| C-01 | Conquista válida: cambia el propietario de todas las celdas pedidas (tierra de otra nación y sin reclamar) |
| C-02 | Las celdas no pedidas y el terreno no cambian; el agua sigue sin propietario |
| C-03 | Se puede conquistar tierra de otra nación (los recuentos de ambas cuadran) |
| C-04 | Forma del resultado: `ok`, `changed`, `error`, `bad_index`, `changed_cells` |
| C-05 | Agua rechazada (sola y mezclada con tierra) |
| C-06 | Celda ya del atacante rechazada |
| C-07 | Coordenadas fuera del mapa rechazadas |
| C-08 | Atacante inválido (`NONE`, 99, −1, 5) rechazado |
| C-09 | Lista vacía y elementos que no son `Vector2i` (texto, `Vector2`, `null`, entero) rechazados |
| C-10 | Objetivos repetidos rechazados, con la posición de la repetida |
| C-11 | Zona desconectada rechazada (piezas lejanas, solo diagonal, dos bloques, isla) |
| C-12 | Zona sin contacto con el atacante rechazada (también atacante sin territorio) |
| C-13 | Basta con que una celda de la zona toque al atacante |
| C-14 | Una sola celda inválida entre varias válidas no modifica ninguna |
| C-15 | Conquistas encadenadas: tras avanzar aparece el contacto que faltaba |
| C-16 | `load_from_data` rechaza tamaños, terreno, propietarios y agua con propietario inválidos sin cambiar nada |
| C-17 | Mapa por defecto: conquistar una celda cambia solo esa celda, el terreno no cambia y una instancia nueva sigue generando el mapa original; `try_set_owner` sigue funcionando |
| C-18 | La vista: `refresh_cell` sobre `changed_cells` deja la imagen igual que un repintado completo |

Las 21 pruebas del hito 3 y las 14 del hito 4 siguen existiendo sin cambios; el comportamiento de `try_set_owner` no se ha modificado.

| ID | Pendiente (manual en Godot) |
|---|---|
| M-20 | Ejecutar `test_territory_conquest.gd` (o F6 en `run_conquest_tests.tscn`) y confirmar 18 PASS; ejecutar también las de los hitos 3 y 4 |
| M-21 | Nada se ve distinto en F5: el hito 5 no añade interfaz de conquista (no hay forma de lanzarla desde el juego todavía) |

### Hito 5b — Naciones y HUD (escritas, sin ejecutar en Godot)

Cubren los antiguos T-20 y T-21 (la continuidad inicial ya la cubre G-12). Mapa controlado: 603 celdas de tierra; jugador 100, IA 1 100, sin reclamar 403.

| ID | Qué comprueba |
|---|---|
| H-01 | Las 4 naciones conservan IDs 1–4, claves, nombres y colores |
| H-02 | Solo la nación del jugador tiene controlador `human`; las demás `ai` |
| H-03 | `count_land_by_owner`: solo tierra, todas las naciones presentes (también con 0), suma = tierra total |
| H-04 | Lo mismo en el mapa por defecto: coincide con `count_owned_by`, naciones con territorio y tierra sin reclamar |
| H-05 | Formato del porcentaje: coma decimal, 100 %, total 0 sin error |
| H-06 | Filas de la leyenda: orden, nombres, celdas, porcentajes, colores = los de la cuadrícula, el agua sin cifra |
| H-07 | Tras conquistar, las filas reflejan +2/−2 y la tierra total no cambia |
| H-08 | `ownership_changed`: una emisión por operación válida; ninguna en rechazos ni en `try_set_owner` sin cambio |
| H-09 | Resumen del jugador («Confederación de Alba · 100 celdas · 16,6 %») |
| H-10 | La escena principal carga; la etiqueta del jugador coincide con la cuadrícula; un cambio marca el refresco y tras refrescar muestra las celdas actuales |

| ID | Pendiente (manual en Godot) |
|---|---|
| M-30 | Ejecutar `test_territory_hud.gd` (o F6 en `run_hud_tests.tscn`) y confirmar 10 PASS; repetir las de los hitos 3, 4 y 5 |
| M-31 | Visual: la leyenda de dos columnas cabe bajo el mapa, las cifras se leen y no se solapan con el panel de celda |
| M-32 | Visual: el resumen del jugador (arriba a la derecha) y el recuadro blanco del jugador en la leyenda se entienden sin ocultar el mapa |
| M-33 | Con las cifras iniciales: cada nación 441 celdas y ~1,6 % (la réplica de diseño del hito 3 da 27.324 de tierra); no es un dato confirmado en Godot |

### Hito 6 — Ciudades y economía básica (21 PASS ejecutadas por el propietario en Godot 4.7.2)

Mapa controlado (`load_from_data`): tierra x 10..39, y 10..29; jugador x 10..24; IA 1 x 25..34; resto sin reclamar. Usan además el mapa por defecto (ciudades iniciales) y la escena `territory_main.tscn` (integración). Las de rechazo comprueban que ni dinero, ni ciudades, ni propietarios, ni terreno cambian.

| ID | Qué comprueba |
|---|---|
| CE-01 | Constantes de equilibrio coherentes (coste > 0, saldo inicial < coste, distancia mínima > 2 × radio visual máximo, tablas por nivel, umbrales crecientes) |
| CE-02 | Mapa por defecto: 4 ciudades iniciales (una por nación) en su posición de inicio, en tierra de su nación, nivel 1, IDs únicos, deterministas |
| CE-03 | Mapa controlado: búsqueda determinista dentro del territorio; naciones sin tierra no reciben ciudad; recolocar da lo mismo |
| CE-04 | Economía: saldo inicial, operaciones negativas o inválidas rechazadas, saldo nunca negativo, señal solo en operaciones aplicadas |
| CE-05 | Fundación válida: ciudad nueva (propietario, celda, nivel 1), se descuenta exactamente `FOUND_COST`, una sola señal |
| CE-06 | Rechazo en agua, fuera del mapa, territorio ajeno y tierra sin reclamar |
| CE-07 | Rechazo de posición duplicada y de posición demasiado próxima (también a ciudades de otras naciones) |
| CE-08 | Distancia Chebyshev: límite − 1 rechazado, límite exacto aceptado |
| CE-09 | Rechazo sin dinero suficiente; con el dinero justo se acepta y queda 0 |
| CE-10 | Una fundación inválida no descuenta dinero, no cambia territorio, no crea ciudades parciales ni consume IDs; todos los códigos tienen mensaje |
| CE-11 | Nación inexistente (`OWNER_NONE`, 99) rechazada |
| CE-12 | Crecimiento temporal y cambios de nivel (umbrales crecientes, nivel máximo, saltos grandes con sobrante) |
| CE-13 | Independencia de los fotogramas (pasos de 10 s, 1 s y 0,25 s dan lo mismo; delta ≤ 0 ignorado; fracciones acumuladas) |
| CE-14 | Crecer no cambia propietarios ni terreno, no emite `ownership_changed` y la mancha queda en el territorio propio |
| CE-15 | Producción de dinero y recursos según nivel; varias ciudades suman; la tasa mejora al subir de nivel |
| CE-16 | Solo se paga al propietario; una ciudad sin propietario no produce, no crece ni se dibuja, pero no se destruye |
| CE-17 | Cambio de propietario de la celda central (`conquer_cells`): la ciudad pasa al nuevo dueño, conserva nivel y progreso, y la producción se redirige |
| CE-18 | Mancha visual: 5/13/25/41 celdas por nivel, acotada, recortada en el borde del territorio y sin invadir otra nación ni el agua |
| CE-19 | `city_covering`/`city_id_at` y texto de la ciudad (propietario, nivel, producción por segundo, crecimiento, nivel máximo) |
| CE-20 | Pantalla: arranca con 4 ciudades; el HUD muestra la economía; botón y modo de fundación; clic inválido sin cobro y modo activo; clic válido funda y cobra; sin selección en modo fundación; fuera del modo el clic selecciona |
| CE-21 | Las cuatro suites anteriores (archivos de pruebas y escenas F6) siguen presentes |

| ID | Pendiente (manual en Godot) |
|---|---|
| M-40 | Ejecutar `test_city_economy.gd` (o F6 en `run_city_tests.tscn`) y confirmar 21 PASS; repetir las cuatro suites anteriores (63 PASS) — **hecho por el propietario (21 PASS)** |
| M-41 | (comprobado por el propietario: las ciudades aparecen y crecen visualmente) F5: se ven 4 ciudades pequeñas (cruz de 5 píxeles clara con el centro blanco) en el centro de cada territorio, sin ocultar fronteras |
| M-42 | Arriba a la derecha aparece «Dinero 50 (+2/s) · Recursos 0 (+1/s)» y el dinero sube 2 por segundo |
| M-43 | Con 100 de dinero (~25 s): «Fundar ciudad» → clic en territorio azul a ≥ 9 celdas de la ciudad: aparece la ciudad y baja el dinero en 100 |
| M-44 | Clics inválidos (agua, territorio ajeno, cerca de una ciudad, sin dinero): mensaje a la izquierda, sin cobro, el modo sigue activo; `Esc` y el botón lo cancelan |
| M-45 | Clic sobre el botón o el panel de información no funda ni selecciona nada en el mapa |
| M-46 | Seleccionar una celda de una ciudad muestra propietario, nivel, producción y crecimiento; tras ~30 s sube a nivel 2 y crece la mancha |
| M-47 | El panel de información de 4 líneas no se solapa con el borde inferior ni con la leyenda |

### Hito 7 — Población, trabajadores y mantenimiento (24 PASS ejecutadas por el propietario en Godot 4.7.2)

Mapa controlado como el del hito 6 (tierra x 10..39, y 10..29; jugador x 10..24; IA 1 x 25..34), con ciudades fundadas a mano y población inyectada, y tiempo con `CityManager.advance(n)` (n ticks exactos de 1 s). Una ciudad fundada en el tick 0 sube a nivel 2 en el tick 30, a 3 en el 90 y a 4 en el 210. Las cifras de los casos deterministas (nacidos, reparto, movilización, déficit) se contrastaron con una réplica de la lógica en Python (herramienta de diseño: **no es una prueba de Godot ni la sustituye**).

| ID | Qué comprueba |
|---|---|
| PO-01 | Constantes coherentes (tablas por nivel, prioridad > 100 %, máximo de movilización 1–100, mantenimiento > 0, plazo de gracia, pérdidas parciales) y **equilibrio inicial sostenible** a población máxima por nivel (toda trabajadora, o mitad y mitad) |
| PO-02 | Población inicial por nación, total = trabajadores + soldados, consultas de naciones inexistentes (`OWNER_NONE`, 99, -1) y población inyectable |
| PO-03 | Generación de población a través de las ciudades: acumulación de fracciones, dos ciudades suman, sin ciudades no hay crecimiento, una ciudad sin propietario no aporta |
| PO-04 | Reparto de la población nueva con 0, 30, 50 y 100 %: `floor(nacidos × %)` soldados y el resto trabajadores, sin perder ni duplicar a nadie |
| PO-05 | Cambiar el porcentaje no reasigna a los existentes (todos los valores 0–100; suman 100; rechaza −1, 101 y naciones inexistentes); solo cambian los nacidos después |
| PO-06 | Conservación: movilización y cambios de reparto con el total fijo (ciudad de nivel máximo, sin hueco); con nacimientos, nunca por encima de la capacidad ni saltos > 1 persona por tick |
| PO-07 | Capacidad de las ciudades activas; al tope no nace nadie; fundar otra ciudad la amplía; sin ráfaga al liberarse capacidad; la población por encima de la capacidad no se reduce sola |
| PO-08 | Ciudad prioritaria: x2 de crecimiento (3 → 6 nacidos), se puede quitar, varias son independientes; no cambia dinero, nivel, progreso ni territorio |
| PO-09 | Reglas de la prioridad: solo el dueño, ciudad/nación inexistente rechazadas, sin cambios de territorio ni señales, se pierde al conquistarse la ciudad y no se hereda al volver |
| PO-10 | Subir de nivel no crea soldados de golpe (sin saltos > 1 en 220 ticks) |
| PO-11 | Movilización progresiva: reserva inicial, conversión `floor(total × tick / duración)`, no instantánea, resultado exacto (200/40 → 100/140), total constante, progreso 50 % a mitad de plazo, señal por tick |
| PO-12 | Movilización: porcentajes fuera de rango, nación inexistente, «nada que movilizar» y mensajes de error; nunca se reservan más trabajadores de los que hay |
| PO-13 | Sin duplicados: segunda orden rechazada mientras hay una en curso, reserva intacta, los nacidos durante el proceso siguen el porcentaje vigente (también tras cambiarlo), nueva orden tras terminar |
| PO-14 | Costes de mantenimiento exactos (10 ticks = 40 recursos; 20 ticks = 81: el redondeo no se acumula) y sin población no hay coste |
| PO-15 | Prioridad de mantenimiento real: con recursos justos cobra primero el grupo elegido y el otro queda en deuda; a largo plazo pierde gente el grupo no prioritario; valores inválidos rechazados |
| PO-16 | Déficit gradual: 5 ticks de gracia sin pérdidas, luego 1 % (mín. 1) por tick, sin crecimiento durante el déficit, deuda acotada, saldo nunca negativo y recuperación al volver los recursos |
| PO-17 | Déficit con movilización en curso: la reserva nunca supera a los trabajadores y nada se vuelve negativo |
| PO-18 | Un déficit prolongado se corrige solo antes del tick 100, la población vuelve a crecer, no crece durante el déficit y el dinero no se toca |
| PO-19 | Sin saldos negativos: `Economy.spend_resources` valida como `spend_money` y un mantenimiento enorme durante 150 ticks no deja ningún saldo ni población negativos |
| PO-20 | Juego por defecto sostenible: 600 ticks, cuatro naciones, reparto 50 % y movilización del 25 % cada 40 ticks, sin déficit ni superar la capacidad |
| PO-21 | Comportamiento anterior conservado: mismo dinero, niveles, progreso y producción con y sin población; propietarios y terreno intactos; sin `ownership_changed`; `ticked` una vez por tick |
| PO-22 | Textos del HUD (resumen, reparto, movilización, mantenimiento, déficit en sus dos etapas, prioridad de ciudad) con datos reales |
| PO-23 | Pantalla: el panel lee los datos reales; deslizador de reparto, movilización, prioridad de mantenimiento y casilla de prioridad de ciudad actúan sobre los datos; una ciudad ajena no ofrece el control; el territorio no cambia |
| PO-24 | Las suites anteriores, sus escenas F6 y los archivos del hito siguen presentes |

| ID | Pendiente (manual en Godot) |
|---|---|
| M-50 | (hecho por el propietario: 24 PASS de población y las cinco suites anteriores, 108 PASS en total) |
| M-51 | F5: a la derecha del mapa aparece el panel «Población» con 36 de población (30 trabajadores y 6 soldados), sin tapar el mapa ni desbordar la ventana (columna de 148 px) |
| M-52 | La población sube lentamente (≈ 1 persona cada 7 s) y se detiene al llegar al máximo de la ciudad (50 con una ciudad de nivel 1) |
| M-53 | Deslizador «Población nueva»: los porcentajes se muestran y suman 100; al moverlo no cambian los trabajadores y soldados ya existentes |
| M-54 | «Movilizar 25 %»: la barra y «Movilizando x/y» avanzan durante 30 s, el botón queda desactivado y al terminar los soldados han subido en lo reservado sin cambiar la población total |
| M-55 | Seleccionar una ciudad propia muestra la casilla «Prioridad de población» (y no en ciudades ajenas); activarla duplica el aporte mostrado y el crecimiento observado; el panel inferior no se sale de la ventana ni se solapa con la leyenda de forma molesta |
| M-56 | Botón «Cobra 1.º: Economía/Ejército» alterna; para ver un déficit: movilizar repetidamente con reparto 100 % a soldados hasta que el coste supere la producción y comprobar el aviso en rojo, la pérdida gradual y la recuperación |
| M-57 | Legibilidad de textos a 12 px y ajuste de líneas del panel; sensación de ritmo (crecimiento, movilización) |

### Hito 8 — Organización militar (escritas, sin ejecutar en Godot)

Mapa controlado como el del hito 7 (tierra x 10..39, y 10..29; jugador x 10..24; IA 1 x 25..34, sin reclamar x 35..39), con la ciudad del jugador en (12, 12) y población inyectada; un **enclave** (tres celdas aisladas del jugador rodeadas por la IA 1 y tierra sin reclamar, para tener las cuatro direcciones válidas en un mismo origen); un mapa de esquinas para los objetivos fuera del mapa; mundo con ciudad de nivel 4 para la movilización; y la escena principal para la prueba de pantalla. Como el objetivo nunca puede ser propio, los sectores del jugador del mapa por defecto salen de la frontera x = 24 hacia el este. No se ha escrito ninguna réplica en otro lenguaje: la revisión fue estática. En la simplificación de la interfaz (flujo «crear y asignar») se adaptaron MI-02…MI-04, MI-08…MI-17 y MI-19 por el cambio legítimo de reglas (objetivo no propio) y de flujo; no se eliminó ninguna aserción de comportamiento.

| ID | Qué comprueba |
|---|---|
| MI-01 | Las cuatro direcciones (índices, nombres, iniciales) son ortogonales y `target_cell` da la celda contigua correcta |
| MI-02 | Crear sectores válidos en las cuatro direcciones desde un mismo origen (enclave): propietario, origen, dirección, objetivo (tres de la IA 1, uno sin reclamar), 0 soldados, ids únicos y señal; no asigna soldados ni cambia propietarios; `get_sector` devuelve copia |
| MI-03 | Rechazo de origen de otra nación, sin reclamar, agua, fuera del mapa (x/y negativas, = ancho/alto), dirección −1/4 y naciones inexistentes; `validate_sector` coincide; la IA puede usar su territorio y no el ajeno |
| MI-04 | Rechazo de objetivos en agua (borde oeste, norte y sur) y fuera del mapa (esquinas); desde la esquina hacia tierra sin reclamar sí vale |
| MI-05 | Rechazo de objetivos propios en las cuatro direcciones (también con soldados iniciales), solo vale la dirección que sale del territorio, la IA tampoco puede apuntar a sí misma, el agua se reconoce como agua y el origen ajeno antes que el objetivo; los rechazos no emiten señal ni tocan el territorio |
| MI-06 | **Crear con cantidad inicial:** nace con 8 y quedan 12; una sola señal; usa justo la reserva; con reserva insuficiente, negativa o enorme no se crea nada (ni sector vacío, ni id gastado, ni señal, ni cambio de reserva); orden de comprobaciones (duplicado, objetivo propio y origen ajeno antes que cantidad); `validate_sector` con cantidad; población, dinero, recursos y territorio intactos |
| MI-07 | Rechazo de duplicados (también con otra cantidad; sin señal ni cambios); otro origen o otra dirección valen; tras eliminar se recrea con un id nuevo |
| MI-08 | Seis sectores a lo largo de la frontera jugador–IA 1 con fuerzas distintas; objetivos sin reclamar; un objetivo propio no vale; el territorio y `ownership_changed` no se tocan |
| MI-09 | Asignar, aumentar, reducir, usar justo el último disponible, fijar la misma cantidad (sin señal) y dejar un sector a 0; el total de `Population` no cambia |
| MI-10 | Imposible asignar más de lo disponible (por set, por adjust y con cantidades enormes), cantidades negativas, sector inexistente; los rechazos no cambian nada; reservas independientes por nación |
| MI-11 | Invariante tras cada orden de una secuencia fija: total = `Population.soldiers`, asignados = suma de sectores, asignados + disponibles = total; naciones inexistentes |
| MI-12 | Eliminar devuelve los soldados a la reserva sin tocar la población, no se puede eliminar dos veces ni asignar a un sector eliminado, y lo liberado se reasigna |
| MI-13 | Déficit de la IA 1 (250 trabajadores, 40 soldados, sin recursos) durante 60 ticks: tras cada tick el exceso sale del sector más nuevo y luego del antiguo (cifras exactas), nunca hay más asignados que soldados, no vuelven a la reserva, ningún sector se elimina y `enforce_soldier_limits` es idempotente |
| MI-14 | Crear (con cantidad), asignar, reducir y eliminar no emiten señales de población, economía, ciudades ni territorio y dejan idénticos población, mantenimiento, economía, ciudades, propietarios y terreno; no se convierten trabajadores en soldados |
| MI-15 | Movilización de 100 trabajadores con todo asignado: las órdenes no cambian lo asignado; los reservados aún no se pueden asignar; lo convertido solo aumenta la reserva; la población total no cambia; el reparto de población nueva no toca las asignaciones |
| MI-16 | Una conquista de la celda de origen elimina el sector y devuelve sus soldados; si el objetivo pasa a ser del jugador, el sector se conserva; una conquista ajena a los orígenes no cambia nada |
| MI-17 | Textos del panel (resumen, plan con dueño del objetivo, cantidades, línea de la lista, detalle) y mensajes de error de creación (incluidos objetivo propio y soldados) y asignación |
| MI-18 | **Marcadores del mapa:** reparto de cifras sin solapes (`SectorLayer.label_layout`): sin sectores no hay cifras, un sector va a la derecha del objetivo, con cifras enormes solo caben las dos primeras y las demás se omiten, la del sector elegido siempre se dibuja, reparto determinista |
| MI-19 | **Pantalla:** el panel y la capa existen y el panel captura el clic; ya no hay botones +1/+5/−1/−5; apuntar a territorio propio se explica y no crea; origen del mapa + dirección + cantidad con un deslizador limitado a la reserva (1…disponibles, también por encima y por debajo); «Crear sector y asignar» crea el sector ya con sus soldados; lista, detalle y resaltado; editar con el deslizador limitado a lo asignable (reserva + lo que ya tiene), mover no cambia nada hasta «Aplicar»; aplicar sube y baja; sin reserva no se crea otro sector; una celda ajena no permite crear; «Liberar y eliminar» devuelve todo; población, dinero y territorio no cambian |
| MI-20 | Con sectores que se crean con cantidad, reajustan, eliminan y recrean durante 150 ticks (más movilización, prioridad de ciudad y reparto de población nueva), población, mantenimiento, dinero, recursos, ciudades, propietarios y terreno son idénticos tick a tick a los de un mundo de control sin sectores; `try_set_owner` y `conquer_cells` siguen rechazando el agua |
| MI-21 | Las suites anteriores, sus escenas F6 y los archivos del hito siguen presentes |

| ID | Pendiente (manual en Godot) |
|---|---|
| M-60 | Ejecutar `test_military.gd` (o F6 en `run_military_tests.tscn`) y confirmar 21 PASS; repetir las seis suites anteriores (108 PASS) |
| M-61 | F5: a la izquierda del mapa aparece el panel «EJÉRCITO» bajo el botón «Fundar ciudad» sin tapar el mapa ni el mensaje de fundación y sin salirse de la ventana (probar con varios sectores y mensajes de error largos) |
| M-62 | Seleccionar una celda propia **de la frontera**, elegir una dirección hacia tierra sin reclamar o de otra nación, mover el deslizador de cantidad y pulsar «Crear sector y asignar»: aparece el marcador (origen, línea con punta de flecha y cifra) y la lista; el deslizador nunca pasa de los disponibles; en un sector elegido, mover el deslizador y «Aplicar» cambia la cifra y los disponibles; «Liberar y eliminar» devuelve los soldados |
| M-63 | Clics en botones, lista y panel no seleccionan celdas del mapa; el modo de fundación sigue funcionando |
| M-64 | Legibilidad de las cifras sobre el mapa (escala 3): con varios sectores contiguos algunas cifras se omiten en vez de solaparse (el número exacto está en la lista); la del sector elegido y su recuadro se ven siempre; comprobar también la punta de flecha |
| M-65 | Movilizar y comprobar que los disponibles suben a medida que se convierten trabajadores; provocar un déficit y comprobar que los asignados bajan sin errores |

### Simulación global, pausa y reloj (la pausa se hizo en el hito 10; ver DI-01 y DI-17)
| ID | Qué comprobar |
|---|---|
| T-30 | Mismos pasos + misma semilla → mismo estado (hash) |
| T-33 | La pausa detiene el avance de toda la simulación; reanudar continúa (hecho: DI-01) |
| T-35 | Ningún paso de simulación cambia propietarios (la expansión automática está descartada) |

### Hito 9 — Ataques, combate e invasiones progresivas (escritas, sin ejecutar en Godot)

Mismo mapa controlado que el hito 8 (tierra x 10..39, y 10..29; jugador x 10..24; IA 1 x 25..34, sin reclamar x 35..39; 20 celdas expuestas de la IA 1 = 3 tramos de frontera), **sin ciudades** salvo donde se indica y con muchos recursos para todas las naciones (nunca hay déficit): los soldados solo cambian por los combates. Escenarios extra: una fila de tierra hasta el borde del mapa y un mapa con dos celdas libres entre el jugador y la IA 1. El tiempo avanza con `CityManager.advance(n)` (n ticks exactos). Las cifras de los escenarios se contrastaron con una réplica en Python (no es una prueba de Godot).

| ID | Qué comprueba |
|---|---|
| CB-01 | Fórmulas puras (`Combat`): constantes coherentes, redondeo hacia arriba, victoria clara (10 contra 4: bajas 2 y 3), victoria por poco, empate (lo gana la defensa), derrota, derrota total, umbrales de las etiquetas (1,5 y 0,8), sin defensa, sin atacantes, bajas siempre dentro de lo que hay (1.600 combinaciones) y determinismo |
| CB-02 | Defensa local: tramos = techo(celdas / 8); defensa por tramo (2, 6, 0, 1, 4, 3 en casos fijos); **propiedad de no contar dos veces** la misma fuerza para 61 cifras de soldados y 9 tamaños de frontera; celdas expuestas reales del mapa (20), nación sin territorio (0), defensa con 6, 30 y 0 soldados, tierra sin reclamar, y la caché se recalcula al cambiar un propietario |
| CB-03 | La previsión es determinista, no cambia nada, usa solo los soldados asignados, coincide con el combate real (bajas y resultado) y una previsión de derrota se cumple |
| CB-04 | Inicio, ofensiva ya activa (sin segunda ofensiva), detener (y no dos veces), una ofensiva detenida no avanza, reanudar, sector o nación inexistentes, `stop_all` y que el agua ni siquiera permite crear el sector |
| CB-05 | Sector sin soldados rechazado (sin guerra ni rastro); no se asigna más de lo disponible; quitar los soldados o la deserción durante el ataque lo detiene; la IA ataca con las mismas reglas y su ofensiva se detiene si se queda sin soldados |
| CB-06 | **Victoria:** guerra simétrica, celda ocupada y frente avanzado, bajas exactas (1 y 2), propietario y terreno intactos, sector, reserva y población coherentes, trabajadores sin tocar, la ofensiva continúa y el segundo combate |
| CB-07 | **Derrota:** la ofensiva se detiene, el frente no avanza, no se ocupa nada, bajas reales (el sector cae a 0), territorio intacto, la guerra sigue, sin soldados no se reintenta, reforzada se reanuda y las bajas se acumulan |
| CB-08 | **Una celda por intervalo:** nada antes de cumplirse el intervalo, exactamente una celda al cumplirse, cinco pasos seguidos, y 60 fotogramas de 0,25 s dan lo mismo que ticks enteros |
| CB-09 | **Invasión completa:** cuatro combates agotan a la IA 1 (4 y 6 bajas); sin defensores ocupa sin bajas una línea continua hasta el fondo de su territorio; al llegar a tierra sin reclamar sin contacto con territorio propio se detiene (conserva lo ocupado) y reanudar sigue bloqueado; ningún propietario cambia |
| CB-10 | **Tierra sin reclamar:** conquista explícita celda a celda (cinco celdas, solo esas cambian, `ownership_changed` una vez por celda y `territory_changed` para repintar), sin guerra, sin ocupaciones, sin bajas; el agua detiene la ofensiva |
| CB-11 | Límite del mapa (fila hasta x = 319: se detiene sin bajas) y agua al oeste (diez celdas y se detiene) |
| CB-12 | Frente perdido (se libera la ocupación del frente): se detiene, reanuda desde el origen, volver por una celda ocupada es una marcha sin bajas, la celda liberada se combate otra vez y `conquer_cells` sobre lo ocupado lo convierte en propiedad real sin dejar ocupación |
| CB-13 | `Occupation`: ocupar sin tocar propietarios ni terreno, consultas directas, recuentos, señales, validaciones (sin reclamar, propia, agua, fuera del mapa, ocupante inexistente), ocupar de nuevo, sustitución por un tercero, liberar, `release_all_of` y descarte al cambiar el propietario oficial |
| CB-14 | `WarState`: declarar, simetría, agresor, sin duplicados ni datos inválidos; la guerra empieza al atacar a otra nación (no por tener un sector ni por atacar tierra sin reclamar), sobrevive a detener el ataque y al paso del tiempo |
| CB-15 | **Economía:** el ocupante no cobra nada; la ciudad ocupada suspende su producción (ingresos 0, tasas 0, dinero igual tras 5 ticks) pero sigue de su dueño y crece de nivel; no se funda sobre celdas ocupadas (ocupante: no es suyo; dueño: ocupada) sin cobrar; al liberar la producción se reanuda; 100 ticks de ocupación no cambian al dueño |
| CB-16 | **Consistencia:** en 40 ticks de combate nunca hay cifras negativas, asignados > existentes ni reserva ≠ total − asignados; los trabajadores no cambian; las bajas contadas son las que desaparecieron de la población; el sector de la IA 1 se recorta del más nuevo al más antiguo; las bajas salen primero de la reserva; `remove_soldiers` con límites |
| CB-17 | Dos ofensivas independientes en la misma frontera comparten el fondo de defensa (las bajas del defensor suman exactamente sus 6 soldados), detener una no detiene la otra y las reservas cuadran |
| CB-18 | 300 ticks con ciudades, población y economía no mueven fronteras ni crean ocupaciones; tras detener un ataque, 400 ticks no cambian nada; las ocupaciones no se vuelven propiedad con el tiempo |
| CB-19 | Eliminar el sector borra su ofensiva pero no la ocupación ni la guerra; perder la celda de origen elimina sector y ofensiva |
| CB-20 | **Mapa:** las celdas ocupadas se pintan en tablero con el tono claro del ocupante (distinto del color de cualquier propietario), la imagen solo cambia al repintar, liberar restaura el color y sin ocupación el dibujo es el de siempre; propietario y fronteras no cambian |
| CB-21 | Capa de sectores: la cifra va junto al objetivo si el sector está preparado y junto a la celda siguiente al frente si ataca o está detenido; sin ofensivas se comporta como en el hito 8 |
| CB-22 | Textos: línea de la lista (« · ATQ»), relación, etiquetas, previsión completa (victoria, derrota, celda propia, sin reclamar, bloqueada), estado de la ofensiva, motivos de parada, mensajes de inicio, línea de guerra y ocupaciones, y descripción de la celda ocupada |
| CB-23 | **Pantalla:** crear el sector con la interfaz, previsión visible con atacantes, defensa, etiqueta y aviso de que no es una probabilidad, «Confirmar ataque» pasa a atacar (lista y panel lo distinguen), una segunda pulsación no crea otra ofensiva, el avance ocupa la celda y repinta el mapa sin cambiar propietarios, resumen y recuento actualizados, detener / reanudar, sin soldados el botón se desactiva, liberar el sector conserva la ocupación |
| CB-24 | Determinismo: dos partidas idénticas con dos ofensivas, una detención y 38 ticks dan exactamente el mismo estado |
| CB-25 | Las suites anteriores, sus escenas F6 y los archivos del hito (y del prototipo de provincias) siguen presentes |

| ID | Pendiente (manual en Godot) |
|---|---|
| M-70 | Ejecutar `test_combat.gd` (o F6 en `run_combat_tests.tscn`) y confirmar 25 PASS; repetir las siete suites anteriores (108 PASS + las de militar) |
| M-71 | F5: el panel «EJÉRCITO» cabe en la columna izquierda con su barra de desplazamiento, sin tapar el mapa ni salirse de la ventana; el bloque «ATAQUE» aparece al elegir un sector y se ve entero (desplazando si hace falta) |
| M-72 | Para probar un ataque real hay que acercar territorios: elegir una celda libre junto a tu frontera, atacar tierra sin reclamar con un sector hasta llegar a otra nación (el mapa inicial deja las naciones separadas); comprobar que la tierra libre pasa a ser tuya celda a celda y que al entrar en la otra nación empieza «Guerra con…» |
| M-73 | Legibilidad: el recuadro del frente, la línea naranja, la punta de flecha y el «alto» al detener; las celdas ocupadas en tablero se distinguen del territorio propio y del enemigo; la cifra junto al frente |
| M-74 | La previsión es comprensible antes de confirmar (atacantes, defensa estimada, relación, resultado, bajas) y coincide con lo que ocurre en el primer avance |
| M-75 | Una ciudad enemiga ocupada se ve con el centro naranja y su producción se suspende (el panel de celda lo indica); al liberar la ocupación se reanuda (probar liberando por conquista) |
| M-76 | Sensación de ritmo: ¿es 1 celda cada 3 s demasiado lento o rápido?; ¿se entiende que detener no devuelve lo ocupado? Coste de recalcular las celdas expuestas al conquistar (debería ser imperceptible) |

### Hito 10 — Guerra, diplomacia y jugabilidad simplificada (escritas, sin ejecutar en Godot)

Mapas controlados como los del hito 9: **duelo** (tierra x 10..39, y 10..29; jugador x 10..24; IA 1 x 25..34; sin reclamar x 35..39) y **tres** (jugador x 10..24; IA 1 y 10..19 y IA 2 y 20..29 en x 25..39). Sin ciudades salvo donde se indica, con muchos recursos (nunca hay déficit) y 50 de dinero por nación. El tiempo avanza con `CityManager.advance(n)` (n ticks exactos). Las cifras de la IA se contrastaron con una réplica en Python de las fórmulas (no es una prueba de Godot). Además se **reescribieron las pruebas de interfaz** de `combat_tests.gd` (`_test_screen`, `_test_texts`) y `military_tests.gd` (`_test_screen`, `_test_texts`) para el flujo nuevo (los controles antiguos «Crear sector…», «Aplicar», «Liberar y eliminar» ya no existen): se conservan las comprobaciones sobre soldados, reservas, mapa y ocupación, y se sustituyen las del flujo de crear y editar por las equivalentes del flujo de atacar, ajustar y retirar.

| ID | Qué comprueba |
|---|---|
| DI-01 | **Pausa:** `advance` no ejecuta ticks en pausa (aunque llegue mucho tiempo); territorio, ocupaciones, ofensivas (también su cuenta atrás), saldos, población, movilización, crecimiento de ciudades, duración de la guerra y de la tregua no cambian; fundar y negociar se rechazan; consultar y planificar un ataque sí, y no avanza; al reanudar todo sigue desde donde estaba; la señal `pause_changed` se emite una vez por cambio |
| DI-02 | `WarState`: registro por guerra (id, partes, agresor, inicio, duración con el reloj), bajas y ocupaciones por bando, terminar una guerra sin tocar otra, treguas simétricas con cuenta atrás, `declare_war` bloqueado por tregua, expirar y empezar una guerra nueva; sin reloj sigue valiendo |
| DI-03 | `Occupation`: consultar y contar por ocupante y propietario, `release_between` libera ambos sentidos sin tocar otras parejas y avisa de las celdas, `export_state`/`import_state` |
| DI-04 | **Ataque en un paso:** `plan_attack` no cambia nada y prevé lo mismo que ocurre; `launch_attack` crea el frente, asigna y lanza en una operación (guerra declarada, reserva coherente); reforzar y reducir con la ofensiva activa (mismo frente, sin reiniciar), continuar un frente detenido con otra cantidad, varios puntos de una misma frontera; poca fuerza anuncia derrota y mucha no cuesta todas las bajas |
| DI-05 | **Órdenes inválidas** (origen ajeno o fuera del mapa, objetivo propio o de agua, dirección inválida, nación desconocida, 0 o negativos, más de los disponibles): ninguna crea un frente, compromete soldados ni declara la guerra, el estado es idéntico y cada una tiene mensaje; agua y borde; pedir de más con un frente existente no lo toca |
| DI-06 | Propuestas: sin guerra no; misma nación, tipo desconocido, pago negativo, pagador ajeno o sin dinero; las inválidas no cambian nada; propuesta pendiente a un humano sin tocar saldos, una sola por pareja, solo la responde el destinatario, rechazar la descarta; mensajes de error |
| DI-07 | **Paz con conquistas:** reluctancia de la IA con la fórmula documentada; el ensayo no cambia nada (3 celdas para el jugador, 2 para la IA 1, 1 suelta que no se concede); al firmar exactamente 5 celdas cambian de dueño, se avisa para repintarlas, no queda ocupación ni guerra, empieza la tregua, historial y texto; lo traspasado cuenta como propio |
| DI-08 | **Paz blanca:** el ensayo no traspasa nada, ningún propietario cambia, las 6 ocupaciones se liberan (y se avisa para repintar), fin de guerra y tregua, mensaje; no revierte la tierra libre conquistada antes |
| DI-09 | **Guerras independientes:** la paz blanca con la IA 1 deja intactas las ocupaciones, las bajas y la guerra con la IA 2; después la paz con conquistas con la IA 2 traspasa solo lo suyo |
| DI-10 | **Pagos:** pagan la IA o el jugador; el dinero se transfiere (no se crea ni destruye); pagar de más se rechaza sin cambios; pagar exactamente todo deja 0; una propuesta pendiente no toca saldos hasta aceptarse; nunca negativos |
| DI-11 | **Atomicidad:** si el pagador gasta su dinero entre la oferta y la respuesta, aceptar falla sin cambiar nada (ni territorio, ni ocupaciones, ni saldos, ni ofensivas, que siguen activas) y la propuesta se conserva; con dinero otra vez se firma; aceptar una propuesta cuya guerra ya terminó falla sin cambios |
| DI-12 | **Paz y ofensivas:** firmar detiene solo las ofensivas entre ambas naciones (la dirigida a otra sigue), soldados, reservas y ocupaciones de la otra guerra coherentes, la propiedad no cambia con detener y reanudar, y la ofensiva detenida no puede reanudarse (tregua) |
| DI-13 | **Tregua:** duración configurada y simétrica; `plan_attack`, `launch_attack` (jugador e IA, desde el mismo o desde otro punto) y `start_offensive` la respetan sin crear frentes ni gastar soldados ni declarar guerra; cuenta atrás con el reloj; expira justo al terminar y entonces se puede atacar con una guerra nueva y registro nuevo; no protege a terceras naciones |
| DI-14 | **IA, decisión:** una IA ganadora rechaza (con mensaje), acepta justo en el límite (pagando 60) y contraoferta pagando 60 cuando le falta 1; aceptar o rechazar la contraoferta; el cansancio (31 ticks, 20 y 40 bajas) la acerca a la paz; una IA que pierde acepta pagar y contraoferta o rechaza si pide demasiado; contraoferta imposible de pagar → rechazo o paz blanca; sin soldados no divide por cero |
| DI-15 | **IA, propuestas:** propone sola al primer tick (paz blanca si ceder celdas no le conviene), no se repite, respeta el intervalo tras ser rechazada, caduca y se sustituye sin acumularse, aceptarla firma; margen exacto (−14 no, −15 sí); la IA ganadora no ofrece la paz; las guerras entre IA no generan propuestas; en pausa ni propone ni caduca |
| DI-16 | **Panel de diplomacia:** controles, textos puros, aparece con la guerra, el deslizador de pago nunca supera el saldo, proponer paz blanca firma y muestra la tregua con su cuenta atrás y desaparece al acabar; propuesta entrante con Aceptar/Rechazar; en pausa se desactiva y avisa |
| DI-17 | **Pantalla:** botón de pausa e indicador; en pausa no pasa el tiempo ni cambia la economía y se puede seleccionar y consultar; no se funda; la barra espaciadora pausa; reanudar restaura |
| DI-18 | Determinismo: dos partidas idénticas con ataques, un tratado y 38 ticks dan el mismo estado |
| DI-19 | Las suites anteriores, sus escenas F6 y los archivos del hito (y del prototipo de provincias) siguen presentes |

Las pruebas CB-20 y CB-23 (hito 9) se corrigieron en este hito: comparan los píxeles de la imagen con tolerancia de cuantización (`1/255 + 0.0005`), y siguen comprobando que un color incorrecto, una ocupación sin dibujar o una celda vecina desfasada se detectan.

| ID | Pendiente (manual en Godot) |
|---|---|
| M-80 | Ejecutar `test_diplomacy.gd` (o F6 en `run_diplomacy_tests.tscn`) y confirmar 19 PASS; repetir `test_combat.gd` (25) y `test_military.gd` y las demás suites |
| M-81 | F5: el panel «EJÉRCITO» y, con guerra, el panel «DIPLOMACIA» caben en la columna izquierda (con barra de desplazamiento) sin tapar el mapa; el botón «Pausa» y el indicador «EN PAUSA» se ven arriba a la izquierda |
| M-82 | Flujo de ataque: pulsar la celda enemiga o libre pegada a tu frontera elige origen y dirección; el deslizador y 25/50/75/100 % cambian la cantidad; «Atacar» → «Detener» → «Continuar»; «Ajustar» y «Retirar frente»; ¿se entiende sin saber qué es un sector? |
| M-83 | Hacer una guerra real (conquistar tierra libre hasta tocar a otra nación), ocupar celdas y proponer la paz con conquistas y la blanca: ¿las celdas cambian de color como se espera, desaparece el tablero y se repinta el mapa y la leyenda? |
| M-84 | Pagos y respuesta de la IA: el mensaje de aceptar / rechazar / contraoferta es claro; aceptar o rechazar una contraoferta o una propuesta de la IA |
| M-85 | Tregua: tras la paz, intentar atacar a esa nación (el botón se desactiva y se explica) y comprobar que tras 60 s se puede otra vez |
| M-86 | Pausa: con ofensivas, ciudades y población en marcha, pausar y comprobar que nada se mueve (cifras, mapa, tiempo de tregua) y que el panel sigue respondiendo; reanudar |
| M-87 | Ritmo: ¿es razonable la tregua de 60 s?, ¿la IA propone la paz demasiado pronto o tarde?, ¿las respuestas de la IA parecen coherentes con la situación? |

### Hito 11 — Gran reforma de jugabilidad (escritas, sin ejecutar en Godot)
Archivo `tests/gameplay_tests.gd` (ejecutor `tests/test_gameplay.gd`, escena F6 `tests/run_gameplay_tests.tscn`). Mapas controlados (duelo y abierto) salvo GP-15…GP-17, que usan la partida por defecto con la IA activada. La IA de los mundos controlados se crea desactivada y las pruebas llaman a `decide()`.
| ID | Qué comprueba |
|---|---|
| GP-01 | Trabajadores empleados: 30 empleados producen 12 de dinero y 9 de recursos en 10 ticks; con 60 trabajadores y 30 puestos, lo mismo (techo) pero más consumo; más nivel = más puestos; una ciudad ocupada no da puestos; balance neto coherente |
| GP-02 | Déficit por exceso de soldados (30 + 80): desmovilizar 50 lo corrige en 10 ticks (el mundo de control sigue en déficit); validaciones de `demobilize`; sin negativos |
| GP-03 | Prioridad: sin dinero no se cobra ni acelera; con 5 de dinero se cobran 5 ticks y la ciudad gana 1 punto de nivel extra por tick; validaciones de `add_growth` |
| GP-04 | Frente ancho en expansión: la franja prevista (columna de 9 celdas) es la conquistada; con 3 soldados, 3 celdas; avanza columna a columna, nunca más de 12 celdas por avance, y se detiene en el agua (225 celdas); no salta una columna de agua |
| GP-05 | Una expansión que llega a otra nación se detiene (`STOP_CONTACT`) sin guerra ni ocupación; la previsión lo avisa; reanudar es un ataque explícito que declara la guerra |
| GP-06 | Combate con frente ancho: un enfrentamiento por avance, las 6 celdas previstas se ocupan, las bajas son las previstas, la propiedad no cambia y el registro de guerra anota bajas y ocupaciones; derrota prevista = derrota real |
| GP-07 | Los soldados de una ofensiva activa no defienden; un frente detenido vuelve a defender; `attacks_against` lista la amenaza |
| GP-08 | Bonificación de ciudad: misma defensa local, ×1,8 junto a la ciudad y ×1,2 lejos; 6 atacantes ganan lejos y pierden junto a ella |
| GP-09 | Liberación: la celda propia ocupada es objetivo contra el ocupante; `suggest_front` propone el frente; se libera sin cambiar propietarios |
| GP-10 | IA defensiva: atacada con 10 y con 5 en reserva, retira su expansión; no crea soldados; sube el reparto de soldados |
| GP-11 | IA ofensiva: en guerra y con ventaja ataca con el 70 % de sus soldados libres y previsión de victoria; débil, no ataca al jugador; retira un frente derrotado |
| GP-12 | IA y treguas: con tregua no declara la guerra; sin tregua (y tras el plazo de gracia) la declara y avisa; antes del plazo, nunca |
| GP-13 | Dos IA en guerra igualada y larga hacen la paz (propuesta, aceptación, tregua y aviso); una IA sin recursos, tras los ticks necesarios para que su ejército quede sin pagar (`ceil(1000 / (6 · SOLDIER_UPKEEP_MILLI))`), está en déficit y se cansa antes |
| GP-14 | Tratados con el frente ancho: una oferta imposible no cambia nada; la IA 1, derrotada, ya propuso sola una paz blanca (una sola pendiente por pareja) y el jugador la rechaza sin cambiar la guerra ni las ocupaciones; la paz con conquistas traspasa las 6 celdas, termina la guerra, detiene la ofensiva y empieza la tregua; la tregua bloquea `plan_attack` y deja de hacerlo al expirar |
| GP-15 | Partida por defecto con IA, 240 ticks: sin negativos ni asignaciones imposibles; todas las IA amplían territorio; alguna funda una ciudad; el jugador pasivo no gana ni pierde territorio oficial |
| GP-16 | La pausa detiene también a la IA (nada cambia en 200 s de pausa) y al reanudar todo vuelve a moverse |
| GP-17 | Determinismo: dos partidas por defecto con IA, 200 ticks, acaban en el mismo estado |
| GP-18 | `suggest_front` (celda lejana, vecina, interior, agua) y textos nuevos (defensa, amenazas, franja, empleo, balance con signo, desmovilizar); la pantalla crea la IA activada y muestra sus avisos; controles nuevos presentes |
| GP-19 | Las suites anteriores y los archivos del hito existen |

**Cambios en suites anteriores por las reglas nuevas (no se redujo ninguna comprobación de lógica):**
- `combat_tests.gd` y `diplomacy_tests.gd`: sus mundos controlados fijan `front_half_width = 0` (avance de una celda del hito 9) para conservar sus escenarios celda a celda; las pantallas desactivan la IA (`screen.ai.enabled = false`). CB «estado de guerra»: la expansión que llega a la IA 1 ya no declara la guerra (se detiene con `STOP_CONTACT`); se añadió la orden explícita y se conservó la comprobación de la ocupación. CB «economía»: el dinero del jugador suma ahora lo de sus trabajadores.
- `population_tests.gd`: la prioridad cuesta dinero y acelera el nivel (se comprueban el coste exacto y el nivel; los nacidos siguen siendo 3 y 6); el coste del mantenimiento suma lo producido por los empleados; la prueba de prioridad de mantenimiento usa 60 soldados (no 40) y la de recuperación del déficit 40 + 60 (no 50 + 50) porque los trabajadores ya producen; «comportamiento anterior» compara dinero y recursos con fórmulas exactas (ciudades + trabajadores − mantenimiento) y ya no usa la prioridad; la pantalla desactiva la IA.
- `military_tests.gd`: pulsar una celda ajena lejana ahora propone un frente desde la frontera más cercana (antes limpiaba la elección); la pantalla desactiva la IA.
- `city_economy_tests.gd`: el HUD muestra el balance real (`net_economy_summary`).

### Construcciones (pendiente; antes «hito 11»)
| ID | Qué comprobar |
|---|---|
| T-64 | Construcciones: se rechazan sin dinero suficiente |

### Reclutamiento forzoso (antes «hito 11», absorbido por el hito 7)
La movilización progresiva se prueba en PO-11, PO-12, PO-13 y PO-17. Las penalizaciones definitivas (D13) se probarán cuando se definan.

### Hito 12 — IA
La IA estratégica básica del hito 11 ya se prueba en GP-10…GP-17 (órdenes válidas con las mismas reglas que el jugador, determinismo y partida larga sin errores). T-90…T-92 quedan cubiertas por ellas; lo que se añada al redefinir el hito 12 tendrá pruebas propias.

### Hito 13 — Victoria, derrota y reinicio
| ID | Qué comprobar |
|---|---|
| T-100 | Detección de victoria y derrota según D11 |
| T-101 | Tras el final se rechazan órdenes |
| T-102 | Reinicio restaura el estado inicial exacto |

### Rendimiento y regresión
- Medir en el PC del propietario el coste de un paso de simulación y de una actualización visual con el tamaño de mapa elegido (D1); registrar los números reales en este documento. No se fijan umbrales hasta tener mediciones.
- Cada hito mantiene pasando las pruebas de los hitos anteriores que sigan vigentes.
- Antes de ampliar el sistema de pruebas, evaluar extraer un ejecutor común para evitar repetir el código base de cada archivo de pruebas (hoy se repite en dos archivos).

## Estado del hito 3 (datos del territorio)

| Comprobación | Cómo | Estado |
|---|---|---|
| Algoritmo del mapa inicial (límites de las pruebas) | Réplica en Python con la misma aritmética entera | Ejecutado en la nube; no sustituye a Godot |
| Búsqueda de referencias a provincias en los archivos nuevos | `grep` | Ejecutado: sin coincidencias |
| `tests/test_territory_grid.gd` | Comando de arriba | Ejecutado por el propietario en Godot 4.7.2: 21 PASS, 0 FAIL |
| Compatibilidad del script con Godot 4.7 (sintaxis, tipado) | Revisión estática | Hecha por lectura; **sin compilar** |

## Estado del hito 4 (vista pixelada)

| Comprobación | Cómo | Estado |
|---|---|---|
| Premisas de las pruebas V-02/V-04 (existen un tramo interior de 6x3, costa sin reclamar, naciones con interior y borde) y vista previa del diseño | Réplica en Python de la generación del mapa y de las reglas de color/frontera | Ejecutada en la nube (tierra 27.324, 4 territorios de 441 celdas, 64 de borde y 377 de interior cada uno); **no sustituye a Godot** |
| `tests/test_territory_map_view.gd` | `godot --headless --path . --script res://tests/test_territory_map_view.gd` | **Pendiente** en Godot (PC del propietario) |
| Arranque de la escena y aspecto | F5 en el editor | **Pendiente** (validación visual del propietario) |
| Compatibilidad con Godot 4.7 (sintaxis, tipado) | Revisión estática | Hecha por lectura; **sin compilar** |

## Estado del hito 5 (conquista territorial)

| Comprobación | Cómo | Estado |
|---|---|---|
| `tests/test_territory_conquest.gd` (18 pruebas) | `godot --headless --path . --script res://tests/test_territory_conquest.gd` | **Pendiente** en Godot (PC del propietario) |
| Pruebas de los hitos 3 y 4 tras el cambio | Comandos de arriba | Hito 3: confirmado por el propietario **antes** de este cambio (21 PASS); hay que repetirlo. Hito 4: sin ejecutar |
| Compatibilidad con Godot 4.7 (sintaxis, tipado) | Revisión estática | Hecha por lectura; **sin compilar** |
| Escenarios de las pruebas C-01…C-15 (códigos de error esperados sobre el mapa controlado) | Réplica en Python de las reglas de validación (21 casos) | Ejecutada en la nube: 21/21 coinciden; **no es una prueba de Godot ni la sustituye** |

## Estado del hito 5b (naciones y HUD)

| Comprobación | Cómo | Estado |
|---|---|---|
| `tests/test_territory_hud.gd` (10 pruebas) | `godot --headless --path . --script res://tests/test_territory_hud.gd` | **Pendiente** en Godot (PC del propietario) |
| Aspecto de la leyenda y del resumen | F5 en el editor | **Pendiente** (validación visual del propietario) |
| Pruebas de los hitos 3, 4 y 5 tras el cambio | Comandos de arriba | Hito 3 confirmado antes de este cambio (21 PASS); hay que repetirlo. Hitos 4 y 5: sin ejecutar |
| Compatibilidad con Godot 4.7 (sintaxis, tipado) | Revisión estática | Hecha por lectura; **sin compilar** |

## Estado del hito 6 (ciudades y economía básica)

| Comprobación | Cómo | Estado |
|---|---|---|
| Validación local previa de los hitos 3–5b | Suites ejecutadas por el propietario | 21 + 14 + 18 + 10 = 63 PASS, comunicado por el propietario (Godot 4.7.2); **no ejecutado por Claude** |
| Clic en una celda muestra su información | Comprobación manual del propietario | Comunicada por el propietario |
| `tests/test_city_economy.gd` (21 pruebas) | `godot --headless --path . --script res://tests/test_city_economy.gd` | **21 PASS** ejecutadas por el propietario en Godot 4.7.2 (tras corregir una posición inválida en la prueba de fundación; comunicado por el propietario) |
| Suites anteriores tras el cambio | Comandos de arriba | Ejecutadas por el propietario (63 PASS); el hito 6 solo añade a `territory_map_view.gd` (señal `cell_clicked`, `selection_enabled`), `territory_info_panel.gd`, `territory_screen.gd` y `territory_main.tscn` |
| Compatibilidad con Godot 4.7 (sintaxis, tipado) | Revisión estática | Hecha por lectura; **sin compilar** (no hay Godot en la nube) |
| Aspecto y manejo (M-41…M-47) | F5 en el editor | El propietario comprobó que las ciudades aparecen y crecen visualmente; el resto (M-42…M-47) no se ha registrado |

## Estado del hito 7 (población, trabajadores y mantenimiento)

| Comprobación | Cómo | Estado |
|---|---|---|
| Validación local previa (hitos 3–6) | Suites ejecutadas por el propietario | 21 + 14 + 18 + 10 = 63 PASS y 21 PASS de ciudades (tras corregir la posición de una prueba), comunicado por el propietario (Godot 4.7.2); **no ejecutado por Claude** |
| `tests/test_population.gd` (24 pruebas) | `godot --headless --path . --script res://tests/test_population.gd` | **24 PASS** ejecutadas por el propietario en Godot 4.7.2 (comunicado por el propietario) |
| Suites anteriores tras el cambio | Comandos de «Cómo ejecutar las pruebas» | Repetidas por el propietario (108 PASS en total); el hito 7 añadió a `economy.gd` (`spend_resources`), `city_manager.gd` (señal `ticked`), `territory_info_panel.gd`, `territory_screen.gd` y `territory_main.tscn` |
| Réplica en Python de la lógica de población | Escrita para contrastar cifras y equilibrio | Ejecutada en la nube; **no es una prueba de Godot ni la sustituye** |
| Compatibilidad con Godot 4.7 (sintaxis, tipado) | Revisión estática | Hecha por lectura; **sin compilar** (no hay Godot en la nube) |
| Aspecto y manejo (M-51…M-57) | F5 en el editor | **Pendiente** (validación del propietario) |

## Estado del hito 8 (organización militar)

| Comprobación | Cómo | Estado |
|---|---|---|
| Validación local previa (hitos 3–7) | Suites ejecutadas por el propietario | 21 + 14 + 18 + 10 + 21 + 24 = 108 PASS, comunicado por el propietario (Godot 4.7.2); **no ejecutado por Claude** |
| `tests/test_military.gd` (21 pruebas) | `godot --headless --path . --script res://tests/test_military.gd` | **Pendiente** en Godot (PC del propietario); ampliada y adaptada en la simplificación de la interfaz |
| Suites anteriores tras el cambio | Comandos de «Cómo ejecutar las pruebas» | **Pendiente** de repetir; el hito 8 solo cambia `territory_screen.gd` y `territory_main.tscn` (nuevos nodos, creación de `Military` y conexiones; el área del mensaje de fundación se acortó de 144 a 46 px de alto (3 líneas) y el panel militar empieza en y = 166); `Population`, `Economy`, `CityManager` y `TerritoryGrid` no se tocan |
| Compatibilidad con Godot 4.7 (sintaxis, tipado) | Revisión estática | Hecha por lectura; **sin compilar** (no hay Godot en la nube). Sin réplicas en otros lenguajes |
| Aspecto y manejo (M-61…M-65) | F5 en el editor | **Pendiente** (validación del propietario) |

## Estado del hito 9 (ataques, combate y ocupación)

| Comprobación | Cómo | Estado |
|---|---|---|
| Base de partida | Rama `claude/ecstatic-bardeen-1de9nl` en el commit `7c13199` (hito 8 simplificado); el propietario probó a mano el sistema militar simplificado y confirmó que funciona | Comunicado por el propietario; **no verificado por Claude** |
| `tests/test_combat.gd` (25 pruebas) | `godot --headless --path . --script res://tests/test_combat.gd` | **Pendiente** en Godot (PC del propietario) |
| Suites anteriores tras el cambio | Comandos de «Cómo ejecutar las pruebas» | **Pendiente** de repetir. El hito 9 cambia `city_manager.gd` (ocupación opcional, error de fundación nuevo, producción suspendida), `population.gd` (`remove_soldiers`), `military.gd` (`apply_casualties`), `territory_map_view.gd` (color de ocupación opcional), `sector_layer_view.gd`, `city_layer_view.gd`, `territory_info_panel.gd`, `military_panel.gd`, `territory_screen.gd` y `territory_main.tscn`; **no se cambió ninguna aserción** de las suites existentes y los textos de la lista y el detalle del panel militar siguen siendo los mismos cuando no hay ataque |
| Revisión estática de las pruebas | Lectura línea a línea (tipos explícitos en lugar de `:=` con `Variant`, cifras recalculadas a mano) | Hecha; **sin compilar** (no hay Godot en la nube) |
| Réplica en Python de las fórmulas y de los escenarios de victoria, derrota, invasión completa y dos ofensivas simultáneas | Escrita para contrastar las cifras esperadas de las pruebas | Ejecutada en la nube; **no es una prueba de Godot ni la sustituye**; el resto de escenarios (economía, mapa, pantalla, bordes) solo se revisaron a mano |
| Aspecto y manejo (M-71…M-76) | F5 en el editor | **Pendiente** (validación del propietario) |

## Estado del hito 10 (guerra, diplomacia y jugabilidad simplificada)

| Comprobación | Cómo | Estado |
|---|---|---|
| Base de partida | Rama `claude/ecstatic-bardeen-1de9nl` en el commit `827cafa` (hito 9). El propietario ejecutó `test_combat.gd` en Godot 4.7.2: 23 de 25 PASS; fallaron CB-20 y CB-23 por comparar floats con píxeles `RGBA8` | Comunicado por el propietario; **no verificado por Claude** |
| `tests/test_diplomacy.gd` (19 pruebas) | `godot --headless --path . --script res://tests/test_diplomacy.gd` | **Pendiente** en Godot (PC del propietario) |
| `tests/test_combat.gd` (25 pruebas, CB-20 y CB-23 corregidas/reescritas) y `tests/test_military.gd` (pruebas de interfaz reescritas) | Comandos de «Cómo ejecutar las pruebas» | **Pendiente** de ejecutar en Godot |
| Suites anteriores tras el cambio | Comandos de «Cómo ejecutar las pruebas» | **Pendiente** de repetir. El hito 10 cambia `city_manager.gd` (pausa, `tick_count`, error de fundación en pausa), `war_state.gd` (registro por guerra, treguas, reloj opcional; `WarState.new()` sin argumentos sigue valiendo), `occupation.gd` (consultas y liberación por parejas, exportar/importar), `offensives.gd` (tregua, `plan_attack`, `launch_attack`, `stop_between`, `sector_near`, anotaciones de guerra), `military.gd` (mensajes), `military_panel.gd` (reescrito), `territory_screen.gd` y `territory_main.tscn` (columna de guerra, botón de pausa) y añade `diplomacy.gd`, `diplomacy_balance.gd` y `diplomacy_panel.gd`. Las suites de territorio, vista, conquista, HUD, ciudades y población no se tocan |
| Cambios en aserciones de suites existentes | Revisión del diff | Se **reescribieron** las pruebas de interfaz de CB y MI (`_test_screen`, `_test_texts`) porque los controles antiguos desaparecieron; se actualizaron los textos que cambiaron («Combate equilibrado», previsión compacta, estado con «Soldados N», «Último… · bajas a / b») y se añadió `STOP_TRUCE` a la lista de motivos; no se redujo ninguna comprobación de lógica |
| Revisión estática | Lectura línea a línea; tipos explícitos en lugar de `:=` con `Variant`; comprobación mecánica de paréntesis y sangrías | Hecha; **sin compilar** (no hay Godot en la nube) |
| Réplica en Python de las fórmulas de la IA y de los escenarios numéricos de DI-07, DI-14 y DI-15 | Escrita para contrastar las cifras esperadas | Ejecutada en la nube; **no es una prueba de Godot ni la sustituye**; el resto (mapas, pantalla, paneles) solo se revisó a mano |
| Aspecto y manejo (M-80…M-87) | F5 en el editor | **Pendiente** (validación del propietario) |

## Estado del hito 11 (gran reforma de jugabilidad)

| Comprobación | Cómo | Estado |
|---|---|---|
| Base de partida | Rama `claude/ecstatic-bardeen-1de9nl` en el commit `81efaa6` (hito 10), al día con el remoto | Comprobado por Claude (git) |
| Godot en el entorno | Búsqueda del ejecutable | **No disponible** en la nube: nada se ha compilado ni ejecutado |
| `tests/test_gameplay.gd` (19 pruebas) | `godot --headless --path . --script res://tests/test_gameplay.gd` | Primera ejecución del propietario: 17 PASS, 2 FAIL (GP-13, GP-14; preparación de las pruebas, corregida). **Nueva ejecución pendiente** en Godot (PC del propietario). GP-15…GP-17 ejecutan partidas de 200–240 ticks con IA: pueden tardar varios segundos |
| Suites anteriores tras el cambio | Comandos de «Cómo ejecutar las pruebas» | **Pendiente** de repetir. El hito 11 cambia `population.gd`, `city_manager.gd` (`add_growth`), `military.gd` (frentes de liberación), `offensives.gd` (frente ancho, objetivo, liberación, defensa, ciudad), `combat.gd` (bonificación opcional), `diplomacy.gd` (valoración), `sector_layer_view.gd`, los paneles y la pantalla, y añade `ai_controller.gd` y `ai_balance.gd` |
| Revisión estática | Lectura línea a línea; tipos explícitos en lugar de `:=` con `Variant` | Hecha; **sin compilar** |
| Réplica en Python de la economía (escenarios de GP-02, GP-03 y de las pruebas de población adaptadas) | Escrita para elegir y contrastar las cifras esperadas | Ejecutada en la nube; **no es una prueba de Godot ni la sustituye**; los escenarios de combate y de IA se calcularon a mano |
| Aspecto, manejo y diversión | F5 en el editor | **Pendiente** (validación del propietario): ritmo de expansión, presión de la IA, legibilidad de amenazas y previsión, rendimiento de las decisiones de la IA |
