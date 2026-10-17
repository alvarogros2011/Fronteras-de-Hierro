## Pruebas automáticas de la operación de conquista (hito 5). Sin plugins.
##
## Única definición de las comprobaciones; la usan:
##   - tests/test_territory_conquest.gd (consola, headless):
##       godot --headless --path . --script res://tests/test_territory_conquest.gd
##   - tests/run_conquest_tests.tscn (editor de Godot, F6).
##
## Casi todas usan un mapa controlado (load_from_data) para no depender de la generación:
##   - Tierra: rectángulo x 10..39, y 10..29. El resto es agua.
##   - Jugador: x 10..14. IA 1: x 15..19. El resto de la tierra (x 20..39) sin reclamar.
##   - Isla aparte: tierra en (100..102, 50), sin reclamar y sin conexión con el rectángulo.
##
## run_all() devuelve [{"name": String, "errors": Array}, ...]   (errors vacío = PASS)
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const MapView := preload("res://scripts/world/territory_map_view.gd")

const PLAYER := TerritoryGrid.OWNER_PLAYER
const AI_1 := TerritoryGrid.OWNER_AI_1

var _results: Array = []


func run_all() -> Array:
	_results = []
	_run("conquista válida: cambia todas las celdas pedidas", _test_valid_conquest)
	_run("conquista válida: no cambia celdas no pedidas ni el terreno", _test_nothing_else_changes)
	_run("se puede conquistar tierra de otra nación", _test_conquer_enemy_land)
	_run("el resultado describe la conquista (ok, changed, error, changed_cells)", _test_result_shape)
	_run("se rechaza el agua y sigue sin propietario", _test_water_rejected)
	_run("se rechaza una celda que ya es del atacante", _test_already_owned_rejected)
	_run("se rechazan coordenadas fuera del mapa", _test_out_of_bounds_rejected)
	_run("se rechaza un atacante inválido", _test_invalid_attacker_rejected)
	_run("se rechazan lista vacía y elementos que no son Vector2i", _test_invalid_data_rejected)
	_run("se rechazan objetivos repetidos", _test_duplicates_rejected)
	_run("se rechaza una zona desconectada (también por diagonal)", _test_not_contiguous_rejected)
	_run("se rechaza una zona sin contacto con el atacante", _test_no_contact_rejected)
	_run("basta con que una celda de la zona toque al atacante", _test_partial_contact_accepted)
	_run("una sola celda inválida no modifica ninguna", _test_atomic_rejection)
	_run("las conquistas encadenadas amplían el contacto", _test_chained_conquests)
	_run("load_from_data rechaza datos inválidos sin cambiar nada", _test_load_from_data_validation)
	_run("el mapa por defecto sigue siendo determinista tras conquistar en otra instancia", _test_default_map_unaffected)
	_run("la vista repinta solo las celdas conquistadas y queda igual que un repintado completo", _test_view_refresh)
	return _results


func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	_results.append({"name": test_name, "errors": errors})


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


## Mapa controlado (ver cabecera).
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
			if x <= 14:
				owners[y * TerritoryGrid.WIDTH + x] = PLAYER
			elif x <= 19:
				owners[y * TerritoryGrid.WIDTH + x] = AI_1
	for x in range(100, 103):
		terrain[50 * TerritoryGrid.WIDTH + x] = TerritoryGrid.TERRAIN_LAND
	var grid := TerritoryGrid.new()
	grid.load_from_data(terrain, owners)
	return grid


func _block(x0: int, y0: int, x1: int, y1: int) -> Array:
	var cells: Array = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			cells.append(Vector2i(x, y))
	return cells


## Número de celdas cuyo propietario difiere entre dos copias de los propietarios.
func _count_differences(a: PackedByteArray, b: PackedByteArray) -> int:
	var total := 0
	for i in a.size():
		if a[i] != b[i]:
			total += 1
	return total


