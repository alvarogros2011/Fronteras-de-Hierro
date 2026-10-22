## Pruebas automáticas del hito 11 (reforma de jugabilidad): economía con trabajadores productivos, prioridad
## con coste, desmovilización y recuperación del déficit, frente ancho, expansión que no ataca, liberación,
## defensa sin las tropas atacantes, bonificación de ciudad, IA estratégica (defensa, ataque, treguas,
## diplomacia), tratados con el frente ancho, pausa y determinismo. Sin plugins.
##
## Única definición de las comprobaciones; la usan:
##   - tests/test_gameplay.gd (consola, headless):
##       godot --headless --path . --script res://tests/test_gameplay.gd
##   - tests/run_gameplay_tests.tscn (editor de Godot, F6).
##
## Mapas controlados (load_from_data), salvo las pruebas que dicen usar el mapa por defecto. El tiempo avanza
## con CityManager.advance(n): n ticks exactos de 1 s de juego, sin esperas reales ni azar.
##   - Mapa de duelo: tierra x 10..39, y 10..29; jugador x 10..24, IA 1 x 25..34, sin reclamar x 35..39.
##   - Mapa abierto: tierra x 10..39, y 10..29; jugador x 10..14; el resto sin reclamar.
## Los números de los escenarios de economía se calcularon con una réplica en Python de las fórmulas (que no
## es una prueba de Godot ni la sustituye).
##
## run_all() devuelve [{"name": String, "errors": Array}, ...]   (errors vacío = PASS)
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
const AIController := preload("res://scripts/world/ai_controller.gd")
const Combat := preload("res://scripts/world/combat.gd")
const CombatBalance := preload("res://scripts/data/combat_balance.gd")
const PopulationBalance := preload("res://scripts/data/population_balance.gd")
const EconomyBalance := preload("res://scripts/data/economy_balance.gd")
const DiplomacyBalance := preload("res://scripts/data/diplomacy_balance.gd")
const AIBalance := preload("res://scripts/data/ai_balance.gd")
const MilitaryPanel := preload("res://scripts/ui/military_panel.gd")
const PopulationPanel := preload("res://scripts/ui/population_panel.gd")
const Screen := preload("res://scripts/ui/territory_screen.gd")

const PLAYER := TerritoryGrid.OWNER_PLAYER
const AI_1 := TerritoryGrid.OWNER_AI_1
const AI_2 := TerritoryGrid.OWNER_AI_2
const CITY_A := Vector2i(12, 12)
const BORDER := Vector2i(24, 15)
const INTERVAL := CombatBalance.ADVANCE_INTERVAL_TICKS

var _results: Array = []
var _signal_cells: Array = []
var _events: Array = []


func run_all() -> Array:
	_results = []
	_run("GP-01 los trabajadores empleados producen, con techo en los puestos; una ciudad ocupada no da trabajo", _test_workers_produce)
	_run("GP-02 un déficit por exceso de soldados se corrige desmovilizando, sin negativos", _test_deficit_recovery)
	_run("GP-03 la prioridad de crecimiento cuesta dinero y sin dinero no actúa", _test_priority_cost)
	_run("GP-04 frente ancho: la expansión toma una franja por avance, sin saltos y se detiene en el agua", _test_wide_expansion)
	_run("GP-05 una expansión que toca otra nación se detiene sin declarar la guerra", _test_expansion_contact)
	_run("GP-06 combate con frente ancho: un enfrentamiento por avance y la previsión coincide con el resultado", _test_wide_combat)
	_run("GP-07 los soldados que atacan no defienden", _test_defense_without_attackers)
	_run("GP-08 una ciudad refuerza la defensa de su entorno", _test_city_defense)
	_run("GP-09 liberar una celda propia ocupada combate al ocupante y no cambia la propiedad", _test_liberation)
	_run("GP-10 IA defensiva: retira su expansión para defenderse sin crear soldados", _test_ai_defends)
	_run("GP-11 IA ofensiva: ataca en guerra solo con previsión de victoria", _test_ai_attacks)
	_run("GP-12 IA y treguas: no declara la guerra con tregua; sin tregua, sí", _test_ai_truce)
	_run("GP-13 IA y diplomacia: dos IA en guerra hacen la paz cuando les compensa", _test_ai_peace)
	_run("GP-14 tratados con el frente ancho: oferta fallida sin cambios, paz con conquistas y tregua", _test_treaty_wave)
	_run("GP-15 partida por defecto con IA: el mapa evoluciona y nunca hay valores imposibles", _test_default_world_activity)
	_run("GP-16 la pausa también detiene a la IA", _test_pause_stops_ai)
	_run("GP-17 determinismo: dos partidas iguales con IA acaban igual", _test_determinism)
	_run("GP-18 frente sugerido, textos y avisos de la interfaz", _test_ui)
	_run("GP-19 las suites anteriores y los archivos del hito siguen presentes", _test_files_present)
	return _results


func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	_results.append({"name": test_name, "errors": errors})


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


func _collect_cells(cells: Array) -> void:
	_signal_cells.append_array(cells)


func _collect_event(text: String) -> void:
	_events.append(text)


# ---------------------------------------------------------------------------
# Datos controlados
# ---------------------------------------------------------------------------

## Tierra x 10..39, y 10..29. Jugador x 10..`player_last`; IA 1 x `ai_first`..34 (si ai_first <= 34);
## el resto sin reclamar. `water_x` (si >= 0) convierte en agua esa columna entera.
func _make_grid(player_last: int, ai_first: int, water_x: int = -1) -> TerritoryGrid:
	var terrain := PackedByteArray()
	terrain.resize(TerritoryGrid.CELL_COUNT)
	terrain.fill(TerritoryGrid.TERRAIN_WATER)
	var owners := PackedByteArray()
	owners.resize(TerritoryGrid.CELL_COUNT)
	owners.fill(TerritoryGrid.OWNER_NONE)
	for y in range(10, 30):
		for x in range(10, 40):
			if x == water_x:
				continue
			var index := y * TerritoryGrid.WIDTH + x
			terrain[index] = TerritoryGrid.TERRAIN_LAND
			if x <= player_last:
				owners[index] = PLAYER
			elif x >= ai_first and x <= 34:
				owners[index] = AI_1
	var grid := TerritoryGrid.new()
	grid.load_from_data(terrain, owners)
	return grid


func _duel_grid() -> TerritoryGrid:
	return _make_grid(24, 25)


func _open_grid(water_x: int = -1) -> TerritoryGrid:
	return _make_grid(14, 99, water_x)


