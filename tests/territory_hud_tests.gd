## Pruebas automáticas de las naciones y el HUD territorial (hito 5b). Sin plugins.
##
## Única definición de las comprobaciones; la usan:
##   - tests/test_territory_hud.gd (consola, headless):
##       godot --headless --path . --script res://tests/test_territory_hud.gd
##   - tests/run_hud_tests.tscn (editor de Godot, F6).
##
## Mapa controlado (load_from_data): tierra x 10..39, y 10..29 (600 celdas) más 3 celdas de isla
## en (100..102, 50): 603 de tierra. Jugador x 10..14 (100), IA 1 x 15..19 (100), resto sin
## reclamar (403). IA 2 e IA 3 sin celdas. El resto del mapa es agua.
##
## run_all() devuelve [{"name": String, "errors": Array}, ...]   (errors vacío = PASS)
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Legend := preload("res://scripts/ui/territory_legend.gd")
const Screen := preload("res://scripts/ui/territory_screen.gd")

const PLAYER := TerritoryGrid.OWNER_PLAYER
const AI_1 := TerritoryGrid.OWNER_AI_1
const SCREEN_PATH := "res://scenes/territory_main.tscn"

var _results: Array = []


func run_all() -> Array:
	_results = []
	_run("las 4 naciones conservan IDs, claves, nombres y colores", _test_nations_unchanged)
	_run("solo la nación del jugador está controlada por un humano", _test_controllers)
	_run("count_land_by_owner cuenta solo tierra y suma la tierra total", _test_count_land_by_owner)
	_run("count_land_by_owner coincide con count_owned_by en el mapa por defecto", _test_counts_default_map)
	_run("formato del porcentaje (coma decimal, total 0)", _test_format_share)
	_run("las filas de la leyenda salen de la cuadrícula", _test_build_rows)
	_run("las filas se actualizan tras conquistar y la tierra total no cambia", _test_rows_after_conquest)
	_run("ownership_changed: una vez por operación válida, nunca en rechazos", _test_signal)
	_run("resumen del jugador para el HUD", _test_player_summary)
	_run("la pantalla muestra datos de la cuadrícula y se marca para refrescar al cambiar", _test_screen)
	return _results


func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	_results.append({"name": test_name, "errors": errors})


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


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


func _test_nations_unchanged() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var expected := [
		[1, "player", "Confederación de Alba", Color(0.25, 0.55, 0.90)],
		[2, "ai_1", "Reino de Cobre", Color(0.85, 0.30, 0.30)],
		[3, "ai_2", "República de Bruma", Color(0.90, 0.75, 0.25)],
		[4, "ai_3", "Imperio de Ceniza", Color(0.70, 0.45, 0.85)],
	]
	_expect(errors, grid.get_nation_ids(), [1, 2, 3, 4], "IDs en orden estable")
	for entry: Array in expected:
		var nation := grid.get_nation(entry[0])
		_expect(errors, nation["key"], entry[1], "clave de %d" % entry[0])
		_expect(errors, nation["name"], entry[2], "nombre de %d" % entry[0])
		_expect(errors, nation["color"], entry[3], "color de %d" % entry[0])
	return errors


func _test_controllers() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var humans := 0
	for nation_id: int in grid.get_nation_ids():
		var controller: String = grid.get_nation(nation_id)["controller"]
		_expect(errors, controller == "human" or controller == "ai", true, "controlador válido de %d" % nation_id)
		if controller == "human":
			humans += 1
			_expect(errors, nation_id, PLAYER, "la nación humana es la del jugador")
	_expect(errors, humans, 1, "número de naciones humanas")
	return errors


func _test_count_land_by_owner() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var counts := grid.count_land_by_owner()
	_expect(errors, counts[PLAYER], 100, "jugador")
	_expect(errors, counts[AI_1], 100, "IA 1")
	_expect(errors, counts[TerritoryGrid.OWNER_AI_2], 0, "IA 2 aparece con 0")
	_expect(errors, counts[TerritoryGrid.OWNER_AI_3], 0, "IA 3 aparece con 0")
	_expect(errors, counts[TerritoryGrid.OWNER_NONE], 403, "tierra sin reclamar (sin contar agua)")
	_expect(errors, counts.size(), 5, "claves del resultado")
	var total := 0
	for owner_id: int in counts:
		total += counts[owner_id]
	_expect(errors, total, 603, "suma = tierra total")
	_expect(errors, total, grid.count_land(), "suma = count_land()")
	return errors


func _test_counts_default_map() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var counts := grid.count_land_by_owner()
	var total := 0
	for owner_id: int in counts:
		total += counts[owner_id]
	_expect(errors, total, grid.count_land(), "suma = tierra total")
	for nation_id: int in grid.get_nation_ids():
		_expect(errors, counts[nation_id], grid.count_owned_by(nation_id), "nación %d = count_owned_by" % nation_id)
		_expect(errors, counts[nation_id] > 0, true, "nación %d con territorio" % nation_id)
	_expect(errors, counts[TerritoryGrid.OWNER_NONE] > 0, true, "hay tierra sin reclamar")
	return errors


func _test_format_share() -> Array:
	var errors: Array = []
	_expect(errors, Legend.format_share(1, 4), "25,0 %", "1 de 4")
	_expect(errors, Legend.format_share(1, 3), "33,3 %", "1 de 3")
	_expect(errors, Legend.format_share(2, 3), "66,7 %", "2 de 3")
	_expect(errors, Legend.format_share(0, 10), "0,0 %", "0 de 10")
	_expect(errors, Legend.format_share(10, 10), "100,0 %", "todo")
	_expect(errors, Legend.format_share(5, 0), "0,0 %", "total 0 sin error")
	return errors


