# Auditoría integral de la base tras el hito 11

Documento de referencia para planificar los siguientes hitos. Es una **auditoría**: no cambia reglas de juego. Las únicas modificaciones de código hechas junto a este informe son las de la sección 2 (bloqueo de análisis de las pruebas).

**Limitación principal:** en el entorno de la nube **no hay ejecutable de Godot**. Nada de lo descrito aquí se ha compilado ni ejecutado. Todo es revisión estática (lectura del código y dos analizadores heurísticos propios, sección 2.3). Cada hallazgo indica si es un **error confirmado por lectura**, un **riesgo estático** o una **hipótesis de diseño** que hay que validar jugando.

Leyenda de la naturaleza de cada hallazgo:

| Etiqueta | Significado |
|---|---|
| **Confirmado (lectura)** | El código hace eso sin ambigüedad; no se ha ejecutado |
| **Riesgo estático** | Probable a partir del código, pero depende de condiciones de ejecución que no se han observado |
| **Hipótesis de diseño** | Cuestión de ritmo, equilibrio o diversión: solo se decide jugando |

---

## 0. Resumen ejecutivo

- **P0 corregido:** `tests/diplomacy_tests.gd` tenía cinco declaraciones `var x := diccionario["clave"].metodo(...)`; Godot no puede inferir el tipo (el valor es `Variant`) y la suite no se podía analizar. Estaba así **desde el hito 10** (`81efaa6`): la suite DI-01…DI-19 **nunca ha podido ejecutarse**. Corregido con tipos explícitos `Dictionary`. Pendiente de validar en Godot.
- **Primer fallo previsible tras la corrección (P1-01):** DI-12 («firmar la paz detiene las ofensivas…») avanza 3 ticks antes de proponer la paz; la IA 1, muy débil, ya habrá propuesto sola una paz blanca en el tick 1 y la propuesta del jugador devolverá `ERR_PENDING_EXISTS`. Es la **misma causa que rompió GP-14**. Además la prueba lee `result["treaty"]["stopped"]` sobre un diccionario vacío, lo que provoca un **error de ejecución** que puede interrumpir la suite. No se ha tocado (no es un bloqueo de análisis); está descrita la corrección.
- **Error de reglas más relevante (P1-02):** una ofensiva contra la nación G puede «robar» sin combate una celda de G **ocupada por una tercera nación T**, aunque no exista guerra con T.
- **Validación pendiente (P1-03):** 7 de las 10 suites del sistema nuevo cambiaron o dependen de código que cambió después de su última ejecución real. Antes de ampliar el juego hay que ejecutar las 10 suites (192 pruebas).
- **Documentación contradictoria sobre el estado de las pruebas (P1-04):** por ejemplo, `docs/TEST_PLAN.md` atribuye a la suite de diplomacia el resultado de la suite de jugabilidad (17 PASS / 2 FAIL en GP-13 y GP-14).
- La arquitectura (lógica separada de la vista, reloj único, ocupación ≠ propiedad, tratados atómicos ensayados) es **sólida y coherente** en lo esencial. No se recomienda ninguna reescritura.
- Los problemas de diversión que se intuyen (expansión sin coste, defensa muy diluida, dinero sin uso, niveles de ciudad que dependen solo del tiempo) son **hipótesis de diseño**: hay que medirlos jugando antes de tocar valores.

---

## 1. Estado real del repositorio

| Dato | Valor comprobado |
|---|---|
| Rama | `claude/ecstatic-bardeen-1de9nl` |
| Estado inicial de la copia de la nube | 2 commits por detrás del remoto (en `81efaa6`); actualizada con **fast-forward** a `641bd30` sin conflictos |
| Commit auditado | `641bd30` «Hito 11: corrige la preparación de GP-13 y GP-14» |
| Cambios locales previos | Ninguno (árbol limpio) |
| Hito 10 | `81efaa6` «Hito 10: guerra, diplomacia y jugabilidad simplificada» |
| Hito 11 | `25a8ad8` «Hito 11: gran reforma de jugabilidad…» (31 archivos, +2624 / −164) |
| Corrección anterior de pruebas | `641bd30` (solo `tests/gameplay_tests.gd`, `docs/TEST_PLAN.md`, `CLAUDE.md`) |
| Godot en el entorno | **No disponible**: no se ha compilado ni ejecutado nada |
| Tamaño | 7.909 líneas en `scripts/` (24 archivos); 10 suites del sistema nuevo con 192 pruebas |

---

## 2. Correcciones de compilación realizadas

### 2.1 El error de `edge`

| Campo | Detalle |
|---|---|
| Archivo y línea | `tests/diplomacy_tests.gd:456` (función `_test_launch_invalid`) |
| Código | `var edge := strip["off"].launch_attack(PLAYER, Vector2i(314, 100), Military.DIR_NORTH, 4)` |
| Tipo real | `Dictionary` (`Offensives.launch_attack(...) -> Dictionary`) |
| Por qué falla | `strip` es el `Dictionary` que devuelve `_make_world`; `strip["off"]` es `Variant`. Llamar a un método sobre un `Variant` da un resultado de tipo desconocido en tiempo de análisis, así que `:=` no puede inferir el tipo («Cannot infer the type of "edge"…»). No es un problema de `int`: el valor es un diccionario de resultado |
| Corrección | `var edge: Dictionary = strip["off"].launch_attack(...)` |
| Desde cuándo | Commit `81efaa6` (hito 10). La suite de diplomacia no ha podido cargarse nunca |

### 2.2 Mismo patrón en el mismo archivo (corregidos)

Godot solo informa del primer error de análisis; tras corregir `edge` habría aparecido el siguiente. Los cinco casos tienen la misma causa y la misma corrección (`: Dictionary`):

| Línea | Variable | Expresión |
|---|---|---|
| 456 | `edge` | `strip["off"].launch_attack(...)` |
| 458 | `unreachable` | `strip["off"].launch_attack(...)` |
| 462 | `too_many` | `strip["off"].launch_attack(...)` |
| 609 | `white` | `world2["dip"].propose(...)` (`propose(...) -> Dictionary`) |
| 804 | `other` | `tri["off"].launch_attack(...)` |

