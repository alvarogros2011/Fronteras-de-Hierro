## Pruebas automáticas de población, movilización y mantenimiento (hito 7). Sin plugins.
##
## Única definición de las comprobaciones; la usan:
##   - tests/test_population.gd (consola, headless):
##       godot --headless --path . --script res://tests/test_population.gd
##   - tests/run_population_tests.tscn (editor de Godot, F6).
##
## Mapa controlado (load_from_data): tierra x 10..39, y 10..29; jugador x 10..24, IA 1 x 25..34,
## sin reclamar x 35..39; el resto es agua. Las ciudades se fundan a mano (sin ciudades iniciales)
## y la población inicial se inyecta, así que ninguna prueba depende del mapa por defecto salvo las
## que lo dicen. El tiempo avanza con CityManager.advance(n): n ticks exactos de 1 s de juego.
## Una ciudad fundada en el tick 0 sube a nivel 2 en el tick 30, a 3 en el 90 y a 4 en el 210.
##
## run_all() devuelve [{"name": String, "errors": Array}, ...]   (errors vacío = PASS)
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Economy := preload("res://scripts/world/economy.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Population := preload("res://scripts/world/population.gd")
const Balance := preload("res://scripts/data/population_balance.gd")
const EconomyBalance := preload("res://scripts/data/economy_balance.gd")
const Screen := preload("res://scripts/ui/territory_screen.gd")
const InfoPanel := preload("res://scripts/ui/territory_info_panel.gd")
const PopulationPanel := preload("res://scripts/ui/population_panel.gd")

const PLAYER := TerritoryGrid.OWNER_PLAYER
const AI_1 := TerritoryGrid.OWNER_AI_1
const SCREEN_PATH := "res://scenes/territory_main.tscn"
const CITY_A := Vector2i(12, 12)
const CITY_B := Vector2i(22, 12)  # a 10 celdas de A: cabe (mínimo 9)

var _results: Array = []
var _signal_count: int = 0
var _tick_count: int = 0


func run_all() -> Array:
	_results = []
	_run("las constantes de equilibrio son coherentes y el equilibrio inicial es sostenible", _test_balance_constants)
	_run("población inicial por nación, consultas y naciones inexistentes", _test_initial_and_queries)
	_run("la población nace a través de las ciudades (acumulando fracciones)", _test_growth_through_cities)
	_run("la población nueva se reparte según el porcentaje sin perder ni duplicar a nadie", _test_split)
	_run("cambiar el porcentaje no reasigna a los trabajadores y soldados existentes", _test_percent_does_not_reassign)
	_run("se conservan los totales: tope de capacidad, sin saltos y movilización sin altas ni bajas", _test_conservation)
	_run("la capacidad suma las ciudades activas; no mata gente ni se desborda al crecer", _test_capacity)
	_run("ciudad prioritaria: crece el doble, se puede quitar y varias son independientes", _test_priority_growth)
	_run("la prioridad solo la fija el dueño, se pierde al cambiar de dueño y no toca el territorio", _test_priority_rules)
	_run("subir de nivel no crea soldados de golpe", _test_level_up_creates_no_soldiers)
	_run("movilización progresiva: reserva, ritmo constante, resultado exacto y no instantánea", _test_mobilization_timeline)
	_run("movilización: validaciones y nunca más trabajadores de los disponibles", _test_mobilization_validation)
	_run("movilización sin duplicados y con la población nueva siguiendo el porcentaje vigente", _test_mobilization_no_double_count)
	_run("costes de mantenimiento exactos y sin redondeos a favor ni en contra", _test_upkeep_cost)
	_run("la prioridad de mantenimiento decide qué grupo cobra primero", _test_maintenance_priority)
	_run("déficit gradual: gracia, pérdidas lentas, sin crecimiento y recuperación", _test_deficit_gradual)
	_run("déficit con movilización en curso: la reserva nunca supera a los trabajadores", _test_deficit_with_mobilization)
	_run("un déficit prolongado se corrige solo y el crecimiento se detiene mientras dura", _test_deficit_recovers)
	_run("ningún saldo se vuelve negativo; spend_resources valida como spend_money", _test_no_negative_balances)
	_run("el juego por defecto es sostenible, incluso movilizando y reclutando mucho", _test_default_play_sustainable)
	_run("el comportamiento territorial y económico anterior se conserva", _test_previous_behavior_kept)
	_run("textos del HUD de población, movilización, mantenimiento y déficit", _test_ui_texts)
	_run("pantalla: panel de población, movilización, mantenimiento y prioridad de ciudad", _test_screen)
	_run("las suites anteriores y los archivos del hito siguen presentes", _test_files_present)
	return _results


func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	_results.append({"name": test_name, "errors": errors})


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


func _count_signal() -> void:
	_signal_count += 1


func _count_tick() -> void:
	_tick_count += 1


# ---------------------------------------------------------------------------
# Datos controlados
# ---------------------------------------------------------------------------

func _make_grid() -> TerritoryGrid:
	var terrain := PackedByteArray()
	terrain.resize(TerritoryGrid.CELL_COUNT)
	terrain.fill(TerritoryGrid.TERRAIN_WATER)
	var owners := PackedByteArray()
	owners.resize(TerritoryGrid.CELL_COUNT)
	owners.fill(TerritoryGrid.OWNER_NONE)
	for y in range(10, 30):
		for x in range(10, 40):
			terrain[y * TerritoryGrid.WIDTH + x] = TerritoryGrid.TERRAIN_LAND
			if x <= 24:
				owners[y * TerritoryGrid.WIDTH + x] = PLAYER
			elif x <= 34:
				owners[y * TerritoryGrid.WIDTH + x] = AI_1
	var grid := TerritoryGrid.new()
	grid.load_from_data(terrain, owners)
	return grid


## Mapa controlado con las ciudades del jugador dadas (fundadas en el tick 0) y una población
## inyectada. Las naciones sin entrada en `initial` empiezan en 0. Sin ticks transcurridos.
func _make_world(initial: Dictionary, player_cities: Array = [CITY_A]) -> Dictionary:
	var grid := _make_grid()
	var economy := Economy.new(grid.get_nation_ids())
	var cities := CityManager.new(grid, economy)
	economy.add(PLAYER, 1000, 0)
	for cell: Vector2i in player_cities:
		cities.found_city(PLAYER, cell)
	var population := Population.new(cities, economy, grid.get_nation_ids(), initial)
	return {"grid": grid, "economy": economy, "cities": cities, "pop": population}


## Como _make_world pero la ciudad del jugador ya es de nivel 4 (210 ticks antes de crear la
## población): capacidad 240 y producción de 5 recursos por tick, y sin sitio para nacimientos
## cuando la población inicial es 240, así que los totales no se mueven por crecimiento.
func _make_maxed_world(initial: Dictionary) -> Dictionary:
	var grid := _make_grid()
	var economy := Economy.new(grid.get_nation_ids())
	var cities := CityManager.new(grid, economy)
	economy.add(PLAYER, 1000, 0)
	cities.found_city(PLAYER, CITY_A)
	cities.advance(210.0)
	var population := Population.new(cities, economy, grid.get_nation_ids(), initial)
	return {"grid": grid, "economy": economy, "cities": cities, "pop": population}


func _advance(world: Dictionary, ticks: int) -> void:
	var cities: CityManager = world["cities"]
	cities.advance(float(ticks))


## Datos sin cálculos intermedios: [trabajadores, soldados] de la nación.
func _people(pop: Population, nation_id: int) -> Array:
	return [pop.workers(nation_id), pop.soldiers(nation_id)]


# ---------------------------------------------------------------------------
# Pruebas
# ---------------------------------------------------------------------------

@warning_ignore("integer_division")
func _test_balance_constants() -> Array:
	var errors: Array = []
	var levels := EconomyBalance.MAX_LEVEL
	for table: Array in [Balance.GROWTH_MILLI_PER_LEVEL, Balance.CAPACITY_PER_LEVEL]:
		_expect(errors, table.size(), levels + 1, "las tablas tienen una entrada por nivel")
	for level in range(1, levels):
		_expect(errors, Balance.CAPACITY_PER_LEVEL[level + 1] > Balance.CAPACITY_PER_LEVEL[level], true, "la capacidad sube con el nivel %d" % (level + 1))
		_expect(errors, Balance.GROWTH_MILLI_PER_LEVEL[level + 1] >= Balance.GROWTH_MILLI_PER_LEVEL[level], true, "el crecimiento no baja con el nivel %d" % (level + 1))
	_expect(errors, Balance.PRIORITY_GROWTH_PERCENT > 100, true, "la prioridad aumenta el crecimiento")
	_expect(errors, Balance.MOBILIZATION_MAX_PERCENT >= 1 and Balance.MOBILIZATION_MAX_PERCENT <= 100, true, "el máximo de movilización es un porcentaje válido")
	_expect(errors, Balance.MOBILIZATION_TICKS > 1, true, "la movilización dura más de un tick")
	_expect(errors, Balance.WORKER_UPKEEP_MILLI > 0 and Balance.SOLDIER_UPKEEP_MILLI >= Balance.WORKER_UPKEEP_MILLI, true, "mantenerse cuesta; un soldado no cuesta menos que un trabajador")
	_expect(errors, Balance.DEFICIT_GRACE_TICKS > 0, true, "hay un plazo de gracia antes de perder población")
	_expect(errors, Balance.DEFICIT_LOSS_PERMILLE >= 1 and Balance.DEFICIT_LOSS_PERMILLE < 1000, true, "las pérdidas por déficit son parciales")
	_expect(errors, Balance.DEFICIT_DEBT_LIMIT_TICKS >= 1, true, "la deuda admite al menos un tick")
	_expect(errors, Balance.INITIAL_NEW_SOLDIER_PERCENT >= 0 and Balance.INITIAL_NEW_SOLDIER_PERCENT <= 100, true, "reparto inicial válido")
	var grid := TerritoryGrid.new()
	for nation_id: int in grid.get_nation_ids():
		_expect(errors, Balance.INITIAL_POPULATION.has(nation_id), true, "población inicial de la nación %d" % nation_id)
		var start: Dictionary = Balance.INITIAL_POPULATION[nation_id]
		_expect(errors, start["workers"] >= 0 and start["soldiers"] >= 0, true, "cifras iniciales no negativas")
		_expect(errors, start["workers"] + start["soldiers"] <= Balance.CAPACITY_PER_LEVEL[1], true, "se empieza por debajo de la capacidad de una ciudad de nivel 1")
	# Equilibrio: a población máxima, y con cualquier mezcla razonable, el coste cabe en la producción.
	for level in range(1, levels + 1):
		var cap: int = Balance.CAPACITY_PER_LEVEL[level]
		var income: int = EconomyBalance.RESOURCES_PER_TICK[level] * 1000
		_expect(errors, cap * Balance.WORKER_UPKEEP_MILLI <= income, true, "nivel %d: toda la población trabajadora es sostenible" % level)
		var half := cap / 2
		var mixed := half * Balance.WORKER_UPKEEP_MILLI + (cap - half) * Balance.SOLDIER_UPKEEP_MILLI
		_expect(errors, mixed <= income, true, "nivel %d: mitad y mitad es sostenible" % level)
	return errors


func _test_initial_and_queries() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var economy := Economy.new(grid.get_nation_ids())
	var cities := CityManager.new(grid, economy)
	cities.place_initial_cities()
	var pop := Population.new(cities, economy, grid.get_nation_ids())
	for nation_id: int in grid.get_nation_ids():
		var start: Dictionary = Balance.INITIAL_POPULATION[nation_id]
		_expect(errors, _people(pop, nation_id), [start["workers"], start["soldiers"]], "población inicial de la nación %d" % nation_id)
		_expect(errors, pop.total_population(nation_id), start["workers"] + start["soldiers"], "total = trabajadores + soldados")
		_expect(errors, pop.available_workers(nation_id), start["workers"], "sin movilización, todos los trabajadores están disponibles")
		_expect(errors, pop.pending_mobilization(nation_id), 0, "sin movilización no hay pendientes")
		_expect(errors, pop.capacity(nation_id), Balance.CAPACITY_PER_LEVEL[1], "una ciudad inicial de nivel 1 admite su capacidad")
		var summary := pop.get_summary(nation_id)
		_expect(errors, [summary["total"], summary["workers"], summary["soldiers"]], [pop.total_population(nation_id), pop.workers(nation_id), pop.soldiers(nation_id)], "el resumen coincide con las consultas")
		_expect(errors, summary["new_soldier_percent"] + summary["new_worker_percent"], 100, "los porcentajes de reparto suman 100")
		_expect(errors, summary["new_soldier_percent"], Balance.INITIAL_NEW_SOLDIER_PERCENT, "reparto inicial")
		_expect(errors, pop.maintenance_priority(nation_id), Population.MAINT_WORKERS_FIRST, "prioridad de mantenimiento inicial")
		_expect(errors, pop.get_maintenance(nation_id)["in_deficit"], false, "empieza sin déficit")
		_expect(errors, pop.get_mobilization(nation_id)["active"], false, "empieza sin movilización")
	for unknown: int in [TerritoryGrid.OWNER_NONE, 99, -1]:
		_expect(errors, [pop.has_nation(unknown), pop.workers(unknown), pop.soldiers(unknown), pop.total_population(unknown)], [false, -1, -1, -1], "nación %d inexistente" % unknown)
		_expect(errors, [pop.get_summary(unknown).is_empty(), pop.get_maintenance(unknown).is_empty(), pop.get_mobilization(unknown).is_empty()], [true, true, true], "consultas vacías de la nación %d" % unknown)
	# Datos inyectables: una nación que falta en la tabla empieza en 0.
	var custom := Population.new(cities, economy, grid.get_nation_ids(), {PLAYER: {"workers": 7, "soldiers": 3}})
	_expect(errors, [_people(custom, PLAYER), _people(custom, AI_1)], [[7, 3], [0, 0]], "población inyectada")
	return errors


func _test_growth_through_cities() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 10, "soldiers": 0}, AI_1: {"workers": 10, "soldiers": 0}})
	var pop: Population = world["pop"]
	world["economy"].add(AI_1, 0, 100)  # sin ciudades no produce: así su mantenimiento no entra en déficit
	pop.set_new_soldier_percent(PLAYER, 0)
	_expect(errors, pop.growth_milli(PLAYER), Balance.GROWTH_MILLI_PER_LEVEL[1], "aporte de una ciudad de nivel 1")
	_expect(errors, pop.growth_milli(AI_1), 0, "una nación sin ciudades no aporta nada")
	_advance(world, 6)
	_expect(errors, pop.total_population(PLAYER), 10, "6 ticks = 900 milésimas: aún nadie")
	_advance(world, 1)
	_expect(errors, pop.total_population(PLAYER), 11, "7 ticks = 1.050 milésimas: nace 1 y el resto se acumula")
	_advance(world, 13)
	_expect(errors, pop.total_population(PLAYER), 13, "20 ticks = 3.000 milésimas = 3 personas")
	_expect(errors, pop.total_population(AI_1), 10, "sin ciudades no hay crecimiento")
	# Dos ciudades aportan el doble.
	var two := _make_world({PLAYER: {"workers": 10, "soldiers": 0}}, [CITY_A, CITY_B])
	var pop2: Population = two["pop"]
	pop2.set_new_soldier_percent(PLAYER, 0)
	_expect(errors, pop2.growth_milli(PLAYER), 2 * Balance.GROWTH_MILLI_PER_LEVEL[1], "dos ciudades suman")
	_advance(two, 20)
	_expect(errors, pop2.total_population(PLAYER), 16, "dos ciudades: 6.000 milésimas = 6 personas")
	# Una ciudad sin propietario (centro sin dueño) no aporta.
	var grid: TerritoryGrid = two["grid"]
	grid.try_set_owner(CITY_B.x, CITY_B.y, TerritoryGrid.OWNER_NONE)
	_expect(errors, pop2.city_growth_milli(2), 0, "ciudad sin propietario: aporte 0")
	_expect(errors, pop2.growth_milli(PLAYER), Balance.GROWTH_MILLI_PER_LEVEL[1], "solo aporta la ciudad que sigue siendo del jugador")
	return errors


