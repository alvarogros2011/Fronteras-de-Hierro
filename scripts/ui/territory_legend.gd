## Leyenda y resumen territorial del mapa (hitos 4 y 5b): una fila por nación con su color,
## nombre, celdas de tierra que controla y su porcentaje de la tierra total del mapa.
## Después, "Sin reclamar" (tierra sin dueño, con sus celdas) y "Agua" (solo color).
##
## No guarda datos propios: las filas se construyen a partir de TerritoryGrid con build_rows
## y la pantalla las vuelve a pedir cuando cambia algún propietario (señal ownership_changed).
## Son estadísticas de TERRITORIO (celdas de tierra), no de población, poder militar ni economía.
extends Control

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const MapView := preload("res://scripts/world/territory_map_view.gd")

const COLUMNS := 2
const COLUMN_WIDTH := 300
const ROW_HEIGHT := 22
const SWATCH := 12
const FONT_SIZE := 14
const TEXT_COLOR := Color(0.78, 0.8, 0.84)
const MUTED_COLOR := Color(0.6, 0.64, 0.7)
const PLAYER_MARK_COLOR := Color(1, 1, 1, 0.9)

var _rows: Array = []


## Filas de la leyenda desde la cuadrícula (la única fuente de datos). Cada fila:
##   {"name", "color", "cells": int (-1 = sin cifra), "share": String ("" = sin cifra), "human": bool}
## Orden: naciones por ID, tierra sin reclamar y agua. El porcentaje es de la TIERRA total
## (agua excluida), con una decimal y coma decimal.
static func build_rows(source: TerritoryGrid) -> Array:
	var counts := source.count_land_by_owner()
	var total := 0
	for owner_id: int in counts:
		total += counts[owner_id]
	var rows: Array = []
	for nation_id: int in source.get_nation_ids():
		var nation := source.get_nation(nation_id)
		rows.append({"name": nation["name"], "color": nation["color"], "cells": counts[nation_id],
				"share": format_share(counts[nation_id], total), "human": nation["controller"] == "human"})
	var unclaimed: int = counts[TerritoryGrid.OWNER_NONE]
	rows.append({"name": "Sin reclamar", "color": MapView.COLOR_LAND, "cells": unclaimed,
			"share": format_share(unclaimed, total), "human": false})
	rows.append({"name": "Agua", "color": MapView.COLOR_WATER, "cells": -1, "share": "", "human": false})
	return rows


## "12,3 %" para cells sobre total; "0,0 %" si total es 0.
static func format_share(cells: int, total: int) -> String:
	if total <= 0:
		return "0,0 %"
	return ("%.1f" % (100.0 * cells / total)).replace(".", ",") + " %"


## Texto de una fila con cifras: "441 celdas · 1,6 %"; vacío si la fila no tiene cifra.
static func row_stats_text(row: Dictionary) -> String:
	if row["cells"] < 0:
		return ""
	return "%d celdas · %s" % [row["cells"], row["share"]]


## Resumen de la nación del jugador para el HUD: "Confederación de Alba · 441 celdas · 1,6 %".
static func player_summary(rows: Array) -> String:
	for row: Dictionary in rows:
		if row["human"]:
			return "%s · %s" % [row["name"], row_stats_text(row)]
	return ""


func set_rows(new_rows: Array) -> void:
	_rows = new_rows
	custom_minimum_size = Vector2(COLUMNS * COLUMN_WIDTH, ceili(_rows.size() / float(COLUMNS)) * ROW_HEIGHT)
	queue_redraw()


@warning_ignore("integer_division")
func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Se rellena por columnas: las primeras filas a la izquierda, el resto a la derecha.
	var per_column := ceili(_rows.size() / float(COLUMNS))
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var origin := Vector2((i / per_column) * COLUMN_WIDTH, (i % per_column) * ROW_HEIGHT)
		var swatch := Rect2(origin + Vector2(0, 4), Vector2(SWATCH, SWATCH))
		draw_rect(swatch, row["color"])
		if row["human"]:
			draw_rect(swatch.grow(2), PLAYER_MARK_COLOR, false, 1.0)
		draw_string(font, origin + Vector2(SWATCH + 10, 16), row["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
		var stats := row_stats_text(row)
		if stats != "":
			draw_string(font, origin + Vector2(0, 16), stats, HORIZONTAL_ALIGNMENT_RIGHT, COLUMN_WIDTH - 12, FONT_SIZE - 2, MUTED_COLOR)
