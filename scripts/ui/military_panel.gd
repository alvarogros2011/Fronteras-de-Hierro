## Panel de ataque del jugador (hitos 8, 9 y 10). Va en la columna izquierda, fuera del mapa, y captura
## el clic para no seleccionar el mapa por error.
##
## FLUJO SIMPLIFICADO (hito 10): el jugador ya no crea y selecciona «sectores». Elige un FRENTE y ataca:
##   1. Pulsa en el mapa una celda propia de la frontera (si solo tiene un lado atacable, la dirección
##      se elige sola) o directamente la celda enemiga o libre que quiere atacar (la celda propia contigua
##      y la dirección se deducen). También puede pulsar un frente ya existente en el mapa o en la lista.
##   2. Elige cuántos soldados con el deslizador o con 25 / 50 / 75 / 100 %.
##   3. Ve la previsión compacta (atacantes, defensa local, etiqueta, bajas, qué pasa si vence).
##   4. Pulsa el único botón principal: «Atacar» (sin ofensiva), «Detener» (activa) o «Continuar»
##      (detenida). Offensives.launch_attack crea o reutiliza internamente el frente y lanza la ofensiva en
##      una sola operación atómica: una orden inválida no consume soldados ni deja un frente a medias.
## Con un frente existente aparecen además «Ajustar a N» (refuerza o reduce sus soldados con el mismo
## deslizador) y «Retirar frente» (los soldados vuelven a la reserva). La palabra «sector» no aparece en
## la interfaz; sigue siendo el nombre interno de la organización de fuerzas (Military).
##
## No guarda datos propios salvo la selección de interfaz (origen, dirección y cantidad del deslizador):
## cada refresh() lee del estado real (Military, Offensives, Population). Los controles solo llaman a las
## órdenes de Offensives y Military; el reglamento (límites, tregua, objetivo no propio…) vive allí. El
## deslizador nunca ofrece más de lo que se puede comprometer (lo que ya tiene el frente más la reserva).
## Los textos salen de funciones estáticas para poder probarlos sin nodos. Es un panel funcional: el
## aspecto se mejorará en la fase visual.
extends PanelContainer

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Military := preload("res://scripts/world/military.gd")
const Population := preload("res://scripts/world/population.gd")
const Offensives := preload("res://scripts/world/offensives.gd")
const Occupation := preload("res://scripts/world/occupation.gd")
const WarState := preload("res://scripts/world/war_state.gd")
const Combat := preload("res://scripts/world/combat.gd")
const EconomyBalance := preload("res://scripts/data/economy_balance.gd")

## Se emite al cambiar el frente elegido (Military.NO_SECTOR = ninguno). La capa del mapa lo resalta.
signal sector_selected(sector_id: int)

const NO_CELL := Vector2i(-1, -1)
const NO_DIRECTION := -1
const FONT_SIZE := 12
const INNER_WIDTH := 124
const TEXT_COLOR := Color(0.85, 0.87, 0.9)
const MUTED_COLOR := Color(0.6, 0.64, 0.7)
const WARN_COLOR := Color(0.95, 0.75, 0.3)
const ATTACK_COLOR := Color(1.0, 0.6, 0.25)
const LIST_HEIGHT := 48
const QUICK_PERCENTS: Array[int] = [25, 50, 75, 100]

var _military: Military
var _population: Population
var _grid: TerritoryGrid
var _nation_id: int = TerritoryGrid.INVALID
var _offensives: Offensives = null
var _wars: WarState = null
var _occupation: Occupation = null

var _origin: Vector2i = NO_CELL
var _direction: int = NO_DIRECTION
var _hint: String = ""
var _selected_sector: int = Military.NO_SECTOR
var _listed_ids: Array = []
## Frente (origen y dirección) para el que se fijó el valor por defecto del deslizador: mientras no
## cambie, el valor que mueve el jugador se respeta aunque el panel se refresque.
var _slider_key: String = ""
var _refreshing: bool = false

