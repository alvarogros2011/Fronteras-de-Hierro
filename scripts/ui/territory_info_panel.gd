## Panel compacto con la información de la celda seleccionada (hito 4): coordenadas,
## terreno y propietario. Solo lee de TerritoryGrid; no tiene ningún control que cambie datos.
extends PanelContainer

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Balance := preload("res://scripts/data/economy_balance.gd")

const NO_CELL := Vector2i(-1, -1)
const EMPTY_TEXT := "Haz clic en una celda de tierra para inspeccionarla."

var grid: TerritoryGrid
## Ciudades (hito 6). Si se asigna, se añade la información de la ciudad que cubra la celda.
var cities: CityManager

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


## Texto de una ciudad: propietario, nivel, producción por segundo y crecimiento.
static func describe_city(source: TerritoryGrid, manager: CityManager, city_id: int) -> String:
	var city := manager.get_city(city_id)
	var nation := source.get_nation(city["owner"])
	var owner_name: String = nation["name"] if not nation.is_empty() else "Sin propietario"
	var growth := "nivel máximo" if city["needed"] == 0 else "crecimiento %d/%d" % [city["progress"], city["needed"]]
	return "Ciudad #%d · %s · nivel %d\nProduce +%s dinero/s, +%s recursos/s · %s" % [city_id, owner_name, city["level"],
			format_rate(city["money_rate"]), format_rate(city["resource_rate"]), growth]


## Cantidad por tick convertida a por segundo ("2" o "0,5").
static func format_rate(per_tick: int) -> String:
	var per_second := per_tick / Balance.TICK_SECONDS
	if is_equal_approx(per_second, roundf(per_second)):
		return "%d" % int(roundf(per_second))
	return ("%.1f" % per_second).replace(".", ",")


func show_cell(cell: Vector2i) -> void:
	if _label == null:
		return
	var text := describe(grid, cell)
	if cities != null and grid != null and grid.is_valid_coord(cell.x, cell.y):
		var city_id := cities.city_covering(cell)
		if city_id != CityManager.NO_CITY:
			text += "\n" + describe_city(grid, cities, city_id)
	_label.text = text
