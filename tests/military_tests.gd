## Pruebas automáticas de la organización militar (hito 8): sectores y asignación de soldados.
## Sin plugins.
##
## Única definición de las comprobaciones; la usan:
##   - tests/test_military.gd (consola, headless):
##       godot --headless --path . --script res://tests/test_military.gd
##   - tests/run_military_tests.tscn (editor de Godot, F6).
##
## Mapa controlado (load_from_data): tierra x 10..39, y 10..29; jugador x 10..24, IA 1 x 25..34,
## sin reclamar x 35..39; el resto es agua. La ciudad del jugador se funda a mano en (12, 12) y la
## población se inyecta, así que ninguna prueba depende del mapa por defecto salvo la de la
## pantalla. El tiempo avanza con CityManager.advance(n): n ticks exactos de 1 s de juego.
##
## run_all() devuelve [{"name": String, "errors": Array}, ...]   (errors vacío = PASS)
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Economy := preload("res://scripts/world/economy.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Population := preload("res://scripts/world/population.gd")
const Military := preload("res://scripts/world/military.gd")
const PopulationBalance := preload("res://scripts/data/population_balance.gd")
const Screen := preload("res://scripts/ui/territory_screen.gd")
const MilitaryPanel := preload("res://scripts/ui/military_panel.gd")

const PLAYER := TerritoryGrid.OWNER_PLAYER
const AI_1 := TerritoryGrid.OWNER_AI_1
const SCREEN_PATH := "res://scenes/territory_main.tscn"
const CITY_A := Vector2i(12, 12)

var _results: Array = []
var _signal_count: int = 0


func run_all() -> Array:
	_results = []
	_run("las cuatro direcciones son ortogonales y el objetivo es la celda contigua", _test_directions)
	_run("crear sectores válidos en las cuatro direcciones", _test_create_four_directions)
	_run("rechaza orígenes que no son del jugador, fuera del mapa, agua, direcciones y naciones inválidas", _test_rejects_bad_origin)
	_run("rechaza objetivos fuera del mapa o en agua", _test_rejects_bad_target)
	_run("rechaza sectores duplicados (mismo origen y dirección)", _test_rejects_duplicates)
	_run("varios sectores a lo largo de una misma frontera sin cambiar el territorio", _test_many_sectors_one_border)
	_run("asignación válida: asignar, aumentar, reducir y devolver sin cambiar el total", _test_assign_valid)
	_run("imposible asignar más soldados de los disponibles ni cantidades negativas", _test_assign_limits)
	_run("coherencia entre soldados totales, asignados y disponibles", _test_totals_coherent)
	_run("eliminar un sector devuelve sus soldados a la reserva sin tocar la población", _test_remove_returns_soldiers)
	_run("redistribución determinista cuando disminuye el total de soldados", _test_soldier_loss_correction)
	_run("asignar y liberar no cambian población, economía, ciudades ni territorio", _test_no_side_effects)
	_run("compatibilidad con la movilización: no duplica ni permite asignaciones imposibles", _test_mobilization_compat)
	_run("una conquista que quita el origen elimina el sector y libera sus soldados", _test_conquest_effects)
	_run("textos y mensajes del panel militar", _test_texts)
	_run("pantalla: panel militar, selección de celda, direcciones, lista, ajuste y liberación", _test_screen)
	_run("ciudades, economía y población se comportan igual con sectores activos que sin ellos", _test_previous_systems_unchanged)
	_run("las suites anteriores y los archivos del hito están presentes", _test_files_present)
	return _results


func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	_results.append({"name": test_name, "errors": errors})


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


func _count_signal() -> void:
	_signal_count += 1


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


## Dos bloques de tierra del jugador en las esquinas del mapa (0..5 x 0..5 y 314..319 x 174..179),
## para probar objetivos que caen fuera del mapa.
func _make_corner_grid() -> TerritoryGrid:
	var terrain := PackedByteArray()
	terrain.resize(TerritoryGrid.CELL_COUNT)
	terrain.fill(TerritoryGrid.TERRAIN_WATER)
	var owners := PackedByteArray()
	owners.resize(TerritoryGrid.CELL_COUNT)
	owners.fill(TerritoryGrid.OWNER_NONE)
	for y in range(0, 6):
		for x in range(0, 6):
			terrain[y * TerritoryGrid.WIDTH + x] = TerritoryGrid.TERRAIN_LAND
			owners[y * TerritoryGrid.WIDTH + x] = PLAYER
	for y in range(174, 180):
		for x in range(314, 320):
			terrain[y * TerritoryGrid.WIDTH + x] = TerritoryGrid.TERRAIN_LAND
			owners[y * TerritoryGrid.WIDTH + x] = PLAYER
	var grid := TerritoryGrid.new()
	grid.load_from_data(terrain, owners)
	return grid


## Mundo controlado con una ciudad del jugador (fundada en el tick 0), la población inyectada y el
## sistema militar. Sin ticks transcurridos. Las naciones sin entrada en `initial` empiezan en 0.
func _make_world(initial: Dictionary, grid: TerritoryGrid = null) -> Dictionary:
	if grid == null:
		grid = _make_grid()
	var economy := Economy.new(grid.get_nation_ids())
	var cities := CityManager.new(grid, economy)
	economy.add(PLAYER, 1000, 0)
	cities.found_city(PLAYER, CITY_A)
	var population := Population.new(cities, economy, grid.get_nation_ids(), initial)
	var military := Military.new(grid, population)
	return {"grid": grid, "economy": economy, "cities": cities, "pop": population, "mil": military}


## Como _make_world pero la ciudad del jugador ya es de nivel 4 (210 ticks antes de crear la
## población): capacidad 240 y producción de 5 recursos por tick, así que una población de 240
## no crece y se mantiene sin déficit.
func _make_maxed_world(initial: Dictionary) -> Dictionary:
	var grid := _make_grid()
	var economy := Economy.new(grid.get_nation_ids())
	var cities := CityManager.new(grid, economy)
	economy.add(PLAYER, 1000, 0)
	cities.found_city(PLAYER, CITY_A)
	cities.advance(210.0)
	var population := Population.new(cities, economy, grid.get_nation_ids(), initial)
	var military := Military.new(grid, population)
	return {"grid": grid, "economy": economy, "cities": cities, "pop": population, "mil": military}


func _advance(world: Dictionary, ticks: int) -> void:
	var cities: CityManager = world["cities"]
	cities.advance(float(ticks))


## Todo lo que los sectores no deben tocar, en un Dictionary comparable.
func _snapshot(world: Dictionary) -> Dictionary:
	var grid: TerritoryGrid = world["grid"]
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	var pop: Population = world["pop"]
	var per_nation: Dictionary = {}
	for nation_id: int in grid.get_nation_ids():
		per_nation[nation_id] = {
			"workers": pop.workers(nation_id), "soldiers": pop.soldiers(nation_id),
			"total": pop.total_population(nation_id), "money": economy.get_money(nation_id),
			"resources": economy.get_resources(nation_id), "income": cities.income_for(nation_id),
			"maintenance": pop.get_maintenance(nation_id), "mobilization": pop.get_mobilization(nation_id),
			"summary": pop.get_summary(nation_id),
		}
	var city_data: Array = []
	for city_id: int in cities.get_city_ids():
		city_data.append(cities.get_city(city_id))
	return {"nations": per_nation, "cities": city_data, "owners": grid.copy_owner_data(), "terrain": grid.copy_terrain_data()}


## Datos de las asignaciones sin pasar por cálculos: [total, asignados, disponibles].
func _counts(mil: Military, nation_id: int) -> Array:
	return [mil.total_soldiers(nation_id), mil.assigned_soldiers(nation_id), mil.available_soldiers(nation_id)]


# ---------------------------------------------------------------------------
# Pruebas
# ---------------------------------------------------------------------------

func _test_directions() -> Array:
	var errors: Array = []
	_expect(errors, [Military.DIR_NORTH, Military.DIR_EAST, Military.DIR_SOUTH, Military.DIR_WEST], [0, 1, 2, 3], "índices de las direcciones")
	_expect(errors, Military.DIRECTION_STEPS.size(), 4, "hay exactamente cuatro direcciones")
	_expect(errors, Military.DIRECTION_NAMES, ["Norte", "Este", "Sur", "Oeste"], "nombres")
	_expect(errors, Military.DIRECTION_SHORT_NAMES, ["N", "E", "S", "O"], "iniciales")
	for step: Vector2i in Military.DIRECTION_STEPS:
		_expect(errors, absi(step.x) + absi(step.y), 1, "cada dirección es ortogonal (sin diagonales): %s" % step)
	var origin := Vector2i(20, 20)
	_expect(errors, Military.target_cell(origin, Military.DIR_NORTH), Vector2i(20, 19), "norte: y disminuye")
	_expect(errors, Military.target_cell(origin, Military.DIR_EAST), Vector2i(21, 20), "este: x aumenta")
	_expect(errors, Military.target_cell(origin, Military.DIR_SOUTH), Vector2i(20, 21), "sur: y aumenta")
	_expect(errors, Military.target_cell(origin, Military.DIR_WEST), Vector2i(19, 20), "oeste: x disminuye")
	return errors


func _test_create_four_directions() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}})
	var mil: Military = world["mil"]
	var grid: TerritoryGrid = world["grid"]
	var owners_before := grid.copy_owner_data()
	_expect(errors, mil.sector_count(), 0, "empieza sin sectores")
	_signal_count = 0
	mil.changed.connect(_count_signal)
	var origin := Vector2i(15, 15)
	var ids: Array = []
	for direction in 4:
		var result := mil.create_sector(PLAYER, origin, direction)
		_expect(errors, [result["ok"], result["error"]], [true, Military.SECTOR_OK], "crear en dirección %d" % direction)
		ids.append(result["id"])
		var sector := mil.get_sector(result["id"])
		_expect(errors, sector["owner"], PLAYER, "propietario del sector %d" % direction)
		_expect(errors, sector["origin"], origin, "origen del sector %d" % direction)
		_expect(errors, sector["direction"], direction, "dirección del sector %d" % direction)
		_expect(errors, sector["target"], origin + Military.DIRECTION_STEPS[direction], "objetivo adyacente del sector %d" % direction)
		_expect(errors, sector["soldiers"], 0, "un sector nuevo no tiene soldados")
		_expect(errors, mil.validate_sector(PLAYER, origin, direction), Military.SECTOR_ERR_DUPLICATE, "ahora ya existe (%d)" % direction)
	_expect(errors, _signal_count, 4, "cada creación emite changed una vez")
	_expect(errors, mil.sector_count(), 4, "cuatro sectores")
	_expect(errors, mil.get_sector_ids(PLAYER), ids, "ids en orden de creación")
	var unique: Dictionary = {}
	for sector_id: int in ids:
		unique[sector_id] = true
	_expect(errors, unique.size(), 4, "ids únicos")
	_expect(errors, _counts(mil, PLAYER), [20, 0, 20], "crear sectores no asigna ni crea soldados")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "crear sectores no cambia propietarios")
	# El sector devuelto es una copia.
	var copy := mil.get_sector(ids[0])
	copy["soldiers"] = 999
	_expect(errors, mil.get_sector(ids[0])["soldiers"], 0, "get_sector devuelve una copia")
	_expect(errors, mil.get_sector(999).is_empty(), true, "un sector inexistente da un diccionario vacío")
	return errors


