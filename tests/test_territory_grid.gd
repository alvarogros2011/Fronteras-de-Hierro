## Pruebas automáticas de la cuadrícula de territorio (hito 3). Sin plugins.
##
## Ejecución (desde la raíz del proyecto):
##   godot --headless --path . --script res://tests/test_territory_grid.gd
##
## Imprime PASS/FAIL por prueba y termina con código 0 si todo pasa o 1 si algo falla.
extends SceneTree

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")

const EXPECTED_WIDTH := 320
const EXPECTED_HEIGHT := 180
const EXPECTED_CELLS := 57600
const MIN_LAND_CELLS := 20000
const MIN_WATER_CELLS := 10000
const MIN_UNCLAIMED_LAND := 15000
const MIN_NATION_CELLS := 100
const MIN_COLOR_DISTANCE := 0.30

var _failed := 0
var _passed := 0
var _grid: TerritoryGrid


func _initialize() -> void:
	_grid = TerritoryGrid.new()
	_run("el mapa mide exactamente 320x180", _test_dimensions)
	_run("los dos arrays tienen exactamente 57.600 elementos", _test_array_sizes)
	_run("conversión coordenadas <-> índice (orden por filas)", _test_index_conversion)
	_run("coordenadas e índices fuera de límites se rechazan", _test_out_of_bounds)
	_run("el terreno solo contiene agua (0) o tierra (1)", _test_terrain_values)
	_run("IDs de las 4 naciones únicos y coherentes", _test_nation_ids)
	_run("metadatos de naciones: nombre, clave y colores contrastados", _test_nation_metadata)
	_run("no hay propietarios desconocidos", _test_no_unknown_owners)
	_run("el agua no tiene propietario y el borde del mapa es agua", _test_water_has_no_owner)
	_run("hay suficiente tierra y agua", _test_land_amount)
	_run("cada nación tiene un territorio inicial no vacío", _test_nations_not_empty)
	_run("cada territorio inicial está conectado (adyacencia ortogonal)", _test_nations_connected)
	_run("los territorios iniciales están separados entre sí", _test_nations_separated)
	_run("hay tierra sin reclamar", _test_unclaimed_land)
	_run("dos instancias producen la misma configuración", _test_determinism)
	_run("asignar un propietario válido a tierra sin reclamar", _test_valid_assignment)
	_run("se rechaza asignar una nación inexistente", _test_unknown_owner_rejected)
	_run("se rechaza asignar propietario al agua", _test_water_assignment_rejected)
	_run("una operación inválida no altera el estado", _test_invalid_operations_keep_state)
	_run("consulta de naciones por ID y por clave", _test_nation_queries)
	_run("reset_to_default restaura el mapa inicial", _test_reset)
	print("")
	print("Resultado: %d PASS, %d FAIL" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Ejecuta una prueba. Cada prueba devuelve un Array de mensajes de error (vacío = PASS).
func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	if errors.is_empty():
		_passed += 1
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		print("FAIL: %s" % test_name)
		for error: String in errors:
			print("      - %s" % error)


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


## Primera celda (en orden de índice) con ese terreno y propietario, o Vector2i(-1, -1).
func _find_cell(grid: TerritoryGrid, terrain: int, owner_id: int) -> Vector2i:
	for index in EXPECTED_CELLS:
		if grid.terrain_at(index) == terrain and grid.owner_at(index) == owner_id:
			return grid.index_to_coord(index)
	return Vector2i(-1, -1)


func _test_dimensions() -> Array:
	var errors := []
	_expect(errors, _grid.get_width(), EXPECTED_WIDTH, "ancho")
	_expect(errors, _grid.get_height(), EXPECTED_HEIGHT, "alto")
	_expect(errors, TerritoryGrid.CELL_COUNT, EXPECTED_CELLS, "número de celdas")
	return errors


func _test_array_sizes() -> Array:
	var errors := []
	_expect(errors, _grid.copy_terrain_data().size(), EXPECTED_CELLS, "tamaño del array de terreno")
	_expect(errors, _grid.copy_owner_data().size(), EXPECTED_CELLS, "tamaño del array de propietario")
	return errors


func _test_index_conversion() -> Array:
	var errors := []
	_expect(errors, _grid.coord_to_index(0, 0), 0, "índice de (0,0)")
	_expect(errors, _grid.coord_to_index(1, 0), 1, "índice de (1,0)")
	_expect(errors, _grid.coord_to_index(0, 1), EXPECTED_WIDTH, "índice de (0,1)")
	_expect(errors, _grid.coord_to_index(319, 179), EXPECTED_CELLS - 1, "índice de la última celda")
	_expect(errors, _grid.coord_to_index(10, 20), 20 * EXPECTED_WIDTH + 10, "índice de (10,20)")
	_expect(errors, _grid.index_to_coord(EXPECTED_CELLS - 1), Vector2i(319, 179), "coordenadas de la última celda")
	# Ida y vuelta para TODAS las celdas.
	var round_trip_errors := 0
	for y in EXPECTED_HEIGHT:
		for x in EXPECTED_WIDTH:
			var index := _grid.coord_to_index(x, y)
			if index != y * EXPECTED_WIDTH + x or _grid.index_to_coord(index) != Vector2i(x, y):
				round_trip_errors += 1
	_expect(errors, round_trip_errors, 0, "celdas con conversión de ida y vuelta incorrecta")
	return errors


func _test_out_of_bounds() -> Array:
	var errors := []
	var invalid_coords := [
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(320, 0), Vector2i(0, 180),
		Vector2i(320, 180), Vector2i(-5, -5), Vector2i(100000, 3),
	]
	for coord: Vector2i in invalid_coords:
		_expect(errors, _grid.is_valid_coord(coord.x, coord.y), false, "is_valid_coord%s" % coord)
		_expect(errors, _grid.coord_to_index(coord.x, coord.y), TerritoryGrid.INVALID, "coord_to_index%s" % coord)
		_expect(errors, _grid.get_cell_terrain(coord.x, coord.y), TerritoryGrid.INVALID, "terreno en %s" % coord)
		_expect(errors, _grid.get_cell_owner(coord.x, coord.y), TerritoryGrid.INVALID, "propietario en %s" % coord)
		_expect(errors, _grid.is_land(coord.x, coord.y), false, "is_land%s" % coord)
	for index in [-1, EXPECTED_CELLS, EXPECTED_CELLS + 7]:
		_expect(errors, _grid.is_valid_index(index), false, "is_valid_index(%d)" % index)
		_expect(errors, _grid.index_to_coord(index), Vector2i(-1, -1), "index_to_coord(%d)" % index)
		_expect(errors, _grid.terrain_at(index), TerritoryGrid.INVALID, "terrain_at(%d)" % index)
		_expect(errors, _grid.owner_at(index), TerritoryGrid.INVALID, "owner_at(%d)" % index)
	_expect(errors, _grid.is_valid_coord(0, 0), true, "is_valid_coord(0,0)")
	_expect(errors, _grid.is_valid_coord(319, 179), true, "is_valid_coord(319,179)")
	return errors


func _test_terrain_values() -> Array:
	var errors := []
	var invalid := 0
	for index in EXPECTED_CELLS:
		var terrain := _grid.terrain_at(index)
		if terrain != TerritoryGrid.TERRAIN_WATER and terrain != TerritoryGrid.TERRAIN_LAND:
			invalid += 1
	_expect(errors, invalid, 0, "celdas con terreno no válido")
	_expect(errors, TerritoryGrid.TERRAIN_WATER, 0, "valor de WATER")
	_expect(errors, TerritoryGrid.TERRAIN_LAND, 1, "valor de LAND")
	return errors


func _test_nation_ids() -> Array:
	var errors := []
	_expect(errors, TerritoryGrid.OWNER_NONE, 0, "OWNER_NONE")
	_expect(errors, TerritoryGrid.OWNER_PLAYER, 1, "OWNER_PLAYER")
	_expect(errors, TerritoryGrid.OWNER_AI_1, 2, "OWNER_AI_1")
	_expect(errors, TerritoryGrid.OWNER_AI_2, 3, "OWNER_AI_2")
	_expect(errors, TerritoryGrid.OWNER_AI_3, 4, "OWNER_AI_3")
	var ids := _grid.get_nation_ids()
	_expect(errors, ids, [1, 2, 3, 4], "lista de IDs de naciones")
	var seen := {}
	for nation_id: int in ids:
		if seen.has(nation_id):
			errors.append("ID de nación repetido: %d" % nation_id)
		seen[nation_id] = true
		_expect(errors, _grid.get_nation(nation_id).get("id"), nation_id, "campo id de la nación %d" % nation_id)
	_expect(errors, _grid.has_nation(TerritoryGrid.OWNER_NONE), false, "OWNER_NONE no es una nación")
	return errors


func _test_nation_metadata() -> Array:
	var errors := []
	var keys := {}
	var names := {}
	var ids := _grid.get_nation_ids()
	for nation_id: int in ids:
		var nation := _grid.get_nation(nation_id)
		var key: String = nation.get("key", "")
		var nation_name: String = nation.get("name", "")
		var color: Color = nation.get("color", Color(0, 0, 0, 0))
		if key.is_empty() or key != key.to_lower() or key.contains(" "):
			errors.append("clave no válida en la nación %d: '%s'" % [nation_id, key])
		if nation_name.strip_edges().is_empty():
			errors.append("nombre vacío en la nación %d" % nation_id)
		if keys.has(key):
			errors.append("clave repetida: %s" % key)
		if names.has(nation_name):
			errors.append("nombre repetido: %s" % nation_name)
		keys[key] = true
		names[nation_name] = true
		if not is_equal_approx(color.a, 1.0):
			errors.append("el color de %s debe ser opaco" % key)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Color = _grid.get_nation(ids[i])["color"]
			var b: Color = _grid.get_nation(ids[j])["color"]
			var distance := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			if distance < MIN_COLOR_DISTANCE:
				errors.append("colores poco contrastados entre %d y %d (distancia %.2f)" % [ids[i], ids[j], distance])
	return errors


func _test_no_unknown_owners() -> Array:
	var errors := []
	var unknown := 0
	for index in EXPECTED_CELLS:
		var owner_id := _grid.owner_at(index)
		if owner_id != TerritoryGrid.OWNER_NONE and not _grid.has_nation(owner_id):
			unknown += 1
	_expect(errors, unknown, 0, "celdas con propietario desconocido")
	return errors


func _test_water_has_no_owner() -> Array:
	var errors := []
	var owned_water := 0
	for index in EXPECTED_CELLS:
		if _grid.terrain_at(index) == TerritoryGrid.TERRAIN_WATER and _grid.owner_at(index) != TerritoryGrid.OWNER_NONE:
			owned_water += 1
	_expect(errors, owned_water, 0, "celdas de agua con propietario")
	var land_on_edge := 0
	for x in EXPECTED_WIDTH:
		land_on_edge += int(_grid.is_land(x, 0)) + int(_grid.is_land(x, EXPECTED_HEIGHT - 1))
	for y in EXPECTED_HEIGHT:
		land_on_edge += int(_grid.is_land(0, y)) + int(_grid.is_land(EXPECTED_WIDTH - 1, y))
	_expect(errors, land_on_edge, 0, "celdas de tierra en el borde del mapa")
	return errors


func _test_land_amount() -> Array:
	var errors := []
	var land := _grid.count_land()
	var water := EXPECTED_CELLS - land
	if land < MIN_LAND_CELLS:
		errors.append("tierra insuficiente: %d celdas (mínimo %d)" % [land, MIN_LAND_CELLS])
	if water < MIN_WATER_CELLS:
		errors.append("agua insuficiente: %d celdas (mínimo %d)" % [water, MIN_WATER_CELLS])
	return errors


func _test_nations_not_empty() -> Array:
	var errors := []
	for nation_id: int in _grid.get_nation_ids():
		var count := _grid.count_owned_by(nation_id)
		if count < MIN_NATION_CELLS:
			errors.append("la nación %d tiene solo %d celdas (mínimo %d)" % [nation_id, count, MIN_NATION_CELLS])
	return errors


## Comprobación independiente de la lógica interna de la cuadrícula: recorrido en anchura
## sobre los datos copiados, con adyacencia ortogonal (arriba, abajo, izquierda, derecha).
func _count_reachable(owner_data: PackedByteArray, start: int, owner_id: int) -> int:
	var visited := {}
	var queue: Array = [start]
	visited[start] = true
	var head := 0
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		var x := index % EXPECTED_WIDTH
		var y := index / EXPECTED_WIDTH
		var neighbors: Array = []
		if x > 0:
			neighbors.append(index - 1)
		if x < EXPECTED_WIDTH - 1:
			neighbors.append(index + 1)
		if y > 0:
			neighbors.append(index - EXPECTED_WIDTH)
		if y < EXPECTED_HEIGHT - 1:
			neighbors.append(index + EXPECTED_WIDTH)
		for neighbor: int in neighbors:
			if owner_data[neighbor] == owner_id and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return visited.size()


func _test_nations_connected() -> Array:
	var errors := []
	var owner_data := _grid.copy_owner_data()
	for nation_id: int in _grid.get_nation_ids():
		var first := owner_data.find(nation_id)
		if first == -1:
			errors.append("la nación %d no tiene celdas" % nation_id)
			continue
		var total := _grid.count_owned_by(nation_id)
		var reachable := _count_reachable(owner_data, first, nation_id)
		if reachable != total:
			errors.append("la nación %d no está conectada: %d celdas alcanzables de %d" % [nation_id, reachable, total])
	return errors


func _test_nations_separated() -> Array:
	var errors := []
	var touching := 0
	for y in EXPECTED_HEIGHT:
		for x in EXPECTED_WIDTH:
			var here := _grid.get_cell_owner(x, y)
			if here == TerritoryGrid.OWNER_NONE:
				continue
			var right := _grid.get_cell_owner(x + 1, y)
			var below := _grid.get_cell_owner(x, y + 1)
			for other in [right, below]:
				if other != TerritoryGrid.OWNER_NONE and other != TerritoryGrid.INVALID and other != here:
					touching += 1
	_expect(errors, touching, 0, "pares de celdas adyacentes de naciones distintas")
	return errors


func _test_unclaimed_land() -> Array:
	var errors := []
	var unclaimed := 0
	for index in EXPECTED_CELLS:
		if _grid.terrain_at(index) == TerritoryGrid.TERRAIN_LAND and _grid.owner_at(index) == TerritoryGrid.OWNER_NONE:
			unclaimed += 1
	if unclaimed < MIN_UNCLAIMED_LAND:
		errors.append("tierra sin reclamar insuficiente: %d celdas (mínimo %d)" % [unclaimed, MIN_UNCLAIMED_LAND])
	return errors


func _test_determinism() -> Array:
	var errors := []
	var other := TerritoryGrid.new()
	if other.copy_terrain_data() != _grid.copy_terrain_data():
		errors.append("el terreno difiere entre dos instancias")
	if other.copy_owner_data() != _grid.copy_owner_data():
		errors.append("los propietarios difieren entre dos instancias")
	return errors


func _test_valid_assignment() -> Array:
	var errors := []
	var grid := TerritoryGrid.new()
	var cell := _find_cell(grid, TerritoryGrid.TERRAIN_LAND, TerritoryGrid.OWNER_NONE)
	if cell == Vector2i(-1, -1):
		return ["no se encontró tierra sin reclamar para la prueba"]
	var before_player := grid.count_owned_by(TerritoryGrid.OWNER_PLAYER)
	var before_none := grid.count_owned_by(TerritoryGrid.OWNER_NONE)
	_expect(errors, grid.try_set_owner(cell.x, cell.y, TerritoryGrid.OWNER_PLAYER), true, "resultado de la asignación")
	_expect(errors, grid.get_cell_owner(cell.x, cell.y), TerritoryGrid.OWNER_PLAYER, "propietario tras asignar")
	_expect(errors, grid.count_owned_by(TerritoryGrid.OWNER_PLAYER), before_player + 1, "celdas del jugador")
	_expect(errors, grid.count_owned_by(TerritoryGrid.OWNER_NONE), before_none - 1, "celdas sin propietario")
	_expect(errors, grid.copy_owner_data().size(), EXPECTED_CELLS, "tamaño del array de propietario")
	_expect(errors, grid.copy_terrain_data(), _grid.copy_terrain_data(), "el terreno no debe cambiar")
	# Liberar la celda devuelve el estado inicial.
	_expect(errors, grid.try_set_owner(cell.x, cell.y, TerritoryGrid.OWNER_NONE), true, "liberar la celda")
	_expect(errors, grid.copy_owner_data(), _grid.copy_owner_data(), "estado tras liberar la celda")
	return errors


func _test_unknown_owner_rejected() -> Array:
	var errors := []
	var grid := TerritoryGrid.new()
	var cell := _find_cell(grid, TerritoryGrid.TERRAIN_LAND, TerritoryGrid.OWNER_NONE)
	for bad_owner in [5, 99, 255, -1, 256]:
		_expect(errors, grid.try_set_owner(cell.x, cell.y, bad_owner), false, "propietario inexistente %d" % bad_owner)
		_expect(errors, grid.get_cell_owner(cell.x, cell.y), TerritoryGrid.OWNER_NONE, "celda tras rechazar %d" % bad_owner)
	return errors


func _test_water_assignment_rejected() -> Array:
	var errors := []
	var grid := TerritoryGrid.new()
	var water := _find_cell(grid, TerritoryGrid.TERRAIN_WATER, TerritoryGrid.OWNER_NONE)
	if water == Vector2i(-1, -1):
		return ["no se encontró agua para la prueba"]
	for nation_id: int in grid.get_nation_ids():
		_expect(errors, grid.try_set_owner(water.x, water.y, nation_id), false, "asignar la nación %d al agua" % nation_id)
	_expect(errors, grid.get_cell_owner(water.x, water.y), TerritoryGrid.OWNER_NONE, "propietario del agua")
	_expect(errors, grid.copy_owner_data(), _grid.copy_owner_data(), "estado completo tras los rechazos")
	return errors


func _test_invalid_operations_keep_state() -> Array:
	var errors := []
	var grid := TerritoryGrid.new()
	var owner_before := grid.copy_owner_data()
	var terrain_before := grid.copy_terrain_data()
	var land := _find_cell(grid, TerritoryGrid.TERRAIN_LAND, TerritoryGrid.OWNER_NONE)
	var water := _find_cell(grid, TerritoryGrid.TERRAIN_WATER, TerritoryGrid.OWNER_NONE)
	var attempts := [
		[-1, 0, TerritoryGrid.OWNER_PLAYER], [0, -1, TerritoryGrid.OWNER_PLAYER],
		[320, 0, TerritoryGrid.OWNER_PLAYER], [0, 180, TerritoryGrid.OWNER_PLAYER],
		[320, 180, TerritoryGrid.OWNER_AI_1], [land.x, land.y, 42], [land.x, land.y, -3],
		[water.x, water.y, TerritoryGrid.OWNER_AI_3], [-7, 500, 99],
	]
	for attempt: Array in attempts:
		_expect(errors, grid.try_set_owner(attempt[0], attempt[1], attempt[2]), false, "operación inválida %s" % [attempt])
	_expect(errors, grid.copy_owner_data(), owner_before, "propietarios tras operaciones inválidas")
	_expect(errors, grid.copy_terrain_data(), terrain_before, "terreno tras operaciones inválidas")
	_expect(errors, grid.copy_owner_data().size(), EXPECTED_CELLS, "tamaño de propietarios")
	_expect(errors, grid.copy_terrain_data().size(), EXPECTED_CELLS, "tamaño de terreno")
	# Modificar una copia no debe afectar a la cuadrícula.
	var copy := grid.copy_owner_data()
	copy[0] = 3
	_expect(errors, grid.owner_at(0), TerritoryGrid.OWNER_NONE, "la copia no debe alterar el original")
	return errors


func _test_nation_queries() -> Array:
	var errors := []
	var expected := {
		TerritoryGrid.OWNER_PLAYER: "player", TerritoryGrid.OWNER_AI_1: "ai_1",
		TerritoryGrid.OWNER_AI_2: "ai_2", TerritoryGrid.OWNER_AI_3: "ai_3",
	}
	for nation_id: int in expected:
		_expect(errors, _grid.has_nation(nation_id), true, "has_nation(%d)" % nation_id)
		_expect(errors, _grid.get_nation(nation_id).get("key"), expected[nation_id], "clave de la nación %d" % nation_id)
		_expect(errors, _grid.get_nation_id_by_key(expected[nation_id]), nation_id, "ID de la clave %s" % expected[nation_id])
	_expect(errors, _grid.get_nation(99), {}, "nación inexistente")
	_expect(errors, _grid.get_nation(TerritoryGrid.OWNER_NONE), {}, "OWNER_NONE no tiene metadatos")
	_expect(errors, _grid.get_nation_id_by_key("no_existe"), TerritoryGrid.INVALID, "clave inexistente")
	return errors


func _test_reset() -> Array:
	var errors := []
	var grid := TerritoryGrid.new()
	var cell := _find_cell(grid, TerritoryGrid.TERRAIN_LAND, TerritoryGrid.OWNER_NONE)
	grid.try_set_owner(cell.x, cell.y, TerritoryGrid.OWNER_AI_2)
	grid.reset_to_default()
	_expect(errors, grid.copy_owner_data(), _grid.copy_owner_data(), "propietarios tras reset")
	_expect(errors, grid.copy_terrain_data(), _grid.copy_terrain_data(), "terreno tras reset")
	return errors