No se ha cambiado ningún valor esperado ni ninguna comprobación.

### 2.3 Búsqueda de otros bloqueos de análisis (estática)

Sin Godot, se escribieron dos analizadores heurísticos (fuera del repositorio, en el directorio temporal de la sesión) y se revisaron sus avisos a mano:

1. **Inferencia con `:=`** en todos los `.gd`: subíndices de `Dictionary`/`Array` sin tipo, métodos llamados sobre subíndices, `Dictionary.get`, funciones sin tipo de retorno, funciones globales que devuelven `Variant` (`max`, `min`, `clamp`, `abs`…) y ternarios. **Resultado:** solo los cinco casos de 2.2. Todas las funciones del proyecto declaran tipo de retorno. Los ternarios de `scripts/` combinan ramas del mismo tipo y, además, esos scripts los cargó ya Godot del propietario al ejecutar GP (la escena principal los carga todos).
2. **Miembros y aridad**: cada `Alias.miembro` y `variable_tipada.metodo(...)` existe en el script del alias (o es de la clase de motor), y el número de argumentos encaja con la firma. **Resultado:** sin discrepancias (los únicos avisos eran comentarios `## decide()` o miembros de `Control`/`Node2D`).

Limitaciones: son analizadores por expresiones regulares; no sustituyen al analizador de Godot. **La validación local es obligatoria.**

### 2.4 Por qué «no se puede iniciar ninguna suite»

El error está solo en `tests/diplomacy_tests.gd`. Los ejecutores (`tests/test_*.gd`) precargan únicamente su propia suite, así que las demás no dependen de ese archivo. Hipótesis: el propietario empezó por la suite de diplomacia, o el depurador del editor detuvo la ejecución al ver el error. Si tras esta corrección otra suite sigue sin cargar, el mensaje nuevo indicará otro archivo: conviene comunicarlo tal cual.

---

## 3. Arquitectura actual por subsistemas

### 3.1 Mapa de propiedad de los datos (fuentes de verdad)

| Dato | Único propietario | Derivados (no se guardan) |
|---|---|---|
| Terreno y propietario oficial de cada celda | `TerritoryGrid` (`PackedByteArray` × 2) | Fronteras, recuentos por nación, celdas expuestas |
| Ocupación militar | `Occupation` (`Dictionary` Vector2i → {occupier, owner}) | Celdas ocupadas por nación |
| Ciudades (centro, nivel, progreso) | `CityManager` | Propietario de la ciudad (= dueño de la celda central), ocupación de la ciudad, producción |
| Dinero y recursos | `Economy` | — |
| Trabajadores, soldados, movilización, deudas | `Population` (por nación) | Total, capacidad, puestos de trabajo, empleados |
| Reparto de soldados en frentes | `Military` (sectores) | Reserva = total − asignados |
| Ofensivas (estado, frente, objetivo, cifras) | `Offensives` | Previsión, amenazas, soldados que defienden |
| Guerras y treguas | `WarState` | Duración |
| Propuestas, historial de tratados | `Diplomacy` | Postura de la IA |
| Decisiones de IA | `AIController` (solo memoria de cooldowns) | — |
| Reloj único, pausa, contador de ticks | `CityManager` | Tiempo de juego |

**Conclusión:** no hay contadores duplicados de la misma magnitud. Las únicas cachés son `Offensives._exposed_cache` (se vacía con `ownership_changed`, correcto porque solo depende de la propiedad oficial) y `AIController._scan_cache` (vive solo durante una decisión).

### 3.2 Dependencias y orden de construcción

`TerritoryScreen._ready()` crea, en este orden: `TerritoryGrid` → `Occupation` → `Economy` → `CityManager` (+ `set_occupation`) → `WarState` → ciudades iniciales → `Population` → `Military` → `Offensives` → `Diplomacy` → `AIController`. No hay dependencias circulares de construcción: cada sistema recibe por constructor los que necesita.

Orden dentro de un tick (orden de conexión a `CityManager.ticked`): producción de ciudades (dentro de `_tick`) → `Population` → `Offensives` → `Diplomacy` → `AIController`. Es el orden documentado y es razonable (la IA decide con el mundo ya avanzado).

### 3.3 Señales

- Conexiones hechas una sola vez, en constructores o `setup`. No hay desconexiones explícitas; como todos los sistemas viven lo mismo que la pantalla, no es un problema en el juego. En las pruebas se crean muchos mundos con referencias cruzadas por señales; no se ha observado ni medido ninguna fuga.
- Reentrada controlada: `Offensives._stepping` evita sincronizar a mitad de un avance y `MilitaryPanel._refreshing` evita refrescos anidados.
- Las operaciones por lotes (`occupy_cells`, `release_cells`, `conquer_cells`) emiten una señal por operación, no por celda. Correcto.

### 3.4 Restos del prototipo y código poco usado

| Elemento | Estado |
|---|---|
| Prototipo de provincias (`scenes/main.tscn`, `scripts/map/`, `scripts/data/province_data.gd`, `scripts/ui/province_info_panel.gd`, pruebas de provincias) | Legado conservado a propósito (CLAUDE.md, D16). No interfiere: la escena principal es `territory_main.tscn` |
| `TerritoryGrid.try_set_owner` | Segunda vía para cambiar propietarios; solo la usan pruebas (20 llamadas). Contradice la regla «solo `conquer_cells`» si algún día la usa el juego (P3-08) |
| `Offensives.stop_all`, `Occupation.release_all_of`, `WarState.aggressor_of`, `Military.adjust_sector_soldiers`, `PopulationPanel.maintenance_text`, `Offensives.start_error_message`, `Military.sector_error_message` | Sin uso en `scripts/`, solo en pruebas. Inofensivo; candidatos a limpieza futura |
| `TerritoryScreen.economy_summary` | Rama de respaldo que solo se usa si `population` es `null` (nunca en el juego) |

---

## 4. Hallazgos

### P0 — Bloqueos

