## Pantalla del hito 4: une la cuadrícula, la vista pixelada, la leyenda y el panel de información.
## Crea la única TerritoryGrid y se la entrega a los demás; ninguno de ellos la modifica.
extends Control

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const MapView := preload("res://scripts/world/territory_map_view.gd")
const InfoPanel := preload("res://scripts/ui/territory_info_panel.gd")
const Legend := preload("res://scripts/ui/territory_legend.gd")

@onready var _view: MapView = %Mapa
@onready var _info: InfoPanel = %Info
@onready var _legend: Legend = %Leyenda


func _ready() -> void:
	var grid := TerritoryGrid.new()
	_info.grid = grid
	_legend.setup(grid)
	_view.selection_changed.connect(_info.show_cell)
	_view.set_grid(grid)
