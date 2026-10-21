## Panel compacto con la información de la celda seleccionada (hito 4): coordenadas,
## terreno y propietario. Solo lee de TerritoryGrid. Desde el hito 7, si la celda pertenece a una
## ciudad del jugador, añade un control para activar o quitar su prioridad de crecimiento de
## población (solo cambia el crecimiento de población: nunca territorio, dinero ni nivel).
## Hito 11: la ciudad muestra también sus puestos de trabajo, y la prioridad su coste en dinero y su
## efecto (población x2 y nivel más rápido).
extends PanelContainer

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Population := preload("res://scripts/world/population.gd")
const Occupation := preload("res://scripts/world/occupation.gd")
const PopulationPanel := preload("res://scripts/ui/population_panel.gd")
const PopulationBalance := preload("res://scripts/data/population_balance.gd")
const Balance := preload("res://scripts/data/economy_balance.gd")

const NO_CELL := Vector2i(-1, -1)
const EMPTY_TEXT := "Haz clic en una celda de tierra para inspeccionarla."

var grid: TerritoryGrid
## Ciudades (hito 6). Si se asigna, se añade la información de la ciudad que cubra la celda.
var cities: CityManager
## Población (hito 7) y nación del jugador. Si ambos están asignados, las ciudades del jugador
## muestran el control de prioridad de crecimiento.
var population: Population
var player_id: int = TerritoryGrid.INVALID
## Ocupación militar (hito 9). Si se asigna, una celda ocupada lo indica (la propiedad oficial no cambia).
var occupation: Occupation = null

var _label: Label
var _priority_button: CheckButton
var _shown_city_id: int = CityManager.NO_CITY


func _ready() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	box.add_child(_label)
	_priority_button = CheckButton.new()
	_priority_button.focus_mode = Control.FOCUS_NONE
	_priority_button.add_theme_font_size_override("font_size", 12)
	_priority_button.visible = false
	_priority_button.toggled.connect(_on_priority_toggled)
	box.add_child(_priority_button)
	show_cell(NO_CELL)


## Texto del panel para una celda (NO_CELL o fuera de límites = texto de ayuda).
static func describe(source: TerritoryGrid, cell: Vector2i) -> String:
	if source == null or not source.is_valid_coord(cell.x, cell.y):
		return EMPTY_TEXT
	var terrain := "Tierra" if source.is_land(cell.x, cell.y) else "Agua"
	var owner_id := source.get_cell_owner(cell.x, cell.y)
	var owner_name := "Sin reclamar"
	if owner_id != TerritoryGrid.OWNER_NONE:
		owner_name = source.get_nation(owner_id)["name"]
	return "Celda (%d, %d) · %s\nPropietario: %s" % [cell.x, cell.y, terrain, owner_name]


## Línea de ocupación de una celda: «Ocupada por X (provisional)», o "" si nadie la ocupa. La
## propiedad oficial se muestra aparte y no cambia por la ocupación.
static func describe_occupation(source: TerritoryGrid, occupied_by: Occupation, cell: Vector2i) -> String:
	if source == null or occupied_by == null or not occupied_by.is_occupied(cell):
		return ""
	var nation := source.get_nation(occupied_by.occupier_at(cell))
	return "Ocupada por %s (provisional)" % (nation["name"] if not nation.is_empty() else "otra nación")


## Texto de una ciudad: propietario, nivel, producción por segundo y crecimiento. Si su centro está
## ocupado, avisa de que la producción está suspendida.
static func describe_city(source: TerritoryGrid, manager: CityManager, city_id: int) -> String:
	var city := manager.get_city(city_id)
	var nation := source.get_nation(city["owner"])
	var owner_name: String = nation["name"] if not nation.is_empty() else "Sin propietario"
	var growth := "nivel máximo" if city["needed"] == 0 else "crecimiento %d/%d" % [city["progress"], city["needed"]]
	var text := "Ciudad #%d · %s · nivel %d\nProduce +%s dinero/s, +%s recursos/s · %s" % [city_id, owner_name, city["level"],
			format_rate(city["money_rate"]), format_rate(city["resource_rate"]), growth]
	if city["occupied"]:
		text += "\nCiudad ocupada: producción suspendida"
	return text


## Línea de trabajo de la ciudad (hito 11): «Puestos de trabajo 30» (0 si está ocupada) y, si es
## prioritaria, su coste.
static func city_work_text(source: Population, manager: CityManager, city_id: int) -> String:
	var city := manager.get_city(city_id)
	var jobs: int = 0 if city["occupied"] else PopulationBalance.JOBS_PER_LEVEL[city["level"]]
	var text := "Puestos de trabajo %d" % jobs
	if source.is_city_priority(city_id):
		text += " · Prioridad: -%d dinero/s" % PopulationBalance.PRIORITY_MONEY_PER_TICK
	return text


## Cantidad por tick convertida a por segundo ("2" o "0,5").
static func format_rate(per_tick: int) -> String:
	var per_second := per_tick / Balance.TICK_SECONDS
	if is_equal_approx(per_second, roundf(per_second)):
		return "%d" % int(roundf(per_second))
	return ("%.1f" % per_second).replace(".", ",")


## Texto del control de prioridad: "Prioridad de población · +0,15/s" (aporte bruto de la ciudad).
static func priority_text(source: Population, city_id: int) -> String:
	return "Prioridad de población · +%s/s" % PopulationPanel.format_milli_rate(source.city_growth_milli(city_id))


func show_cell(cell: Vector2i) -> void:
	if _label == null:
		return
	var text := describe(grid, cell)
	var occupation_line := describe_occupation(grid, occupation, cell)
	if occupation_line != "":
		text += "\n" + occupation_line
	var city_id := CityManager.NO_CITY
	if cities != null and grid != null and grid.is_valid_coord(cell.x, cell.y):
		city_id = cities.city_covering(cell)
		if city_id != CityManager.NO_CITY:
			text += "\n" + describe_city(grid, cities, city_id)
			if population != null:
				text += "\n" + city_work_text(population, cities, city_id)
	_label.text = text
	_shown_city_id = CityManager.NO_CITY
	_priority_button.visible = false
	if city_id != CityManager.NO_CITY and population != null and cities.get_owner(city_id) == player_id:
		_shown_city_id = city_id
		_priority_button.visible = true
		_priority_button.text = priority_text(population, city_id)
		_priority_button.tooltip_text = "Cuesta %d de dinero por segundo: duplica el crecimiento de población de la ciudad y acelera su subida de nivel." % PopulationBalance.PRIORITY_MONEY_PER_TICK
		_priority_button.set_pressed_no_signal(population.is_city_priority(city_id))


## Control de prioridad de crecimiento (visible solo con una ciudad del jugador seleccionada).
func priority_toggle() -> CheckButton:
	return _priority_button


func _on_priority_toggled(pressed: bool) -> void:
	if _shown_city_id != CityManager.NO_CITY and population != null:
		population.set_city_priority(player_id, _shown_city_id, pressed)
