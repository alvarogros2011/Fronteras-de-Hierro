## Pruebas automáticas de la vista pixelada del territorio (hito 4). Sin plugins.
##
## Única definición de las comprobaciones; la usan:
##   - tests/test_territory_map_view.gd (consola, headless):
##       godot --headless --path . --script res://tests/test_territory_map_view.gd
##   - tests/run_view_tests.tscn (editor de Godot, F6).
##
## La vista es un Node2D: las pruebas la añaden temporalmente a la raíz del SceneTree
## (necesario para to_local/to_global) y la liberan al terminar. No se comprueba la
## apariencia en pantalla (eso es validación manual), solo imagen, coordenadas y estado.
##
## run_all() devuelve [{"name": String, "errors": Array}, ...]   (errors vacío = PASS)
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const MapView := preload("res://scripts/world/territory_map_view.gd")
const InfoPanel := preload("res://scripts/ui/territory_info_panel.gd")

const NO_CELL := Vector2i(-1, -1)
const COLOR_TOLERANCE := 0.01

var _results: Array = []
var _tree: SceneTree


func run_all() -> Array:
	_results = []
	_tree = Engine.get_main_loop() as SceneTree
	_run("la imagen mide 320x180 y cada píxel coincide con la cuadrícula", _test_image_matches_grid)
	_run("colores de agua, tierra sin reclamar y naciones", _test_cell_colors)
	_run("is_border coincide con una comprobación independiente", _test_is_border)
	_run("frontera entre dos naciones: una línea a cada lado, sin huecos", _test_border_between_nations)
	_run("celda <-> posición visual (esquinas y centros)", _test_cell_position_roundtrip)
	_run("bordes del mapa y coordenadas fuera de límites", _test_map_bounds)
	_run("posición y escala del nodo (incluido un padre movido)", _test_transform_changes)
	_run("resaltado: solo tierra, nunca agua ni fuera del mapa", _test_hover)
	_run("selección: tierra selecciona, agua/fuera/limpiar la vacían", _test_selection)
	_run("las señales de selección solo se emiten al cambiar", _test_selection_signals)
	_run("set_grid limpia selección y resaltado", _test_set_grid_clears)
	_run("refresh_cell actualiza solo la celda y sus 4 vecinas", _test_refresh_cell)
	_run("el panel de información coincide con TerritoryGrid", _test_info_panel_text)
	_run("la interacción no modifica terreno ni propietarios", _test_interaction_keeps_data)
	return _results


func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	_results.append({"name": test_name, "errors": errors})


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


func _expect_color(errors: Array, actual: Color, expected: Color, what: String) -> void:
	if absf(actual.r - expected.r) > COLOR_TOLERANCE or absf(actual.g - expected.g) > COLOR_TOLERANCE \
			or absf(actual.b - expected.b) > COLOR_TOLERANCE or absf(actual.a - expected.a) > COLOR_TOLERANCE:
		errors.append("%s: se esperaba %s y salió %s" % [what, expected, actual])


func _same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= COLOR_TOLERANCE and absf(a.g - b.g) <= COLOR_TOLERANCE \
			and absf(a.b - b.b) <= COLOR_TOLERANCE and absf(a.a - b.a) <= COLOR_TOLERANCE


## Vista nueva dentro del árbol, colocada en `pos` con escala `zoom`, mostrando `grid`.
func _make_view(grid: TerritoryGrid, pos: Vector2 = Vector2(160, 76), zoom: float = 3.0) -> MapView:
	var view: MapView = MapView.new()
	view.position = pos
	view.scale = Vector2(zoom, zoom)
	_tree.root.add_child(view)
	view.set_grid(grid)
	return view


## Primera celda (en orden de índice) que cumple el predicado, o NO_CELL.
func _find_cell(grid: TerritoryGrid, predicate: Callable) -> Vector2i:
	for index in TerritoryGrid.CELL_COUNT:
		var cell := grid.index_to_coord(index)
		if predicate.call(cell):
			return cell
	return NO_CELL


func _is_water(grid: TerritoryGrid, cell: Vector2i) -> bool:
	return grid.get_cell_terrain(cell.x, cell.y) == TerritoryGrid.TERRAIN_WATER