## Mundo completo sobre una cuadrícula. `rich`: todas las naciones con muchos recursos (sin déficit). La IA
## estratégica se crea DESACTIVADA (las pruebas llaman a decide() cuando lo necesitan).
func _make_world(initial: Dictionary, grid: TerritoryGrid, rich: bool = true) -> Dictionary:
	var economy := Economy.new(grid.get_nation_ids())
	if rich:
		for nation_id: int in grid.get_nation_ids():
			economy.add(nation_id, 0, 100000)
	var cities := CityManager.new(grid, economy)
	var occupation := Occupation.new(grid)
	cities.set_occupation(occupation)
	var population := Population.new(cities, economy, grid.get_nation_ids(), initial)
	var military := Military.new(grid, population)
	var wars := WarState.new(cities)
	var offensives := Offensives.new(grid, population, military, cities, occupation, wars)
	var diplomacy := Diplomacy.new(grid, economy, cities, population, occupation, wars, offensives)
	var ai := AIController.new(grid, economy, cities, population, military, occupation, wars, offensives, diplomacy)
	ai.enabled = false
	return {"grid": grid, "economy": economy, "cities": cities, "pop": population, "mil": military,
			"occ": occupation, "wars": wars, "off": offensives, "dip": diplomacy, "ai": ai}


## La partida por defecto (mapa generado, ciudades iniciales y población inicial), como la pantalla, con
## la IA ACTIVADA.
func _default_world() -> Dictionary:
	var grid := TerritoryGrid.new()
	var occupation := Occupation.new(grid)
	var economy := Economy.new(grid.get_nation_ids())
	var cities := CityManager.new(grid, economy)
	cities.set_occupation(occupation)
	var wars := WarState.new(cities)
	cities.place_initial_cities()
	var population := Population.new(cities, economy, grid.get_nation_ids())
	var military := Military.new(grid, population)
	var offensives := Offensives.new(grid, population, military, cities, occupation, wars)
	var diplomacy := Diplomacy.new(grid, economy, cities, population, occupation, wars, offensives)
	var ai := AIController.new(grid, economy, cities, population, military, occupation, wars, offensives, diplomacy)
	return {"grid": grid, "economy": economy, "cities": cities, "pop": population, "mil": military,
			"occ": occupation, "wars": wars, "off": offensives, "dip": diplomacy, "ai": ai}


func _ticks(world: Dictionary, ticks: int) -> void:
	var cities: CityManager = world["cities"]
	cities.advance(float(ticks))


## Todo lo que debe ser reproducible, en un Dictionary comparable.
func _snapshot(world: Dictionary) -> Dictionary:
	var grid: TerritoryGrid = world["grid"]
	var pop: Population = world["pop"]
	var mil: Military = world["mil"]
	var occ: Occupation = world["occ"]
	var off: Offensives = world["off"]
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	var nations: Dictionary = {}
	for nation_id: int in grid.get_nation_ids():
		nations[nation_id] = [pop.workers(nation_id), pop.soldiers(nation_id), mil.assigned_soldiers(nation_id),
				economy.get_money(nation_id), economy.get_resources(nation_id), pop.new_soldier_percent(nation_id)]
	var sectors: Array = []
	for sector_id: int in mil.get_sector_ids():
		sectors.append([mil.get_sector(sector_id), off.get_offensive(sector_id)])
	var occupied: Array = []
	for cell: Vector2i in occ.get_cells():
		occupied.append([cell, occ.occupier_at(cell)])
	var city_data: Array = []
	for city_id: int in cities.get_city_ids():
		city_data.append(cities.get_city(city_id))
	return {"nations": nations, "sectors": sectors, "occupied": occupied, "cities": city_data,
			"wars": world["wars"].war_pairs(), "owners": grid.copy_owner_data()}


## ¿Toca la celda (ortogonalmente) territorio oficial de la nación?
func _touches(grid: TerritoryGrid, cell: Vector2i, nation_id: int) -> bool:
	for step: Vector2i in TerritoryGrid.ORTHOGONAL_STEPS:
		var neighbor := cell + step
		if grid.get_cell_owner(neighbor.x, neighbor.y) == nation_id:
			return true
	return false


# ---------------------------------------------------------------------------
# Economía
# ---------------------------------------------------------------------------

func _test_workers_produce() -> Array:
	var errors: Array = []
	_expect(errors, PopulationBalance.JOBS_PER_LEVEL.size(), EconomyBalance.MAX_LEVEL + 1, "una entrada de puestos por nivel")
	for level in range(1, EconomyBalance.MAX_LEVEL + 1):
		_expect(errors, PopulationBalance.JOBS_PER_LEVEL[level] < PopulationBalance.CAPACITY_PER_LEVEL[level], true, "nivel %d: menos puestos que capacidad" % level)
		# Un trabajador empleado produce más recursos de los que consume: trabajar compensa.
	_expect(errors, PopulationBalance.WORKER_RESOURCES_MILLI > PopulationBalance.WORKER_UPKEEP_MILLI, true, "un empleado produce más recursos de los que consume")
	# 30 trabajadores en una ciudad de nivel 1 (30 puestos).
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 0}}, _duel_grid(), false)
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	var pop: Population = world["pop"]
	economy.add(PLAYER, 1000, 0)
	cities.found_city(PLAYER, CITY_A)
	_expect(errors, [pop.jobs(PLAYER), pop.employed(PLAYER)], [30, 30], "30 puestos y 30 empleados")
	_expect(errors, pop.worker_output_milli(PLAYER), {"money": 30 * PopulationBalance.WORKER_MONEY_MILLI, "resources": 30 * PopulationBalance.WORKER_RESOURCES_MILLI}, "producción por tick en milésimas")
	_ticks(world, 10)
	_expect(errors, [pop.get_stats(PLAYER)["worker_money"], pop.get_stats(PLAYER)["worker_resources"]], [12, 9], "10 ticks: 12 de dinero y 9 de recursos de los trabajadores")
	# Con el doble de trabajadores y los mismos puestos se produce lo mismo: la producción tiene techo.
	var crowded := _make_world({PLAYER: {"workers": 60, "soldiers": 0}}, _duel_grid(), false)
	crowded["economy"].add(PLAYER, 1000, 0)
	crowded["cities"].found_city(PLAYER, CITY_A)
	_expect(errors, [crowded["pop"].employed(PLAYER), crowded["pop"].get_summary(PLAYER)["jobs"]], [30, 30], "60 trabajadores: solo 30 empleados")
	_ticks(crowded, 10)
	_expect(errors, [crowded["pop"].get_stats(PLAYER)["worker_money"], crowded["pop"].get_stats(PLAYER)["worker_resources"]], [12, 9], "sin más puestos no se produce más")
	_expect(errors, crowded["pop"].get_stats(PLAYER)["upkeep_paid"] > pop.get_stats(PLAYER)["upkeep_paid"], true, "pero los desempleados sí consumen")
	# Una ciudad de nivel mayor da más puestos.
	cities.advance(float(EconomyBalance.GROWTH_TO_NEXT[1]))
	_expect(errors, pop.jobs(PLAYER), PopulationBalance.JOBS_PER_LEVEL[2], "al subir de nivel aumentan los puestos")
	# Una ciudad ocupada no da trabajo: sus trabajadores dejan de producir.
	var occupied := _make_world({PLAYER: {"workers": 30, "soldiers": 0}}, _duel_grid(), false)
	occupied["economy"].add(PLAYER, 1000, 0)
	occupied["cities"].found_city(PLAYER, CITY_A)
	_expect(errors, occupied["occ"].occupy(AI_1, CITY_A), Occupation.OCC_OK, "la IA 1 ocupa el centro de la ciudad")
	_expect(errors, [occupied["pop"].jobs(PLAYER), occupied["pop"].employed(PLAYER)], [0, 0], "ciudad ocupada: sin puestos")
	_ticks(occupied, 10)
	_expect(errors, [occupied["pop"].get_stats(PLAYER)["worker_money"], occupied["pop"].get_stats(PLAYER)["worker_resources"]], [0, 0], "ni producción de los trabajadores")
	# El balance neto que ve el jugador suma ciudades y trabajadores y resta mantenimiento.
	var net := pop.net_income_milli(PLAYER)
	var base := cities.income_for(PLAYER)
	var output := pop.worker_output_milli(PLAYER)
	_expect(errors, net, {"money": base["money"] * 1000 + output["money"], "resources": base["resources"] * 1000 + output["resources"] - pop.upkeep_milli(PLAYER)["total"]}, "balance neto coherente")
	return errors