var _scroll: ScrollContainer
var _summary_label: Label
var _war_label: Label
var _target_label: Label
var _direction_buttons: Array[Button] = []
var _amount_label: Label
var _amount_slider: HSlider
var _quick_buttons: Array[Button] = []
var _forecast_label: Label
var _attack_button: Button
var _adjust_button: Button
var _withdraw_button: Button
var _state_label: Label
var _list: ItemList
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

	_add_heading(box, "ATACAR")
	_target_label = _add_label(box, TEXT_COLOR, "ObjetivoAtaque")
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
	_amount_label = _add_label(box, TEXT_COLOR, "CantidadAtaque")
	_amount_slider = HSlider.new()
	_amount_slider.name = "SliderAtaque"
	_amount_slider.min_value = 1
	_amount_slider.max_value = 1
	_amount_slider.step = 1
	_amount_slider.focus_mode = Control.FOCUS_NONE
	_amount_slider.custom_minimum_size = Vector2(INNER_WIDTH, 16)
	_amount_slider.value_changed.connect(_on_slider_changed)
	box.add_child(_amount_slider)
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 2)
	box.add_child(quick)
	for percent in QUICK_PERCENTS:
		var quick_button := _make_button("%d%%" % percent, "BotonPorcentaje%d" % percent)
		quick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick_button.tooltip_text = "%d %% de los soldados que se pueden comprometer" % percent
		quick_button.pressed.connect(set_percent.bind(percent))
		quick.add_child(quick_button)
		_quick_buttons.append(quick_button)
	_forecast_label = _add_label(box, TEXT_COLOR, "PrevisionAtaque")
	_attack_button = _make_button("Atacar", "BotonAtacar")
	_attack_button.pressed.connect(_on_attack_pressed)
	box.add_child(_attack_button)
	_state_label = _add_label(box, ATTACK_COLOR, "EstadoOfensiva")
	_adjust_button = _make_button("Ajustar", "BotonAjustar")
	_adjust_button.tooltip_text = "Refuerza o reduce los soldados de este frente sin cambiar su estado"
	_adjust_button.pressed.connect(_on_adjust_pressed)
	box.add_child(_adjust_button)
	_withdraw_button = _make_button("Retirar frente", "BotonRetirar")
	_withdraw_button.tooltip_text = "Detiene el frente y devuelve sus soldados a la reserva; las celdas ocupadas se mantienen"
	_withdraw_button.pressed.connect(_on_withdraw_pressed)
	box.add_child(_withdraw_button)

	_add_heading(box, "FRENTES")
	_list = ItemList.new()
	_list.name = "ListaSectores"
	_list.focus_mode = Control.FOCUS_NONE
	_list.custom_minimum_size = Vector2(INNER_WIDTH, LIST_HEIGHT)
	_list.add_theme_font_size_override("font_size", FONT_SIZE)
	_list.item_selected.connect(_on_list_item_selected)
	box.add_child(_list)
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
	# El panel es estrecho: un texto largo se recorta en vez de ensanchar la columna.
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return button


## Conecta el panel con los datos del jugador y lo refresca. Se vuelve a dibujar solo cada vez que
## Military, Population, Offensives, la guerra, la ocupación o el territorio cambian. Military debe
## haberse creado antes que el panel: así corrige la asignación antes de que el panel lea los totales.
func setup(military: Military, population: Population, grid: TerritoryGrid, nation_id: int,
		offensives: Offensives, wars: WarState = null, occupation: Occupation = null) -> void:
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
	offensives.changed.connect(refresh)
	if wars != null:
		wars.changed.connect(refresh)
	if occupation != null:
		occupation.changed.connect(refresh)
	refresh()


# ---------------------------------------------------------------------------
# Elección del frente
# ---------------------------------------------------------------------------

## Interpreta la celda pulsada en el mapa (la selección del mapa llega aquí):
##   - un frente existente (su origen, su celda objetivo o su frente) lo elige;
##   - una celda propia es el origen (la dirección se elige sola si solo hay un lado atacable);
##   - una celda enemiga o libre junto a territorio propio fija el origen (la celda propia contigua) y la
##     dirección hacia ella;
##   - cualquier otra cosa limpia la elección y explica por qué.
func set_origin(cell: Vector2i) -> void:
	_hint = ""
	if cell == NO_CELL:
		_origin = NO_CELL
		_direction = NO_DIRECTION
	else:
		_resolve_cell(cell)
	refresh()


