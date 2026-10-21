## IA estratégica de las naciones que no maneja el jugador (hito 11). Sin nodos ni dibujo.
##
## Es sencilla y determinista: prioridades claras, evaluaciones simples y un intervalo de decisión fijo
## (ai_balance.gd). NO hace trampas: solo usa las mismas órdenes públicas que el jugador
## (Population.set_new_soldier_percent / start_mobilization / demobilize / set_city_priority,
## CityManager.found_city, Offensives.plan_attack / launch_attack / stop_offensive, Military.remove_sector y
## Diplomacy.propose / accept / reject), así que nunca crea soldados, dinero, recursos ni ciudades, y respeta
## las guerras, las ocupaciones y las treguas porque esas reglas viven en los sistemas, no aquí.
##
## Reloj: cuelga de CityManager.ticked (el reloj único), así que la pausa la detiene. Cada IA decide cada
## DECISION_INTERVAL_TICKS, escalonadas (la i-ésima cuando (tick + i) % intervalo == 0).
##
## Una decisión, en este orden: economía, frentes, diplomacia (antes de atacar: si firma la paz no lanza
## ataques nuevos) y ofensiva. decide() devuelve la lista de lo que hizo, para las pruebas:
##   1. ECONOMÍA: reparto de la población nueva (más soldados en guerra o amenazada; ninguno con déficit o
##      con recursos bajos y balance negativo); con déficit DESMOVILIZA parte de la reserva; funda una ciudad
##      cuando le sobra el dinero (en un sitio interior, lo más compacto posible); paga la prioridad de
##      crecimiento de su mejor ciudad si le sobra dinero (y la quita si escasea); en guerra y con menos
##      defensa que su enemigo, moviliza si puede mantenerlo.
##   2. FRENTES: retira (los soldados vuelven a la reserva) los frentes detenidos o casi vacíos; si la están
##      atacando y su reserva no cubre a los atacantes, retira primero las expansiones y después los ataques
##      contra terceros (nunca el ataque contra quien la ataca).
##   3. OFENSIVA, con sus soldados libres (reserva menos lo que exige la amenaza y, en guerra, una guardia):
##      a) en cada guerra sin frente propio, ataca (primero libera sus celdas ocupadas) solo si la previsión
##         es una victoria; b) si nadie la ataca, se expande por tierra sin reclamar con hasta
##         MAX_EXPANSION_FRONTS frentes;
##      c) declara una guerra solo tras WAR_GRACE_TICKS, sin otras guerras ni amenazas, con balance de
##         recursos positivo, a un vecino sin tregua que no esté ya en guerra (MAX_WARS_ON_TARGET), cuyo
##         fondo de defensa supere en ATTACK_SUPERIORITY_PERCENT, y con una previsión de victoria. Elige al
##         más débil. Así no se lanzan todas contra el jugador a la vez.
##   4. DIPLOMACIA: responde a las propuestas que le llegan (contraofertas incluidas) con la misma
##      valoración de Diplomacy, y en guerras contra otra IA propone la paz cuando su reluctancia lo indica
##      (las propuestas a naciones humanas ya las genera Diplomacy).
## Emite `event` con un texto cuando algo afecta al jugador o cambia el mapa político (guerras y paces).
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Economy := preload("res://scripts/world/economy.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Population := preload("res://scripts/world/population.gd")
const Military := preload("res://scripts/world/military.gd")
const Occupation := preload("res://scripts/world/occupation.gd")
const WarState := preload("res://scripts/world/war_state.gd")
const Offensives := preload("res://scripts/world/offensives.gd")
const Diplomacy := preload("res://scripts/world/diplomacy.gd")
const Balance := preload("res://scripts/data/ai_balance.gd")
const EconomyBalance := preload("res://scripts/data/economy_balance.gd")
const DiplomacyBalance := preload("res://scripts/data/diplomacy_balance.gd")

## Aviso para el jugador (guerras declaradas, paces firmadas entre IA). Lo muestra la pantalla.
signal event(text: String)

const NO_CELL := Vector2i(-1, -1)

## Con false ninguna IA decide (las pruebas de otros hitos lo usan para escenarios sin IA).
var enabled: bool = true

var _grid: TerritoryGrid
var _economy: Economy
var _cities: CityManager
var _population: Population
var _military: Military
var _occupation: Occupation
var _wars: WarState
var _offensives: Offensives
var _diplomacy: Diplomacy
var _last_war: Dictionary = {}  # nación -> tick de su última declaración de guerra
var _next_peace: Dictionary = {}  # "a:b" -> tick a partir del cual puede volver a proponer la paz
var _decisions: Dictionary = {}  # nación -> decisiones tomadas (rota la dirección de expansión)
var _scan_cache: Dictionary = {}  # nación -> barrido de su frontera (solo durante una decisión)
var _deciding: bool = false


func _init(grid: TerritoryGrid, economy: Economy, cities: CityManager, population: Population, military: Military,
		occupation: Occupation, wars: WarState, offensives: Offensives, diplomacy: Diplomacy) -> void:
	_grid = grid
	_economy = economy
	_cities = cities
	_population = population
	_military = military
	_occupation = occupation
	_wars = wars
	_offensives = offensives
	_diplomacy = diplomacy
	_cities.ticked.connect(_on_tick)


## Naciones que maneja la IA (controller "ai"), por id.
func ai_nations() -> Array:
	var result: Array = []
	for nation_id: int in _grid.get_nation_ids():
		if _is_ai(nation_id):
			result.append(nation_id)
	return result


func _is_ai(nation_id: int) -> bool:
	return _grid.get_nation(nation_id).get("controller", "") == "ai"


func _name(nation_id: int) -> String:
	return _grid.get_nation(nation_id).get("name", "?")


func _on_tick() -> void:
	if not enabled:
		return
	var now := _cities.tick_count()
	var nations := ai_nations()
	for index in nations.size():
		if (now + index) % Balance.DECISION_INTERVAL_TICKS == 0:
			decide(nations[index])


## Una decisión completa de la IA `nation_id` (ver la cabecera). Devuelve las acciones tomadas, como
## textos breves en orden. Una nación sin ciudades ni soldados no hace nada.
func decide(nation_id: int) -> Array:
	var actions: Array = []
	if not _population.has_nation(nation_id):
		return actions
	if _cities.count_owned_by(nation_id) == 0 and _population.soldiers(nation_id) <= 0:
		return actions
	_decisions[nation_id] = _decisions.get(nation_id, 0) + 1
	_scan_cache.clear()
	_deciding = true
	_manage_economy(nation_id, actions)
	_manage_fronts(nation_id, actions)
	_manage_diplomacy(nation_id, actions)
	_manage_offense(nation_id, actions)
	_deciding = false
	_scan_cache.clear()
	return actions


# ---------------------------------------------------------------------------
# Lectura de la situación
# ---------------------------------------------------------------------------

## Soldados enemigos que atacan ahora a la nación (ofensivas activas cuyo objetivo es ella).
func incoming_soldiers(nation_id: int) -> int:
	var total := 0
	for attack: Dictionary in _offensives.attacks_against(nation_id):
		total += attack["soldiers"]
	return total


## ¿Está en guerra o la están atacando?
func is_threatened(nation_id: int) -> bool:
	return not _wars.enemies_of(nation_id).is_empty() or incoming_soldiers(nation_id) > 0


## Soldados libres para atacar: la reserva menos lo que exige la amenaza y, en guerra, una guardia.
@warning_ignore("integer_division")
func free_soldiers(nation_id: int) -> int:
	var free := _military.available_soldiers(nation_id) - incoming_soldiers(nation_id) * Balance.DEFENSE_RESERVE_PERCENT / 100
	if not _wars.enemies_of(nation_id).is_empty():
		free -= _population.soldiers(nation_id) * Balance.WAR_HOME_GUARD_PERCENT / 100
	return maxi(0, free)


## Naciones con frontera terrestre con la nación (alguna celda suya toca una celda de ellas), por id.
func neighbors_of(nation_id: int) -> Array:
	return _border_scan(nation_id)["neighbors"]


## Un único barrido del mapa para la nación (se guarda solo durante la decisión en curso): centro de su
## territorio, naciones vecinas y, por dirección, la celda propia más avanzada que da a tierra sin
## reclamar (a igualdad, la más cercana al centro y después la primera en orden de filas).
@warning_ignore("integer_division")
func _border_scan(nation_id: int) -> Dictionary:
	if _scan_cache.has(nation_id):
		return _scan_cache[nation_id]
	var owners := _grid.copy_owner_data()
	var width := TerritoryGrid.WIDTH
	var sum := Vector2i.ZERO
	var count := 0
	var found := {}
	var frontier: Array = []  # celdas propias con alguna vecina sin reclamar
	for index in TerritoryGrid.CELL_COUNT:
		if owners[index] != nation_id:
			continue
		var x := index % width
		var y := index / width
		sum += Vector2i(x, y)
		count += 1
		var touches_free := false
		for neighbor in [index - 1 if x > 0 else -1, index + 1 if x < width - 1 else -1, index - width, index + width]:
			if neighbor < 0 or neighbor >= TerritoryGrid.CELL_COUNT:
				continue
			var other: int = owners[neighbor]
			if other == TerritoryGrid.OWNER_NONE:
				touches_free = true
			elif other != nation_id:
				found[other] = true
		if touches_free:
			frontier.append(Vector2i(x, y))
	var neighbors: Array = found.keys()
	neighbors.sort()
	var center := Vector2i(sum.x / count, sum.y / count) if count > 0 else NO_CELL
	var expansion: Array = []
	for direction in Military.DIRECTION_STEPS.size():
		var step: Vector2i = Military.DIRECTION_STEPS[direction]
		var best := NO_CELL
		var best_reach := -1000000
		var best_offset := 0
		for cell: Vector2i in frontier:
			var next := cell + step
			if not _grid.is_land(next.x, next.y) or _grid.get_cell_owner(next.x, next.y) != TerritoryGrid.OWNER_NONE:
				continue
			var reach := cell.x * step.x + cell.y * step.y
			var offset := absi((cell.x - center.x) * step.y) + absi((cell.y - center.y) * step.x)
			if reach > best_reach or (reach == best_reach and offset < best_offset):
				best = cell
				best_reach = reach
				best_offset = offset
		expansion.append(best)
	var scan := {"center": center, "neighbors": neighbors, "expansion": expansion}
	if _deciding:
		_scan_cache[nation_id] = scan
	return scan


func _front_count(nation_id: int, expansion: bool) -> int:
	var total := 0
	for sector_id: int in _military.get_sector_ids(nation_id):
		if not _offensives.is_active(sector_id):
			continue
		var is_expansion := _offensives.goal_of(sector_id) == TerritoryGrid.OWNER_NONE
		if is_expansion == expansion:
			total += 1
	return total


func _has_front_against(nation_id: int, enemy_id: int) -> bool:
	for sector_id: int in _military.get_sector_ids(nation_id):
		if _offensives.is_active(sector_id) and _offensives.goal_of(sector_id) == enemy_id:
			return true
	return false


# ---------------------------------------------------------------------------
# 1. Economía
# ---------------------------------------------------------------------------

@warning_ignore("integer_division")
func _manage_economy(nation_id: int, actions: Array) -> void:
	var maintenance := _population.get_maintenance(nation_id)
	var net := _population.net_income_milli(nation_id)
	var threatened := is_threatened(nation_id)
	var low: bool = net["resources"] < 0 and _economy.get_resources(nation_id) < Balance.LOW_RESOURCES
	var percent := Balance.WAR_SOLDIER_PERCENT if threatened else Balance.PEACE_SOLDIER_PERCENT
	if maintenance["in_deficit"] or low:
		percent = 0
	if _population.new_soldier_percent(nation_id) != percent:
		_population.set_new_soldier_percent(nation_id, percent)
		actions.append("reparto %d %% soldados" % percent)
	if maintenance["in_deficit"]:
		var reserve := _military.available_soldiers(nation_id)
		if reserve > 0:
			var amount := mini(reserve, maxi(1, reserve * Balance.DEFICIT_DEMOBILIZE_PERCENT / 100))
			if _population.demobilize(nation_id, amount) == Population.DEMOB_OK:
				actions.append("desmoviliza %d" % amount)
	var free_money := _economy.get_money(nation_id) - Balance.MONEY_RESERVE
	if free_money >= EconomyBalance.FOUND_COST and not maintenance["in_deficit"]:
		var site := city_site(nation_id)
		if site != NO_CELL and _cities.found_city(nation_id, site)["ok"]:
			actions.append("funda ciudad en (%d, %d)" % [site.x, site.y])
			free_money = _economy.get_money(nation_id) - Balance.MONEY_RESERVE
	var priorities := _population.priority_cities(nation_id)
	if priorities.is_empty() and free_money >= Balance.PRIORITY_MONEY and not maintenance["in_deficit"]:
		var best := _best_growth_city(nation_id)
		if best != CityManager.NO_CITY and _population.set_city_priority(nation_id, best, true):
			actions.append("prioridad en la ciudad %d" % best)
	elif not priorities.is_empty() and (free_money < Balance.PRIORITY_MONEY / 2 or maintenance["in_deficit"]):
		for city_id: int in priorities:
			_population.set_city_priority(nation_id, city_id, false)
		actions.append("quita la prioridad")
	if threatened and not maintenance["in_deficit"] and not low and net["resources"] > 0 \
			and not _population.get_mobilization(nation_id)["active"] and _weaker_than_enemies(nation_id):
		if _population.start_mobilization(nation_id, Balance.WAR_MOBILIZATION_PERCENT) == Population.MOB_OK:
			actions.append("moviliza %d %%" % Balance.WAR_MOBILIZATION_PERCENT)


func _weaker_than_enemies(nation_id: int) -> bool:
	var own := _offensives.defending_soldiers(nation_id)
	for enemy_id: int in _wars.enemies_of(nation_id):
		if _population.soldiers(enemy_id) > own:
			return true
	return incoming_soldiers(nation_id) > own


## Ciudad que más gana con la prioridad: la de mayor nivel que aún puede subir (a igualdad, la de id menor).
func _best_growth_city(nation_id: int) -> int:
	var best := CityManager.NO_CITY
	var best_level := 0
	for city_id: int in _cities.get_city_ids():
		if _cities.get_owner(city_id) != nation_id or _cities.is_occupied(city_id):
			continue
		var level: int = _cities.get_city(city_id)["level"]
		if level < EconomyBalance.MAX_LEVEL and level > best_level:
			best = city_id
			best_level = level
	return best


## Sitio para fundar: celda propia de la rejilla FOUND_SAMPLE_STEP donde check_founding lo permite, lejos de
## fronteras con otras naciones, lo más cerca posible de sus ciudades (crecimiento compacto); a igualdad, la
## primera en orden de filas. NO_CELL si no hay ninguno.
@warning_ignore("integer_division")
func city_site(nation_id: int) -> Vector2i:
	var owners := _grid.copy_owner_data()
	var width := TerritoryGrid.WIDTH
	var best := NO_CELL
	var best_score := 1000000
	var centers: Array = []
	for city_id: int in _cities.get_city_ids():
		if _cities.get_owner(city_id) == nation_id:
			centers.append(_cities.get_city(city_id)["cell"])
	for index in TerritoryGrid.CELL_COUNT:
		if owners[index] != nation_id:
			continue
		var x := index % width
		var y := index / width
		if x % Balance.FOUND_SAMPLE_STEP != 0 or y % Balance.FOUND_SAMPLE_STEP != 0:
			continue
		var cell := Vector2i(x, y)
		if _cities.check_founding(nation_id, cell) != CityManager.FOUND_OK or _near_foreign(owners, nation_id, cell):
			continue
		var score := 0
		for center: Vector2i in centers:
			var distance := maxi(absi(center.x - x), absi(center.y - y))
			score = distance if score == 0 or distance < score else score
		if score < best_score:
			best_score = score
			best = cell
	return best


func _near_foreign(owners: PackedByteArray, nation_id: int, cell: Vector2i) -> bool:
	var margin := Balance.FOUND_BORDER_MARGIN
	for dy in range(-margin, margin + 1):
		for dx in range(-margin, margin + 1):
			var x := cell.x + dx
			var y := cell.y + dy
			if not _grid.is_valid_coord(x, y):
				continue
			var other: int = owners[y * TerritoryGrid.WIDTH + x]
			if other != TerritoryGrid.OWNER_NONE and other != nation_id:
				return true
	return false


# ---------------------------------------------------------------------------
# 2. Frentes: reorganizar y defender
# ---------------------------------------------------------------------------

@warning_ignore("integer_division")
func _manage_fronts(nation_id: int, actions: Array) -> void:
	for sector_id: int in _military.get_sector_ids(nation_id):
		var soldiers: int = _military.get_sector(sector_id)["soldiers"]
		if not _offensives.is_active(sector_id) or soldiers < Balance.MIN_FRONT_SOLDIERS:
			_military.remove_sector(sector_id)
			actions.append("retira el frente %d" % sector_id)
	var incoming := incoming_soldiers(nation_id)
	if incoming <= 0:
		return
	var needed := incoming * Balance.DEFENSE_RESERVE_PERCENT / 100
	var attackers := {}
	for attack: Dictionary in _offensives.attacks_against(nation_id):
		attackers[attack["attacker"]] = true
	for expansion_pass in [true, false]:
		var ids := _military.get_sector_ids(nation_id)
		ids.reverse()
		for sector_id: int in ids:
			if _military.available_soldiers(nation_id) >= needed:
				return
			var goal := _offensives.goal_of(sector_id)
			var is_expansion := goal == TerritoryGrid.OWNER_NONE
			if is_expansion != expansion_pass or attackers.has(goal):
				continue
			_military.remove_sector(sector_id)
			actions.append("retira el frente %d para defenderse" % sector_id)


# ---------------------------------------------------------------------------
# 3. Ofensiva
# ---------------------------------------------------------------------------

@warning_ignore("integer_division")
func _manage_offense(nation_id: int, actions: Array) -> void:
	if _population.get_maintenance(nation_id)["in_deficit"]:
		return
	var free := free_soldiers(nation_id)
	if free < Balance.MIN_EXPANSION_SOLDIERS:
		return
	for enemy_id: int in _wars.enemies_of(nation_id):
		if _has_front_against(nation_id, enemy_id):
			continue
		if _attack(nation_id, enemy_id, maxi(1, free * Balance.ATTACK_COMMIT_PERCENT / 100), actions):
			return
	if _front_count(nation_id, true) < Balance.MAX_EXPANSION_FRONTS and incoming_soldiers(nation_id) == 0:
		var commit := maxi(Balance.MIN_EXPANSION_SOLDIERS, free * Balance.EXPANSION_COMMIT_PERCENT / 100)
		if _expand(nation_id, mini(commit, free), actions):
			return
	_consider_war(nation_id, free, actions)


## Lanza un ataque contra `enemy_id` con `commit` soldados si encuentra un frente y la previsión es una
## victoria. Devuelve si lo lanzó.
func _attack(nation_id: int, enemy_id: int, commit: int, actions: Array) -> bool:
	var front := front_against(nation_id, enemy_id)
	if front.is_empty():
		return false
	var plan := _offensives.plan_attack(nation_id, front["origin"], front["direction"], commit)
	if not plan["ok"] or not plan["info"].get("attacker_wins", false):
		return false
	var was_at_war := _wars.at_war(nation_id, enemy_id)
	var result := _offensives.launch_attack(nation_id, front["origin"], front["direction"], commit)
	if not result["ok"]:
		return false
	actions.append("ataca a %d con %d" % [enemy_id, commit])
	if not was_at_war and _wars.at_war(nation_id, enemy_id):
		_last_war[nation_id] = _cities.tick_count()
		if _is_ai(enemy_id):
			event.emit("%s declara la guerra a %s." % [_name(nation_id), _name(enemy_id)])
		else:
			event.emit("¡%s te declara la guerra!" % _name(nation_id))
	return true


## Frente para atacar a `enemy_id`: primero liberar una celda propia que ocupa; si no, desde la celda propia
## de frontera con él más cercana a una de sus ciudades (o la primera en orden de filas si no tiene).
## {"origin", "direction"} o {} si no hay contacto.
@warning_ignore("integer_division")
func front_against(nation_id: int, enemy_id: int) -> Dictionary:
	for cell: Vector2i in _occupation.get_cells_between(enemy_id, nation_id):
		var liberation := _offensives.suggest_front(nation_id, cell)
		if not liberation.is_empty() and liberation["direction"] >= 0:
			return liberation
	var centers: Array = []
	for city_id: int in _cities.get_city_ids():
		if _cities.get_owner(city_id) == enemy_id:
			centers.append(_cities.get_city(city_id)["cell"])
	var owners := _grid.copy_owner_data()
	var width := TerritoryGrid.WIDTH
	var best := {}
	var best_score := 1000000
	for index in TerritoryGrid.CELL_COUNT:
		if owners[index] != nation_id:
			continue
		var origin := Vector2i(index % width, index / width)
		for direction in Military.DIRECTION_STEPS.size():
			var target: Vector2i = origin + Military.DIRECTION_STEPS[direction]
			if not _grid.is_valid_coord(target.x, target.y) or _grid.get_cell_owner(target.x, target.y) != enemy_id:
				continue
			if _occupation.occupier_at(target) == nation_id or not _offensives.can_attack_from(nation_id, origin, direction):
				continue
			var score := 0
			for center: Vector2i in centers:
				var distance := absi(center.x - target.x) + absi(center.y - target.y)
				score = distance if score == 0 or distance < score else score
			if score < best_score:
				best_score = score
				best = {"origin": origin, "direction": direction}
	return best


## Abre un frente de expansión: prueba las cuatro direcciones (empezando por una que rota en cada decisión)
## sin otra expansión activa en esa dirección; el origen es la celda propia más avanzada en esa dirección
## (la más cercana al centro de su territorio a igualdad) que da a tierra sin reclamar.
func _expand(nation_id: int, commit: int, actions: Array) -> bool:
	var start: int = _decisions.get(nation_id, 0) % Military.DIRECTION_STEPS.size()
	for offset in Military.DIRECTION_STEPS.size():
		var direction := (start + offset) % Military.DIRECTION_STEPS.size()
		if _has_expansion_in(nation_id, direction):
			continue
		var origin := expansion_origin(nation_id, direction)
		if origin == NO_CELL:
			continue
		var plan := _offensives.plan_attack(nation_id, origin, direction, commit)
		if not plan["ok"] or plan["info"].get("goal", -1) != TerritoryGrid.OWNER_NONE:
			continue
		if _offensives.launch_attack(nation_id, origin, direction, commit)["ok"]:
			actions.append("se expande hacia %s con %d" % [Military.DIRECTION_NAMES[direction], commit])
			return true
	return false


func _has_expansion_in(nation_id: int, direction: int) -> bool:
	for sector_id: int in _military.get_sector_ids(nation_id):
		if _offensives.is_active(sector_id) and _offensives.goal_of(sector_id) == TerritoryGrid.OWNER_NONE \
				and _military.get_sector(sector_id)["direction"] == direction:
			return true
	return false


## Celda propia más avanzada en `direction` cuya vecina en esa dirección es tierra sin reclamar; a igualdad,
## la más cercana al centro de su territorio (y después la primera en orden de filas). NO_CELL si no hay.
func expansion_origin(nation_id: int, direction: int) -> Vector2i:
	return _border_scan(nation_id)["expansion"][direction]


## Declara una guerra si se cumplen todas las condiciones de la cabecera (3c).
@warning_ignore("integer_division")
func _consider_war(nation_id: int, free: int, actions: Array) -> void:
	var now := _cities.tick_count()
	if now < Balance.WAR_GRACE_TICKS or not _wars.enemies_of(nation_id).is_empty():
		return
	if now - _last_war.get(nation_id, -Balance.WAR_COOLDOWN_TICKS) < Balance.WAR_COOLDOWN_TICKS:
		return
	if incoming_soldiers(nation_id) > 0 or _population.net_income_milli(nation_id)["resources"] <= 0:
		return
	var target := TerritoryGrid.INVALID
	var target_defense := 0
	for other_id: int in neighbors_of(nation_id):
		if _wars.has_truce(nation_id, other_id) or _wars.enemies_of(other_id).size() >= Balance.MAX_WARS_ON_TARGET:
			continue
		var defense := _offensives.defending_soldiers(other_id)
		if free * 100 < defense * Balance.ATTACK_SUPERIORITY_PERCENT:
			continue
		if target == TerritoryGrid.INVALID or defense < target_defense:
			target = other_id
			target_defense = defense
	if target == TerritoryGrid.INVALID:
		return
	_attack(nation_id, target, maxi(1, free * Balance.ATTACK_COMMIT_PERCENT / 100), actions)


# ---------------------------------------------------------------------------
# 4. Diplomacia
# ---------------------------------------------------------------------------

func _manage_diplomacy(nation_id: int, actions: Array) -> void:
	for proposal: Dictionary in _diplomacy.pending_for(nation_id):
		var verdict := _diplomacy.evaluate_terms(nation_id, proposal["from"], proposal["kind"], proposal["payer"], proposal["amount"])
		if verdict["response"] == Diplomacy.RESPONSE_ACCEPTED:
			var accepted := _diplomacy.accept(proposal["id"], nation_id)
			if accepted["ok"]:
				actions.append("acepta la paz con %d" % proposal["from"])
				event.emit("%s y %s firman la paz." % [_name(nation_id), _name(proposal["from"])])
				continue
		_diplomacy.reject(proposal["id"], nation_id)
		actions.append("rechaza la propuesta de %d" % proposal["from"])
	var now := _cities.tick_count()
	for enemy_id: int in _wars.enemies_of(nation_id):
		if not _is_ai(enemy_id) or _diplomacy.has_pending(nation_id, enemy_id):
			continue
		var key := "%d:%d" % [mini(nation_id, enemy_id), maxi(nation_id, enemy_id)]
		if now < _next_peace.get(key, 0):
			continue
		var stance := _diplomacy.ai_stance(nation_id, enemy_id)
		if stance["reluctance"] > -DiplomacyBalance.PEACE_SEEK_MARGIN:
			continue
		_next_peace[key] = now + DiplomacyBalance.AI_OFFER_INTERVAL_TICKS
		var kind := Diplomacy.KIND_CONQUESTS if stance["held_own"] > stance["held_other"] else Diplomacy.KIND_WHITE
		var result := _diplomacy.propose(nation_id, enemy_id, kind, Diplomacy.NO_PAYER, 0)
		if result["ok"] and result["response"] == Diplomacy.RESPONSE_ACCEPTED:
			actions.append("firma la paz con %d" % enemy_id)
			event.emit("%s y %s firman la paz." % [_name(nation_id), _name(enemy_id)])
		elif result["ok"]:
			actions.append("propone la paz a %d" % enemy_id)
