## Panel compacto con la información de la celda seleccionada (hito 4): coordenadas,
## terreno y propietario. Solo lee de TerritoryGrid; no tiene ningún control que cambie datos.
extends PanelContainer

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")

const NO_CELL := Vector2i(-1, -1)
const EMPTY_TEXT := "Haz clic en una celda de tierra para inspeccionarla."

var grid: TerritoryGrid

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	add_child(_label)
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


func show_cell(cell: Vector2i) -> void:
	if _label != null:
		_label.text = describe(grid, cell)
