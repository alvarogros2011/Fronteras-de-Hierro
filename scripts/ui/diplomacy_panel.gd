## Panel de diplomacia del jugador (hito 10). Va en la columna izquierda, bajo el panel de ataque, y solo
## se muestra cuando hay algo que decidir o consultar: una guerra, una propuesta pendiente o una tregua.
## Captura el clic para no seleccionar el mapa por error.
##
## Con una guerra abierta muestra su estado (duración, celdas ocupadas por cada bando, bajas) y un
## formulario mínimo: tipo de paz (con conquistas / blanca), quién paga y cuánto, y un botón «Proponer
## paz». La respuesta de la IA (acepta, rechaza o contraoferta) aparece en el mensaje; una contraoferta o
## una propuesta de la IA se contesta con «Aceptar» o «Rechazar». Las treguas muestran el tiempo que
## falta. En pausa no se negocia (el tratado cambiaría saldos y territorio al instante) y el panel lo
## dice. No guarda datos propios salvo la selección de interfaz (enemigo, tipo, pagador y cantidad):
## cada refresh() lee del estado real (Diplomacy, WarState, Occupation, Economy). La lógica vive en
## Diplomacy; aquí solo se llaman sus órdenes.
extends PanelContainer

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Diplomacy := preload("res://scripts/world/diplomacy.gd")
const WarState := preload("res://scripts/world/war_state.gd")
const Occupation := preload("res://scripts/world/occupation.gd")
const Economy := preload("res://scripts/world/economy.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const EconomyBalance := preload("res://scripts/data/economy_balance.gd")

const FONT_SIZE := 12
const INNER_WIDTH := 124
const TEXT_COLOR := Color(0.85, 0.87, 0.9)
const MUTED_COLOR := Color(0.6, 0.64, 0.7)
const WARN_COLOR := Color(0.95, 0.75, 0.3)
const OK_COLOR := Color(0.55, 0.85, 0.55)

## Quién paga en la propuesta.
const PAYER_NONE := 0
const PAYER_ME := 1
const PAYER_THEM := 2
const PAYER_NAMES: Array[String] = ["Sin pago", "Pago yo", "Pagan ellos"]

var _diplomacy: Diplomacy
var _wars: WarState
var _grid: TerritoryGrid
var _economy: Economy
var _occupation: Occupation
var _cities: CityManager
var _nation_id: int = TerritoryGrid.INVALID

var _enemy_id: int = TerritoryGrid.INVALID
var _refreshing: bool = false

var _scroll: ScrollContainer
var _status_label: Label
var _enemy_picker: OptionButton
var _incoming_label: Label
var _accept_button: Button
var _reject_button: Button
var _form: VBoxContainer
var _kind_picker: OptionButton
var _payer_picker: OptionButton
var _payment_label: Label
var _payment_slider: HSlider
var _summary_label: Label
var _propose_button: Button
var _pause_label: Label
var _message_label: Label


func _ready() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "DesplazamientoDiplomacia"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(box)
	_add_heading(box, "DIPLOMACIA")
	_status_label = _add_label(box, WARN_COLOR, "EstadoDiplomacia")
	_enemy_picker = OptionButton.new()
	_enemy_picker.name = "SelectorEnemigo"
	_enemy_picker.focus_mode = Control.FOCUS_NONE
	_enemy_picker.add_theme_font_size_override("font_size", FONT_SIZE)
	_enemy_picker.item_selected.connect(_on_enemy_selected)
	box.add_child(_enemy_picker)
	_incoming_label = _add_label(box, OK_COLOR, "PropuestaEntrante")
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 2)
	box.add_child(answers)
	_accept_button = _make_button("Aceptar", "BotonAceptarPropuesta")
	_accept_button.pressed.connect(_on_accept_pressed)
	answers.add_child(_accept_button)
	_reject_button = _make_button("Rechazar", "BotonRechazarPropuesta")
	_reject_button.pressed.connect(_on_reject_pressed)
	answers.add_child(_reject_button)

	_form = VBoxContainer.new()
	_form.name = "FormularioPaz"
	_form.add_theme_constant_override("separation", 3)
	box.add_child(_form)
	_kind_picker = OptionButton.new()
	_kind_picker.name = "TipoPaz"
	_kind_picker.focus_mode = Control.FOCUS_NONE
	_kind_picker.add_theme_font_size_override("font_size", FONT_SIZE)
	for kind_name in Diplomacy.KIND_NAMES:
		_kind_picker.add_item(kind_name)
	_kind_picker.item_selected.connect(_on_form_changed)
	_form.add_child(_kind_picker)
	_payer_picker = OptionButton.new()
	_payer_picker.name = "PagoQuien"
	_payer_picker.focus_mode = Control.FOCUS_NONE
	_payer_picker.add_theme_font_size_override("font_size", FONT_SIZE)
	for payer_name in PAYER_NAMES:
		_payer_picker.add_item(payer_name)
	_payer_picker.item_selected.connect(_on_form_changed)
	_form.add_child(_payer_picker)
	_payment_label = _add_label(_form, TEXT_COLOR, "CantidadPago")
	_payment_slider = HSlider.new()
	_payment_slider.name = "SliderPago"
	_payment_slider.min_value = 0
	_payment_slider.max_value = 1
	_payment_slider.step = 1
	_payment_slider.focus_mode = Control.FOCUS_NONE
	_payment_slider.custom_minimum_size = Vector2(INNER_WIDTH, 16)
	_payment_slider.value_changed.connect(_on_form_changed)
	_form.add_child(_payment_slider)
	_summary_label = _add_label(_form, MUTED_COLOR, "ResumenTratado")
	_propose_button = _make_button("Proponer paz", "BotonProponer")
	_propose_button.pressed.connect(_on_propose_pressed)
	_form.add_child(_propose_button)
	_pause_label = _add_label(box, WARN_COLOR, "AvisoPausaDiplomacia")
	_pause_label.text = "En pausa: reanuda para negociar."
	_message_label = _add_label(box, MUTED_COLOR, "MensajeDiplomacia")


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
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