func _test_rejects_bad_origin() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 10}})
	var mil: Military = world["mil"]
	var grid: TerritoryGrid = world["grid"]
	var owners_before := grid.copy_owner_data()
	var cases := [
		[PLAYER, Vector2i(30, 15), Military.DIR_NORTH, Military.SECTOR_ERR_ORIGIN_NOT_OWNED, "celda de otra nación"],
		[PLAYER, Vector2i(37, 15), Military.DIR_NORTH, Military.SECTOR_ERR_ORIGIN_NOT_OWNED, "celda sin reclamar"],
		[PLAYER, Vector2i(5, 5), Military.DIR_NORTH, Military.SECTOR_ERR_ORIGIN_NOT_OWNED, "celda de agua"],
		[PLAYER, Vector2i(-1, 15), Military.DIR_EAST, Military.SECTOR_ERR_ORIGIN_OUT_OF_BOUNDS, "x negativa"],
		[PLAYER, Vector2i(15, -1), Military.DIR_EAST, Military.SECTOR_ERR_ORIGIN_OUT_OF_BOUNDS, "y negativa"],
		[PLAYER, Vector2i(TerritoryGrid.WIDTH, 15), Military.DIR_WEST, Military.SECTOR_ERR_ORIGIN_OUT_OF_BOUNDS, "x = ancho"],
		[PLAYER, Vector2i(15, TerritoryGrid.HEIGHT), Military.DIR_NORTH, Military.SECTOR_ERR_ORIGIN_OUT_OF_BOUNDS, "y = alto"],
		[PLAYER, Vector2i(15, 15), -1, Military.SECTOR_ERR_BAD_DIRECTION, "dirección -1"],
		[PLAYER, Vector2i(15, 15), 4, Military.SECTOR_ERR_BAD_DIRECTION, "dirección 4"],
		[TerritoryGrid.OWNER_NONE, Vector2i(37, 15), Military.DIR_NORTH, Military.SECTOR_ERR_UNKNOWN_NATION, "nación OWNER_NONE"],
		[99, Vector2i(15, 15), Military.DIR_NORTH, Military.SECTOR_ERR_UNKNOWN_NATION, "nación 99"],
		[-1, Vector2i(15, 15), Military.DIR_NORTH, Military.SECTOR_ERR_UNKNOWN_NATION, "nación -1"],
	]
	for item: Array in cases:
		var result := mil.create_sector(item[0], item[1], item[2])
		_expect(errors, [result["ok"], result["error"], result["id"]], [false, item[3], Military.NO_SECTOR], "rechazo: " + item[4])
		_expect(errors, mil.validate_sector(item[0], item[1], item[2]), item[3], "validate_sector coincide: " + item[4])
	_expect(errors, mil.sector_count(), 0, "ningún rechazo deja sectores")
	# Un jugador no puede usar una celda de la IA, pero la IA sí la suya (el modelo es por nación).
	_expect(errors, mil.create_sector(AI_1, Vector2i(30, 15), Military.DIR_NORTH)["ok"], true, "la IA puede planificar sobre su propio territorio")
	_expect(errors, mil.create_sector(AI_1, Vector2i(15, 15), Military.DIR_NORTH)["error"], Military.SECTOR_ERR_ORIGIN_NOT_OWNED, "y no sobre el del jugador")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "propietarios intactos")
	return errors