func _test_deficit_recovery() -> Array:
	var errors: Array = []
	# 30 trabajadores y 80 soldados con una ciudad de nivel 1 y sin recursos: el ejército no se puede mantener.
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 80}}, _duel_grid(), false)
	var control := _make_world({PLAYER: {"workers": 30, "soldiers": 80}}, _duel_grid(), false)
	for each: Dictionary in [world, control]:
		each["economy"].add(PLAYER, 1000, 0)
		each["cities"].found_city(PLAYER, CITY_A)
	var pop: Population = world["pop"]
	var economy: Economy = world["economy"]
	_ticks(world, 10)
	_ticks(control, 10)
	_expect(errors, [pop.get_maintenance(PLAYER)["in_deficit"], pop.get_maintenance(PLAYER)["stage"]], [true, Population.STAGE_ATTRITION], "tras 10 ticks hay déficit grave")
	# Validaciones de la desmovilización: no cambian nada.
	var before := [pop.workers(PLAYER), pop.soldiers(PLAYER)]
	_expect(errors, [pop.demobilize(PLAYER, 0), pop.demobilize(PLAYER, 1000), pop.demobilize(99, 5)],
			[Population.DEMOB_ERR_AMOUNT, Population.DEMOB_ERR_NOT_ENOUGH, Population.DEMOB_ERR_UNKNOWN_NATION], "cantidades inválidas rechazadas")
	_expect(errors, [pop.workers(PLAYER), pop.soldiers(PLAYER)], before, "los rechazos no cambian nada")
	# Desmovilizar es inmediato, sin coste y conserva la población.
	var money := economy.get_money(PLAYER)
	_expect(errors, pop.demobilize(PLAYER, 50), Population.DEMOB_OK, "se desmovilizan 50 soldados")
	_expect(errors, [pop.workers(PLAYER), pop.soldiers(PLAYER), economy.get_money(PLAYER)], [before[0] + 50, before[1] - 50, money], "50 soldados pasan a trabajadores sin coste")
	var lowest := 1000000
	for tick in 10:
		_ticks(world, 1)
		_ticks(control, 1)
		lowest = mini(lowest, economy.get_resources(PLAYER))
	_expect(errors, pop.get_maintenance(PLAYER)["in_deficit"], false, "en 10 ticks el déficit se ha corregido")
	_expect(errors, control["pop"].get_maintenance(PLAYER)["in_deficit"], true, "sin desmovilizar seguiría en déficit")
	_expect(errors, lowest >= 0 and pop.workers(PLAYER) >= 0 and pop.soldiers(PLAYER) >= 0, true, "nunca hay valores negativos")
	return errors


func _test_priority_cost() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 10, "soldiers": 0}}, _duel_grid(), false)
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	var pop: Population = world["pop"]
	economy.add(PLAYER, 1000, 0)
	var city_id: int = cities.found_city(PLAYER, CITY_A)["city_id"]
	# Ciudad ocupada (no produce) y sin dinero: la prioridad marcada no se puede pagar.
	world["occ"].occupy(AI_1, CITY_A)
	economy.spend_money(PLAYER, economy.get_money(PLAYER))
	_expect(errors, pop.set_city_priority(PLAYER, city_id, true), true, "se marca la prioridad")
	_expect(errors, pop.priority_cost(PLAYER), PopulationBalance.PRIORITY_MONEY_PER_TICK, "coste por tick de las prioridades")
	_ticks(world, 10)
	_expect(errors, [pop.get_stats(PLAYER)["priority_paid"], economy.get_money(PLAYER), cities.get_city(city_id)["progress"]],
			[0, 0, 10 * EconomyBalance.GROWTH_PER_TICK], "sin dinero no se paga ni acelera el nivel (y el saldo nunca es negativo)")
	# Con 5 de dinero se pagan 5 ticks.
	economy.add(PLAYER, 5, 0)
	_ticks(world, 5)
	_expect(errors, [pop.get_stats(PLAYER)["priority_paid"], economy.get_money(PLAYER)], [5 * PopulationBalance.PRIORITY_MONEY_PER_TICK, 0], "se cobra mientras hay dinero")
	_expect(errors, cities.get_city(city_id)["progress"], 15 * EconomyBalance.GROWTH_PER_TICK + 5 * PopulationBalance.PRIORITY_CITY_GROWTH, "y esos ticks la ciudad crece más rápido")
	# add_growth: validaciones.
	_expect(errors, [cities.add_growth(999, 1), cities.add_growth(city_id, 0), cities.add_growth(city_id, -3)], [false, false, false], "add_growth rechaza ciudades inexistentes y puntos no positivos")
	return errors


# ---------------------------------------------------------------------------
# Guerra: frente ancho
# ---------------------------------------------------------------------------

