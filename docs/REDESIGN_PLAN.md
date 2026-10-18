# Plan de rediseño — Fronteras de Hierro

Documento técnico y de planificación. **No hay código nuevo asociado.** Las decisiones de diseño abiertas (D1, D2…) están en `docs/GDD.md` §12; aquí solo se indica cuándo bloquean el trabajo. Las cifras de rendimiento citadas son estimaciones razonadas: **no se ha medido nada** (no hay Godot en la nube).

## 1. Resumen de la nueva visión

| Antes (prototipo, legado) | Ahora |
|---|---|
| 14 provincias poligonales seleccionables | Territorio pixelado continuo por nación, sin provincias seleccionables |
| 2 bandos (jugador/enemigo) | Varias naciones |
| Ataques entre provincias con un número de tropas | Expansión de fronteras, ciudades, población y ejércitos aún por definir |
| Sin economía | Dos recursos: dinero y recursos |
| Sin ciudades | Ciudades como agrupaciones de píxeles que crecen cada vez más despacio y suben de nivel |
| Sin población | Trabajadores y soldados; control deslizante para la población nueva; reclutamiento forzoso |

Referencia: experiencia general de OpenFront (territorio por celdas, expansión, ataques), con interfaz limpia y mapa como protagonista. Sin soldados individuales ni número global único de ejército.

Sin decidir: modelo de ejércitos (D7), combate (D8), mecánica diferenciadora (D9) y los números de economía y población.

## 2. Evaluación del código existente

El prototipo tiene unas 330 líneas de código de juego y unas 450 de pruebas. Ninguna parte conoce el concepto de "celda" ni de "nación".

| Elemento | Veredicto | Motivo |
|---|---|---|
| `project.godot` (1280x720, `canvas_items`, Compatibility, filtro `nearest`) | **Reutilizar** | Ya es adecuado para pixel art. La resolución base podría revisarse según D1 |
| Estructura `scenes/ scripts/ tests/ docs/` | **Reutilizar** | Suficiente |
| Patrón de pruebas (`SceneTree`, PASS/FAIL, código de salida) | **Reutilizar** | Sin plugins; sirve para toda la lógica nueva. Refactor menor: extraer un ejecutor común cuando haya un tercer archivo |
| Patrón "módulo de datos sin nodos + `preload` sin `class_name`" | **Reutilizar la idea** | Funciona en headless sin abrir el editor |
| Patrón señal `selection_changed` → panel | **Reutilizar la idea** | Comunicación lógica→UI sin dependencias directas |
| `ProvinceMap.make_input_local` + conversión a local | **Reutilizar la idea** | Sirve igual para ratón → celda |
| Aspecto del panel (StyleBoxFlat, colores) y reglas de `mouse_filter` | **Reutilizar** | Base del HUD limpio |
| `main.tscn` (título, mapa, panel lateral) | **Refactorizar** | Cambia el nodo del mapa y el contenido del panel; el reparto de capas Control/Node2D se puede conservar |
| `province_map.gd` | **Refactorizar y, en la práctica, sustituir** | Mezcla dibujo, selección y leyenda; hay que separar vista del territorio, selección y HUD |
| `province_info_panel.gd` | **Refactorizar** | El patrón `build_info` estático + `show_*` sirve para ciudades y naciones; el contenido (vecinas) deja de existir |
| `province_data.gd` (provincias, polígonos, vecinos, propietarios `player/enemy`) | **Dejará de usarse** | Las provincias desaparecen; dos propietarios fijos no sirven para varias naciones |
| `test_province_data.gd` | **Dejará de usarse** | Prueba datos que se retirarán. Se reaprovechan las ideas: conectividad, integridad y determinismo |
| `test_province_selection.gd` | **Dejará de usarse** (casi todo) | Se reaprovecha la idea de pruebas de borde y de transformación del nodo |

**No se elimina nada ahora.** El prototipo permanece intacto y sigue arrancando con F5 mientras se construye el sistema nuevo. Decisión del propietario: su retirada se decidirá cuando el nuevo mapa visual y su interacción hayan sido validados manualmente en su PC (D16). Opciones: (a) borrarlo (el historial de git ya lo conserva), (b) moverlo a una carpeta `legacy/` o (c) dejarlo en una rama.