## Tierra sin reclamar rodeada solo de tierra sin reclamar (no es costa ni frontera).
func _is_unclaimed_interior(grid: TerritoryGrid, cell: Vector2i) -> bool:
	if not grid.is_land(cell.x, cell.y) or grid.get_cell_owner(cell.x, cell.y) != TerritoryGrid.OWNER_NONE:
		return false
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + step
		if not grid.is_land(n.x, n.y) or grid.get_cell_owner(n.x, n.y) != TerritoryGrid.OWNER_NONE:
			return false
	return true


func _snapshot_pixels(view: MapView) -> Array:
	var pixels: Array = []
	for y in TerritoryGrid.HEIGHT:
		for x in TerritoryGrid.WIDTH:
			pixels.append(view.get_image_pixel(x, y))
	return pixels


# ---------------------------------------------------------------------------
# Imagen y colores
# ---------------------------------------------------------------------------

func _test_image_matches_grid() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid)
	var mismatches := 0
	var first := ""
	for y in TerritoryGrid.HEIGHT:
		for x in TerritoryGrid.WIDTH:
			if not _same_color(view.get_image_pixel(x, y), view.cell_color(x, y)):
				mismatches += 1
				if first == "":
					first = "(%d, %d)" % [x, y]
	_expect(errors, mismatches, 0, "píxeles distintos de cell_color (primero en %s)" % first)
	# Fuera de la imagen no hay píxel.
	_expect_color(errors, view.get_image_pixel(-1, 0), Color(0, 0, 0, 0), "píxel fuera de la imagen")
	_expect_color(errors, view.get_image_pixel(TerritoryGrid.WIDTH, 0), Color(0, 0, 0, 0), "píxel fuera de la imagen (x=320)")
	view.free()
	return errors


func _test_cell_colors() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid)

	var water := _find_cell(grid, func(c: Vector2i) -> bool: return _is_water(grid, c))
	_expect(errors, water != NO_CELL, true, "existe una celda de agua")
	_expect_color(errors, view.get_image_pixel(water.x, water.y), MapView.COLOR_WATER, "agua")

	var unclaimed := _find_cell(grid, func(c: Vector2i) -> bool: return _is_unclaimed_interior(grid, c))
	_expect(errors, unclaimed != NO_CELL, true, "existe tierra sin reclamar interior")
	_expect_color(errors, view.get_image_pixel(unclaimed.x, unclaimed.y), MapView.COLOR_LAND, "tierra sin reclamar")

	var shore := _find_cell(grid, func(c: Vector2i) -> bool: return _is_unclaimed_shore(grid, c))
	_expect(errors, shore != NO_CELL, true, "existe costa de tierra sin reclamar")
	_expect_color(errors, view.get_image_pixel(shore.x, shore.y), MapView.COLOR_SHORE, "costa sin reclamar")

	for nation_id: int in grid.get_nation_ids():
		var base: Color = grid.get_nation(nation_id)["color"]
		var interior := _find_cell(grid, func(c: Vector2i) -> bool: return grid.get_cell_owner(c.x, c.y) == nation_id and not view.is_border(c.x, c.y))
		_expect(errors, interior != NO_CELL, true, "nación %d tiene interior" % nation_id)
		if interior != NO_CELL:
			_expect_color(errors, view.get_image_pixel(interior.x, interior.y), base, "interior de la nación %d" % nation_id)
		var edge := _find_cell(grid, func(c: Vector2i) -> bool: return grid.get_cell_owner(c.x, c.y) == nation_id and view.is_border(c.x, c.y))
		_expect(errors, edge != NO_CELL, true, "nación %d tiene borde" % nation_id)
		if edge != NO_CELL:
			_expect_color(errors, view.get_image_pixel(edge.x, edge.y), base.darkened(MapView.BORDER_DARKEN), "borde de la nación %d" % nation_id)
	view.free()
	return errors


## Tierra sin reclamar que toca agua (costa).
func _is_unclaimed_shore(grid: TerritoryGrid, cell: Vector2i) -> bool:
	return grid.is_land(cell.x, cell.y) and grid.get_cell_owner(cell.x, cell.y) == TerritoryGrid.OWNER_NONE and _touches_water(grid, cell)


## Bloque de width x height celdas, desde `origin`, todas tierra sin reclamar interior.
func _is_interior_block(grid: TerritoryGrid, origin: Vector2i, width: int, height: int) -> bool:
	for dx in width:
		for dy in height:
			if not _is_unclaimed_interior(grid, Vector2i(origin.x + dx, origin.y + dy)):
				return false
	return true


