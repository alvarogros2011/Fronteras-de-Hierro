## Organización militar (hito 8): sectores y asignación de soldados. Sin nodos ni dibujo.
##
## Un SECTOR es una orden de despliegue y planificación: una celda de origen del propio
## territorio, una dirección ortogonal (norte, este, sur u oeste), la celda objetivo contigua en
## esa dirección y una cifra de soldados asignados. El objetivo debe ser tierra SIN RECLAMAR o de
## OTRA nación (nunca una celda de la propia nación). NO es un combate: crear un sector o asignarle
## soldados no inicia una guerra, no mueve tropas y no cambia ninguna frontera. Este sistema nunca
## escribe en TerritoryGrid; el territorio solo cambia por TerritoryGrid.conquer_cells.
##
## Fuente de verdad de los soldados: Population. Aquí NO se guarda ningún contador nacional de
## soldados; el total es siempre Population.soldiers(nación). Lo único que se guarda es cuánto
## de ese total está asignado a cada sector. Reserva disponible = total - suma de asignados.
## Asignar o liberar soldados es un simple apunte: no crea ni elimina soldados, no toca a los
## trabajadores, no cuesta dinero ni recursos (el mantenimiento sigue dependiendo de los
## soldados nacionales) y la redistribución nunca causa bajas.
##
## Si el total de soldados baja por debajo de lo asignado (deserción por déficit u otro sistema
## de Population), se corrige de forma determinista al emitir Population `changed`: se quita
## exceso de los sectores de la nación EMPEZANDO POR EL MÁS NUEVO (id mayor) y se sigue con el
## anterior hasta cubrir el exceso; cada sector pierde como mucho lo que tiene. Los sectores no
## se eliminan por ello (pueden quedar en 0). Esos soldados no vuelven a la reserva: ya no
## existen en la población.
##
## Que el objetivo no sea propio se exige solo AL CREAR el sector: si más tarde cambia de dueño
## (por una conquista) el sector se conserva y el panel lo muestra como territorio propio.
##
## Si el origen de un sector deja de ser de su nación (conquista), el sector se elimina al
## emitir TerritoryGrid `ownership_changed` y sus soldados vuelven a la reserva.
##
## Ampliación prevista (no implementada): un sector apuntará a varias celdas contiguas (frente
## más ancho); hoy "target" es una sola celda y se guarda aparte del origen y la dirección para
## poder sustituirla por una lista sin cambiar el resto. Combate, avance y ocupación son de
## hitos posteriores. Ni IA ni multijugador crean sectores todavía.
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Population := preload("res://scripts/world/population.gd")

## Se emite tras cualquier cambio en los sectores o en su asignación. No lleva datos.
signal changed

## Direcciones ortogonales (también índices de DIRECTION_STEPS y DIRECTION_NAMES).
const DIR_NORTH := 0
const DIR_EAST := 1
const DIR_SOUTH := 2
const DIR_WEST := 3
const DIRECTION_STEPS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIRECTION_NAMES: Array[String] = ["Norte", "Este", "Sur", "Oeste"]
const DIRECTION_SHORT_NAMES: Array[String] = ["N", "E", "S", "O"]

const NO_SECTOR := -1

const SECTOR_OK := 0
const SECTOR_ERR_UNKNOWN_NATION := 1
const SECTOR_ERR_BAD_DIRECTION := 2
const SECTOR_ERR_ORIGIN_OUT_OF_BOUNDS := 3
const SECTOR_ERR_ORIGIN_NOT_OWNED := 4  # la celda de origen no es de la nación (incluye el agua)
const SECTOR_ERR_TARGET_OUT_OF_BOUNDS := 5
const SECTOR_ERR_TARGET_WATER := 6
const SECTOR_ERR_DUPLICATE := 7  # ya hay un sector con ese origen y esa dirección
const SECTOR_ERR_TARGET_OWN := 8  # el objetivo ya es territorio de la propia nación
const SECTOR_ERR_SOLDIERS_NEGATIVE := 9  # cantidad inicial de soldados negativa
const SECTOR_ERR_SOLDIERS_NOT_ENOUGH := 10  # la cantidad inicial supera la reserva disponible