## Comprueba que conquer_cells falla con ese error y que no cambió ninguna celda.
func _expect_rejected(errors: Array, grid: TerritoryGrid, attacker: int, cells: Array, expected_error: int, what: String) -> Dictionary:
	var owners_before := grid.copy_owner_data()
	var terrain_before := grid.copy_terrain_data()
	var result := grid.conquer_cells(attacker, cells)
	_expect(errors, result["ok"], false, "%s: ok" % what)
	_expect(errors, result["error"], expected_error, "%s: código de error" % what)
	_expect(errors, result["changed"], 0, "%s: celdas cambiadas" % what)
	_expect(errors, result["changed_cells"].size(), 0, "%s: lista de cambiadas" % what)
	_expect(errors, grid.copy_owner_data() == owners_before, true, "%s: propietarios intactos" % what)
	_expect(errors, grid.copy_terrain_data() == terrain_before, true, "%s: terreno intacto" % what)
	return result


# ---------------------------------------------------------------------------

func _test_valid_conquest() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var cells := _block(15, 10, 16, 12)  # 6 celdas de la IA 1 pegadas al jugador
	var result := grid.conquer_cells(PLAYER, cells)
	_expect(errors, result["ok"], true, "ok")
	_expect(errors, result["changed"], 6, "celdas cambiadas")
	for cell: Vector2i in cells:
		_expect(errors, grid.get_cell_owner(cell.x, cell.y), PLAYER, "propietario de %s" % cell)
	# Zona sin reclamar pegada a la IA 1 conquistada por la IA 1.
	var neutral := _block(20, 20, 21, 20)
	var result_neutral := grid.conquer_cells(AI_1, neutral)
	_expect(errors, result_neutral["ok"], true, "conquista de tierra sin reclamar: ok")
	for cell: Vector2i in neutral:
		_expect(errors, grid.get_cell_owner(cell.x, cell.y), AI_1, "propietario de %s" % cell)
	return errors


func _test_nothing_else_changes() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var owners_before := grid.copy_owner_data()
	var terrain_before := grid.copy_terrain_data()
	var cells := _block(20, 10, 22, 11)
	# Tierra sin reclamar pegada a la IA 1 (x=19), que es la atacante.
	var result := grid.conquer_cells(AI_1, cells)
	_expect(errors, result["ok"], true, "ok")
	_expect(errors, _count_differences(owners_before, grid.copy_owner_data()), cells.size(), "celdas con propietario distinto")
	_expect(errors, grid.copy_terrain_data() == terrain_before, true, "el terreno no cambió")
	var owners_after := grid.copy_owner_data()
	var unexpected := 0
	for i in owners_after.size():
		var cell := grid.index_to_coord(i)
		if not cells.has(cell) and owners_after[i] != owners_before[i]:
			unexpected += 1
	_expect(errors, unexpected, 0, "celdas no pedidas modificadas")
	# El agua sigue sin propietario: las celdas sin propietario son agua más tierra sin reclamar.
	_expect(errors, grid.get_cell_owner(9, 12), TerritoryGrid.OWNER_NONE, "el agua sigue sin propietario")
	return errors


func _test_conquer_enemy_land() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var before_enemy := grid.count_owned_by(AI_1)
	var before_player := grid.count_owned_by(PLAYER)
	var result := grid.conquer_cells(PLAYER, [Vector2i(15, 10), Vector2i(15, 11)])
	_expect(errors, result["ok"], true, "ok")
	_expect(errors, grid.count_owned_by(AI_1), before_enemy - 2, "la IA 1 pierde 2 celdas")
	_expect(errors, grid.count_owned_by(PLAYER), before_player + 2, "el jugador gana 2 celdas")
	return errors


func _test_result_shape() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var cells := [Vector2i(15, 10), Vector2i(16, 10)]
	var result := grid.conquer_cells(PLAYER, cells)
	_expect(errors, result["ok"], true, "ok")
	_expect(errors, result["error"], TerritoryGrid.CONQUEST_OK, "error")
	_expect(errors, result["changed"], 2, "changed")
	_expect(errors, result["bad_index"], -1, "bad_index")
	_expect(errors, result["changed_cells"], cells, "changed_cells")
	# Un fallo con celda concreta señala su posición en la lista.
	var failed := grid.conquer_cells(PLAYER, [Vector2i(17, 10), Vector2i(0, 0)])
	_expect(errors, failed["bad_index"], 1, "bad_index del fallo (celda de agua)")
	return errors


