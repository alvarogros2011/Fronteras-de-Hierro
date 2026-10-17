# Documento de Diseño — Fronteras de Hierro

Leyenda: **[C]** = decisión confirmada por el propietario. **[S]** = suposición propuesta, pendiente de validar.

## 1. Concepto

- **[C]** Estrategia 2D en tiempo real de conquista de territorios y guerra.
- **[C]** El jugador dirige una nación ficticia en un mapa de provincias conectadas, conquista territorio, mueve tropas y combate contra una facción enemiga controlada por IA.
- **[C]** Inspirado en conceptos generales de OpenFront y Call of War, sin copiar contenido protegido.
- **[C]** Godot 4.7, GDScript, Windows PC, pixel art, mapa estratégico cenital.

## 1b. Dirección de diseño permanente

**Confirmado [C]:**
- Fácil de aprender y de jugar. Muy cercano a OpenFront en el bucle general: expansión territorial, ataques y economía sencilla.
- Con una **mecánica propia** que se definirá progresivamente (ver "Pendiente").
- Presentación **clean**: el mapa es lo principal; interfaz minimalista y legible; colores territoriales claros y consistentes; elementos visuales discretos y funcionales; sin exceso de efectos, animaciones, ventanas o información.
- No es un RTS táctico detallado.
- Economía futura con como máximo uno o dos recursos.
- La resolución de combates debe permitir entender fácilmente si se tiene ventaja antes de iniciar un ataque.
- Las tropas futuras no tienen por qué ser una única cifra global, pero no se simulan soldados individuales ni se crea una interfaz táctica recargada.

**Pendiente de decisión del propietario (no definido, no implementado):**
- Modelo concreto de unidades.
- Mecánica diferenciadora.
- Cuándo se introduce la economía (el alcance del MVP de §6 no la incluye).

Las propuestas **[S]** de tropas y combate de §4 son provisionales y pueden cambiar con estas decisiones.

## 2. Experiencia objetivo

- **[S]** Partidas cortas (5–15 minutos) y legibles de un vistazo: se ve quién posee cada provincia y cuántas tropas hay.
- **[S]** Decisiones tácticas simples: dónde atacar, dónde acumular tropas, qué frontera descuidar.
- **[S]** El resultado de cada combate es predecible y explicable (sin azar oculto).

## 3. Bucle de juego (MVP)

1. Se muestra el mapa con provincias del jugador y del enemigo.
2. El jugador selecciona una provincia propia y ordena un ataque o movimiento hacia una provincia adyacente.
3. Las tropas actúan en tiempo real; el combate se resuelve con reglas deterministas.
4. Si el atacante vence, la provincia cambia de dueño.
5. La IA enemiga actúa en paralelo con las mismas reglas.
6. La partida termina con victoria (enemigo sin provincias) o derrota (jugador sin provincias). Se puede reiniciar.

## 4. Mecánicas principales

| Mecánica | Descripción | Estado |
|---|---|---|
| Mapa | Provincias conectadas por adyacencia (grafo). | **[C]** 14 provincias, ficticio; dibujo estático **implementado** en el hito 1 |
| Propiedad | Cada provincia pertenece al jugador o al enemigo. | **[C]** reparto inicial 7 contra 7 (datos y color implementados; sin cambios de dueño aún) |
| Selección | Elegir una provincia con el ratón y consultar su información básica (nombre, propietario, vecinas). | **[C]**; **implementado** en el hito 2 |
| Ataque | Solo contra provincias adyacentes de otro dueño. | **[C]** |
| Movimiento de tropas | Mover tropas entre provincias. | **[C]** existe; detalle **[S]** |
| Combate | Determinista y comprobable. | **[C]**; fórmula **[S]** |
| Captura | El atacante victorioso cambia el dueño. | **[C]** |
| IA enemiga | Decide ataques con reglas simples. | **[C]**; reglas **[S]** |
| Victoria/derrota | Condiciones claras y reinicio de partida. | **[C]** |

### Propuestas de detalle (todas **[S]**)

