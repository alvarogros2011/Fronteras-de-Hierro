## Ocupación militar provisional (hito 9): QUIÉN controla por la fuerza cada celda, separado de
## QUIÉN es su propietario oficial. Sin nodos ni dibujo.
##
## La propiedad oficial vive solo en TerritoryGrid. Este sistema nunca escribe en la cuadrícula:
## ocupar una celda no cambia su propietario ni su terreno. Por cada celda ocupada guarda el
## ocupante y el propietario oficial en el momento de ocuparla. Solo se ocupa tierra de OTRA nación
## (la tierra sin reclamar se conquista con TerritoryGrid.conquer_cells, nunca se ocupa).
##
## Coherencia: cuando la cuadrícula emite `ownership_changed`, se descartan las ocupaciones cuyo
## propietario oficial ya no es el que tenían (por ejemplo, la celda fue conquistada: por el propio
## ocupante, con lo que ya es suya, o por un tercero). Así una ocupación nunca queda obsoleta.
##
## Preparado para tratados de paz (no implementados): transferir las zonas ocupadas sería
## conquistar con el ocupante las celdas de `get_cells(ocupante)`; restaurar las fronteras previas
## a la guerra sería `release_all_of(ocupante)`. Ninguna de las dos ocurre sola.
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")

## Se emite tras cualquier cambio de ocupación (una vez por operación). No lleva datos.
signal changed
## Se emite con las celdas (Vector2i) cuya ocupación cambió: ocupadas, liberadas o descartadas.
## La vista las repinta con refresh_cell.
signal cells_changed(cells: Array)

const OCC_OK := 0
const OCC_ERR_UNKNOWN_OCCUPIER := 1
const OCC_ERR_OUT_OF_BOUNDS := 2
const OCC_ERR_NOT_LAND := 3
const OCC_ERR_NOT_ENEMY_LAND := 4  # sin reclamar o ya del propio ocupante

var _grid: TerritoryGrid
var _cells: Dictionary = {}  # Vector2i -> {"occupier": int, "owner": int}


func _init(grid: TerritoryGrid) -> void:
	_grid = grid
	_grid.ownership_changed.connect(_on_ownership_changed)


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

## Nación que ocupa la celda, u OWNER_NONE si nadie la ocupa.
func occupier_at(cell: Vector2i) -> int:
	return _cells[cell]["occupier"] if _cells.has(cell) else TerritoryGrid.OWNER_NONE


func is_occupied(cell: Vector2i) -> bool:
	return _cells.has(cell)


## Propietario oficial que tenía la celda al ser ocupada (OWNER_NONE si no está ocupada).
func official_owner_at(cell: Vector2i) -> int:
	return _cells[cell]["owner"] if _cells.has(cell) else TerritoryGrid.OWNER_NONE


## Celdas ocupadas, en orden de ocupación (por ocupante si se indica uno; si no, todas).
func get_cells(occupier_id: int = TerritoryGrid.INVALID) -> Array:
	var result: Array = []
	for cell: Vector2i in _cells:
		if occupier_id == TerritoryGrid.INVALID or _cells[cell]["occupier"] == occupier_id:
			result.append(cell)
	return result


## Número de celdas ocupadas (por ocupante si se indica uno).
func count(occupier_id: int = TerritoryGrid.INVALID) -> int:
	if occupier_id == TerritoryGrid.INVALID:
		return _cells.size()
	var total := 0
	for cell: Vector2i in _cells:
		if _cells[cell]["occupier"] == occupier_id:
			total += 1
	return total


## Celdas de la nación `owner_id` que están ocupadas por otra.
func count_taken_from(owner_id: int) -> int:
	var total := 0
	for cell: Vector2i in _cells:
		if _cells[cell]["owner"] == owner_id:
			total += 1
	return total


# ---------------------------------------------------------------------------
# Órdenes
# ---------------------------------------------------------------------------

## Comprueba, sin cambiar nada, si `occupier_id` puede ocupar la celda: nación existente, celda
## dentro del mapa, tierra y con propietario oficial distinto del ocupante y de «sin reclamar».
func validate(occupier_id: int, cell: Vector2i) -> int:
	if not _grid.has_nation(occupier_id):
		return OCC_ERR_UNKNOWN_OCCUPIER
	if not _grid.is_valid_coord(cell.x, cell.y):
		return OCC_ERR_OUT_OF_BOUNDS
	if not _grid.is_land(cell.x, cell.y):
		return OCC_ERR_NOT_LAND
	var owner_id := _grid.get_cell_owner(cell.x, cell.y)
	if owner_id == TerritoryGrid.OWNER_NONE or owner_id == occupier_id:
		return OCC_ERR_NOT_ENEMY_LAND
	return OCC_OK


## Ocupa la celda (si ya la ocupaba otra nación, pasa al nuevo ocupante). No toca la cuadrícula.
## Devuelve OCC_OK o el motivo del rechazo, sin cambiar nada.
func occupy(occupier_id: int, cell: Vector2i) -> int:
	var error := validate(occupier_id, cell)
	if error != OCC_OK:
		return error
	if _cells.has(cell) and _cells[cell]["occupier"] == occupier_id:
		return OCC_OK
	_cells[cell] = {"occupier": occupier_id, "owner": _grid.get_cell_owner(cell.x, cell.y)}
	cells_changed.emit([cell])
	changed.emit()
	return OCC_OK


## Libera la celda. Devuelve false, sin cambiar nada, si no estaba ocupada.
func release(cell: Vector2i) -> bool:
	if not _cells.has(cell):
		return false
	_cells.erase(cell)
	cells_changed.emit([cell])
	changed.emit()
	return true


## Libera todas las celdas que ocupa una nación (restaurar fronteras). Devuelve cuántas.
func release_all_of(occupier_id: int) -> int:
	var released: Array = get_cells(occupier_id)
	for cell: Vector2i in released:
		_cells.erase(cell)
	if not released.is_empty():
		cells_changed.emit(released)
		changed.emit()
	return released.size()


static func error_message(code: int) -> String:
	match code:
		OCC_OK:
			return "Celda ocupada."
		OCC_ERR_UNKNOWN_OCCUPIER:
			return "Nación desconocida."
		OCC_ERR_OUT_OF_BOUNDS:
			return "Fuera del mapa."
		OCC_ERR_NOT_LAND:
			return "Solo se ocupa tierra."
		OCC_ERR_NOT_ENEMY_LAND:
			return "Solo se ocupa tierra de otra nación."
	return "Error desconocido."


# ---------------------------------------------------------------------------
# Coherencia con el territorio
# ---------------------------------------------------------------------------

## Descarta las ocupaciones cuyo propietario oficial cambió. Devuelve cuántas descartó.
func prune_stale() -> int:
	var stale: Array = []
	for cell: Vector2i in _cells:
		if _grid.get_cell_owner(cell.x, cell.y) != _cells[cell]["owner"]:
			stale.append(cell)
	for cell: Vector2i in stale:
		_cells.erase(cell)
	if not stale.is_empty():
		cells_changed.emit(stale)
		changed.emit()
	return stale.size()


func _on_ownership_changed() -> void:
	prune_stale()