func _test_rejects_bad_target() -> Array:
	var errors: Array = []
	# Objetivo en agua: borde de la tierra del jugador (x = 10 es el límite oeste, y = 10 el norte, y = 29 el sur).
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}})
	var mil: Military = world["mil"]
	_expect(errors, mil.create_sector(PLAYER, Vector2i(10, 15), Military.DIR_WEST)["error"], Military.SECTOR_ERR_TARGET_WATER, "oeste del borde: agua")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(15, 10), Military.DIR_NORTH)["error"], Military.SECTOR_ERR_TARGET_WATER, "norte del borde: agua")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(15, 29), Military.DIR_SOUTH)["error"], Military.SECTOR_ERR_TARGET_WATER, "sur del borde: agua")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(10, 15), Military.DIR_EAST)["ok"], true, "hacia dentro sí vale")
	_expect(errors, mil.sector_count(), 1, "solo el válido")
	# Objetivo fuera del mapa: esquinas.
	var corner := _make_world({PLAYER: {"workers": 30, "soldiers": 20}}, _make_corner_grid())
	var cmil: Military = corner["mil"]
	var cases := [
		[Vector2i(0, 0), Military.DIR_NORTH], [Vector2i(0, 0), Military.DIR_WEST],
		[Vector2i(319, 179), Military.DIR_EAST], [Vector2i(319, 179), Military.DIR_SOUTH],
		[Vector2i(3, 0), Military.DIR_NORTH], [Vector2i(0, 3), Military.DIR_WEST],
	]
	for item: Array in cases:
		var result := cmil.create_sector(PLAYER, item[0], item[1])
		_expect(errors, [result["ok"], result["error"]], [false, Military.SECTOR_ERR_TARGET_OUT_OF_BOUNDS], "objetivo fuera del mapa desde %s dirección %d" % [item[0], item[1]])
	_expect(errors, cmil.create_sector(PLAYER, Vector2i(0, 0), Military.DIR_EAST)["ok"], true, "desde la esquina hacia dentro vale")
	_expect(errors, cmil.create_sector(PLAYER, Vector2i(319, 179), Military.DIR_NORTH)["ok"], true, "desde la otra esquina hacia dentro vale")
	_expect(errors, cmil.sector_count(), 2, "solo los válidos")
	return errors


func _test_rejects_duplicates() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}})
	var mil: Military = world["mil"]
	var first := mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_EAST)
	_expect(errors, first["ok"], true, "primer sector")
	mil.set_sector_soldiers(first["id"], 5)
	_signal_count = 0
	mil.changed.connect(_count_signal)
	var again := mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_EAST)
	_expect(errors, [again["ok"], again["error"], again["id"]], [false, Military.SECTOR_ERR_DUPLICATE, Military.NO_SECTOR], "mismo origen y dirección")
	_expect(errors, _signal_count, 0, "el rechazo no emite señal")
	_expect(errors, [mil.sector_count(), mil.get_sector(first["id"])["soldiers"]], [1, 5], "el original no cambia")
	_expect(errors, mil.sector_at(Vector2i(15, 15), Military.DIR_EAST), first["id"], "sector_at lo encuentra")
	_expect(errors, mil.sector_at(Vector2i(15, 15), Military.DIR_WEST), Military.NO_SECTOR, "sector_at: otra dirección no existe")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_WEST)["ok"], true, "mismo origen, otra dirección: vale")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(16, 15), Military.DIR_EAST)["ok"], true, "otro origen, misma dirección: vale")
	# Tras eliminar se puede volver a crear, con un id nuevo.
	mil.remove_sector(first["id"])
	var recreated := mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_EAST)
	_expect(errors, recreated["ok"], true, "tras eliminar se puede recrear")
	_expect(errors, recreated["id"] > first["id"], true, "los ids no se reutilizan")
	_expect(errors, mil.get_sector(recreated["id"])["soldiers"], 0, "y empieza vacío")
	return errors


func _test_many_sectors_one_border() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 10}})
	var mil: Military = world["mil"]
	var grid: TerritoryGrid = world["grid"]
	var owners_before := grid.copy_owner_data()
	_signal_count = 0
	grid.ownership_changed.connect(_count_signal)
	# Frontera jugador | IA 1 en x = 24 | 25: un sector por celda de frontera, todos hacia el este.
	var ids: Array = []
	for y in range(12, 18):
		var result := mil.create_sector(PLAYER, Vector2i(24, y), Military.DIR_EAST)
		_expect(errors, result["ok"], true, "sector en la frontera y=%d" % y)
		ids.append(result["id"])
		_expect(errors, mil.target_owner(result["id"]), AI_1, "el objetivo (25, %d) es de la IA 1" % y)
	_expect(errors, mil.get_sector_ids(PLAYER), ids, "seis sectores distintos en la misma frontera")
	# Distribuir fuerzas distintas entre ellos.
	var amounts := [1, 2, 3, 4, 5, 5]
	for index in ids.size():
		_expect(errors, mil.set_sector_soldiers(ids[index], amounts[index]), Military.ASSIGN_OK, "asignar al sector %d" % index)
	_expect(errors, _counts(mil, PLAYER), [20, 20, 0], "toda la fuerza repartida: 20 asignados, 0 disponibles")
	# Objetivos sin reclamar, propios y en tierra de otra nación coexisten.
	var unclaimed := mil.create_sector(AI_1, Vector2i(34, 15), Military.DIR_EAST)
	_expect(errors, [unclaimed["ok"], mil.target_owner(unclaimed["id"])], [true, TerritoryGrid.OWNER_NONE], "objetivo sin reclamar")
	var own := mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_EAST)
	_expect(errors, [own["ok"], mil.target_owner(own["id"])], [true, PLAYER], "objetivo en territorio propio")
	_expect(errors, mil.target_owner(999), TerritoryGrid.INVALID, "target_owner de un sector inexistente")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ni los sectores ni la asignación cambian el territorio")
	_expect(errors, _signal_count, 0, "ni emiten ownership_changed")
	return errors