## 3. Enfoques técnicos para el territorio pixelado

Requisitos: territorio continuo por nación; fronteras coherentes aunque cambie el propietario; mapas con decenas o cientos de miles de celdas; lógica comprobable sin nodos; ciudades separadas de las fronteras; aspecto pixelado; sin optimización prematura.

### Enfoque A — Polígonos por nación (vectorial)
Convertir cada territorio en polígonos (p. ej. con `Geometry2D`) y dibujarlos.
- Pros: bordes nítidos a cualquier zoom; reutiliza el dibujo actual.
- Contras: cada cambio de propietario exige recalcular contornos (fusión, agujeros, islas); no da el aspecto pixelado buscado; difícil de probar y de depurar; escala mal.
- **Descartado.**

### Enfoque B — `TileMapLayer` (una celda = un tile)
- Pros: nativo de Godot; maneja mapas grandes por trozos; detección de celda con `local_to_map`.
- Contras: los bordes coherentes requieren elegir el tile según los vecinos (atlas con variantes de borde, que hay que dibujar); el estado queda duplicado entre el tilemap y los datos; cambiar celdas una a una por GDScript es más lento de lo deseable en grandes cambios; poca libertad para el estilo visual tipo OpenFront.
- Viable, pero con más arte y más complejidad de la necesaria.

### Enfoque C — Cuadrícula en arrays + imagen en CPU (`Image` + `ImageTexture`)
Los datos viven en arrays empaquetados (`PackedByteArray`): terreno y propietario por celda. La vista tiene una `Image` de 1 píxel por celda, convertida en `ImageTexture` y mostrada en un `Sprite2D` ampliado con filtro `nearest`. Cuando cambia una celda, se repinta ella y sus cuatro vecinas (la frontera se decide comparando con los vecinos) y se marca la textura como sucia.
- Pros: es el modelo más cercano a cómo funcionan juegos tipo OpenFront; datos totalmente separados de la vista (probables sin nodos); fronteras siempre coherentes porque salen de comparar vecinos; sin arte adicional; coste de memoria mínimo; cambios locales baratos.
- Contras: hay que mantener la lógica de repintado local; subir la textura entera cuando hay muchos cambios en un mismo paso cuesta algo en mapas muy grandes; el bucle de repintado se escribe en GDScript (más lento que C++), aunque solo recorre celdas modificadas.

### Enfoque D — Cuadrícula en arrays + shader (GPU)
Mismos datos que C, pero se sube el mapa de propietarios como textura de un canal y un shader decide color y bordes leyendo los vecinos y una paleta.
- Pros: el mejor rendimiento; el repintado deja de ser coste de CPU; bordes y efectos (resaltado de una nación) casi gratis.
- Contras: más complejidad (shader, paleta en textura); difícil de verificar desde la nube; más difícil de probar con pruebas automáticas; riesgo de problemas visuales que solo se ven en el PC del propietario. Es una optimización razonable *después* de que C funcione.

### Comparación

| Criterio | A Polígonos | B TileMapLayer | C Arrays + Image (CPU) | D Arrays + shader |
|---|---|---|---|---|
| Aspecto pixelado | Malo | Bueno (con arte) | Bueno | Bueno |
| Fronteras coherentes al cambiar dueño | Difícil | Media (variantes de tile) | Fácil (comparar vecinos) | Fácil |
| Escala a muchas celdas | Mala | Buena | Buena si solo se repintan cambios | Muy buena |
| Lógica probable sin nodos | Media | Mala (estado en el nodo) | **Excelente** | Excelente (datos), media (vista) |
| Arte necesario | Ninguno | Atlas de bordes | **Ninguno** | Ninguno |
| Complejidad inicial | Media | Media | **Baja** | Media-alta |
| Verificable desde la nube | Parcial | Parcial | **Alta (la imagen se puede comprobar píxel a píxel)** | Baja |

