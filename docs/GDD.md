# Documento de Diseño — Fronteras de Hierro

Leyenda:
- **[C]** Confirmado por el propietario.
- **[P]** Propuesta recomendada por Claude, pendiente de aprobación.
- **[A]** Abierto: sin decidir. Cada decisión abierta tiene un código (D1, D2…) listado en §12.

> El concepto cambió respecto a la primera versión de este documento (mapa de 14 provincias con ataques entre provincias). Esa versión pasó a ser un **prototipo legado** (§13). Todo lo que sigue describe la visión actual. **Implementado hasta ahora:** la base de datos del territorio en cuadrícula (hito 3), su vista pixelada con selección de celdas (hito 4, sin validar en Godot) la operación de conquista de celdas (hito 5), la leyenda con estadísticas territoriales por nación (hito 5b) —las cuatro suites de pruebas de los hitos 3–5b fueron ejecutadas por el propietario en Godot 4.7.2: 63 PASS— **ciudades y economía básica (hito 6; 21 PASS ejecutadas por el propietario, que comprobó que las ciudades aparecen y crecen)** y **población, movilización y mantenimiento (hito 7; 24 PASS ejecutadas por el propietario)** y **organización militar con sectores y asignación de soldados (hito 8, sin ejecutar ni validar en Godot)**; no hay combate ni ejércitos que se muevan. El resto de §5–§9 es diseño.

## 1. Concepto

- **[C]** Juego 2D de estrategia territorial en tiempo real.
- **[C]** Fácil de aprender y de jugar. Muy cercano a la experiencia general de OpenFront, con algunas mecánicas propias y algo más de profundidad, sin llegar a ser un RTS táctico complejo.
- **[C]** Inspirado en conceptos generales de OpenFront sin copiar sus mapas, recursos, código, nombres, interfaz ni contenido protegido. Mundo y naciones ficticios.
- **[C]** Godot 4.7, GDScript, Windows PC, pixel art, mapa cenital.
- **[C]** Tiempo real heredado de la versión anterior; el ritmo, la pausa y la velocidad se concretan en D10.

## 2. Dirección visual

- **[C]** CLEAN, minimalista y legible. El mapa es el elemento principal.
- **[C]** Territorio y fronteras pixeladas, con aspecto parecido al de OpenFront.
- **[C]** Las fronteras **no** dividen el territorio en provincias seleccionables.
- **[C]** Cada nación es un territorio **continuo** formado por celdas o elementos territoriales, no una colección de provincias.
- **[C]** Puede haber varias naciones en el mapa.
- **[C]** Las ciudades se muestran como agrupaciones de píxeles que crecen visualmente.
- **[C]** Marcadores y controles sencillos. Nunca se representan individualmente cientos de soldados.
- **[C]** Evitar interfaces recargadas, demasiadas animaciones y microgestión innecesaria.
- **[P]** Colores de nación planos y distinguibles; fronteras como un tono más oscuro de la propia nación; interfaz limitada a un HUD pequeño y paneles contextuales discretos.

## 3. Experiencia objetivo

- **[P]** Partidas de duración moderada, legibles de un vistazo: se ve quién domina qué territorio, dónde están las ciudades y hacia dónde crecen las fronteras.
- **[P]** Pocas decisiones por minuto, pero con consecuencias claras: dónde fundar ciudades, cómo repartir la población nueva, cuándo y dónde atacar.
- **[C]** El jugador debe entender si tiene ventaja antes de atacar (ver §8).
- **[C]** El juego debe ser sencillo de jugar; la interfaz, CLEAN.

## 4. Bucle de juego

**[P]** (a validar; depende de D3, D5 y D8)

1. El jugador empieza con un territorio inicial y la posibilidad de fundar una ciudad.
2. Las ciudades generan población, dinero y recursos con el tiempo.
3. El jugador reparte la población nueva entre trabajadores y soldados (control deslizante) y gasta dinero en construcciones.
4. Expande sus fronteras y ataca a otras naciones cuando percibe ventaja.
5. Las ciudades crecen visualmente y suben de nivel, aumentando su producción.
6. La partida termina con victoria o derrota (D11). Se puede reiniciar.

## 5. Territorio y naciones