func _test_wide_expansion() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}}, _open_grid())
	var grid: TerritoryGrid = world["grid"]
	var off: Offensives = world["off"]
	var wars: WarState = world["wars"]
	var origin := Vector2i(14, 20)
	var plan := off.plan_attack(PLAYER, origin, Military.DIR_EAST, 12)
	_expect(errors, [plan["ok"], plan["info"]["goal"], plan["info"]["kind"]], [true, TerritoryGrid.OWNER_NONE, Offensives.KIND_UNCLAIMED], "es una expansión sobre tierra sin reclamar")
	var expected: Array = []
	for y in [20, 19, 21, 18, 22, 17, 23, 16, 24]:
		expected.append(Vector2i(15, y))
	_expect(errors, plan["info"]["cells"], expected, "la franja prevista: la columna de 9 celdas pegada al territorio, de la punta hacia fuera")
	var result := off.launch_attack(PLAYER, origin, Military.DIR_EAST, 12)
	_expect(errors, result["ok"], true, "se lanza")
	var sid: int = result["sector_id"]
	_signal_cells = []
	off.territory_changed.connect(_collect_cells)
	_ticks(world, INTERVAL)
	_expect(errors, _signal_cells, expected, "un avance conquista exactamente la franja prevista")
	for cell: Vector2i in expected:
		if grid.get_cell_owner(cell.x, cell.y) != PLAYER:
			errors.append("la celda %s no se conquistó" % cell)
	_expect(errors, [off.get_offensive(sid)["claimed"], off.get_offensive(sid)["front"], grid.get_cell_owner(16, 20)], [9, Vector2i(15, 20), TerritoryGrid.OWNER_NONE], "9 celdas, la punta avanza una y nada más")
	_expect(errors, wars.war_count(), 0, "expandirse no declara guerras")
	# Más tropas, avance más rápido: con 3 soldados solo 3 celdas por avance.
	var small := _make_world({PLAYER: {"workers": 30, "soldiers": 20}}, _open_grid())
	var small_plan: Dictionary = small["off"].plan_attack(PLAYER, origin, Military.DIR_EAST, 3)
	_expect(errors, small_plan["info"]["cells"], [Vector2i(15, 20), Vector2i(15, 19), Vector2i(15, 21)], "3 soldados: 3 celdas")
	_expect(errors, [Offensives.cells_for(3, true), Offensives.cells_for(3), Offensives.cells_for(1000, true), Offensives.cells_for(0)], [3, 1, CombatBalance.MAX_CELLS_PER_STEP, 1], "celdas por avance según los soldados")
	# Avanza hasta el borde de la tierra y se detiene en el agua.
	var previous := 9
	for step in 30:
		_ticks(world, INTERVAL)
		var claimed: int = off.get_offensive(sid)["claimed"]
		if claimed - previous > CombatBalance.MAX_CELLS_PER_STEP:
			errors.append("más celdas de las permitidas en un avance (%d)" % (claimed - previous))
		previous = claimed
	_expect(errors, [off.sector_state(sid), off.get_offensive(sid)["reason"], off.get_offensive(sid)["claimed"]], [Offensives.STATE_STOPPED, Offensives.STOP_WATER, 25 * 9], "25 columnas de 9 celdas y se detiene en el agua")
	for y in range(10, 30):
		for x in range(15, 40):
			var inside := y >= 16 and y <= 24
			if (grid.get_cell_owner(x, y) == PLAYER) != inside:
				errors.append("la celda (%d, %d) no debería %s" % [x, y, "faltar" if inside else "ser del jugador"])
				break
	# Nunca salta el agua: con una columna de agua en x = 25, nada al otro lado cambia de dueño.
	var moat := _make_world({PLAYER: {"workers": 30, "soldiers": 20}}, _open_grid(25))
	var moat_sid: int = moat["off"].launch_attack(PLAYER, origin, Military.DIR_EAST, 12)["sector_id"]
	_ticks(moat, INTERVAL * 20)
	_expect(errors, [moat["off"].sector_state(moat_sid), moat["off"].get_offensive(moat_sid)["reason"]], [Offensives.STATE_STOPPED, Offensives.STOP_WATER], "se detiene en el agua")
	for y in range(10, 30):
		for x in range(26, 40):
			if moat["grid"].get_cell_owner(x, y) != TerritoryGrid.OWNER_NONE:
				errors.append("se conquistó (%d, %d) al otro lado del agua" % [x, y])
	return errors


func _test_expansion_contact() -> Array:
	var errors: Array = []
	# Jugador x 10..20, sin reclamar x 21..24, IA 1 x 25..34.
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}}, _make_grid(20, 25))
	var off: Offensives = world["off"]
	var wars: WarState = world["wars"]
	var occ: Occupation = world["occ"]
	var sid: int = off.launch_attack(PLAYER, Vector2i(20, 15), Military.DIR_EAST, 12)["sector_id"]
	_ticks(world, INTERVAL * 4)
	_expect(errors, [off.get_offensive(sid)["front"], off.is_active(sid), wars.war_count()], [Vector2i(24, 15), true, 0], "cuatro avances hasta la frontera de la IA 1, sin guerra")
	var fc := off.forecast(sid)
	_expect(errors, [fc["blocked"], fc["reason"]], [true, Offensives.STOP_CONTACT], "la previsión avisa: una expansión no ataca")
	_ticks(world, INTERVAL)
	_expect(errors, [off.sector_state(sid), off.get_offensive(sid)["reason"], wars.war_count(), occ.count()], [Offensives.STATE_STOPPED, Offensives.STOP_CONTACT, 0, 0], "se detiene sin declarar la guerra ni ocupar nada")
	_expect(errors, Offensives.stop_reason_message(Offensives.STOP_CONTACT).contains("expansión"), true, "el motivo se explica")
	# Atacar es una orden explícita.
	var attack := off.launch_attack(PLAYER, Vector2i(20, 15), Military.DIR_EAST, 12)
	_expect(errors, [attack["ok"], wars.at_war(PLAYER, AI_1), off.goal_of(sid)], [true, true, AI_1], "reanudar es un ataque contra la IA 1 y declara la guerra")
	return errors