func _test_split() -> Array:
	var errors: Array = []
	for percent in [0, 30, 50, 100]:
		var world := _make_world({PLAYER: {"workers": 10, "soldiers": 0}}, [CITY_A, CITY_B])
		var pop: Population = world["pop"]
		_expect(errors, pop.set_new_soldier_percent(PLAYER, percent), true, "porcentaje %d aceptado" % percent)
		_advance(world, 29)
		var born: int = pop.total_population(PLAYER) - 10
		_expect(errors, born, 8, "29 ticks con dos ciudades: 8.700 milésimas = 8 nacidos")
		var new_soldiers := floori(born * percent / 100.0)
		_expect(errors, pop.soldiers(PLAYER), new_soldiers, "soldados nuevos con %d %%" % percent)
		_expect(errors, pop.workers(PLAYER), 10 + born - new_soldiers, "trabajadores nuevos con %d %%" % percent)
		_expect(errors, pop.workers(PLAYER) + pop.soldiers(PLAYER), 10 + born, "no se pierde ni se duplica nadie en el reparto")
	return errors


func _test_percent_does_not_reassign() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 20, "soldiers": 10}})
	var pop: Population = world["pop"]
	for percent in [0, 100, 50, 13, 100, 0]:
		pop.set_new_soldier_percent(PLAYER, percent)
		_expect(errors, _people(pop, PLAYER), [20, 10], "cambiar a %d %% no toca a los existentes" % percent)
		_expect(errors, pop.new_soldier_percent(PLAYER) + pop.new_worker_percent(PLAYER), 100, "siempre suman 100")
	_expect(errors, pop.set_new_soldier_percent(PLAYER, -1), false, "-1 rechazado")
	_expect(errors, pop.set_new_soldier_percent(PLAYER, 101), false, "101 rechazado")
	_expect(errors, pop.set_new_soldier_percent(99, 50), false, "nación inexistente rechazada")
	_expect(errors, pop.new_soldier_percent(PLAYER), 0, "los rechazos no cambian el reparto")
	for percent in range(0, 101):
		pop.set_new_soldier_percent(PLAYER, percent)
		if pop.new_soldier_percent(PLAYER) + pop.new_worker_percent(PLAYER) != 100:
			errors.append("los porcentajes no suman 100 con %d" % percent)
	# Con un reparto del 100 % a soldados solo cambian los soldados, y solo por los nacidos.
	pop.set_new_soldier_percent(PLAYER, 100)
	_advance(world, 10)
	_expect(errors, _people(pop, PLAYER), [20, 11], "10 ticks: 1 nacido, todo a soldados; los trabajadores intactos")
	pop.set_new_soldier_percent(PLAYER, 0)
	_advance(world, 10)
	_expect(errors, _people(pop, PLAYER), [22, 11], "tras pasar a 0 %: los 2 nuevos son trabajadores y los soldados siguen igual")
	return errors


