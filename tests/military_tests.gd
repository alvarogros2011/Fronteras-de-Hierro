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
const SectorLayer := preload("res://scripts/world/sector_layer_view.gd")

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
	_run("rechaza objetivos que ya son territorio propio", _test_rejects_own_target)
	_run("crear un sector con su cantidad inicial de soldados, de forma atómica", _test_create_with_soldiers)
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
	_run("marcadores del mapa: las cifras no se solapan y la del sector elegido siempre se ve", _test_label_layout)
	_run("pantalla: panel militar, selección de celda, dirección, cantidad, edición y liberación", _test_screen)
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


## Dos bloques de tierra en las esquinas del mapa (0..5 x 0..5 y 314..319 x 174..179): el jugador
## posee x <= 2 en la primera y y >= 177 en la segunda; el resto es tierra sin reclamar. Sirve para
## probar objetivos que caen fuera del mapa y sectores válidos que salen de una esquina.
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
			owners[y * TerritoryGrid.WIDTH + x] = PLAYER if x <= 2 else TerritoryGrid.OWNER_NONE
	for y in range(174, 180):
		for x in range(314, 320):
			terrain[y * TerritoryGrid.WIDTH + x] = TerritoryGrid.TERRAIN_LAND
			owners[y * TerritoryGrid.WIDTH + x] = PLAYER if y >= 177 else TerritoryGrid.OWNER_NONE
	var grid := TerritoryGrid.new()
	grid.load_from_data(terrain, owners)
	return grid


## Enclave: tierra x 15..25, y 13..27 de la IA 1, con tres celdas AISLADAS del jugador —(20, 20),
## (23, 16) y (23, 24)— y tierra sin reclamar al oeste de (20, 20). Desde (20, 20) las cuatro
## direcciones tienen un objetivo válido (tres de la IA 1 y uno sin reclamar), porque ningún vecino
## es del jugador.
func _make_enclave_grid() -> TerritoryGrid:
	var terrain := PackedByteArray()
	terrain.resize(TerritoryGrid.CELL_COUNT)
	terrain.fill(TerritoryGrid.TERRAIN_WATER)
	var owners := PackedByteArray()
	owners.resize(TerritoryGrid.CELL_COUNT)
	owners.fill(TerritoryGrid.OWNER_NONE)
	for y in range(13, 28):
		for x in range(15, 26):
			terrain[y * TerritoryGrid.WIDTH + x] = TerritoryGrid.TERRAIN_LAND
			owners[y * TerritoryGrid.WIDTH + x] = AI_1
	for cell: Vector2i in [Vector2i(20, 20), Vector2i(23, 16), Vector2i(23, 24)]:
		owners[cell.y * TerritoryGrid.WIDTH + cell.x] = PLAYER
	owners[20 * TerritoryGrid.WIDTH + 19] = TerritoryGrid.OWNER_NONE
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
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}}, _make_enclave_grid())
	var mil: Military = world["mil"]
	var grid: TerritoryGrid = world["grid"]
	var owners_before := grid.copy_owner_data()
	_expect(errors, mil.sector_count(), 0, "empieza sin sectores")
	_signal_count = 0
	mil.changed.connect(_count_signal)
	var origin := Vector2i(20, 20)
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
		_expect(errors, sector["soldiers"], 0, "un sector creado sin cantidad no tiene soldados")
		_expect(errors, mil.validate_sector(PLAYER, origin, direction), Military.SECTOR_ERR_DUPLICATE, "ahora ya existe (%d)" % direction)
	_expect(errors, _signal_count, 4, "cada creación emite changed una vez")
	_expect(errors, mil.sector_count(), 4, "cuatro sectores")
	_expect(errors, mil.get_sector_ids(PLAYER), ids, "ids en orden de creación")
	var unique: Dictionary = {}
	for sector_id: int in ids:
		unique[sector_id] = true
	_expect(errors, unique.size(), 4, "ids únicos")
	_expect(errors, [mil.target_owner(ids[0]), mil.target_owner(ids[1]), mil.target_owner(ids[2]), mil.target_owner(ids[3])], [AI_1, AI_1, AI_1, TerritoryGrid.OWNER_NONE], "objetivos: tres de la IA 1 y uno sin reclamar")
	_expect(errors, _counts(mil, PLAYER), [20, 0, 20], "crear sectores vacíos no asigna ni crea soldados")
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
	_expect(errors, mil.create_sector(AI_1, Vector2i(25, 15), Military.DIR_WEST)["ok"], true, "la IA puede planificar desde su propio territorio")
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
	_expect(errors, mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_EAST)["ok"], true, "hacia la frontera con la IA sí vale")
	_expect(errors, mil.sector_count(), 1, "solo el válido")
	# Objetivo fuera del mapa: esquinas.
	var corner := _make_world({PLAYER: {"workers": 30, "soldiers": 20}}, _make_corner_grid())
	var cmil: Military = corner["mil"]
	var cases := [
		[Vector2i(0, 0), Military.DIR_NORTH], [Vector2i(0, 0), Military.DIR_WEST],
		[Vector2i(319, 179), Military.DIR_EAST], [Vector2i(319, 179), Military.DIR_SOUTH],
		[Vector2i(2, 0), Military.DIR_NORTH], [Vector2i(0, 3), Military.DIR_WEST],
	]
	for item: Array in cases:
		var result := cmil.create_sector(PLAYER, item[0], item[1])
		_expect(errors, [result["ok"], result["error"]], [false, Military.SECTOR_ERR_TARGET_OUT_OF_BOUNDS], "objetivo fuera del mapa desde %s dirección %d" % [item[0], item[1]])
	_expect(errors, cmil.create_sector(PLAYER, Vector2i(2, 0), Military.DIR_EAST)["ok"], true, "desde la esquina hacia tierra sin reclamar vale")
	_expect(errors, cmil.create_sector(PLAYER, Vector2i(319, 177), Military.DIR_NORTH)["ok"], true, "desde la otra esquina hacia tierra sin reclamar vale")
	_expect(errors, cmil.sector_count(), 2, "solo los válidos")
	return errors