func _test_water_rejected() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	# (9, 12) es agua pegada al territorio del jugador.
	_expect_rejected(errors, grid, PLAYER, [Vector2i(9, 12)], TerritoryGrid.CONQUEST_ERR_WATER, "solo agua")
	_expect(errors, grid.get_cell_owner(9, 12), TerritoryGrid.OWNER_NONE, "el agua sigue sin propietario")
	# Mezclada con tierra válida.
	_expect_rejected(errors, grid, PLAYER, [Vector2i(15, 12), Vector2i(9, 12)], TerritoryGrid.CONQUEST_ERR_WATER, "agua mezclada con tierra")
	return errors


func _test_already_owned_rejected() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	_expect_rejected(errors, grid, PLAYER, [Vector2i(14, 10)], TerritoryGrid.CONQUEST_ERR_ALREADY_OWNED, "celda propia")
	_expect_rejected(errors, grid, PLAYER, [Vector2i(15, 10), Vector2i(14, 10)], TerritoryGrid.CONQUEST_ERR_ALREADY_OWNED, "celda propia mezclada")
	return errors


func _test_out_of_bounds_rejected() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	for cell: Vector2i in [Vector2i(-1, 10), Vector2i(10, -1), Vector2i(320, 10), Vector2i(10, 180), Vector2i(-5, 400)]:
		_expect_rejected(errors, grid, PLAYER, [cell], TerritoryGrid.CONQUEST_ERR_OUT_OF_BOUNDS, "fuera del mapa %s" % cell)
	_expect_rejected(errors, grid, PLAYER, [Vector2i(15, 10), Vector2i(320, 0)], TerritoryGrid.CONQUEST_ERR_OUT_OF_BOUNDS, "fuera del mapa mezclada")
	return errors


func _test_invalid_attacker_rejected() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var cells := [Vector2i(15, 10)]
	for attacker in [TerritoryGrid.OWNER_NONE, 99, -1, 5]:
		_expect_rejected(errors, grid, attacker, cells, TerritoryGrid.CONQUEST_ERR_UNKNOWN_ATTACKER, "atacante %d" % attacker)
	return errors


func _test_invalid_data_rejected() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	_expect_rejected(errors, grid, PLAYER, [], TerritoryGrid.CONQUEST_ERR_EMPTY, "lista vacía")
	_expect_rejected(errors, grid, PLAYER, ["15,10"], TerritoryGrid.CONQUEST_ERR_INVALID_DATA, "texto")
	_expect_rejected(errors, grid, PLAYER, [Vector2(15, 10)], TerritoryGrid.CONQUEST_ERR_INVALID_DATA, "Vector2 en vez de Vector2i")
	_expect_rejected(errors, grid, PLAYER, [null], TerritoryGrid.CONQUEST_ERR_INVALID_DATA, "null")
	_expect_rejected(errors, grid, PLAYER, [Vector2i(15, 10), 7], TerritoryGrid.CONQUEST_ERR_INVALID_DATA, "entero mezclado")
	return errors


func _test_duplicates_rejected() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var result := _expect_rejected(errors, grid, PLAYER, [Vector2i(15, 10), Vector2i(16, 10), Vector2i(15, 10)], TerritoryGrid.CONQUEST_ERR_DUPLICATE, "repetida")
	_expect(errors, result["bad_index"], 2, "posición de la repetida")
	return errors