## Conecta el panel con los datos del jugador. Se vuelve a dibujar con cada tick (las cuentas atrás de
## guerra y tregua) y cada vez que cambian la diplomacia, las guerras, la ocupación, la economía o la pausa.
func setup(diplomacy: Diplomacy, wars: WarState, grid: TerritoryGrid, economy: Economy, occupation: Occupation,
		cities: CityManager, nation_id: int) -> void:
	_diplomacy = diplomacy
	_wars = wars
	_grid = grid
	_economy = economy
	_occupation = occupation
	_cities = cities
	_nation_id = nation_id
	diplomacy.changed.connect(refresh)
	wars.changed.connect(refresh)
	occupation.changed.connect(refresh)
	economy.balances_changed.connect(refresh)
	cities.pause_changed.connect(_on_pause_changed)
	cities.ticked.connect(refresh)
	refresh()


# ---------------------------------------------------------------------------
# Estado de la interfaz
# ---------------------------------------------------------------------------

## Nación enemiga elegida (TerritoryGrid.INVALID si no hay guerra).
func chosen_enemy() -> int:
	return _enemy_id


func set_kind(kind: int) -> void:
	_kind_picker.select(clampi(kind, 0, Diplomacy.KIND_NAMES.size() - 1))
	refresh()


func chosen_kind() -> int:
	return _kind_picker.selected


func set_payer_mode(mode: int) -> void:
	_payer_picker.select(clampi(mode, PAYER_NONE, PAYER_THEM))
	refresh()


func chosen_payer_mode() -> int:
	return _payer_picker.selected


func set_payment(amount: int) -> void:
	_payment_slider.value = amount
	refresh()


func payment() -> int:
	return int(_payment_slider.value)


## Vuelve a leer el estado real y actualiza todos los textos y controles.
func refresh() -> void:
	if _diplomacy == null or _status_label == null or _refreshing:
		return
	_refreshing = true
	var enemies := _wars.enemies_of(_nation_id)
	var truces := _wars.truces_of(_nation_id)
	var incoming := _diplomacy.pending_for(_nation_id)
	if not enemies.has(_enemy_id):
		_enemy_id = enemies[0] if not enemies.is_empty() else TerritoryGrid.INVALID
	visible = not enemies.is_empty() or not truces.is_empty() or not incoming.is_empty()
	_refresh_enemies(enemies)
	_status_label.text = status_text(_status_lines(enemies, truces))
	_refresh_incoming(incoming)
	_refresh_form(incoming)
	_pause_label.visible = _cities.is_paused() and (not enemies.is_empty() or not incoming.is_empty())
	_refreshing = false


func _refresh_enemies(enemies: Array) -> void:
	_enemy_picker.visible = enemies.size() > 1
	if _enemy_picker.item_count != enemies.size():
		_enemy_picker.clear()
		for enemy_id: int in enemies:
			_enemy_picker.add_item(_grid.get_nation(enemy_id)["name"])
	if _enemy_id != TerritoryGrid.INVALID:
		_enemy_picker.select(enemies.find(_enemy_id))


func _status_lines(enemies: Array, truces: Array) -> Array:
	var lines: Array = []
	if _enemy_id != TerritoryGrid.INVALID:
		var war := _wars.get_war(_nation_id, _enemy_id)
		lines.append(war_text(_grid.get_nation(_enemy_id)["name"], int(war["duration"] * EconomyBalance.TICK_SECONDS),
				_occupation.count_between(_nation_id, _enemy_id), _occupation.count_between(_enemy_id, _nation_id),
				war["casualties"].get(_nation_id, 0), war["casualties"].get(_enemy_id, 0)))
	if enemies.size() > 1:
		lines.append("(%d guerras abiertas)" % enemies.size())
	for truce: Dictionary in truces:
		lines.append(truce_text(_grid.get_nation(truce["other"])["name"], int(truce["remaining"] * EconomyBalance.TICK_SECONDS)))
	return lines