func _test_rejects_own_target() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 10}})
	var mil: Military = world["mil"]
	var grid: TerritoryGrid = world["grid"]
	var owners_before := grid.copy_owner_data()
	_signal_count = 0
	mil.changed.connect(_count_signal)
	# Dentro del territorio propio ningún sector es válido, sea cual sea la dirección.
	for direction in 4:
		var result := mil.create_sector(PLAYER, Vector2i(15, 15), direction)
		_expect(errors, [result["ok"], result["error"], result["id"]], [false, Military.SECTOR_ERR_TARGET_OWN, Military.NO_SECTOR], "objetivo propio en dirección %d" % direction)
		_expect(errors, mil.create_sector(PLAYER, Vector2i(15, 15), direction, 5)["error"], Military.SECTOR_ERR_TARGET_OWN, "con soldados iniciales también (%d)" % direction)
	# En la frontera, solo vale la dirección que sale del territorio.
	_expect(errors, mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_NORTH)["error"], Military.SECTOR_ERR_TARGET_OWN, "norte desde la frontera: sigue siendo propio")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_SOUTH)["error"], Military.SECTOR_ERR_TARGET_OWN, "sur desde la frontera: sigue siendo propio")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_WEST)["error"], Military.SECTOR_ERR_TARGET_OWN, "oeste desde la frontera: sigue siendo propio")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_EAST)["ok"], true, "este desde la frontera: territorio de la IA 1, vale")
	# La IA 1 tampoco puede apuntar a sí misma; sí a la tierra sin reclamar y al jugador.
	_expect(errors, mil.create_sector(AI_1, Vector2i(30, 15), Military.DIR_NORTH)["error"], Military.SECTOR_ERR_TARGET_OWN, "la IA 1 no puede apuntar a su propio territorio")
	_expect(errors, mil.create_sector(AI_1, Vector2i(34, 15), Military.DIR_EAST)["ok"], true, "tierra sin reclamar vale")
	_expect(errors, mil.create_sector(AI_1, Vector2i(25, 15), Military.DIR_WEST)["ok"], true, "territorio del jugador vale")
	# El agua se rechaza antes que lo propio, y un origen ajeno antes que el objetivo.
	_expect(errors, mil.create_sector(PLAYER, Vector2i(10, 15), Military.DIR_WEST)["error"], Military.SECTOR_ERR_TARGET_WATER, "el agua se reconoce como agua, no como propio")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(30, 15), Military.DIR_NORTH)["error"], Military.SECTOR_ERR_ORIGIN_NOT_OWNED, "origen ajeno")
	_expect(errors, mil.sector_count(), 3, "solo los tres sectores válidos")
	_expect(errors, _signal_count, 3, "los rechazos no emiten señal")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "rechazar objetivos propios no toca el territorio")
	return errors