func _touches_water(grid: TerritoryGrid, cell: Vector2i) -> bool:
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + step
		if grid.is_valid_coord(n.x, n.y) and not grid.is_land(n.x, n.y):
			return true
	return false


func _test_is_border() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid)
	# Comprobación independiente: usa los arrays copiados y el índice y * 320 + x.
	var terrain := grid.copy_terrain_data()
	var owners := grid.copy_owner_data()
	var width := TerritoryGrid.WIDTH
	var height := TerritoryGrid.HEIGHT
	var wrong := 0
	var first := ""
	for y in height:
		for x in width:
			var index := y * width + x
			var expected := false
			if terrain[index] == TerritoryGrid.TERRAIN_LAND:
				for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + step.x
					var ny: int = y + step.y
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					var n_index := ny * width + nx
					if terrain[n_index] == TerritoryGrid.TERRAIN_WATER or owners[n_index] != owners[index]:
						expected = true
			if view.is_border(x, y) != expected:
				wrong += 1
				if first == "":
					first = "(%d, %d)" % [x, y]
	_expect(errors, wrong, 0, "celdas con is_border distinto del esperado (primera en %s)" % first)
	# El agua nunca es celda de frontera.
	var water := _find_cell(grid, func(c: Vector2i) -> bool: return _is_water(grid, c))
	_expect(errors, view.is_border(water.x, water.y), false, "el agua no es frontera")
	view.free()
	return errors


func _test_border_between_nations() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	# Se fuerzan dos naciones contiguas en un tramo de tierra interior sin reclamar.
	var start := _find_cell(grid, func(c: Vector2i) -> bool: return _is_interior_block(grid, c, 6, 3))
	_expect(errors, start != NO_CELL, true, "hay un tramo interior de 6x3 celdas")
	if start == NO_CELL:
		return errors
	for dy in 3:
		for dx in 3:
			grid.try_set_owner(start.x + dx, start.y + dy, TerritoryGrid.OWNER_PLAYER)
			grid.try_set_owner(start.x + 3 + dx, start.y + dy, TerritoryGrid.OWNER_AI_1)
	var view := _make_view(grid)
	var player_color: Color = grid.get_nation(TerritoryGrid.OWNER_PLAYER)["color"]
	var ai_color: Color = grid.get_nation(TerritoryGrid.OWNER_AI_1)["color"]
	for dy in 3:
		# Columnas a ambos lados del límite: las dos son frontera, cada una con su color.
		_expect_color(errors, view.get_image_pixel(start.x + 2, start.y + dy), player_color.darkened(MapView.BORDER_DARKEN), "borde del jugador, fila %d" % dy)
		_expect_color(errors, view.get_image_pixel(start.x + 3, start.y + dy), ai_color.darkened(MapView.BORDER_DARKEN), "borde de la IA 1, fila %d" % dy)
	# Con 3 filas, la fila central de la columna 0 sigue siendo borde (vecino sin reclamar a la izquierda).
	_expect(errors, view.is_border(start.x, start.y + 1), true, "el límite con tierra sin reclamar también es frontera")
	view.free()
	return errors


# ---------------------------------------------------------------------------
# Coordenadas
# ---------------------------------------------------------------------------

func _test_cell_position_roundtrip() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid, Vector2(160, 76), 3.0)
	var samples: Array[Vector2i] = [Vector2i(0, 0), Vector2i(319, 0), Vector2i(0, 179), Vector2i(319, 179), Vector2i(108, 114), Vector2i(212, 66), Vector2i(160, 90)]
	for cell in samples:
		_expect(errors, view.cell_from_global(view.cell_center_global(cell)), cell, "centro de %s" % cell)
		# Esquina superior izquierda de la celda en pantalla: posición + celda * escala.
		var top_left := Vector2(160, 76) + Vector2(cell) * 3.0 + Vector2(0.05, 0.05)
		_expect(errors, view.cell_from_global(top_left), cell, "esquina superior izquierda (+0,05) de %s" % cell)
		_expect(errors, view.cell_from_global(top_left + Vector2(2.85, 2.85)), cell, "esquina inferior derecha (-0,15) de %s" % cell)
	# Posición visual concreta (escala 3): la celda (108, 114) ocupa x 484..486, y 418..420.
	_expect(errors, view.cell_center_global(Vector2i(108, 114)), Vector2(160 + 108 * 3 + 1.5, 76 + 114 * 3 + 1.5), "centro visual de (108, 114)")
	# Un píxel antes de la celda cae en la anterior.
	_expect(errors, view.cell_from_global(Vector2(160 + 108 * 3 - 0.5, 76 + 114 * 3 + 1)), Vector2i(107, 114), "píxel anterior en x")
	# cell_from_local trabaja con 1 unidad por celda.
	_expect(errors, view.cell_from_local(Vector2(5.9, 7.2)), Vector2i(5, 7), "cell_from_local")
	view.free()
	return errors