func _test_not_contiguous_rejected() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	# Una celda toca al jugador y la otra está lejos.
	_expect_rejected(errors, grid, PLAYER, [Vector2i(15, 10), Vector2i(30, 25)], TerritoryGrid.CONQUEST_ERR_NOT_CONTIGUOUS, "dos piezas lejanas")
	# Solo se tocan en diagonal.
	_expect_rejected(errors, grid, PLAYER, [Vector2i(15, 10), Vector2i(16, 11)], TerritoryGrid.CONQUEST_ERR_NOT_CONTIGUOUS, "contacto solo diagonal")
	# Dos piezas contiguas por separado (2 + 2).
	_expect_rejected(errors, grid, PLAYER, [Vector2i(15, 10), Vector2i(16, 10), Vector2i(15, 20), Vector2i(16, 20)], TerritoryGrid.CONQUEST_ERR_NOT_CONTIGUOUS, "dos bloques")
	# Una celda en la isla separada.
	_expect_rejected(errors, grid, PLAYER, [Vector2i(15, 10), Vector2i(100, 50)], TerritoryGrid.CONQUEST_ERR_NOT_CONTIGUOUS, "isla separada")
	return errors


func _test_no_contact_rejected() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	# Contigua pero lejos del jugador (x >= 25).
	_expect_rejected(errors, grid, PLAYER, [Vector2i(25, 15), Vector2i(26, 15)], TerritoryGrid.CONQUEST_ERR_NO_CONTACT, "zona sin contacto")
	# La isla es contigua pero el jugador no la toca.
	_expect_rejected(errors, grid, PLAYER, [Vector2i(100, 50), Vector2i(101, 50), Vector2i(102, 50)], TerritoryGrid.CONQUEST_ERR_NO_CONTACT, "isla contigua sin contacto")
	# Un atacante sin ningún territorio no puede tocar nada.
	_expect_rejected(errors, grid, TerritoryGrid.OWNER_AI_3, [Vector2i(25, 15)], TerritoryGrid.CONQUEST_ERR_NO_CONTACT, "atacante sin territorio")
	return errors


func _test_partial_contact_accepted() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	# Solo la primera celda toca al jugador (x=14); las demás extienden la zona hacia la IA 1.
	var cells := [Vector2i(15, 10), Vector2i(16, 10), Vector2i(17, 10)]
	var result := grid.conquer_cells(PLAYER, cells)
	_expect(errors, result["ok"], true, "ok")
	_expect(errors, result["changed"], 3, "changed")
	return errors


func _test_atomic_rejection() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	# 8 celdas válidas y una de agua al final.
	var cells := _block(15, 10, 18, 11)
	cells.append(Vector2i(9, 10))
	_expect_rejected(errors, grid, PLAYER, cells, TerritoryGrid.CONQUEST_ERR_WATER, "9 celdas, 1 de agua")
	# Válidas y una ya propia al principio.
	cells = [Vector2i(14, 10)] + _block(15, 10, 16, 10)
	_expect_rejected(errors, grid, PLAYER, cells, TerritoryGrid.CONQUEST_ERR_ALREADY_OWNED, "celda propia al principio")
	# Válidas y una fuera del mapa en medio.
	cells = [Vector2i(15, 10), Vector2i(-3, -3), Vector2i(16, 10)]
	_expect_rejected(errors, grid, PLAYER, cells, TerritoryGrid.CONQUEST_ERR_OUT_OF_BOUNDS, "fuera del mapa en medio")
	return errors


func _test_chained_conquests() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	# Sin contacto todavía: x=20 queda tras la IA 1 (x 15..19).
	_expect_rejected(errors, grid, PLAYER, [Vector2i(20, 10)], TerritoryGrid.CONQUEST_ERR_NO_CONTACT, "antes de avanzar")
	# Avanza sobre la IA 1 fila a fila hasta tocar x=20.
	for x in range(15, 20):
		_expect(errors, grid.conquer_cells(PLAYER, [Vector2i(x, 10)])["ok"], true, "avance a x=%d" % x)
	_expect(errors, grid.conquer_cells(PLAYER, [Vector2i(20, 10)])["ok"], true, "ahora sí toca x=20")
	return errors


