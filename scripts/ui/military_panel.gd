## Panel militar del jugador (hito 8): soldados totales, asignados y disponibles; creación de
## sectores (celda propia seleccionada en el mapa + una de cuatro direcciones); lista de sectores;
## ajuste de los soldados de un sector y liberación (eliminar el sector). Va en la columna
## izquierda, fuera del mapa, y captura el clic para no seleccionar el mapa por error.
##
## No guarda datos propios salvo la selección de interfaz (celda de origen, dirección y sector
## elegido): cada refresh() lee del estado real (Military, Population). Los controles solo llaman
## a las órdenes de Military; el reglamento (límites, duplicados…) vive allí. Los textos salen de
## funciones estáticas para poder probarlos sin nodos. Es un panel funcional: el aspecto se
## mejorará en la fase visual.
extends PanelContainer

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Military := preload("res://scripts/world/military.gd")
const Population := preload("res://scripts/world/population.gd")

## Se emite al cambiar el sector elegido en la lista (Military.NO_SECTOR = ninguno).
signal sector_selected(sector_id: int)

const NO_CELL := Vector2i(-1, -1)
const NO_DIRECTION := -1
const FONT_SIZE := 12
const INNER_WIDTH := 124
const TEXT_COLOR := Color(0.85, 0.87, 0.9)
const MUTED_COLOR := Color(0.6, 0.64, 0.7)
const WARN_COLOR := Color(0.95, 0.75, 0.3)
## Cambios de la asignación que ofrecen los botones (el último es el mayor).
const ADJUST_STEPS: Array[int] = [1, 5]
const LIST_HEIGHT := 56

var _military: Military
var _population: Population
var _grid: TerritoryGrid
var _nation_id: int = TerritoryGrid.INVALID

var _origin: Vector2i = NO_CELL
var _direction: int = NO_DIRECTION
var _selected_sector: int = Military.NO_SECTOR
var _listed_ids: Array = []

var _summary_label: Label
var _plan_label: Label
var _direction_buttons: Array[Button] = []
var _create_button: Button
var _list: ItemList
var _detail_label: Label
var _adjust_buttons: Dictionary = {}  # delta (int) -> Button
var _release_button: Button
var _message_label: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_add_heading(box, "EJÉRCITO")
	_summary_label = _add_label(box, TEXT_COLOR, "ResumenMilitar")

	_add_heading(box, "NUEVO SECTOR")
	_plan_label = _add_label(box, TEXT_COLOR, "PlanSector")
	var directions := HBoxContainer.new()
	directions.add_theme_constant_override("separation", 2)
	box.add_child(directions)
	var group := ButtonGroup.new()
	for direction in Military.DIRECTION_NAMES.size():
		var button := _make_button(Military.DIRECTION_SHORT_NAMES[direction], "BotonDireccion" + Military.DIRECTION_NAMES[direction])
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = Military.DIRECTION_NAMES[direction]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_direction_pressed.bind(direction))
		directions.add_child(button)
		_direction_buttons.append(button)
	_create_button = _make_button("Crear sector", "BotonCrearSector")
	_create_button.pressed.connect(_on_create_pressed)
	box.add_child(_create_button)

	_add_heading(box, "SECTORES")
	_list = ItemList.new()
	_list.name = "ListaSectores"
	_list.focus_mode = Control.FOCUS_NONE
	_list.custom_minimum_size = Vector2(INNER_WIDTH, LIST_HEIGHT)
	_list.add_theme_font_size_override("font_size", FONT_SIZE)
	_list.item_selected.connect(_on_list_item_selected)
	box.add_child(_list)
	_detail_label = _add_label(box, TEXT_COLOR, "DetalleSector")
	var adjust := HBoxContainer.new()
	adjust.add_theme_constant_override("separation", 2)
	box.add_child(adjust)
	for step: int in [-ADJUST_STEPS[1], -ADJUST_STEPS[0], ADJUST_STEPS[0], ADJUST_STEPS[1]]:
		var button := _make_button(adjust_button_text(step), "BotonAjuste%s%d" % ["Mas" if step > 0 else "Menos", absi(step)])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_adjust_pressed.bind(step))
		adjust.add_child(button)
		_adjust_buttons[step] = button
	_release_button = _make_button("Liberar y eliminar", "BotonLiberarSector")
	_release_button.pressed.connect(_on_release_pressed)
	box.add_child(_release_button)
	_message_label = _add_label(box, MUTED_COLOR, "MensajeMilitar")