> **Actualización (hito 3):** la parte de datos de esta arquitectura ya está implementada en `scripts/world/territory_grid.gd` con valores provisionales: 320x180, `PackedByteArray` de terreno (agua/tierra) y de propietario (`OWNER_NONE`, jugador y tres IA), sin dibujo. La detección de fronteras y la comprobación de continuidad se aplazaron a los hitos 4 y 6. Siguen siendo propuestas técnicas, no preferencias confirmadas.

## 4. Arquitectura recomendada

**Recomendación: Enfoque C**, con el Enfoque D como optimización futura si las mediciones en el PC lo justifican. La vista del territorio se mantiene detrás de una interfaz pequeña (`refresh_cells`, `world_to_cell`) para que cambiar de C a D no toque la lógica.

### Datos del territorio
- `TerritoryGrid` (`RefCounted`, sin nodos): `width`, `height`, `terrain: PackedByteArray` (tierra/agua u otros tipos según D1), `owner: PackedByteArray` (0 = sin propietario; 1..N = nación). Índice de celda = `y * width + x`.
- Operaciones previstas: consultar/cambiar terreno y propietario, vecinos ortogonales, `is_border(cell)`, recuento por nación, comprobación de continuidad. Emite una lista de celdas modificadas para que la vista repinte solo esas.
- Una celda de agua no tiene propietario.

### Vista
- `TerritoryView` (`Node2D`): una `Image` (1 píxel por celda) + `ImageTexture` + `Sprite2D` con filtro `nearest`. Pinta el color de la nación; la celda de frontera usa un tono más oscuro de ese color. Convierte posición del ratón a celda con las coordenadas locales (como ya se hace hoy).
- Sin nodos por celda.

### Simulación
- `GameState` (`RefCounted`) agrupa las capas de §6. Un reloj avanza la simulación en **pasos fijos** (p. ej. unas decenas por segundo; valor por decidir en D10), independiente de los fotogramas.
- Las órdenes del jugador y de la IA son llamadas simples a funciones de la simulación que devuelven si fueron válidas. Sin sistema genérico de comandos ni de eventos hasta que haga falta.
- Azar solo con generador sembrado inyectado.

### Tamaño orientativo
Una malla de 320×180 son 57.600 celdas; a 4 píxeles por celda llena una ventana de 1280×720. Una imagen RGBA de ese tamaño ocupa unos 230 KB, y una de 1024×576 (~590.000 celdas) unos 2,3 MB: subir la textura entera es asumible incluso cada paso. El punto débil esperado es el **bucle en GDScript** al repintar muchas celdas a la vez, no la GPU. **Estas cifras son estimaciones, no mediciones**; el hito 4 incluye medir en el PC antes de comprometer un tamaño (D1).

### Pros y contras de la recomendación
- **Pros:** simple, comprobable sin interfaz, sin arte, fronteras coherentes por construcción, camino claro hacia una versión con shader.
- **Contras:** habrá que escribir y probar el repintado local; el pixelado queda limitado a la resolución de la cuadrícula (zoom grande mostrará píxeles grandes, que es el estilo buscado); mapas enormes pueden exigir el Enfoque D o repintado por bloques.

### Fronteras
Una celda es de frontera si algún vecino ortogonal tiene propietario distinto (o es agua, para la costa). Se recalcula localmente al cambiar una celda y sus vecinas. Las fronteras no son objetos: son una propiedad derivada del propietario, por eso no pueden quedar incoherentes.

## 5. Ciudades separadas del territorio

Las ciudades **no** modifican el propietario de las celdas ni las fronteras. Se guardan en su propia capa:
- `CityRegistry` (implementado en el hito 6 como `scripts/world/city_manager.gd`, con el propietario derivado de la cuadrícula en vez de guardado): lista de ciudades con id, celda ancla y nivel; más adelante tamaño y trabajadores asignados (según D5).
- La forma de la ciudad (qué celdas ocupa) se deriva de su ancla, tamaño y una regla determinista (D6), y se pinta en una **textura superpuesta**, independiente de la del territorio. Así el crecimiento urbano y la expansión de fronteras son procesos distintos incluso visualmente.
- Para consultas (¿hay una ciudad en esta celda?) puede mantenerse un array por celda con el id de ciudad, mantenido solo por `CityRegistry`.
- Crecimiento con rendimientos decrecientes: cada celda adicional cuesta más población que la anterior; niveles por umbrales; tras subir de nivel el crecimiento sigue siendo posible pero más lento. Fórmulas y números: D6.

