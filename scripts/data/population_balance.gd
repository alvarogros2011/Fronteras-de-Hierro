## Valores de equilibrio de población, movilización y mantenimiento (hito 7). TODOS son
## PROVISIONALES: sirven para que el prototipo sea jugable y se ajustarán al equilibrar.
## Es el único sitio donde cambiarlos (los de ciudades y economía siguen en economy_balance.gd).
##
## Unidades: las personas son enteros. Lo que es fraccionario por tick (crecimiento y coste de
## mantenimiento) se expresa en MILÉSIMAS (1000 = 1 persona o 1 recurso) y el resto se acumula
## entre ticks, así que nunca se pierde ni se inventa población por redondeo. Un tick dura
## EconomyBalance.TICK_SECONDS segundos de juego. Las tablas se indexan por nivel de ciudad
## (el índice 0 no se usa).
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")

# --- Población inicial de cada nación (configurable por nación) ---
## Una ciudad de nivel 1 admite 50 personas: se empieza por debajo para que haya margen de crecer.
const INITIAL_POPULATION: Dictionary = {
	TerritoryGrid.OWNER_PLAYER: {"workers": 30, "soldiers": 6},
	TerritoryGrid.OWNER_AI_1: {"workers": 30, "soldiers": 6},
	TerritoryGrid.OWNER_AI_2: {"workers": 30, "soldiers": 6},
	TerritoryGrid.OWNER_AI_3: {"workers": 30, "soldiers": 6},
}
## Porcentaje inicial de la población NUEVA que pasa a soldados (el resto, a trabajadores).
const INITIAL_NEW_SOLDIER_PERCENT := 20

# --- Crecimiento de población, por ciudad activa según su nivel ---
## Personas nuevas por tick, en milésimas (150 = 0,15 personas por tick).
const GROWTH_MILLI_PER_LEVEL: Array[int] = [0, 150, 200, 250, 300]
## Población máxima que aporta cada ciudad activa. La de la nación es la suma de las suyas.
## Con estos valores el mantenimiento de una población al tope nunca supera lo que producen
## las ciudades salvo que casi todo sean soldados (ver docs/GDD.md, «Población y mantenimiento»).
const CAPACITY_PER_LEVEL: Array[int] = [0, 50, 90, 150, 240]
## Efecto de la prioridad de crecimiento sobre una ciudad: su crecimiento se multiplica por
## este porcentaje (200 = el doble). Cada ciudad prioritaria lo recibe de forma independiente.
const PRIORITY_GROWTH_PERCENT := 200

# --- Movilización progresiva ---
## Máximo porcentaje de los trabajadores que se puede movilizar en una orden (1..100).
const MOBILIZATION_MAX_PERCENT := 50
## Ticks que dura una movilización: la cantidad reservada se convierte repartida en este plazo.
const MOBILIZATION_TICKS := 30

# --- Mantenimiento (recursos por persona y tick, en milésimas) ---
const WORKER_UPKEEP_MILLI := 12
const SOLDIER_UPKEEP_MILLI := 25

# --- Consecuencias del déficit de recursos (por grupo con deuda) ---
## Lo que no se puede pagar queda como deuda del grupo, hasta este número de ticks de su coste.
## Mientras un grupo tiene deuda está en déficit; la deuda se salda antes que el coste nuevo.
const DEFICIT_DEBT_LIMIT_TICKS := 3
## Ticks seguidos con deuda antes de que el grupo empiece a perder gente. Mientras algún
## grupo está en déficit, además, la nación NO genera población nueva.
const DEFICIT_GRACE_TICKS := 5
## Tras el plazo, cada tick el grupo en déficit pierde este porcentaje en milésimas de sus
## miembros (10 = 1 %), siempre al menos 1 persona. Trabajadores: mueren o emigran.
## Soldados: desertan. No son bajas de combate (el combate no existe todavía).
const DEFICIT_LOSS_PERMILLE := 10
