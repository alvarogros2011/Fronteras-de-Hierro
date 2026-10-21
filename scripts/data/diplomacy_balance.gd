## Valores de equilibrio de la diplomacia (hito 10). TODOS son PROVISIONALES: sirven para que el
## prototipo sea jugable y se ajustarán al equilibrar. Es el único sitio donde cambiarlos (el modelo de
## decisión de la IA está explicado en scripts/world/diplomacy.gd y en docs/GDD.md, «Diplomacia»).
##
## Las cifras son enteras y no hay azar. Un tick dura EconomyBalance.TICK_SECONDS segundos de juego
## (1 s), así que «ticks» y «segundos de juego» coinciden mientras no se cambie ese valor.
extends RefCounted

# --- Tregua ---
## Duración de la tregua tras firmar cualquier tratado (60 s de juego). Provisional.
const TRUCE_TICKS := 60

# --- Propuestas ---
## Una propuesta pendiente de respuesta (la IA propone al jugador, o una contraoferta) caduca a los
## ticks indicados.
const PROPOSAL_TIMEOUT_TICKS := 45
## Mínimo de ticks entre dos propuestas de la IA a la misma nación (y tras ser rechazada o caducar),
## para no repetir ofertas en cada actualización.
const AI_OFFER_INTERVAL_TICKS := 30

# --- Decisión de la IA (todo en «puntos de dinero») ---
## Valor de una celda de territorio al comparar un tratado.
const CELL_VALUE := 2
## Esperanza de ganar por cada 100 milésimas de ventaja de soldados sobre el rival (la fuerza propia
## se mide como soldados propios / (propios + rivales), en milésimas, y 500 es el empate).
const STRENGTH_WEIGHT := 20
## Cansancio de la guerra: puntos por cada tick de guerra y por cada baja propia acumulada.
const WEARINESS_PER_TICK := 1
const CASUALTY_WEIGHT := 2
## La IA solo ofrece la paz por iniciativa propia cuando su «reluctancia» (esperanza - cansancio) baja de
## menos este margen.
const PEACE_SEEK_MARGIN := 15
## La IA contraoferta (en vez de rechazar) si le faltan como mucho estos puntos para aceptar.
const COUNTER_MAX_SHORTFALL := 40

# --- Hito 11: la guerra también se mide en economía ---
## Con el frente ancho se ocupan muchas celdas: la parte de la «esperanza» que sale de las celdas
## ocupadas (diferencia * CELL_VALUE) se limita a ± este valor, para que una IA que ocupa mucho siga
## pudiendo cansarse de la guerra.
const HELD_HOPE_CAP := 60
## Cansancio extra mientras la IA está en déficit de recursos (no puede sostener su ejército).
const DEFICIT_WEARINESS := 40
## Cansancio extra por cada ciudad propia cuyo centro ocupa el rival (pierde su producción).
const OCCUPIED_CITY_WEARINESS := 25