const ASSIGN_OK := 0
const ASSIGN_ERR_UNKNOWN_SECTOR := 1
const ASSIGN_ERR_NEGATIVE := 2  # cantidad negativa, o un ajuste que dejaría el sector por debajo de 0
const ASSIGN_ERR_NOT_ENOUGH := 3  # no hay tantos soldados disponibles en la reserva

var _grid: TerritoryGrid
var _population: Population
var _sectors: Dictionary = {}  # id -> {"id", "owner", "origin", "direction", "target", "soldiers"}
var _next_id: int = 1


func _init(grid: TerritoryGrid, population: Population) -> void:
	_grid = grid
	_population = population
	_population.changed.connect(_on_population_changed)
	_grid.ownership_changed.connect(_on_ownership_changed)


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func sector_count() -> int:
	return _sectors.size()


func has_sector(sector_id: int) -> bool:
	return _sectors.has(sector_id)


## IDs de los sectores de la nación, en orden de creación (todas las naciones si nation_id es
## TerritoryGrid.INVALID).
func get_sector_ids(nation_id: int = TerritoryGrid.INVALID) -> Array:
	var ids: Array = []
	for sector_id: int in _sectors:
		if nation_id == TerritoryGrid.INVALID or _sectors[sector_id]["owner"] == nation_id:
			ids.append(sector_id)
	return ids


## Copia de los datos de un sector (vacío si no existe): id, owner, origin, direction, target y
## soldiers. Modificarla no afecta al sector.
func get_sector(sector_id: int) -> Dictionary:
	return _sectors[sector_id].duplicate() if _sectors.has(sector_id) else {}


## ID del sector con ese origen y esa dirección, o NO_SECTOR.
func sector_at(origin: Vector2i, direction: int) -> int:
	for sector_id: int in _sectors:
		var sector: Dictionary = _sectors[sector_id]
		if sector["origin"] == origin and sector["direction"] == direction:
			return sector_id
	return NO_SECTOR


## Soldados totales de la nación: los de Population (-1 si la nación no existe).
func total_soldiers(nation_id: int) -> int:
	return _population.soldiers(nation_id)


## Soldados asignados a sectores de la nación (0 si no tiene sectores o no existe).
func assigned_soldiers(nation_id: int) -> int:
	var total := 0
	for sector_id: int in _sectors:
		if _sectors[sector_id]["owner"] == nation_id:
			total += _sectors[sector_id]["soldiers"]
	return total


## Reserva: soldados de la nación sin asignar a ningún sector (-1 si la nación no existe).
## Nunca es negativa.
func available_soldiers(nation_id: int) -> int:
	if not _population.has_nation(nation_id):
		return -1
	return maxi(0, _population.soldiers(nation_id) - assigned_soldiers(nation_id))


## Resumen {"total", "assigned", "available"} de la nación (vacío si no existe).
func get_summary(nation_id: int) -> Dictionary:
	if not _population.has_nation(nation_id):
		return {}
	return {
		"total": total_soldiers(nation_id),
		"assigned": assigned_soldiers(nation_id),
		"available": available_soldiers(nation_id),
	}


## Propietario ACTUAL de la celda objetivo del sector (OWNER_NONE si no está reclamada;
## TerritoryGrid.INVALID si el sector no existe). Se lee de la cuadrícula, no se guarda.
func target_owner(sector_id: int) -> int:
	if not _sectors.has(sector_id):
		return TerritoryGrid.INVALID
	var target: Vector2i = _sectors[sector_id]["target"]
	return _grid.get_cell_owner(target.x, target.y)


## Celda contigua a `origin` en la dirección dada (sin validar nada).
static func target_cell(origin: Vector2i, direction: int) -> Vector2i:
	return origin + DIRECTION_STEPS[direction]


# ---------------------------------------------------------------------------
# Validación y órdenes
# ---------------------------------------------------------------------------

