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
##
## Ataques (hito 9): al elegir un sector aparece el bloque «ATAQUE» con su estado (preparado, atacando
## o detenido y por qué), la PREVISIÓN del siguiente avance (atacantes, defensa local estimada,
## relación de fuerzas, resultado previsto y bajas aproximadas; regla determinista, no una
## probabilidad), el botón «Confirmar ataque» (o «Reanudar ataque») y «Detener ataque», y las cifras del
## frente y las bajas. Arriba, y solo si hay conflicto, una línea discreta con las guerras y las
## ocupaciones. El contenido va en una columna con barra de desplazamiento (el panel ocupa la columna
## izquierda): ya no cabe todo a la vez. Las órdenes llegan a Offensives; nada se decide aquí.
extends PanelContainer

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Military := preload("res://scripts/world/military.gd")
const Population := preload("res://scripts/world/population.gd")
const Offensives := preload("res://scripts/world/offensives.gd")
const Occupation := preload("res://scripts/world/occupation.gd")
const WarState := preload("res://scripts/world/war_state.gd")
const Combat := preload("res://scripts/world/combat.gd")
const EconomyBalance := preload("res://scripts/data/economy_balance.gd")

## Se emite al cambiar el sector elegido en la lista (Military.NO_SECTOR = ninguno).
signal sector_selected(sector_id: int)

const NO_CELL := Vector2i(-1, -1)
const NO_DIRECTION := -1
const FONT_SIZE := 12
const INNER_WIDTH := 124
const TEXT_COLOR := Color(0.85, 0.87, 0.9)
const MUTED_COLOR := Color(0.6, 0.64, 0.7)
const WARN_COLOR := Color(0.95, 0.75, 0.3)
const ATTACK_COLOR := Color(1.0, 0.6, 0.25)
const LIST_HEIGHT := 56

var _military: Military
var _population: Population
var _grid: TerritoryGrid
var _nation_id: int = TerritoryGrid.INVALID
var _offensives: Offensives = null
var _wars: WarState = null
var _occupation: Occupation = null

var _origin: Vector2i = NO_CELL
var _direction: int = NO_DIRECTION
var _selected_sector: int = Military.NO_SECTOR
var _listed_ids: Array = []
## Última asignación del sector elegido que se volcó en el deslizador de edición (-1 = ninguna):
## mientras no cambie, el valor que mueve el jugador se respeta aunque el panel se refresque.
var _edit_shown_sector: int = Military.NO_SECTOR
var _edit_shown_assigned: int = -1
var _refreshing: bool = false

var _scroll: ScrollContainer
var _summary_label: Label
var _war_label: Label
var _combat_box: VBoxContainer
var _state_label: Label
var _forecast_label: Label
var _attack_button: Button
var _stop_button: Button
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
	_scroll = ScrollContainer.new()
	_scroll.name = "DesplazamientoMilitar"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(box)
	_add_heading(box, "EJÉRCITO")
	_summary_label = _add_label(box, TEXT_COLOR, "ResumenMilitar")
	_war_label = _add_label(box, WARN_COLOR, "GuerraMilitar")
	_war_label.visible = false

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
	_combat_box = VBoxContainer.new()
	_combat_box.name = "CombateSector"
	_combat_box.add_theme_constant_override("separation", 3)
	_combat_box.visible = false
	box.add_child(_combat_box)
	_add_heading(_combat_box, "ATAQUE")
	_state_label = _add_label(_combat_box, ATTACK_COLOR, "EstadoOfensiva")
	_forecast_label = _add_label(_combat_box, TEXT_COLOR, "PrevisionAtaque")
	_attack_button = _make_button("Confirmar ataque", "BotonAtacar")
	_attack_button.tooltip_text = "Inicia la ofensiva del sector con los soldados que tiene asignados"
	_attack_button.pressed.connect(_on_attack_pressed)
	_combat_box.add_child(_attack_button)
	_stop_button = _make_button("Detener ataque", "BotonDetener")
	_stop_button.tooltip_text = "Detiene la ofensiva; las celdas ya ocupadas se mantienen"
	_stop_button.pressed.connect(_on_stop_pressed)
	_combat_box.add_child(_stop_button)
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
	# El panel es estrecho: un texto largo se recorta en vez de ensanchar la columna.
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return button


## Conecta el panel con los datos del jugador y lo refresca. Se vuelve a dibujar solo cada vez
## que Military, Population o el territorio cambian. Military debe haberse creado antes que el
## panel: así corrige la asignación antes de que el panel lea los totales.
func setup(military: Military, population: Population, grid: TerritoryGrid, nation_id: int,
		offensives: Offensives = null, wars: WarState = null, occupation: Occupation = null) -> void:
	_military = military
	_population = population
	_grid = grid
	_nation_id = nation_id
	_offensives = offensives
	_wars = wars
	_occupation = occupation
	military.changed.connect(refresh)
	population.changed.connect(refresh)
	grid.ownership_changed.connect(refresh)
	if offensives != null:
		offensives.changed.connect(refresh)
	if wars != null:
		wars.changed.connect(refresh)
	if occupation != null:
		occupation.changed.connect(refresh)
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
		if new_id != Military.NO_SECTOR:
			_scroll_to_combat.call_deferred()


