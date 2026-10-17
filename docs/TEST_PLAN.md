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
godot --headless --path . --script res://tests/test_province_data.gd
godot --headless --path . --script res://tests/test_province_selection.gd
```

Cada archivo imprime PASS/FAIL por prueba y termina con código 0 (todo bien) o 1 (algún fallo). Alternativa sin terminal (pruebas del territorio): abrir `res://tests/run_territory_tests.tscn` en el editor de Godot y pulsar **F6**; la pantalla muestra PASS/FAIL, el número de correctas y el de fallidas. Las comprobaciones viven en `tests/territory_grid_tests.gd` y las usan tanto esa escena como el ejecutor headless `tests/test_territory_grid.gd`. Las del hito 5b (naciones y HUD) siguen el mismo patrón: `tests/territory_hud_tests.gd`, `tests/test_territory_hud.gd` y `tests/run_hud_tests.tscn`. Las del hito 5 (conquista) siguen el mismo patrón: `tests/territory_conquest_tests.gd`, `tests/test_territory_conquest.gd` y `tests/run_conquest_tests.tscn`. Las del hito 4 siguen el mismo patrón: `tests/territory_map_view_tests.gd`, ejecutor headless `tests/test_territory_map_view.gd` y escena F6 `tests/run_view_tests.tscn`.

## Estado actual

| Elemento | Estado |
|---|---|
| Pantalla inicial, mapa de provincias y selección (validación visual) | Validado a mano por el propietario en Godot 4.7.2 / Windows |
| `tests/territory_grid_tests.gd` + ejecutores `tests/test_territory_grid.gd` (headless) y `tests/run_territory_tests.tscn` (F6) (hito 3, sistema nuevo) | Ejecutados a mano por el propietario en Godot 4.7.2: **21 PASS, 0 FAIL** |
| `tests/territory_map_view_tests.gd` + `tests/test_territory_map_view.gd` + `tests/run_view_tests.tscn` (hito 4, 14 pruebas V-01…V-14) | Escritos. **Ejecución en Godot sin confirmar** (no hay Godot en la nube) |
| `tests/test_province_data.gd` | Escrito. **Ejecución en Godot sin confirmar** |
| `tests/test_province_selection.gd` | Escrito. **Ejecución en Godot sin confirmar** |
| Réplica en Python del algoritmo del mapa inicial (herramienta de diseño: tierra 27.324 celdas, 4 territorios de 441, sin adyacencias entre naciones, borde de agua) y de la lógica de provincias | Ejecutada en la nube; **no es una prueba de Godot ni la sustituye** |
| `tests/territory_conquest_tests.gd` + `tests/test_territory_conquest.gd` + `tests/run_conquest_tests.tscn` (hito 5, 18 pruebas C-01…C-18) | Escritos. **Ejecución en Godot sin confirmar** (no hay Godot en la nube) |
| `tests/territory_hud_tests.gd` + `tests/test_territory_hud.gd` + `tests/run_hud_tests.tscn` (hito 5b, 10 pruebas H-01…H-10) | Escritos. **Ejecución en Godot sin confirmar** |
| Pruebas del sistema de territorio, ciudades, población, recursos, ejércitos, IA | **No existen**: esas mecánicas no están implementadas |

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

### Hito 6 — Simulación y expansión
| ID | Qué comprobar |
|---|---|
| T-30 | Mismos pasos + misma semilla → mismo estado (hash) |
| T-31 | La expansión solo reclama celdas de tierra adyacentes; no crea territorio desconectado |
| T-32 | Conservación: total de celdas y de celdas por propietario coherentes |
| T-33 | La pausa detiene el avance; reanudar continúa |
| T-34 | Comprobación reutilizable de continuidad del territorio de una nación (detecta enclaves separados) |

### Hito 7 — Ciudades
| ID | Qué comprobar |
|---|---|
| T-40 | Fundación válida e inválida según las condiciones de D4 |
| T-41 | El tamaño inicial de una ciudad es el definido |
| T-42 | Fundar o crecer una ciudad no cambia propietarios ni fronteras; expandir fronteras no cambia ciudades |
| T-43 | Dos ciudades no ocupan la misma celda |

### Hito 8 — Población y crecimiento urbano
| ID | Qué comprobar |
|---|---|
| T-50 | Cambiar el reparto trabajadores/soldados solo afecta a la población nueva |
| T-51 | El reparto suma siempre el 100 % y se conserva la población total |
| T-52 | El crecimiento por unidad de población es decreciente con el tamaño |
| T-53 | Subida automática de nivel al cruzar umbrales; después sigue creciendo más despacio |
| T-54 | La ciudad no crece sin trabajadores asignados |

### Hito 9 — Dinero y recursos
| ID | Qué comprobar |
|---|---|
| T-60 | Existen exactamente dos recursos (dinero y recursos) |
| T-61 | Producción de ciudades según nivel y trabajadores |
| T-62 | Mantenimiento de trabajadores y soldados con recursos |
| T-63 | Comportamiento definido cuando no alcanzan los recursos; saldos sin valores negativos no previstos |
| T-64 | Construcciones: se rechazan sin dinero suficiente |

### Hito 10 — Ejércitos y combate
| ID | Qué comprobar |
|---|---|
| T-70 | Ataques inválidos rechazados (según reglas que se definan) |
| T-71 | La previsión de ventaja coincide con el resultado (determinista) o con la distribución definida (con azar y semilla) |
| T-72 | Los números previstos de pérdidas y probabilidad son coherentes y reproducibles |
| T-73 | Destino de las ciudades en territorio conquistado (D12) |
| M-70 | Visual: la previsión es comprensible antes de confirmar el ataque |

### Hito 11 — Reclutamiento forzoso
| ID | Qué comprobar |
|---|---|
| T-80 | Solo se convierte el porcentaje elegible |
| T-81 | La población total se conserva |
| T-82 | Las consecuencias definidas en D13 se aplican |

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
