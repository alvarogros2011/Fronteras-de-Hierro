## Pantalla principal (hitos 4, 5b, 6 y 7): une la cuadrícula, la vista pixelada, la leyenda con
## estadísticas, el resumen del jugador, el panel de información, las ciudades, la economía y la
## población. Crea la única TerritoryGrid, la Economy, el CityManager y la Population y se los
## entrega a los demás. Ninguno de ellos modifica el territorio.
##
## Las estadísticas territoriales se recalculan desde la cuadrícula cuando esta emite
## ownership_changed, como mucho una vez por fotograma. La economía (saldos) se refresca al
## cambiar los saldos. El tiempo del juego avanza en _physics_process.
##
## Modo de fundación: el botón (o begin_founding) lo activa; mientras está activo el clic en el
## mapa intenta fundar una ciudad en vez de seleccionar. Escape o el botón lo cancelan.
extends Control

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const MapView := preload("res://scripts/world/territory_map_view.gd")
const InfoPanel := preload("res://scripts/ui/territory_info_panel.gd")
const Legend := preload("res://scripts/ui/territory_legend.gd")
const Economy := preload("res://scripts/world/economy.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const CityLayer := preload("res://scripts/world/city_layer_view.gd")
const Population := preload("res://scripts/world/population.gd")
const PopulationPanel := preload("res://scripts/ui/population_panel.gd")
const Balance := preload("res://scripts/data/economy_balance.gd")

## Tope de segundos de juego por fotograma (evita un salto enorme tras una pausa de la ventana).
const MAX_FRAME_DELTA := 0.5

var grid: TerritoryGrid
var economy: Economy
var cities: CityManager
var population: Population
var founding_mode: bool = false

var _player_id: int = TerritoryGrid.INVALID

@onready var _view: MapView = %Mapa
@onready var _info: InfoPanel = %Info
@onready var _legend: Legend = %Leyenda
@onready var _player_label: Label = %Jugador
@onready var _economy_label: Label = %Economia
@onready var _found_button: Button = %BotonFundar
@onready var _message_label: Label = %Mensaje
@onready var _city_layer: CityLayer = %Ciudades
@onready var _population_panel: PopulationPanel = %Poblacion


func _ready() -> void:
	grid = TerritoryGrid.new()
	for nation_id: int in grid.get_nation_ids():
		if grid.get_nation(nation_id)["controller"] == "human":
			_player_id = nation_id
	economy = Economy.new(grid.get_nation_ids())
	cities = CityManager.new(grid, economy)
	cities.place_initial_cities()
	population = Population.new(cities, economy, grid.get_nation_ids())
	_info.grid = grid
	_info.cities = cities
	_info.population = population
	_info.player_id = _player_id
	_view.selection_changed.connect(_info.show_cell)
	_view.cell_clicked.connect(_on_cell_clicked)
	_view.set_grid(grid)
	_city_layer.setup(grid, cities)
	grid.ownership_changed.connect(_on_ownership_changed)
	economy.balances_changed.connect(_refresh_economy)
	cities.changed.connect(_on_cities_changed)
	population.changed.connect(_on_population_changed)
	_population_panel.setup(population, cities, _player_id)
	_found_button.pressed.connect(_on_found_button_pressed)
	refresh_stats()
	_set_founding_ui()


## Recalcula las estadísticas ya (también lo usan las pruebas).
func refresh_stats() -> void:
	var rows := Legend.build_rows(grid)
	_legend.set_rows(rows)
	_player_label.text = Legend.player_summary(rows)
	_info.show_cell(_view.selected_cell)
	_refresh_economy()
	set_process(false)


func _on_ownership_changed() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	refresh_stats()


func _physics_process(delta: float) -> void:
	cities.advance(minf(delta, MAX_FRAME_DELTA))


# ---------------------------------------------------------------------------
# Economía en el HUD
# ---------------------------------------------------------------------------

## "Dinero 50 (+2/s) · Recursos 0 (+1/s)" para la nación indicada.
static func economy_summary(source: Economy, manager: CityManager, nation_id: int) -> String:
	var income := manager.income_for(nation_id)
	return "Dinero %d (+%s/s) · Recursos %d (+%s/s)" % [source.get_money(nation_id), InfoPanel.format_rate(income["money"]),
			source.get_resources(nation_id), InfoPanel.format_rate(income["resources"])]


func _refresh_economy() -> void:
	_economy_label.text = economy_summary(economy, cities, _player_id)


func _on_cities_changed() -> void:
	_refresh_economy()
	_info.show_cell(_view.selected_cell)


## La población cambia cada tick y con las órdenes: se refresca el panel de la celda
## seleccionada (estado de la prioridad de crecimiento de su ciudad).
func _on_population_changed() -> void:
	_info.show_cell(_view.selected_cell)


# ---------------------------------------------------------------------------
# Modo de fundación
# ---------------------------------------------------------------------------

func begin_founding() -> void:
	founding_mode = true
	_view.selection_enabled = false
	_set_founding_ui()
	_message_label.text = "Haz clic en tu territorio para fundar. Esc cancela."


func cancel_founding() -> void:
	founding_mode = false
	_view.selection_enabled = true
	_set_founding_ui()
	_message_label.text = ""


## Intenta fundar una ciudad del jugador en la celda. Si sale bien, termina el modo de
## fundación; si no, muestra el motivo y el modo sigue activo para reintentar o cancelar.
## Devuelve el resultado de CityManager.found_city.
func try_found_at(cell: Vector2i) -> Dictionary:
	var result := cities.found_city(_player_id, cell)
	if result["ok"]:
		cancel_founding()
		_message_label.text = "Ciudad fundada en (%d, %d)." % [cell.x, cell.y]
	else:
		_message_label.text = CityManager.error_message(result["error"])
	return result


func _on_cell_clicked(cell: Vector2i) -> void:
	if founding_mode:
		try_found_at(cell)


func _on_found_button_pressed() -> void:
	if founding_mode:
		cancel_founding()
	else:
		begin_founding()


func _unhandled_key_input(event: InputEvent) -> void:
	if founding_mode and event.is_action_pressed("ui_cancel"):
		cancel_founding()
		get_viewport().set_input_as_handled()


func _set_founding_ui() -> void:
	_found_button.text = "Cancelar (Esc)" if founding_mode else "Fundar ciudad (%d)" % Balance.FOUND_COST