**Confirmado [C]**
- No hay provincias: el territorio está formado por celdas.
- Cada nación es un territorio continuo formado por celdas; varias naciones posibles.
- Las fronteras son pixeladas, con estética similar a OpenFront, y surgen de la diferencia de propietario entre celdas adyacentes.
- En el futuro el jugador podrá concentrar un ataque en una zona concreta del mapa, con ayuda opcional de una flecha de dirección o herramienta visual equivalente (no implementado).

**Propuesta técnica [P]** — valores provisionales, **implementados en el hito 3** (`scripts/world/territory_grid.gd`); no son preferencias confirmadas y pueden cambiar si surge una limitación técnica real:
- Cuadrícula lógica de **320 x 180** celdas (57.600; 16:9). La ventana sigue siendo 1280x720; la futura vista usará `Image`/`ImageTexture` ampliada con filtro `nearest`.
- Dos `PackedByteArray` de 57.600 elementos: terreno y propietario. Índice lineal por filas: `index = y * 320 + x`.
- Terreno inicial: `WATER = 0` y `LAND = 1`, sin bonificaciones.
- Propietarios: `OWNER_NONE = 0` (agua o tierra sin reclamar), `OWNER_PLAYER = 1`, `OWNER_AI_1 = 2`, `OWNER_AI_2 = 3`, `OWNER_AI_3 = 4`. El agua siempre es `OWNER_NONE`; la tierra puede estar sin reclamar o ser de una nación.
- Cuatro naciones iniciales (jugador y tres rivales de IA futuros) con ID numérico, clave textual, nombre provisional y color. Los nombres son provisionales (D17).
- Mapa inicial determinista (sin azar): una masa de tierra con costa irregular, agua alrededor, cuatro pequeños territorios iniciales conectados y separados, y gran parte de la tierra sin reclamar para la expansión futura. El mapa no pretende ser bonito ni histórico.
- Las operaciones de cambio de propietario validan límites, nación conocida y terreno, y devuelven éxito o fracaso sin alterar el estado si fallan.
- El territorio es independiente de las ciudades: las ciudades se superponen y no definen las fronteras.

**Abierto [A]**
- D1: cámara con zoom y desplazamiento; si el mapa llegará a generarse de forma aleatoria; más tipos de terreno (los valores de arriba son provisionales).
- D2: número definitivo de naciones y quién controla cada una (4 es provisional).
- D3: fórmula y coste exactos de los ataques y cómo crece el territorio tras un ataque.
- D12: qué ocurre con una ciudad cuando su celda cambia de propietario.
- D18: cómo se selecciona y visualiza la zona de ataque.

## 6. Ciudades y población

**Confirmado [C]**
- Las ciudades se fundan haciendo clic en una ubicación válida del propio territorio; cuestan dinero y tardan un breve tiempo en fundarse.
- Al inicio, una ciudad ocupa una superficie visual pequeña (unos pocos píxeles o celdas) y crece visualmente desde su centro.
- Las ciudades crecen con el tiempo según la población trabajadora que se les asigna.
- El crecimiento se ralentiza progresivamente al aumentar el tamaño, para evitar que todo el país sea una superficie urbana enorme.
- Al alcanzar umbrales, la ciudad sube de nivel automáticamente; después su expansión visual sigue siendo posible, pero más lenta.
- La población se divide en **trabajadores** y **soldados**.
- Un control deslizante del HUD decide qué porcentaje de la **nueva** población generada va a trabajadores y qué porcentaje a soldados.
- Cambiar el control **no reasigna** la población que ya existe.
- El jugador puede activar una **prioridad de población** para una ciudad, que favorece su crecimiento poblacional.
- Existe una opción de **reclutamiento forzoso** que convierte un porcentaje de los trabajadores existentes en soldados durante un plazo corto, no instantáneamente.
- Cantidades, costes y equilibrio: sin definir.

**Propuesto [P]**
- La ciudad es una entidad separada del territorio: tiene identificador, nación propietaria, posición, nivel y tamaño visual propios.
- El crecimiento visual de la ciudad (más píxeles) y la expansión de fronteras de la nación son procesos distintos y no se mezclan.
- El tamaño de la ciudad se calcula con una función de crecimiento decreciente (cada píxel adicional cuesta más), con niveles por umbrales; la fórmula concreta se decide con D6.