func _add_heading(box: Container, text: String) -> void:
	var label := _add_label(box, MUTED_COLOR)
	label.text = text


## Los controles con nombre se buscan por él en las pruebas (find_child).
func _add_label(box: Container, color: Color, node_name: String = "") -> Label:
	var label := Label.new()
	if node_name != "":
		label.name = node_name
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(INNER_WIDTH, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return label


func _make_button(text: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	return button


## Conecta el panel con los datos del jugador y lo refresca. Se vuelve a dibujar solo cada vez
## que Military o Population emiten `changed`. Military debe haberse creado antes que el panel:
## así corrige la asignación antes de que el panel lea los totales.
func setup(military: Military, population: Population, grid: TerritoryGrid, nation_id: int) -> void:
	_military = military
	_population = population
	_grid = grid
	_nation_id = nation_id
	military.changed.connect(refresh)
	population.changed.connect(refresh)
	grid.ownership_changed.connect(refresh)
	refresh()


# ---------------------------------------------------------------------------
# Estado de la interfaz
# ---------------------------------------------------------------------------

## Celda de origen elegida (la selección del mapa). Cualquier celda vale aquí; la validez se
## comprueba al pintar el plan y al crear. NO_CELL = ninguna.
func set_origin(cell: Vector2i) -> void:
	_origin = cell
	refresh()


func chosen_origin() -> Vector2i:
	return _origin


## Dirección elegida (Military.DIR_*) o NO_DIRECTION.
func set_direction(direction: int) -> void:
	_direction = direction if direction >= Military.DIR_NORTH and direction <= Military.DIR_WEST else NO_DIRECTION
	for index in _direction_buttons.size():
		_direction_buttons[index].set_pressed_no_signal(index == _direction)
	refresh()


func chosen_direction() -> int:
	return _direction


## Elige un sector de la lista (Military.NO_SECTOR o un id inexistente = ninguno).
func select_sector(sector_id: int) -> void:
	var new_id := sector_id if _is_own_sector(sector_id) else Military.NO_SECTOR
	var changed_selection := new_id != _selected_sector
	_selected_sector = new_id
	refresh()
	if changed_selection:
		sector_selected.emit(_selected_sector)


func selected_sector() -> int:
	return _selected_sector


## Vuelve a leer el estado real y actualiza todos los textos y controles.
func refresh() -> void:
	if _military == null or _summary_label == null:
		return
	_summary_label.text = summary_text(_military.get_summary(_nation_id))
	var plan_error := _plan_error()
	_plan_label.text = plan_text(_origin, _direction, plan_error)
	_create_button.disabled = plan_error != Military.SECTOR_OK
	if _selected_sector != Military.NO_SECTOR and not _is_own_sector(_selected_sector):
		_selected_sector = Military.NO_SECTOR
		sector_selected.emit(Military.NO_SECTOR)
	_rebuild_list()
	_refresh_detail()


func _is_own_sector(sector_id: int) -> bool:
	return _military != null and _military.has_sector(sector_id) and _military.get_sector(sector_id)["owner"] == _nation_id


## SECTOR_OK si con el origen y la dirección elegidos se podría crear el sector; si no, el motivo.
func _plan_error() -> int:
	if _origin == NO_CELL or _direction == NO_DIRECTION:
		return Military.SECTOR_ERR_ORIGIN_NOT_OWNED if _origin == NO_CELL else Military.SECTOR_ERR_BAD_DIRECTION
	return _military.validate_sector(_nation_id, _origin, _direction)


func _rebuild_list() -> void:
	var ids := _military.get_sector_ids(_nation_id)
	if ids != _listed_ids:
		_list.clear()
		for sector_id: int in ids:
			_list.add_item("")
			_list.set_item_metadata(_list.item_count - 1, sector_id)
		_listed_ids = ids
	for index in ids.size():
		_list.set_item_text(index, list_item_text(_military.get_sector(ids[index])))
	if _selected_sector == Military.NO_SECTOR:
		_list.deselect_all()
	else:
		_list.select(ids.find(_selected_sector))


func _refresh_detail() -> void:
	var has_selection := _selected_sector != Military.NO_SECTOR
	var sector := _military.get_sector(_selected_sector)
	_detail_label.text = detail_text(sector, _target_owner_text(_selected_sector)) if has_selection else "Selecciona un sector de la lista."
	var assigned: int = sector["soldiers"] if has_selection else 0
	var available := _military.available_soldiers(_nation_id)
	for delta: int in _adjust_buttons:
		var button: Button = _adjust_buttons[delta]
		button.disabled = not has_selection or (assigned <= 0 if delta < 0 else available <= 0)
	_release_button.disabled = not has_selection


func _target_owner_text(sector_id: int) -> String:
	var owner_id := _military.target_owner(sector_id)
	if owner_id == _nation_id:
		return "Tu territorio"
	if owner_id == TerritoryGrid.OWNER_NONE:
		return "Sin reclamar"
	return _grid.get_nation(owner_id)["name"]


# ---------------------------------------------------------------------------
# Controles
# ---------------------------------------------------------------------------

func _on_direction_pressed(direction: int) -> void:
	set_direction(direction)


func _on_create_pressed() -> void:
	var result := _military.create_sector(_nation_id, _origin, _direction)
	_message_label.text = Military.sector_error_message(result["error"])
	if result["ok"]:
		select_sector(result["id"])


func _on_list_item_selected(index: int) -> void:
	select_sector(_list.get_item_metadata(index))


## Cambia la asignación del sector elegido en `delta`, recortado a lo que hay: sube hasta los
## disponibles y baja hasta 0 (nunca se pide más de lo posible).
func _on_adjust_pressed(delta: int) -> void:
	if _selected_sector == Military.NO_SECTOR:
		return
	var assigned: int = _military.get_sector(_selected_sector)["soldiers"]
	var clamped := mini(delta, _military.available_soldiers(_nation_id)) if delta > 0 else maxi(delta, -assigned)
	var code := _military.adjust_sector_soldiers(_selected_sector, clamped)
	_message_label.text = Military.assign_error_message(code)


func _on_release_pressed() -> void:
	if _selected_sector == Military.NO_SECTOR:
		return
	var released: int = _military.get_sector(_selected_sector)["soldiers"]
	_military.remove_sector(_selected_sector)
	_message_label.text = "Sector eliminado. %d soldados vuelven a la reserva." % released


# ---------------------------------------------------------------------------
# Textos (funciones puras, probadas sin interfaz)
# ---------------------------------------------------------------------------

## "Soldados 6\nAsignados 2\nDisponibles 4" a partir de Military.get_summary.
static func summary_text(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Sin ejército"
	return "Soldados %d\nAsignados %d\nDisponibles %d" % [summary["total"], summary["assigned"], summary["available"]]


## Texto del plan de sector: origen, objetivo y motivo si no se puede crear.
static func plan_text(origin: Vector2i, direction: int, error: int) -> String:
	if origin == NO_CELL:
		return "Selecciona una celda propia en el mapa."
	var text := "Origen (%d, %d)" % [origin.x, origin.y]
	if direction == NO_DIRECTION:
		return text + "\nElige una dirección."
	var target := Military.target_cell(origin, direction)
	text += "\nObjetivo (%d, %d) · %s" % [target.x, target.y, Military.DIRECTION_NAMES[direction]]
	return text + "\n" + (Military.sector_error_message(error) if error != Military.SECTOR_OK else "Listo para crear.")


## "+5" / "-1" en los botones de ajuste.
static func adjust_button_text(delta: int) -> String:
	return "+%d" % delta if delta > 0 else "%d" % delta


## Línea de la lista: "#3 (12,12) E · 5".
static func list_item_text(sector: Dictionary) -> String:
	var origin: Vector2i = sector["origin"]
	return "#%d (%d,%d) %s · %d" % [sector["id"], origin.x, origin.y, Military.DIRECTION_SHORT_NAMES[sector["direction"]], sector["soldiers"]]


## Detalle del sector elegido: origen, objetivo, dirección, a quién pertenece el objetivo y soldados.
static func detail_text(sector: Dictionary, target_owner_text: String) -> String:
	var origin: Vector2i = sector["origin"]
	var target: Vector2i = sector["target"]
	return "Sector #%d · %s\nOrigen (%d, %d)\nObjetivo (%d, %d)\n%s\nSoldados %d" % [sector["id"], Military.DIRECTION_NAMES[sector["direction"]],
			origin.x, origin.y, target.x, target.y, target_owner_text, sector["soldiers"]]