func _test_map_bounds() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid)
	_expect(errors, view.cell_from_local(Vector2(0, 0)), Vector2i(0, 0), "esquina (0, 0)")
	_expect(errors, view.cell_from_local(Vector2(319.99, 179.99)), Vector2i(319, 179), "esquina (319, 179)")
	_expect(errors, view.cell_from_local(Vector2(320, 10)), NO_CELL, "x = 320")
	_expect(errors, view.cell_from_local(Vector2(10, 180)), NO_CELL, "y = 180")
	_expect(errors, view.cell_from_local(Vector2(-0.01, 10)), NO_CELL, "x ligeramente negativo")
	_expect(errors, view.cell_from_local(Vector2(10, -0.01)), NO_CELL, "y ligeramente negativo")
	_expect(errors, view.cell_from_local(Vector2(-500, 9000)), NO_CELL, "muy lejos")
	# En pantalla: un píxel antes del origen y justo después del final.
	_expect(errors, view.cell_from_global(Vector2(159.5, 100)), NO_CELL, "a la izquierda del mapa")
	_expect(errors, view.cell_from_global(Vector2(160 + 960 + 0.5, 100)), NO_CELL, "a la derecha del mapa")
	_expect(errors, view.cell_from_global(Vector2(300, 76 + 540 + 0.5)), NO_CELL, "debajo del mapa")
	_expect(errors, view.cell_from_global(Vector2(1279, 719)), NO_CELL, "esquina de la ventana")
	view.free()
	return errors


func _test_transform_changes() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	# Otra posición y escala.
	var view := _make_view(grid, Vector2(40, 20), 4.0)
	var cell := Vector2i(108, 114)
	_expect(errors, view.cell_from_global(view.cell_center_global(cell)), cell, "ida y vuelta con escala 4")
	_expect(errors, view.cell_from_global(Vector2(40, 20) + Vector2(cell) * 4.0 + Vector2(3.9, 0.1)), cell, "dentro de la celda con escala 4")
	_expect(errors, view.cell_from_global(Vector2(40, 20) + Vector2(cell) * 4.0 + Vector2(4.1, 0.1)), Vector2i(109, 114), "siguiente celda con escala 4")
	# Mover el nodo después de crearlo.
	view.position = Vector2(300, 200)
	view.scale = Vector2(2, 2)
	_expect(errors, view.cell_from_global(view.cell_center_global(cell)), cell, "ida y vuelta tras mover y reescalar")
	_expect(errors, view.cell_from_global(Vector2(300, 200) + Vector2(10.5, 10.5)), Vector2i(5, 5), "posición conocida tras mover")
	view.free()

	# Con un nodo padre desplazado y escalado.
	var parent := Node2D.new()
	parent.position = Vector2(100, 50)
	parent.scale = Vector2(2, 2)
	_tree.root.add_child(parent)
	var child: MapView = MapView.new()
	child.position = Vector2(10, 5)
	child.scale = Vector2(1.5, 1.5)
	parent.add_child(child)
	child.set_grid(grid)
	for sample in [Vector2i(0, 0), Vector2i(50, 60), Vector2i(319, 179)]:
		_expect(errors, child.cell_from_global(child.cell_center_global(sample)), sample, "con padre transformado, celda %s" % sample)
	# Global del origen del hijo = 100 + 10 * 2 = 120, 50 + 5 * 2 = 60; cada celda mide 3 en pantalla.
	_expect(errors, child.cell_from_global(Vector2(120, 60) + Vector2(3.1, 0.1)), Vector2i(1, 0), "celda conocida con padre")
	parent.free()
	return errors