**Abierto [A]**
- D4: condiciones exactas de una ubicación válida (distancia mínima entre ciudades, número máximo…), coste en dinero y tiempo de fundación. (Confirmado: clic en el propio territorio, coste en dinero, breve tiempo.)
- D5: cómo se asignan los trabajadores a cada ciudad (manual por ciudad, automático, por cercanía…) y si la población es global o por ciudad.
- D6: cómo se representa el crecimiento en el mapa (forma, regla de ocupación de píxeles, niveles y umbrales).
- D13: porcentaje elegible, duración del plazo corto y penalizaciones del reclutamiento forzoso.
- D19: efecto, coste y límites de la prioridad de población de una ciudad.
- D15: ¿el control deslizante es global de la nación o por ciudad?

## 7. Recursos

- **[C]** Solo dos recursos económicos:
  1. **Dinero**: se genera en las ciudades y financia construcciones.
  2. **Recursos**: se generan en las ciudades y mantienen a trabajadores y soldados.
- **[C]** No hay comida, combustible, munición, energía, materiales diferentes ni otros recursos. El modelo debe seguir siendo sencillo.
- **[A]** D14: cuánto produce cada ciudad y cómo depende de su nivel y trabajadores; cuánto consume cada trabajador y soldado; qué ocurre cuando los recursos no alcanzan; qué construcciones existen y cuánto cuestan.
- **[P]** Identificadores internos `money` y `supplies` para evitar confundir el recurso "Recursos" con la categoría general.

## 8. Combate y ejércitos

- **[C]** El jugador debe entender fácilmente si tiene ventaja antes de atacar.
- **[C]** Cuando se defina el combate, el juego mostrará una previsión comprensible de las posibilidades de victoria y las pérdidas estimadas.
- **[C]** Los ejércitos se representan inicialmente mediante una **cifra de soldados**. No se crean regimientos ni entidades individuales de soldados.
- **[C]** En el futuro, el jugador podrá concentrar un ataque en una zona concreta del mapa, con ayuda opcional de una flecha de dirección (ver §5, D18).
- **[P]** D7 (provisional, hito 8): el total es una cifra nacional y el jugador lo reparte entre sectores de despliegue; ver «Organización militar (hito 8)». **[A]** Abierto: otras agrupaciones (por ciudad) y cómo se combina todo en un ataque. La directriz anterior de "no usar un único número global" se reconcilia así: hay un total nacional, pero la fuerza útil es la de cada sector.
- **[A]** D8: combate determinista o con azar (si hay azar, cómo se expresa la "probabilidad de victoria").
- **[P]** Independientemente de D7/D8, el cálculo de la previsión será una función pura y comprobable, separada de la interfaz.

## 9. HUD y controles

- **[C]** Control deslizante en el HUD para repartir la población nueva entre trabajadores y soldados.
- **[C]** Opción de reclutamiento forzoso.
- **[P]** Clic izquierdo para seleccionar o actuar sobre el mapa; panel contextual pequeño para ciudades y naciones; indicadores discretos de dinero y recursos; cámara con zoom y desplazamiento si el mapa lo requiere (D1, D10).
- **[P]** Ningún botón se añade hasta que la acción que dispara existe.

## 10. Mecánica diferenciadora

- **[C]** Las ciudades, el crecimiento urbano y la gestión sencilla de la población **podrían** ser parte de la identidad del juego.
- **[A]** D9: cuál es la mecánica propia definitiva. **No es una decisión tomada.** Se decidirá tras valorar alternativas con el propietario; hasta entonces ningún documento ni código debe presentarlo como definitivo.

## 11. Alcance del MVP

**[P]** (propuesta; el MVP no está confirmado bajo la nueva visión)

Un mapa pixelado con varias naciones, expansión territorial, fundación y crecimiento de ciudades, reparto de población trabajadores/soldados con reclutamiento forzoso, dos recursos, ataques con previsión de ventaja, una IA simple, victoria/derrota y reinicio.

Fuera del MVP: multijugador, guardado de partida, más recursos (excluidos por diseño), investigación, diplomacia, suministros y cualquier mecánica no listada aquí.

## 12. Decisiones abiertas