func _test_assign_valid() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}})
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var a: int = mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_NORTH)["id"]
	var b: int = mil.create_sector(PLAYER, Vector2i(16, 15), Military.DIR_NORTH)["id"]
	_signal_count = 0
	mil.changed.connect(_count_signal)
	_expect(errors, mil.set_sector_soldiers(a, 8), Military.ASSIGN_OK, "asignar 8")
	_expect(errors, [mil.get_sector(a)["soldiers"], _counts(mil, PLAYER)], [8, [20, 8, 12]], "8 asignados, 12 disponibles")
	_expect(errors, mil.adjust_sector_soldiers(a, 2), Military.ASSIGN_OK, "aumentar 2")
	_expect(errors, mil.get_sector(a)["soldiers"], 10, "10 en el sector")
	_expect(errors, mil.adjust_sector_soldiers(a, -3), Military.ASSIGN_OK, "reducir 3")
	_expect(errors, [mil.get_sector(a)["soldiers"], _counts(mil, PLAYER)], [7, [20, 7, 13]], "reducir devuelve a la reserva")
	_expect(errors, mil.set_sector_soldiers(b, 12), Military.ASSIGN_OK, "asignar 12 al segundo")
	_expect(errors, _counts(mil, PLAYER), [20, 19, 1], "dos sectores: 19 asignados, 1 disponible")
	_expect(errors, mil.set_sector_soldiers(b, 13), Military.ASSIGN_OK, "puede usar justo el último disponible")
	_expect(errors, _counts(mil, PLAYER), [20, 20, 0], "reserva agotada")
	_expect(errors, _signal_count, 5, "cada cambio real emite changed")
	_signal_count = 0
	_expect(errors, mil.set_sector_soldiers(b, 13), Military.ASSIGN_OK, "fijar la misma cantidad es válido")
	_expect(errors, mil.adjust_sector_soldiers(b, 0), Military.ASSIGN_OK, "ajuste 0 es válido")
	_expect(errors, _signal_count, 0, "y no emite señal")
	_expect(errors, mil.set_sector_soldiers(b, 0), Military.ASSIGN_OK, "dejar un sector a 0 es válido")
	_expect(errors, [mil.has_sector(b), _counts(mil, PLAYER)], [true, [20, 7, 13]], "el sector sigue existiendo con 0 soldados")
	_expect(errors, pop.soldiers(PLAYER), 20, "los soldados de la población no cambian en ningún momento")
	return errors


func _test_assign_limits() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 10}})
	var mil: Military = world["mil"]
	var a: int = mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_NORTH)["id"]
	var b: int = mil.create_sector(PLAYER, Vector2i(16, 15), Military.DIR_NORTH)["id"]
	var ai_sector: int = mil.create_sector(AI_1, Vector2i(30, 15), Military.DIR_NORTH)["id"]
	_expect(errors, mil.set_sector_soldiers(a, 15), Military.ASSIGN_OK, "15 al primero")
	_signal_count = 0
	mil.changed.connect(_count_signal)
	_expect(errors, mil.set_sector_soldiers(b, 6), Military.ASSIGN_ERR_NOT_ENOUGH, "6 > 5 disponibles")
	_expect(errors, [mil.get_sector(b)["soldiers"], _counts(mil, PLAYER)], [0, [20, 15, 5]], "un rechazo no cambia nada")
	_expect(errors, mil.set_sector_soldiers(b, 5), Military.ASSIGN_OK, "justo los 5 disponibles")
	_expect(errors, mil.adjust_sector_soldiers(b, 1), Military.ASSIGN_ERR_NOT_ENOUGH, "ni uno más")
	_expect(errors, mil.set_sector_soldiers(a, 16), Military.ASSIGN_ERR_NOT_ENOUGH, "subir el primero sin reserva")
	_expect(errors, mil.set_sector_soldiers(a, 1000000), Military.ASSIGN_ERR_NOT_ENOUGH, "una cantidad enorme")
	_expect(errors, _counts(mil, PLAYER), [20, 20, 0], "el total asignado nunca supera el real")
	_expect(errors, mil.set_sector_soldiers(a, -1), Military.ASSIGN_ERR_NEGATIVE, "cantidad negativa")
	_expect(errors, mil.adjust_sector_soldiers(a, -16), Military.ASSIGN_ERR_NEGATIVE, "reducir por debajo de 0")
	_expect(errors, mil.get_sector(a)["soldiers"], 15, "el sector no cambió")
	_expect(errors, mil.set_sector_soldiers(999, 1), Military.ASSIGN_ERR_UNKNOWN_SECTOR, "sector inexistente (set)")
	_expect(errors, mil.adjust_sector_soldiers(999, 1), Military.ASSIGN_ERR_UNKNOWN_SECTOR, "sector inexistente (adjust)")
	_expect(errors, mil.set_sector_soldiers(-1, 0), Military.ASSIGN_ERR_UNKNOWN_SECTOR, "id -1")
	_expect(errors, _signal_count, 1, "solo la asignación válida de 5 emitió señal")
	# La reserva es por nación: los soldados de la IA no alimentan al jugador ni al revés.
	_expect(errors, mil.set_sector_soldiers(ai_sector, 11), Military.ASSIGN_ERR_NOT_ENOUGH, "la IA tiene 10, no 11")
	_expect(errors, mil.set_sector_soldiers(ai_sector, 10), Military.ASSIGN_OK, "la IA asigna sus 10")
	_expect(errors, [_counts(mil, PLAYER), _counts(mil, AI_1)], [[20, 20, 0], [10, 10, 0]], "reservas independientes")
	_expect(errors, mil.get_summary(PLAYER), {"total": 20, "assigned": 20, "available": 0}, "resumen del jugador")
	return errors