#### P0-01 · Análisis imposible de `tests/diplomacy_tests.gd` — **CORREGIDO** (pendiente de validar)
- **Subsistema:** pruebas de diplomacia (DI-01…DI-19).
- **Archivo:** `tests/diplomacy_tests.gd` líneas 456, 458, 462, 609, 804.
- **Evidencia:** sección 2.
- **Consecuencia:** la suite no carga; desde el hito 10 ninguna prueba DI se ha ejecutado nunca.
- **Naturaleza:** error confirmado (lo comunicó el propietario y la causa se ve en el código).
- **Recomendación:** ejecutar `godot --headless --path . --script res://tests/test_diplomacy.gd` y comunicar el resultado completo.
- **Dependencias:** P1-01 (primer fallo previsible).

No se han encontrado otros bloqueos de análisis en la revisión estática (sección 2.3).

### P1 — Corregir antes de ampliar el juego

#### P1-01 · DI-12 fallará y puede interrumpir la suite
- **Subsistema:** pruebas de diplomacia.
- **Archivo:** `tests/diplomacy_tests.gd`, `_test_peace_stops_offensives` (≈ líneas 726–760).
- **Evidencia:** crea dos ofensivas del jugador (20 soldados) contra la IA 1 (6) y la IA 2 (6), lo que declara ambas guerras en el tick 0, y avanza 3 ticks. En el tick 1, `Diplomacy._make_ai_offers` calcula la reluctancia de la IA 1: fuerza 6·1000/26 = 230 → esperanza (230 − 500)·20/100 = −54; cansancio ≈ 1 → reluctancia ≈ −55 < −15 (`PEACE_SEEK_MARGIN`), así que **la IA 1 propone sola una paz blanca**. Después, `dip.propose(PLAYER, AI_1, …)` devuelve `ERR_PENDING_EXISTS` (una propuesta pendiente por pareja) y `result["treaty"]` es `{}`. La línea siguiente lee `result["treaty"]["stopped"]` → **error de ejecución** por clave inexistente.
- **Consecuencia:** DI-12 falla; según cómo se ejecute (editor con depurador o consola), el error puede detener la función o la ejecución entera de la suite.
- **Naturaleza:** riesgo estático alto (misma causa que el fallo real de GP-14, ya observado por el propietario).
- **Recomendación:** misma solución que GP-14 en `641bd30`: comprobar que la IA 1 ha propuesto, rechazar esa propuesta y después proponer. No requiere cambiar ningún resultado esperado. No aplicada en esta tarea (no es un bloqueo de análisis); se recomienda hacerla en cuanto se confirme con la ejecución.
- **Dependencias:** P0-01.

#### P1-02 · Una ofensiva roba sin combate las ocupaciones de un tercero
- **Subsistema:** combate y ocupación.
- **Archivo:** `scripts/world/offensives.gd`, `_is_wave_cell` (≈ línea 475) y `evaluate` (≈ líneas 314–345); `scripts/world/occupation.gd`, `occupy_cells`.
- **Evidencia:** para una ofensiva de A contra G, una celda es válida si `owner == G and occupier != A`. Si la celda es de G pero está **ocupada por T** (otra guerra), también es válida. `Occupation.occupy_cells` solo exige que el dueño oficial no sea A ni «sin reclamar», así que sobrescribe el ocupante T por A. El enfrentamiento se calcula con la defensa de **G** (que no controla esa celda) y la tregua se comprueba solo con G.
- **Consecuencia:** T pierde celdas sin combatir y sin estar en guerra con A; A puede incluso tener tregua con T. La «paz con conquistas» posterior entre T y G ya no incluye esas celdas. Escenario realista: el jugador ataca a una IA que ya está en guerra con otra IA (la regla `MAX_WARS_ON_TARGET` solo limita a las IA).
- **Naturaleza:** confirmado por lectura (no ejecutado).
- **Recomendación:** decidir la regla (pregunta de diseño): a) las celdas ocupadas por un tercero no forman parte de la franja (la opción más simple y segura); o b) son de T y atacarlas exige guerra con T. Añadir una prueba con tres naciones.
- **Dependencias:** ninguna.

#### P1-03 · La mayoría de las suites no se han ejecutado sobre el código actual
- **Subsistema:** validación.
- **Evidencia** (última ejecución real comunicada frente a cambios posteriores):

| Suite | Pruebas | Última ejecución real | ¿Cambió la suite o el código que prueba después? |
|---|---|---|---|
| `territory_grid_tests` | 21 | Hito 3–5b: 21 PASS | No (la cuadrícula no cambia desde `45f601b`) |
| `territory_map_view_tests` | 14 | Hito 4: 14 PASS | **Sí**: `territory_map_view.gd` cambió en los hitos 6 y 9 (ocupación) |
| `territory_conquest_tests` | 18 | Hito 5: 18 PASS | No |
| `territory_hud_tests` | 10 | Hito 5b: 10 PASS | **Sí**: carga `territory_main.tscn`, que ahora crea todos los sistemas, incluida la IA activa |
| `city_economy_tests` | 21 | Hito 6: 21 PASS | **Sí**: suite y `city_manager.gd` (hito 11) |
| `population_tests` | 24 | Hito 7: 24 PASS | **Sí**: suite (+32/−16) y `population.gd` (+160/−3) en el hito 11 |
| `military_tests` | 21 | Nunca confirmada | Sí |
| `combat_tests` | 25 | Hito 9: 23/25 | **Sí** (hitos 10 y 11) |
| `diplomacy_tests` | 19 | Nunca (no cargaba) | Sí |
| `gameplay_tests` | 19 | Hito 11: 17/19 | Sí (`641bd30` corrige GP-13 y GP-14) |

- **Consecuencia:** construir encima sin ejecutar las suites mezclaría fallos nuevos con fallos antiguos.
- **Naturaleza:** confirmado (historial de git y estado documentado).
- **Recomendación:** ejecutar las 10 suites y registrar resultados reales antes de cualquier hito nuevo.