| Código | Pregunta | Bloquea |
|---|---|---|
| D1 | Provisional: 320x180, agua/tierra, mapa determinista (hito 3). Abierto: cámara (zoom/desplazamiento), mapa aleatorio, más terrenos | Hito 4 (cámara) |
| D2 | Provisional: 4 naciones (jugador + 3 de IA; campo `controller` human/ai). Abierto: cuántas en el MVP y quién las controla | Tras el hito 5b |
| D3 | Fórmula y coste de los ataques; cómo crece el territorio tras atacar; cómo se expande hacia tierra vacía | Hito 7 (aplazado) |
| D4 | Provisional (hito 6): coste 100, distancia mínima 9, fundación **inmediata** (el tiempo de fundación confirmado **no está implementado**: pendiente registrado). Abierto: valores definitivos, tiempo de fundación, límite de ciudades | Revisión en el equilibrado |
| D5 | Provisional (hito 7): población **nacional**, sin asignar trabajadores a ciudades concretas (fuera del diseño actual). Abierto: producción según trabajadores | Hito 9 |
| D6 | Provisional (hito 6): 4 niveles, umbrales 30/60/120 ticks, rombo de píxeles. Hito 7: el nivel fija capacidad y crecimiento de población, pero la población no acelera el crecimiento visual. Abierto: relación definitiva | Ninguno directo |
| D7 | Provisional (hito 8): el total de soldados es **nacional** (`Population`) y el jugador lo reparte entre **sectores** de una celda; el resto es la reserva. Abierto: si hay otras agrupaciones (por ciudad), cómo se combinan en un ataque y si un sector crece a varias celdas | Hito 10 |
| D8 | Combate determinista o con azar; significado de la probabilidad de victoria | Hito 10 |
| D9 | Mecánica diferenciadora definitiva | Ninguno directo; afecta a la prioridad |
| D10 | Ritmo del tiempo real: pausa, control de velocidad, duración objetivo de la partida | Hito 7 |
| D11 | Condiciones de victoria y derrota | Hito 13 |
| D12 | Destino de las ciudades cuando cambia el propietario de su territorio | Hito 10 |
| D13 | Provisional (hito 7): movilización de hasta el 50 % de los trabajadores en 30 ticks, sin penalizaciones propias. Abierto: valores definitivos y penalizaciones | Revisión en el equilibrado |
| D14 | Provisional (hitos 6 y 7): producción por nivel de ciudad y mantenimiento por persona con déficit gradual. Abierto: producción según trabajadores, construcciones | Hito 9 |
| D15 | Provisional (hito 7): el control de reparto es **global de la nación**. Abierto: ¿por ciudad? | Ninguno directo |
| D16 | Retirada del prototipo de provincias: cuando el nuevo mapa visual y su interacción estén validados a mano por el propietario | Tras el hito 4–5 |
| D17 | Nombres: mundo, naciones y ciudades (hoy hay nombres provisionales de naciones) | Sin bloqueo |
| D18 | Cómo se selecciona y visualiza la zona de ataque (flecha u otra herramienta) | Hito 10 |
| D19 | Provisional (hito 7): prioridad por ciudad, x2 al crecimiento de población, sin coste ni límite. Abierto: coste y límites definitivos | Revisión en el equilibrado |
| D20 | Provisional (hito 8): sin límite de sectores por nación, sin coste en dinero ni recursos, objetivo de una sola celda y sin condición diplomática para apuntar a otra nación (planificar no es atacar). Abierto: límite o coste de sectores, frentes de varias celdas y qué exige realmente una guerra (declaración formal, tratados, treguas) | Hito 10 |

## 13. Prototipo anterior de provincias (legado)

Implementado en los hitos 0–2 y validado a mano por el propietario en Godot 4.7.2 (pantalla inicial, mapa y selección). Las pruebas automáticas **no** están confirmadas como ejecutadas.

- Mapa estático de 14 provincias (7 jugador, 7 enemigo) con vecindades, dibujado con polígonos.
- Selección con clic izquierdo y panel de información (nombre, propietario, vecinas).

Este prototipo **no se amplía** y no define el diseño actual: las provincias seleccionables contradicen §2. Se mantiene intacto mientras se construye y valida el sistema territorial nuevo; su retirada se decidirá cuando el nuevo mapa visual y su interacción hayan sido validados manualmente en el PC del propietario (D16). Detalle en `docs/REDESIGN_PLAN.md` §2.

## Regla de conquista territorial (hito 5)

