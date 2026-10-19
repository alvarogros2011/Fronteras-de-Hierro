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
godot --headless --path . --script res://tests/test_province_data.gd
godot --headless --path . --script res://tests/test_province_selection.gd
```

Cada archivo imprime PASS/FAIL por prueba y termina con código 0 (todo bien) o 1 (algún fallo). Alternativa sin terminal (pruebas del territorio): abrir `res://tests/run_territory_tests.tscn` en el editor de Godot y pulsar **F6**; la pantalla muestra PASS/FAIL, el número de correctas y el de fallidas. Las comprobaciones viven en `tests/territory_grid_tests.gd` y las usan tanto esa escena como el ejecutor headless `tests/test_territory_grid.gd`. Las del hito 5b (naciones y HUD) siguen el mismo patrón: `tests/territory_hud_tests.gd`, `tests/test_territory_hud.gd` y `tests/run_hud_tests.tscn`. Las del hito 5 (conquista) siguen el mismo patrón: `tests/territory_conquest_tests.gd`, `tests/test_territory_conquest.gd` y `tests/run_conquest_tests.tscn`. Las del hito 4 siguen el mismo patrón: `tests/territory_map_view_tests.gd`, ejecutor headless `tests/test_territory_map_view.gd` y escena F6 `tests/run_view_tests.tscn`. Las del hito 6 (ciudades y economía): `tests/city_economy_tests.gd`, `tests/test_city_economy.gd` y `tests/run_city_tests.tscn`. Las del hito 7 (población y mantenimiento): `tests/population_tests.gd`, `tests/test_population.gd` y `tests/run_population_tests.tscn`. Las del hito 8 (organización militar): `tests/military_tests.gd`, `tests/test_military.gd` y `tests/run_military_tests.tscn`.

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
| `tests/military_tests.gd` + `tests/test_military.gd` + `tests/run_military_tests.tscn` (hito 8, 21 pruebas MI-01…MI-21) | Escritos. **Ejecución en Godot sin confirmar** (no hay Godot en la nube) |
| Pruebas de combate, ataques, IA | **No existen**: esas mecánicas no están implementadas |

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

### Simulación global, pausa y reloj (pendiente de redefinición; antes «hito 7»)
| ID | Qué comprobar |
|---|---|
| T-30 | Mismos pasos + misma semilla → mismo estado (hash) |
| T-33 | La pausa detiene el avance de toda la simulación; reanudar continúa |
| T-35 | Ningún paso de simulación cambia propietarios (la expansión automática está descartada) |

### Hito 9 — Construcciones y producción según trabajadores
| ID | Qué comprobar |
|---|---|
| T-61 | Producción de ciudades según nivel y trabajadores (si se decide D14) sin romper el equilibrio inicial del hito 7 |
| T-64 | Construcciones: se rechazan sin dinero suficiente |

### Hito 10 — Ejércitos y combate
(La asignación de soldados a sectores ya se prueba en MI-01…MI-21.)

| ID | Qué comprobar |
|---|---|
| T-70 | Ataques inválidos rechazados (según reglas que se definan) |
| T-71 | La previsión de ventaja coincide con el resultado (determinista) o con la distribución definida (con azar y semilla) |
| T-72 | Los números previstos de pérdidas y probabilidad son coherentes y reproducibles |
| T-73 | Destino de las ciudades en territorio conquistado (D12) |
| M-70 | Visual: la previsión es comprensible antes de confirmar el ataque |

### Hito 11 — (absorbido por el hito 7)
La movilización progresiva se prueba en PO-11, PO-12, PO-13 y PO-17. Las penalizaciones definitivas (D13) se probarán cuando se definan.

### Hito 12 — IA
| ID | Qué comprobar |
|---|---|
| T-90 | La IA solo emite órdenes válidas |
| T-91 | Determinismo: mismo estado y semilla → misma decisión |
| T-92 | Una simulación larga sin jugador no produce errores |

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
