## Pantalla principal (hitos 4, 5b, 6, 7, 8, 9 y 10): une la cuadrícula, la vista pixelada, la leyenda con
## estadísticas, el resumen del jugador, el panel de información, las ciudades, la economía, la
## población, la organización militar, las ofensivas y la diplomacia. Crea la única TerritoryGrid, la
## Economy, el CityManager (reloj único y pausa), la Population, el Military, la Occupation, el WarState,
## las Offensives y la Diplomacy y se los entrega a los demás. El territorio solo cambia por conquer_cells:
## las ofensivas conquistan tierra sin reclamar y los tratados de paz traspasan lo ocupado; ocupar tierra de
## otra nación no cambia propietarios (Occupation).
##
## Pausa (hito 10): el botón «Pausa» (o la barra espaciadora) pausa el reloj único (CityManager): se
## detienen a la vez ciudades, población, producción, movilizaciones, ofensivas, guerras, treguas y
## propuestas. La interfaz sigue respondiendo y se puede consultar todo.
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
const Military := preload("res://scripts/world/military.gd")
const MilitaryPanel := preload("res://scripts/ui/military_panel.gd")
const SectorLayer := preload("res://scripts/world/sector_layer_view.gd")
const Occupation := preload("res://scripts/world/occupation.gd")
const WarState := preload("res://scripts/world/war_state.gd")
const Diplomacy := preload("res://scripts/world/diplomacy.gd")
const DiplomacyPanel := preload("res://scripts/ui/diplomacy_panel.gd")
const Offensives := preload("res://scripts/world/offensives.gd")
const Balance := preload("res://scripts/data/economy_balance.gd")

## Tope de segundos de juego por fotograma (evita un salto enorme tras una pausa de la ventana).
const MAX_FRAME_DELTA := 0.5

var grid: TerritoryGrid
var economy: Economy
var cities: CityManager
var population: Population
var military: Military
var occupation: Occupation
var wars: WarState
var offensives: Offensives
var diplomacy: Diplomacy
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
@onready var _military_panel: MilitaryPanel = %Militar
@onready var _sector_layer: SectorLayer = %Sectores
@onready var _diplomacy_panel: DiplomacyPanel = %Diplomacia
@onready var _pause_button: Button = %BotonPausa
@onready var _pause_label: Label = %IndicadorPausa


func _ready() -> void:
	grid = TerritoryGrid.new()
	occupation = Occupation.new(grid)
	for nation_id: int in grid.get_nation_ids():
		if grid.get_nation(nation_id)["controller"] == "human":
			_player_id = nation_id
	economy = Economy.new(grid.get_nation_ids())
	cities = CityManager.new(grid, economy)
	cities.set_occupation(occupation)
	wars = WarState.new(cities)
	cities.place_initial_cities()
	population = Population.new(cities, economy, grid.get_nation_ids())
	# Military se crea antes que su panel: así corrige las asignaciones antes de que se lean.
	military = Military.new(grid, population)
	# Las ofensivas avanzan tras la población en cada tick (se conectan después a CityManager.ticked).
	offensives = Offensives.new(grid, population, military, cities, occupation, wars)
	# La diplomacia va después de las ofensivas: en cada tick las ofensivas avanzan antes de que la IA proponga.
	diplomacy = Diplomacy.new(grid, economy, cities, population, occupation, wars, offensives)
	_view.occupation = occupation
	_info.grid = grid
	_info.occupation = occupation
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
	_military_panel.setup(military, population, grid, _player_id, offensives, wars, occupation)
	_diplomacy_panel.setup(diplomacy, wars, grid, economy, occupation, cities, _player_id)
	_sector_layer.setup(grid, military, _player_id, offensives)
	occupation.cells_changed.connect(_repaint_cells)
	offensives.territory_changed.connect(_repaint_cells)
	diplomacy.territory_changed.connect(_repaint_cells)
	occupation.changed.connect(_on_occupation_changed)
	_view.selection_changed.connect(_military_panel.set_origin)
	_military_panel.sector_selected.connect(_sector_layer.set_highlight)
	_found_button.pressed.connect(_on_found_button_pressed)
	_pause_button.pressed.connect(toggle_pause)
	cities.pause_changed.connect(_on_pause_changed)
	refresh_stats()
	_set_founding_ui()
	_set_pause_ui()


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


## Repinta en el mapa las celdas cuyo propietario u ocupación cambiaron (la vista no se entera sola).
func _repaint_cells(cells: Array) -> void:
	for cell: Vector2i in cells:
		_view.refresh_cell(cell.x, cell.y)


func _on_occupation_changed() -> void:
	_info.show_cell(_view.selected_cell)


# ---------------------------------------------------------------------------
# Pausa
# ---------------------------------------------------------------------------

## Pausa o reanuda toda la simulación (el reloj único vive en CityManager).
func set_paused(paused: bool) -> void:
	cities.set_paused(paused)


func toggle_pause() -> void:
	cities.toggle_pause()


func _on_pause_changed(_paused: bool) -> void:
	_set_pause_ui()


func _set_pause_ui() -> void:
	_pause_button.text = "Reanudar (Espacio)" if cities.is_paused() else "Pausa (Espacio)"
	_pause_label.text = "EN PAUSA" if cities.is_paused() else ""


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
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE:
			toggle_pause()
			get_viewport().set_input_as_handled()


func _set_founding_ui() -> void:
	_found_button.text = "Cancelar (Esc)" if founding_mode else "Fundar ciudad (%d)" % Balance.FOUND_COST
