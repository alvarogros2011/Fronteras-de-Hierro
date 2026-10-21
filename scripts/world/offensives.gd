## Ofensivas militares (hito 9): ataques, combates e invasiones progresivas. Sin nodos ni dibujo.
##
## Una OFENSIVA es el estado de ataque de un SECTOR del hito 8: usa como fuerza los soldados que el
## sector tiene asignados en cada momento (no crea ningún ejército) y avanza en la dirección del sector,
## de una celda en una celda, cada ADVANCE_INTERVAL_TICKS ticks de CityManager (el mismo reloj fijo que
## la población, así que el resultado depende del tiempo de juego y no de los fotogramas). Como mucho hay
## una ofensiva por sector. Estados: preparado (sin ofensiva), ATACANDO y DETENIDO (con el motivo).
##
## Frente: celda hasta la que ha llegado la ofensiva (empieza en el origen del sector). Cada intento de
## avance mira la celda siguiente (frente + dirección). Se exige que el frente siga siendo propio u
## ocupado por la nación atacante, así que nunca se avanza por celdas desconectadas del origen. Resultados:
##   - Fuera del mapa, agua o tierra sin reclamar sin contacto con territorio propio: la ofensiva se detiene.
##   - Celda propia o ya ocupada por la nación: el frente avanza sin combate.
##   - Tierra sin reclamar: enfrentamiento contra UNCLAIMED_DEFENSE; si vence, se CONQUISTA con la
##     operación explícita TerritoryGrid.conquer_cells (decisión centralizada aquí, documentada en el
##     GDD: no hay nación rival con quien negociar su cesión). No empieza ninguna guerra.
##   - Tierra de otra nación: empieza (si no existía) el estado de guerra entre ambas y hay un
##     enfrentamiento. Si vence, la celda se OCUPA provisionalmente (Occupation): el propietario oficial
##     NO cambia. Si pierde, la ofensiva se detiene (el frente se queda donde estaba).
## También se detiene al quedarse sin soldados, por orden manual (stop_offensive) o si pierde el frente.
## Una ofensiva detenida conserva el frente, las cifras y las ocupaciones conseguidas; start_offensive la
## reanuda desde el frente (si ya no es suyo, desde el origen). Eliminar el sector borra la ofensiva, pero
## no las ocupaciones.
##
## Combate (ver Combat y combat_balance.gd): determinista y sin azar. La defensa local de la nación
## defensora es su fondo común de soldados repartido a partes iguales entre sus tramos de frontera
## (celdas suyas en contacto con tierra de otra nación, agrupadas de CELLS_PER_FRONT en CELLS_PER_FRONT),
## no la cifra completa en cada punto. forecast() calcula exactamente lo que ocurriría en el siguiente
## avance, sin cambiar nada.
##
## Bajas reales: las del atacante restan del sector y de Population (Military.apply_casualties); las del
## defensor, de Population.remove_soldiers (sus sectores se reajustan solos, del más nuevo al más antiguo,
## solo si el total real queda por debajo de lo asignado). Los trabajadores nunca se tocan.
## Nada aquí cambia fronteras salvo conquer_cells sobre tierra sin reclamar; el tiempo, la economía y las
## ciudades no avanzan fronteras.
##
## Hito 10:
##   - ORDEN DE ATAQUE EN UN SOLO PASO: plan_attack() valida y prevé un ataque «desde esta celda, en esta
##     dirección, con N soldados» sin cambiar nada, y launch_attack() lo ejecuta de forma atómica: crea o
##     reutiliza el sector (el «frente»), le asigna los soldados y lanza la ofensiva; si algo falla, no queda
##     ningún sector a medias ni soldados comprometidos. El «sector» pasa a ser un detalle interno: para el
##     jugador es un frente que se refuerza, se detiene o se retira. Con una ofensiva ya activa, launch_attack
##     solo ajusta sus soldados (refuerzo o reducción).
##   - TREGUA: evaluate() trata la tregua vigente con el defensor como un avance bloqueado (STOP_TRUCE), así
##     que ni start_offensive, ni launch_attack ni el avance de una ofensiva en marcha pueden atacar a una
##     nación con la que hay tregua. La regla vive aquí, no en la interfaz.
##   - stop_between(a, b) detiene las ofensivas entre dos naciones (lo usa Diplomacy antes de aplicar un tratado).
##   - Cada enfrentamiento y cada ocupación se anotan en el registro de su guerra (WarState).
##
## Hito 11 (reforma de la guerra):
##   - FRENTE ANCHO: cada intento de avance toma, tras UN enfrentamiento, varias celdas del objetivo
##     alrededor de la punta (la celda siguiente al frente): las de la ventana Chebyshev de semiancho
##     front_half_width que estén pegadas a lo que ya controla el atacante, ordenadas por distancia a la
##     punta (y luego por fila y columna). Como mucho cells_for(soldados) = soldados / SOLDIERS_PER_CELL
##     (entre 1 y MAX_CELLS_PER_STEP): más tropas, avance más rápido. Nunca salta agua ni celdas sueltas
##     (cada celda toca lo ya controlado) y la tierra sin reclamar se conquista celda a celda con
##     conquer_cells. Si la punta da al agua, la franja sigue llenando la ventana y la ofensiva se detiene
##     cuando no queda nada que tomar. front_half_width = 0 reproduce el avance de una celda del hito 9.
##   - OBJETIVO (goal): cada ofensiva tiene un objetivo fijo desde que empieza: tierra sin reclamar
##     (OWNER_NONE: una EXPANSIÓN) o una nación. Una expansión NUNCA ataca: al tocar otra nación se detiene
##     (STOP_CONTACT) sin declarar la guerra; atacar es siempre una orden explícita. Una ofensiva contra una
##     nación solo toma celdas de esa nación y se detiene al acabarse (STOP_GOAL_END).
##   - LIBERACIÓN: una celda propia ocupada por el enemigo es un objetivo (KIND_LIBERATE): se combate
##     contra el ocupante y, si se vence, la ocupación se libera (la propiedad no cambia: ya era propia).
##   - DEFENSA: los soldados de las ofensivas ACTIVAS de una nación no defienden (defending_soldiers): el
##     fondo de defensa es su reserva más sus frentes detenidos. Cerca de una ciudad del defensor
##     (CITY_DEFENSE_RADIUS) la bonificación de defensa sube CITY_DEFENSE_BONUS_PERCENT puntos.
##   - suggest_front() elige el origen y la dirección para atacar cualquier celda pulsada en el mapa, y
##     attacks_against() lista las ofensivas que amenazan a una nación (interfaz e IA).
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Population := preload("res://scripts/world/population.gd")
const Military := preload("res://scripts/world/military.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Occupation := preload("res://scripts/world/occupation.gd")
const WarState := preload("res://scripts/world/war_state.gd")
const Combat := preload("res://scripts/world/combat.gd")
const Balance := preload("res://scripts/data/combat_balance.gd")

## Se emite tras cualquier cambio en las ofensivas (inicio, parada, avance, bajas). No lleva datos.
signal changed
## Se emite con las celdas (Vector2i) cuyo PROPIETARIO cambió por una conquista de tierra sin
## reclamar. La vista debe repintarlas con refresh_cell. (Los cambios de ocupación los anuncia
## Occupation.cells_changed.)
signal territory_changed(cells: Array)

const NO_CELL := Vector2i(-1, -1)

const STATE_READY := 0  # sector sin ofensiva
const STATE_ACTIVE := 1
const STATE_STOPPED := 2

const STOP_NONE := 0
const STOP_MANUAL := 1
const STOP_NO_SOLDIERS := 2
const STOP_WATER := 3
const STOP_MAP_EDGE := 4
const STOP_DEFEAT := 5
const STOP_FRONT_LOST := 6
const STOP_CANNOT_CLAIM := 7  # tierra sin reclamar sin contacto con territorio propio
const STOP_TRUCE := 8  # tregua vigente con la nación defensora
const STOP_CONTACT := 9  # una expansión llega a otra nación: atacar exige una orden explícita
const STOP_GOAL_END := 10  # ya no queda territorio del objetivo delante

const START_OK := 0
const START_ERR_UNKNOWN_SECTOR := 1
const START_ERR_ALREADY_ACTIVE := 2
const START_ERR_NO_SOLDIERS := 3
const START_ERR_BLOCKED := 4  # el siguiente avance es imposible; el motivo (STOP_*) va en "reason"

## Resultado de plan_attack / launch_attack.
const LAUNCH_OK := 0
const LAUNCH_ERR_UNKNOWN_NATION := 1
const LAUNCH_ERR_SECTOR := 2  # origen, dirección u objetivo no válidos; el motivo (Military.SECTOR_ERR_*) va en "sector_error"
const LAUNCH_ERR_NO_SOLDIERS := 3  # hay que enviar al menos 1 soldado
const LAUNCH_ERR_NOT_ENOUGH := 4  # más soldados de los disponibles
const LAUNCH_ERR_BLOCKED := 5  # el siguiente avance es imposible (agua, borde, tregua…); el motivo (STOP_*) va en "reason"

## Tipo de la celda a la que se intenta avanzar.
const KIND_BLOCKED := 0
const KIND_OWN := 1  # propia: se avanza sin combate
const KIND_OCCUPIED := 2  # ya ocupada por la nación: se avanza sin combate
const KIND_UNCLAIMED := 3  # sin reclamar: se conquista
const KIND_ENEMY := 4  # de otra nación: se ocupa
const KIND_LIBERATE := 5  # propia pero ocupada por otra nación: se combate y se libera

## Objetivo aún sin decidir (la ofensiva todavía marcha por su propio territorio).
const GOAL_UNSET := -1

var _grid: TerritoryGrid
var _population: Population
var _military: Military
var _cities: CityManager
var _occupation: Occupation
var _wars: WarState
var _offensives: Dictionary = {}  # id de sector -> datos (ver _new_offensive)
var _exposed_cache: Dictionary = {}  # id de nación -> celdas expuestas
var _stepping: bool = false

## Semiancho del frente (hito 11). 0 = avance de una sola celda, como en el hito 9 (lo usan las pruebas
## de los hitos 9 y 10 para conservar sus escenarios celda a celda).
var front_half_width: int = Balance.FRONT_HALF_WIDTH


func _init(grid: TerritoryGrid, population: Population, military: Military, cities: CityManager, occupation: Occupation, wars: WarState) -> void:
	_grid = grid
	_population = population
	_military = military
	_cities = cities
	_occupation = occupation
	_wars = wars
	_cities.ticked.connect(_on_tick)
	_military.changed.connect(_on_military_changed)
	_grid.ownership_changed.connect(_on_ownership_changed)


func _new_offensive(sector_id: int, front: Vector2i, goal: int) -> Dictionary:
	return {
		"sector_id": sector_id,
		"state": STATE_ACTIVE,
		"reason": STOP_NONE,
		"front": front,
		"goal": goal,  # OWNER_NONE (expansión), una nación o GOAL_UNSET
		"countdown": Balance.ADVANCE_INTERVAL_TICKS,
		"occupied": 0,  # celdas enemigas ocupadas
		"claimed": 0,  # celdas sin reclamar conquistadas
		"liberated": 0,  # celdas propias liberadas
		"attacker_losses": 0,
		"defender_losses": 0,
		"last_clash": {},
	}


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

## STATE_READY si el sector no tiene ofensiva (o no existe), STATE_ACTIVE o STATE_STOPPED.
func sector_state(sector_id: int) -> int:
	return _offensives[sector_id]["state"] if _offensives.has(sector_id) else STATE_READY


func is_active(sector_id: int) -> bool:
	return sector_state(sector_id) == STATE_ACTIVE


## Ofensivas activas (de la nación indicada, o de todas).
func active_count(nation_id: int = TerritoryGrid.INVALID) -> int:
	var total := 0
	for sector_id: int in _offensives:
		if _offensives[sector_id]["state"] != STATE_ACTIVE:
			continue
		if nation_id == TerritoryGrid.INVALID or (_military.has_sector(sector_id) and _military.get_sector(sector_id)["owner"] == nation_id):
			total += 1
	return total


## Soldados de la nación comprometidos en ofensivas ACTIVAS (no defienden).
func attacking_soldiers(nation_id: int) -> int:
	var total := 0
	for sector_id: int in _offensives:
		if _offensives[sector_id]["state"] != STATE_ACTIVE or not _military.has_sector(sector_id):
			continue
		var sector := _military.get_sector(sector_id)
		if sector["owner"] == nation_id:
			total += sector["soldiers"]
	return total


## Fondo de defensa de la nación (hito 11): sus soldados menos los que están atacando (nunca negativo).
func defending_soldiers(nation_id: int) -> int:
	return maxi(0, _population.soldiers(nation_id) - attacking_soldiers(nation_id))


## Objetivo de la ofensiva del sector (OWNER_NONE, una nación o GOAL_UNSET; GOAL_UNSET sin ofensiva).
func goal_of(sector_id: int) -> int:
	return _offensives[sector_id]["goal"] if _offensives.has(sector_id) else GOAL_UNSET


## Ofensivas ACTIVAS de otras naciones cuyo objetivo es `nation_id`, por id de sector:
## [{"sector_id", "attacker", "soldiers", "front"}]. Es la lista de amenazas de la interfaz y de la IA.
func attacks_against(nation_id: int) -> Array:
	var result: Array = []
	var ids: Array = _offensives.keys()
	ids.sort()
	for sector_id: int in ids:
		var offensive: Dictionary = _offensives[sector_id]
		if offensive["state"] != STATE_ACTIVE or offensive["goal"] != nation_id or not _military.has_sector(sector_id):
			continue
		var sector := _military.get_sector(sector_id)
		result.append({"sector_id": sector_id, "attacker": sector["owner"], "soldiers": sector["soldiers"], "front": offensive["front"]})
	return result


## Celdas que puede tomar como mucho un frente con `soldiers` soldados en un avance (contra una nación, o
## en una expansión sobre tierra sin reclamar si `expansion`).
@warning_ignore("integer_division")
static func cells_for(soldiers: int, expansion: bool = false) -> int:
	var per_cell := Balance.EXPANSION_SOLDIERS_PER_CELL if expansion else Balance.SOLDIERS_PER_CELL
	return clampi(soldiers / per_cell, 1, Balance.MAX_CELLS_PER_STEP)


## Copia de los datos de la ofensiva del sector (vacío si no tiene): sector_id, state, reason, front,
## next_cell (la celda a la que apunta ahora), soldiers (los que tiene el frente ahora), countdown
## (ticks hasta el próximo avance), occupied,
## claimed, attacker_losses, defender_losses y last_clash ({} o cell, won, attackers, defense,
## attacker_losses, defender_losses). Modificarla no afecta a la ofensiva.
func get_offensive(sector_id: int) -> Dictionary:
	if not _offensives.has(sector_id):
		return {}
	var data: Dictionary = _offensives[sector_id].duplicate(true)
	data["next_cell"] = current_target(sector_id)
	data["soldiers"] = _military.get_sector(sector_id)["soldiers"] if _military.has_sector(sector_id) else 0
	return data


## Celda a la que apunta el sector ahora: la siguiente al frente (o al origen si no ha avanzado).
## NO_CELL si el sector no existe.
func current_target(sector_id: int) -> Vector2i:
	if not _military.has_sector(sector_id):
		return NO_CELL
	var sector := _military.get_sector(sector_id)
	return _front_for(sector_id, sector) + Military.DIRECTION_STEPS[sector["direction"]]


## Celdas de la nación en contacto ortogonal con tierra de OTRA nación (la tierra sin reclamar y el
## agua no cuentan). Se calcula recorriendo el mapa y se guarda hasta el próximo cambio de propietarios.
@warning_ignore("integer_division")
func exposed_cells(nation_id: int) -> int:
	if _exposed_cache.has(nation_id):
		return _exposed_cache[nation_id]
	var owners := _grid.copy_owner_data()
	var width := TerritoryGrid.WIDTH
	var height := TerritoryGrid.HEIGHT
	var total := 0
	for index in TerritoryGrid.CELL_COUNT:
		if owners[index] != nation_id:
			continue
		var x := index % width
		var y := index / width
		if (x > 0 and _is_other_nation(owners[index - 1], nation_id)) \
				or (x < width - 1 and _is_other_nation(owners[index + 1], nation_id)) \
				or (y > 0 and _is_other_nation(owners[index - width], nation_id)) \
				or (y < height - 1 and _is_other_nation(owners[index + width], nation_id)):
			total += 1
	_exposed_cache[nation_id] = total
	return total


func _is_other_nation(owner_id: int, nation_id: int) -> bool:
	return owner_id != TerritoryGrid.OWNER_NONE and owner_id != nation_id


## Qué pasaría si `attackers` soldados de `attacker_id` intentaran avanzar a `target` AHORA. No cambia
## nada. Devuelve: target, attackers, kind (KIND_*), blocked + reason (STOP_*), defender (nación o
## OWNER_NONE), defender_soldiers (los que defienden: sin los que están atacando), exposed, fronts, defense
## (defensa local estimada), bonus_percent y city_bonus (bonificación de defensa, mayor junto a una ciudad
## del defensor), combat (hay enfrentamiento) y el resultado de Combat.resolve (attacker_wins,
## attacker_losses, defender_losses, attackers_after, ratio_permille, category; sin enfrentamiento: sin
## bajas). Es la evaluación de UNA celda; un avance real usa _plan_step (la franja completa).
func evaluate(attacker_id: int, attackers: int, target: Vector2i) -> Dictionary:
	var info := {
		"target": target, "attackers": attackers, "kind": KIND_BLOCKED, "blocked": false, "reason": STOP_NONE,
		"defender": TerritoryGrid.OWNER_NONE, "defender_soldiers": 0, "exposed": 0, "fronts": 0, "defense": 0,
		"bonus_percent": Balance.DEFENSE_BONUS_PERCENT, "city_bonus": false,
		"combat": false, "attacker_wins": false, "attacker_losses": 0, "defender_losses": 0,
		"attackers_after": attackers, "ratio_permille": 0, "category": Combat.CATEGORY_ADVANTAGE,
	}
	if not _grid.is_valid_coord(target.x, target.y):
		return _blocked(info, STOP_MAP_EDGE)
	if not _grid.is_land(target.x, target.y):
		return _blocked(info, STOP_WATER)
	var owner_id := _grid.get_cell_owner(target.x, target.y)
	var occupier := _occupation.occupier_at(target)
	if owner_id == attacker_id and (occupier == TerritoryGrid.OWNER_NONE or occupier == attacker_id):
		info["kind"] = KIND_OWN
		info["attacker_wins"] = true
		return info
	if occupier == attacker_id:
		info["kind"] = KIND_OCCUPIED
		info["attacker_wins"] = true
		return info
	var defense := 0
	if owner_id == TerritoryGrid.OWNER_NONE:
		if not _touches_owner(target, attacker_id):
			return _blocked(info, STOP_CANNOT_CLAIM)
		info["kind"] = KIND_UNCLAIMED
		defense = Balance.UNCLAIMED_DEFENSE
	else:
		var defender := occupier if owner_id == attacker_id else owner_id
		info["kind"] = KIND_LIBERATE if owner_id == attacker_id else KIND_ENEMY
		info["defender"] = defender
		if _wars.has_truce(attacker_id, defender):
			return _blocked(info, STOP_TRUCE)
		info["defender_soldiers"] = defending_soldiers(defender)
		info["exposed"] = exposed_cells(defender)
		info["fronts"] = Combat.front_count(info["exposed"])
		defense = Combat.defense_per_front(info["defender_soldiers"], info["exposed"])
		if owner_id == defender and _near_city_of(defender, target):
			info["city_bonus"] = true
			info["bonus_percent"] = Balance.DEFENSE_BONUS_PERCENT + Balance.CITY_DEFENSE_BONUS_PERCENT
	info["defense"] = defense
	info["combat"] = true
	info.merge(Combat.resolve(attackers, defense, info["bonus_percent"]), true)
	return info


func _blocked(info: Dictionary, reason: int) -> Dictionary:
	info["kind"] = KIND_BLOCKED
	info["blocked"] = true
	info["reason"] = reason
	return info


## Previsión del siguiente avance del sector (ver _plan_step: exactamente lo que hará el próximo avance);
## vacía si el sector no existe. Añade sector_id y state. Lo que se muestra antes de confirmar el ataque.
func forecast(sector_id: int) -> Dictionary:
	if not _military.has_sector(sector_id):
		return {}
	var sector := _military.get_sector(sector_id)
	var goal := goal_of(sector_id) if is_active(sector_id) else GOAL_UNSET
	var info := _plan_step(sector["owner"], sector["soldiers"], _front_for(sector_id, sector), sector["direction"], goal)
	info["sector_id"] = sector_id
	info["state"] = sector_state(sector_id)
	return info


# ---------------------------------------------------------------------------
# Plan de un avance (hito 11): la franja que se tomaría y su enfrentamiento
# ---------------------------------------------------------------------------

## Objetivo que implica la evaluación de una celda: OWNER_NONE (tierra sin reclamar), la nación defensora
## (enemiga, ocupante o con tregua) o GOAL_UNSET (agua, borde del mapa, propia).
static func _goal_from(info: Dictionary) -> int:
	match info["kind"]:
		KIND_UNCLAIMED:
			return TerritoryGrid.OWNER_NONE
		KIND_ENEMY, KIND_LIBERATE:
			return info["defender"]
	if info["blocked"]:
		if info["reason"] == STOP_TRUCE:
			return info["defender"]
		if info["reason"] == STOP_CANNOT_CLAIM:
			return TerritoryGrid.OWNER_NONE
	return GOAL_UNSET


## Lo que haría AHORA un avance de `attackers` soldados de `attacker_id` desde `front` en `direction` con
## el objetivo `goal` (GOAL_UNSET: se deduce de la celda siguiente). No cambia nada. Devuelve el formato de
## evaluate (con target = la punta, front + dirección) más: goal (objetivo resuelto), move (la punta es
## propia u ocupada: se avanza sin combate), cells (celdas que se tomarían si se vence, en orden),
## max_cells, first_cell y spear_reason (por qué la punta no avanza, aunque la franja sí). El enfrentamiento
## se evalúa sobre la primera celda de la franja, con la bonificación de ciudad si ALGUNA celda de la franja
## está junto a una ciudad del defensor. forecast, plan_attack, start_offensive y el avance real usan esta
## misma función: la previsión coincide con el resultado.
func _plan_step(attacker_id: int, attackers: int, front: Vector2i, direction: int, goal: int) -> Dictionary:
	var target: Vector2i = front + Military.DIRECTION_STEPS[direction]
	var info := evaluate(attacker_id, attackers, target)
	info["goal"] = goal
	info["move"] = false
	info["cells"] = []
	info["max_cells"] = cells_for(attackers)
	if info["kind"] == KIND_OWN or info["kind"] == KIND_OCCUPIED:
		info["move"] = true
		return info
	var spear_goal := _goal_from(info)
	if goal == GOAL_UNSET:
		goal = spear_goal
		info["goal"] = goal
	if goal == GOAL_UNSET:
		return info
	if goal != TerritoryGrid.OWNER_NONE and _wars.has_truce(attacker_id, goal):
		return _blocked(info, STOP_TRUCE)
	# Por qué no avanza la punta (la franja puede seguir tomando celdas del objetivo a su alrededor).
	var spear_reason := STOP_NONE
	if info["blocked"] and not (info["reason"] == STOP_TRUCE and spear_goal != goal):
		spear_reason = info["reason"]
	elif spear_goal != goal:
		spear_reason = STOP_CONTACT if goal == TerritoryGrid.OWNER_NONE else STOP_GOAL_END
	var limit := cells_for(attackers, goal == TerritoryGrid.OWNER_NONE)
	var cells := _wave_cells(attacker_id, target, goal, limit)
	if cells.is_empty():
		return _blocked(info, spear_reason if spear_reason != STOP_NONE else STOP_CANNOT_CLAIM)
	var clash := evaluate(attacker_id, attackers, cells[0])
	var bonus: int = clash["bonus_percent"]
	if goal != TerritoryGrid.OWNER_NONE and not clash["city_bonus"]:
		for cell: Vector2i in cells:
			if _grid.get_cell_owner(cell.x, cell.y) == goal and _near_city_of(goal, cell):
				clash["city_bonus"] = true
				bonus = Balance.DEFENSE_BONUS_PERCENT + Balance.CITY_DEFENSE_BONUS_PERCENT
				break
	clash["bonus_percent"] = bonus
	clash.merge(Combat.resolve(attackers, clash["defense"], bonus), true)
	clash["target"] = target
	clash["first_cell"] = cells[0]
	clash["goal"] = goal
	clash["move"] = false
	clash["cells"] = cells
	clash["max_cells"] = limit
	clash["spear_reason"] = spear_reason
	return clash


## Celdas de la franja: dentro de la ventana Chebyshev de semiancho front_half_width alrededor de `spear`,
## tierra del objetivo (sin reclamar con contacto oficial, o de la nación `goal`: suya sin ocupar por el
## atacante, o del atacante ocupada por `goal`) y pegadas ortogonalmente a algo que el atacante ya controla.
## Ordenadas por distancia Manhattan a la punta, luego por fila y columna; como mucho `limit`.
@warning_ignore("integer_division")
func _wave_cells(attacker_id: int, spear: Vector2i, goal: int, limit: int) -> Array:
	var width := maxi(0, front_half_width)
	# Clave entera única por celda: distancia * 1 000 000 + fila * 1000 + columna (fila < 1000, columna < 1000).
	var keys: Array[int] = []
	for dy in range(-width, width + 1):
		for dx in range(-width, width + 1):
			var cell := spear + Vector2i(dx, dy)
			if _is_wave_cell(attacker_id, cell, goal):
				keys.append((absi(dx) + absi(dy)) * 1000000 + cell.y * 1000 + cell.x)
	keys.sort()
	var cells: Array = []
	for key in keys:
		if cells.size() >= limit:
			break
		cells.append(Vector2i(key % 1000, (key / 1000) % 1000))
	return cells


func _is_wave_cell(attacker_id: int, cell: Vector2i, goal: int) -> bool:
	if not _grid.is_land(cell.x, cell.y):
		return false
	var owner_id := _grid.get_cell_owner(cell.x, cell.y)
	var occupier := _occupation.occupier_at(cell)
	if goal == TerritoryGrid.OWNER_NONE:
		return owner_id == TerritoryGrid.OWNER_NONE and _touches_owner(cell, attacker_id)
	var valid := (owner_id == goal and occupier != attacker_id) or (owner_id == attacker_id and occupier == goal)
	if not valid:
		return false
	for step: Vector2i in TerritoryGrid.ORTHOGONAL_STEPS:
		var neighbor := cell + step
		if _grid.is_valid_coord(neighbor.x, neighbor.y) and _controls(attacker_id, neighbor):
			return true
	return false


## ¿Controla la nación la celda? (suya y sin ocupar por otra, u ocupada por ella)
func _controls(nation_id: int, cell: Vector2i) -> bool:
	var occupier := _occupation.occupier_at(cell)
	if occupier != TerritoryGrid.OWNER_NONE:
		return occupier == nation_id
	return _grid.get_cell_owner(cell.x, cell.y) == nation_id


## ¿Hay una ciudad de la nación a distancia Chebyshev <= CITY_DEFENSE_RADIUS de la celda?
func _near_city_of(nation_id: int, cell: Vector2i) -> bool:
	for city_id: int in _cities.get_city_ids():
		if _cities.get_owner(city_id) != nation_id:
			continue
		var center: Vector2i = _cities.get_city(city_id)["cell"]
		if maxi(absi(center.x - cell.x), absi(center.y - cell.y)) <= Balance.CITY_DEFENSE_RADIUS:
			return true
	return false


# ---------------------------------------------------------------------------
# Órdenes
# ---------------------------------------------------------------------------

## Inicia (o reanuda desde el frente) la ofensiva del sector. Rechaza, sin cambiar nada: sector
## inexistente, ofensiva ya activa, sector sin soldados o un siguiente avance imposible (agua, borde del
## mapa, tierra sin reclamar sin contacto). Si el objetivo inmediato es tierra de otra nación, empieza
## la guerra entre ambas (provisional). Devuelve {"ok", "error" (START_*), "reason" (STOP_* si
## START_ERR_BLOCKED)}.
func start_offensive(sector_id: int) -> Dictionary:
	if not _military.has_sector(sector_id):
		return _start_result(START_ERR_UNKNOWN_SECTOR)
	if is_active(sector_id):
		return _start_result(START_ERR_ALREADY_ACTIVE)
	var sector := _military.get_sector(sector_id)
	if sector["soldiers"] <= 0:
		return _start_result(START_ERR_NO_SOLDIERS)
	var front := _front_for(sector_id, sector)
	var info := _plan_step(sector["owner"], sector["soldiers"], front, sector["direction"], GOAL_UNSET)
	if info["blocked"]:
		return _start_result(START_ERR_BLOCKED, info["reason"])
	var goal: int = info["goal"]
	if goal > TerritoryGrid.OWNER_NONE:
		_wars.declare_war(sector["owner"], goal)
	if _offensives.has(sector_id):
		var previous: Dictionary = _offensives[sector_id]
		previous["state"] = STATE_ACTIVE
		previous["reason"] = STOP_NONE
		previous["front"] = front
		previous["goal"] = goal
		previous["countdown"] = Balance.ADVANCE_INTERVAL_TICKS
	else:
		_offensives[sector_id] = _new_offensive(sector_id, front, goal)
	changed.emit()
	return _start_result(START_OK)


func _start_result(error: int, reason: int = STOP_NONE) -> Dictionary:
	return {"ok": error == START_OK, "error": error, "reason": reason}


## Detiene a mano la ofensiva activa del sector. Conserva el frente, las cifras y las ocupaciones.
## Devuelve false, sin cambiar nada, si el sector no tiene una ofensiva activa.
func stop_offensive(sector_id: int) -> bool:
	if not is_active(sector_id):
		return false
	_stop(sector_id, STOP_MANUAL)
	return true


## Detiene todas las ofensivas activas de una nación. Devuelve cuántas.
func stop_all(nation_id: int) -> int:
	var stopped := 0
	for sector_id: int in _military.get_sector_ids(nation_id):
		if stop_offensive(sector_id):
			stopped += 1
	return stopped


## Detiene las ofensivas activas entre dos naciones: las de cada una cuyo objetivo es la otra o cuya
## próxima celda es territorio oficial de la otra (también las que avanzan sobre celdas ya ocupadas a esa
## nación). No toca las ofensivas contra tierra sin reclamar ni contra terceras naciones. Devuelve cuántas.
func stop_between(first_id: int, second_id: int) -> int:
	var stopped := 0
	var ids: Array = _offensives.keys()
	ids.sort()
	for sector_id: int in ids:
		if not is_active(sector_id) or not _military.has_sector(sector_id):
			continue
		var attacker: int = _military.get_sector(sector_id)["owner"]
		var target := current_target(sector_id)
		var target_owner := _grid.get_cell_owner(target.x, target.y)
		var goal: int = _offensives[sector_id]["goal"]
		if (attacker == first_id and (target_owner == second_id or goal == second_id)) \
				or (attacker == second_id and (target_owner == first_id or goal == first_id)):
			_stop(sector_id, STOP_MANUAL)
			stopped += 1
	return stopped


# ---------------------------------------------------------------------------
# Orden de ataque en un paso (hito 10)
# ---------------------------------------------------------------------------

## Sector de la nación «cerca» de la celda (o Military.NO_SECTOR): el que parte de ella, apunta a ella o
## tiene en ella su frente. Sirve para elegir un frente existente pulsando el mapa.
func sector_near(nation_id: int, cell: Vector2i) -> int:
	for sector_id: int in _military.get_sector_ids(nation_id):
		var sector := _military.get_sector(sector_id)
		if sector["origin"] == cell or sector["target"] == cell:
			return sector_id
		if _offensives.has(sector_id) and (_offensives[sector_id]["front"] == cell or current_target(sector_id) == cell):
			return sector_id
	return Military.NO_SECTOR


## Valida y prevé un ataque de `soldiers` soldados de la nación desde `origin` hacia `direction`
## (Military.DIR_*) SIN cambiar nada. Si ya hay un frente en ese origen y dirección se reutiliza y
## su próximo avance parte de donde está. Devuelve: ok, error (LAUNCH_*), sector_error
## (Military.SECTOR_ERR_*, si error es LAUNCH_ERR_SECTOR), reason (STOP_*, si LAUNCH_ERR_BLOCKED),
## sector_id (o NO_SECTOR si habría que crearlo), state (STATE_*), origin, direction, target (celda a la
## que se avanzaría), assigned (soldados que ya tiene el frente), max_soldiers (lo máximo que se puede
## comprometer: lo que ya tiene más la reserva) y info (evaluate de ese avance; {} si el sector no es
## válido). Orden de los errores: nación, sector, soldados (<1), reserva, avance bloqueado.
func plan_attack(nation_id: int, origin: Vector2i, direction: int, soldiers: int) -> Dictionary:
	var plan := {
		"ok": false, "error": LAUNCH_OK, "sector_error": Military.SECTOR_OK, "reason": STOP_NONE,
		"sector_id": Military.NO_SECTOR, "state": STATE_READY, "origin": origin, "direction": direction,
		"target": NO_CELL, "assigned": 0, "max_soldiers": 0, "soldiers": soldiers, "info": {},
	}
	if not _population.has_nation(nation_id):
		plan["error"] = LAUNCH_ERR_UNKNOWN_NATION
		return plan
	if direction < Military.DIR_NORTH or direction > Military.DIR_WEST:
		plan["error"] = LAUNCH_ERR_SECTOR
		plan["sector_error"] = Military.SECTOR_ERR_BAD_DIRECTION
		return plan
	var sector_id := _military.sector_at(origin, direction)
	var front := origin
	var goal := GOAL_UNSET
	if sector_id != Military.NO_SECTOR:
		var sector := _military.get_sector(sector_id)
		if sector["owner"] != nation_id:
			plan["error"] = LAUNCH_ERR_SECTOR
			plan["sector_error"] = Military.SECTOR_ERR_ORIGIN_NOT_OWNED
			return plan
		plan["sector_id"] = sector_id
		plan["state"] = sector_state(sector_id)
		plan["assigned"] = sector["soldiers"]
		front = _front_for(sector_id, sector)
		if is_active(sector_id):
			goal = goal_of(sector_id)
	else:
		var sector_error := _military.validate_sector(nation_id, origin, direction, 0, _is_liberation_target(nation_id, origin + Military.DIRECTION_STEPS[direction]))
		if sector_error != Military.SECTOR_OK:
			plan["error"] = LAUNCH_ERR_SECTOR
			plan["sector_error"] = sector_error
			return plan
	var target: Vector2i = front + Military.DIRECTION_STEPS[direction]
	plan["target"] = target
	plan["max_soldiers"] = plan["assigned"] + maxi(0, _military.available_soldiers(nation_id))
	var info := _plan_step(nation_id, soldiers, front, direction, goal)
	plan["info"] = info
	if soldiers < 1:
		plan["error"] = LAUNCH_ERR_NO_SOLDIERS
	elif soldiers > plan["max_soldiers"]:
		plan["error"] = LAUNCH_ERR_NOT_ENOUGH
	elif info["blocked"]:
		plan["error"] = LAUNCH_ERR_BLOCKED
		plan["reason"] = info["reason"]
	else:
		plan["ok"] = true
	return plan


## Ejecuta el ataque de forma atómica: crea o reutiliza el frente, le deja exactamente `soldiers`
## soldados y lanza (o reanuda) la ofensiva. Con la ofensiva ya activa solo ajusta los soldados. Si
## plan_attack lo rechaza, o algo falla después, no cambia nada (no queda un frente a medias ni
## soldados comprometidos). Devuelve {ok, error, sector_error, reason, sector_id, created, max_soldiers} con
## los mismos códigos que plan_attack; created indica que el frente se creó en esta orden.
func launch_attack(nation_id: int, origin: Vector2i, direction: int, soldiers: int) -> Dictionary:
	var plan := plan_attack(nation_id, origin, direction, soldiers)
	var result := {"ok": false, "error": plan["error"], "sector_error": plan["sector_error"], "reason": plan["reason"],
			"sector_id": plan["sector_id"], "created": false, "max_soldiers": plan["max_soldiers"]}
	if not plan["ok"]:
		return result
	var sector_id: int = plan["sector_id"]
	var previous: int = plan["assigned"]
	var created := false
	if sector_id == Military.NO_SECTOR:
		var creation := _military.create_sector(nation_id, origin, direction, soldiers, _is_liberation_target(nation_id, origin + Military.DIRECTION_STEPS[direction]))
		if not creation["ok"]:
			result["error"] = LAUNCH_ERR_SECTOR
			result["sector_error"] = creation["error"]
			return result
		sector_id = creation["id"]
		created = true
	elif soldiers != previous:
		if _military.set_sector_soldiers(sector_id, soldiers) != Military.ASSIGN_OK:
			result["error"] = LAUNCH_ERR_NOT_ENOUGH
			return result
	result["sector_id"] = sector_id
	result["created"] = created
	if not is_active(sector_id):
		var started := start_offensive(sector_id)
		if not started["ok"]:
			if created:
				_military.remove_sector(sector_id)
				result["sector_id"] = Military.NO_SECTOR
				result["created"] = false
			else:
				_military.set_sector_soldiers(sector_id, previous)
			result["error"] = LAUNCH_ERR_BLOCKED
			result["reason"] = started["reason"]
			return result
	result["ok"] = true
	result["error"] = LAUNCH_OK
	return result


## ¿La celda es propia y está ocupada por otra nación? (un frente de liberación puede apuntar a ella)
func _is_liberation_target(nation_id: int, cell: Vector2i) -> bool:
	if not _grid.is_valid_coord(cell.x, cell.y) or _grid.get_cell_owner(cell.x, cell.y) != nation_id:
		return false
	var occupier := _occupation.occupier_at(cell)
	return occupier != TerritoryGrid.OWNER_NONE and occupier != nation_id


## ¿Se puede abrir un frente nuevo desde `origin` hacia `direction`? (origen propio, objetivo de tierra no
## controlada por la nación: sin reclamar, enemiga o propia ocupada por otra)
func can_attack_from(nation_id: int, origin: Vector2i, direction: int) -> bool:
	var target: Vector2i = origin + Military.DIRECTION_STEPS[direction]
	return _military.validate_sector(nation_id, origin, direction, 0, _is_liberation_target(nation_id, target)) == Military.SECTOR_OK


## ¿Es la celda un objetivo atacable para la nación? (tierra que no controla)
func is_attackable(nation_id: int, cell: Vector2i) -> bool:
	return _grid.is_land(cell.x, cell.y) and not _controls(nation_id, cell)


## Frente sugerido para atacar `cell` (hito 11: el jugador pulsa lo que quiere atacar, esté donde esté):
## {"origin", "direction"} o {} si no hay forma. Si la celda es atacable y toca territorio propio, el
## origen es esa celda propia vecina (en el orden norte, este, sur, oeste de la dirección); si está lejos,
## la celda propia de frontera más cercana (Manhattan; luego fila y columna) y, desde ella, la dirección
## atacable que más se acerca. Si la celda es propia, ella misma es el origen con su única dirección
## atacable (-1 si hay varias o ninguna).
@warning_ignore("integer_division")
func suggest_front(nation_id: int, cell: Vector2i) -> Dictionary:
	if not _grid.is_valid_coord(cell.x, cell.y) or not _grid.is_land(cell.x, cell.y):
		return {}
	if not is_attackable(nation_id, cell):
		if _grid.get_cell_owner(cell.x, cell.y) != nation_id:
			return {}
		var options: Array = []
		for direction in Military.DIRECTION_STEPS.size():
			if can_attack_from(nation_id, cell, direction):
				options.append(direction)
		return {"origin": cell, "direction": options[0] if options.size() == 1 else -1}
	for direction in Military.DIRECTION_STEPS.size():
		var origin: Vector2i = cell - Military.DIRECTION_STEPS[direction]
		if _grid.is_valid_coord(origin.x, origin.y) and _grid.get_cell_owner(origin.x, origin.y) == nation_id \
				and can_attack_from(nation_id, origin, direction):
			return {"origin": origin, "direction": direction}
	var owners := _grid.copy_owner_data()
	var width := TerritoryGrid.WIDTH
	var best_index := -1
	var best_distance := 0
	for index in TerritoryGrid.CELL_COUNT:
		if owners[index] != nation_id:
			continue
		var x := index % width
		var y := index / width
		var distance := absi(x - cell.x) + absi(y - cell.y)
		if best_index >= 0 and distance >= best_distance:
			continue
		var origin := Vector2i(x, y)
		for direction in Military.DIRECTION_STEPS.size():
			if is_attackable(nation_id, origin + Military.DIRECTION_STEPS[direction]):
				best_index = index
				best_distance = distance
				break
	if best_index < 0:
		return {}
	var start := Vector2i(best_index % width, best_index / width)
	var best_direction := -1
	var best_gain := -1000000
	for direction in Military.DIRECTION_STEPS.size():
		if not can_attack_from(nation_id, start, direction):
			continue
		var step: Vector2i = Military.DIRECTION_STEPS[direction]
		var gain := step.x * (cell.x - start.x) + step.y * (cell.y - start.y)
		if gain > best_gain:
			best_gain = gain
			best_direction = direction
	if best_direction < 0:
		return {}
	return {"origin": start, "direction": best_direction}


func _stop(sector_id: int, reason: int) -> void:
	var offensive: Dictionary = _offensives[sector_id]
	offensive["state"] = STATE_STOPPED
	offensive["reason"] = reason
	offensive["countdown"] = 0
	changed.emit()


# ---------------------------------------------------------------------------
# Textos
# ---------------------------------------------------------------------------

static func stop_reason_message(code: int) -> String:
	match code:
		STOP_NONE:
			return ""
		STOP_MANUAL:
			return "detenida por el jugador"
		STOP_NO_SOLDIERS:
			return "sin soldados"
		STOP_WATER:
			return "el frente llega al agua"
		STOP_MAP_EDGE:
			return "el frente llega al borde del mapa"
		STOP_DEFEAT:
			return "enfrentamiento perdido"
		STOP_FRONT_LOST:
			return "se perdió el frente"
		STOP_CANNOT_CLAIM:
			return "sin contacto con territorio propio para reclamar"
		STOP_TRUCE:
			return "tregua vigente"
		STOP_CONTACT:
			return "contacto con otra nación: una expansión no ataca (ordena un ataque)"
		STOP_GOAL_END:
			return "no queda territorio enemigo delante"
	return "motivo desconocido"


static func launch_error_message(plan: Dictionary) -> String:
	match plan["error"]:
		LAUNCH_OK:
			return "Ataque en marcha."
		LAUNCH_ERR_UNKNOWN_NATION:
			return "Nación desconocida."
		LAUNCH_ERR_SECTOR:
			return Military.attack_target_error_message(plan["sector_error"])
		LAUNCH_ERR_NO_SOLDIERS:
			return "Elige al menos 1 soldado."
		LAUNCH_ERR_NOT_ENOUGH:
			return "No hay tantos soldados disponibles (máximo %d)." % plan["max_soldiers"]
		LAUNCH_ERR_BLOCKED:
			return "No se puede avanzar: %s." % stop_reason_message(plan["reason"])
	return "Error desconocido."


static func start_error_message(code: int, reason: int = STOP_NONE) -> String:
	match code:
		START_OK:
			return "Ataque iniciado."
		START_ERR_UNKNOWN_SECTOR:
			return "El sector no existe."
		START_ERR_ALREADY_ACTIVE:
			return "El sector ya está atacando."
		START_ERR_NO_SOLDIERS:
			return "El sector no tiene soldados."
		START_ERR_BLOCKED:
			return "No se puede avanzar: %s." % stop_reason_message(reason)
	return "Error desconocido."


# ---------------------------------------------------------------------------
# Coherencia con los otros sistemas
# ---------------------------------------------------------------------------

## Frente desde el que debe avanzar el sector: el de su ofensiva si sigue siendo suyo; si no, el origen.
func _front_for(sector_id: int, sector: Dictionary) -> Vector2i:
	if _offensives.has(sector_id):
		var front: Vector2i = _offensives[sector_id]["front"]
		if _is_ours(sector["owner"], front):
			return front
	return sector["origin"]


## ¿La celda es de la nación o está ocupada por ella?
func _is_ours(nation_id: int, cell: Vector2i) -> bool:
	return _grid.get_cell_owner(cell.x, cell.y) == nation_id or _occupation.occupier_at(cell) == nation_id


## ¿Algún vecino ortogonal de la celda es propiedad oficial de la nación? (condición de conquer_cells)
func _touches_owner(cell: Vector2i, nation_id: int) -> bool:
	for step: Vector2i in TerritoryGrid.ORTHOGONAL_STEPS:
		var neighbor := cell + step
		if _grid.get_cell_owner(neighbor.x, neighbor.y) == nation_id:
			return true
	return false


func _on_ownership_changed() -> void:
	_exposed_cache.clear()


func _on_military_changed() -> void:
	if not _stepping:
		_sync()


## Elimina las ofensivas de sectores que ya no existen y detiene las que se quedaron sin soldados.
func _sync() -> void:
	var dirty := false
	for sector_id: int in _offensives.keys():
		if not _military.has_sector(sector_id):
			_offensives.erase(sector_id)
			dirty = true
		elif _offensives[sector_id]["state"] == STATE_ACTIVE and _military.get_sector(sector_id)["soldiers"] <= 0:
			_stop(sector_id, STOP_NO_SOLDIERS)
			dirty = true
	if dirty:
		changed.emit()


# ---------------------------------------------------------------------------
# Tiempo: avance
# ---------------------------------------------------------------------------

func _on_tick() -> void:
	var ids: Array = _offensives.keys()
	ids.sort()
	var any_active := false
	for sector_id: int in ids:
		if not _offensives.has(sector_id) or _offensives[sector_id]["state"] != STATE_ACTIVE:
			continue
		any_active = true
		var offensive: Dictionary = _offensives[sector_id]
		offensive["countdown"] -= 1
		if offensive["countdown"] <= 0:
			offensive["countdown"] = Balance.ADVANCE_INTERVAL_TICKS
			_step(sector_id)
	if any_active:
		changed.emit()


## Un intento de avance de la ofensiva activa: aplica exactamente lo que _plan_step() prevé (un
## enfrentamiento y, si se vence, la franja de celdas en orden).
func _step(sector_id: int) -> void:
	var offensive: Dictionary = _offensives[sector_id]
	var sector := _military.get_sector(sector_id)
	var attacker: int = sector["owner"]
	var attackers: int = sector["soldiers"]
	if attackers <= 0:
		_stop(sector_id, STOP_NO_SOLDIERS)
		return
	var front: Vector2i = offensive["front"]
	if not _is_ours(attacker, front):
		_stop(sector_id, STOP_FRONT_LOST)
		return
	var plan := _plan_step(attacker, attackers, front, sector["direction"], offensive["goal"])
	var target: Vector2i = plan["target"]
	if plan["move"]:
		offensive["front"] = target
		return
	if plan["blocked"]:
		_stop(sector_id, plan["reason"])
		return
	offensive["goal"] = plan["goal"]
	var kind: int = plan["kind"]
	var defender: int = plan["defender"]
	var against_nation := defender != TerritoryGrid.OWNER_NONE
	if against_nation:
		_wars.declare_war(attacker, defender)
	_stepping = true
	var attacker_losses := _military.apply_casualties(sector_id, plan["attacker_losses"])
	var defender_losses := 0
	if against_nation:
		defender_losses = _population.remove_soldiers(defender, plan["defender_losses"])
	offensive["attacker_losses"] += attacker_losses
	offensive["defender_losses"] += defender_losses
	if against_nation:
		_wars.record_clash(attacker, defender, attacker_losses, defender_losses)
	var wins: bool = plan["attacker_wins"]
	var conquered: Array = []
	var taken := 0
	if wins:
		taken = _take_cells(offensive, attacker, defender, plan["cells"], conquered)
		if _is_ours(attacker, target):
			offensive["front"] = target
	offensive["last_clash"] = {
		"cell": plan.get("first_cell", target), "won": wins, "attackers": attackers, "defense": plan["defense"],
		"attacker_losses": attacker_losses, "defender_losses": defender_losses, "cells": taken, "kind": kind,
	}
	_stepping = false
	if not conquered.is_empty():
		territory_changed.emit(conquered)
	if not wins:
		_stop(sector_id, STOP_DEFEAT)
	elif taken == 0:
		_stop(sector_id, STOP_CANNOT_CLAIM)
	elif _military.has_sector(sector_id) and _military.get_sector(sector_id)["soldiers"] <= 0:
		_stop(sector_id, STOP_NO_SOLDIERS)
	_sync()


## Toma la franja tras vencer, con pocas operaciones (para no repetir avisos por cada celda): conquista la
## tierra sin reclamar por zonas contiguas (una conquer_cells por zona, celdas en el orden de la franja),
## libera las celdas propias ocupadas por el defensor y ocupa las del defensor. Devuelve cuántas tomó y
## añade a `conquered` las que cambiaron de propietario.
func _take_cells(offensive: Dictionary, attacker: int, defender: int, cells: Array, conquered: Array) -> int:
	var claim: Array = []
	var liberate: Array = []
	var occupy: Array = []
	for cell: Vector2i in cells:
		var owner_id := _grid.get_cell_owner(cell.x, cell.y)
		if owner_id == TerritoryGrid.OWNER_NONE:
			claim.append(cell)
		elif owner_id == attacker:
			if _occupation.occupier_at(cell) == defender:
				liberate.append(cell)
		else:
			occupy.append(cell)
	var taken := 0
	for zone: Array in _zones(claim):
		var result := _grid.conquer_cells(attacker, zone)
		if result["ok"]:
			offensive["claimed"] += zone.size()
			taken += zone.size()
			conquered.append_array(result["changed_cells"])
	var released := _occupation.release_cells(liberate)
	offensive["liberated"] += released
	taken += released
	var held := _occupation.occupy_cells(attacker, occupy)
	offensive["occupied"] += held.size()
	taken += held.size()
	for _cell: Vector2i in held:
		_wars.record_occupation(attacker, defender)
	return taken


## Agrupa las celdas en zonas contiguas (vecinos ortogonales); cada zona conserva el orden de `cells`.
func _zones(cells: Array) -> Array:
	var order := {}
	for index in cells.size():
		order[cells[index]] = index
	var seen := {}
	var zones: Array = []
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		seen[start] = true
		var members: Array = [start]
		var cursor := 0
		while cursor < members.size():
			var current: Vector2i = members[cursor]
			cursor += 1
			for step: Vector2i in TerritoryGrid.ORTHOGONAL_STEPS:
				var neighbor := current + step
				if order.has(neighbor) and not seen.has(neighbor):
					seen[neighbor] = true
					members.append(neighbor)
		var indexes: Array = []
		for cell: Vector2i in members:
			indexes.append(order[cell])
		indexes.sort()
		var zone: Array = []
		for index: int in indexes:
			zone.append(cells[index])
		zones.append(zone)
	return zones