func selected_sector() -> int:
	return _selected_sector


## Vuelve a leer el estado real y actualiza todos los textos y controles.
func refresh() -> void:
	if _military == null or _summary_label == null or _refreshing:
		return
	_refreshing = true
	_summary_label.text = summary_text(_military.get_summary(_nation_id))
	_refresh_war()
	_refresh_new_sector()
	if _selected_sector != Military.NO_SECTOR and not _is_own_sector(_selected_sector):
		_selected_sector = Military.NO_SECTOR
		sector_selected.emit(Military.NO_SECTOR)
	_rebuild_list()
	_refresh_edit()
	_refresh_combat()
	_refreshing = false


## Desplaza la columna hasta el bloque de ataque (se llama diferido: el diseño se calcula después).
func _scroll_to_combat() -> void:
	if _scroll != null and _combat_box != null and _combat_box.visible and is_inside_tree():
		_scroll.ensure_control_visible(_combat_box)


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
		var attacking := _offensives != null and _offensives.is_active(ids[index])
		_list.set_item_text(index, list_item_text(_military.get_sector(ids[index]), attacking))
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


## Línea de conflicto (guerras activas y ocupaciones); oculta si no hay nada que mostrar.
func _refresh_war() -> void:
	var enemy_names: Array = []
	if _wars != null:
		for enemy_id: int in _wars.enemies_of(_nation_id):
			enemy_names.append(_grid.get_nation(enemy_id)["name"])
	var occupied := _occupation.count(_nation_id) if _occupation != null else 0
	var taken := _occupation.count_taken_from(_nation_id) if _occupation != null else 0
	_war_label.text = war_text(enemy_names, occupied, taken)
	_war_label.visible = _war_label.text != ""


## Bloque de ataque del sector elegido: estado, previsión y botones.
func _refresh_combat() -> void:
	var has_selection := _selected_sector != Military.NO_SECTOR and _offensives != null
	_combat_box.visible = has_selection
	if not has_selection:
		return
	var state := _offensives.sector_state(_selected_sector)
	var forecast := _offensives.forecast(_selected_sector)
	var defender_name := ""
	if forecast["defender"] != TerritoryGrid.OWNER_NONE:
		defender_name = _grid.get_nation(forecast["defender"])["name"]
	_state_label.text = state_text(state, _offensives.get_offensive(_selected_sector))
	_forecast_label.text = forecast_text(forecast, defender_name)
	_attack_button.text = "Reanudar ataque" if state == Offensives.STATE_STOPPED else "Confirmar ataque"
	_attack_button.disabled = state == Offensives.STATE_ACTIVE or forecast["blocked"] or _military.get_sector(_selected_sector)["soldiers"] <= 0
	_stop_button.disabled = state != Offensives.STATE_ACTIVE


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


## Confirma el ataque del sector elegido con los soldados que tiene asignados.
func _on_attack_pressed() -> void:
	if _selected_sector == Military.NO_SECTOR or _offensives == null:
		return
	var result := _offensives.start_offensive(_selected_sector)
	_message_label.text = Offensives.start_error_message(result["error"], result["reason"])


func _on_stop_pressed() -> void:
	if _selected_sector == Military.NO_SECTOR or _offensives == null:
		return
	if _offensives.stop_offensive(_selected_sector):
		_message_label.text = "Ataque detenido. Las celdas ocupadas se mantienen."


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


## Línea de la lista: "#3 (12,12) E · 5" (con « · ATQ» al final si el sector está atacando).
static func list_item_text(sector: Dictionary, attacking: bool = false) -> String:
	var origin: Vector2i = sector["origin"]
	var text := "#%d (%d,%d) %s · %d" % [sector["id"], origin.x, origin.y, Military.DIRECTION_SHORT_NAMES[sector["direction"]], sector["soldiers"]]
	return text + " · ATQ" if attacking else text


## Detalle del sector elegido: origen, objetivo, dirección, a quién pertenece el objetivo y soldados.
static func detail_text(sector: Dictionary, target_owner_text: String) -> String:
	var origin: Vector2i = sector["origin"]
	var target: Vector2i = sector["target"]
	return "Sector #%d · %s\nOrigen (%d, %d)\nObjetivo (%d, %d)\n%s\nSoldados %d" % [sector["id"], Military.DIRECTION_NAMES[sector["direction"]],
			origin.x, origin.y, target.x, target.y, target_owner_text, sector["soldiers"]]