func _test_load_from_data_validation() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var owners_before := grid.copy_owner_data()
	var terrain_before := grid.copy_terrain_data()
	var terrain := terrain_before.duplicate()
	var owners := owners_before.duplicate()
	_expect(errors, grid.load_from_data(PackedByteArray([0, 1]), owners), false, "terreno de tamaño incorrecto")
	_expect(errors, grid.load_from_data(terrain, PackedByteArray([0])), false, "propietarios de tamaño incorrecto")
	var bad_terrain := terrain.duplicate()
	bad_terrain[500] = 2
	_expect(errors, grid.load_from_data(bad_terrain, owners), false, "terreno desconocido")
	var bad_owner := owners.duplicate()
	bad_owner[12 * TerritoryGrid.WIDTH + 12] = 77
	_expect(errors, grid.load_from_data(terrain, bad_owner), false, "propietario desconocido")
	var water_owned := owners.duplicate()
	water_owned[0] = PLAYER  # la celda 0 es agua
	_expect(errors, grid.load_from_data(terrain, water_owned), false, "agua con propietario")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "propietarios intactos tras los rechazos")
	_expect(errors, grid.copy_terrain_data() == terrain_before, true, "terreno intacto tras los rechazos")
	_expect(errors, grid.load_from_data(terrain, owners), true, "datos válidos")
	return errors


func _test_default_map_unaffected() -> Array:
	var errors: Array = []
	var pristine := TerritoryGrid.new()
	var grid := TerritoryGrid.new()
	_expect(errors, grid.copy_owner_data() == pristine.copy_owner_data(), true, "mismo mapa inicial")
	# Una celda sin reclamar pegada al territorio del jugador, buscada en el mapa real.
	var target := Vector2i(-1, -1)
	for index in TerritoryGrid.CELL_COUNT:
		var cell := grid.index_to_coord(index)
		if grid.is_land(cell.x, cell.y) and grid.get_cell_owner(cell.x, cell.y) == TerritoryGrid.OWNER_NONE:
			for step in TerritoryGrid.ORTHOGONAL_STEPS:
				var n: Vector2i = cell + step
				if grid.get_cell_owner(n.x, n.y) == PLAYER:
					target = cell
			if target != Vector2i(-1, -1):
				break
	_expect(errors, target != Vector2i(-1, -1), true, "hay tierra sin reclamar junto al jugador")
	var result := grid.conquer_cells(PLAYER, [target])
	_expect(errors, result["ok"], true, "conquista en el mapa por defecto")
	_expect(errors, _count_differences(pristine.copy_owner_data(), grid.copy_owner_data()), 1, "solo una celda difiere")
	_expect(errors, grid.copy_terrain_data() == pristine.copy_terrain_data(), true, "terreno igual")
	# Otra instancia sigue generando el mapa original.
	_expect(errors, TerritoryGrid.new().copy_owner_data() == pristine.copy_owner_data(), true, "la generación no depende de conquistas previas")
	_expect(errors, grid.try_set_owner(target.x, target.y, AI_1), true, "try_set_owner sigue funcionando")
	return errors


func _test_view_refresh() -> Array:
	var errors: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	var grid := _make_grid()
	var view: MapView = MapView.new()
	tree.root.add_child(view)
	view.set_grid(grid)
	var result := grid.conquer_cells(PLAYER, _block(15, 10, 16, 11))
	_expect(errors, result["ok"], true, "ok")
	for cell: Vector2i in result["changed_cells"]:
		view.refresh_cell(cell.x, cell.y)
	var incremental: Array = []
	for y in TerritoryGrid.HEIGHT:
		for x in TerritoryGrid.WIDTH:
			incremental.append(view.get_image_pixel(x, y))
	view.refresh_all()
	var differences := 0
	var i := 0
	for y in TerritoryGrid.HEIGHT:
		for x in TerritoryGrid.WIDTH:
			var a: Color = incremental[i]
			var b := view.get_image_pixel(x, y)
			if absf(a.r - b.r) > 0.01 or absf(a.g - b.g) > 0.01 or absf(a.b - b.b) > 0.01:
				differences += 1
			i += 1
	_expect(errors, differences, 0, "diferencias entre refresh_cell por celda conquistada y repintado completo")
	view.free()
	return errors