func _test_conservation() -> Array:
	var errors: Array = []
	# Sin sitio para nacimientos: la movilización y los cambios de reparto no alteran el total.
	var maxed := _make_maxed_world({PLAYER: {"workers": 200, "soldiers": 40}})
	var pop: Population = maxed["pop"]
	_expect(errors, maxed["cities"].get_city(1)["level"], EconomyBalance.MAX_LEVEL, "la ciudad llegó al nivel máximo")
	_expect(errors, pop.capacity(PLAYER), 240, "capacidad 240")
	_expect(errors, pop.start_mobilization(PLAYER, 50), Population.MOB_OK, "movilización aceptada")
	for tick in 40:
		if tick % 7 == 0:
			pop.set_new_soldier_percent(PLAYER, (tick * 13) % 101)
		_advance(maxed, 1)
		if pop.total_population(PLAYER) != 240:
			errors.append("el total cambió en el tick %d: %d" % [tick, pop.total_population(PLAYER)])
		if pop.workers(PLAYER) < 0 or pop.soldiers(PLAYER) < 0:
			errors.append("cifras negativas en el tick %d" % tick)
	# Con nacimientos: nunca se supera la capacidad y no hay saltos mayores que 1 persona por tick.
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 6}})
	var growing: Population = world["pop"]
	var cities: CityManager = world["cities"]
	var previous := growing.total_population(PLAYER)
	var born_total := 0
	for tick in 150:
		_advance(world, 1)
		var total := growing.total_population(PLAYER)
		if total < previous or total - previous > 1:
			errors.append("salto de población en el tick %d: %d -> %d" % [tick, previous, total])
		if total > growing.capacity(PLAYER):
			errors.append("capacidad superada en el tick %d" % tick)
		born_total += total - previous
		previous = total
	_expect(errors, growing.total_population(PLAYER), 36 + born_total, "total = inicial + nacidos")
	_expect(errors, cities.get_city(1)["level"], 3, "tras 150 ticks la ciudad es de nivel 3 (referencia del escenario)")
	return errors


func _test_capacity() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 50, "soldiers": 0}})
	var pop: Population = world["pop"]
	var cities: CityManager = world["cities"]
	_expect(errors, pop.capacity(PLAYER), Balance.CAPACITY_PER_LEVEL[1], "una ciudad de nivel 1")
	_expect(errors, pop.capacity(AI_1), 0, "sin ciudades no hay capacidad")
	_advance(world, 29)
	_expect(errors, pop.total_population(PLAYER), 50, "al tope no nace nadie")
	_expect(errors, pop.get_summary(PLAYER)["growth_milli"], 0, "el crecimiento efectivo es 0 al tope")
	# Fundar otra ciudad amplía la capacidad.
	_expect(errors, cities.found_city(PLAYER, CITY_B)["ok"], true, "se funda otra ciudad")
	_expect(errors, pop.capacity(PLAYER), 2 * Balance.CAPACITY_PER_LEVEL[1], "dos ciudades suman capacidad")
	_expect(errors, pop.get_summary(PLAYER)["growth_milli"], 2 * Balance.GROWTH_MILLI_PER_LEVEL[1], "con hueco vuelve el crecimiento")
	# La fracción acumulada contra el tope no se convierte en una ráfaga: como mucho 1 nacido en el tick 30.
	_advance(world, 1)
	var after_level_up := pop.total_population(PLAYER)
	_expect(errors, after_level_up >= 50 and after_level_up <= 51, true, "sin ráfaga al liberarse capacidad (hay %d)" % after_level_up)
	# Con mucha más población que capacidad, nadie desaparece mientras el mantenimiento se pague.
	var over := _make_world({PLAYER: {"workers": 60, "soldiers": 0}})
	_advance(over, 20)
	_expect(errors, _people(over["pop"], PLAYER), [60, 0], "la población por encima de la capacidad no se reduce sola")
	return errors


@warning_ignore("integer_division")
func _test_priority_growth() -> Array:
	var errors: Array = []
	var plain := _make_world({PLAYER: {"workers": 10, "soldiers": 0}})
	var boosted := _make_world({PLAYER: {"workers": 10, "soldiers": 0}})
	var pop_a: Population = plain["pop"]
	var pop_b: Population = boosted["pop"]
	pop_a.set_new_soldier_percent(PLAYER, 0)
	pop_b.set_new_soldier_percent(PLAYER, 0)
	_expect(errors, pop_b.set_city_priority(PLAYER, 1, true), true, "se activa la prioridad")
	_expect(errors, [pop_b.is_city_priority(1), pop_a.is_city_priority(1)], [true, false], "estado de la prioridad")
	var base := Balance.GROWTH_MILLI_PER_LEVEL[1]
	_expect(errors, pop_b.city_growth_milli(1), base * Balance.PRIORITY_GROWTH_PERCENT / 100, "la ciudad prioritaria multiplica su aporte")
	_expect(errors, pop_a.city_growth_milli(1), base, "la otra mantiene el aporte base")
	_advance(plain, 20)
	_advance(boosted, 20)
	_expect(errors, pop_a.total_population(PLAYER) - 10, 3, "sin prioridad: 3 nacidos en 20 ticks")
	_expect(errors, pop_b.total_population(PLAYER) - 10, 6, "con prioridad: 6 nacidos en 20 ticks")
	# Hito 11: la prioridad cuesta PRIORITY_MONEY_PER_TICK de dinero por tick y acelera el nivel de la ciudad
	# (PRIORITY_CITY_GROWTH puntos extra por tick); nunca cambia el territorio.
	_expect(errors, [pop_b.get_stats(PLAYER)["priority_paid"], pop_a.get_stats(PLAYER)["priority_paid"]], [20 * Balance.PRIORITY_MONEY_PER_TICK, 0], "la prioridad cobra su coste cada tick")
	var points := 20 * (EconomyBalance.GROWTH_PER_TICK + Balance.PRIORITY_CITY_GROWTH)
	_expect(errors, [boosted["cities"].get_city(1)["level"], boosted["cities"].get_city(1)["progress"]], [2, points - EconomyBalance.GROWTH_TO_NEXT[1]], "la ciudad prioritaria sube antes de nivel")
	_expect(errors, [plain["cities"].get_city(1)["level"], plain["cities"].get_city(1)["progress"]], [1, 20 * EconomyBalance.GROWTH_PER_TICK], "la otra sigue su ritmo")
	_expect(errors, boosted["grid"].copy_owner_data() == plain["grid"].copy_owner_data(), true, "mismo territorio")
	# Se puede quitar. La ciudad subió a nivel 2 (comprobado arriba), así que su aporte base ya es el del nivel 2,
	# no el del nivel 1 (`base`); la prioridad solo multiplica el del nivel real.
	var level_now: int = boosted["cities"].get_city(1)["level"]
	var base_now: int = Balance.GROWTH_MILLI_PER_LEVEL[level_now]
	_expect(errors, [level_now, base_now != base], [2, true], "el aporte base depende del nivel real de la ciudad")
	_expect(errors, pop_b.city_growth_milli(1), base_now * Balance.PRIORITY_GROWTH_PERCENT / 100, "activa en nivel 2: duplica el aporte del nivel 2")
	pop_b.set_city_priority(PLAYER, 1, false)
	_expect(errors, [pop_b.is_city_priority(1), pop_b.city_growth_milli(1)], [false, base_now], "tras desactivarla vuelve al aporte base del nivel real")
	# Varias ciudades prioritarias a la vez: cada una recibe el efecto por separado.
	var two := _make_world({PLAYER: {"workers": 10, "soldiers": 0}}, [CITY_A, CITY_B])
	var pop: Population = two["pop"]
	var boosted_milli := base * Balance.PRIORITY_GROWTH_PERCENT / 100
	_expect(errors, pop.growth_milli(PLAYER), 2 * base, "ninguna prioritaria")
	pop.set_city_priority(PLAYER, 1, true)
	_expect(errors, pop.growth_milli(PLAYER), boosted_milli + base, "una prioritaria")
	pop.set_city_priority(PLAYER, 2, true)
	_expect(errors, pop.growth_milli(PLAYER), 2 * boosted_milli, "las dos prioritarias: efecto independiente en cada una")
	pop.set_city_priority(PLAYER, 1, false)
	_expect(errors, pop.growth_milli(PLAYER), boosted_milli + base, "quitar una no afecta a la otra")
	return errors