#### P1-04 · Estado de las pruebas contradictorio en la documentación
- **Subsistema:** documentación.
- **Evidencia:**
  - `docs/TEST_PLAN.md`, tabla de estado: la fila de `diplomacy_tests.gd` dice «17 PASS y 2 FAIL (GP-13 y GP-14…)», que es el resultado de `gameplay_tests.gd`; la fila de `gameplay_tests.gd` sigue diciendo «Ejecución en Godot sin confirmar». Error introducido en `641bd30`.
  - `README.md` (línea 23 y §«Hito 11») y `docs/ROADMAP.md` (tabla de estado, hitos 9–11) dicen que las pruebas de los hitos 9–11 están «sin ejecutar», mientras `CLAUDE.md` registra 23/25 (hito 9) y 17/19 (GP).
- **Consecuencia:** el propietario y futuras sesiones pueden partir de un estado falso.
- **Naturaleza:** confirmado.
- **Recomendación:** corregir esas filas en cuanto se ejecuten las suites (P1-03), en un único commit de documentación. No se han tocado en esta tarea para no mezclar alcance.

### P2 — Mejoras importantes de jugabilidad y coherencia de reglas

#### P2-01 · Expandirse no cuesta nada y el jugador no tiene límite de frentes
- **Subsistema:** combate / expansión.
- **Archivo:** `combat_balance.gd` (`UNCLAIMED_DEFENSE = 0`, `EXPANSION_SOLDIERS_PER_CELL = 1`, `MAX_CELLS_PER_STEP = 12`); `military.gd` (sin límite de sectores, D20); `ai_balance.gd` (`MAX_EXPANSION_FRONTS = 2`, `EXPANSION_COMMIT_PERCENT = 50`).
- **Evidencia:** una expansión gana siempre sin bajas y toma hasta `soldados` celdas cada 3 ticks (máx. 12 por frente). El jugador puede repartir todos sus soldados en muchos frentes; la IA, como mucho 2 frentes y la mitad de sus soldados libres.
- **Consecuencia:** estrategia dominante probable: «todo a expandir». La IA queda por detrás en territorio por diseño de sus límites, no por la situación.
- **Naturaleza:** hipótesis de diseño (requiere jugar).
- **Recomendación:** medir en una partida el territorio del jugador frente al de la IA a los 2–3 minutos. Si se confirma: coste por frente o por celda (D20/D22), o techo de frentes simultáneos igual para todos.

#### P2-02 · Defensa muy repartida y ocupación sin guarnición: el atacante tiene mucha ventaja
- **Subsistema:** combate.
- **Archivo:** `combat.gd` (`defense_per_front`), `offensives.gd` (`evaluate`).
- **Evidencia:** la defensa local = soldados que defienden ÷ tramos de frontera (celdas expuestas ÷ 8). Ejemplo: 30 soldados y 80 celdas expuestas → 10 tramos → defensa 3; con 4 atacantes ya se vence (4·100 > 3·120). Cada victoria toma hasta `soldados/3` celdas y las ocupaciones no necesitan soldados para mantenerse. Varias ofensivas contra la misma nación encuentran cada una la defensa completa del tramo, y todas restan del mismo fondo.
- **Consecuencia:** posible bola de nieve; el defensor no puede concentrar fuerzas donde le atacan.
- **Naturaleza:** hipótesis de diseño.
- **Recomendación:** jugar un escenario de guerra simétrico; si se confirma, valorar defensa concentrada en el tramo amenazado o un coste de mantener ocupaciones.

#### P2-03 · Las bajas del defensor pueden recortar un frente que está atacando
- **Subsistema:** población / organización militar.
- **Archivo:** `offensives.gd` `_step` → `population.remove_soldiers`; `military.gd` `enforce_soldier_limits` (recorta del sector más nuevo al más antiguo).
- **Evidencia:** la defensa se calcula sin los soldados que atacan, pero las bajas del defensor se restan del total nacional. Si la reserva no las cubre, `enforce_soldier_limits` recorta el **sector más nuevo**, que puede ser una ofensiva activa, en vez de un frente detenido (cuyos soldados sí defendían).
- **Consecuencia:** pequeña incoherencia con la regla «los que atacan no defienden»; puede detener un ataque lejano por un combate en otra frontera.
- **Naturaleza:** riesgo estático (solo con reserva casi vacía).
- **Recomendación:** al aplicar bajas del defensor, recortar primero los frentes detenidos. Prueba con reserva 0.

#### P2-04 · Una guerra con el jugador puede no terminar nunca y bloquear a la IA
- **Subsistema:** IA / diplomacia.
- **Archivo:** `war_state.gd` (las guerras solo terminan con `end_war` desde un tratado); `ai_controller.gd` `_consider_war` (exige no tener guerras), `_manage_economy` (45 % de soldados en guerra), `free_soldiers` (guardia del 30 %).
- **Evidencia:** si el jugador ignora o rechaza las ofertas, la IA sigue «en guerra» aunque nadie combata: no declara otras guerras, mantiene el reparto de guerra y reserva guardia indefinidamente.
- **Consecuencia:** IA pasiva y desequilibrada en partidas largas.
- **Naturaleza:** confirmado por lectura en cuanto a la regla; el impacto en la diversión es hipótesis.
- **Recomendación:** decidir (D21) si una guerra sin combates durante N ticks termina sola en paz blanca, o si la IA puede actuar con normalidad en una guerra «inactiva».

#### P2-05 · Lanzar un ataque en pausa declara la guerra al instante
- **Subsistema:** pausa / reglas.
- **Archivo:** `offensives.gd` (`launch_attack`/`start_offensive` no miran la pausa); `city_manager.gd` (`check_founding` sí); `diplomacy.gd` (`validate_terms` sí).
- **Evidencia:** D10 dice «en pausa se puede consultar y planificar ataques, pero no fundar ni negociar». Lanzar (no solo planificar) también funciona: crea el frente, compromete soldados y declara la guerra. Lo mismo para desmovilizar, movilizar, prioridades, ajustar y retirar frentes.
- **Consecuencia:** la regla no es uniforme; no hay explotación clara (el combate solo avanza con ticks), pero la guerra empieza en pausa.
- **Naturaleza:** confirmado por lectura; la valoración es de diseño.
- **Recomendación:** decidir qué órdenes valen en pausa y aplicarlo en la lógica, no en la interfaz.

