## Capa de dibujo de los sectores militares (hito 8). Solo lee: no modifica la cuadrícula ni los sectores.
##
## Va como hijo de la vista del mapa, así comparte su posición y escala (1 unidad = 1 celda).
## Cada sector del jugador es un marcador discreto: la celda de origen en un tono claro de su
## nación, una línea hasta la celda objetivo con una pequeña punta de flecha, y la cifra de
## soldados junto al objetivo. El sector elegido en el panel lleva un recuadro blanco y su cifra
## se dibuja siempre y encima de las demás. No hay figuras de soldados.
##
## Solapamiento: las cifras no se amontonan. Se colocan una a una (la elegida la última, para que
## se vea) en la primera de cuatro posiciones (derecha, izquierda, debajo, encima del objetivo)
## que no choque con otra cifra ya colocada; si no cabe en ninguna, esa cifra no se dibuja (el
## número exacto de cada sector sigue en la lista del panel). Se dibuja en un único _draw y solo
## se redibuja cuando cambian los sectores, los propietarios o la selección.
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
## Hueco mínimo, en celdas, entre una cifra y la celda objetivo.
const LABEL_GAP := 0.4

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


## Dónde va la cifra de cada sector de la nación: {id de sector: Rect2} en unidades de celda, solo
## para las cifras que caben sin chocar con otra (la del sector elegido siempre aparece, aunque
## tenga que solaparse). `char_size` es el tamaño de un carácter y de una línea de texto en
## unidades de celda; el ancho de cada cifra es su número de caracteres por `char_size.x`.
func label_layout(char_size: Vector2) -> Dictionary:
	var layout: Dictionary = {}
	if _military == null:
		return layout
	var ids := _military.get_sector_ids(_nation_id)
	var ordered: Array = []
	for sector_id: int in ids:
		if sector_id != _highlight_id:
			ordered.append(sector_id)
	if ids.has(_highlight_id):
		ordered.append(_highlight_id)
	var taken: Array[Rect2] = []
	for sector_id: int in ordered:
		var sector := _military.get_sector(sector_id)
		var size := Vector2(char_size.x * str(sector["soldiers"]).length(), char_size.y)
		var rect := _free_rect(sector["target"], size, taken, sector_id == _highlight_id)
		if rect.size != Vector2.ZERO:
			layout[sector_id] = rect
			taken.append(rect)
	return layout


## Primera posición libre para una cifra de tamaño `size` junto a la celda objetivo, o un Rect2
## vacío si no cabe (salvo `force`: entonces se usa la primera aunque choque).
func _free_rect(target: Vector2i, size: Vector2, taken: Array[Rect2], force: bool) -> Rect2:
	var cell := Vector2(target)
	var candidates: Array[Rect2] = [
		Rect2(cell + Vector2(1.0 + LABEL_GAP, 0.5 - size.y / 2.0), size),
		Rect2(cell + Vector2(-LABEL_GAP - size.x, 0.5 - size.y / 2.0), size),
		Rect2(cell + Vector2(0.5 - size.x / 2.0, 1.0 + LABEL_GAP), size),
		Rect2(cell + Vector2(0.5 - size.x / 2.0, -LABEL_GAP - size.y), size),
	]
	for rect in candidates:
		var fits := true
		for other in taken:
			if rect.intersects(other):
				fits = false
				break
		if fits:
			return rect
	return candidates[0] if force else Rect2()


func _draw() -> void:
	if _military == null:
		return
	var color: Color = _grid.get_nation(_nation_id)["color"]
	for sector_id: int in _military.get_sector_ids(_nation_id):
		_draw_marker(_military.get_sector(sector_id), color, sector_id == _highlight_id)
	var font: Font = ThemeDB.fallback_font
	var scale_factor := global_scale
	if font == null or scale_factor.x == 0.0 or scale_factor.y == 0.0:
		return
	# Tamaño del texto en celdas: píxeles de pantalla entre la escala del mapa.
	var char_size := Vector2(font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / scale_factor.x, font.get_height(FONT_SIZE) / scale_factor.y)
	var ascent := font.get_ascent(FONT_SIZE) / scale_factor.y
	var layout := label_layout(char_size)
	for sector_id: int in layout:
		var soldiers: int = _military.get_sector(sector_id)["soldiers"]
		var rect: Rect2 = layout[sector_id]
		var text_color := TEXT_COLOR if soldiers > 0 else EMPTY_TEXT_COLOR
		draw_set_transform(rect.position + Vector2(0.0, ascent), 0.0, Vector2.ONE / scale_factor)
		draw_string_outline(font, Vector2.ZERO, str(soldiers), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, TEXT_OUTLINE_COLOR)
		draw_string(font, Vector2.ZERO, str(soldiers), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, text_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Origen, línea y punta de flecha de un sector (la cifra se dibuja aparte).
func _draw_marker(sector: Dictionary, color: Color, selected: bool) -> void:
	var origin: Vector2i = sector["origin"]
	var target: Vector2i = sector["target"]
	var line_color := color.lightened(TARGET_LIGHTEN)
	var from := Vector2(origin) + Vector2(0.5, 0.5)
	var to := Vector2(target) + Vector2(0.5, 0.5)
	draw_rect(Rect2(Vector2(origin), Vector2.ONE), color.lightened(ORIGIN_LIGHTEN))
	draw_line(from, to, line_color, LINE_WIDTH)
	var forward := Vector2(target - origin)
	var side := Vector2(forward.y, forward.x).abs() * 0.5
	draw_colored_polygon(PackedVector2Array([to + forward * 0.5, to - forward * 0.5 + side, to - forward * 0.5 - side]), line_color)
	if selected:
		var area := Rect2(Vector2(origin), Vector2.ONE).merge(Rect2(Vector2(target), Vector2.ONE))
		draw_rect(area.grow(0.5), SELECT_COLOR, false, 0.5)