## 6. Separación conceptual de capas

| Capa | Responsabilidad | Conoce a | Nunca hace |
|---|---|---|---|
| Territorio (`TerritoryGrid`) | Terreno, propietario por celda, fronteras derivadas | Nada | Saber de ciudades, población o ejércitos |
| Naciones | Identidad (id, nombre, color, quién la controla) | Territorio (para el recuento) | Calcular economía |
| Ciudades (`CityRegistry`; hoy `CityManager`) | Posición, nivel, tamaño visual, trabajadores asignados (futuro) | Territorio (ancla válida y propietario) | Cambiar fronteras |
| Población | Trabajadores y soldados; reparto de población nueva (control deslizante); conversión por reclutamiento forzoso | Ciudades, naciones | Dibujar o tocar territorio |
| Economía | Dinero y recursos (solo dos); producción, mantenimiento, construcciones | Ciudades, población | Añadir recursos nuevos |
| Ejército | Representación pendiente (D7); fuerza, previsión de combate, ataques | Territorio, población, naciones | Simular soldados individuales ni usar un único número global |
| Simulación | Reloj de pasos fijos y orden de actualización de las capas | Todas | Dibujar |
| Presentación | Vistas y HUD que leen el estado; transmiten las órdenes | Estado de la simulación | Contener reglas del juego |

Las dependencias van en una sola dirección (de abajo hacia arriba en la tabla). Las vistas leen estado; no escriben reglas.

## 7. Próximos hitos (resumen; detalle y criterios en `docs/ROADMAP.md`)

| Hito | Contenido | Depende de | Decisiones previas |
|---|---|---|---|
| 3 | Datos del territorio (cuadrícula) con pruebas — **hecho; 21 PASS del propietario** | — | D1 (valores provisionales) |
| 4 | Vista pixelada, fronteras derivadas, ratón → celda; medir rendimiento — **implementado sin cámara; 14 PASS del propietario; medición de rendimiento por hacer** | 3 | D1 (cámara) |
| 5 | Fundamentos de la conquista: operación `conquer_cells` validada y atómica — **hecho; 18 PASS del propietario** | 4 | — (el combate/autorización: D3) |
| 5b | Naciones y HUD base (antes «hito 5») — **hecho; 10 PASS del propietario** | 4 | D2 (valores provisionales) |
| 6 | **Ciudades y economía básica** (ciudades iniciales, fundación, crecimiento por niveles, dinero y recursos) — **implementado; pruebas por ejecutar en Godot** | 5b | D4, D6, D14 (valores provisionales) |
| 7 | Reloj de simulación global y expansión territorial (con comprobación de continuidad) — aplazado desde el antiguo hito 6 | 5, 6 | D3, D10 |
| 8 | Población, trabajadores, reparto y crecimiento urbano | 6 | D5, D6, D15 |
| 9 | Mantenimiento de trabajadores y soldados y construcciones | 8 | D14 |
| 10 | Cifra de soldados, ataques (zona de ataque con flecha opcional) y previsión de combate | 6, 8 | D7, D8, D12, D18 |
| 11 | Reclutamiento forzoso | 8, 10 | D13 |
| 12 | IA | 10 | — |
| 13 | Victoria, derrota y reinicio | 12 | D11 |
| 14 | Pulido y cierre del MVP | 13 | — |

## 8. Riesgos técnicos