func _test_create_with_soldiers() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}})
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var economy: Economy = world["economy"]
	var grid: TerritoryGrid = world["grid"]
	var owners_before := grid.copy_owner_data()
	var money_before := economy.get_money(PLAYER)
	var resources_before := economy.get_resources(PLAYER)
	_signal_count = 0
	mil.changed.connect(_count_signal)
	var first := mil.create_sector(PLAYER, Vector2i(24, 12), Military.DIR_EAST, 8)
	_expect(errors, [first["ok"], first["error"]], [true, Military.SECTOR_OK], "crear con 8 soldados")
	_expect(errors, [mil.get_sector(first["id"])["soldiers"], _counts(mil, PLAYER)], [8, [20, 8, 12]], "el sector nace con 8 y quedan 12 disponibles")
	_expect(errors, _signal_count, 1, "crear y asignar es una sola operación: una sola señal")
	var second := mil.create_sector(PLAYER, Vector2i(24, 13), Military.DIR_EAST, 12)
	_expect(errors, [second["ok"], _counts(mil, PLAYER)], [true, [20, 20, 0]], "se puede usar justo la reserva completa")
	_expect(errors, second["id"], first["id"] + 1, "ids consecutivos")
	# Rechazos atómicos: no queda ningún sector parcial, ni se gasta un id, ni se mueve la reserva.
	_signal_count = 0
	var rejected := mil.create_sector(PLAYER, Vector2i(24, 14), Military.DIR_EAST, 1)
	_expect(errors, [rejected["ok"], rejected["error"], rejected["id"]], [false, Military.SECTOR_ERR_SOLDIERS_NOT_ENOUGH, Military.NO_SECTOR], "sin reserva no se crea ni con 1 soldado")
	_expect(errors, [mil.sector_count(), mil.sector_at(Vector2i(24, 14), Military.DIR_EAST), _counts(mil, PLAYER), _signal_count], [2, Military.NO_SECTOR, [20, 20, 0], 0], "no queda sector vacío, la reserva no cambia y no hay señal")
	mil.set_sector_soldiers(second["id"], 2)
	_expect(errors, mil.create_sector(PLAYER, Vector2i(24, 14), Military.DIR_EAST, 11)["error"], Military.SECTOR_ERR_SOLDIERS_NOT_ENOUGH, "11 > 10 disponibles")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(24, 14), Military.DIR_EAST, -1)["error"], Military.SECTOR_ERR_SOLDIERS_NEGATIVE, "cantidad negativa")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(24, 14), Military.DIR_EAST, 1000000)["error"], Military.SECTOR_ERR_SOLDIERS_NOT_ENOUGH, "cantidad enorme")
	_expect(errors, [mil.sector_count(), _counts(mil, PLAYER)], [2, [20, 10, 10]], "ningún rechazo cambió nada")
	var third := mil.create_sector(PLAYER, Vector2i(24, 14), Military.DIR_EAST, 10)
	_expect(errors, [third["ok"], third["id"], _counts(mil, PLAYER)], [true, second["id"] + 1, [20, 20, 0]], "tras los rechazos, el siguiente id es consecutivo")
	# El orden de las comprobaciones: duplicado antes que cantidad; origen y objetivo antes que cantidad.
	_expect(errors, mil.create_sector(PLAYER, Vector2i(24, 12), Military.DIR_EAST, 99)["error"], Military.SECTOR_ERR_DUPLICATE, "duplicado antes que cantidad")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_EAST, 99)["error"], Military.SECTOR_ERR_TARGET_OWN, "objetivo propio antes que cantidad")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(30, 15), Military.DIR_EAST, 99)["error"], Military.SECTOR_ERR_ORIGIN_NOT_OWNED, "origen ajeno antes que cantidad")
	_expect(errors, mil.validate_sector(PLAYER, Vector2i(24, 15), Military.DIR_EAST, 1), Military.SECTOR_ERR_SOLDIERS_NOT_ENOUGH, "validate_sector admite la cantidad")
	_expect(errors, mil.validate_sector(PLAYER, Vector2i(24, 15), Military.DIR_EAST, 0), Military.SECTOR_OK, "y 0 soldados sigue siendo válido (sector vacío)")
	# Nada de esto toca población, economía ni territorio.
	_expect(errors, [pop.workers(PLAYER), pop.soldiers(PLAYER)], [30, 20], "la población no cambió")
	_expect(errors, [economy.get_money(PLAYER), economy.get_resources(PLAYER)], [money_before, resources_before], "ni el dinero ni los recursos")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ni el territorio")
	return errors