- **[C]** El territorio solo cambia de propietario como consecuencia de una **conquista explícita**. Nunca se expande solo por el tiempo, la economía, el crecimiento de una ciudad ni por dibujar el mapa. (Confirmado por el propietario.)
- **[P]** Una conquista es un conjunto concreto de celdas de **tierra**, contiguo por vecinos ortogonales y con contacto ortogonal con el territorio actual del atacante; se aplica entera o no se aplica. El agua nunca tiene propietario. Puede tomar tierra de otra nación o sin reclamar.
- **[A]** Quién puede atacar, cuándo, qué celdas, con qué coste y cómo se resuelve (D3, D7, D8) sigue abierto; el hito 5 solo implementa la operación segura que usará el combate.

## Información territorial en pantalla (hito 5b)

- **[P]** La leyenda muestra por nación las **celdas de tierra** que controla y su **porcentaje de la tierra total** del mapa (agua excluida). Son estadísticas de territorio: no representan población, poder militar ni economía. La nación del jugador se marca en la leyenda y se resume arriba a la derecha.
- **[P]** Las cifras se derivan siempre de la cuadrícula; no se guardan copias.

## Ciudades y economía básica (hito 6)

Implementado. El propietario ejecutó en Godot 4.7.2 sus 21 pruebas (21 PASS) y comprobó que las ciudades iniciales aparecen y crecen visualmente. Todos los números son **[P] provisionales**, centralizados en `scripts/data/economy_balance.gd`, y se ajustarán al equilibrar.

- **[C]** Solo dos recursos: dinero y recursos. No hay tercer recurso (el dinero servirá también, más adelante, para los pagos de los tratados de paz).
- **[P]** Cada nación empieza con una **ciudad de nivel 1** (sin ser capital ni tener bonificaciones), 50 de dinero y 0 de recursos. Las ciudades iniciales están en el territorio inicial de cada nación.
- **[P]** Fundar una ciudad: el jugador pulsa «Fundar ciudad» y hace clic en una celda. Debe estar dentro del mapa, ser tierra del jugador, sin ciudad, a **al menos 9 celdas (Chebyshev) de cualquier ciudad** (propia o ajena) y el jugador debe tener **100 de dinero**. Solo se cobra cuando la fundación se completa; si no, mensaje breve y se puede reintentar o cancelar (`Esc`). **Inmediata** por ahora; el «breve tiempo de fundación» confirmado queda pendiente.
- **[P]** Crecimiento: +1 punto por segundo de juego; niveles 1→2 a 30, 2→3 a 60 y 3→4 a 120 puntos (cada vez más lento); el nivel 4 es el máximo. Mancha de píxeles de 5, 13, 25 y 41 celdas (rombo de radio 1–4), dentro del territorio del propietario. **El crecimiento es visual y de nivel: nunca cambia propietarios ni conquista celdas.**
- **[P]** Producción por segundo y ciudad según nivel: dinero 2/3/5/8 y recursos 1/2/3/5. Se paga al propietario actual de la ciudad.
- **[P]** Si una celda con ciudad cambia de propietario (conquista), la ciudad pasa al nuevo propietario con su nivel y progreso; no se destruye. Es una decisión provisional que **adelanta una respuesta a D12** (destino de las ciudades) solo en lo mínimo; la ocupación militar provisional no existe todavía y no se ha acoplado.
- **[P]** HUD: dinero y recursos del jugador arriba a la derecha, con su ingreso por segundo; el panel de celda añade propietario, nivel, producción y crecimiento de la ciudad que cubra la celda seleccionada.
- Población, trabajadores, soldados, prioridad de población y mantenimiento se añadieron después, en el hito 7 (ver abajo); **tampoco hay expansión territorial automática**. Pendiente: la fundación es instantánea y el tiempo de fundación confirmado no está implementado.

## Población, movilización y mantenimiento (hito 7)

Implementado; el propietario ejecutó sus 24 pruebas en Godot 4.7.2 (24 PASS; la validación visual del panel no se ha registrado). Todos los números son **[P] provisionales**, centralizados en `scripts/data/population_balance.gd`. Nada de esto crea combate, ejércitos que se muevan ni cambia fronteras: **la población, la economía y el mantenimiento nunca modifican el territorio** (solo `conquer_cells`).

