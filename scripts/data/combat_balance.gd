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
## Por debajo de este valor: «defensa superior». Entre ambos: «enfrentamiento equilibrado».
const DEFENSE_RATIO_PERMILLE := 800