func _test_rejects_duplicates() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}}, _make_enclave_grid())
	var mil: Military = world["mil"]
	var first := mil.create_sector(PLAYER, Vector2i(20, 20), Military.DIR_EAST, 5)
	_expect(errors, first["ok"], true, "primer sector")
	_signal_count = 0
	mil.changed.connect(_count_signal)
	var again := mil.create_sector(PLAYER, Vector2i(20, 20), Military.DIR_EAST)
	_expect(errors, [again["ok"], again["error"], again["id"]], [false, Military.SECTOR_ERR_DUPLICATE, Military.NO_SECTOR], "mismo origen y dirección")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(20, 20), Military.DIR_EAST, 3)["error"], Military.SECTOR_ERR_DUPLICATE, "también con otra cantidad")
	_expect(errors, _signal_count, 0, "el rechazo no emite señal")
	_expect(errors, [mil.sector_count(), mil.get_sector(first["id"])["soldiers"], _counts(mil, PLAYER)], [1, 5, [20, 5, 15]], "el original no cambia")
	_expect(errors, mil.sector_at(Vector2i(20, 20), Military.DIR_EAST), first["id"], "sector_at lo encuentra")
	_expect(errors, mil.sector_at(Vector2i(20, 20), Military.DIR_WEST), Military.NO_SECTOR, "sector_at: otra dirección no existe")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(20, 20), Military.DIR_SOUTH)["ok"], true, "mismo origen, otra dirección: vale")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(23, 16), Military.DIR_EAST)["ok"], true, "otro origen, misma dirección: vale")
	# Tras eliminar se puede volver a crear, con un id nuevo.
	mil.remove_sector(first["id"])
	var recreated := mil.create_sector(PLAYER, Vector2i(20, 20), Military.DIR_EAST)
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
	# Objetivos sin reclamar y en tierra de otra nación coexisten.
	var unclaimed := mil.create_sector(AI_1, Vector2i(34, 15), Military.DIR_EAST)
	_expect(errors, [unclaimed["ok"], mil.target_owner(unclaimed["id"])], [true, TerritoryGrid.OWNER_NONE], "objetivo sin reclamar")
	_expect(errors, mil.create_sector(PLAYER, Vector2i(15, 15), Military.DIR_EAST)["error"], Military.SECTOR_ERR_TARGET_OWN, "un objetivo en territorio propio no vale")
	_expect(errors, mil.target_owner(999), TerritoryGrid.INVALID, "target_owner de un sector inexistente")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ni los sectores ni la asignación cambian el territorio")
	_expect(errors, _signal_count, 0, "ni emiten ownership_changed")
	return errors


func _test_assign_valid() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}})
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var a: int = mil.create_sector(PLAYER, Vector2i(24, 12), Military.DIR_EAST)["id"]
	var b: int = mil.create_sector(PLAYER, Vector2i(24, 13), Military.DIR_EAST)["id"]
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
	var a: int = mil.create_sector(PLAYER, Vector2i(24, 12), Military.DIR_EAST)["id"]
	var b: int = mil.create_sector(PLAYER, Vector2i(24, 13), Military.DIR_EAST)["id"]
	var ai_sector: int = mil.create_sector(AI_1, Vector2i(25, 15), Military.DIR_WEST)["id"]
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
		ids.append(mil.create_sector(PLAYER, Vector2i(24, 12 + index), Military.DIR_EAST)["id"])
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
	var a: int = mil.create_sector(PLAYER, Vector2i(24, 12), Military.DIR_EAST)["id"]
	var b: int = mil.create_sector(PLAYER, Vector2i(24, 13), Military.DIR_EAST)["id"]
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
	var old_sector: int = mil.create_sector(AI_1, Vector2i(25, 15), Military.DIR_WEST)["id"]
	var new_sector: int = mil.create_sector(AI_1, Vector2i(25, 16), Military.DIR_WEST)["id"]
	var player_sector: int = mil.create_sector(PLAYER, Vector2i(24, 12), Military.DIR_EAST)["id"]
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
	var b: int = mil.create_sector(PLAYER, Vector2i(24, 16), Military.DIR_EAST)["id"]
	var soldiers: int = pop.soldiers(PLAYER)
	mil.set_sector_soldiers(a, soldiers)
	mil.adjust_sector_soldiers(a, -3)
	mil.set_sector_soldiers(b, 3)
	mil.remove_sector(a)
	mil.remove_sector(b)
	mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_EAST, 4)
	mil.create_sector(PLAYER, Vector2i(24, 17), Military.DIR_EAST)
	_expect(errors, _signal_count, 0, "ninguna orden militar emite señales de población, economía, ciudades o territorio")
	_expect(errors, _snapshot(world) == before, true, "población, economía, ciudades y territorio idénticos")
	_expect(errors, [pop.workers(PLAYER), pop.soldiers(PLAYER)], [before["nations"][PLAYER]["workers"], before["nations"][PLAYER]["soldiers"]], "no se convirtieron trabajadores en soldados")
	return errors