#### P2-06 · El nivel de las ciudades depende solo del tiempo
- **Subsistema:** ciudades.
- **Archivo:** `city_manager.gd` `_tick` (`GROWTH_PER_TICK = 1` para todas), `economy_balance.gd` (`GROWTH_TO_NEXT = [0, 30, 60, 120, 0]`).
- **Evidencia:** toda ciudad llega al nivel 4 a los 210 s, con o sin trabajadores; la prioridad solo suma +1 por tick. El diseño confirmado dice que la ciudad crece «según la población trabajadora asignada» (D6 lo registra como provisional).
- **Consecuencia:** pocas decisiones interesantes sobre ciudades; tras unos minutos todas son iguales.
- **Naturaleza:** hipótesis de diseño (desviación documentada).
- **Recomendación:** decidir D6 antes de construcciones.

#### P2-07 · Pocos usos del dinero y recursos que dejan de importar
- **Subsistema:** economía.
- **Evidencia (cálculo con los valores actuales):** al inicio, una ciudad de nivel 1 con 30 empleados da ≈ +3,2 de dinero/s y ≈ +1,39 de recursos/s netos. Los gastos de dinero son fundar (100), prioridades (1/s por ciudad) y pagos de tratados. Una ciudad de nivel 4 con 140 empleados produce ≈ 9,2 recursos/s, suficiente para mantener ≈ 370 soldados (0,025 por soldado y segundo).
- **Consecuencia:** el dinero se acumula y el déficit solo importa al principio.
- **Naturaleza:** hipótesis de diseño.
- **Recomendación:** observar los saldos a los 5 y 10 minutos de partida antes de decidir construcciones (D14).

#### P2-08 · Cada clic en el mapa reconfigura el panel de ataque
- **Subsistema:** interfaz.
- **Archivo:** `territory_screen.gd` (`_view.selection_changed.connect(_military_panel.set_origin)`); `military_panel.gd` `_resolve_cell`.
- **Evidencia:** consultar una ciudad propia muestra en el panel militar «Esa celda no da a tierra libre ni enemiga»; pulsar una celda enemiga lejana para informarse prepara un ataque desde la frontera más cercana. Selección e intención de ataque van juntas.
- **Consecuencia:** mensajes confusos; riesgo de atacar (y declarar la guerra) por un clic de consulta seguido de «Atacar».
- **Naturaleza:** confirmado por lectura; el impacto, por validar jugando.
- **Recomendación:** separar «inspeccionar» y «preparar ataque» (por ejemplo, el panel de ataque solo reacciona en modo ataque) y pedir confirmación cuando un ataque inicia una guerra.

#### P2-09 · Una sola línea de mensajes
- **Subsistema:** interfaz.
- **Archivo:** `territory_screen.gd` `_on_ai_event` (sobrescribe `_message_label.text`).
- **Evidencia:** las declaraciones de guerra y las paces de la IA sustituyen al mensaje anterior (incluido el resultado de la última orden del jugador).
- **Consecuencia:** se pierden avisos importantes («¡X te declara la guerra!»).
- **Naturaleza:** confirmado por lectura.
- **Recomendación:** registro corto de los últimos avisos o aviso destacado para las guerras contra el jugador.

#### P2-10 · Repintado del mapa: subida completa de la textura por cada celda
- **Subsistema:** rendimiento del mapa.
- **Archivo:** `territory_map_view.gd` `refresh_cell` → `_upload()` → `ImageTexture.update(_image)`; `territory_screen.gd` `_repaint_cells` llama a `refresh_cell` por celda.
- **Evidencia:** cada celda repintada sube a la GPU la imagen completa (320×180 RGBA8 ≈ 225 KB). Un avance del frente ancho toma hasta 12 celdas; con la IA (2 expansiones por nación) y el jugador puede haber decenas de celdas por tick.
- **Consecuencia:** posibles tirones con muchas ofensivas.
- **Naturaleza:** riesgo estático (no medido).
- **Recomendación:** medir primero; la corrección es pequeña (repintar el lote y subir la textura una vez).

### P3 — Mejoras futuras

| Id | Subsistema | Archivo / función | Evidencia | Naturaleza | Recomendación |
|---|---|---|---|---|---|
| P3-01 | Rendimiento IA | `ai_controller.gd` `_border_scan`, `city_site`, `front_against`; `offensives.gd` `suggest_front` | Varios recorridos completos de 57.600 celdas por decisión; `front_against` llama a `suggest_front` por cada celda propia ocupada hasta encontrar una válida (cada llamada puede recorrer el mapa) | Riesgo estático | Medir el tiempo de un tick con 3 IA; cachés de frontera incrementales solo si hace falta |
| P3-02 | Rendimiento diplomacia | `diplomacy.gd` `plan_treaty` | `TerritoryGrid.new()` **regenera el mapa por defecto** (ruido, componentes, territorios) antes de `load_from_data` (que valida 57.600 celdas) en cada ensayo de tratado | Confirmado (coste no medido) | Copia ligera de la cuadrícula sin generación |
| P3-03 | Rendimiento combate | `offensives.gd` `exposed_cells` | Recorrido completo por nación tras cada cambio de propiedad; las expansiones cambian la propiedad casi cada tick | Riesgo estático | Medir; recuento incremental si es caro |
| P3-04 | Rendimiento interfaz | `military_panel.gd` `refresh` | Conectado a 6 señales; cada refresco hace `plan_attack` (franja de 81 celdas) y reconstruye la lista; varias veces por tick | Riesgo estático | Agrupar el refresco una vez por fotograma |
| P3-05 | Diplomacia | `diplomacy.gd` `_apply` (ruta de deshacer) | Si una conquista fallase a mitad, se restauran cuadrícula, ocupación y pago, pero no los sectores eliminados por `prune_lost_sectors` ni las ofensivas detenidas; tampoco se repinta el mapa | Riesgo estático (ruta inalcanzable si el ensayo es correcto) | Dejar constancia; no tocar salvo que aparezca |
| P3-06 | Combate | `offensives.gd` `_on_tick` | Las ofensivas avanzan por orden de id de sector: las más antiguas actúan primero en el mismo tick | Confirmado; impacto pequeño | Aceptable; revisar si hay quejas de equidad |
| P3-07 | Combate | `offensives.gd` `_is_ours` | Un frente situado en una celda propia **ocupada por el enemigo** sigue contando como «nuestro» | Riesgo estático | Usar `_controls` si se confirma un caso raro |
| P3-08 | Territorio | `territory_grid.gd` `try_set_owner` | Segunda vía de cambio de propietario (solo pruebas) | Confirmado | Marcarla como solo para pruebas o retirarla con la limpieza del legado |
| P3-09 | IA | `ai_controller.gd` `front_against` | Elige el primer frente de liberación posible aunque su ataque esté bloqueado, sin probar otros frentes contra el mismo enemigo | Riesgo estático | Probar el siguiente candidato si `plan_attack` falla |
| P3-10 | Interfaz | `military_panel.gd` (`INNER_WIDTH = 124`, `FONT_SIZE = 12`) | Columnas estrechas con mucho texto | Hipótesis | Revisión en la fase visual |
| P3-11 | Mantenibilidad | `offensives.gd` (1.049 líneas), `military_panel.gd` (727) | Archivos largos con varias responsabilidades (plan, órdenes, textos, sincronización) | Confirmado | Separar textos y plan solo cuando se toque esa zona |
| P3-12 | Mapa | Sección 9 | Aspecto cuadriculado | Diseño | Ver opciones |

