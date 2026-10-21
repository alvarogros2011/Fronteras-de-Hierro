## Valores de equilibrio del combate, la ocupación y el avance de las ofensivas (hito 9). TODOS son
## PROVISIONALES: sirven para que el prototipo sea jugable y se ajustarán al equilibrar. Es el único
## sitio donde cambiarlos (la fórmula está explicada en docs/GDD.md, «Ataques, combate y ocupación»).
##
## Todas las cifras son enteras y el combate no usa azar: el mismo estado de partida da siempre el
## mismo resultado. Los porcentajes se aplican con redondeo hacia arriba cuando son bajas (ver
## Combat.ceil_percent), así que un enfrentamiento con defensores siempre cuesta al menos 1 baja
## al bando que corresponda. Un tick dura EconomyBalance.TICK_SECONDS segundos de juego.
extends RefCounted

# --- Avance ---
## Ticks entre un intento de avance y el siguiente (con TICK_SECONDS = 1, segundos de juego).
const ADVANCE_INTERVAL_TICKS := 3

# --- Defensa local estimada ---
## Porcentaje de los soldados reales de la nación defensora que se reparte entre sus tramos de
## frontera (100 = todos). Es un único fondo común: NO se cuenta completo en cada tramo.
const DEFENSE_POOL_PERCENT := 100
## Celdas expuestas (tierra de la nación en contacto ortogonal con tierra de otra nación) que forman
## un tramo de frontera. Tramos = techo(celdas expuestas / este valor), al menos 1.
const CELLS_PER_FRONT := 8
## Defensa mínima de un tramo cuando la nación tiene algún soldado.
const MIN_LOCAL_DEFENSE := 1
## Defensa de la tierra sin reclamar (0 = sin resistencia: avanzar solo cuesta tiempo).
const UNCLAIMED_DEFENSE := 0

# --- Resolución de un enfrentamiento ---
## Bonificación del defensor: su defensa se multiplica por este porcentaje (120 = +20 %). El atacante
## gana solo si atacantes * 100 > defensa * este valor (un empate lo gana la defensa).
const DEFENSE_BONUS_PERCENT := 120
## Bajas del bando vencedor, como porcentaje de la fuerza del vencido.
const WINNER_LOSS_PERCENT := 35
## Bajas del bando vencido, como porcentaje de su propia fuerza.
const LOSER_LOSS_PERCENT := 70

# --- Etiquetas de la previsión (relación atacantes / defensa efectiva, en milésimas) ---
## A partir de este valor: «ventaja atacante».
const ADVANTAGE_RATIO_PERMILLE := 1500
## Por debajo de este valor: «defensa superior». Entre ambos: «combate equilibrado».
const DEFENSE_RATIO_PERMILLE := 800

# --- Frente ancho (hito 11) ---
## Una ofensiva ya no avanza en una línea de una celda: en cada intento de avance toma una franja del
## objetivo alrededor de su punta. Semiancho de esa franja (distancia Chebyshev a la celda siguiente
## a la punta): 4 = una ventana de 9 x 9 celdas. 0 reproduce el avance de una celda del hito 9.
const FRONT_HALF_WIDTH := 4
## Celdas que puede tomar como mucho una ofensiva en un intento de avance.
const MAX_CELLS_PER_STEP := 12
## Soldados del frente por cada celda que puede tomar en un avance (redondeo hacia abajo, al menos 1):
## contra una nación, con 3 soldados toma 1 celda por avance y con 36 o más, el máximo. Más tropas =
## avance más rápido. En una expansión (tierra sin reclamar, sin defensa) basta 1 soldado por celda.
const SOLDIERS_PER_CELL := 3
const EXPANSION_SOLDIERS_PER_CELL := 1

# --- Defensa (hito 11) ---
## Los soldados comprometidos en una ofensiva ACTIVA no defienden: el fondo de defensa de una nación
## son sus soldados menos los que están atacando (reserva + frentes detenidos). Atacar con todo deja
## la retaguardia expuesta.
## Bonificación EXTRA de defensa (porcentaje que se suma a DEFENSE_BONUS_PERCENT) en las celdas a
## distancia Chebyshev <= CITY_DEFENSE_RADIUS del centro de una ciudad del defensor: 120 + 60 = 180 %.
const CITY_DEFENSE_BONUS_PERCENT := 60
const CITY_DEFENSE_RADIUS := 3