@warning_ignore("integer_division")
func _test_priority_rules() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 10, "soldiers": 0}, AI_1: {"workers": 10, "soldiers": 0}}, [Vector2i(24, 12)])
	var grid: TerritoryGrid = world["grid"]
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	var pop: Population = world["pop"]
	var owners_before := grid.copy_owner_data()
	var money_before := economy.get_money(PLAYER)
	_signal_count = 0
	grid.ownership_changed.connect(_count_signal)
	_expect(errors, pop.set_city_priority(AI_1, 1, true), false, "otra nación no puede marcar mi ciudad")
	_expect(errors, pop.set_city_priority(PLAYER, 99, true), false, "ciudad inexistente")
	_expect(errors, pop.set_city_priority(99, 1, true), false, "nación inexistente")
	_expect(errors, pop.is_city_priority(1), false, "los rechazos no cambian nada")
	_expect(errors, pop.set_city_priority(PLAYER, 1, true), true, "el dueño sí puede")
	_expect(errors, pop.set_city_priority(PLAYER, 1, true), true, "repetir es inofensivo")
	var base := Balance.GROWTH_MILLI_PER_LEVEL[1]
	_expect(errors, [grid.copy_owner_data() == owners_before, economy.get_money(PLAYER), _signal_count], [true, money_before, 0], "prioridad: sin cambios de territorio ni de dinero")
	grid.ownership_changed.disconnect(_count_signal)
	# Si la ciudad se conquista, la prioridad del anterior dueño deja de aplicarse.
	_expect(errors, grid.conquer_cells(AI_1, [Vector2i(24, 12)])["ok"], true, "la IA 1 conquista la celda central")
	_expect(errors, cities.get_owner(1), AI_1, "la ciudad es ahora de la IA 1")
	_expect(errors, [pop.is_city_priority(1), pop.city_growth_milli(1)], [false, base], "la prioridad del jugador no pasa al nuevo dueño")
	_expect(errors, [pop.growth_milli(PLAYER), pop.growth_milli(AI_1)], [0, base], "el aporte pasa al nuevo dueño")
	_expect(errors, pop.set_city_priority(PLAYER, 1, true), false, "el antiguo dueño ya no puede marcarla")
	_expect(errors, pop.set_city_priority(AI_1, 1, true), true, "el nuevo dueño sí")
	_expect(errors, pop.city_growth_milli(1), base * Balance.PRIORITY_GROWTH_PERCENT / 100, "efecto para el nuevo dueño")
	# Al volver al jugador, no recupera la prioridad que fijó la IA.
	_expect(errors, grid.conquer_cells(PLAYER, [Vector2i(24, 12)])["ok"], true, "el jugador la reconquista")
	_expect(errors, [pop.is_city_priority(1), pop.city_growth_milli(1)], [false, base], "la prioridad de la IA no pasa al jugador")
	return errors


func _test_level_up_creates_no_soldiers() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 6}})
	var pop: Population = world["pop"]
	var cities: CityManager = world["cities"]
	var previous_soldiers := pop.soldiers(PLAYER)
	var previous_total := pop.total_population(PLAYER)
	for tick in 220:
		var level_before: int = cities.get_city(1)["level"]
		_advance(world, 1)
		var soldiers := pop.soldiers(PLAYER)
		var total := pop.total_population(PLAYER)
		if soldiers - previous_soldiers > 1 or total - previous_total > 1:
			errors.append("salto de población en el tick %d (nivel %d -> %d)" % [tick + 1, level_before, cities.get_city(1)["level"]])
		previous_soldiers = soldiers
		previous_total = total
	_expect(errors, cities.get_city(1)["level"], EconomyBalance.MAX_LEVEL, "la ciudad subió de nivel durante la prueba")
	return errors


@warning_ignore("integer_division")
func _test_mobilization_timeline() -> Array:
	var errors: Array = []
	var world := _make_maxed_world({PLAYER: {"workers": 200, "soldiers": 40}})
	var pop: Population = world["pop"]
	_signal_count = 0
	pop.changed.connect(_count_signal)
	_expect(errors, pop.start_mobilization(PLAYER, 50), Population.MOB_OK, "movilización aceptada")
	_expect(errors, _signal_count, 1, "iniciar avisa una vez")
	var started := pop.get_mobilization(PLAYER)
	_expect(errors, [started["active"], started["total"], started["converted"], started["pending"]], [true, 100, 0, 100], "se reservan 100 trabajadores (50 % de 200)")
	_expect(errors, [started["elapsed_ticks"], started["duration_ticks"], started["progress_percent"]], [0, Balance.MOBILIZATION_TICKS, 0], "tiempo y progreso iniciales")
	_expect(errors, [pop.workers(PLAYER), pop.soldiers(PLAYER), pop.total_population(PLAYER)], [200, 40, 240], "al iniciar nadie ha cambiado de grupo todavía")
	_expect(errors, [pop.available_workers(PLAYER), pop.pending_mobilization(PLAYER)], [100, 100], "los reservados ya no están disponibles")
	for tick in range(1, Balance.MOBILIZATION_TICKS + 1):
		_advance(world, 1)
		var converted := floori(100.0 * tick / Balance.MOBILIZATION_TICKS)
		if tick < Balance.MOBILIZATION_TICKS:
			var state := pop.get_mobilization(PLAYER)
			_expect(errors, [state["active"], state["converted"], state["pending"], state["elapsed_ticks"]], [true, converted, 100 - converted, tick], "estado en el tick %d" % tick)
			_expect(errors, pop.available_workers(PLAYER), 200 - converted - (100 - converted), "disponibles en el tick %d" % tick)
		_expect(errors, _people(pop, PLAYER), [200 - converted, 40 + converted], "reparto en el tick %d" % tick)
		_expect(errors, pop.total_population(PLAYER), 240, "el total no cambia en el tick %d" % tick)
		if tick == 1:
			_expect(errors, converted < 100, true, "no es instantánea: tras un tick quedan pendientes")
		if tick == Balance.MOBILIZATION_TICKS / 2:
			_expect(errors, pop.get_mobilization(PLAYER)["progress_percent"], 50, "a mitad de plazo, 50 %")
	var done := pop.get_mobilization(PLAYER)
	_expect(errors, [done["active"], done["pending"], done["progress_percent"]], [false, 0, 0], "terminada: sin pendientes")
	_expect(errors, _people(pop, PLAYER), [100, 140], "resultado final exacto")
	_expect(errors, _signal_count > Balance.MOBILIZATION_TICKS, true, "cada tick avisa a la interfaz")
	_expect(errors, pop.get_maintenance(PLAYER)["in_deficit"], false, "la movilización era sostenible")
	pop.changed.disconnect(_count_signal)
	return errors


func _test_mobilization_validation() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 100, "soldiers": 0}, AI_1: {"workers": 1, "soldiers": 0}})
	var pop: Population = world["pop"]
	for percent in [0, -5, Balance.MOBILIZATION_MAX_PERCENT + 1, 100, 101]:
		_expect(errors, pop.start_mobilization(PLAYER, percent), Population.MOB_ERR_PERCENT, "%d %% fuera de rango" % percent)
	_expect(errors, pop.start_mobilization(99, 10), Population.MOB_ERR_UNKNOWN_NATION, "nación inexistente")
	_expect(errors, pop.start_mobilization(TerritoryGrid.OWNER_NONE, 10), Population.MOB_ERR_UNKNOWN_NATION, "OWNER_NONE no es una nación")
	_expect(errors, pop.start_mobilization(AI_1, 50), Population.MOB_ERR_NOTHING, "50 % de 1 trabajador no llega a una persona")
	_expect(errors, pop.get_mobilization(PLAYER)["active"], false, "los rechazos no inician nada")
	_expect(errors, [pop.pending_mobilization(PLAYER), pop.available_workers(PLAYER), pop.workers(PLAYER)], [0, 100, 100], "ni reservan gente")
	for code in [Population.MOB_OK, Population.MOB_ERR_UNKNOWN_NATION, Population.MOB_ERR_ACTIVE, Population.MOB_ERR_PERCENT, Population.MOB_ERR_NOTHING]:
		var message := Population.mobilization_error_message(code)
		_expect(errors, message != "" and message != "Error desconocido.", true, "mensaje del código %d" % code)
	# El máximo permitido nunca reserva más trabajadores de los que hay, tampoco con pocos.
	for workers in [1, 2, 3, 7, 33, 100]:
		var scenario := _make_world({PLAYER: {"workers": workers, "soldiers": 0}})
		var scenario_pop: Population = scenario["pop"]
		var code := scenario_pop.start_mobilization(PLAYER, Balance.MOBILIZATION_MAX_PERCENT)
		if code == Population.MOB_OK:
			var reserved := scenario_pop.pending_mobilization(PLAYER)
			_expect(errors, reserved >= 1 and reserved <= workers, true, "con %d trabajadores se reservan %d" % [workers, reserved])
			_expect(errors, scenario_pop.available_workers(PLAYER), workers - reserved, "disponibles = trabajadores - reservados")
		else:
			_expect(errors, code, Population.MOB_ERR_NOTHING, "con %d trabajadores solo cabe 'nada que movilizar'" % workers)
	return errors


