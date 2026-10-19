## Vista pixelada del territorio (hito 4). Solo representa e inspecciona: no modifica nada.
##
## TerritoryGrid es la ÚNICA fuente de terreno y propietario. Esta vista solo guarda una
## imagen de colores (caché de dibujo, 1 píxel = 1 celda) y la selección/resaltado.
## Nunca llama a try_set_owner ni escribe en la cuadrícula.
##
## Dibujo (1 píxel de la imagen = 1 celda; la escala sale de `scale` del nodo, p. ej. 3):
##   - Agua: azul oscuro apagado.
##   - Tierra sin reclamar: gris neutro; si toca agua, un tono algo más oscuro (costa).
##   - Tierra de una nación: color de la nación; si es celda de frontera
##     (ver is_border), el mismo color oscurecido.
##   Las fronteras no se almacenan: salen de comparar vecinos ortogonales.
##   Entre dos naciones queda una línea de 2 celdas (una de cada lado) sin huecos.
##   Frontera entre nación y tierra sin reclamar, y costa de una nación: línea de 1 celda
##   en la propia nación. La costa de la tierra sin reclamar usa el tono de costa.
##   - Celda ocupada militarmente (hito 9, si se asigna `occupation`): en tablero de ajedrez, las
##     celdas con (x + y) par en un tono claro del color del OCUPANTE y las demás con el color de la
##     nación propietaria (con su borde). Se ve de un vistazo que no es una conquista consolidada ni
##     el color liso de ninguna nación. La ocupación nunca cambia el propietario ni las fronteras.
##
## Coordenadas: la imagen se dibuja en (0, 0) del nodo con 1 unidad por celda; posición y
## escala del nodo la colocan en pantalla. cell_from_local / cell_from_global invierten
## esa transformación (la global incluye posición, escala y padres del nodo).
##
## Actualización: la imagen se pinta entera al asignar la cuadrícula (refresh_all) y
## después solo cambian las celdas que se pidan (refresh_cell: la celda y sus 4 vecinas,
## porque las fronteras dependen de los vecinos). La cuadrícula no emite señales, así que
## quien la modifique debe llamar a refresh_cell. En esta fase el mapa es estático.
extends Node2D

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Occupation := preload("res://scripts/world/occupation.gd")

## Se emite al cambiar la selección; cell == NO_CELL indica selección vacía.
signal selection_changed(cell: Vector2i)
## Se emite al cambiar la celda resaltada por el ratón; NO_CELL = ninguna.
signal hover_changed(cell: Vector2i)
## Se emite en cada clic izquierdo con la celda pulsada (NO_CELL si cae fuera del mapa), incluso
## si la selección está desactivada. La pantalla lo usa para el modo de fundación (hito 6).
signal cell_clicked(cell: Vector2i)

const NO_CELL := Vector2i(-1, -1)

const COLOR_WATER := Color(0.10, 0.16, 0.25)
const COLOR_LAND := Color(0.37, 0.39, 0.36)
const COLOR_SHORE := Color(0.30, 0.32, 0.30)
const BORDER_DARKEN := 0.35
## Aclarado del color del ocupante en las celdas del tablero de ocupación.
const OCCUPATION_LIGHTEN := 0.3
const HOVER_COLOR := Color(1, 1, 1, 0.30)
const SELECT_FILL_COLOR := Color(1, 1, 1, 0.30)
const SELECT_RING_COLOR := Color(1, 1, 1, 0.90)

const _NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var grid: TerritoryGrid
## Ocupación militar (hito 9). Opcional: sin ella, el dibujo es el de siempre. Quien la modifique debe
## repintar las celdas afectadas con refresh_cell (Occupation.cells_changed las anuncia).
var occupation: Occupation = null
var selected_cell: Vector2i = NO_CELL
var hover_cell: Vector2i = NO_CELL
## Si es false, los clics no cambian la selección (solo emiten cell_clicked).
var selection_enabled: bool = true

var _image: Image
var _texture: ImageTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Asigna la cuadrícula a representar (obligatorio antes de usar la vista), limpia selección y resaltado y pinta todo.
func set_grid(new_grid: TerritoryGrid) -> void:
	grid = new_grid
	_set_selected(NO_CELL)
	_set_hover(NO_CELL)
	refresh_all()


# ---------------------------------------------------------------------------
# Colores y fronteras (derivados de la cuadrícula; nada se almacena aparte)
# ---------------------------------------------------------------------------

## True si (x, y) es tierra y algún vecino ortogonal es agua o tiene otro propietario.
## Los vecinos fuera del mapa se ignoran.
func is_border(x: int, y: int) -> bool:
	if not grid.is_land(x, y):
		return false
	var owner_id := grid.get_cell_owner(x, y)
	for step in _NEIGHBORS:
		var nx := x + step.x
		var ny := y + step.y
		if not grid.is_valid_coord(nx, ny):
			continue
		if not grid.is_land(nx, ny) or grid.get_cell_owner(nx, ny) != owner_id:
			return true
	return false


## Color con el que se pinta la celda (x, y).
func cell_color(x: int, y: int) -> Color:
	if not grid.is_land(x, y):
		return COLOR_WATER
	var owner_id := grid.get_cell_owner(x, y)
	if owner_id == TerritoryGrid.OWNER_NONE:
		return COLOR_SHORE if _touches_water(x, y) else COLOR_LAND
	var base: Color = grid.get_nation(owner_id)["color"]
	var owner_color := base.darkened(BORDER_DARKEN) if is_border(x, y) else base
	if occupation != null and (x + y) % 2 == 0:
		var occupier := occupation.occupier_at(Vector2i(x, y))
		if occupier != TerritoryGrid.OWNER_NONE and grid.has_nation(occupier):
			var occupier_color: Color = grid.get_nation(occupier)["color"]
			return occupier_color.lightened(OCCUPATION_LIGHTEN)
	return owner_color


