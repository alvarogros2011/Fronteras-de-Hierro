## Dibuja el mapa estratégico (estático) a partir de ProvinceData.
## No guarda información propia de las provincias: regiones, nombres, colores
## de propietario y recuentos salen siempre de los datos.
extends Node2D

const ProvinceData := preload("res://scripts/data/province_data.gd")

const COLOR_PLAYER := Color(0.25, 0.50, 0.80)
const COLOR_ENEMY := Color(0.78, 0.30, 0.28)
const COLOR_BORDER := Color(0.06, 0.07, 0.09)
const COLOR_TEXT := Color(0.96, 0.96, 0.98)
const COLOR_TEXT_OUTLINE := Color(0.05, 0.06, 0.08)
const COLOR_LEGEND_TEXT := Color(0.80, 0.83, 0.87)

const BORDER_WIDTH := 3.0
const LABEL_FONT_SIZE := 18
const LEGEND_FONT_SIZE := 18
const LEGEND_Y := 668.0
const LEGEND_SWATCH := Vector2(22, 22)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for province: Dictionary in ProvinceData.all():
		_draw_province(province, font)
	_draw_legend(font)


func _owner_color(owner_id: String) -> Color:
	return COLOR_PLAYER if owner_id == ProvinceData.OWNER_PLAYER else COLOR_ENEMY


func _draw_province(province: Dictionary, font: Font) -> void:
	var polygon := PackedVector2Array(province["polygon"])
	draw_colored_polygon(polygon, _owner_color(province["owner"]))
	# Contorno cerrado: se repite el primer vértice al final.
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, COLOR_BORDER, BORDER_WIDTH)
	var center := ProvinceData.polygon_center(province["polygon"])
	_draw_centered_text(font, province["name"], center, LABEL_FONT_SIZE)


func _draw_centered_text(font: Font, text: String, center: Vector2, font_size: int) -> void:
	var baseline := Vector2(center.x - 100.0, center.y - font.get_height(font_size) / 2.0 + font.get_ascent(font_size))
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, 200.0, font_size, 5, COLOR_TEXT_OUTLINE)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, 200.0, font_size, COLOR_TEXT)


func _draw_legend(font: Font) -> void:
	var player_count := ProvinceData.count_owned_by(ProvinceData.OWNER_PLAYER)
	var enemy_count := ProvinceData.count_owned_by(ProvinceData.OWNER_ENEMY)
	var entries := [
		[COLOR_PLAYER, "Jugador: %d" % player_count],
		[COLOR_ENEMY, "Enemigo: %d" % enemy_count],
	]
	var x := 140.0
	for entry: Array in entries:
		draw_rect(Rect2(Vector2(x, LEGEND_Y), LEGEND_SWATCH), entry[0])
		draw_rect(Rect2(Vector2(x, LEGEND_Y), LEGEND_SWATCH), COLOR_BORDER, false, 2.0)
		var text_pos := Vector2(x + LEGEND_SWATCH.x + 10.0, LEGEND_Y + font.get_ascent(LEGEND_FONT_SIZE))
		draw_string(font, text_pos, entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, COLOR_LEGEND_TEXT)
		x += 200.0
	var total_text := "Provincias: %d" % ProvinceData.all().size()
	var total_pos := Vector2(1140.0 - 260.0, LEGEND_Y + font.get_ascent(LEGEND_FONT_SIZE))
	draw_string(font, total_pos, total_text, HORIZONTAL_ALIGNMENT_RIGHT, 260.0, LEGEND_FONT_SIZE, COLOR_LEGEND_TEXT)