func _resolve_cell(cell: Vector2i) -> void:
	var sector_id := _offensives.sector_near(_nation_id, cell)
	if sector_id != Military.NO_SECTOR:
		var sector := _military.get_sector(sector_id)
		_origin = sector["origin"]
		_direction = sector["direction"]
		return
	if not _grid.is_land(cell.x, cell.y):
		_clear_choice("El agua no se puede atacar.")
		return
	if _grid.get_cell_owner(cell.x, cell.y) == _nation_id:
		_origin = cell
		_direction = _only_attack_direction(cell)
		if _direction == NO_DIRECTION and not _has_attack_direction(cell):
			_hint = "Esa celda no da a tierra libre ni enemiga."
		return
	for direction in Military.DIRECTION_STEPS.size():
		var origin_candidate: Vector2i = cell - Military.DIRECTION_STEPS[direction]
		if _grid.is_valid_coord(origin_candidate.x, origin_candidate.y) and _grid.get_cell_owner(origin_candidate.x, origin_candidate.y) == _nation_id:
			_origin = origin_candidate
			_direction = direction
			return
	_clear_choice("Elige una celda de tu frontera o una celda enemiga o libre pegada a tu territorio.")


func _clear_choice(hint: String) -> void:
	_origin = NO_CELL
	_direction = NO_DIRECTION
	_hint = hint


## Direcciones desde `cell` hacia las que se puede crear un frente nuevo (objetivo tierra no propia).
func _attack_directions(cell: Vector2i) -> Array:
	var result: Array = []
	for direction in Military.DIRECTION_STEPS.size():
		if _military.validate_sector(_nation_id, cell, direction, 0) == Military.SECTOR_OK:
			result.append(direction)
	return result


func _has_attack_direction(cell: Vector2i) -> bool:
	return not _attack_directions(cell).is_empty()


func _only_attack_direction(cell: Vector2i) -> int:
	var directions := _attack_directions(cell)
	return directions[0] if directions.size() == 1 else NO_DIRECTION


func chosen_origin() -> Vector2i:
	return _origin


## Dirección elegida (Military.DIR_*) o NO_DIRECTION.
func set_direction(direction: int) -> void:
	_direction = direction if direction >= Military.DIR_NORTH and direction <= Military.DIR_WEST else NO_DIRECTION
	_hint = ""
	refresh()


func chosen_direction() -> int:
	return _direction


## Elige un frente existente (Military.NO_SECTOR, un id inexistente o ajeno = ninguno).
func select_sector(sector_id: int) -> void:
	if _is_own_sector(sector_id):
		var sector := _military.get_sector(sector_id)
		_origin = sector["origin"]
		_direction = sector["direction"]
	else:
		_origin = NO_CELL
		_direction = NO_DIRECTION
	_hint = ""
	refresh()


## Frente elegido: el que existe en el origen y la dirección actuales (Military.NO_SECTOR si ninguno).
func selected_sector() -> int:
	return _selected_sector


## Soldados que se enviarían (el deslizador los recorta a 1..máximo comprometible).
func set_amount(amount: int) -> void:
	_amount_slider.value = amount


func amount() -> int:
	return int(_amount_slider.value)


## Fija la cantidad a un porcentaje del máximo comprometible (redondeo hacia arriba, mínimo 1).
@warning_ignore("integer_division")
func set_percent(percent: int) -> void:
	var limit := int(_amount_slider.max_value)
	_amount_slider.value = clampi((limit * percent + 99) / 100, 1, maxi(1, limit))


func _is_own_sector(sector_id: int) -> bool:
	return _military != null and _military.has_sector(sector_id) and _military.get_sector(sector_id)["owner"] == _nation_id


# ---------------------------------------------------------------------------
# Refresco
# ---------------------------------------------------------------------------

## Vuelve a leer el estado real y actualiza todos los textos y controles.
func refresh() -> void:
	if _military == null or _summary_label == null or _refreshing:
		return
	_refreshing = true
	_summary_label.text = summary_text(_military.get_summary(_nation_id))
	_refresh_war()
	_refresh_attack()
	_rebuild_list()
	_refreshing = false


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