| Riesgo | Efecto | Mitigación |
|---|---|---|
| Rendimiento de GDScript al repintar o simular muchas celdas | Tirones | Repintar solo celdas cambiadas; medir en el hito 4 con el tamaño real; subir a shader (Enfoque D) o a bloques si hace falta |
| Nada se ha ejecutado en Godot desde la nube | Errores de sintaxis o escena descubiertos tarde | Hitos pequeños; el propietario confirma las pruebas en cada entrega; incluir en cada informe qué sigue sin verificar |
| Las pruebas automáticas actuales no están confirmadas | Falsa sensación de cobertura | Pedir al propietario ejecutarlas una vez, o abandonarlas con el prototipo |
| Aspecto visual solo verificable en el PC | Iteraciones largas | Capturas o descripciones del propietario; pruebas píxel a píxel de la imagen |
| Diseño abierto (ejércitos, combate, expansión) | Hitos bloqueados o rehechos | No empezar un hito sin sus decisiones; mantener la lógica detrás de funciones pequeñas |
| Comprobación de continuidad del territorio costosa en mapas grandes | Lentitud | Hacerla incremental o solo en pruebas y en cambios puntuales |
| Crecimiento urbano que confunda fronteras o produzca ciudades enormes | Aspecto y equilibrio malos | Capa separada y curva de crecimiento decreciente; probar la curva |
| Desviación de alcance (nuevos recursos, unidades, etc.) | Proyecto inabarcable | Reglas de `CLAUDE.md`: dos recursos, un hito cada vez |
| `:=` con valores `Variant` y otras trampas de GDScript no probadas | Errores al cargar | Tipado explícito; ejecución por el propietario |
| Determinismo roto por flotantes o por orden de iteración | Resultados no reproducibles | Aritmética entera cuando sea posible; orden de actualización fijo; semilla inyectada |

## 9. Decisiones que necesitan respuesta del usuario

Detalle completo en `docs/GDD.md` §12. En orden de urgencia:

**Antes del hito 3 y 4**
- **D1** — Tamaño aproximado del mapa, si se dibuja a mano o se genera, y si solo hay tierra y agua o más terrenos. ¿Cámara con zoom y desplazamiento?

**Antes del hito 5b** (4 naciones es el valor provisional del hito 3)
- **D2** — ¿Cuántas naciones en el MVP y quién las controla (una jugador, el resto IA)?

**Antes del hito 7** (aplazado; el hito 6 es ciudades y economía)
- **D3** — ¿Qué se gasta al expandir el territorio (tropas, dinero, nada) y es continuo o por órdenes?
- **D10** — Ritmo del tiempo real: ¿pausa, velocidad variable, duración de partida?
- **D16** — Ya decidido el plazo: se retira tras validar el nuevo mapa visual y su interacción en tu PC. Queda por elegir cómo (borrar, `legacy/` o rama).

**Antes de los hitos 8–9** (el hito 6 usa valores provisionales de D4, D6 y D14)
- **D4** — Condiciones definitivas para fundar ciudades.
- **D19** — Efecto, coste y límites de la prioridad de población de una ciudad.
- **D5 / D15** — ¿Cómo se asignan los trabajadores? ¿El control deslizante es global o por ciudad? ¿La población es global o por ciudad?
- **D6** — Cómo se ve crecer una ciudad (forma, niveles, umbrales).
- **D14** — Producción, consumo y construcciones del dinero y los recursos.

**Antes del hito 10 en adelante**
- **D7** — Ya se sabe que los ejércitos son una cifra de soldados (sin regimientos). Falta decidir dónde se guarda y cómo se agrupa esa cifra, y reconciliarlo con la antigua directriz de "no usar un único número global".
- **D18** — Cómo se selecciona y visualiza la zona de ataque (flecha u otra herramienta).
- **D8** — ¿El combate es determinista o con azar? ¿Qué significa "probabilidad de victoria"?
- **D12** — ¿Qué pasa con una ciudad cuando su territorio cambia de dueño?
- **D13** — Límites y penalizaciones del reclutamiento forzoso.
- **D11** — Condiciones de victoria y derrota.

**Transversales**
- **D9** — Mecánica diferenciadora definitiva (no es una decisión tomada; ciudades y población son candidatas).
- **D17** — Nombres del mundo, las naciones y las ciudades (provisionales sin bloqueo).