func _test_wide_combat() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 30}, AI_1: {"workers": 30, "soldiers": 6}}, _duel_grid())
	var grid: TerritoryGrid = world["grid"]
	var off: Offensives = world["off"]
	var occ: Occupation = world["occ"]
	var pop: Population = world["pop"]
	var wars: WarState = world["wars"]
	var owners := grid.copy_owner_data()
	var plan := off.plan_attack(PLAYER, BORDER, Military.DIR_EAST, 18)
	var info: Dictionary = plan["info"]
	var expected := [Vector2i(25, 15), Vector2i(25, 14), Vector2i(25, 16), Vector2i(25, 13), Vector2i(25, 17), Vector2i(25, 12)]
	_expect(errors, [info["kind"], info["defense"], info["max_cells"], info["cells"]], [Offensives.KIND_ENEMY, 2, 6, expected], "18 soldiers: hasta 6 celdas de la columna enemiga contra una defensa local de 2")
	_expect(errors, [info["attacker_wins"], info["attacker_losses"], info["defender_losses"]], [true, 1, 2], "un solo enfrentamiento: victoria con 1 y 2 bajas")
	var sid: int = off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 18)["sector_id"]
	_ticks(world, INTERVAL)
	_expect(errors, occ.get_cells(PLAYER), expected, "se ocupan exactamente las celdas previstas")
	_expect(errors, [pop.soldiers(PLAYER), pop.soldiers(AI_1), off.get_offensive(sid)["occupied"]], [29, 4, 6], "las bajas son las previstas")
	_expect(errors, grid.copy_owner_data() == owners, true, "ocupar no cambia ningún propietario")
	_expect(errors, [wars.casualties_of(PLAYER, AI_1), wars.occupations_by(PLAYER, AI_1)], [1, 6], "el registro de la guerra anota bajas y ocupaciones")
	_ticks(world, INTERVAL)
	_expect(errors, occ.count(PLAYER), 11, "el segundo avance (17 soldados, hasta 5 celdas) amplía la ocupación")
	for cell: Vector2i in occ.get_cells(PLAYER):
		if grid.get_cell_owner(cell.x, cell.y) != AI_1:
			errors.append("una celda ocupada (%s) dejó de ser oficialmente de la IA 1" % cell)
	# Derrota: pocos soldados contra una defensa mayor; la previsión lo dice y el resultado coincide.
	var weak := _make_world({PLAYER: {"workers": 30, "soldiers": 30}, AI_1: {"workers": 30, "soldiers": 30}}, _duel_grid())
	var weak_plan: Dictionary = weak["off"].plan_attack(PLAYER, BORDER, Military.DIR_EAST, 6)
	_expect(errors, weak_plan["info"]["attacker_wins"], false, "previsión de derrota")
	var weak_sid: int = weak["off"].launch_attack(PLAYER, BORDER, Military.DIR_EAST, 6)["sector_id"]
	_ticks(weak, INTERVAL)
	_expect(errors, [weak["off"].get_offensive(weak_sid)["reason"], weak["occ"].count(), weak["pop"].soldiers(PLAYER)],
			[Offensives.STOP_DEFEAT, 0, 30 - weak_plan["info"]["attacker_losses"]], "derrota: se detiene, no ocupa nada y pierde lo previsto")
	return errors


func _test_defense_without_attackers() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}}, _duel_grid())
	var off: Offensives = world["off"]
	_expect(errors, [off.defending_soldiers(AI_1), off.evaluate(PLAYER, 10, Vector2i(25, 15))["defense"]], [6, 2], "sin ataques, defienden sus 6 soldados (2 por tramo)")
	var ai_attack := off.launch_attack(AI_1, Vector2i(25, 20), Military.DIR_WEST, 4)
	_expect(errors, ai_attack["ok"], true, "la IA 1 ataca con 4")
	_expect(errors, [off.attacking_soldiers(AI_1), off.defending_soldiers(AI_1)], [4, 2], "4 atacan y solo 2 defienden")
	var info := off.evaluate(PLAYER, 10, Vector2i(25, 15))
	_expect(errors, [info["defender_soldiers"], info["defense"]], [2, 1], "la defensa local baja")
	_expect(errors, off.attacks_against(PLAYER).size(), 1, "el jugador ve la amenaza")
	_expect(errors, off.attacks_against(PLAYER)[0]["soldiers"], 4, "con sus soldados")
	off.stop_offensive(ai_attack["sector_id"])
	_expect(errors, [off.defending_soldiers(AI_1), off.attacks_against(PLAYER).size()], [6, 0], "un frente detenido vuelve a defender")
	return errors


func _test_city_defense() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 30}, AI_1: {"workers": 30, "soldiers": 12}}, _duel_grid())
	var off: Offensives = world["off"]
	world["economy"].add(AI_1, 1000, 0)
	_expect(errors, world["cities"].found_city(AI_1, Vector2i(27, 15))["ok"], true, "la IA 1 funda una ciudad junto a la frontera")
	var near := off.plan_attack(PLAYER, BORDER, Military.DIR_EAST, 6)
	var far := off.plan_attack(PLAYER, Vector2i(24, 25), Military.DIR_EAST, 6)
	_expect(errors, [near["info"]["defense"], far["info"]["defense"]], [4, 4], "misma defensa local (12 soldados en 3 tramos)")
	_expect(errors, [near["info"]["city_bonus"], near["info"]["bonus_percent"]], [true, CombatBalance.DEFENSE_BONUS_PERCENT + CombatBalance.CITY_DEFENSE_BONUS_PERCENT], "junto a la ciudad la defensa se refuerza")
	_expect(errors, [far["info"]["city_bonus"], far["info"]["bonus_percent"]], [false, CombatBalance.DEFENSE_BONUS_PERCENT], "lejos, no")
	_expect(errors, [near["info"]["attacker_wins"], far["info"]["attacker_wins"]], [false, true], "6 atacantes ganan lejos de la ciudad y pierden junto a ella")
	_expect(errors, [Combat.attacker_wins(6, 4), Combat.attacker_wins(6, 4, 180), Combat.attacker_wins(8, 4, 180)], [true, false, true], "regla exacta con la bonificación")
	return errors


func _test_liberation() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}}, _duel_grid())
	var grid: TerritoryGrid = world["grid"]
	var off: Offensives = world["off"]
	var occ: Occupation = world["occ"]
	world["wars"].declare_war(AI_1, PLAYER)
	var taken := Vector2i(24, 15)
	occ.occupy(AI_1, taken)
	var owners := grid.copy_owner_data()
	var info := off.evaluate(PLAYER, 6, taken)
	_expect(errors, [info["kind"], info["defender"], info["defense"]], [Offensives.KIND_LIBERATE, AI_1, 2], "la celda propia ocupada es un objetivo contra el ocupante")
	var suggestion := off.suggest_front(PLAYER, taken)
	_expect(errors, suggestion, {"origin": Vector2i(24, 16), "direction": Military.DIR_NORTH}, "pulsar la celda propia ocupada propone un frente para liberarla")
	var result := off.launch_attack(PLAYER, Vector2i(23, 15), Military.DIR_EAST, 6)
	_expect(errors, result["ok"], true, "se puede lanzar un frente de liberación")
	_ticks(world, INTERVAL)
	_expect(errors, [occ.occupier_at(taken), grid.get_cell_owner(taken.x, taken.y), off.get_offensive(result["sector_id"])["liberated"]], [TerritoryGrid.OWNER_NONE, PLAYER, 1], "la celda se libera y sigue siendo del jugador")
	_expect(errors, grid.copy_owner_data() == owners, true, "liberar no cambia propietarios")
	_expect(errors, world["pop"].soldiers(AI_1) < 6, true, "el ocupante sufrió bajas")
	return errors


# ---------------------------------------------------------------------------
# IA estratégica
# ---------------------------------------------------------------------------