## Bloque de ataque: objetivo, cantidad, previsión, estado y botones del frente elegido.
@warning_ignore("integer_division")
func _refresh_attack() -> void:
	var has_front := _origin != NO_CELL and _direction != NO_DIRECTION
	var sector_id := _military.sector_at(_origin, _direction) if has_front else Military.NO_SECTOR
	if sector_id != Military.NO_SECTOR and not _is_own_sector(sector_id):
		sector_id = Military.NO_SECTOR
		has_front = false
	for index in _direction_buttons.size():
		_direction_buttons[index].set_pressed_no_signal(index == _direction)
	_set_selected_sector(sector_id)
	if not has_front:
		_refresh_no_front()
		return
	var sector := _military.get_sector(sector_id) if sector_id != Military.NO_SECTOR else {}
	var assigned: int = sector["soldiers"] if not sector.is_empty() else 0
	var limit := assigned + maxi(0, _military.available_soldiers(_nation_id))
	# El máximo se fija antes de leer el valor: el deslizador recorta solo lo que ya no cabe.
	_amount_slider.max_value = maxi(limit, 1)
	_amount_slider.editable = limit > 0
	var key := "%d,%d,%d" % [_origin.x, _origin.y, _direction]
	if key != _slider_key:
		_slider_key = key
		var initial := assigned if assigned > 0 else clampi((limit + 1) / 2, 1, maxi(1, limit))
		_amount_slider.set_value_no_signal(initial)
	var wanted := int(_amount_slider.value)
	var plan := _offensives.plan_attack(_nation_id, _origin, _direction, wanted)
	var state: int = plan["state"]
	var info: Dictionary = plan["info"]
	var defender_name := ""
	if not info.is_empty() and info["defender"] != TerritoryGrid.OWNER_NONE:
		defender_name = _grid.get_nation(info["defender"])["name"]
	_target_label.text = target_text(_origin, _direction, plan, _owner_text(plan["target"]))
	_amount_label.text = amount_text(wanted, limit) if limit > 0 else "Sin soldados disponibles"
	_forecast_label.text = forecast_text(info, defender_name) if plan["error"] != Offensives.LAUNCH_ERR_SECTOR else ""
	_state_label.visible = sector_id != Military.NO_SECTOR and state != Offensives.STATE_READY
	if _state_label.visible:
		_state_label.text = state_text(state, _offensives.get_offensive(sector_id))
	_attack_button.text = main_button_text(state)
	_attack_button.disabled = false if state == Offensives.STATE_ACTIVE else not plan["ok"]
	for quick_button in _quick_buttons:
		quick_button.disabled = limit <= 0
	_adjust_button.visible = sector_id != Military.NO_SECTOR and wanted != assigned
	_adjust_button.text = "Ajustar a %d" % wanted
	_adjust_button.disabled = wanted < 1 or wanted > limit
	_withdraw_button.visible = sector_id != Military.NO_SECTOR


func _refresh_no_front() -> void:
	_slider_key = ""
	_target_label.text = _hint if _hint != "" else target_text(_origin, _direction, {}, "")
	_amount_label.text = ""
	_amount_slider.editable = false
	_forecast_label.text = ""
	_state_label.visible = false
	_attack_button.text = main_button_text(Offensives.STATE_READY)
	_attack_button.disabled = true
	for quick_button in _quick_buttons:
		quick_button.disabled = true
	_adjust_button.visible = false
	_withdraw_button.visible = false


func _set_selected_sector(sector_id: int) -> void:
	if sector_id == _selected_sector:
		return
	_selected_sector = sector_id
	sector_selected.emit(sector_id)
	if sector_id != Military.NO_SECTOR:
		_scroll_to_state.call_deferred()


## Desplaza la columna hasta el estado del frente (diferido: el diseño se calcula después).
func _scroll_to_state() -> void:
	if _scroll != null and _state_label != null and _state_label.visible and is_inside_tree():
		_scroll.ensure_control_visible(_state_label)