func _touches_water(x: int, y: int) -> bool:
	for step in _NEIGHBORS:
		var nx := x + step.x
		var ny := y + step.y
		if grid.is_valid_coord(nx, ny) and not grid.is_land(nx, ny):
			return true
	return false


# ---------------------------------------------------------------------------
# Imagen
# ---------------------------------------------------------------------------

## Repinta toda la imagen (una vez al asignar la cuadrícula). 57.600 celdas.
func refresh_all() -> void:
	if grid == null:
		return
	if _image == null:
		_image = Image.create(grid.get_width(), grid.get_height(), false, Image.FORMAT_RGBA8)
	for y in grid.get_height():
		for x in grid.get_width():
			_image.set_pixel(x, y, cell_color(x, y))
	_upload()


## Repinta la celda y sus 4 vecinas (las fronteras dependen de los vecinos).
## Las coordenadas fuera de límites se ignoran.
func refresh_cell(x: int, y: int) -> void:
	if grid == null or _image == null or not grid.is_valid_coord(x, y):
		return
	_image.set_pixel(x, y, cell_color(x, y))
	for step in _NEIGHBORS:
		var nx := x + step.x
		var ny := y + step.y
		if grid.is_valid_coord(nx, ny):
			_image.set_pixel(nx, ny, cell_color(nx, ny))
	_upload()


## Color actual del píxel de la imagen de la celda (para pruebas), o Color(0,0,0,0) si no hay imagen.
func get_image_pixel(x: int, y: int) -> Color:
	if _image == null or x < 0 or y < 0 or x >= _image.get_width() or y >= _image.get_height():
		return Color(0, 0, 0, 0)
	return _image.get_pixel(x, y)


func _upload() -> void:
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)
	queue_redraw()


# ---------------------------------------------------------------------------
# Coordenadas ratón/píxel <-> celda
# ---------------------------------------------------------------------------

## Celda bajo un punto en coordenadas LOCALES del nodo (1 unidad = 1 celda),
## o NO_CELL si cae fuera del mapa.
func cell_from_local(local_point: Vector2) -> Vector2i:
	if grid == null:
		return NO_CELL
	var cell := Vector2i(floori(local_point.x), floori(local_point.y))
	return cell if grid.is_valid_coord(cell.x, cell.y) else NO_CELL


## Celda bajo un punto en coordenadas globales (las del ratón). Requiere el nodo en el árbol.
func cell_from_global(global_point: Vector2) -> Vector2i:
	return cell_from_local(to_local(global_point))


## Posición global del centro visual de una celda. Requiere el nodo en el árbol.
func cell_center_global(cell: Vector2i) -> Vector2:
	return to_global(Vector2(cell) + Vector2(0.5, 0.5))


# ---------------------------------------------------------------------------
# Resaltado y selección (solo inspección)
# ---------------------------------------------------------------------------

## Solo las celdas de tierra se resaltan y se pueden seleccionar.
func is_selectable(cell: Vector2i) -> bool:
	return grid != null and cell != NO_CELL and grid.is_land(cell.x, cell.y)


func pointer_moved(global_point: Vector2) -> void:
	var cell := cell_from_global(global_point)
	_set_hover(cell if is_selectable(cell) else NO_CELL)


## Clic izquierdo: emite cell_clicked y, si la selección está activada, selecciona la celda de
## tierra bajo el punto; en agua o fuera del mapa limpia la selección.
func pointer_pressed(global_point: Vector2) -> void:
	var cell := cell_from_global(global_point)
	cell_clicked.emit(cell)
	if not selection_enabled:
		return
	_set_selected(cell if is_selectable(cell) else NO_CELL)


func clear_selection() -> void:
	_set_selected(NO_CELL)


func _set_selected(cell: Vector2i) -> void:
	if cell == selected_cell:
		return
	selected_cell = cell
	queue_redraw()
	selection_changed.emit(cell)


func _set_hover(cell: Vector2i) -> void:
	if cell == hover_cell:
		return
	hover_cell = cell
	queue_redraw()
	hover_changed.emit(cell)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_moved(get_global_mouse_position())
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			pointer_pressed(get_global_mouse_position())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_set_hover(NO_CELL)


func _draw() -> void:
	if _texture == null:
		return
	draw_texture(_texture, Vector2.ZERO)
	if hover_cell != NO_CELL and hover_cell != selected_cell:
		draw_rect(Rect2(Vector2(hover_cell), Vector2.ONE), HOVER_COLOR)
	if selected_cell != NO_CELL:
		var x := float(selected_cell.x)
		var y := float(selected_cell.y)
		draw_rect(Rect2(x, y, 1, 1), SELECT_FILL_COLOR)
		draw_rect(Rect2(x - 1, y - 1, 3, 1), SELECT_RING_COLOR)
		draw_rect(Rect2(x - 1, y + 1, 3, 1), SELECT_RING_COLOR)
		draw_rect(Rect2(x - 1, y, 1, 1), SELECT_RING_COLOR)
		draw_rect(Rect2(x + 1, y, 1, 1), SELECT_RING_COLOR)