func _test_totals_coherent() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}})
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var ids: Array = []
	for index in 4:
		ids.append(mil.create_sector(PLAYER, Vector2i(14 + index, 15), Military.DIR_SOUTH)["id"])
	# Secuencia fija de órdenes (válidas e inválidas); el invariante se comprueba tras cada una.
	var operations := [[0, 6], [1, 7], [2, 8], [3, 1], [0, 0], [3, 9], [1, 20], [2, 0], [1, 3], [3, 12]]
	for item: Array in operations:
		mil.set_sector_soldiers(ids[item[0]], item[1])
		var assigned := 0
		for sector_id: int in ids:
			assigned += mil.get_sector(sector_id)["soldiers"]
		_expect(errors, mil.total_soldiers(PLAYER), pop.soldiers(PLAYER), "el total sale de Population")
		_expect(errors, mil.assigned_soldiers(PLAYER), assigned, "asignados = suma de los sectores")
		_expect(errors, mil.assigned_soldiers(PLAYER) + mil.available_soldiers(PLAYER), mil.total_soldiers(PLAYER), "asignados + disponibles = total")
		_expect(errors, mil.available_soldiers(PLAYER) >= 0 and mil.assigned_soldiers(PLAYER) <= mil.total_soldiers(PLAYER), true, "nunca se excede el total tras %s" % [item])
		var summary := mil.get_summary(PLAYER)
		_expect(errors, [summary["total"], summary["assigned"], summary["available"]], _counts(mil, PLAYER), "el resumen coincide")
	for unknown: int in [TerritoryGrid.OWNER_NONE, 99, -1]:
		_expect(errors, [mil.total_soldiers(unknown), mil.available_soldiers(unknown), mil.assigned_soldiers(unknown), mil.get_summary(unknown).is_empty()], [-1, -1, 0, true], "nación inexistente %d" % unknown)
	# Una nación sin sectores tiene todo disponible.
	_expect(errors, _counts(mil, AI_1), [0, 0, 0], "nación sin población ni sectores")
	return errors


func _test_remove_returns_soldiers() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}})
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var a: int = mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_NORTH)["id"]
	var b: int = mil.create_sector(PLAYER, Vector2i(16, 15), Military.DIR_NORTH)["id"]
	mil.set_sector_soldiers(a, 10)
	mil.set_sector_soldiers(b, 5)
	_expect(errors, _counts(mil, PLAYER), [20, 15, 5], "antes de eliminar")
	_signal_count = 0
	mil.changed.connect(_count_signal)
	_expect(errors, mil.remove_sector(a), true, "eliminar el primero")
	_expect(errors, _counts(mil, PLAYER), [20, 5, 15], "sus 10 soldados vuelven a la reserva")
	_expect(errors, [mil.has_sector(a), mil.get_sector(a).is_empty(), mil.sector_count()], [false, true, 1], "el sector ya no existe")
	_expect(errors, [pop.soldiers(PLAYER), pop.workers(PLAYER)], [20, 30], "la población no cambia")
	_expect(errors, mil.remove_sector(a), false, "eliminar dos veces falla")
	_expect(errors, mil.remove_sector(999), false, "eliminar un sector inexistente falla")
	_expect(errors, _signal_count, 1, "solo la eliminación real emite señal")
	_expect(errors, mil.set_sector_soldiers(a, 1), Military.ASSIGN_ERR_UNKNOWN_SECTOR, "no se puede asignar a un sector eliminado")
	# Los soldados liberados se pueden reasignar a otro sector.
	_expect(errors, mil.set_sector_soldiers(b, 20), Military.ASSIGN_OK, "reasignar la reserva completa a otro sector")
	_expect(errors, _counts(mil, PLAYER), [20, 20, 0], "toda la fuerza en un solo sector")
	mil.remove_sector(b)
	_expect(errors, [_counts(mil, PLAYER), mil.sector_count()], [[20, 0, 20], 0], "sin sectores, todo disponible")
	return errors


## Con la IA 1 sin recursos (sin ciudades) y 40 soldados, el déficit les hace desertar poco a poco.
## Dos sectores (el segundo es el más nuevo) reparten los 40; al bajar el total se quita primero
## del más nuevo, sin eliminar ningún sector.
func _test_soldier_loss_correction() -> Array:
	var errors: Array = []
	var world := _make_world({AI_1: {"workers": 250, "soldiers": 40}, PLAYER: {"workers": 30, "soldiers": 20}})
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var cities: CityManager = world["cities"]
	var old_sector: int = mil.create_sector(AI_1, Vector2i(30, 15), Military.DIR_NORTH)["id"]
	var new_sector: int = mil.create_sector(AI_1, Vector2i(31, 15), Military.DIR_NORTH)["id"]
	var player_sector: int = mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_NORTH)["id"]
	mil.set_sector_soldiers(old_sector, 30)
	mil.set_sector_soldiers(new_sector, 10)
	mil.set_sector_soldiers(player_sector, 4)
	_expect(errors, _counts(mil, AI_1), [40, 40, 0], "toda la fuerza de la IA está asignada")
	var lowest := 40
	for tick in range(1, 61):
		cities.advance(1.0)
		var soldiers := pop.soldiers(AI_1)
		lowest = mini(lowest, soldiers)
		var expected_old := mini(30, soldiers)
		var expected_new := maxi(0, mini(10, soldiers - 30))
		_expect(errors, [mil.get_sector(old_sector)["soldiers"], mil.get_sector(new_sector)["soldiers"]], [expected_old, expected_new], "tick %d: el exceso sale primero del sector más nuevo (soldados %d)" % [tick, soldiers])
		_expect(errors, mil.total_soldiers(AI_1), soldiers, "tick %d: el total sigue siendo el de Population" % tick)
		_expect(errors, mil.assigned_soldiers(AI_1) <= soldiers, true, "tick %d: nunca más asignados que soldados" % tick)
		_expect(errors, mil.available_soldiers(AI_1), 0, "tick %d: los soldados perdidos no vuelven a la reserva" % tick)
		_expect(errors, mil.sector_count(), 3, "tick %d: ningún sector se elimina por la corrección" % tick)
	_expect(errors, lowest < 40, true, "el déficit sí hizo desertar soldados")
	_expect(errors, lowest, 0, "tras 60 ticks la IA se quedó sin soldados")
	_expect(errors, [mil.get_sector(old_sector)["soldiers"], mil.get_sector(new_sector)["soldiers"]], [0, 0], "los sectores quedan vacíos pero existen")
	_expect(errors, mil.get_sector(player_sector)["soldiers"] <= 4, true, "el jugador no pierde soldados asignados por el déficit ajeno")
	# La corrección es idempotente y no hace nada si no hay exceso.
	_expect(errors, mil.enforce_soldier_limits(), 0, "sin exceso no se quita nada")
	return errors