---

## 5. Riesgos de rendimiento

**Ninguno está medido.** No se ha ejecutado Godot. Clasificación según el código:

| Riesgo | Frecuencia | Coste por vez | Prioridad |
|---|---|---|---|
| Subida de textura por celda (P2-10) | Por cada celda conquistada, ocupada o liberada | 225 KB a la GPU | Alta probabilidad de notarse con muchas ofensivas |
| Barridos de mapa de la IA (P3-01) | ≈ 3 decisiones cada 4 ticks | Varios × 57.600 celdas en GDScript | Media |
| `exposed_cells` (P3-03) | Tras cada cambio de propiedad, por nación evaluada | 57.600 celdas | Media |
| `plan_treaty` (P3-02) | Al proponer o evaluar tratados | Generación completa del mapa + validación | Baja frecuencia, pico puntual |
| Refrescos del panel militar (P3-04) | Varias veces por tick | `plan_attack` + lista | Media-baja |
| `suggest_front` al pulsar lejos | Por clic | 57.600 celdas | Baja |
| Leyenda (`count_land_by_owner`) | Como mucho una vez por fotograma tras cambios | 57.600 celdas | Baja |

**Recomendación:** antes de optimizar, añadir una medición simple (tiempo de un tick y del repintado) en una partida de 5 minutos con las tres IA y comunicar los números.

---

## 6. Estado y cobertura de las pruebas

### 6.1 Inventario

10 suites del sistema nuevo, 192 pruebas; cada suite tiene ejecutor headless (`tests/test_*.gd`) y escena F6 (`tests/run_*.tscn`) que usan el **mismo** script de comprobaciones mediante `run_all()`. El ejecutor F6 (`run_territory_tests.gd`) usa `load()` y muestra en pantalla si la suite no carga; los ejecutores headless usan `preload()` y fallan al analizar. Coherente.

### 6.2 Calidad observada

- Las pruebas de lógica comprueban estados reales (saldos, propietarios, ocupaciones, soldados) y no solo valores de retorno. Hay instantáneas completas del mundo (`_snapshot`) para comprobar que una orden rechazada no cambia nada. Buen nivel.
- **Escenarios frágiles por la diplomacia automática:** `Diplomacy._make_ai_offers` actúa en cada tick aunque la IA estratégica esté desactivada (`ai.enabled = false` solo apaga `AIController`). Cualquier prueba que avance ticks en guerra con una IA débil y después proponga la paz choca con «una propuesta por pareja» (GP-14 confirmado, DI-12 previsto). Recomendación: un interruptor equivalente en `Diplomacy` para las pruebas que no prueban esa conducta, o responder siempre la oferta como en GP-14.
- **Mundos con recursos ilimitados:** `diplomacy_tests._make_world` añade 100.000 recursos a cada nación; esas pruebas nunca ven déficit, así que no cubren la interacción déficit ↔ diplomacia (la cubre GP-13).
- **Pruebas de pantalla con la IA activa:** `territory_hud_tests` carga `territory_main.tscn` sin desactivar la IA (las suites de los hitos 10 y 11 sí la desactivan). Hoy no avanza el tiempo, así que la IA no llega a decidir; si una prueba futura de esa suite avanza ticks, conviene desactivarla (`screen.ai.enabled = false`).
- **Valores esperados calculados fuera de Godot:** en el hito 11 algunas cifras esperadas se obtuvieron con una réplica en Python (registrado en `TEST_PLAN.md`). La réplica no es una ejecución de Godot; la ejecución real decidirá.
- **Duración:** GP-15…GP-17 simulan 200–240 ticks con IA; el propietario ya las ejecutó, así que el tiempo es aceptable.

### 6.3 Coberturas que faltan (invariantes globales)

Ninguna prueba recorre una partida larga comprobando **en cada tick** estas invariantes (GP-15 comprueba algunas solo al final):

1. Soldados asignados ≤ soldados de la nación; reserva ≥ 0.
2. Ninguna celda ocupada es de agua, sin reclamar o del propio ocupante.
3. Toda ocupación pertenece a una pareja en guerra **o** se está liberando por tratado en ese mismo tick.
4. Ninguna ofensiva activa apunta a una nación con tregua.
5. Saldos ≥ 0; población ≤ capacidad + movilización (o la regla que se decida).
6. Ninguna guerra entre naciones con tregua.

Recomendación: una prueba «invariantes en cada tick» sobre la partida por defecto de GP-15 (barata de escribir, muy valiosa antes de acelerar).

---

## 7. Incoherencias entre código y documentación

