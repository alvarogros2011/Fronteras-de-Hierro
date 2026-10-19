## Capa de dibujo de las ciudades (hito 6). Solo lee: no modifica la cuadrícula ni las ciudades.
##
## Va como hijo de la vista del mapa, así comparte su posición y escala (1 unidad = 1 celda).
## Cada ciudad es una mancha de píxeles (CityManager.visual_cells, siempre dentro del territorio
## de su propietario) en un tono claro del color de la nación, con el centro más claro. Se dibuja
## con rectángulos de 1 celda en un único _draw (sin un nodo por píxel) y solo se redibuja cuando
## cambian las ciudades o algún propietario.
extends Node2D

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")

const BODY_LIGHTEN := 0.55
const CENTER_COLOR := Color(1, 1, 1, 1)
## Centro de una ciudad ocupada (hito 9): su producción está suspendida.
const OCCUPIED_CENTER_COLOR := Color(1.0, 0.55, 0.15, 1)

var _grid: TerritoryGrid
var _cities: CityManager


func setup(grid: TerritoryGrid, cities: CityManager) -> void:
	_grid = grid
	_cities = cities
	_cities.changed.connect(queue_redraw)
	_grid.ownership_changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if _cities == null:
		return
	for city_id: int in _cities.get_city_ids():
		var owner_id := _cities.get_owner(city_id)
		if owner_id == TerritoryGrid.OWNER_NONE:
			continue
		var color: Color = _grid.get_nation(owner_id)["color"]
		var body := color.lightened(BODY_LIGHTEN)
		for cell in _cities.visual_cells(city_id):
			draw_rect(Rect2(Vector2(cell), Vector2.ONE), body)
		var center: Vector2i = _cities.get_city(city_id)["cell"]
		draw_rect(Rect2(Vector2(center), Vector2.ONE), OCCUPIED_CENTER_COLOR if _cities.is_occupied(city_id) else CENTER_COLOR)
