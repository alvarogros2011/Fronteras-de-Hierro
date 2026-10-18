## Valores de equilibrio de ciudades y economía (hito 6). TODOS son PROVISIONALES: sirven para
## que el prototipo sea jugable y se ajustarán al equilibrar. Es el único sitio donde cambiarlos
## (los de población, movilización y mantenimiento del hito 7 están en population_balance.gd).
##
## Todas las cifras son enteras y se aplican por tick (paso fijo de TICK_SECONDS segundos de
## tiempo de juego), de modo que la simulación es determinista y no depende de los fotogramas.
## Las tablas se indexan por nivel de ciudad (el índice 0 no se usa).
extends RefCounted

## Duración de un tick de simulación económica y de crecimiento, en segundos.
const TICK_SECONDS := 1.0

# --- Fundación ---
## Dinero que cuesta fundar una ciudad.
const FOUND_COST := 100
## Distancia mínima entre ciudades (Chebyshev: max(|dx|, |dy|) en celdas), de cualquier nación.
## Debe ser mayor que 2 * radio visual máximo para que dos ciudades no se solapen.
const MIN_CITY_DISTANCE := 9

# --- Crecimiento ---
const MAX_LEVEL := 4
## Puntos de crecimiento que gana cada ciudad por tick.
const GROWTH_PER_TICK := 1
## Puntos necesarios para pasar del nivel indicado al siguiente. Cada umbral es mayor que el anterior.
## El valor del nivel máximo no se usa.
const GROWTH_TO_NEXT: Array[int] = [0, 30, 60, 120, 0]

# --- Producción por tick y ciudad, según su nivel ---
const MONEY_PER_TICK: Array[int] = [0, 2, 3, 5, 8]
const RESOURCES_PER_TICK: Array[int] = [0, 1, 2, 3, 5]

# --- Presentación ---
## Radio (distancia Manhattan, en celdas) de la mancha de píxeles de la ciudad según su nivel:
## nivel 1 = 5 píxeles (cruz), nivel 4 = 41. Límite visual: nunca supera VISUAL_RADIUS[MAX_LEVEL].
const VISUAL_RADIUS: Array[int] = [0, 1, 2, 3, 4]

# --- Saldo inicial de cada nación ---
## Menor que FOUND_COST: hay que ahorrar con la producción de la ciudad inicial para fundar otra.
const INITIAL_MONEY := 50
const INITIAL_RESOURCES := 0