func _test_ai_defends() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 30}, AI_1: {"workers": 30, "soldiers": 20}}, _duel_grid())
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var ai: AIController = world["ai"]
	var expansion := off.launch_attack(AI_1, Vector2i(34, 15), Military.DIR_EAST, 15)
	_expect(errors, [expansion["ok"], off.goal_of(expansion["sector_id"])], [true, TerritoryGrid.OWNER_NONE], "la IA 1 se expande hacia el este con 15")
	_expect(errors, off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 10)["ok"], true, "el jugador la ataca con 10")
	_expect(errors, [ai.incoming_soldiers(AI_1), mil.available_soldiers(AI_1)], [10, 5], "amenaza de 10 y solo 5 en reserva")
	var actions := ai.decide(AI_1)
	_expect(errors, actions.has("retira el frente %d para defenderse" % expansion["sector_id"]), true, "retira la expansión para defenderse (acciones: %s)" % [actions])
	_expect(errors, [mil.sector_count() - mil.get_sector_ids(PLAYER).size(), mil.available_soldiers(AI_1), world["pop"].soldiers(AI_1)], [0, 20, 20], "sus 20 soldados vuelven a la reserva: ninguno nuevo")
	_expect(errors, off.is_active(mil.get_sector_ids(PLAYER)[0]), true, "el ataque del jugador sigue")
	_expect(errors, world["pop"].new_soldier_percent(AI_1), AIBalance.WAR_SOLDIER_PERCENT, "amenazada, recluta más soldados con la población nueva")
	return errors


func _test_ai_attacks() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 6}, AI_1: {"workers": 30, "soldiers": 30}}, _duel_grid())
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var ai: AIController = world["ai"]
	world["wars"].declare_war(PLAYER, AI_1)
	_expect(errors, ai.free_soldiers(AI_1), 30 - 30 * AIBalance.WAR_HOME_GUARD_PERCENT / 100, "en guerra guarda una parte en casa")
	var actions := ai.decide(AI_1)
	var fronts := mil.get_sector_ids(AI_1)
	_expect(errors, fronts.size(), 1, "abre un frente (acciones: %s)" % [actions])
	if fronts.size() == 1:
		var sid: int = fronts[0]
		_expect(errors, [off.is_active(sid), off.goal_of(sid), mil.get_sector(sid)["soldiers"]], [true, PLAYER, 21 * AIBalance.ATTACK_COMMIT_PERCENT / 100], "ataca al jugador con parte de sus soldados libres")
		_expect(errors, off.forecast(sid)["attacker_wins"], true, "con previsión de victoria")
	_expect(errors, world["pop"].soldiers(AI_1), 30, "sin crear soldados")
	# Débil, no ataca.
	var weak := _make_world({PLAYER: {"workers": 30, "soldiers": 30}, AI_1: {"workers": 30, "soldiers": 6}}, _duel_grid())
	weak["wars"].declare_war(PLAYER, AI_1)
	weak["ai"].decide(AI_1)
	var against_player := 0
	for sector_id: int in weak["mil"].get_sector_ids(AI_1):
		if weak["off"].goal_of(sector_id) == PLAYER:
			against_player += 1
	_expect(errors, against_player, 0, "con previsión de derrota no ataca al jugador (como mucho se expande por tierra libre)")
	# Un frente derrotado se retira para reorganizarse.
	var beaten := _make_world({PLAYER: {"workers": 30, "soldiers": 30}, AI_1: {"workers": 30, "soldiers": 10}}, _duel_grid())
	var beaten_sid: int = beaten["off"].launch_attack(AI_1, Vector2i(25, 15), Military.DIR_WEST, 4)["sector_id"]
	_ticks(beaten, INTERVAL)
	_expect(errors, beaten["off"].get_offensive(beaten_sid)["reason"], Offensives.STOP_DEFEAT, "el ataque de la IA 1 fracasa")
	beaten["ai"].decide(AI_1)
	_expect(errors, beaten["mil"].has_sector(beaten_sid), false, "y la IA retira el frente (los supervivientes vuelven a la reserva)")
	return errors


func _test_ai_truce() -> Array:
	var errors: Array = []
	var results: Array = []
	for with_truce in [true, false]:
		var world := _make_world({PLAYER: {"workers": 30, "soldiers": 6}, AI_1: {"workers": 30, "soldiers": 30}}, _duel_grid())
		world["economy"].add(AI_1, 1000, 0)
		world["cities"].found_city(AI_1, Vector2i(30, 20))
		_ticks(world, AIBalance.WAR_GRACE_TICKS)
		if with_truce:
			world["wars"].start_truce(AI_1, PLAYER, DiplomacyBalance.TRUCE_TICKS)
		_events = []
		world["ai"].event.connect(_collect_event)
		world["ai"].decide(AI_1)
		world["ai"].decide(AI_1)
		var at_war: bool = world["wars"].at_war(AI_1, PLAYER)
		results.append(at_war)
		if with_truce:
			_expect(errors, [at_war, world["off"].attacks_against(PLAYER).size()], [false, 0], "con tregua no declara la guerra ni ataca")
		else:
			_expect(errors, [at_war, world["off"].attacks_against(PLAYER).size(), _events.has("¡%s te declara la guerra!" % world["grid"].get_nation(AI_1)["name"])], [true, 1, true], "sin tregua y con ventaja, declara la guerra y avisa al jugador")
	# Antes del plazo de gracia nunca declara la guerra.
	var early := _make_world({PLAYER: {"workers": 30, "soldiers": 6}, AI_1: {"workers": 30, "soldiers": 30}}, _duel_grid())
	early["economy"].add(AI_1, 1000, 0)
	early["cities"].found_city(AI_1, Vector2i(30, 20))
	_ticks(early, 10)
	early["ai"].decide(AI_1)
	early["ai"].decide(AI_1)
	_expect(errors, early["wars"].war_count(), 0, "al principio de la partida no hay guerras")
	return errors