func _test_mobilization_no_double_count() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 60, "soldiers": 0}}, [CITY_A, CITY_B])
	var pop: Population = world["pop"]
	pop.set_new_soldier_percent(PLAYER, 50)
	_expect(errors, pop.start_mobilization(PLAYER, 50), Population.MOB_OK, "se reservan 30 de 60")
	_advance(world, 29)
	_expect(errors, _people(pop, PLAYER), [35, 33], "tick 29: 29 convertidos + 8 nacidos (4 y 4)")
	_expect(errors, pop.total_population(PLAYER), 68, "total = 60 + 8 nacidos")
	_expect(errors, [pop.pending_mobilization(PLAYER), pop.available_workers(PLAYER)], [1, 34], "queda 1 pendiente y no se cuenta como disponible")
	# Una segunda orden mientras hay una en curso se rechaza y no reserva a nadie más.
	_expect(errors, pop.start_mobilization(PLAYER, 10), Population.MOB_ERR_ACTIVE, "no hay dos movilizaciones a la vez")
	_expect(errors, [pop.pending_mobilization(PLAYER), pop.get_mobilization(PLAYER)["total"]], [1, 30], "la reserva sigue siendo la original")
	# Cambiar el porcentaje durante la movilización solo afecta a los nacidos a partir de ahora.
	pop.set_new_soldier_percent(PLAYER, 100)
	_advance(world, 1)
	_expect(errors, pop.get_mobilization(PLAYER)["active"], false, "la movilización terminó")
	_expect(errors, _people(pop, PLAYER), [34, 35], "el último convertido sale de trabajadores; el nacido nuevo, con el 100 % vigente, es soldado")
	_expect(errors, pop.total_population(PLAYER), 69, "la movilización no creó población: solo nació 1 persona")
	# Terminada, se puede ordenar otra, sobre los trabajadores actuales.
	_expect(errors, pop.start_mobilization(PLAYER, 50), Population.MOB_OK, "nueva orden tras terminar")
	_expect(errors, [pop.pending_mobilization(PLAYER), pop.available_workers(PLAYER)], [17, 17], "50 % de 34 trabajadores")
	_expect(errors, pop.get_maintenance(PLAYER)["in_deficit"], false, "sin déficit en todo el proceso")
	return errors


@warning_ignore("integer_division")
func _test_upkeep_cost() -> Array:
	var errors: Array = []
	var world := _make_maxed_world({PLAYER: {"workers": 150, "soldiers": 90}})
	var pop: Population = world["pop"]
	var economy: Economy = world["economy"]
	var cost: Dictionary = pop.get_maintenance(PLAYER)["cost_milli"]
	_expect(errors, [cost["workers"], cost["soldiers"], cost["total"]], [150 * Balance.WORKER_UPKEEP_MILLI, 90 * Balance.SOLDIER_UPKEEP_MILLI, 150 * Balance.WORKER_UPKEEP_MILLI + 90 * Balance.SOLDIER_UPKEEP_MILLI], "coste por tick en milésimas")
	var start := economy.get_resources(PLAYER)
	var income: int = EconomyBalance.RESOURCES_PER_TICK[EconomyBalance.MAX_LEVEL]
	# Hito 11: los trabajadores empleados (150 trabajadores, 140 puestos) también producen recursos.
	var employed := mini(150, Balance.JOBS_PER_LEVEL[EconomyBalance.MAX_LEVEL])
	_expect(errors, pop.employed(PLAYER), employed, "empleados = min(trabajadores, puestos)")
	_advance(world, 10)
	var produced_10: int = 10 * employed * Balance.WORKER_RESOURCES_MILLI / 1000
	_expect(errors, pop.get_stats(PLAYER)["worker_resources"], produced_10, "lo producido por los empleados en 10 ticks")
	# 10 ticks: 18.000 milésimas de trabajadores (18) y 22.500 de soldados (22, quedan 500 acumuladas).
	_expect(errors, economy.get_resources(PLAYER), start + 10 * income + produced_10 - 40, "10 ticks cuestan exactamente 40 recursos")
	_expect(errors, pop.get_stats(PLAYER)["upkeep_paid"], 40, "y se anotan como mantenimiento pagado")
	_advance(world, 10)
	var produced_20: int = 20 * employed * Balance.WORKER_RESOURCES_MILLI / 1000
	_expect(errors, economy.get_resources(PLAYER), start + 20 * income + produced_20 - 81, "20 ticks cuestan 36 + 45 = 81: el redondeo no se acumula")
	_expect(errors, [pop.get_maintenance(PLAYER)["in_deficit"], pop.get_maintenance(PLAYER)["debt"]["total"]], [false, 0], "sin déficit ni deuda")
	_expect(errors, _people(pop, PLAYER), [150, 90], "pagar no cambia la población")
	# Sin población no hay coste.
	var empty := _make_world({})
	var empty_pop: Population = empty["pop"]
	empty["economy"].add(PLAYER, 0, 10)
	_advance(empty, 5)
	_expect(errors, [empty_pop.get_maintenance(PLAYER)["cost_milli"]["total"], empty["economy"].get_resources(PLAYER)], [0, 15], "sin población no se gasta nada (solo suma la producción)")
	return errors


func _test_maintenance_priority() -> Array:
	var errors: Array = []
	_expect(errors, Population.MAINT_WORKERS_FIRST != Population.MAINT_SOLDIERS_FIRST, true, "las dos prioridades son distintas")
	# 250 trabajadores cuestan 3 recursos por tick y 40 soldados, 1. Hay justo 3 recursos y ninguna producción.
	for soldiers_first in [false, true]:
		var world := _make_world({AI_1: {"workers": 250, "soldiers": 40}})
		var pop: Population = world["pop"]
		var economy: Economy = world["economy"]
		economy.add(AI_1, 0, 3)
		var priority := Population.MAINT_SOLDIERS_FIRST if soldiers_first else Population.MAINT_WORKERS_FIRST
		_expect(errors, pop.set_maintenance_priority(AI_1, priority), true, "prioridad aceptada")
		_expect(errors, pop.maintenance_priority(AI_1), priority, "prioridad guardada")
		_advance(world, 1)
		var state := pop.get_maintenance(AI_1)
		_expect(errors, economy.get_resources(AI_1), 0, "se gastaron los 3 recursos y ninguno más")
		if soldiers_first:
			_expect(errors, [state["workers_covered"], state["soldiers_covered"]], [false, true], "primero cobran los soldados")
			_expect(errors, [state["debt"]["workers"], state["debt"]["soldiers"]], [1, 0], "a los trabajadores les falta 1")
		else:
			_expect(errors, [state["workers_covered"], state["soldiers_covered"]], [true, false], "primero cobran los trabajadores")
			_expect(errors, [state["debt"]["workers"], state["debt"]["soldiers"]], [0, 1], "a los soldados les falta 1")
		_expect(errors, state["stage"], Population.STAGE_SHORTAGE, "déficit en su primera etapa")
	var one := _make_world({})
	_expect(errors, one["pop"].set_maintenance_priority(PLAYER, 2), false, "valor de prioridad inválido rechazado")
	_expect(errors, one["pop"].set_maintenance_priority(99, Population.MAINT_SOLDIERS_FIRST), false, "nación inexistente rechazada")
	_expect(errors, one["pop"].maintenance_priority(PLAYER), Population.MAINT_WORKERS_FIRST, "por defecto cobran primero los trabajadores")
	# A largo plazo, con una producción insuficiente, el grupo sin prioridad es el que pierde gente. Desde el
	# hito 11 los 30 trabajadores empleados aportan 0,9 recursos/tick: hacen falta 60 soldados (no 40) para que
	# el coste (0,6 + 1,5) supere la producción (1 + 0,9).
	for soldiers_first in [false, true]:
		var world := _make_world({PLAYER: {"workers": 50, "soldiers": 60}})
		var pop: Population = world["pop"]
		pop.set_maintenance_priority(PLAYER, Population.MAINT_SOLDIERS_FIRST if soldiers_first else Population.MAINT_WORKERS_FIRST)
		_advance(world, 30)
		if soldiers_first:
			_expect(errors, pop.soldiers(PLAYER), 60, "prioridad ejército: los soldados no pierden a nadie")
			_expect(errors, pop.workers(PLAYER) < 50, true, "prioridad ejército: los trabajadores sí")
		else:
			_expect(errors, pop.workers(PLAYER), 50, "prioridad economía: los trabajadores no pierden a nadie")
			_expect(errors, pop.soldiers(PLAYER) < 60, true, "prioridad economía: los soldados sí")
	return errors