func _test_mobilization_compat() -> Array:
	var errors: Array = []
	var world := _make_maxed_world({PLAYER: {"workers": 200, "soldiers": 40}})
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var a: int = mil.create_sector(PLAYER, Vector2i(24, 12), Military.DIR_EAST)["id"]
	var b: int = mil.create_sector(PLAYER, Vector2i(24, 13), Military.DIR_EAST)["id"]
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
	var lost_origin: int = mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_EAST, 7)["id"]
	var kept: int = mil.create_sector(PLAYER, Vector2i(24, 16), Military.DIR_EAST, 6)["id"]
	_expect(errors, _counts(mil, PLAYER), [20, 13, 7], "antes de la conquista")
	_signal_count = 0
	mil.changed.connect(_count_signal)
	var result := grid.conquer_cells(AI_1, [Vector2i(24, 15)])
	_expect(errors, result["ok"], true, "la IA conquista (24, 15) por la vía explícita")
	_expect(errors, [mil.has_sector(lost_origin), mil.has_sector(kept)], [false, true], "el sector cuyo origen se perdió desaparece; el otro sigue")
	_expect(errors, _counts(mil, PLAYER), [20, 6, 14], "los 7 soldados del sector perdido vuelven a la reserva")
	_expect(errors, mil.target_owner(kept), AI_1, "el objetivo del sector que sigue es de la IA")
	_expect(errors, _signal_count, 1, "se avisa una vez del cambio")
	# Si el objetivo pasa a ser del jugador, el sector se conserva (la regla se exige al crear).
	_expect(errors, grid.conquer_cells(PLAYER, [Vector2i(25, 16)])["ok"], true, "el jugador conquista el objetivo (25, 16)")
	_expect(errors, [mil.has_sector(kept), mil.target_owner(kept), _counts(mil, PLAYER)], [true, PLAYER, [20, 6, 14]], "el sector sigue, con el objetivo ya propio")
	# Una conquista que no afecta a ningún origen no toca los sectores.
	var count_before := mil.sector_count()
	grid.conquer_cells(AI_1, [Vector2i(24, 20)])
	_expect(errors, [mil.sector_count(), _counts(mil, PLAYER)], [count_before, [20, 6, 14]], "una conquista ajena a los orígenes no cambia nada")
	return errors


func _test_texts() -> Array:
	var errors: Array = []
	_expect(errors, MilitaryPanel.summary_text({"total": 6, "assigned": 2, "available": 4}), "Soldados 6\nAsignados 2\nDisponibles 4", "resumen")
	_expect(errors, MilitaryPanel.summary_text({}), "Sin ejército", "resumen vacío")
	_expect(errors, MilitaryPanel.amount_text(3, 6), "Soldados: 3 de 6", "cantidad elegida")
	var sector := {"id": 3, "owner": PLAYER, "origin": Vector2i(12, 12), "direction": Military.DIR_SOUTH, "target": Vector2i(12, 13), "soldiers": 5}
	_expect(errors, MilitaryPanel.list_item_text(sector), "#3 (12,12) S · 5", "línea de la lista")
	for code in range(Military.SECTOR_ERR_UNKNOWN_NATION, Military.SECTOR_ERR_SOLDIERS_NOT_ENOUGH + 1):
		_expect(errors, Military.attack_target_error_message(code) != "" and Military.attack_target_error_message(code) != "No se puede atacar desde ahí.", true, "mensaje de ataque %d" % code)
	for code in range(Military.SECTOR_OK, Military.SECTOR_ERR_SOLDIERS_NOT_ENOUGH + 1):
		_expect(errors, Military.sector_error_message(code) != "" and Military.sector_error_message(code) != "Error desconocido.", true, "mensaje de creación %d" % code)
	for code in range(Military.ASSIGN_OK, Military.ASSIGN_ERR_NOT_ENOUGH + 1):
		_expect(errors, Military.assign_error_message(code) != "" and Military.assign_error_message(code) != "Error desconocido.", true, "mensaje de asignación %d" % code)
	_expect(errors, [Military.sector_error_message(99), Military.assign_error_message(99)], ["Error desconocido.", "Error desconocido."], "códigos desconocidos")
	return errors