func _refresh_incoming(incoming: Array) -> void:
	var has_incoming := not incoming.is_empty()
	_incoming_label.visible = has_incoming
	_accept_button.visible = has_incoming
	_reject_button.visible = has_incoming
	if not has_incoming:
		return
	var proposal: Dictionary = incoming[0]
	_incoming_label.text = _diplomacy.proposal_text(proposal)
	_accept_button.disabled = _cities.is_paused()
	_reject_button.disabled = false


func _refresh_form(incoming: Array) -> void:
	var at_war := _enemy_id != TerritoryGrid.INVALID
	_form.visible = at_war and incoming.is_empty()
	if not _form.visible:
		return
	var payer_mode := _payer_picker.selected
	var payer := _payer_id(payer_mode)
	var balance := _economy.get_money(payer) if payer != Diplomacy.NO_PAYER else 0
	_payment_slider.max_value = maxi(balance, 1)
	_payment_slider.editable = payer != Diplomacy.NO_PAYER and balance > 0
	if payer == Diplomacy.NO_PAYER:
		_payment_slider.set_value_no_signal(0)
	var amount := int(_payment_slider.value)
	_payment_label.text = payment_text(payer_mode, amount, balance)
	_summary_label.text = treaty_summary_text(_kind_picker.selected, _occupation.count_between(_nation_id, _enemy_id),
			_occupation.count_between(_enemy_id, _nation_id))
	_propose_button.disabled = _cities.is_paused() or (payer != Diplomacy.NO_PAYER and amount > balance)


## Id de la nación que paga según el modo elegido.
func _payer_id(mode: int) -> int:
	match mode:
		PAYER_ME:
			return _nation_id
		PAYER_THEM:
			return _enemy_id
	return Diplomacy.NO_PAYER


# ---------------------------------------------------------------------------
# Controles
# ---------------------------------------------------------------------------

func _on_enemy_selected(index: int) -> void:
	var enemies := _wars.enemies_of(_nation_id)
	if index >= 0 and index < enemies.size():
		_enemy_id = enemies[index]
	refresh()


func _on_form_changed(_value: Variant = null) -> void:
	refresh()


func _on_pause_changed(_paused: bool) -> void:
	refresh()


func _on_propose_pressed() -> void:
	if _enemy_id == TerritoryGrid.INVALID:
		return
	var payer := _payer_id(_payer_picker.selected)
	var amount := int(_payment_slider.value) if payer != Diplomacy.NO_PAYER else 0
	var result := _diplomacy.propose(_nation_id, _enemy_id, _kind_picker.selected, payer, amount)
	_message_label.text = result["message"]


func _on_accept_pressed() -> void:
	var incoming := _diplomacy.pending_for(_nation_id)
	if incoming.is_empty():
		return
	var result := _diplomacy.accept(incoming[0]["id"], _nation_id)
	_message_label.text = result["message"]


func _on_reject_pressed() -> void:
	var incoming := _diplomacy.pending_for(_nation_id)
	if incoming.is_empty():
		return
	var result := _diplomacy.reject(incoming[0]["id"], _nation_id)
	_message_label.text = result["message"]


# ---------------------------------------------------------------------------
# Textos (funciones puras, probadas sin interfaz)
# ---------------------------------------------------------------------------

## Unión de las líneas de estado; «Sin conflictos.» si no hay ninguna.
static func status_text(lines: Array) -> String:
	if lines.is_empty():
		return "Sin conflictos."
	return "\n".join(PackedStringArray(lines))


## «En guerra con X (35 s)\nOcupas 3 · Te ocupan 1\nBajas: tuyas 4 · suyas 7».
static func war_text(enemy_name: String, seconds: int, held_by_me: int, held_by_them: int, my_casualties: int, their_casualties: int) -> String:
	return "En guerra con %s (%d s)\nOcupas %d · Te ocupan %d\nBajas: tuyas %d · suyas %d" % [enemy_name, seconds, held_by_me, held_by_them, my_casualties, their_casualties]


## «Tregua con X: 42 s».
static func truce_text(other_name: String, seconds: int) -> String:
	return "Tregua con %s: %d s" % [other_name, seconds]


## Pago elegido: «Sin pago», «Pagas 12 (tienes 40)» o «Pagan ellos: 12 (tienen 30)».
static func payment_text(payer_mode: int, amount: int, balance: int) -> String:
	match payer_mode:
		PAYER_ME:
			return "Pagas %d (tienes %d)" % [amount, balance]
		PAYER_THEM:
			return "Pagan ellos: %d (tienen %d)" % [amount, balance]
	return "Sin pago"


## Qué haría el tratado, en una frase: lo que se conserva (con conquistas) o se libera (blanca).
static func treaty_summary_text(kind: int, held_by_me: int, held_by_them: int) -> String:
	if kind == Diplomacy.KIND_CONQUESTS:
		return "Cada parte se queda lo que ocupa: ganas hasta %d celdas y pierdes hasta %d." % [held_by_me, held_by_them]
	return "Nadie cambia de dueño. Se liberan %d celdas ocupadas." % (held_by_me + held_by_them)
