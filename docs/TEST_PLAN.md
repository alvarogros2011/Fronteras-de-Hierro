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
godot --headless --path . --script res://tests/test_province_data.gd
godot --headless --path . --script res://tests/test_province_selection.gd
```

Cada archivo imprime PASS/FAIL por prueba y termina con código 0 (todo bien) o 1 (algún fallo). Alternativa sin terminal (pruebas del territorio): abrir `res://tests/run_territory_tests.tscn` en el editor de Godot y pulsar **F6**; la pantalla muestra PASS/FAIL, el número de correctas y el de fallidas. Las comprobaciones viven en `tests/territory_grid_tests.gd` y las usan tanto esa escena como el ejecutor headless `tests/test_territory_grid.gd`.

## Estado actual

| Elemento | Estado |
|---|---|
| Pantalla inicial, mapa de provincias y selección (validación visual) | Validado a mano por el propietario en Godot 4.7.2 / Windows |
| `tests/territory_grid_tests.gd` + ejecutores `tests/test_territory_grid.gd` (headless) y `tests/run_territory_tests.tscn` (F6) (hito 3, sistema nuevo) | Escritos. **Ejecución en Godot sin confirmar** |
| `tests/test_province_data.gd` | Escrito. **Ejecución en Godot sin confirmar** |
| `tests/test_province_selection.gd` | Escrito. **Ejecución en Godot sin confirmar** |
| Réplica en Python del algoritmo del mapa inicial (herramienta de diseño: tierra 27.324 celdas, 4 territorios de 441, sin adyacencias entre naciones, borde de agua) y de la lógica de provincias | Ejecutada en la nube; **no es una prueba de Godot ni la sustituye** |
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

### Hito 4 — Vista pixelada
| ID | Qué comprobar |
|---|---|
| T-10 | El color de cada píxel de la imagen corresponde al propietario de su celda |
| T-11 | Las celdas de frontera usan el tono de frontera |
| T-12 | Cambiar una celda actualiza solo esa celda y sus cuatro vecinas |
| T-13 | Conversión posición de ratón → celda correcta con el nodo movido, escalado o con zoom |
| T-14 | Medición de tiempo de actualización (manual, en el PC) |
| T-15 | Detección de frontera (`is_border`): celda de frontera si algún vecino ortogonal tiene otro propietario o es agua |
| M-10 | Visual: aspecto pixelado limpio, fronteras coherentes, sin provincias seleccionables |

### Hito 5 — Naciones y HUD
| ID | Qué comprobar |
|---|---|
| T-20 | Registro de naciones y territorios iniciales (la continuidad inicial ya la cubre G-12) |
| T-21 | El HUD muestra datos iguales a los del estado |

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
| `tests/test_territory_grid.gd` | Comando de arriba | **Pendiente** en Godot (PC del propietario) |
| Compatibilidad del script con Godot 4.7 (sintaxis, tipado) | Revisión estática | Hecha por lectura; **sin compilar** |