## Estado de la ofensiva del sector: «Preparado», «ATACANDO · próximo avance en 2 s» o «Detenido: motivo»,
## seguido (si ya hubo ofensiva) del frente, las celdas conseguidas, las bajas y el último enfrentamiento.
static func state_text(state: int, offensive: Dictionary) -> String:
	if state == Offensives.STATE_READY or offensive.is_empty():
		return "Preparado (sin atacar)"
	var head := ""
	if state == Offensives.STATE_ACTIVE:
		head = "ATACANDO · próximo avance en %d s" % int(offensive["countdown"] * EconomyBalance.TICK_SECONDS)
	else:
		head = "Detenido: " + Offensives.stop_reason_message(offensive["reason"])
	var front: Vector2i = offensive["front"]
	var next_cell: Vector2i = offensive["next_cell"]
	var text := "%s\nFrente (%d, %d) → (%d, %d)\nCeldas: %d ocupadas · %d reclamadas\nBajas: propias %d · enemigas %d" % [head, front.x, front.y,
			next_cell.x, next_cell.y, offensive["occupied"], offensive["claimed"], offensive["attacker_losses"], offensive["defender_losses"]]
	var clash: Dictionary = offensive["last_clash"]
	if not clash.is_empty():
		var cell: Vector2i = clash["cell"]
		text += "\nÚltimo: %s en (%d, %d)" % ["victoria" if clash["won"] else "derrota", cell.x, cell.y]
	return text


## Nombre de la etiqueta de la previsión (ventaja atacante / equilibrado / defensa superior).
static func category_text(category: int) -> String:
	match category:
		Combat.CATEGORY_ADVANTAGE:
			return "Ventaja atacante"
		Combat.CATEGORY_BALANCED:
			return "Enfrentamiento equilibrado"
	return "Defensa superior"


## «2,2 a 1» (relación atacantes / defensa efectiva con un decimal) o «sin defensa».
@warning_ignore("integer_division")
static func ratio_text(ratio_permille: int) -> String:
	if ratio_permille >= Combat.NO_RESISTANCE_RATIO:
		return "sin defensa"
	var tenths: int = ratio_permille / 100
	return "%d,%d a 1" % [tenths / 10, tenths % 10]


## Previsión del siguiente avance a partir de Offensives.forecast. Es un cálculo con la regla
## determinista del prototipo, no una probabilidad estadística, y lo dice. `defender_name`: nombre de la
## nación defensora (solo se usa en territorio de otra nación).
static func forecast_text(info: Dictionary, defender_name: String) -> String:
	if info.is_empty():
		return ""
	var target: Vector2i = info["target"]
	var head := "Siguiente celda (%d, %d)" % [target.x, target.y]
	if info["blocked"]:
		return head + "\nNo se puede avanzar: " + Offensives.stop_reason_message(info["reason"]) + "."
	if info["kind"] == Offensives.KIND_OWN:
		return head + " · propia\nAvance sin combate."
	if info["kind"] == Offensives.KIND_OCCUPIED:
		return head + " · ya ocupada\nAvance sin combate."
	var enemy: bool = info["kind"] == Offensives.KIND_ENEMY
	var lines: Array[String] = [head + (" · " + defender_name if enemy else " · sin reclamar"), "Atacantes %d" % info["attackers"]]
	var gain := "se ocupa la celda" if enemy else "se reclama la celda"
	if info["defense"] <= 0:
		lines.append("Sin resistencia: %s sin bajas." % gain)
		return "\n".join(PackedStringArray(lines))
	lines.append("Defensa local estimada ~%d" % info["defense"])
	if enemy:
		lines.append("(de %d soldados en %d tramos de frontera)" % [info["defender_soldiers"], info["fronts"]])
	lines.append("Relación %s · %s" % [ratio_text(info["ratio_permille"]), category_text(info["category"])])
	if info["attacker_wins"]:
		lines.append("Previsto: victoria, %s" % gain)
	else:
		lines.append("Previsto: derrota, el ataque se detiene")
	lines.append("Bajas aprox.: propias %d · enemigas %d" % [info["attacker_losses"], info["defender_losses"]])
	lines.append("Regla determinista del prototipo, no una probabilidad.")
	return "\n".join(PackedStringArray(lines))


## Línea de conflicto: «Guerra con: A, B», «Ocupadas por ti: N» y «Tu territorio ocupado: M». Vacía si
## no hay guerras ni ocupaciones.
static func war_text(enemy_names: Array, occupied: int, taken: int) -> String:
	var lines: Array[String] = []
	if not enemy_names.is_empty():
		lines.append("Guerra con: " + ", ".join(PackedStringArray(enemy_names)))
	if occupied > 0:
		lines.append("Celdas ocupadas por ti: %d" % occupied)
	if taken > 0:
		lines.append("Tu territorio ocupado: %d" % taken)
	return "\n".join(PackedStringArray(lines))