- Cada provincia tiene un número entero de tropas (**provisional**: el modelo de unidades está pendiente, ver §1b).
- Las provincias suelen empezar con tropas fijas definidas en el mapa; el número de provincias iniciales por bando es simétrico.
- Combate: el atacante envía N tropas contra D defensoras. Si N > D, gana: la provincia pasa al atacante con N − D tropas. Si N ≤ D, el atacante pierde todo y el defensor queda con D − N. Sin azar.
- "Tiempo real": las órdenes de tropas tardan un tiempo fijo en completarse; la IA decide cada X segundos.
- Sin generación de tropas en el MVP, o con una tasa fija y muy simple, a decidir en el hito de combate.

## 5. Controles previstos **[S]**

| Acción | Control |
|---|---|
| Seleccionar provincia / ver su información | Clic izquierdo (**implementado**) |
| Limpiar selección | Clic izquierdo en una zona vacía del mapa (**implementado**) |
| Ordenar ataque/movimiento | Clic izquierdo sobre provincia adyacente con una propia seleccionada |
| Cancelar selección con teclado/ratón derecho | Clic derecho o `Esc` (pendiente; no implementado) |
| Reiniciar partida | Botón en pantalla final y tecla `R` |
| Pausa | `Espacio` (opcional, a decidir) |

## 6. Alcance del MVP

El MVP incluye, y solo incluye:

1. Mapa ficticio de 14 provincias conectadas (7 jugador, 7 enemigo al inicio). **[Implementado, estático, en el hito 1]**
2. Propiedad jugador/enemigo.
3. Selección de provincia y ataques a adyacentes.
4. Movimiento de tropas y combate determinista y comprobable.
5. Captura de provincias.
6. IA enemiga simple.
7. Condiciones de victoria y derrota claras.
8. Reinicio de partida.

### Selección e información (hito 2) **[S]**

- La selección usa los **polígonos reales** de `province_data.gd` (`Geometry2D.is_point_in_polygon`), en coordenadas locales del nodo del mapa, por lo que sigue funcionando si el mapa se mueve o escala.
- Cualquier provincia (propia o enemiga) se puede seleccionar solo para consultarla; restringir qué provincias pueden ser origen de acciones llegará con el combate.
- Una provincia seleccionada se resalta con un contorno claro; el color del propietario no cambia.
- Panel a la derecha: nombre, propietario ("Jugador"/"Enemigo"), número y nombres de las vecinas. Sin selección muestra una invitación a seleccionar.
- Sin botones de acción: aún no existen acciones.
- En un punto exacto de una frontera compartida gana la primera provincia de la lista (o ninguna si el redondeo lo deja fuera); el resultado es siempre el mismo.
- El propietario mostrado es el inicial de los datos; cuando haya capturas hará falta un estado de partida separado de los datos iniciales.

### Mapa del hito 1 **[S]**

- Rejilla irregular de 5x3 casillas sin la esquina inferior derecha (14 provincias). Dos provincias son vecinas si comparten una arista; las que solo se tocan en una esquina no lo son.
- Todos los nombres son provisionales. Ids ASCII estables (p. ej. `villa_roble`).
- El jugador ocupa el oeste y la provincia central; el enemigo, el este y el norte/sur del centro.
- Los datos viven en un único módulo (`scripts/data/province_data.gd`); el dibujo los lee de ahí.

## 7. Funcionalidades posteriores (fuera del MVP)

Requieren aprobación expresa antes de empezar:

- Recursos y economía.
- Reclutamiento.
- Edificios.
- Distintos tipos de unidad.
- Investigación.
- Líneas de suministro.
- Más facciones, más mapas, menús, sonido, guardado de partida.

## 8. Decisiones abiertas

| # | Pregunta | Propuesta inicial |
|---|---|---|
| 1 | ¿Regla exacta de combate? | La del apartado 4 (atacante gana si N > D). |
| 2 | ¿Las provincias generan tropas? | Tasa fija simple, decidir en el hito de combate. |
| 3 | ¿Tiempo real con pausa? | Sí, pausa opcional. |
| 4 | ¿Cómo se dibuja el mapa? | Polígonos 2D coloreados (hecho en hito 1); pixel art después. |
| 5 | ¿Nombres de la nación, el enemigo y las provincias? | Ficticios, a proponer por el propietario. |
| 6 | ¿Tamaño de la resolución de pixel art? | Por definir al llegar a los gráficos. |
| 7 | ¿Pruebas automáticas con GUT o con scripts propios? | Scripts propios sin plugin (ver TEST_PLAN). |