func _test_build_rows() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var rows := Legend.build_rows(grid)
	_expect(errors, rows.size(), 6, "filas: 4 naciones, sin reclamar y agua")
	var names: Array = []
	for row: Dictionary in rows:
		names.append(row["name"])
	_expect(errors, names, ["Confederación de Alba", "Reino de Cobre", "República de Bruma", "Imperio de Ceniza", "Sin reclamar", "Agua"], "nombres y orden")
	_expect(errors, rows[0]["cells"], 100, "celdas del jugador")
	_expect(errors, rows[0]["share"], "16,6 %", "porcentaje del jugador (100 de 603)")
	_expect(errors, rows[0]["human"], true, "el jugador es humano")
	_expect(errors, rows[1]["human"], false, "IA 1 no es humana")
	_expect(errors, rows[2]["cells"], 0, "IA 2 sin celdas")
	_expect(errors, rows[4]["cells"], 403, "sin reclamar")
	_expect(errors, rows[4]["share"], "66,8 %", "porcentaje sin reclamar (403 de 603)")
	_expect(errors, rows[5]["cells"], -1, "el agua no tiene cifra")
	_expect(errors, Legend.row_stats_text(rows[5]), "", "el agua no muestra estadística")
	for i in 4:
		var nation := grid.get_nation(i + 1)
		_expect(errors, rows[i]["color"], nation["color"], "color de la fila %d = color de la nación" % i)
	return errors


func _test_rows_after_conquest() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var result := grid.conquer_cells(PLAYER, [Vector2i(15, 10), Vector2i(15, 11)])
	_expect(errors, result["ok"], true, "conquista de tierra de la IA 1")
	var rows := Legend.build_rows(grid)
	_expect(errors, rows[0]["cells"], 102, "jugador +2")
	_expect(errors, rows[1]["cells"], 98, "IA 1 -2")
	_expect(errors, rows[4]["cells"], 403, "sin reclamar igual")
	result = grid.conquer_cells(PLAYER, [Vector2i(16, 10), Vector2i(16, 11)])
	var total := 0
	for row: Dictionary in Legend.build_rows(grid):
		if row["cells"] >= 0:
			total += row["cells"]
	_expect(errors, total, 603, "la tierra total no cambia al conquistar")
	return errors


func _test_signal() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var count := [0]
	grid.ownership_changed.connect(func() -> void: count[0] += 1)
	grid.conquer_cells(PLAYER, [Vector2i(15, 10), Vector2i(16, 10)])
	_expect(errors, count[0], 1, "conquista válida de 2 celdas: una emisión")
	grid.conquer_cells(PLAYER, [Vector2i(9, 12)])  # agua
	grid.conquer_cells(PLAYER, [Vector2i(14, 10)])  # ya propia
	grid.conquer_cells(0, [Vector2i(30, 25)])  # atacante inválido
	_expect(errors, count[0], 1, "los rechazos no emiten")
	_expect(errors, grid.try_set_owner(30, 25, AI_1), true, "try_set_owner válido")
	_expect(errors, count[0], 2, "try_set_owner con cambio emite")
	grid.try_set_owner(30, 25, AI_1)
	_expect(errors, count[0], 2, "try_set_owner sin cambio no emite")
	grid.try_set_owner(9, 12, PLAYER)  # agua: rechazado
	grid.try_set_owner(-1, 0, PLAYER)
	_expect(errors, count[0], 2, "try_set_owner rechazado no emite")
	grid.load_from_data(PackedByteArray([1]), PackedByteArray([1]))
	_expect(errors, count[0], 2, "load_from_data inválido no emite")
	grid.load_from_data(grid.copy_terrain_data(), grid.copy_owner_data())
	_expect(errors, count[0], 3, "load_from_data válido emite")
	return errors


func _test_player_summary() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var rows := Legend.build_rows(grid)
	_expect(errors, Legend.row_stats_text(rows[0]), "100 celdas · 16,6 %", "texto de estadística")
	_expect(errors, Legend.player_summary(rows), "Confederación de Alba · 100 celdas · 16,6 %", "resumen del jugador")
	_expect(errors, Legend.player_summary([]), "", "sin filas, sin resumen")
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
	var label: Label = screen.get_node("%Jugador")
	_expect(errors, label.text, Legend.player_summary(Legend.build_rows(grid)), "resumen inicial = datos de la cuadrícula")
	_expect(errors, screen.is_processing(), false, "sin cambios no se recalcula")
	# Un cambio de propietario marca el refresco pendiente; las cifras se actualizan al refrescar.
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
	_expect(errors, grid.conquer_cells(PLAYER, [target])["ok"], true, "conquista junto al jugador")
	_expect(errors, screen.is_processing(), true, "el cambio marca el refresco pendiente")
	screen.refresh_stats()
	_expect(errors, screen.is_processing(), false, "tras refrescar no queda pendiente")
	_expect(errors, label.text, Legend.player_summary(Legend.build_rows(grid)), "resumen tras la conquista = datos de la cuadrícula")
	_expect(errors, label.text.contains("%d celdas" % grid.count_owned_by(PLAYER)), true, "el resumen muestra las celdas actuales del jugador")
	screen.free()
	return errors