## Comprueba, sin cambiar nada, si se podría crear un sector con `soldiers` soldados iniciales.
## Devuelve SECTOR_OK o el primer motivo de rechazo (SECTOR_ERR_*), en este orden: nación,
## dirección, origen dentro del mapa, origen propio, objetivo dentro del mapa, objetivo tierra,
## objetivo no propio, sector duplicado, soldados no negativos, soldados dentro de la reserva.
## El objetivo puede ser tierra sin reclamar o de otra nación: preparar un sector no inicia
## ninguna guerra ni exige nada diplomático.
func validate_sector(nation_id: int, origin: Vector2i, direction: int, soldiers: int = 0) -> int:
	if not _population.has_nation(nation_id):
		return SECTOR_ERR_UNKNOWN_NATION
	if direction < DIR_NORTH or direction > DIR_WEST:
		return SECTOR_ERR_BAD_DIRECTION
	if not _grid.is_valid_coord(origin.x, origin.y):
		return SECTOR_ERR_ORIGIN_OUT_OF_BOUNDS
	if _grid.get_cell_owner(origin.x, origin.y) != nation_id:
		return SECTOR_ERR_ORIGIN_NOT_OWNED
	var target := target_cell(origin, direction)
	if not _grid.is_valid_coord(target.x, target.y):
		return SECTOR_ERR_TARGET_OUT_OF_BOUNDS
	if not _grid.is_land(target.x, target.y):
		return SECTOR_ERR_TARGET_WATER
	if _grid.get_cell_owner(target.x, target.y) == nation_id:
		return SECTOR_ERR_TARGET_OWN
	if sector_at(origin, direction) != NO_SECTOR:
		return SECTOR_ERR_DUPLICATE
	if soldiers < 0:
		return SECTOR_ERR_SOLDIERS_NEGATIVE
	if soldiers > available_soldiers(nation_id):
		return SECTOR_ERR_SOLDIERS_NOT_ENOUGH
	return SECTOR_OK


## Crea un sector con `soldiers` soldados iniciales (0 = vacío) en una sola operación atómica:
## se valida todo antes de tocar nada, así que o se crea el sector ya con su asignación o no
## cambia nada (nunca queda un sector vacío a medias). Emite changed una sola vez. Devuelve
## {"ok": bool, "error": int, "id": int}; si falla, id es NO_SECTOR. Los ids son estables y no se
## reutilizan.
func create_sector(nation_id: int, origin: Vector2i, direction: int, soldiers: int = 0) -> Dictionary:
	var error := validate_sector(nation_id, origin, direction, soldiers)
	if error != SECTOR_OK:
		return {"ok": false, "error": error, "id": NO_SECTOR}
	var sector_id := _next_id
	_next_id += 1
	_sectors[sector_id] = {
		"id": sector_id,
		"owner": nation_id,
		"origin": origin,
		"direction": direction,
		"target": target_cell(origin, direction),
		"soldiers": soldiers,
	}
	changed.emit()
	return {"ok": true, "error": SECTOR_OK, "id": sector_id}


## Fija los soldados asignados al sector (aumenta o reduce). Aumentar toma de la reserva y reducir
## devuelve a ella; el total de la nación no cambia. Devuelve ASSIGN_OK o el motivo (ASSIGN_ERR_*)
## sin cambiar nada: sector inexistente, cantidad negativa o más de los que hay disponibles.
func set_sector_soldiers(sector_id: int, amount: int) -> int:
	if not _sectors.has(sector_id):
		return ASSIGN_ERR_UNKNOWN_SECTOR
	if amount < 0:
		return ASSIGN_ERR_NEGATIVE
	var sector: Dictionary = _sectors[sector_id]
	var increase: int = amount - sector["soldiers"]
	if increase > available_soldiers(sector["owner"]):
		return ASSIGN_ERR_NOT_ENOUGH
	if increase != 0:
		sector["soldiers"] = amount
		changed.emit()
	return ASSIGN_OK


## Suma `delta` (positivo o negativo) a la asignación del sector, con las mismas reglas que
## set_sector_soldiers; un delta que dejaría el sector por debajo de 0 es ASSIGN_ERR_NEGATIVE.
func adjust_sector_soldiers(sector_id: int, delta: int) -> int:
	if not _sectors.has(sector_id):
		return ASSIGN_ERR_UNKNOWN_SECTOR
	var amount: int = _sectors[sector_id]["soldiers"] + delta
	if amount < 0:
		return ASSIGN_ERR_NEGATIVE
	return set_sector_soldiers(sector_id, amount)