**Además:** el hito 3 ya usa la arquitectura recomendada de forma provisional; confirmar si se mantiene (cuadrícula + imagen en CPU, §4) tras ver el resultado visual en el hito 4.


## Decisiones técnicas del hito 4 (vista pixelada)

Propuestas técnicas provisionales; el propietario puede revertirlas.

- **Representación:** `Image` RGBA8 de 320x180 (1 píxel = 1 celda) + `ImageTexture`, dibujada con `draw_texture` en un `Node2D` (`territory_map_view.gd`) con filtro `nearest`. La escala (3 → 960x540) y la posición salen de `scale` y `position` del nodo; no hay cámara (D1 sigue abierto). Una textura de 57.600 píxeles es ~230 KB; se vuelve a subir entera en cada cambio (`ImageTexture.update`), lo que es asumible a este tamaño.
- **Una sola fuente de datos:** la vista no guarda propietarios ni terreno, solo la imagen de colores (caché de dibujo) y la selección. `TerritoryGrid` no emite señales: quien cambie una celda debe llamar a `refresh_cell(x, y)` (repinta la celda y sus 4 vecinas). Si en el hito 6 hay muchos cambios por paso, convendrá una señal o una lista de celdas modificadas.
- **Fronteras:** celda de frontera = tierra con algún vecino ortogonal que sea agua o tenga otro propietario (`is_border`). Se pinta con el color de la nación oscurecido, siempre del lado de la propia nación: entre dos naciones queda una línea de 2 celdas sin huecos; entre nación y tierra sin reclamar y en las costas de una nación, 1 celda. La tierra sin reclamar solo marca la costa (tono más oscuro), no su límite con naciones.
- **Selección:** solo la tierra se resalta y se selecciona. Un clic en agua o fuera del mapa **limpia** la selección (decisión provisional; alternativa: permitir inspeccionar el agua).
- **Entrada:** `_unhandled_input`, así que los paneles de la interfaz que capturan el clic no seleccionan el mapa. La conversión usa la transformación global del nodo, por lo que admite mover o escalar el nodo o sus padres.
- **Coste esperado (estimación, no medida):** el pintado completo inicial son 57.600 celdas con ~5 consultas a la cuadrícula cada una en GDScript, una sola vez al arrancar; `refresh_cell` toca 5 píxeles y sube la textura. Cada fotograma con el ratón en movimiento solo redibuja una textura y dos rectángulos. Posibles mejoras si hiciera falta: pintar desde los arrays copiados en vez de consultar celda a celda, subir solo las regiones modificadas, o pasar a un shader (enfoque D). El hito 4 sigue pendiente de medir en el PC.

## Decisiones técnicas del hito 5 (conquista)

Propuestas técnicas provisionales; el propietario puede revertirlas.

- **Dónde vive:** en `TerritoryGrid` (`conquer_cells`). Es el dueño de los datos y la regla (contigüidad y contacto) es una invariante de los datos del territorio; así no hay segunda copia ni un módulo nuevo. Cuando existan combate y simulación (hitos 6+), llamarán a esta operación; la validación de reglas de juego (coste, ejércitos…) irá fuera, en esas capas.
- **Atomicidad:** primero `_validate_conquest` (no escribe nada) y después una sola pasada de escritura. Resultado en un `Dictionary` con códigos `CONQUEST_*` (convención ya usada: enteros y bool, sin excepciones).
- **Contigüidad y contacto:** vecinos ortogonales (no diagonales). La zona completa debe ser de una pieza y alguna celda suya debe tocar al atacante. Coste: proporcional al tamaño de la zona pedida, no al mapa.
- **`try_set_owner` se conserva** (bajo nivel, usado por pruebas y herramientas); el juego debe usar `conquer_cells`.
- **Refresco visual:** `changed_cells` lista exactamente las celdas cambiadas; la vista llama a `refresh_cell(x, y)` con cada una (cada llamada repinta 5 píxeles y sube la textura). Con zonas muy grandes convendría un `refresh_cells` que suba la textura una sola vez; no se ha hecho porque aún no hay conquistas reales.
- **Aún sin decidir:** si una nación puede quedarse sin celdas (eliminación, D11) y qué hacer entonces; la operación lo permite sin tratamiento especial. Tampoco evita que una conquista deje territorio enemigo partido en dos zonas.


