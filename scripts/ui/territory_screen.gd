## Pantalla principal (hitos 4 y 5b): une la cuadrícula, la vista pixelada, la leyenda con
## estadísticas, el resumen del jugador y el panel de información.
## Crea la única TerritoryGrid y se la entrega a los demás; ninguno de ellos la modifica.
##
## Las estadísticas se recalculan desde la cuadrícula cuando esta emite ownership_changed,
## como mucho una vez por fotograma (aunque cambien muchas celdas seguidas).
extends Control

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const MapView := preload("res://scripts/world/territory_map_view.gd")
const InfoPanel := preload("res://scripts/ui/territory_info_panel.gd")
const Legend := preload("res://scripts/ui/territory_legend.gd")

var grid: TerritoryGrid

@onready var _view: MapView = %Mapa
@onready var _info: InfoPanel = %Info
@onready var _legend: Legend = %Leyenda
@onready var _player_label: Label = %Jugador


func _ready() -> void:
	grid = TerritoryGrid.new()
	_info.grid = grid
	_view.selection_changed.connect(_info.show_cell)
	_view.set_grid(grid)
	grid.ownership_changed.connect(_on_ownership_changed)
	refresh_stats()


## Recalcula las estadísticas ya (también lo usan las pruebas).
func refresh_stats() -> void:
	var rows := Legend.build_rows(grid)
	_legend.set_rows(rows)
	_player_label.text = Legend.player_summary(rows)
	_info.show_cell(_view.selected_cell)
	set_process(false)


func _on_ownership_changed() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	refresh_stats()