| Documento | Texto | Realidad en el código | Resolución sugerida |
|---|---|---|---|
| `docs/TEST_PLAN.md`, tabla de estado | Fila de diplomacia: «17 PASS y 2 FAIL (GP-13 y GP-14…)»; fila de jugabilidad: «sin confirmar» | Las dos filas están intercambiadas | Corregir tras ejecutar (P1-04) |
| `README.md` y `docs/ROADMAP.md` (tabla) | Pruebas de los hitos 9–11 «sin ejecutar» | El propietario ejecutó el hito 9 (23/25) y GP (17/19) | Igual que arriba |
| `docs/GDD.md` ≈ línea 340 | «Las guerras entre dos IA no generan propuestas (no hay IA estratégica)» | `AIController._manage_diplomacy` propone la paz entre IA desde el hito 11 | Actualizar el párrafo |
| `docs/GDD.md` ≈ línea 276 | «No hay IA militar todavía… la defensa se estima con los soldados reales (`Population.soldiers`)» | Desde el hito 11 la defensa usa `defending_soldiers` (sin los que atacan) y existe IA militar | Actualizar el párrafo |
| `docs/ROADMAP.md`, hito 12 | «IA enemiga» como hito pendiente | La IA básica existe desde el hito 11 (la tabla ya lo dice; el cuerpo mantiene criterios antiguos) | Redefinir el hito 12 tras jugar |
| `CLAUDE.md` / diseño confirmado | La ciudad crece «según la población trabajadora asignada» | Crece solo con el tiempo (D6 provisional) | Decisión del propietario (P2-06) |
| `CLAUDE.md` / D10 | En pausa no se funda ni se negocia | Sí se pueden lanzar ataques y otras órdenes (P2-05) | Decidir y documentar |
| `diplomacy.gd` `truce_remaining` | Comentario «Segundos de juego» | Devuelve ticks (hoy 1 tick = 1 s) | Cosmético |
| `CLAUDE.md` «el territorio solo cambia por `conquer_cells`» | — | `try_set_owner` también lo cambia (solo pruebas) | P3-08 |

Decisiones provisionales tratadas como definitivas: no se ha encontrado ninguna presentada como definitiva en el código; las constantes llevan el comentario de provisionales y el GDD las numera (D3…D26). La regla de ocupación de ciudades (producción suspendida; capacidad y crecimiento conservados) está documentada en D12/D26 y coincide con el código.

---

## 8. Evaluación de la IA respecto al diseño previsto

| Intención del propietario | Mecanismo actual | Valoración |
|---|---|---|
| Etapa económica inicial breve | `WAR_GRACE_TICKS = 150` (2,5 min) antes de declarar guerras; antes solo se expande | Se aproxima. **Validar** si 2,5 min es «breve» |
| Conflictos y expansión pronto | Expansión desde el primer tick (2 frentes, 50 % de los soldados libres) | Expansión pronta: sí. Conflictos: dependen de que haya contacto de fronteras |
| IA algo más pacífica que el jugador | Gracia, enfriamiento de 120 ticks, una guerra a la vez, superioridad del 150 %, previsión de victoria, recursos positivos | Sí, por reglas explícitas. Con P2-01 la IA puede quedarse además **atrás** en territorio, lo que es otra cosa |
| Guerras entre IA | `_consider_war` elige al vecino más débil, sea IA o jugador | Posible; **validar** que ocurre en partidas reales (GP-15 no lo exige) |
| Ocasionalmente una IA ataca al jugador | El jugador es candidato si es vecino, no está en guerra y su defensa es baja | Sí; si el jugador tiene muchos soldados expandiéndose (no defienden), parecerá débil y será atacado: explicable por la situación |
| Decisiones explicables, sin ventajas arbitrarias | Solo órdenes públicas; sin crear recursos ni soldados; respeta treguas porque la regla vive en `Offensives`/`WarState` | Cumple. Observación: información perfecta del mapa (igual que el jugador ve el mapa) |
| No contar atacantes como defensores | `defending_soldiers` resta los frentes activos; `free_soldiers` parte de la reserva | Cumple |
| No atacar durante una tregua | `_plan_step`/`evaluate` bloquean con `STOP_TRUCE`; `declare_war` se niega | Cumple (en la lógica, no solo en la IA) |
| Recuperación de déficit | Reparto de soldados a 0 %, desmoviliza el 20 % de la reserva, no ataca, quita prioridades | Cumple; desmovilizar es instantáneo y gratis (asimetría con la movilización de 30 s, diseñada) |
| Retirada ante amenaza | Retira expansiones y ataques contra terceros si la reserva no cubre a los atacantes | Cumple; retirar es instantáneo (los soldados vuelven a la reserva desde cualquier punto) |

Aspectos a validar jugando: frecuencia real de guerras entre IA, cuántas veces atacan al jugador en 10 minutos, si la IA se queda bloqueada en una guerra sin combates (P2-04) y su ritmo de expansión frente al del jugador (P2-01). **No se han ajustado valores.**

---

## 9. Opciones técnicas para aumentar el detalle del mapa

Situación actual: 320×180 celdas lógicas (57.600), una imagen de 320×180 píxeles escalada ×3 (`scenes/territory_main.tscn`: nodo `Mapa`, `scale = 3`), cada celda = cuadrado de 3×3 píxeles de pantalla; fronteras pintadas oscureciendo la celda de borde; ocupación en damero. El terreno sale de un ruido de valores determinista (`TerritoryGrid._generate_landmass`).

### Opción 1 — Misma cuadrícula, mejor aspecto de costas y fronteras
- **Qué es:** dibujar costas suavizadas (muestreando el mismo ruido a 3× de resolución solo para el agua), fronteras como líneas finas entre celdas en vez de celdas oscurecidas, sombreado ligero. Preferiblemente con un *shader* que lea una textura de propietarios de 320×180.
- **Ventajas:** no toca conquistas, combate, IA, diplomacia ni pruebas de lógica; coste de rendimiento casi nulo con *shader*; reversible.
- **Riesgos:** las conquistas siguen avanzando en escalones de 3 píxeles; el interior de los territorios sigue viéndose por bloques; hay que cuidar que la costa dibujada coincida con la tierra lógica (clic en «tierra» dibujada que es agua lógica).
- **Celdas:** 57.600. **Pruebas:** solo las de la vista (`territory_map_view_tests`, comparación de píxeles).