**Modelo.** La población es **nacional**: por nación se guardan trabajadores y soldados; total, trabajadores disponibles (sin reservar), capacidad y crecimiento se derivan. Las ciudades no guardan población: cada ciudad activa (con propietario) contribuye según su nivel al crecimiento y a la capacidad de su propietario. Una ciudad conquistada contribuye al nuevo dueño. Los soldados son una **cifra nacional** (no hay unidades dibujadas); desde el hito 8 el jugador reparte esa cifra entre sectores (ver «Organización militar (hito 8)»).

| Concepto | Regla | Valor provisional |
|---|---|---|
| Población inicial | Igual para las cuatro naciones, configurable por nación | 30 trabajadores + 6 soldados |
| Crecimiento (por ciudad y tick) | Según nivel 1/2/3/4; las fracciones se acumulan | 0,15 / 0,20 / 0,25 / 0,30 personas |
| Capacidad (por ciudad activa) | Tope de población nacional = suma de las suyas; si se supera (p. ej. por perder una ciudad) nadie desaparece por ello | 50 / 90 / 150 / 240 |
| Prioridad de crecimiento | Casilla por ciudad (solo en ciudades del jugador). Multiplica el crecimiento de población de **esa** ciudad; varias a la vez actúan cada una por separado (marcarlas todas equivale a duplicar el crecimiento nacional); sin coste ni límite por ahora. Si la ciudad cambia de dueño, la prioridad del anterior deja de aplicarse. No toca territorio, dinero ni niveles | x2 |
| Reparto de la población nueva | % a soldados (el resto a trabajadores, siempre suman 100). Solo afecta a los nacidos a partir de ese momento. Los nacidos de un tick se reparten con un resto acumulado: nadie se pierde ni se duplica | 20 % soldados |
| Movilización | Orden sobre un % de los trabajadores actuales: se reservan ya (redondeo hacia abajo, al menos 1 persona) y se convierten en soldados a ritmo constante. Solo una a la vez por nación; la población total no cambia; los nacidos durante el proceso siguen el reparto vigente | hasta 50 %, en 30 ticks |
| Mantenimiento | Cada persona consume «recursos» cada tick (con el resto fraccionario acumulado, sin redondear a favor ni en contra) | trabajador 0,012; soldado 0,025 |
| Prioridad de mantenimiento | Qué grupo cobra primero cuando no alcanzan los recursos: **Economía** (trabajadores) o **Ejército** (soldados). El otro recibe lo que quede | Economía primero |
| Déficit | Lo que no se puede pagar queda como **deuda** del grupo (límite: 3 ticks de su coste); la deuda se salda antes que el coste nuevo | — |

**Consecuencias exactas del déficit** (por grupo con deuda, en este orden):
1. Desde el primer tick con deuda: **la nación no genera población nueva** y el HUD muestra «Déficit: sin recursos para … Sin crecimiento.».
2. Tras **5 ticks seguidos** con deuda: el grupo pierde cada tick un **1 %** (mínimo 1 persona) de sus miembros hasta saldar la deuda; el HUD muestra «Déficit grave…». Trabajadores: mueren o emigran; soldados: desertan. **No son bajas de combate** (el combate no existe).
3. Si se vuelve a poder pagar, la deuda se salda, el déficit termina y se reanuda el crecimiento. Si se movilizaba, la reserva se recorta para no superar nunca a los trabajadores que quedan.
Los saldos de dinero y recursos **nunca** son negativos: el mantenimiento paga solo lo que hay. El dinero no interviene en el mantenimiento.

**Equilibrio inicial** (comprobado por prueba): a población máxima el coste cabe en la producción de las ciudades del mismo nivel con cualquier mezcla razonable (por ejemplo, mitad trabajadores y mitad soldados); solo una población casi totalmente de soldados excede la producción (un soldado cuesta más que un trabajador). El juego por defecto, con las cuatro naciones, no entra en déficit en 600 ticks aunque el jugador reparta al 50 % y movilice el 25 % cada 40 ticks; un déficit provocado (población mayor que la producción) se corrige solo por las pérdidas graduales y la subida de nivel de las ciudades.

**Límites conocidos:** la producción de las ciudades **no depende todavía de los trabajadores** (solo del nivel; D14), así que ahora mismo los trabajadores solo cuestan recursos y la población sirve de base al futuro ejército. Las consecuencias del déficit sobre la fuerza militar dependen del combate (hito 10) y no están implementadas. No hay pausa del tiempo (D10).