func _test_no_side_effects() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 10}})
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	var grid: TerritoryGrid = world["grid"]
	_advance(world, 20)  # algo de historia: recursos acumulados, ciudad creciendo
	var before := _snapshot(world)
	_signal_count = 0
	pop.changed.connect(_count_signal)
	economy.balances_changed.connect(_count_signal)
	cities.changed.connect(_count_signal)
	grid.ownership_changed.connect(_count_signal)
	var a: int = mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_EAST)["id"]
	var b: int = mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_WEST)["id"]
	var soldiers: int = pop.soldiers(PLAYER)
	mil.set_sector_soldiers(a, soldiers)
	mil.adjust_sector_soldiers(a, -3)
	mil.set_sector_soldiers(b, 3)
	mil.remove_sector(a)
	mil.remove_sector(b)
	mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_EAST)
	_expect(errors, _signal_count, 0, "ninguna orden militar emite señales de población, economía, ciudades o territorio")
	_expect(errors, _snapshot(world) == before, true, "población, economía, ciudades y territorio idénticos")
	_expect(errors, [pop.workers(PLAYER), pop.soldiers(PLAYER)], [before["nations"][PLAYER]["workers"], before["nations"][PLAYER]["soldiers"]], "no se convirtieron trabajadores en soldados")
	return errors


func _test_mobilization_compat() -> Array:
	var errors: Array = []
	var world := _make_maxed_world({PLAYER: {"workers": 200, "soldiers": 40}})
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var a: int = mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_NORTH)["id"]
	var b: int = mil.create_sector(PLAYER, Vector2i(16, 15), Military.DIR_NORTH)["id"]
	mil.set_sector_soldiers(a, 30)
	mil.set_sector_soldiers(b, 10)
	_expect(errors, _counts(mil, PLAYER), [40, 40, 0], "toda la fuerza actual está asignada")
	_expect(errors, pop.start_mobilization(PLAYER, 50), Population.MOB_OK, "se inicia una movilización (100 trabajadores)")
	_expect(errors, [_counts(mil, PLAYER), pop.total_population(PLAYER)], [[40, 40, 0], 240], "la orden no cambia asignaciones ni población")
	_expect(errors, mil.set_sector_soldiers(a, 31), Military.ASSIGN_ERR_NOT_ENOUGH, "los trabajadores reservados aún no son soldados: no se pueden asignar")
	_advance(world, 15)
	_expect(errors, pop.soldiers(PLAYER), 90, "a mitad de plazo se han convertido 50")
	_expect(errors, _counts(mil, PLAYER), [90, 40, 50], "la reserva sube exactamente lo convertido; lo asignado no se duplica")
	_expect(errors, pop.total_population(PLAYER), 240, "la población total no cambia")
	_expect(errors, mil.set_sector_soldiers(a, 80), Military.ASSIGN_OK, "ahora sí se pueden asignar los nuevos soldados")
	_expect(errors, mil.set_sector_soldiers(a, 81), Military.ASSIGN_ERR_NOT_ENOUGH, "pero solo los que existen")
	_advance(world, 15)
	_expect(errors, _counts(mil, PLAYER), [140, 90, 50], "al terminar: 140 soldados, 90 asignados, 50 disponibles")
	_expect(errors, mil.assigned_soldiers(PLAYER) + mil.available_soldiers(PLAYER), pop.soldiers(PLAYER), "asignados + disponibles = soldados reales")
	_expect(errors, pop.workers(PLAYER), 100, "los trabajadores que quedan son los esperados")
	# El reparto de la población nueva no toca lo asignado.
	pop.set_new_soldier_percent(PLAYER, 100)
	_expect(errors, _counts(mil, PLAYER), [140, 90, 50], "cambiar el reparto de población nueva no cambia las asignaciones")
	return errors


func _test_conquest_effects() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 10}})
	var mil: Military = world["mil"]
	var grid: TerritoryGrid = world["grid"]
	var lost_origin: int = mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_EAST)["id"]
	var kept: int = mil.create_sector(PLAYER, Vector2i(23, 15), Military.DIR_EAST)["id"]
	mil.set_sector_soldiers(lost_origin, 7)
	mil.set_sector_soldiers(kept, 6)
	_expect(errors, _counts(mil, PLAYER), [20, 13, 7], "antes de la conquista")
	_signal_count = 0
	mil.changed.connect(_count_signal)
	var result := grid.conquer_cells(AI_1, [Vector2i(24, 15)])
	_expect(errors, result["ok"], true, "la IA conquista (24, 15) por la vía explícita")
	_expect(errors, [mil.has_sector(lost_origin), mil.has_sector(kept)], [false, true], "el sector cuyo origen se perdió desaparece; el otro sigue")
	_expect(errors, _counts(mil, PLAYER), [20, 6, 14], "los 7 soldados del sector perdido vuelven a la reserva")
	_expect(errors, mil.target_owner(kept), AI_1, "el objetivo del sector que sigue ahora es de la IA")
	_expect(errors, _signal_count, 1, "se avisa una vez del cambio")
	# Una conquista que no afecta a ningún origen no toca los sectores.
	var count_before := mil.sector_count()
	grid.conquer_cells(AI_1, [Vector2i(24, 20)])
	_expect(errors, [mil.sector_count(), _counts(mil, PLAYER)], [count_before, [20, 6, 14]], "una conquista ajena a los orígenes no cambia nada")
	return errors