func _test_deficit_gradual() -> Array:
	var errors: Array = []
	var grace := Balance.DEFICIT_GRACE_TICKS
	# Sin ciudades ni recursos: cada tick se deben 3 recursos de trabajadores y 1 de soldados.
	var world := _make_world({AI_1: {"workers": 250, "soldiers": 40}})
	var pop: Population = world["pop"]
	var economy: Economy = world["economy"]
	_expect(errors, grace, 5, "el escenario está calculado para 5 ticks de gracia")
	for tick in range(1, grace + 1):
		_advance(world, 1)
		_expect(errors, _people(pop, AI_1), [250, 40], "dentro del plazo de gracia (tick %d) nadie se pierde" % tick)
		_expect(errors, pop.get_maintenance(AI_1)["stage"], Population.STAGE_SHORTAGE, "tick %d: déficit sin pérdidas" % tick)
	_expect(errors, pop.get_summary(AI_1)["growth_milli"], 0, "mientras hay déficit no hay crecimiento")
	_advance(world, 1)
	_expect(errors, _people(pop, AI_1), [248, 39], "tick 6: pierden 1 % (mín. 1): 2 trabajadores y 1 soldado")
	_expect(errors, pop.get_maintenance(AI_1)["stage"], Population.STAGE_ATTRITION, "etapa de pérdidas")
	_advance(world, 1)
	_expect(errors, _people(pop, AI_1), [246, 38], "tick 7: sigue gradual")
	_expect(errors, economy.get_resources(AI_1), 0, "el saldo no se volvió negativo")
	var debt: Dictionary = pop.get_maintenance(AI_1)["debt"]
	_expect(errors, [debt["workers"], debt["soldiers"]], [9, 3], "la deuda está limitada a %d ticks de coste" % Balance.DEFICIT_DEBT_LIMIT_TICKS)
	_advance(world, 13)
	var total := pop.total_population(AI_1)
	_expect(errors, total > 145, true, "tras 20 ticks aún queda más de la mitad de la población (%d)" % total)
	_expect(errors, total < 290, true, "pero ya ha bajado")
	# Recuperación: al volver los recursos se salda la deuda, cesan las pérdidas y se reanuda lo normal.
	economy.add(AI_1, 0, 1000)
	_advance(world, 1)
	var recovered := pop.get_maintenance(AI_1)
	_expect(errors, [recovered["in_deficit"], recovered["debt"]["total"]], [false, 0], "con recursos, el déficit termina")
	var people := _people(pop, AI_1)
	_advance(world, 10)
	_expect(errors, _people(pop, AI_1), people, "ya no se pierde a nadie")
	_expect(errors, economy.get_resources(AI_1) >= 0 and economy.get_resources(AI_1) < 1000, true, "el mantenimiento vuelve a pagarse del saldo")
	return errors


func _test_deficit_with_mobilization() -> Array:
	var errors: Array = []
	var world := _make_world({AI_1: {"workers": 250, "soldiers": 40}})
	var pop: Population = world["pop"]
	var economy: Economy = world["economy"]
	_expect(errors, pop.start_mobilization(AI_1, 50), Population.MOB_OK, "se reservan 125")
	var previous_total := 290
	for tick in range(1, 41):
		_advance(world, 1)
		var total := pop.total_population(AI_1)
		if total > previous_total:
			errors.append("la población creció en el tick %d (%d -> %d)" % [tick, previous_total, total])
		if tick <= Balance.DEFICIT_GRACE_TICKS and total != 290:
			errors.append("hubo pérdidas dentro del plazo de gracia (tick %d)" % tick)
		previous_total = total
		if pop.pending_mobilization(AI_1) > pop.workers(AI_1) or pop.pending_mobilization(AI_1) < 0:
			errors.append("la reserva (%d) supera a los trabajadores (%d) en el tick %d" % [pop.pending_mobilization(AI_1), pop.workers(AI_1), tick])
		if pop.workers(AI_1) < 0 or pop.soldiers(AI_1) < 0 or economy.get_resources(AI_1) < 0:
			errors.append("valor negativo en el tick %d" % tick)
	_expect(errors, pop.get_mobilization(AI_1)["active"], false, "la movilización terminó")
	_expect(errors, pop.soldiers(AI_1) > 40, true, "se convirtieron trabajadores en soldados pese al déficit")
	return errors


func _test_deficit_recovers() -> Array:
	var errors: Array = []
	# Una ciudad (1 recurso/tick, más 0,9 de sus 30 empleados desde el hito 11) no puede mantener 40 + 60:
	# hay déficit hasta que se pierden soldados y sube de nivel; después se estabiliza y vuelve a crecer.
	var world := _make_world({PLAYER: {"workers": 40, "soldiers": 60}})
	var control := _make_world({PLAYER: {"workers": 40, "soldiers": 60}})
	var pop: Population = world["pop"]
	var economy: Economy = world["economy"]
	var seen_deficit := false
	var last_deficit_tick := 0
	var population_at_100 := 0
	for tick in range(1, 201):
		var was_in_deficit: bool = pop.get_maintenance(PLAYER)["in_deficit"]
		var before := pop.total_population(PLAYER)
		_advance(world, 1)
		if was_in_deficit and pop.total_population(PLAYER) > before:
			errors.append("creció durante el déficit (tick %d)" % tick)
		if pop.get_maintenance(PLAYER)["in_deficit"]:
			seen_deficit = true
			last_deficit_tick = tick
		if economy.get_resources(PLAYER) < 0:
			errors.append("saldo de recursos negativo en el tick %d" % tick)
		if tick == 100:
			population_at_100 = pop.total_population(PLAYER)
	_advance(control, 200)
	_expect(errors, seen_deficit, true, "el escenario entra en déficit")
	_expect(errors, last_deficit_tick < 100, true, "el déficit se corrige solo antes del tick 100 (último: %d)" % last_deficit_tick)
	_expect(errors, pop.total_population(PLAYER) > population_at_100, true, "después de corregirse, la población vuelve a crecer")
	_expect(errors, pop.workers(PLAYER) > 0 and pop.soldiers(PLAYER) > 0, true, "quedan trabajadores y soldados")
	_expect(errors, economy.get_money(PLAYER), control["economy"].get_money(PLAYER), "el déficit de recursos no toca el dinero")
	return errors


func _test_no_negative_balances() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var economy := Economy.new(grid.get_nation_ids())
	economy.add(PLAYER, 0, 10)
	_expect(errors, economy.spend_resources(PLAYER, 11), false, "no se puede gastar más de lo que hay")
	_expect(errors, economy.spend_resources(PLAYER, -1), false, "cantidad negativa rechazada")
	_expect(errors, economy.spend_resources(99, 1), false, "nación inexistente rechazada")
	_expect(errors, economy.get_resources(PLAYER), 10, "los rechazos no cambian el saldo")
	_signal_count = 0
	economy.balances_changed.connect(_count_signal)
	_expect(errors, economy.spend_resources(PLAYER, 0), true, "gastar 0 es válido")
	_expect(errors, _signal_count, 0, "gastar 0 no avisa")
	_expect(errors, economy.spend_resources(PLAYER, 4), true, "gasto válido")
	_expect(errors, [economy.get_resources(PLAYER), _signal_count], [6, 1], "descuenta y avisa una vez")
	_expect(errors, economy.spend_resources(PLAYER, 6), true, "se puede gastar exactamente el saldo")
	_expect(errors, economy.get_resources(PLAYER), 0, "queda en 0, nunca en negativo")
	_expect(errors, economy.get_money(PLAYER), EconomyBalance.INITIAL_MONEY, "el dinero no se toca")
	economy.balances_changed.disconnect(_count_signal)
	# Mantenimiento enorme contra producción mínima, durante mucho tiempo, con cualquier reparto.
	var world := _make_world({PLAYER: {"workers": 500, "soldiers": 400}, AI_1: {"workers": 300, "soldiers": 300}})
	var pop: Population = world["pop"]
	for tick in 150:
		_advance(world, 1)
		for nation_id: int in [PLAYER, AI_1]:
			if world["economy"].get_resources(nation_id) < 0 or world["economy"].get_money(nation_id) < 0:
				errors.append("saldo negativo (nación %d, tick %d)" % [nation_id, tick])
			if pop.workers(nation_id) < 0 or pop.soldiers(nation_id) < 0:
				errors.append("población negativa (nación %d, tick %d)" % [nation_id, tick])
	_expect(errors, pop.total_population(PLAYER) > 0, true, "aun con un déficit enorme la población no desaparece de golpe")
	return errors


