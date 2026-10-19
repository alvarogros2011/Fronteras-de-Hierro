## Panel militar del jugador (hito 8): resumen de soldados (totales, asignados y disponibles),
## creación de un sector en cuatro pasos (celda propia del mapa, dirección, cantidad con un
## deslizador y un botón) y edición del sector elegido (mismo tipo de deslizador, «Aplicar» y
## «Liberar y eliminar»). Va en la columna izquierda, fuera del mapa, y captura el clic para no
## seleccionar el mapa por error.
##
## No guarda datos propios salvo la selección de interfaz (celda de origen, dirección y sector
## elegido) y lo que marcan los deslizadores: cada refresh() lee del estado real (Military,
## Population). Los controles solo llaman a las órdenes de Military; el reglamento (límites,
## duplicados, objetivo no propio…) vive allí. Los deslizadores nunca ofrecen más de lo que se
## puede asignar de verdad (la reserva, más lo que ya tiene el sector al editarlo). Los textos
## salen de funciones estáticas para poder probarlos sin nodos. Es un panel funcional: el aspecto
## se mejorará en la fase visual.
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
const LIST_HEIGHT := 56

var _military: Military
var _population: Population
var _grid: TerritoryGrid
var _nation_id: int = TerritoryGrid.INVALID

var _origin: Vector2i = NO_CELL
var _direction: int = NO_DIRECTION
var _selected_sector: int = Military.NO_SECTOR
var _listed_ids: Array = []
## Última asignación del sector elegido que se volcó en el deslizador de edición (-1 = ninguna):
## mientras no cambie, el valor que mueve el jugador se respeta aunque el panel se refresque.
var _edit_shown_sector: int = Military.NO_SECTOR
var _edit_shown_assigned: int = -1
var _refreshing: bool = false

var _summary_label: Label
var _plan_label: Label
var _direction_buttons: Array[Button] = []
var _new_label: Label
var _new_slider: HSlider
var _create_button: Button
var _list: ItemList
var _detail_label: Label
var _edit_box: VBoxContainer
var _edit_label: Label
var _edit_slider: HSlider
var _apply_button: Button
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
	_new_label = _add_label(box, TEXT_COLOR, "CantidadNueva")
	_new_slider = _add_slider(box, 1, "SliderNuevo")
	_new_slider.value_changed.connect(_on_new_slider_changed)
	_create_button = _make_button("Crear sector y asignar", "BotonCrearSector")
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
	_edit_box = VBoxContainer.new()
	_edit_box.name = "EdicionSector"
	_edit_box.add_theme_constant_override("separation", 3)
	box.add_child(_edit_box)
	_edit_label = _add_label(_edit_box, TEXT_COLOR, "CantidadEdicion")
	_edit_slider = _add_slider(_edit_box, 0, "SliderEdicion")
	_edit_slider.value_changed.connect(_on_edit_slider_changed)
	_apply_button = _make_button("Aplicar", "BotonAplicar")
	_apply_button.pressed.connect(_on_apply_pressed)
	_edit_box.add_child(_apply_button)
	_release_button = _make_button("Liberar y eliminar", "BotonLiberarSector")
	_release_button.tooltip_text = "Libera todos los soldados del sector (vuelven a la reserva) y lo elimina"
	_release_button.pressed.connect(_on_release_pressed)
	_edit_box.add_child(_release_button)
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


func _add_slider(box: Container, min_value: int, node_name: String) -> HSlider:
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = min_value
	slider.max_value = maxi(min_value, 1)
	slider.step = 1
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(INNER_WIDTH, 16)
	box.add_child(slider)
	return slider


