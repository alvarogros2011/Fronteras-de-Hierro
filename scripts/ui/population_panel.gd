## Panel de población del jugador (hito 7): resumen de población, reparto de la población nueva,
## movilización, prioridad de mantenimiento y aviso de déficit. Va en la columna derecha, fuera
## del mapa, y captura el clic para no seleccionar el mapa por error.
##
## No guarda datos propios: cada refresh() lee del estado real (Population, CityManager). Los
## controles solo llaman a las órdenes de Population; los valores mostrados vuelven siempre de ahí.
## Los textos salen de funciones estáticas para poder probarlos sin nodos.
extends PanelContainer

const Population := preload("res://scripts/world/population.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Balance := preload("res://scripts/data/population_balance.gd")
const EconomyBalance := preload("res://scripts/data/economy_balance.gd")

const FONT_SIZE := 12
const INNER_WIDTH := 124
const TEXT_COLOR := Color(0.85, 0.87, 0.9)
const MUTED_COLOR := Color(0.6, 0.64, 0.7)
const OK_COLOR := Color(0.55, 0.85, 0.55)
const WARN_COLOR := Color(0.95, 0.75, 0.3)
const BAD_COLOR := Color(0.95, 0.4, 0.4)
const DEFAULT_MOBILIZATION_PERCENT := 25
const MOBILIZATION_STEP := 5

var _population: Population
var _cities: CityManager
var _nation_id: int = -1

var _summary_label: Label
var _growth_label: Label
var _split_slider: HSlider
var _split_label: Label
var _mob_slider: HSlider
var _mob_button: Button
var _mob_label: Label
var _mob_bar: ProgressBar
var _maint_label: Label
var _maint_button: Button
var _deficit_label: Label
var _message_label: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_add_heading(box, "POBLACIÓN")
	_summary_label = _add_label(box, TEXT_COLOR, "Resumen")
	_growth_label = _add_label(box, MUTED_COLOR, "Crecimiento")

	_add_heading(box, "POBLACIÓN NUEVA")
	_split_slider = _add_slider(box, 0, 100, 1, "SliderNueva")
	_split_slider.value_changed.connect(_on_split_changed)
	_split_label = _add_label(box, TEXT_COLOR, "ReparteNueva")

	_add_heading(box, "MOVILIZACIÓN")
	_mob_slider = _add_slider(box, MOBILIZATION_STEP, Balance.MOBILIZATION_MAX_PERCENT, MOBILIZATION_STEP, "SliderMovilizacion")
	_mob_slider.set_value_no_signal(DEFAULT_MOBILIZATION_PERCENT)
	_mob_slider.value_changed.connect(_on_mob_slider_changed)
	_mob_button = Button.new()
	_mob_button.name = "BotonMovilizar"
	_mob_button.focus_mode = Control.FOCUS_NONE
	_mob_button.add_theme_font_size_override("font_size", FONT_SIZE)
	_mob_button.pressed.connect(_on_mob_button_pressed)
	box.add_child(_mob_button)
	_mob_bar = ProgressBar.new()
	_mob_bar.show_percentage = false
	_mob_bar.custom_minimum_size = Vector2(INNER_WIDTH, 6)
	_mob_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_mob_bar)
	_mob_label = _add_label(box, TEXT_COLOR, "EstadoMovilizacion")

	_add_heading(box, "MANTENIMIENTO")
	_maint_label = _add_label(box, TEXT_COLOR, "EstadoMantenimiento")
	_maint_button = Button.new()
	_maint_button.name = "BotonPrioridadMantenimiento"
	_maint_button.focus_mode = Control.FOCUS_NONE
	_maint_button.add_theme_font_size_override("font_size", FONT_SIZE)
	_maint_button.pressed.connect(_on_maint_button_pressed)
	box.add_child(_maint_button)
	_deficit_label = _add_label(box, BAD_COLOR, "Deficit")
	_message_label = _add_label(box, MUTED_COLOR, "Mensaje")
	_mob_button.text = mobilization_button_text(DEFAULT_MOBILIZATION_PERCENT)


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


func _add_slider(box: Container, min_value: int, max_value: int, step: int, node_name: String) -> HSlider:
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(INNER_WIDTH, 16)
	box.add_child(slider)
	return slider


## Conecta el panel con los datos del jugador y lo refresca. Se vuelve a dibujar solo cada vez
## que Population emite `changed`.
func setup(population: Population, cities: CityManager, nation_id: int) -> void:
	_population = population
	_cities = cities
	_nation_id = nation_id
	population.changed.connect(refresh)
	refresh()