# ---------------------------------------------------------------------------
# Resaltado y selección
# ---------------------------------------------------------------------------

func _land_cell(grid: TerritoryGrid) -> Vector2i:
	return _find_cell(grid, func(c: Vector2i) -> bool: return _is_unclaimed_interior(grid, c))


func _test_hover() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid)
	var land := _land_cell(grid)
	var water := _find_cell(grid, func(c: Vector2i) -> bool: return _is_water(grid, c))
	view.pointer_moved(view.cell_center_global(land))
	_expect(errors, view.hover_cell, land, "hover sobre tierra")
	view.pointer_moved(view.cell_center_global(water))
	_expect(errors, view.hover_cell, NO_CELL, "hover sobre agua")
	view.pointer_moved(view.cell_center_global(land))
	view.pointer_moved(Vector2(5, 5))
	_expect(errors, view.hover_cell, NO_CELL, "hover fuera del mapa")
	_expect(errors, view.selected_cell, NO_CELL, "mover el ratón no selecciona")
	view.free()
	return errors


func _test_selection() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid)
	var land := _land_cell(grid)
	var water := _find_cell(grid, func(c: Vector2i) -> bool: return _is_water(grid, c))
	var nation_cell := _find_cell(grid, func(c: Vector2i) -> bool: return grid.get_cell_owner(c.x, c.y) == TerritoryGrid.OWNER_PLAYER)

	view.pointer_pressed(view.cell_center_global(land))
	_expect(errors, view.selected_cell, land, "clic en tierra sin reclamar")
	view.pointer_pressed(view.cell_center_global(nation_cell))
	_expect(errors, view.selected_cell, nation_cell, "clic en territorio nacional")
	view.pointer_pressed(view.cell_center_global(water))
	_expect(errors, view.selected_cell, NO_CELL, "clic en agua limpia la selección")
	view.pointer_pressed(view.cell_center_global(land))
	view.pointer_pressed(Vector2(1000, 700))
	_expect(errors, view.selected_cell, NO_CELL, "clic fuera del mapa limpia la selección")
	view.pointer_pressed(view.cell_center_global(land))
	view.clear_selection()
	_expect(errors, view.selected_cell, NO_CELL, "clear_selection")
	# Clic en agua o fuera sin selección previa: sin error y sigue vacía.
	view.pointer_pressed(view.cell_center_global(water))
	view.pointer_pressed(Vector2(-50, -50))
	_expect(errors, view.selected_cell, NO_CELL, "clics sin selección previa")
	view.free()
	return errors


func _test_selection_signals() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid)
	var land := _land_cell(grid)
	var emitted: Array = []
	view.selection_changed.connect(func(cell: Vector2i) -> void: emitted.append(cell))
	view.pointer_pressed(view.cell_center_global(land))
	view.pointer_pressed(view.cell_center_global(land))
	_expect(errors, emitted, [land], "seleccionar dos veces la misma celda emite una vez")
	view.pointer_pressed(Vector2(5, 5))
	_expect(errors, emitted, [land, NO_CELL], "limpiar emite NO_CELL")
	view.clear_selection()
	_expect(errors, emitted.size(), 2, "limpiar una selección ya vacía no emite")
	view.free()
	return errors


func _test_set_grid_clears() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid)
	var land := _land_cell(grid)
	view.pointer_moved(view.cell_center_global(land))
	view.pointer_pressed(view.cell_center_global(land))
	view.set_grid(TerritoryGrid.new())
	_expect(errors, view.selected_cell, NO_CELL, "selección tras set_grid")
	_expect(errors, view.hover_cell, NO_CELL, "resaltado tras set_grid")
	view.free()
	return errors


# ---------------------------------------------------------------------------
# Actualización de la imagen
# ---------------------------------------------------------------------------