func _make_button(text: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	return button


## Conecta el panel con los datos del jugador y lo refresca. Se vuelve a dibujar solo cada vez
## que Military, Population o el territorio cambian. Military debe haberse creado antes que el
## panel: así corrige la asignación antes de que el panel lea los totales.
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


## Cantidad de soldados con la que se creará el sector (el deslizador la recorta a 1..disponibles).
func set_new_amount(amount: int) -> void:
	_new_slider.value = amount


func new_amount() -> int:
	return int(_new_slider.value)


## Cantidad que se aplicaría al sector elegido (el deslizador la recorta a 0..lo asignable).
func set_edit_amount(amount: int) -> void:
	_edit_slider.value = amount


func edit_amount() -> int:
	return int(_edit_slider.value)


## Elige un sector de la lista (Military.NO_SECTOR o un id inexistente o ajeno = ninguno).
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
	if _military == null or _summary_label == null or _refreshing:
		return
	_refreshing = true
	_summary_label.text = summary_text(_military.get_summary(_nation_id))
	_refresh_new_sector()
	if _selected_sector != Military.NO_SECTOR and not _is_own_sector(_selected_sector):
		_selected_sector = Military.NO_SECTOR
		sector_selected.emit(Military.NO_SECTOR)
	_rebuild_list()
	_refresh_edit()
	_refreshing = false


func _is_own_sector(sector_id: int) -> bool:
	return _military != null and _military.has_sector(sector_id) and _military.get_sector(sector_id)["owner"] == _nation_id


func _refresh_new_sector() -> void:
	var available := _military.available_soldiers(_nation_id)
	# El máximo se fija antes de leer el valor: el deslizador recorta solo lo que ya no cabe.
	_new_slider.max_value = maxi(available, 1)
	_new_slider.editable = available > 0
	var plan_error := _plan_error()
	_plan_label.text = plan_text(_origin, _direction, plan_error, _target_cell_owner_text())
	_new_label.text = amount_text(int(_new_slider.value), available) if available > 0 else "Sin soldados disponibles"
	_create_button.disabled = plan_error != Military.SECTOR_OK


## SECTOR_OK si con el origen, la dirección y la cantidad elegidos se podría crear el sector; si
## no, el motivo (los pasos que faltan por elegir cuentan como motivo).
func _plan_error() -> int:
	if _origin == NO_CELL:
		return Military.SECTOR_ERR_ORIGIN_NOT_OWNED
	if _direction == NO_DIRECTION:
		return Military.SECTOR_ERR_BAD_DIRECTION
	return _military.validate_sector(_nation_id, _origin, _direction, int(_new_slider.value))


## A quién pertenece la celda objetivo del plan actual ("" si aún no hay objetivo).
func _target_cell_owner_text() -> String:
	if _origin == NO_CELL or _direction == NO_DIRECTION:
		return ""
	var target := Military.target_cell(_origin, _direction)
	if not _grid.is_valid_coord(target.x, target.y) or not _grid.is_land(target.x, target.y):
		return ""
	return _owner_text(_grid.get_cell_owner(target.x, target.y))


func _owner_text(owner_id: int) -> String:
	if owner_id == _nation_id:
		return "Tu territorio"
	if owner_id == TerritoryGrid.OWNER_NONE:
		return "Sin reclamar"
	return _grid.get_nation(owner_id)["name"]


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


func _refresh_edit() -> void:
	var has_selection := _selected_sector != Military.NO_SECTOR
	_edit_box.visible = has_selection
	if not has_selection:
		_detail_label.text = "Selecciona un sector de la lista."
		_edit_shown_sector = Military.NO_SECTOR
		_edit_shown_assigned = -1
		return
	var sector := _military.get_sector(_selected_sector)
	var assigned: int = sector["soldiers"]
	var limit := assigned + _military.available_soldiers(_nation_id)
	_detail_label.text = detail_text(sector, _owner_text(_military.target_owner(_selected_sector)))
	_edit_slider.max_value = maxi(limit, 1)
	_edit_slider.editable = limit > 0
	if _edit_shown_sector != _selected_sector or _edit_shown_assigned != assigned:
		_edit_slider.set_value_no_signal(assigned)
		_edit_shown_sector = _selected_sector
		_edit_shown_assigned = assigned
	_edit_label.text = edit_amount_text(int(_edit_slider.value), assigned, limit)
	_apply_button.disabled = int(_edit_slider.value) == assigned


# ---------------------------------------------------------------------------
# Controles
# ---------------------------------------------------------------------------

func _on_direction_pressed(direction: int) -> void:
	set_direction(direction)


func _on_new_slider_changed(_value: float) -> void:
	refresh()


func _on_edit_slider_changed(_value: float) -> void:
	refresh()


## Crea el sector con la cantidad elegida en una sola orden: o se crea ya asignado o no cambia nada.
func _on_create_pressed() -> void:
	var amount := int(_new_slider.value)
	var result := _military.create_sector(_nation_id, _origin, _direction, amount)
	if not result["ok"]:
		_message_label.text = Military.sector_error_message(result["error"])
		return
	_message_label.text = "Sector creado con %d soldados." % amount
	select_sector(result["id"])


func _on_list_item_selected(index: int) -> void:
	select_sector(_list.get_item_metadata(index))


## Fija la asignación del sector elegido a la cantidad del deslizador de edición.
func _on_apply_pressed() -> void:
	if _selected_sector == Military.NO_SECTOR:
		return
	var amount := int(_edit_slider.value)
	var code := _military.set_sector_soldiers(_selected_sector, amount)
	_message_label.text = "Sector con %d soldados." % amount if code == Military.ASSIGN_OK else Military.assign_error_message(code)


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


## Texto del plan de sector: origen, objetivo con su dirección y, en la última línea, el motivo si
## no se puede crear o (si se puede) a quién pertenece el objetivo (o «Listo.» si se desconoce).
static func plan_text(origin: Vector2i, direction: int, error: int, target_owner_text: String = "") -> String:
	if origin == NO_CELL:
		return "Selecciona una celda propia en el mapa."
	var text := "Origen (%d, %d)" % [origin.x, origin.y]
	if direction == NO_DIRECTION:
		return text + "\nElige una dirección."
	var target := Military.target_cell(origin, direction)
	text += "\nObjetivo (%d, %d) · %s" % [target.x, target.y, Military.DIRECTION_NAMES[direction]]
	if error != Military.SECTOR_OK:
		return text + "\n" + Military.sector_error_message(error)
	return text + "\n" + (target_owner_text if target_owner_text != "" else "Listo.")


## "Soldados: 3 de 6" (cantidad elegida y máximo asignable).
static func amount_text(amount: int, maximum: int) -> String:
	return "Soldados: %d de %d" % [amount, maximum]


## «Asignar 7 (ahora 5, máx. 11)» al editar un sector.
static func edit_amount_text(amount: int, assigned: int, maximum: int) -> String:
	return "Asignar %d (ahora %d, máx. %d)" % [amount, assigned, maximum]


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