func _test_texts() -> Array:
	var errors: Array = []
	_expect(errors, MilitaryPanel.summary_text({"total": 6, "assigned": 2, "available": 4}), "Soldados 6\nAsignados 2\nDisponibles 4", "resumen")
	_expect(errors, MilitaryPanel.summary_text({}), "Sin ejército", "resumen vacío")
	_expect(errors, MilitaryPanel.plan_text(MilitaryPanel.NO_CELL, MilitaryPanel.NO_DIRECTION, Military.SECTOR_OK), "Selecciona una celda propia en el mapa.", "sin celda")
	_expect(errors, MilitaryPanel.plan_text(Vector2i(12, 12), MilitaryPanel.NO_DIRECTION, Military.SECTOR_OK), "Origen (12, 12)\nElige una dirección.", "sin dirección")
	_expect(errors, MilitaryPanel.plan_text(Vector2i(12, 12), Military.DIR_EAST, Military.SECTOR_OK), "Origen (12, 12)\nObjetivo (13, 12) · Este\nListo para crear.", "plan válido")
	_expect(errors, MilitaryPanel.plan_text(Vector2i(10, 12), Military.DIR_WEST, Military.SECTOR_ERR_TARGET_WATER), "Origen (10, 12)\nObjetivo (9, 12) · Oeste\nEl objetivo es agua.", "plan con error")
	_expect(errors, [MilitaryPanel.adjust_button_text(5), MilitaryPanel.adjust_button_text(-1)], ["+5", "-1"], "botones de ajuste")
	var sector := {"id": 3, "owner": PLAYER, "origin": Vector2i(12, 12), "direction": Military.DIR_SOUTH, "target": Vector2i(12, 13), "soldiers": 5}
	_expect(errors, MilitaryPanel.list_item_text(sector), "#3 (12,12) S · 5", "línea de la lista")
	_expect(errors, MilitaryPanel.detail_text(sector, "Sin reclamar"), "Sector #3 · Sur\nOrigen (12, 12)\nObjetivo (12, 13)\nSin reclamar\nSoldados 5", "detalle")
	for code in range(Military.SECTOR_OK, Military.SECTOR_ERR_DUPLICATE + 1):
		_expect(errors, Military.sector_error_message(code) != "" and Military.sector_error_message(code) != "Error desconocido.", true, "mensaje de creación %d" % code)
	for code in range(Military.ASSIGN_OK, Military.ASSIGN_ERR_NOT_ENOUGH + 1):
		_expect(errors, Military.assign_error_message(code) != "" and Military.assign_error_message(code) != "Error desconocido.", true, "mensaje de asignación %d" % code)
	_expect(errors, [Military.sector_error_message(99), Military.assign_error_message(99)], ["Error desconocido.", "Error desconocido."], "códigos desconocidos")
	return errors


func _test_screen() -> Array:
	var errors: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	var scene: PackedScene = load(SCREEN_PATH)
	_expect(errors, scene != null, true, "la escena %s carga" % SCREEN_PATH)
	if scene == null:
		return errors
	var screen: Screen = scene.instantiate()
	tree.root.add_child(screen)
	var grid: TerritoryGrid = screen.grid
	var cities: CityManager = screen.cities
	var pop: Population = screen.population
	var mil: Military = screen.military
	var panel: MilitaryPanel = screen.get_node("%Militar")
	var layer = screen.get_node("%Sectores")
	var view = screen.get_node("%Mapa")
	_expect(errors, mil != null and panel != null and layer != null, true, "la pantalla crea el sistema militar, su panel y su capa")
	if mil == null or panel == null or layer == null:
		screen.free()
		return errors
	_expect(errors, panel.mouse_filter, Control.MOUSE_FILTER_STOP, "el panel captura el clic (no selecciona el mapa por error)")
	var names := ["ResumenMilitar", "PlanSector", "BotonDireccionNorte", "BotonDireccionEste", "BotonDireccionSur", "BotonDireccionOeste",
			"BotonCrearSector", "ListaSectores", "DetalleSector", "BotonAjusteMenos5", "BotonAjusteMenos1", "BotonAjusteMas1",
			"BotonAjusteMas5", "BotonLiberarSector", "MensajeMilitar"]
	for node_name: String in names:
		if panel.find_child(node_name, true, false) == null:
			errors.append("falta el control %s" % node_name)
	if not errors.is_empty():
		screen.free()
		return errors
	var summary_label: Label = panel.find_child("ResumenMilitar", true, false)
	var plan_label: Label = panel.find_child("PlanSector", true, false)
	var detail_label: Label = panel.find_child("DetalleSector", true, false)
	var east: Button = panel.find_child("BotonDireccionEste", true, false)
	var north: Button = panel.find_child("BotonDireccionNorte", true, false)
	var create: Button = panel.find_child("BotonCrearSector", true, false)
	var list: ItemList = panel.find_child("ListaSectores", true, false)
	var plus1: Button = panel.find_child("BotonAjusteMas1", true, false)
	var plus5: Button = panel.find_child("BotonAjusteMas5", true, false)
	var minus5: Button = panel.find_child("BotonAjusteMenos5", true, false)
	var release: Button = panel.find_child("BotonLiberarSector", true, false)
	var player_id: int = TerritoryGrid.OWNER_PLAYER
	var start_soldiers: int = PopulationBalance.INITIAL_POPULATION[player_id]["soldiers"]
	var owners_before := grid.copy_owner_data()
	var pop_before := [pop.workers(player_id), pop.soldiers(player_id)]
	# Estado inicial.
	_expect(errors, summary_label.text, MilitaryPanel.summary_text(mil.get_summary(player_id)), "el resumen sale de los datos")
	_expect(errors, mil.get_summary(player_id), {"total": start_soldiers, "assigned": 0, "available": start_soldiers}, "todos los soldados disponibles al empezar")
	_expect(errors, [create.disabled, list.item_count, release.disabled, plus1.disabled], [true, 0, true, true], "sin selección no se puede crear ni ajustar")
	# Seleccionar una celda propia en el mapa (la ciudad del jugador) y elegir dirección.
	var city_cell: Vector2i = Vector2i(-1, -1)
	for city_id: int in cities.get_city_ids():
		if cities.get_owner(city_id) == player_id:
			city_cell = cities.get_city(city_id)["cell"]
	view.pointer_pressed(view.cell_center_global(city_cell))
	_expect(errors, panel.chosen_origin(), city_cell, "la celda seleccionada en el mapa es el origen")
	_expect(errors, plan_label.text, MilitaryPanel.plan_text(city_cell, MilitaryPanel.NO_DIRECTION, Military.SECTOR_OK), "pide elegir dirección")
	_expect(errors, create.disabled, true, "sin dirección no se puede crear")
	east.pressed.emit()
	_expect(errors, [panel.chosen_direction(), east.button_pressed, north.button_pressed], [Military.DIR_EAST, true, false], "se elige el este")
	_expect(errors, [create.disabled, plan_label.text], [false, MilitaryPanel.plan_text(city_cell, Military.DIR_EAST, Military.SECTOR_OK)], "ya se puede crear y el plan se muestra")
	create.pressed.emit()
	_expect(errors, mil.sector_count(), 1, "se creó un sector")
	var sector_id: int = mil.get_sector_ids(player_id)[0]
	var sector := mil.get_sector(sector_id)
	_expect(errors, [sector["origin"], sector["direction"], sector["target"], sector["soldiers"]], [city_cell, Military.DIR_EAST, city_cell + Vector2i(1, 0), 0], "con los datos elegidos y 0 soldados")
	_expect(errors, [list.item_count, list.get_item_text(0)], [1, MilitaryPanel.list_item_text(sector)], "aparece en la lista")
	_expect(errors, [panel.selected_sector(), layer.highlighted_sector()], [sector_id, sector_id], "queda seleccionado y resaltado en el mapa")
	_expect(errors, detail_label.text, MilitaryPanel.detail_text(sector, "Tu territorio"), "el detalle muestra origen, objetivo, dirección y soldados")
	_expect(errors, create.disabled, true, "crear el mismo sector otra vez ya no es posible")
	# Ajustar soldados con los botones (con tope en lo disponible).
	plus5.pressed.emit()
	_expect(errors, [mil.get_sector(sector_id)["soldiers"], mil.available_soldiers(player_id)], [5, start_soldiers - 5], "+5 asigna 5")
	plus5.pressed.emit()
	_expect(errors, [mil.get_sector(sector_id)["soldiers"], mil.available_soldiers(player_id)], [start_soldiers, 0], "+5 sin reserva suficiente asigna solo lo que queda")
	_expect(errors, [plus1.disabled, plus5.disabled, minus5.disabled], [true, true, false], "sin reserva no se puede subir más")
	_expect(errors, [summary_label.text, list.get_item_text(0)], [MilitaryPanel.summary_text(mil.get_summary(player_id)), MilitaryPanel.list_item_text(mil.get_sector(sector_id))], "resumen y lista se actualizan")
	minus5.pressed.emit()
	_expect(errors, mil.get_sector(sector_id)["soldiers"], maxi(0, start_soldiers - 5), "-5 devuelve a la reserva")
	_expect(errors, [pop.workers(player_id), pop.soldiers(player_id)], pop_before, "la población no cambió con las asignaciones")
	# Seleccionar un sector desde la lista (como un clic) y comprobar el resaltado.
	panel.select_sector(Military.NO_SECTOR)
	_expect(errors, [panel.selected_sector(), layer.highlighted_sector(), release.disabled, detail_label.text], [Military.NO_SECTOR, Military.NO_SECTOR, true, "Selecciona un sector de la lista."], "sin sector elegido")
	list.item_selected.emit(0)
	_expect(errors, [panel.selected_sector(), layer.highlighted_sector()], [sector_id, sector_id], "elegir en la lista selecciona y resalta el sector")
	# Una celda que no es del jugador no permite crear sectores.
	var enemy_cell: Vector2i = Vector2i(-1, -1)
	for city_id: int in cities.get_city_ids():
		if cities.get_owner(city_id) == TerritoryGrid.OWNER_AI_1:
			enemy_cell = cities.get_city(city_id)["cell"]
	view.pointer_pressed(view.cell_center_global(enemy_cell))
	_expect(errors, [create.disabled, plan_label.text.contains(Military.sector_error_message(Military.SECTOR_ERR_ORIGIN_NOT_OWNED))], [true, true], "una celda ajena no permite crear y se explica por qué")
	# Liberar: elimina el sector y devuelve todo a la reserva.
	release.pressed.emit()
	_expect(errors, [mil.sector_count(), list.item_count, panel.selected_sector(), layer.highlighted_sector()], [0, 0, Military.NO_SECTOR, Military.NO_SECTOR], "el sector se eliminó y ya no está elegido")
	_expect(errors, mil.get_summary(player_id), {"total": start_soldiers, "assigned": 0, "available": start_soldiers}, "todos los soldados vuelven a la reserva")
	_expect(errors, [pop.workers(player_id), pop.soldiers(player_id)], pop_before, "y la población sigue igual")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ningún control cambió el territorio")
	# El tiempo sigue funcionando con la capa militar en pantalla.
	cities.advance(5.0)
	_expect(errors, summary_label.text, MilitaryPanel.summary_text(mil.get_summary(player_id)), "el resumen sigue la población con el tiempo")
	screen.free()
	return errors