func _test_refresh_cell() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid)
	var target := _land_cell(grid)
	var before := _snapshot_pixels(view)
	_expect(errors, grid.try_set_owner(target.x, target.y, TerritoryGrid.OWNER_AI_2), true, "asignar propietario en la cuadrícula")
	# Sin refresh_cell la imagen no cambia sola.
	_expect(errors, _same_color(view.get_image_pixel(target.x, target.y), before[target.y * TerritoryGrid.WIDTH + target.x]), true, "la imagen no cambia sin refresh_cell")
	view.refresh_cell(target.x, target.y)
	var allowed: Array[Vector2i] = [target, target + Vector2i(1, 0), target + Vector2i(-1, 0), target + Vector2i(0, 1), target + Vector2i(0, -1)]
	var outside_changes := 0
	for y in TerritoryGrid.HEIGHT:
		for x in TerritoryGrid.WIDTH:
			var changed := not _same_color(view.get_image_pixel(x, y), before[y * TerritoryGrid.WIDTH + x])
			if changed and not allowed.has(Vector2i(x, y)):
				outside_changes += 1
	_expect(errors, outside_changes, 0, "píxeles cambiados fuera de la celda y sus vecinas")
	var nation_color: Color = grid.get_nation(TerritoryGrid.OWNER_AI_2)["color"]
	_expect_color(errors, view.get_image_pixel(target.x, target.y), nation_color.darkened(MapView.BORDER_DARKEN), "la celda cambiada es de frontera")
	# Los vecinos (sin reclamar) que ahora tocan otra nación siguen sin reclamar: color de tierra.
	# Lo incremental debe coincidir con repintar todo.
	var incremental := _snapshot_pixels(view)
	view.refresh_all()
	var full := _snapshot_pixels(view)
	var differences := 0
	for i in incremental.size():
		if not _same_color(incremental[i], full[i]):
			differences += 1
	_expect(errors, differences, 0, "diferencias entre actualización incremental y completa")
	# Coordenadas inválidas: sin error ni cambios.
	view.refresh_cell(-1, 5)
	view.refresh_cell(320, 5)
	view.free()
	return errors


# ---------------------------------------------------------------------------
# Información y datos
# ---------------------------------------------------------------------------

func _test_info_panel_text() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	_expect(errors, InfoPanel.describe(grid, NO_CELL), InfoPanel.EMPTY_TEXT, "sin selección")
	_expect(errors, InfoPanel.describe(grid, Vector2i(320, 0)), InfoPanel.EMPTY_TEXT, "fuera de límites")
	_expect(errors, InfoPanel.describe(null, Vector2i(1, 1)), InfoPanel.EMPTY_TEXT, "sin cuadrícula")
	var land := _land_cell(grid)
	_expect(errors, InfoPanel.describe(grid, land), "Celda (%d, %d) · Tierra\nPropietario: Sin reclamar" % [land.x, land.y], "tierra sin reclamar")
	var water := _find_cell(grid, func(c: Vector2i) -> bool: return _is_water(grid, c))
	_expect(errors, InfoPanel.describe(grid, water), "Celda (%d, %d) · Agua\nPropietario: Sin reclamar" % [water.x, water.y], "agua")
	for nation_id: int in grid.get_nation_ids():
		var cell := _find_cell(grid, func(c: Vector2i) -> bool: return grid.get_cell_owner(c.x, c.y) == nation_id)
		var nation_name: String = grid.get_nation(nation_id)["name"]
		_expect(errors, InfoPanel.describe(grid, cell), "Celda (%d, %d) · Tierra\nPropietario: %s" % [cell.x, cell.y, nation_name], "nación %d" % nation_id)
	# El texto sigue a la cuadrícula: tras cambiarla desde fuera, describe lee el nuevo valor.
	grid.try_set_owner(land.x, land.y, TerritoryGrid.OWNER_AI_3)
	var ai_name: String = grid.get_nation(TerritoryGrid.OWNER_AI_3)["name"]
	_expect(errors, InfoPanel.describe(grid, land).ends_with(ai_name), true, "el panel lee el propietario actual de la cuadrícula")
	return errors


func _test_interaction_keeps_data() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var view := _make_view(grid)
	var terrain_before := grid.copy_terrain_data()
	var owners_before := grid.copy_owner_data()
	# Barrido de movimientos y clics por todo el mapa y fuera de él.
	for y in range(-5, 190, 7):
		for x in range(-5, 330, 9):
			var point := Vector2(160 + x * 3 + 1, 76 + y * 3 + 1)
			view.pointer_moved(point)
			view.pointer_pressed(point)
	view.clear_selection()
	view.refresh_all()
	_expect(errors, grid.copy_terrain_data() == terrain_before, true, "el terreno no cambió")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "los propietarios no cambiaron")
	_expect(errors, grid.copy_terrain_data().size(), TerritoryGrid.CELL_COUNT, "tamaño del terreno")
	view.free()
	return errors