### Opción 2 — Más resolución lógica con el mismo tamaño de mapa
- **Qué es:** por ejemplo 640×360 (230.400 celdas, ×4) o 960×540 (518.400, ×9), con 1,5 o 1 píxel por celda.
- **Ventajas:** fronteras y avances realmente más finos; detalle auténtico, no solo visual.
- **Riesgos e impacto:**
  - **Rendimiento:** todos los barridos de la sección 5 se multiplican ×4 o ×9; P2-10, P3-01, P3-02 y P3-03 pasan a ser bloqueantes.
  - **Equilibrio:** todas las constantes en celdas cambian de significado (`FRONT_HALF_WIDTH`, `MAX_CELLS_PER_STEP`, `CELLS_PER_FRONT`, `MIN_CITY_DISTANCE`, `CITY_DEFENSE_RADIUS`, `VISUAL_RADIUS`, `START_SITES`, el número de celdas por avance y la velocidad de expansión).
  - **Ocupación y diplomacia:** muchas más celdas ocupadas en diccionarios por celda; tratados con más zonas.
  - **Pruebas:** las de la cuadrícula por defecto (recuentos, sitios iniciales) y muchas coordenadas fijas tendrían que revisarse.
- **Celdas:** ×4 o ×9.

### Opción 3 — Capa visual detallada sobre la cuadrícula lógica actual
- **Qué es:** una rejilla fina solo de dibujo (por ejemplo 960×540) en la que cada píxel fino pertenece a una celda lógica según una correspondencia **fija y determinista con ruido**: los bordes entre celdas dejan de ser rectos (formas orgánicas), las costas salen del ruido a alta resolución y el color se decide en un *shader* con dos texturas: «píxel fino → celda» (estática) y «celda → propietario/ocupante» (320×180, se actualiza al cambiar).
- **Ventajas:** aspecto orgánico y detallado sin cambiar ninguna regla; conquistas, combate, IA y pruebas de lógica intactos; el coste por cambio es subir una textura pequeña; la misma correspondencia sirve para el clic (lo que ves es lo que pulsas).
- **Riesgos:** más complejidad en la vista (*shader* y textura de correspondencia); hay que garantizar que la tierra dibujada siempre corresponde a celdas de tierra; la granularidad del avance sigue siendo la de la celda lógica (el frente avanza a saltos de «celda orgánica»).
- **Celdas lógicas:** 57.600. **Pruebas:** reescribir las pruebas de píxeles de la vista; añadir pruebas de la correspondencia (todo píxel fino apunta a una celda válida, contigüidad).

### Recomendación
1. Primero resolver P2-10 (subida de textura) y medir (sección 5).
2. Prototipo de la **opción 3** (que incluye lo de la opción 1) sin tocar reglas. Es lo que mejor encaja con «conservar el tamaño, más detalle, menos cuadriculado» con el menor riesgo.
3. Considerar la **opción 2** (como mucho ×4) solo si, tras jugar, la granularidad lógica de los frentes resulta un problema de juego, y solo después de resolver P3-01…P3-03.

---

## 10. Orden de trabajo propuesto para estabilizar la base

Cada fase depende de la anterior. No se recomienda empezar mecánicas nuevas hasta cerrar la fase C.

| Fase | Trabajo | Hallazgos | Depende de |
|---|---|---|---|
| **A. Validación local** (propietario) | Ejecutar las 10 suites en Godot 4.7.2 (`godot --headless --path . --script res://tests/test_<suite>.gd` o F6) y comunicar los resultados completos | P0-01, P1-03 | Este commit |
| **B. Arreglar lo que salga de A** | Corregir la preparación de DI-12 (P1-01) y cualquier otro fallo real, sin rebajar comprobaciones; actualizar TEST_PLAN/README/ROADMAP/GDD con los resultados reales | P1-01, P1-04, sección 7 | A |
| **C. Robustez de reglas** | Decidir y corregir el robo de ocupaciones (P1-02); recortes de bajas del defensor (P2-03); prueba de invariantes por tick (6.3); interruptor de propuestas automáticas para pruebas | P1-02, P2-03, 6.2, 6.3 | B |
| **D. Medición** | Medir tick, repintado e IA en una partida de 5–10 min; corregir P2-10 (pequeño); el resto de la sección 5 solo si los números lo piden | P2-10, P3-01…P3-04 | C |
| **E. Sesión de juego y decisiones de diseño** | Jugar con una lista de observación: territorio jugador vs IA a 3 min (P2-01), guerras simétricas (P2-02), guerras sin fin (P2-04), dinero sobrante (P2-07), ciudades (P2-06), pausa (P2-05), clics y mensajes (P2-08, P2-09) | P2-* | D |
| **F. Hitos de mayor alcance** | Con la base validada: reglas de diseño decididas en E, luego mapa (opción 3), construcciones, victoria | P3-12, D11, D14 | E |

Con este orden, ningún hito nuevo se construye sobre suites sin ejecutar ni sobre la incoherencia de ocupaciones entre tres naciones.

---

## Anexo — Verificación de esta auditoría

| Comprobación | Resultado |
|---|---|
| Git: rama, HEAD, sincronización | Comprobado; fast-forward de `81efaa6` a `641bd30` |
| Godot disponible | **No** |
| Compilación del proyecto | **No realizada** |
| Ejecución de pruebas | **No realizada**; ningún resultado de este documento procede de una ejecución |
| Revisión estática | Lectura completa de `offensives.gd`, `population.gd`, `city_manager.gd`, `military.gd`, `occupation.gd`, `war_state.gd`, `diplomacy.gd`, `ai_controller.gd`, `combat.gd`, `economy.gd`, `territory_screen.gd`, partes de `territory_grid.gd`, `territory_map_view.gd`, `military_panel.gd`, los archivos de equilibrio y las suites de diplomacia y jugabilidad; dos analizadores heurísticos (inferencia `:=`, miembros y aridad) sobre todos los `.gd` |
| Réplicas de mecánicas en otros lenguajes | No usadas (las cifras de los ejemplos son cálculo manual con las constantes) |