func _test_previous_systems_unchanged() -> Array:
	var errors: Array = []
	var initial := {PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 10}}
	var with_military := _make_world(initial)
	var control := _make_world(initial)
	var mil: Military = with_military["mil"]
	var sector_ids: Array = []
	for index in 3:
		sector_ids.append(mil.create_sector(PLAYER, Vector2i(14 + index, 15), Military.DIR_NORTH)["id"])
	for world: Dictionary in [with_military, control]:
		var pop: Population = world["pop"]
		pop.start_mobilization(PLAYER, 25)
		pop.set_city_priority(PLAYER, 1, true)
		pop.set_new_soldier_percent(PLAYER, 40)
	# 150 ticks; con sectores se asigna, se reajusta y se libera mientras tanto.
	for tick in 150:
		_advance(with_military, 1)
		_advance(control, 1)
		match tick % 30:
			0:
				for sector_id: int in sector_ids:
					mil.set_sector_soldiers(sector_id, mini(4, mil.get_sector(sector_id)["soldiers"] + mil.available_soldiers(PLAYER)))
			10:
				mil.adjust_sector_soldiers(sector_ids[0], 2)
				mil.adjust_sector_soldiers(sector_ids[1], -1)
			20:
				mil.remove_sector(sector_ids[2])
				sector_ids[2] = mil.create_sector(PLAYER, Vector2i(16, 15), Military.DIR_NORTH)["id"]
		if _snapshot(with_military) != _snapshot(control):
			errors.append("población, economía, ciudades o territorio difieren del mundo de control en el tick %d" % (tick + 1))
			break
	_expect(errors, mil.assigned_soldiers(PLAYER) <= mil.total_soldiers(PLAYER), true, "las asignaciones nunca superan el total real")
	# Comportamiento territorial anterior: try_set_owner y conquer_cells siguen validando igual.
	var grid: TerritoryGrid = with_military["grid"]
	_expect(errors, grid.try_set_owner(5, 5, PLAYER), false, "try_set_owner sigue rechazando propietarios en el agua")
	_expect(errors, grid.conquer_cells(PLAYER, [Vector2i(5, 5)])["error"], TerritoryGrid.CONQUEST_ERR_WATER, "conquer_cells sigue rechazando el agua")
	return errors


func _test_files_present() -> Array:
	var errors: Array = []
	for path: String in ["res://tests/territory_grid_tests.gd", "res://tests/territory_map_view_tests.gd",
			"res://tests/territory_conquest_tests.gd", "res://tests/territory_hud_tests.gd",
			"res://tests/city_economy_tests.gd", "res://tests/population_tests.gd",
			"res://tests/run_territory_tests.tscn", "res://tests/run_view_tests.tscn",
			"res://tests/run_conquest_tests.tscn", "res://tests/run_hud_tests.tscn",
			"res://tests/run_city_tests.tscn", "res://tests/run_population_tests.tscn",
			"res://tests/test_population.gd", "res://tests/test_military.gd", "res://tests/run_military_tests.tscn",
			"res://scripts/world/military.gd", "res://scripts/world/sector_layer_view.gd", "res://scripts/ui/military_panel.gd",
			"res://tests/test_province_data.gd", "res://tests/test_province_selection.gd"]:
		_expect(errors, FileAccess.file_exists(path), true, "existe " + path)
	return errors