func _test_default_play_sustainable() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var economy := Economy.new(grid.get_nation_ids())
	var cities := CityManager.new(grid, economy)
	cities.place_initial_cities()
	var pop := Population.new(cities, economy, grid.get_nation_ids())
	# El jugador reparte mitad y mitad la población nueva y moviliza el 25 % cada 40 ticks.
	pop.set_new_soldier_percent(PLAYER, 50)
	var ever_in_deficit := false
	for tick in range(1, 601):
		if tick % 40 == 1:
			pop.start_mobilization(PLAYER, 25)
		cities.advance(1.0)
		for nation_id: int in grid.get_nation_ids():
			if pop.get_maintenance(nation_id)["in_deficit"]:
				ever_in_deficit = true
			if pop.total_population(nation_id) > pop.capacity(nation_id):
				errors.append("población por encima de la capacidad (nación %d, tick %d)" % [nation_id, tick])
	_expect(errors, ever_in_deficit, false, "con los valores iniciales no se entra en déficit")
	for nation_id: int in grid.get_nation_ids():
		_expect(errors, pop.total_population(nation_id) > Balance.INITIAL_POPULATION[nation_id]["workers"], true, "la nación %d ha crecido" % nation_id)
	_expect(errors, pop.soldiers(PLAYER) > pop.soldiers(AI_1), true, "el jugador, que recluta, tiene más soldados que una IA pasiva")
	return errors


func _test_previous_behavior_kept() -> Array:
	var errors: Array = []
	var with_pop := _make_world({PLAYER: {"workers": 30, "soldiers": 6}, AI_1: {"workers": 30, "soldiers": 6}}, [CITY_A, CITY_B])
	# Mundo de control: exactamente igual pero sin población.
	var grid := _make_grid()
	var economy := Economy.new(grid.get_nation_ids())
	var cities := CityManager.new(grid, economy)
	economy.add(PLAYER, 1000, 0)
	cities.found_city(PLAYER, CITY_A)
	cities.found_city(PLAYER, CITY_B)
	var owners_before := grid.copy_owner_data()
	var terrain_before := grid.copy_terrain_data()
	_signal_count = 0
	with_pop["grid"].ownership_changed.connect(_count_signal)
	_tick_count = 0
	with_pop["cities"].ticked.connect(_count_tick)
	var pop: Population = with_pop["pop"]
	pop.start_mobilization(PLAYER, 50)
	# (La prioridad de crecimiento, que desde el hito 11 cuesta dinero y acelera el nivel, se prueba aparte.)
	pop.set_maintenance_priority(PLAYER, Population.MAINT_SOLDIERS_FIRST)
	_advance(with_pop, 100)
	cities.advance(100.0)
	_expect(errors, _tick_count, 100, "cada tick de ciudades emite ticked una vez")
	_expect(errors, _signal_count, 0, "población y economía no emiten ownership_changed")
	# Hito 11: la población solo añade lo que producen sus trabajadores empleados y resta su mantenimiento.
	for nation_id: int in grid.get_nation_ids():
		var stats: Dictionary = pop.get_stats(nation_id)
		_expect(errors, with_pop["economy"].get_money(nation_id), economy.get_money(nation_id) + stats["worker_money"] - stats["priority_paid"], "dinero = el de las ciudades + lo de los trabajadores (nación %d)" % nation_id)
		_expect(errors, with_pop["economy"].get_resources(nation_id), economy.get_resources(nation_id) + stats["worker_resources"] - stats["upkeep_paid"], "recursos = ciudades + trabajadores - mantenimiento (nación %d)" % nation_id)
	_expect(errors, pop.get_stats(PLAYER)["worker_money"] > 0, true, "los trabajadores del jugador produjeron")
	_expect(errors, with_pop["economy"].get_resources(PLAYER) >= 0, true, "y nunca negativos")
	for city_id: int in cities.get_city_ids():
		var a: Dictionary = with_pop["cities"].get_city(city_id)
		var b: Dictionary = cities.get_city(city_id)
		_expect(errors, [a["level"], a["progress"], a["owner"], a["cell"]], [b["level"], b["progress"], b["owner"], b["cell"]], "ciudad %d igual con y sin población" % city_id)
	_expect(errors, with_pop["grid"].copy_owner_data() == owners_before, true, "propietarios intactos")
	_expect(errors, with_pop["grid"].copy_terrain_data() == terrain_before, true, "terreno intacto")
	_expect(errors, with_pop["cities"].income_for(PLAYER), cities.income_for(PLAYER), "misma producción")
	with_pop["cities"].ticked.disconnect(_count_tick)
	return errors


func _test_ui_texts() -> Array:
	var errors: Array = []
	_expect(errors, PopulationPanel.summary_text({"total": 36, "workers": 30, "soldiers": 6}), "Población 36\nTrabajadores 30\nSoldados 6", "resumen")
	_expect(errors, PopulationPanel.split_text(20), "Trab. 80 % · Sold. 20 %", "reparto 20 %")
	_expect(errors, PopulationPanel.split_text(0), "Trab. 100 % · Sold. 0 %", "reparto 0 %")
	_expect(errors, PopulationPanel.split_text(100), "Trab. 0 % · Sold. 100 %", "reparto 100 %")
	for percent in range(0, 101, 5):
		var text := PopulationPanel.split_text(percent)
		if not text.contains("%d %%" % percent) or not text.contains("%d %%" % (100 - percent)):
			errors.append("el texto del reparto no muestra %d / %d: '%s'" % [percent, 100 - percent, text])
	_expect(errors, [PopulationPanel.format_milli_rate(0), PopulationPanel.format_milli_rate(1000), PopulationPanel.format_milli_rate(150), PopulationPanel.format_milli_rate(510), PopulationPanel.format_milli_rate(5000)], ["0", "1", "0,15", "0,51", "5"], "formato de tasas por segundo")
	_expect(errors, PopulationPanel.mobilization_button_text(25), "Movilizar 25 %", "texto del botón")
	_expect(errors, PopulationPanel.maintenance_priority_text(Population.MAINT_WORKERS_FIRST), "Cobra 1.º: Economía", "prioridad economía")
	_expect(errors, PopulationPanel.maintenance_priority_text(Population.MAINT_SOLDIERS_FIRST), "Cobra 1.º: Ejército", "prioridad ejército")
	# Con datos reales.
	var world := _make_maxed_world({PLAYER: {"workers": 200, "soldiers": 40}})
	var pop: Population = world["pop"]
	_expect(errors, PopulationPanel.mobilization_text(pop.get_mobilization(PLAYER)), "Sin movilización", "sin movilización")
	pop.start_mobilization(PLAYER, 50)
	_advance(world, 15)
	_expect(errors, PopulationPanel.mobilization_text(pop.get_mobilization(PLAYER)), "Movilizando 50/100 (50 %)\nPendientes: 50", "movilización a mitad")
	var summary := pop.get_summary(PLAYER)
	var maintenance := pop.get_maintenance(PLAYER)
	_expect(errors, PopulationPanel.growth_text(summary, maintenance), "Población al máximo (240)", "al máximo")
	_expect(errors, PopulationPanel.maintenance_text(maintenance, 5).ends_with("Suficiente"), true, "mantenimiento suficiente")
	_expect(errors, PopulationPanel.deficit_text(maintenance), "", "sin aviso de déficit")
	var growing := _make_world({PLAYER: {"workers": 10, "soldiers": 0}})
	var growing_pop: Population = growing["pop"]
	_expect(errors, PopulationPanel.growth_text(growing_pop.get_summary(PLAYER), growing_pop.get_maintenance(PLAYER)), "Crece +0,15/s · máx. 50", "crecimiento")
	_expect(errors, PopulationPanel.growth_text(growing_pop.get_summary(AI_1), growing_pop.get_maintenance(AI_1)), "Sin ciudades: no crece", "sin ciudades")
	# Déficit en sus dos etapas.
	var deficit := _make_world({AI_1: {"workers": 250, "soldiers": 40}})
	var deficit_pop: Population = deficit["pop"]
	_advance(deficit, 1)
	var stage_one := deficit_pop.get_maintenance(AI_1)
	_expect(errors, PopulationPanel.deficit_text(stage_one), "Déficit: sin recursos para trabajadores y soldados. Sin crecimiento.", "déficit sin pérdidas")
	_expect(errors, PopulationPanel.maintenance_text(stage_one, 0).ends_with("INSUFICIENTE"), true, "mantenimiento insuficiente")
	_expect(errors, PopulationPanel.growth_text(deficit_pop.get_summary(AI_1), stage_one), "Crecimiento detenido por el déficit", "crecimiento detenido")
	_advance(deficit, Balance.DEFICIT_GRACE_TICKS)
	_expect(errors, PopulationPanel.deficit_text(deficit_pop.get_maintenance(AI_1)), "Déficit grave: pierden población los trabajadores y soldados.", "déficit con pérdidas")
	# El texto de la ciudad con prioridad.
	var priority_world := _make_world({PLAYER: {"workers": 10, "soldiers": 0}})
	var priority_pop: Population = priority_world["pop"]
	_expect(errors, InfoPanel.priority_text(priority_pop, 1), "Prioridad de población · +0,15/s", "texto de la prioridad")
	priority_pop.set_city_priority(PLAYER, 1, true)
	_expect(errors, InfoPanel.priority_text(priority_pop, 1), "Prioridad de población · +0,30/s", "con prioridad, aporte doble")
	return errors