func _owner_text(cell: Vector2i) -> String:
	if cell == NO_CELL or not _grid.is_valid_coord(cell.x, cell.y):
		return ""
	if not _grid.is_land(cell.x, cell.y):
		return "Agua"
	var owner_id := _grid.get_cell_owner(cell.x, cell.y)
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
		_list.set_item_text(index, list_item_text(_military.get_sector(ids[index]), _offensives.is_active(ids[index])))
	if _selected_sector == Military.NO_SECTOR:
		_list.deselect_all()
	else:
		_list.select(ids.find(_selected_sector))


# ---------------------------------------------------------------------------
# Controles
# ---------------------------------------------------------------------------

func _on_direction_pressed(direction: int) -> void:
	set_direction(direction)


func _on_slider_changed(_value: float) -> void:
	refresh()


func _on_list_item_selected(index: int) -> void:
	select_sector(_list.get_item_metadata(index))


## Botón principal: «Atacar» y «Continuar» lanzan el ataque con la cantidad elegida; «Detener» lo detiene.
func _on_attack_pressed() -> void:
	if _origin == NO_CELL or _direction == NO_DIRECTION:
		return
	var sector_id := _military.sector_at(_origin, _direction)
	if sector_id != Military.NO_SECTOR and _offensives.is_active(sector_id):
		if _offensives.stop_offensive(sector_id):
			_message_label.text = "Ataque detenido. Las celdas ocupadas se mantienen."
		return
	var result := _offensives.launch_attack(_nation_id, _origin, _direction, int(_amount_slider.value))
	if result["ok"]:
		_message_label.text = "Ataque en marcha con %d soldados." % int(_amount_slider.value)
	else:
		_message_label.text = Offensives.launch_error_message(result)


## Refuerza o reduce los soldados del frente sin cambiar su estado (activo o detenido).
func _on_adjust_pressed() -> void:
	var sector_id := _military.sector_at(_origin, _direction)
	if sector_id == Military.NO_SECTOR:
		return
	var wanted := int(_amount_slider.value)
	var code := _military.set_sector_soldiers(sector_id, wanted)
	_message_label.text = "Frente con %d soldados." % wanted if code == Military.ASSIGN_OK else Military.assign_error_message(code)


## Retira el frente: sus soldados vuelven a la reserva (no son bajas) y la ofensiva desaparece.
func _on_withdraw_pressed() -> void:
	var sector_id := _military.sector_at(_origin, _direction)
	if sector_id == Military.NO_SECTOR:
		return
	var released: int = _military.get_sector(sector_id)["soldiers"]
	_military.remove_sector(sector_id)
	_message_label.text = "Frente retirado. %d soldados vuelven a la reserva." % released


# ---------------------------------------------------------------------------
# Textos (funciones puras, probadas sin interfaz)
# ---------------------------------------------------------------------------