func _test_label_layout() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}})
	var mil: Military = world["mil"]
	var layer := SectorLayer.new()
	layer.setup(world["grid"], mil, PLAYER)
	_expect(errors, layer.label_layout(Vector2(1.0, 2.0)).is_empty(), true, "sin sectores no hay cifras")
	# Un solo sector: la cifra va a la derecha de la celda objetivo.
	var only: int = mil.create_sector(PLAYER, Vector2i(24, 12), Military.DIR_EAST, 5)["id"]
	var size := Vector2(1.0, 2.0)
	var layout := layer.label_layout(size)
	_expect(errors, layout.keys(), [only], "una cifra")
	_expect(errors, layout[only], Rect2(Vector2(25, 12) + Vector2(1.0 + SectorLayer.LABEL_GAP, 0.5 - size.y / 2.0), size), "a la derecha del objetivo")
	# Muchos sectores contiguos con cifras enormes (40 x 40 celdas): solo caben dos (derecha e izquierda
	# de la primera y la segunda); las demás se omiten en vez de solaparse.
	var ids: Array = [only]
	for y in range(13, 22):
		ids.append(mil.create_sector(PLAYER, Vector2i(24, y), Military.DIR_EAST, 1)["id"])
	var crowded := layer.label_layout(Vector2(40.0, 40.0))
	_expect(errors, crowded.keys(), [ids[0], ids[1]], "solo las dos primeras cifras caben")
	var rects: Array = crowded.values()
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				errors.append("las cifras %d y %d se solapan" % [i, j])
	_expect(errors, crowded.size() < ids.size(), true, "con tanta densidad se omiten cifras en vez de solaparlas")
	# El sector elegido siempre tiene cifra, aunque no quepa sin pisar otra; los demás siguen sin pisarse.
	var chosen: int = ids[ids.size() - 1]
	layer.set_highlight(chosen)
	_expect(errors, layer.highlighted_sector(), chosen, "el recuadro sigue al sector elegido")
	var with_chosen := layer.label_layout(Vector2(40.0, 40.0))
	_expect(errors, with_chosen.has(chosen), true, "la cifra del sector elegido siempre se dibuja")
	_expect(errors, with_chosen.size(), 3, "las dos primeras y la elegida")
	var others: Array = []
	for sector_id: int in with_chosen:
		if sector_id != chosen:
			others.append(with_chosen[sector_id])
	for i in others.size():
		for j in range(i + 1, others.size()):
			if others[i].intersects(others[j]):
				errors.append("dos cifras de sectores no elegidos se solapan")
	# Determinista: mismos datos, mismo reparto.
	_expect(errors, layer.label_layout(Vector2(40.0, 40.0)) == with_chosen, true, "el reparto es determinista")
	layer.free()
	return errors