func _test_ai_peace() -> Array:
	var errors: Array = []
	# Mapa de tres: IA 1 arriba y IA 2 abajo en x 25..39. Guerra larga entre ambas: ambas se cansan.
	var grid := _make_grid(24, 99)
	var owners := grid.copy_owner_data()
	for y in range(10, 30):
		for x in range(25, 40):
			owners[y * TerritoryGrid.WIDTH + x] = AI_1 if y < 20 else AI_2
	grid.load_from_data(grid.copy_terrain_data(), owners)
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 6}, AI_1: {"workers": 30, "soldiers": 6}, AI_2: {"workers": 30, "soldiers": 6}}, grid)
	var wars: WarState = world["wars"]
	wars.declare_war(AI_1, AI_2)
	_ticks(world, 40)
	var stance: Dictionary = world["dip"].ai_stance(AI_1, AI_2)
	_expect(errors, stance["reluctance"] < -DiplomacyBalance.PEACE_SEEK_MARGIN, true, "tras 40 ticks de guerra igualada la IA 1 está cansada (%d)" % stance["reluctance"])
	_events = []
	world["ai"].event.connect(_collect_event)
	world["ai"].decide(AI_1)
	_expect(errors, [wars.at_war(AI_1, AI_2), wars.has_truce(AI_1, AI_2), world["dip"].history().size()], [false, true, 1], "propone la paz, la otra IA acepta y empieza la tregua")
	_expect(errors, _events.size() >= 1, true, "se anuncia la paz")
	# Las IA sienten el déficit y las ciudades ocupadas en su cansancio. El mantenimiento se acumula en
	# milésimas: la deuda (y con ella el déficit) solo aparece cuando lo debido llega a 1 recurso entero.
	# Para que su ejército quede sin pagar hacen falta ceil(1000 / (6 * SOLDIER_UPKEEP_MILLI)) ticks.
	var poor := _make_world({PLAYER: {"workers": 30, "soldiers": 6}, AI_1: {"workers": 30, "soldiers": 6}}, _duel_grid(), false)
	poor["wars"].declare_war(PLAYER, AI_1)
	var unpaid_ticks := ceili(1000.0 / float(6 * PopulationBalance.SOLDIER_UPKEEP_MILLI))
	_ticks(poor, unpaid_ticks)
	_expect(errors, [poor["economy"].get_resources(AI_1), poor["pop"].get_maintenance(AI_1)["soldiers_covered"]], [0, false], "sin recursos, el ejército de la IA 1 queda sin pagar")
	var poor_stance: Dictionary = poor["dip"].ai_stance(AI_1, PLAYER)
	_expect(errors, [poor_stance["in_deficit"], poor_stance["weariness"] >= DiplomacyBalance.DEFICIT_WEARINESS], [true, true], "una IA sin recursos para su ejército se cansa antes")
	return errors


func _test_treaty_wave() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 30}, AI_1: {"workers": 30, "soldiers": 6}}, _duel_grid())
	var grid: TerritoryGrid = world["grid"]
	var off: Offensives = world["off"]
	var occ: Occupation = world["occ"]
	var wars: WarState = world["wars"]
	var dip: Diplomacy = world["dip"]
	var economy: Economy = world["economy"]
	var sid: int = off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 18)["sector_id"]
	_ticks(world, INTERVAL)
	var held: Array = occ.get_cells(PLAYER)
	_expect(errors, held.size(), 6, "el frente ancho ocupó 6 celdas")
	# Una oferta imposible (la IA 1 no tiene 1000 de dinero) no cambia nada.
	var before := _snapshot(world)
	var failed := dip.propose(PLAYER, AI_1, Diplomacy.KIND_CONQUESTS, AI_1, 1000)
	_expect(errors, [failed["ok"], failed["error"]], [false, Diplomacy.ERR_NO_FUNDS], "oferta rechazada antes de aplicarse")
	_expect(errors, _snapshot(world) == before, true, "y no cambió nada")
	# La IA 1, derrotada, ya propuso sola una paz blanca durante el avance (Diplomacy._make_ai_offers). Solo
	# puede haber una propuesta pendiente por pareja: el jugador la responde (la rechaza) antes de proponer.
	var incoming: Array = dip.pending_for(PLAYER)
	_expect(errors, incoming.size(), 1, "la IA 1, derrotada, ha propuesto la paz por su cuenta")
	if incoming.size() == 1:
		_expect(errors, [incoming[0]["from"], incoming[0]["kind"]], [AI_1, Diplomacy.KIND_WHITE], "una paz blanca de la IA 1")
		_expect(errors, dip.reject(incoming[0]["id"], PLAYER)["ok"], true, "el jugador la rechaza")
	_expect(errors, [dip.has_pending(PLAYER, AI_1), wars.at_war(PLAYER, AI_1), occ.count()], [false, true, 6], "rechazarla no cambia la guerra ni las ocupaciones")
	# Paz con conquistas: lo ocupado pasa a ser del jugador; la guerra termina y empieza la tregua.
	var money := [economy.get_money(PLAYER), economy.get_money(AI_1)]
	var peace := dip.propose(PLAYER, AI_1, Diplomacy.KIND_CONQUESTS, Diplomacy.NO_PAYER, 0)
	_expect(errors, [peace["ok"], peace["response"]], [true, Diplomacy.RESPONSE_ACCEPTED], "la IA 1, derrotada, acepta (%s)" % peace["message"])
	for cell: Vector2i in held:
		if grid.get_cell_owner(cell.x, cell.y) != PLAYER:
			errors.append("la celda ocupada %s no pasó al jugador" % cell)
	_expect(errors, [occ.count(), wars.at_war(PLAYER, AI_1), wars.has_truce(PLAYER, AI_1), off.is_active(sid)], [0, false, true, false], "sin ocupaciones, sin guerra, con tregua y con la ofensiva detenida")
	_expect(errors, [economy.get_money(PLAYER), economy.get_money(AI_1)], money, "sin pago, nadie cobra")
	# La tregua bloquea la lógica militar también con el frente ancho.
	var blocked := off.plan_attack(PLAYER, Vector2i(24, 25), Military.DIR_EAST, 10)
	_expect(errors, [blocked["ok"], blocked["error"], blocked["reason"]], [false, Offensives.LAUNCH_ERR_BLOCKED, Offensives.STOP_TRUCE], "con tregua no se puede atacar")
	_ticks(world, DiplomacyBalance.TRUCE_TICKS)
	_expect(errors, off.plan_attack(PLAYER, Vector2i(24, 25), Military.DIR_EAST, 10)["ok"], true, "al acabar la tregua, sí")
	return errors


# ---------------------------------------------------------------------------
# Partida por defecto, pausa y determinismo
# ---------------------------------------------------------------------------

func _test_default_world_activity() -> Array:
	var errors: Array = []
	var world := _default_world()
	var grid: TerritoryGrid = world["grid"]
	var pop: Population = world["pop"]
	var mil: Military = world["mil"]
	var economy: Economy = world["economy"]
	var occ: Occupation = world["occ"]
	var cities: CityManager = world["cities"]
	var start_counts := grid.count_land_by_owner()
	var start_cities := cities.city_count()
	for tick in 240:
		_ticks(world, 1)
		for nation_id: int in grid.get_nation_ids():
			if economy.get_money(nation_id) < 0 or economy.get_resources(nation_id) < 0 or pop.workers(nation_id) < 0 or pop.soldiers(nation_id) < 0:
				errors.append("valor negativo de la nación %d en el tick %d" % [nation_id, tick + 1])
				return errors
			if mil.assigned_soldiers(nation_id) > pop.soldiers(nation_id):
				errors.append("más soldados asignados que existentes (nación %d, tick %d)" % [nation_id, tick + 1])
				return errors
	for cell: Vector2i in occ.get_cells():
		if grid.get_cell_owner(cell.x, cell.y) == occ.occupier_at(cell):
			errors.append("una celda ocupada por su propio dueño: %s" % cell)
	var counts := grid.count_land_by_owner()
	var grew := 0
	for nation_id: int in world["ai"].ai_nations():
		if counts[nation_id] > start_counts[nation_id]:
			grew += 1
	_expect(errors, grew, world["ai"].ai_nations().size(), "todas las IA han ampliado su territorio")
	_expect(errors, cities.city_count() > start_cities, true, "alguna IA ha fundado una ciudad")
	_expect(errors, counts[TerritoryGrid.OWNER_PLAYER], start_counts[TerritoryGrid.OWNER_PLAYER], "el jugador, que no hace nada, no pierde ni gana territorio oficial")
	return errors