**HUD.** Panel «Población» a la derecha del mapa (resumen de población, trabajadores y soldados; crecimiento; deslizador y porcentajes de la población nueva; deslizador y botón de movilización con barra de progreso y pendientes; coste de mantenimiento frente a producción, estado suficiente/insuficiente, botón de prioridad de mantenimiento y aviso de déficit). La casilla de prioridad de crecimiento está en el panel de información de la ciudad del jugador seleccionada. Todo se lee de los datos reales.

## Organización militar (hito 8)

Implementado, con pruebas escritas (MI-01…MI-18) pero **sin ejecutar ni validar en Godot**. Es una capa de **planificación**: no hay combate, bajas, avance de tropas, invasiones, ocupación, declaración de guerra, tratados ni IA militar. **El territorio solo cambia por `conquer_cells`: crear sectores o asignar soldados nunca cambia fronteras.**

**Modelo.** Un **sector** es una orden de despliegue: id estable (no se reutiliza), nación, celda de **origen**, **dirección** ortogonal (norte, este, sur, oeste; sin diagonales), celda **objetivo** contigua en esa dirección y **soldados asignados**. El objetivo es una sola celda en esta versión; se guarda aparte del origen y la dirección para poder ampliarlo después a un frente de varias celdas.

| Regla | Detalle |
|---|---|
| Creación | El origen está dentro del mapa y es de la nación; el objetivo contiguo está dentro del mapa y es tierra; no existe ya un sector con el mismo origen y dirección. Orden de comprobación: nación, dirección, origen en el mapa, origen propio, objetivo en el mapa, objetivo tierra, duplicado |
| Objetivo | Puede ser tierra propia, sin reclamar o de otra nación. Apuntar a otra nación **no inicia una guerra** ni exige nada diplomático (D20) |
| Varios sectores | Se pueden crear tantos como se quiera (también el mismo origen en otras direcciones y otros orígenes en la misma dirección), así que se pueden concentrar fuerzas en distintos puntos de una misma frontera |
| Soldados | Fuente de verdad: `Population.soldiers`. No se duplica el contador. Disponibles (reserva) = soldados − suma de los asignados de la nación. Asignar o liberar **no crea ni elimina soldados** y no convierte trabajadores |
| Asignación | Fijar, aumentar o reducir la cantidad de un sector; no se admite más que la reserva ni cantidades negativas; la redistribución nunca causa bajas |
| Eliminar | Retira todos los soldados del sector (vuelven a la reserva) y lo elimina |
| Economía | Los sectores no producen ni consumen dinero ni recursos; el mantenimiento sigue dependiendo de los soldados nacionales |

**Cuando bajan los soldados** (deserción por déficit de recursos u otro sistema de población): al final de ese cambio, si lo asignado supera el total real, el exceso se quita **empezando por el sector más nuevo** (id mayor) y siguiendo hacia los más antiguos; cada sector pierde como mucho lo que tiene. Los sectores no se eliminan (pueden quedar con 0) y esos soldados **no** vuelven a la reserva porque ya no existen. Es una decisión provisional y determinista.

**Cuando se pierde el origen** (una conquista le quita la celda de origen a la nación): el sector se elimina y sus soldados vuelven a la reserva. Si solo cambia de dueño el objetivo, el sector sigue.

**Interfaz.** Panel «EJÉRCITO» en la columna izquierda: soldados totales, asignados y disponibles; el **origen** es la celda seleccionada en el mapa (si no es propia se explica por qué no se puede crear); cuatro botones N/E/S/O; «Crear sector»; lista de sectores; detalle (origen, objetivo, dirección, a quién pertenece el objetivo y soldados); botones −5 −1 +1 +5 (los incrementos se recortan a lo que hay) y «Liberar y eliminar». En el mapa, cada sector es un marcador discreto: celda de origen, línea hasta la celda objetivo y la cifra de soldados; el elegido lleva un recuadro. Los paneles capturan el clic, así que no seleccionan el mapa por error. **Límites visuales conocidos:** con muchos sectores contiguos las cifras pueden solaparse y en el peor caso el panel puede acercarse al borde inferior; el aspecto se tratará en la fase visual.

**No implementado (hitos posteriores):** combate, probabilidades de victoria y bajas, avance automático, invasión o cambios de propietario, ocupación militar provisional (deberá mantenerse separada de la propiedad territorial), declaración de guerra, tratados, paz blanca o treguas, IA que cree sectores, flecha de ataque (D18).