## Primera celda del jugador y dirección con las que se puede crear un sector (o [NO_CELL, -1]).
func _find_sector_spot(grid: TerritoryGrid, mil: Military) -> Array:
	for y in TerritoryGrid.HEIGHT:
		for x in TerritoryGrid.WIDTH:
			if grid.get_cell_owner(x, y) != PLAYER:
				continue
			for direction in 4:
				if mil.validate_sector(PLAYER, Vector2i(x, y), direction) == Military.SECTOR_OK:
					return [Vector2i(x, y), direction]
	return [Vector2i(-1, -1), -1]


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
	var mil: Military = screen.military
	var panel: MilitaryPanel = screen.get_node("%Militar")
	var layer = screen.get_node("%Sectores")
	var view = screen.get_node("%Mapa")
	_expect(errors, mil != null and panel != null and layer != null, true, "la pantalla crea el sistema militar, su panel y su capa")
	if mil == null or panel == null or layer == null:
		screen.free()
		return errors
	_expect(errors, panel.mouse_filter, Control.MOUSE_FILTER_STOP, "el panel captura el clic (no selecciona el mapa por error)")
	var names := ["ResumenMilitar", "ObjetivoAtaque", "BotonDireccionNorte", "BotonDireccionEste", "BotonDireccionSur", "BotonDireccionOeste",
			"CantidadAtaque", "SliderAtaque", "BotonPorcentaje25", "BotonPorcentaje50", "BotonPorcentaje75", "BotonPorcentaje100", "BotonAtacar",
			"BotonAjustar", "BotonRetirar", "ListaSectores", "MensajeMilitar"]
	for node_name: String in names:
		if panel.find_child(node_name, true, false) == null:
			errors.append("falta el control %s" % node_name)
	for old_name: String in ["BotonAjusteMas1", "BotonAjusteMas5", "BotonAjusteMenos1", "BotonAjusteMenos5", "BotonCrearSector", "SliderNuevo", "SliderEdicion", "BotonAplicar", "BotonLiberarSector"]:
		if panel.find_child(old_name, true, false) != null:
			errors.append("sigue existiendo el control antiguo %s" % old_name)
	if not errors.is_empty():
		screen.free()
		return errors
	var summary_label: Label = panel.find_child("ResumenMilitar", true, false)
	var target_label: Label = panel.find_child("ObjetivoAtaque", true, false)
	var amount_label: Label = panel.find_child("CantidadAtaque", true, false)
	var slider: HSlider = panel.find_child("SliderAtaque", true, false)
	var message_label: Label = panel.find_child("MensajeMilitar", true, false)
	var attack: Button = panel.find_child("BotonAtacar", true, false)
	var adjust: Button = panel.find_child("BotonAjustar", true, false)
	var withdraw: Button = panel.find_child("BotonRetirar", true, false)
	var list: ItemList = panel.find_child("ListaSectores", true, false)
	var player_id: int = TerritoryGrid.OWNER_PLAYER
	var start_soldiers: int = PopulationBalance.INITIAL_POPULATION[player_id]["soldiers"]
	var owners_before := grid.copy_owner_data()
	var money_before := economy.get_money(player_id)
	var pop_before := [pop.workers(player_id), pop.soldiers(player_id)]
	# Estado inicial: todo disponible, nada que atacar.
	_expect(errors, summary_label.text, MilitaryPanel.summary_text(mil.get_summary(player_id)), "el resumen sale de los datos")
	_expect(errors, mil.get_summary(player_id), {"total": start_soldiers, "assigned": 0, "available": start_soldiers}, "todos los soldados disponibles al empezar")
	_expect(errors, [attack.disabled, list.item_count, adjust.visible, withdraw.visible], [true, 0, false, false], "sin objetivo no se puede atacar y no hay frentes que ajustar")
	# Una celda propia sin lado atacable no sirve: se explica por qué y no hay dirección.
	var city_cell: Vector2i = Vector2i(-1, -1)
	for city_id: int in cities.get_city_ids():
		if cities.get_owner(city_id) == player_id:
			city_cell = cities.get_city(city_id)["cell"]
	view.pointer_pressed(view.cell_center_global(city_cell))
	_expect(errors, [panel.chosen_origin(), panel.chosen_direction(), attack.disabled], [city_cell, MilitaryPanel.NO_DIRECTION, true], "la celda seleccionada en el mapa es el origen y sin lado atacable no hay dirección")
	panel.find_child("BotonDireccionEste", true, false).pressed.emit()
	_expect(errors, [attack.disabled, target_label.text.contains(Military.attack_target_error_message(Military.SECTOR_ERR_TARGET_OWN))], [true, true], "apuntar a territorio propio no se puede y se explica")
	attack.pressed.emit()
	_expect(errors, [mil.sector_count(), mil.assigned_soldiers(player_id), message_label.text], [0, 0, Military.attack_target_error_message(Military.SECTOR_ERR_TARGET_OWN)], "forzar el botón no crea nada ni consume soldados")
	# Un origen y una dirección válidos (el primero que encuentre la búsqueda).
	var spot := _find_sector_spot(grid, mil)
	_expect(errors, spot[1] >= 0, true, "el jugador tiene alguna frontera desde la que atacar")
	if spot[1] < 0:
		screen.free()
		return errors
	var origin: Vector2i = spot[0]
	view.pointer_pressed(view.cell_center_global(origin))
	_expect(errors, panel.chosen_origin(), origin, "nuevo origen")
	if panel.chosen_direction() == MilitaryPanel.NO_DIRECTION:
		panel.find_child("BotonDireccion" + Military.DIRECTION_NAMES[spot[1]], true, false).pressed.emit()
	var direction: int = panel.chosen_direction()
	_expect(errors, mil.validate_sector(player_id, origin, direction), Military.SECTOR_OK, "la dirección elegida (a mano o deducida) es atacable")
	_expect(errors, attack.disabled, false, "con origen y dirección válidos ya se puede atacar")
	# Cantidad: un único deslizador, limitado a la reserva.
	_expect(errors, [slider.min_value, slider.max_value], [1.0, float(start_soldiers)], "el deslizador va de 1 a todos los soldados disponibles")
	panel.set_amount(1000)
	_expect(errors, [panel.amount(), amount_label.text], [start_soldiers, MilitaryPanel.amount_text(start_soldiers, start_soldiers)], "no se puede elegir más que la reserva")
	panel.set_amount(-5)
	_expect(errors, panel.amount(), 1, "ni menos de 1")
	panel.set_amount(4)
	_expect(errors, [panel.amount(), amount_label.text], [4, MilitaryPanel.amount_text(4, start_soldiers)], "la cantidad elegida se muestra")
	_expect(errors, mil.sector_count(), 0, "elegir no crea nada todavía")
	# Una sola orden crea el frente ya asignado y lo lanza.
	attack.pressed.emit()
	_expect(errors, mil.sector_count(), 1, "se creó un frente")
	var sector_id: int = mil.get_sector_ids(player_id)[0]
	var sector := mil.get_sector(sector_id)
	_expect(errors, [sector["origin"], sector["direction"], sector["target"], sector["soldiers"]], [origin, direction, origin + Military.DIRECTION_STEPS[direction], 4], "con los datos elegidos y 4 soldados desde el principio")
	_expect(errors, mil.get_summary(player_id), {"total": start_soldiers, "assigned": 4, "available": start_soldiers - 4}, "4 asignados, el resto disponible")
	_expect(errors, summary_label.text, MilitaryPanel.summary_text(mil.get_summary(player_id)), "el resumen se actualiza")
	_expect(errors, [list.item_count, list.get_item_text(0)], [1, MilitaryPanel.list_item_text(sector, true)], "aparece en la lista como atacando")
	_expect(errors, [panel.selected_sector(), layer.highlighted_sector()], [sector_id, sector_id], "queda elegido y resaltado en el mapa")
	_expect(errors, [attack.text, withdraw.visible], ["Detener", true], "el botón principal pasa a «Detener»")
	attack.pressed.emit()  # se detiene antes de avanzar el tiempo: esta prueba trata de las asignaciones
	_expect(errors, attack.text, "Continuar", "y luego a «Continuar»")
	# Ajustar con el mismo deslizador.
	_expect(errors, [slider.max_value, slider.value, adjust.visible], [float(start_soldiers), 4.0, false], "el deslizador parte de la cantidad actual y llega hasta lo asignable")
	panel.set_amount(1000)
	_expect(errors, panel.amount(), start_soldiers, "no se puede ajustar por encima de lo asignable")
	_expect(errors, [mil.get_sector(sector_id)["soldiers"], adjust.visible, adjust.text], [4, true, "Ajustar a %d" % start_soldiers], "mover el deslizador no cambia nada hasta ajustar")
	adjust.pressed.emit()
	_expect(errors, [mil.get_sector(sector_id)["soldiers"], mil.available_soldiers(player_id)], [start_soldiers, 0], "ajustar toma toda la reserva")
	_expect(errors, [slider.editable, panel.amount()], [true, start_soldiers], "el frente conserva su cantidad en el deslizador")
	panel.set_amount(1)
	adjust.pressed.emit()
	_expect(errors, [mil.get_sector(sector_id)["soldiers"], mil.available_soldiers(player_id)], [1, start_soldiers - 1], "reducir devuelve a la reserva")
	_expect(errors, mil.set_sector_soldiers(sector_id, start_soldiers + 1), Military.ASSIGN_ERR_NOT_ENOUGH, "la lógica también impide pasarse de la reserva")
	_expect(errors, [pop.workers(player_id), pop.soldiers(player_id)], pop_before, "la población no cambió con las asignaciones")
	# Elegir otra celda no destruye el frente; la lista lo vuelve a elegir.
	var enemy_cell: Vector2i = Vector2i(-1, -1)
	for city_id: int in cities.get_city_ids():
		if cities.get_owner(city_id) == TerritoryGrid.OWNER_AI_1:
			enemy_cell = cities.get_city(city_id)["cell"]
	view.pointer_pressed(view.cell_center_global(enemy_cell))
	# Hito 11: pulsar una celda ajena lejana propone el frente desde la frontera propia más cercana.
	_expect(errors, [panel.chosen_origin() != MilitaryPanel.NO_CELL, panel.chosen_direction() != MilitaryPanel.NO_DIRECTION, attack.disabled], [true, true, false], "una celda ajena y lejana propone un frente desde tu frontera más cercana")
	_expect(errors, grid.get_cell_owner(panel.chosen_origin().x, panel.chosen_origin().y), player_id, "el origen propuesto es tuyo")
	_expect(errors, mil.sector_count(), 1, "pero el frente sigue existiendo")
	list.item_selected.emit(0)
	_expect(errors, [panel.selected_sector(), layer.highlighted_sector(), withdraw.visible], [sector_id, sector_id, true], "elegir en la lista selecciona y resalta el frente")
	# Retirar: elimina el frente y devuelve todo a la reserva.
	withdraw.pressed.emit()
	_expect(errors, [mil.sector_count(), list.item_count, panel.selected_sector(), layer.highlighted_sector(), withdraw.visible], [0, 0, Military.NO_SECTOR, Military.NO_SECTOR, false], "el frente se eliminó y ya no está elegido")
	_expect(errors, mil.get_summary(player_id), {"total": start_soldiers, "assigned": 0, "available": start_soldiers}, "todos los soldados vuelven a la reserva")
	_expect(errors, [pop.workers(player_id), pop.soldiers(player_id)], pop_before, "la población sigue igual")
	_expect(errors, economy.get_money(player_id), money_before, "el dinero no cambió")
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
		sector_ids.append(mil.create_sector(PLAYER, Vector2i(24, 12 + index), Military.DIR_EAST)["id"])
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
				sector_ids[2] = mil.create_sector(PLAYER, Vector2i(24, 14), Military.DIR_EAST, mini(2, mil.available_soldiers(PLAYER)))["id"]
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
