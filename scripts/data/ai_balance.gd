## Valores de la IA estratégica (hito 11). TODOS son PROVISIONALES y enteros; es el único sitio donde
## cambiarlos (el modelo de decisión está explicado en scripts/world/ai_controller.gd y en docs/GDD.md,
## «IA estratégica»). Un tick dura EconomyBalance.TICK_SECONDS segundos de juego (1 s).
extends RefCounted

# --- Ritmo ---
## Ticks entre dos decisiones de una misma IA. Las naciones deciden escalonadas (no todas a la vez).
const DECISION_INTERVAL_TICKS := 4
## Ticks de partida antes de que una IA pueda declarar una guerra (expandirse sí puede desde el
## principio): da tiempo al jugador para organizarse.
const WAR_GRACE_TICKS := 150
## Ticks mínimos entre dos declaraciones de guerra de una misma IA.
const WAR_COOLDOWN_TICKS := 120

# --- Economía ---
## Porcentaje de la población nueva que va a soldados en paz y en guerra (o amenazada).
const PEACE_SOLDIER_PERCENT := 25
const WAR_SOLDIER_PERCENT := 45
## Con déficit de recursos, la población nueva va toda a trabajadores y se desmoviliza este porcentaje
## de la reserva en cada decisión (al menos 1 soldado).
const DEFICIT_DEMOBILIZE_PERCENT := 20
## Dinero que la IA guarda siempre (no lo gasta en fundar ni en prioridades).
const MONEY_RESERVE := 40
## Con al menos este dinero libre activa la prioridad de crecimiento en su mejor ciudad (y la quita si
## baja de la mitad).
const PRIORITY_MONEY := 120
## Moviliza este porcentaje de los trabajadores cuando está en guerra y su fondo de defensa es menor
## que el de su enemigo.
const WAR_MOBILIZATION_PERCENT := 20

# --- Expansión sobre tierra sin reclamar ---
## Porcentaje de sus soldados (de la reserva) que compromete en expandirse cuando no hay amenazas.
const EXPANSION_COMMIT_PERCENT := 50
## Frentes de expansión a la vez como mucho.
const MAX_EXPANSION_FRONTS := 2
## Soldados mínimos para abrir un frente de expansión.
const MIN_EXPANSION_SOLDIERS := 3

# --- Guerra ---
## Para declarar una guerra, sus soldados libres deben superar en este porcentaje el fondo de defensa
## total del objetivo (150 = 1,5 veces), y la previsión del primer avance debe ser una victoria.
const ATTACK_SUPERIORITY_PERCENT := 150
## Porcentaje de sus soldados libres que compromete en un ataque contra otra nación.
const ATTACK_COMMIT_PERCENT := 70
## Una ofensiva de la IA con menos de este número de soldados se retira para reorganizarse.
const MIN_FRONT_SOLDIERS := 2
## Reserva mínima (porcentaje de los soldados atacantes del enemigo contra ella) que quiere conservar
## en casa mientras la atacan; si no llega, retira primero sus frentes de expansión y luego los demás.
const DEFENSE_RESERVE_PERCENT := 100
## Un objetivo que ya está en guerra con este número de naciones (o más) no recibe más declaraciones.
const MAX_WARS_ON_TARGET := 1
## En guerra conserva en casa este porcentaje de sus soldados además de lo que exige la amenaza.
const WAR_HOME_GUARD_PERCENT := 30
## Por debajo de estos recursos, con el balance de recursos negativo, deja de reclutar y no moviliza.
const LOW_RESOURCES := 20
## Las ciudades se buscan en una rejilla de este paso (en celdas) y lejos de fronteras con otras naciones
## (a más de FOUND_BORDER_MARGIN celdas).
const FOUND_SAMPLE_STEP := 3
const FOUND_BORDER_MARGIN := 2
