## Capa de dibujo de los sectores militares (hito 8). Solo lee: no modifica la cuadrícula ni los sectores.
##
## Va como hijo de la vista del mapa, así comparte su posición y escala (1 unidad = 1 celda).
## Cada sector del jugador es un marcador discreto: la celda de origen en un tono claro de su
## nación, una línea hacia la celda objetivo (más intensa) y la cifra de soldados junto al objetivo.
## El sector seleccionado en el panel lleva un recuadro blanco. No hay figuras de soldados.
## Se dibuja en un único _draw y solo se redibuja cuando cambian los sectores, los propietarios
## o la selección.
##
## Limitación conocida: con varios sectores en celdas contiguas las cifras pueden solaparse
## (a escala 3 una celda mide 3 píxeles). La mejora visual queda para la fase visual específica.
extends Node2D

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Military := preload("res://scripts/world/military.gd")

const ORIGIN_LIGHTEN := 0.35
const TARGET_LIGHTEN := 0.7
const LINE_WIDTH := 0.6
const SELECT_COLOR := Color(1, 1, 1, 0.95)
const TEXT_COLOR := Color(1, 1, 1)
const TEXT_OUTLINE_COLOR := Color(0, 0, 0, 0.9)
const EMPTY_TEXT_COLOR := Color(0.75, 0.75, 0.75)
## Tamaño del texto en píxeles de pantalla (se compensa la escala del mapa).
const FONT_SIZE := 11

var _grid: TerritoryGrid
var _military: Military
var _highlight_id: int = Military.NO_SECTOR
## Nación cuyos sectores se dibujan (solo los del jugador).
var _nation_id: int = TerritoryGrid.INVALID


func setup(grid: TerritoryGrid, military: Military, nation_id: int) -> void:
	_grid = grid
	_military = military
	_nation_id = nation_id
	_military.changed.connect(queue_redraw)
	_grid.ownership_changed.connect(queue_redraw)
	queue_redraw()


## Sector que se dibuja con recuadro (Military.NO_SECTOR = ninguno).
func set_highlight(sector_id: int) -> void:
	if sector_id == _highlight_id:
		return
	_highlight_id = sector_id
	queue_redraw()


## Sector dibujado con recuadro (Military.NO_SECTOR si ninguno).
func highlighted_sector() -> int:
	return _highlight_id


func _draw() -> void:
	if _military == null:
		return
	var color: Color = _grid.get_nation(_nation_id)["color"]
	var scale_factor := global_scale
	for sector_id: int in _military.get_sector_ids(_nation_id):
		var sector := _military.get_sector(sector_id)
		var origin: Vector2i = sector["origin"]
		var target: Vector2i = sector["target"]
		draw_rect(Rect2(Vector2(origin), Vector2.ONE), color.lightened(ORIGIN_LIGHTEN))
		draw_rect(Rect2(Vector2(target), Vector2.ONE), color.lightened(TARGET_LIGHTEN))
		draw_line(Vector2(origin) + Vector2(0.5, 0.5), Vector2(target) + Vector2(0.5, 0.5), color.lightened(TARGET_LIGHTEN), LINE_WIDTH)
		if sector_id == _highlight_id:
			draw_rect(Rect2(Vector2(origin), Vector2.ONE).merge(Rect2(Vector2(target), Vector2.ONE)).grow(0.5), SELECT_COLOR, false, 0.5)
		_draw_count(target, sector["soldiers"], scale_factor)


## Escribe la cifra al lado del objetivo con el texto a tamaño de pantalla (se deshace la escala).
func _draw_count(target: Vector2i, soldiers: int, scale_factor: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null or scale_factor.x == 0.0 or scale_factor.y == 0.0:
		return
	var text_color := TEXT_COLOR if soldiers > 0 else EMPTY_TEXT_COLOR
	draw_set_transform(Vector2(target) + Vector2(1.5, 1.0), 0.0, Vector2.ONE / scale_factor)
	draw_string_outline(font, Vector2.ZERO, str(soldiers), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, TEXT_OUTLINE_COLOR)
	draw_string(font, Vector2.ZERO, str(soldiers), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, text_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