## "Soldados 6\nAsignados 2\nDisponibles 4" a partir de Military.get_summary.
static func summary_text(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Sin ejército"
	return "Soldados %d\nAsignados %d\nDisponibles %d" % [summary["total"], summary["assigned"], summary["available"]]


## Texto del botón principal según el estado del frente: Atacar / Detener / Continuar.
static func main_button_text(state: int) -> String:
	match state:
		Offensives.STATE_ACTIVE:
			return "Detener"
		Offensives.STATE_STOPPED:
			return "Continuar"
	return "Atacar"


## Objetivo del ataque: «Desde (24, 15) hacia el Este → (25, 15)», a quién pertenece y, si no se puede,
## el motivo. `plan` es el de Offensives.plan_attack ({} mientras falte elegir origen o dirección).
## `target_owner_text` es el dueño de la celda objetivo.
static func target_text(origin: Vector2i, direction: int, plan: Dictionary, target_owner_text: String) -> String:
	if origin == NO_CELL:
		return "Pulsa en el mapa tu frontera o la celda que quieres atacar."
	var text := "Desde (%d, %d)" % [origin.x, origin.y]
	if direction == NO_DIRECTION or plan.is_empty():
		return text + "\nElige una dirección."
	var target: Vector2i = Military.target_cell(origin, direction)
	if plan["error"] != Offensives.LAUNCH_ERR_SECTOR:
		target = plan["target"]
	text += " hacia el %s → (%d, %d)" % [Military.DIRECTION_NAMES[direction], target.x, target.y]
	if plan["error"] == Offensives.LAUNCH_ERR_SECTOR:
		return text + "\n" + Offensives.launch_error_message(plan)
	if target_owner_text != "":
		text += "\n" + target_owner_text
	if plan["error"] == Offensives.LAUNCH_ERR_NO_SOLDIERS or plan["error"] == Offensives.LAUNCH_ERR_NOT_ENOUGH:
		text += "\n" + Offensives.launch_error_message(plan)
	return text


## "Soldados: 3 de 6" (cantidad elegida y máximo comprometible).
static func amount_text(amount: int, maximum: int) -> String:
	return "Soldados: %d de %d" % [amount, maximum]


## Línea de la lista de frentes: "#3 (12,12) E · 5" (con « · ATQ» al final si está atacando).
static func list_item_text(sector: Dictionary, attacking: bool = false) -> String:
	var origin: Vector2i = sector["origin"]
	var text := "#%d (%d,%d) %s · %d" % [sector["id"], origin.x, origin.y, Military.DIRECTION_SHORT_NAMES[sector["direction"]], sector["soldiers"]]
	return text + " · ATQ" if attacking else text


## Estado de la ofensiva: «ATACANDO · próximo avance en 2 s» o «Detenido: motivo», seguido del frente, los
## soldados que le quedan, las celdas conseguidas, las bajas y el último enfrentamiento.
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
	var text := "%s\nFrente (%d, %d) → (%d, %d)\nSoldados %d\nCeldas: %d ocupadas · %d reclamadas\nBajas: propias %d · enemigas %d" % [head, front.x, front.y,
			next_cell.x, next_cell.y, offensive["soldiers"], offensive["occupied"], offensive["claimed"], offensive["attacker_losses"], offensive["defender_losses"]]
	var clash: Dictionary = offensive["last_clash"]
	if not clash.is_empty():
		var cell: Vector2i = clash["cell"]
		text += "\nÚltimo: %s en (%d, %d) · bajas %d / %d" % ["victoria" if clash["won"] else "derrota", cell.x, cell.y, clash["attacker_losses"], clash["defender_losses"]]
	return text


## Etiqueta de la previsión (ventaja atacante / combate equilibrado / defensa superior).
static func category_text(category: int) -> String:
	match category:
		Combat.CATEGORY_ADVANTAGE:
			return "Ventaja atacante"
		Combat.CATEGORY_BALANCED:
			return "Combate equilibrado"
	return "Defensa superior"


## «2,2 a 1» (relación atacantes / defensa efectiva con un decimal) o «sin defensa».
@warning_ignore("integer_division")
static func ratio_text(ratio_permille: int) -> String:
	if ratio_permille >= Combat.NO_RESISTANCE_RATIO:
		return "sin defensa"
	var tenths: int = ratio_permille / 100
	return "%d,%d a 1" % [tenths / 10, tenths % 10]


## Previsión compacta del siguiente avance a partir de Offensives.evaluate / plan_attack["info"]: atacantes,
## defensa local estimada, etiqueta, resultado previsto (y qué pasa con la celda), bajas aproximadas. Es
## el cálculo con la regla determinista del prototipo, no una probabilidad estadística, y lo dice.
## `defender_name`: nación defensora (solo en territorio de otra nación).
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
	var gain := "ocupas la celda; sigue siendo de %s" % defender_name if enemy else "reclamas la celda"
	if info["defense"] <= 0:
		lines.append("Sin resistencia: %s, sin bajas." % gain)
		return "\n".join(PackedStringArray(lines))
	if enemy:
		lines.append("Defensa local ~%d (%d soldados en %d tramos de frontera)" % [info["defense"], info["defender_soldiers"], info["fronts"]])
	else:
		lines.append("Defensa local ~%d" % info["defense"])
	lines.append("%s (%s)" % [category_text(info["category"]), ratio_text(info["ratio_permille"])])
	if info["attacker_wins"]:
		lines.append("Victoria prevista: %s" % gain)
	else:
		lines.append("Derrota prevista: el ataque se detiene")
	lines.append("Bajas aprox.: propias %d · enemigas %d" % [info["attacker_losses"], info["defender_losses"]])
	lines.append("Cálculo determinista, no una probabilidad.")
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