## Vuelve a leer el estado real y actualiza todos los textos y controles.
func refresh() -> void:
	if _population == null or _summary_label == null:
		return
	var summary := _population.get_summary(_nation_id)
	var maintenance := _population.get_maintenance(_nation_id)
	var mobilization := _population.get_mobilization(_nation_id)
	if summary.is_empty():
		return
	_summary_label.text = summary_text(summary)
	_growth_label.text = growth_text(summary, maintenance)
	_split_slider.set_value_no_signal(summary["new_soldier_percent"])
	_split_label.text = split_text(summary["new_soldier_percent"])
	_mob_label.text = mobilization_text(mobilization)
	_mob_bar.visible = mobilization["active"]
	_mob_bar.value = mobilization["progress_percent"]
	_mob_button.disabled = mobilization["active"]
	var income: int = _cities.income_for(_nation_id)["resources"]
	_maint_label.text = maintenance_text(maintenance, income)
	_maint_label.add_theme_color_override("font_color", OK_COLOR if not maintenance["in_deficit"] else BAD_COLOR)
	_maint_button.text = maintenance_priority_text(maintenance["priority"])
	_deficit_label.text = deficit_text(maintenance)
	_deficit_label.visible = maintenance["in_deficit"]


func _on_split_changed(value: float) -> void:
	_population.set_new_soldier_percent(_nation_id, int(value))


func _on_mob_slider_changed(value: float) -> void:
	_mob_button.text = mobilization_button_text(int(value))


func _on_mob_button_pressed() -> void:
	var code := _population.start_mobilization(_nation_id, int(_mob_slider.value))
	_message_label.text = Population.mobilization_error_message(code)


func _on_maint_button_pressed() -> void:
	var next := Population.MAINT_SOLDIERS_FIRST
	if _population.maintenance_priority(_nation_id) == Population.MAINT_SOLDIERS_FIRST:
		next = Population.MAINT_WORKERS_FIRST
	_population.set_maintenance_priority(_nation_id, next)


# ---------------------------------------------------------------------------
# Textos (funciones puras, probadas sin interfaz)
# ---------------------------------------------------------------------------

## "Población 36\nTrabajadores 30\nSoldados 6" a partir de Population.get_summary.
static func summary_text(summary: Dictionary) -> String:
	return "Población %d\nTrabajadores %d\nSoldados %d" % [summary["total"], summary["workers"], summary["soldiers"]]


## Cantidad por tick en milésimas, convertida a por segundo: "1", "0,51" o "0,15".
static func format_milli_rate(milli_per_tick: int) -> String:
	var per_second_milli := milli_per_tick / EconomyBalance.TICK_SECONDS
	if is_equal_approx(per_second_milli / 1000.0, roundf(per_second_milli / 1000.0)):
		return "%d" % int(roundf(per_second_milli / 1000.0))
	return ("%.2f" % (per_second_milli / 1000.0)).replace(".", ",")


static func growth_text(summary: Dictionary, maintenance: Dictionary) -> String:
	if maintenance["in_deficit"]:
		return "Crecimiento detenido por el déficit"
	if summary["capacity"] == 0:
		return "Sin ciudades: no crece"
	if summary["total"] >= summary["capacity"]:
		return "Población al máximo (%d)" % summary["capacity"]
	return "Crece +%s/s · máx. %d" % [format_milli_rate(summary["growth_milli"]), summary["capacity"]]


## "Trab. 80 % · Sold. 20 %" (siempre suman 100).
static func split_text(soldier_percent: int) -> String:
	return "Trab. %d %% · Sold. %d %%" % [100 - soldier_percent, soldier_percent]


static func mobilization_button_text(percent: int) -> String:
	return "Movilizar %d %%" % percent


## Estado de la movilización a partir de Population.get_mobilization.
static func mobilization_text(mobilization: Dictionary) -> String:
	if not mobilization["active"]:
		return "Sin movilización"
	return "Movilizando %d/%d (%d %%)\nPendientes: %d" % [mobilization["converted"], mobilization["total"],
			mobilization["progress_percent"], mobilization["pending"]]


## Coste de mantenimiento frente a la producción de recursos (por segundo) y si es suficiente.
static func maintenance_text(maintenance: Dictionary, resource_income_per_tick: int) -> String:
	var state := "Suficiente" if not maintenance["in_deficit"] else "INSUFICIENTE"
	return "Coste %s/s · Producción %s/s\n%s" % [format_milli_rate(maintenance["cost_milli"]["total"]),
			format_milli_rate(resource_income_per_tick * 1000), state]


static func maintenance_priority_text(priority: int) -> String:
	return "Cobra 1.º: Ejército" if priority == Population.MAINT_SOLDIERS_FIRST else "Cobra 1.º: Economía"


## Aviso de déficit (vacío si no lo hay): qué grupos no se pagan y qué consecuencia sufren.
static func deficit_text(maintenance: Dictionary) -> String:
	if not maintenance["in_deficit"]:
		return ""
	var short: Array[String] = []
	var losing: Array[String] = []
	if not maintenance["workers_covered"]:
		short.append("trabajadores")
		if maintenance["worker_short_ticks"] > Balance.DEFICIT_GRACE_TICKS:
			losing.append("trabajadores")
	if not maintenance["soldiers_covered"]:
		short.append("soldados")
		if maintenance["soldier_short_ticks"] > Balance.DEFICIT_GRACE_TICKS:
			losing.append("soldados")
	if losing.is_empty():
		return "Déficit: sin recursos para %s. Sin crecimiento." % " y ".join(short)
	return "Déficit grave: pierden población los %s." % " y ".join(losing)