func _find_cell_of_owner_city(cities: CityManager, nation_id: int) -> Array:
	for city_id: int in cities.get_city_ids():
		if cities.get_owner(city_id) == nation_id:
			return [city_id, cities.get_city(city_id)["cell"]]
	return [CityManager.NO_CITY, Vector2i(-1, -1)]


func _test_screen() -> Array:
	var errors: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	var scene: PackedScene = load(SCREEN_PATH)
	_expect(errors, scene != null, true, "la escena %s carga" % SCREEN_PATH)
	if scene == null:
		return errors
	var screen: Screen = scene.instantiate()
	tree.root.add_child(screen)
	screen.ai.enabled = false  # sin decisiones de la IA estratégica (hito 11): escenario controlado
	var grid: TerritoryGrid = screen.grid
	var economy: Economy = screen.economy
	var cities: CityManager = screen.cities
	var pop: Population = screen.population
	var panel: PopulationPanel = screen.get_node("%Poblacion")
	var info: InfoPanel = screen.get_node("%Info")
	var view = screen.get_node("%Mapa")
	_expect(errors, pop != null, true, "la pantalla crea la población")
	if pop == null or panel == null:
		screen.free()
		return errors
	var start: Dictionary = Balance.INITIAL_POPULATION[PLAYER]
	var summary_label: Label = panel.find_child("Resumen", true, false)
	var split_label: Label = panel.find_child("ReparteNueva", true, false)
	var mob_label: Label = panel.find_child("EstadoMovilizacion", true, false)
	var maint_label: Label = panel.find_child("EstadoMantenimiento", true, false)
	var deficit_label: Label = panel.find_child("Deficit", true, false)
	var split_slider: HSlider = panel.find_child("SliderNueva", true, false)
	var mob_slider: HSlider = panel.find_child("SliderMovilizacion", true, false)
	var mob_button: Button = panel.find_child("BotonMovilizar", true, false)
	var maint_button: Button = panel.find_child("BotonPrioridadMantenimiento", true, false)
	for node: Node in [summary_label, split_label, mob_label, maint_label, deficit_label, split_slider, mob_slider, mob_button, maint_button]:
		_expect(errors, node != null, true, "el panel tiene todos sus controles")
		if node == null:
			screen.free()
			return errors
	# Los textos salen de los datos reales.
	_expect(errors, summary_label.text, PopulationPanel.summary_text(pop.get_summary(PLAYER)), "resumen desde los datos")
	_expect(errors, summary_label.text.contains("Población %d" % (start["workers"] + start["soldiers"])), true, "población inicial visible")
	_expect(errors, [split_slider.value, split_label.text], [float(Balance.INITIAL_NEW_SOLDIER_PERCENT), PopulationPanel.split_text(Balance.INITIAL_NEW_SOLDIER_PERCENT)], "reparto inicial visible")
	_expect(errors, [mob_label.text, mob_button.disabled], ["Sin movilización", false], "sin movilización")
	_expect(errors, deficit_label.visible, false, "sin aviso de déficit")
	# Control de reparto: actúa sobre los datos y no reasigna a los existentes.
	split_slider.value = 70
	_expect(errors, [pop.new_soldier_percent(PLAYER), pop.new_worker_percent(PLAYER)], [70, 30], "el deslizador fija el reparto")
	_expect(errors, [pop.workers(PLAYER), pop.soldiers(PLAYER)], [start["workers"], start["soldiers"]], "sin reasignar a los existentes")
	_expect(errors, split_label.text, PopulationPanel.split_text(70), "el reparto elegido se muestra")
	# Movilización desde la interfaz.
	_expect(errors, mob_button.text, PopulationPanel.mobilization_button_text(25), "el botón muestra el porcentaje por defecto")
	mob_slider.value = 50
	_expect(errors, mob_button.text, PopulationPanel.mobilization_button_text(50), "el botón sigue al deslizador")
	mob_slider.value = 25
	var money_before := economy.get_money(PLAYER)
	var owners_before := grid.copy_owner_data()
	mob_button.pressed.emit()
	var reserved := floori(start["workers"] * 25 / 100.0)
	_expect(errors, pop.get_mobilization(PLAYER)["total"], reserved, "se reservó el 25 % de los trabajadores")
	_expect(errors, [mob_button.disabled, mob_label.text], [true, PopulationPanel.mobilization_text(pop.get_mobilization(PLAYER))], "la interfaz refleja la movilización")
	_expect(errors, pop.start_mobilization(PLAYER, 10), Population.MOB_ERR_ACTIVE, "no admite otra movilización a la vez")
	cities.advance(float(Balance.MOBILIZATION_TICKS))
	_expect(errors, [pop.get_mobilization(PLAYER)["active"], mob_button.disabled], [false, false], "al terminar se puede movilizar de nuevo")
	_expect(errors, pop.soldiers(PLAYER) >= start["soldiers"] + reserved, true, "los trabajadores reservados son ahora soldados")
	_expect(errors, summary_label.text, PopulationPanel.summary_text(pop.get_summary(PLAYER)), "el resumen se actualizó con el tiempo")
	_expect(errors, economy.get_money(PLAYER) > money_before, true, "la economía siguió produciendo")
	# Prioridad de mantenimiento.
	_expect(errors, maint_button.text, PopulationPanel.maintenance_priority_text(Population.MAINT_WORKERS_FIRST), "prioridad inicial")
	maint_button.pressed.emit()
	_expect(errors, [pop.maintenance_priority(PLAYER), maint_button.text], [Population.MAINT_SOLDIERS_FIRST, PopulationPanel.maintenance_priority_text(Population.MAINT_SOLDIERS_FIRST)], "el botón cambia la prioridad real")
	maint_button.pressed.emit()
	_expect(errors, pop.maintenance_priority(PLAYER), Population.MAINT_WORKERS_FIRST, "y la vuelve a cambiar")
	_expect(errors, maint_label.text.contains("Suficiente"), true, "mantenimiento suficiente visible")
	# Prioridad de crecimiento de una ciudad desde el panel de información.
	var player_city := _find_cell_of_owner_city(cities, PLAYER)
	var ai_city := _find_cell_of_owner_city(cities, AI_1)
	var toggle := info.priority_toggle()
	_expect(errors, toggle != null and not toggle.visible, true, "sin selección no hay control de prioridad")
	view.pointer_pressed(view.cell_center_global(player_city[1]))
	_expect(errors, [toggle.visible, toggle.button_pressed], [true, false], "ciudad propia: control visible y desactivado")
	_expect(errors, toggle.text, InfoPanel.priority_text(pop, player_city[0]), "el control muestra el aporte de la ciudad")
	toggle.button_pressed = true
	_expect(errors, pop.is_city_priority(player_city[0]), true, "el control activa la prioridad real")
	cities.advance(1.0)
	_expect(errors, [toggle.visible, toggle.button_pressed], [true, true], "el estado se lee de los datos tras un tick")
	_expect(errors, toggle.text, InfoPanel.priority_text(pop, player_city[0]), "el aporte mostrado refleja la prioridad")
	toggle.button_pressed = false
	_expect(errors, pop.is_city_priority(player_city[0]), false, "y se puede desactivar")
	view.pointer_pressed(view.cell_center_global(ai_city[1]))
	_expect(errors, toggle.visible, false, "una ciudad ajena no ofrece el control")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ningún control cambió el territorio")
	screen.free()
	return errors


func _test_files_present() -> Array:
	var errors: Array = []
	for path: String in ["res://tests/territory_grid_tests.gd", "res://tests/territory_map_view_tests.gd",
			"res://tests/territory_conquest_tests.gd", "res://tests/territory_hud_tests.gd",
			"res://tests/city_economy_tests.gd", "res://tests/run_territory_tests.tscn",
			"res://tests/run_view_tests.tscn", "res://tests/run_conquest_tests.tscn",
			"res://tests/run_hud_tests.tscn", "res://tests/run_city_tests.tscn",
			"res://tests/test_population.gd", "res://tests/run_population_tests.tscn",
			"res://scripts/world/population.gd", "res://scripts/ui/population_panel.gd",
			"res://scripts/data/population_balance.gd", "res://tests/test_province_data.gd",
			"res://tests/test_province_selection.gd"]:
		_expect(errors, FileAccess.file_exists(path), true, "existe " + path)
	return errors