## Retira todos los soldados del sector y lo elimina: vuelven a la reserva, no desaparecen de la
## población ni son bajas. Devuelve false, sin cambiar nada, si el sector no existe.
func remove_sector(sector_id: int) -> bool:
	if not _sectors.has(sector_id):
		return false
	_sectors.erase(sector_id)
	changed.emit()
	return true


static func sector_error_message(code: int) -> String:
	match code:
		SECTOR_OK:
			return "Sector creado."
		SECTOR_ERR_UNKNOWN_NATION:
			return "Nación desconocida."
		SECTOR_ERR_BAD_DIRECTION:
			return "Dirección no válida."
		SECTOR_ERR_ORIGIN_OUT_OF_BOUNDS:
			return "El origen está fuera del mapa."
		SECTOR_ERR_ORIGIN_NOT_OWNED:
			return "El origen debe ser una celda de tu territorio."
		SECTOR_ERR_TARGET_OUT_OF_BOUNDS:
			return "El objetivo cae fuera del mapa."
		SECTOR_ERR_TARGET_WATER:
			return "El objetivo es agua."
		SECTOR_ERR_DUPLICATE:
			return "Ya hay un sector con ese origen y esa dirección."
		SECTOR_ERR_TARGET_OWN:
			return "El objetivo debe ser tierra sin reclamar o de otra nación."
		SECTOR_ERR_SOLDIERS_NEGATIVE:
			return "La cantidad de soldados no puede ser negativa."
		SECTOR_ERR_SOLDIERS_NOT_ENOUGH:
			return "No hay tantos soldados disponibles."
	return "Error desconocido."


static func assign_error_message(code: int) -> String:
	match code:
		ASSIGN_OK:
			return "Asignación actualizada."
		ASSIGN_ERR_UNKNOWN_SECTOR:
			return "El sector no existe."
		ASSIGN_ERR_NEGATIVE:
			return "No se puede bajar de 0 soldados."
		ASSIGN_ERR_NOT_ENOUGH:
			return "No quedan soldados disponibles."
	return "Error desconocido."


# ---------------------------------------------------------------------------
# Coherencia con los otros sistemas
# ---------------------------------------------------------------------------

## Recorta lo asignado de cada nación a sus soldados reales (ver regla en la cabecera) y devuelve
## cuántos soldados asignados se quitaron en total. Se llama sola tras cada cambio de Population;
## es público para poder probarlo y es idempotente.
func enforce_soldier_limits() -> int:
	var removed := 0
	var nation_ids: Array = []
	for sector_id: int in _sectors:
		if not nation_ids.has(_sectors[sector_id]["owner"]):
			nation_ids.append(_sectors[sector_id]["owner"])
	for nation_id: int in nation_ids:
		var excess := assigned_soldiers(nation_id) - maxi(0, _population.soldiers(nation_id))
		if excess <= 0:
			continue
		var ids := get_sector_ids(nation_id)
		ids.reverse()  # el más nuevo primero
		for sector_id: int in ids:
			if excess <= 0:
				break
			var cut := mini(excess, _sectors[sector_id]["soldiers"])
			_sectors[sector_id]["soldiers"] -= cut
			excess -= cut
			removed += cut
	return removed


## Elimina los sectores cuyo origen ya no pertenece a su nación. Devuelve cuántos eliminó.
func prune_lost_sectors() -> int:
	var lost: Array = []
	for sector_id: int in _sectors:
		var origin: Vector2i = _sectors[sector_id]["origin"]
		if _grid.get_cell_owner(origin.x, origin.y) != _sectors[sector_id]["owner"]:
			lost.append(sector_id)
	for sector_id: int in lost:
		_sectors.erase(sector_id)
	return lost.size()


func _on_population_changed() -> void:
	if enforce_soldier_limits() > 0:
		changed.emit()


func _on_ownership_changed() -> void:
	if prune_lost_sectors() > 0:
		changed.emit()
