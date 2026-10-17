# Documento de Diseño — Fronteras de Hierro

Leyenda:
- **[C]** Confirmado por el propietario.
- **[P]** Propuesta recomendada por Claude, pendiente de aprobación.
- **[A]** Abierto: sin decidir. Cada decisión abierta tiene un código (D1, D2…) listado en §12.

> El concepto cambió respecto a la primera versión de este documento (mapa de 14 provincias con ataques entre provincias). Esa versión pasó a ser un **prototipo legado** (§13). Todo lo que sigue describe la visión actual. **Implementado hasta ahora:** la base de datos del territorio en cuadrícula (hito 3), su vista pixelada con selección de celdas (hito 4, sin validar en Godot) y la operación de conquista de celdas (hito 5, sin ejecutar sus pruebas); no hay combate ni otras mecánicas. El resto de §5–§9 es diseño.

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
- **[A]** D7: dónde se guarda y cómo se agrupa la cifra de soldados (por nación, por ciudad, por zona de ataque…). La directriz anterior de "no usar un único número global" queda pendiente de reconciliar con esta decisión.
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
| D2 | Provisional: 4 naciones (jugador + 3 de IA). Abierto: cuántas en el MVP y quién las controla | Hito 5b |
| D3 | Fórmula y coste de los ataques; cómo crece el territorio tras atacar; cómo se expande hacia tierra vacía | Hito 6 |
| D4 | Condiciones exactas, coste y tiempo de fundación de ciudades | Hito 7 |
| D5 | Asignación de trabajadores a ciudades; población global o por ciudad | Hito 8 |
| D6 | Representación del crecimiento urbano, niveles y umbrales | Hito 7–8 |
| D7 | Dónde se guarda y cómo se agrupa la cifra de soldados | Hito 10 |
| D8 | Combate determinista o con azar; significado de la probabilidad de victoria | Hito 10 |
| D9 | Mecánica diferenciadora definitiva | Ninguno directo; afecta a la prioridad |
| D10 | Ritmo del tiempo real: pausa, control de velocidad, duración objetivo de la partida | Hito 6 |
| D11 | Condiciones de victoria y derrota | Hito 13 |
| D12 | Destino de las ciudades cuando cambia el propietario de su territorio | Hito 10 |
| D13 | Reclutamiento forzoso: porcentaje elegible, duración, penalizaciones | Hito 11 |
| D14 | Producción, consumo, construcciones y costes del dinero y los recursos | Hito 9 |
| D15 | Control deslizante: global de la nación o por ciudad | Hito 8 |
| D16 | Retirada del prototipo de provincias: cuando el nuevo mapa visual y su interacción estén validados a mano por el propietario | Tras el hito 4–5 |
| D17 | Nombres: mundo, naciones y ciudades (hoy hay nombres provisionales de naciones) | Sin bloqueo |
| D18 | Cómo se selecciona y visualiza la zona de ataque (flecha u otra herramienta) | Hito 10 |
| D19 | Prioridad de población: efecto, coste y límites | Hito 8 |

## 13. Prototipo anterior de provincias (legado)

Implementado en los hitos 0–2 y validado a mano por el propietario en Godot 4.7.2 (pantalla inicial, mapa y selección). Las pruebas automáticas **no** están confirmadas como ejecutadas.

- Mapa estático de 14 provincias (7 jugador, 7 enemigo) con vecindades, dibujado con polígonos.
- Selección con clic izquierdo y panel de información (nombre, propietario, vecinas).

Este prototipo **no se amplía** y no define el diseño actual: las provincias seleccionables contradicen §2. Se mantiene intacto mientras se construye y valida el sistema territorial nuevo; su retirada se decidirá cuando el nuevo mapa visual y su interacción hayan sido validados manualmente en el PC del propietario (D16). Detalle en `docs/REDESIGN_PLAN.md` §2.

## Regla de conquista territorial (hito 5)

- **[C]** El territorio solo cambia de propietario como consecuencia de una **conquista explícita**. Nunca se expande solo por el tiempo, la economía, el crecimiento de una ciudad ni por dibujar el mapa. (Confirmado por el propietario.)
- **[P]** Una conquista es un conjunto concreto de celdas de **tierra**, contiguo por vecinos ortogonales y con contacto ortogonal con el territorio actual del atacante; se aplica entera o no se aplica. El agua nunca tiene propietario. Puede tomar tierra de otra nación o sin reclamar.
- **[A]** Quién puede atacar, cuándo, qué celdas, con qué coste y cómo se resuelve (D3, D7, D8) sigue abierto; el hito 5 solo implementa la operación segura que usará el combate.