## Decisiones técnicas del hito 5b (naciones y HUD)

Propuestas técnicas provisionales; el propietario puede revertirlas.

- **Sin cifras duplicadas:** `TerritoryGrid.count_land_by_owner()` cuenta la tierra por propietario en una sola pasada (57.600 celdas, estimación de coste no medida: unos pocos milisegundos o decenas en GDScript). No hay contadores incrementales: se evita que puedan desincronizarse de la cuadrícula.
- **Actualización:** nueva señal `ownership_changed` en `TerritoryGrid` (sin datos), emitida una vez por operación que cambia propietarios (`conquer_cells`, `try_set_owner` con cambio, `load_from_data`, `reset_to_default`). La pantalla marca el refresco pendiente y recalcula en el siguiente fotograma, así que una conquista grande cuesta un solo recuento. `conquer_cells` y la generación no cambian salvo por esta emisión.
- **Registro de naciones:** se mantiene `NATIONS` con IDs, claves, nombres y colores intactos y se añade `controller` ("human"/"ai"), provisional hasta D2.
- **Interfaz:** se reutiliza la leyenda del hito 4 (dos columnas de tres filas) con las cifras alineadas a la derecha y una etiqueta con el resumen del jugador; no se añaden paneles. `build_rows` y `player_summary` son funciones estáticas para poder probarlas sin nodos. El porcentaje es sobre la **tierra total** (incluida la sin reclamar), con una decimal.
- **Pendiente:** validar visualmente que las dos columnas caben bajo el mapa y el aspecto de las cifras.

## Decisiones técnicas del hito 6 (ciudades y economía básica)

Propuestas técnicas provisionales; el propietario puede revertirlas.

- **Tres piezas sin nodos:** `Economy` (saldos de dinero y recursos por nación, sin valores negativos), `CityManager` (ciudades, fundación, crecimiento, producción) y `economy_balance.gd` (todas las constantes de equilibrio). La capa visual (`city_layer_view.gd`) solo lee. `TerritoryGrid` no conoce las ciudades y las ciudades nunca escriben en la cuadrícula.
- **Propietario derivado, no guardado:** el dueño de una ciudad es el de su celda central. Evita duplicar información y hace imposible que un cambio de propietario (`conquer_cells`, `try_set_owner`) deje la ciudad desincronizada. No se acopla a la lógica de combate ni a una señal. Consecuencia: si el centro queda en `OWNER_NONE` la ciudad queda inactiva (ni crece ni produce ni se dibuja), no se destruye. Limitación: si se recarga el terreno con `load_from_data` o `reset_to_default`, las ciudades no se revalidan solas (en agua serían inertes).
- **Tiempo:** `advance(delta)` acumula segundos y ejecuta ticks fijos de `TICK_SECONDS` con aritmética entera; el resultado no depende de los fotogramas. La pantalla lo llama en `_physics_process` con un tope de 0,5 s por fotograma. No se ha creado un reloj global de simulación (hito 7).
- **Visual:** rombo de píxeles (distancia Manhattan ≤ radio del nivel), recortado a la tierra del propietario, dibujado con rectángulos de una celda en un solo `_draw` (sin nodos por píxel), con redibujo solo al cambiar ciudades o propietarios. `MIN_CITY_DISTANCE` debe ser mayor que el doble del radio máximo para que no se solapen (una prueba lo comprueba).
- **Entrada:** `territory_map_view.gd` gana la señal `cell_clicked` y el indicador `selection_enabled`; en modo de fundación el clic ya no selecciona. Los controles nuevos capturan el clic (el botón) o lo ignoran (etiquetas), así que no se funda a través de ellos. No se ha tocado nada de la selección existente.
- **Pendiente de medir/validar en Godot:** disposición del botón y los textos, legibilidad de las ciudades pequeñas a escala 3, ritmo de crecimiento y de ingresos.