func _test_pause_stops_ai() -> Array:
	var errors: Array = []
	var world := _default_world()
	var cities: CityManager = world["cities"]
	_ticks(world, 20)
	cities.set_paused(true)
	var before := _snapshot(world)
	_expect(errors, cities.advance(200.0), 0, "en pausa no se ejecuta ningún tick")
	_expect(errors, _snapshot(world) == before, true, "nada cambia en pausa: ni la IA, ni las ofensivas, ni la economía")
	# La IA tampoco decide sola en pausa (sus decisiones cuelgan del reloj).
	cities.set_paused(false)
	var ticks := cities.tick_count()
	_ticks(world, 8)
	_expect(errors, cities.tick_count(), ticks + 8, "reanudada, el tiempo vuelve a correr")
	_expect(errors, _snapshot(world) != before, true, "y el mundo vuelve a moverse")
	return errors


func _test_determinism() -> Array:
	var errors: Array = []
	var snapshots: Array = []
	for run in 2:
		var world := _default_world()
		_ticks(world, 200)
		snapshots.append(_snapshot(world))
	_expect(errors, snapshots[0] == snapshots[1], true, "dos partidas con IA idénticas acaban en el mismo estado")
	return errors


# ---------------------------------------------------------------------------
# Interfaz
# ---------------------------------------------------------------------------

func _test_ui() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}}, _duel_grid())
	var off: Offensives = world["off"]
	_expect(errors, off.suggest_front(PLAYER, Vector2i(30, 15)), {"origin": Vector2i(24, 15), "direction": Military.DIR_EAST}, "una celda lejana se ataca desde la frontera más cercana")
	_expect(errors, off.suggest_front(PLAYER, Vector2i(25, 15)), {"origin": Vector2i(24, 15), "direction": Military.DIR_EAST}, "una celda vecina, desde la celda propia contigua")
	_expect(errors, off.suggest_front(PLAYER, Vector2i(12, 12)), {"origin": Vector2i(12, 12), "direction": -1}, "una celda propia interior no tiene dirección")
	_expect(errors, off.suggest_front(PLAYER, Vector2i(5, 5)), {}, "el agua no se ataca")
	_expect(errors, [MilitaryPanel.defense_text(12, 0), MilitaryPanel.defense_text(4, 8)], ["Defensa 12", "Defensa 4 (8 atacando no defienden)"], "texto de la defensa")
	_expect(errors, [MilitaryPanel.threats_text([]), MilitaryPanel.threats_text([["Reino de Cobre", 14]])], ["", "TE ATACAN\nReino de Cobre: 14 soldados"], "texto de las amenazas")
	var info: Dictionary = off.plan_attack(PLAYER, BORDER, Military.DIR_EAST, 18)["info"]
	_expect(errors, MilitaryPanel.forecast_text(info, "Reino de Cobre").contains("(y 5 celdas más de la franja)"), true, "la previsión dice cuántas celdas toma la franja")
	_expect(errors, PopulationPanel.jobs_text({"employed": 30, "jobs": 30, "workers": 30}, {"money": 1200, "resources": 900}), "Empleo 30/30 puestos\n+1,20 dinero/s · +0,90 recursos/s", "texto del empleo")
	_expect(errors, PopulationPanel.jobs_text({"employed": 30, "jobs": 30, "workers": 45}, {"money": 1200, "resources": 900}).contains("15 sin trabajo"), true, "avisa de los desempleados")
	_expect(errors, [Screen.signed_milli_rate(1390), Screen.signed_milli_rate(-500), Screen.signed_milli_rate(0)], ["+1,39", "-0,50", "+0"], "balances con signo")
	var pop: Population = world["pop"]
	_expect(errors, Screen.net_economy_summary(world["economy"], pop, PLAYER).begins_with("Dinero %d (" % world["economy"].get_money(PLAYER)), true, "resumen económico con el balance real")
	_expect(errors, [PopulationPanel.demobilization_button_text(5), PopulationPanel.demobilization_button_text(0)], ["Desmovilizar 5", "Sin reserva que desmovilizar"], "botón de desmovilizar")
	# La pantalla crea la IA y muestra sus avisos.
	var tree := Engine.get_main_loop() as SceneTree
	var scene: PackedScene = load("res://scenes/territory_main.tscn")
	if scene == null:
		errors.append("no carga la escena principal")
		return errors
	var screen: Screen = scene.instantiate()
	tree.root.add_child(screen)
	_expect(errors, screen.ai != null and screen.ai.enabled, true, "la pantalla crea la IA estratégica activada")
	screen.ai.event.emit("Aviso de prueba")
	var message: Label = screen.get_node("%Mensaje")
	_expect(errors, message.text, "Aviso de prueba", "los avisos de la IA aparecen en la línea de mensajes")
	var panel = screen.get_node("%Poblacion")
	for node_name: String in ["Empleo", "BotonDesmovilizar"]:
		_expect(errors, panel.find_child(node_name, true, false) != null, true, "el panel de población tiene %s" % node_name)
	var military_panel = screen.get_node("%Militar")
	for node_name: String in ["DefensaMilitar", "AmenazaMilitar"]:
		_expect(errors, military_panel.find_child(node_name, true, false) != null, true, "el panel militar tiene %s" % node_name)
	screen.free()
	return errors


func _test_files_present() -> Array:
	var errors: Array = []
	for path: String in ["res://tests/territory_grid_tests.gd", "res://tests/territory_map_view_tests.gd",
			"res://tests/territory_conquest_tests.gd", "res://tests/territory_hud_tests.gd",
			"res://tests/city_economy_tests.gd", "res://tests/population_tests.gd", "res://tests/military_tests.gd",
			"res://tests/combat_tests.gd", "res://tests/diplomacy_tests.gd", "res://tests/test_gameplay.gd",
			"res://tests/run_gameplay_tests.tscn", "res://scripts/world/ai_controller.gd", "res://scripts/data/ai_balance.gd"]:
		_expect(errors, FileAccess.file_exists(path), true, "existe " + path)
	return errors
