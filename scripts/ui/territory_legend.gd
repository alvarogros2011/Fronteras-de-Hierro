## Leyenda compacta del mapa (hito 4): un cuadrado de color y un nombre por entrada.
## Los colores de las naciones salen de TerritoryGrid; los de terreno, de la vista.
extends Control

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const MapView := preload("res://scripts/world/territory_map_view.gd")

const COLUMNS := 3
const COLUMN_WIDTH := 200
const ROW_HEIGHT := 22
const SWATCH := 12
const FONT_SIZE := 14

var _entries: Array = []


func setup(source: TerritoryGrid) -> void:
	_entries = []
	for nation_id: int in source.get_nation_ids():
		var nation := source.get_nation(nation_id)
		_entries.append({"name": nation["name"], "color": nation["color"]})
	_entries.append({"name": "Sin reclamar", "color": MapView.COLOR_LAND})
	_entries.append({"name": "Agua", "color": MapView.COLOR_WATER})
	custom_minimum_size = Vector2(COLUMNS * COLUMN_WIDTH, ceili(_entries.size() / float(COLUMNS)) * ROW_HEIGHT)
	queue_redraw()


@warning_ignore("integer_division")
func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in _entries.size():
		var origin := Vector2((i % COLUMNS) * COLUMN_WIDTH, (i / COLUMNS) * ROW_HEIGHT)
		draw_rect(Rect2(origin + Vector2(0, 4), Vector2(SWATCH, SWATCH)), _entries[i]["color"])
		draw_string(font, origin + Vector2(SWATCH + 8, 16), _entries[i]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.78, 0.8, 0.84))
