## Ciudades (hito 6): datos, fundación, crecimiento y producción. Sin nodos ni dibujo.
##
## Capas: la cuadrícula (TerritoryGrid) sigue siendo la única autoridad de terreno y propietario;
## las ciudades NO guardan propietario ni terreno propios. El propietario de una ciudad es el de
## la celda donde está su centro, así que si esa celda cambia de dueño (conquista) la ciudad
## cambia de dueño sola y no puede quedar desincronizada. Si el centro no tiene propietario
## (OWNER_NONE), la ciudad queda inactiva: ni crece ni produce. Las ciudades no se destruyen.
## TerritoryGrid no conoce las ciudades, y las ciudades nunca escriben en la cuadrícula:
## crecer es solo visual y no conquista nada.
##
## Datos guardados por ciudad: id (estable, nunca se reutiliza), celda del centro, nivel y
## progreso de crecimiento. Todo lo demás se deriva. Valores de equilibrio: economy_balance.gd.
##
## Ocupación (hito 9): si el centro de una ciudad está ocupado por otra nación (Occupation, opcional),
## la ciudad SUSPENDE su producción de dinero y recursos mientras dure la ocupación (regla provisional):
## no se transfiere al ocupante ni la cobra su dueño. Su propietario sigue siendo el oficial (la
## cuadrícula) y su crecimiento de nivel continúa. Al terminar la ocupación la producción se reanuda
## sola. Tampoco se puede fundar una ciudad en una celda ocupada.
##
## Tiempo: advance(delta) acumula segundos y ejecuta ticks fijos de TICK_SECONDS, de modo que
## el resultado depende del tiempo transcurrido y no del número de fotogramas.
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Economy := preload("res://scripts/world/economy.gd")
const Occupation := preload("res://scripts/world/occupation.gd")
const Balance := preload("res://scripts/data/economy_balance.gd")

## Se emite al fundar una ciudad, al subir de nivel y al recolocar las iniciales.
## La vista la usa para redibujar; no lleva datos.
signal changed
## Se emite al final de cada tick de simulación, ya pagada la producción. Es el reloj único del
## que cuelgan otros sistemas (población, mantenimiento) para avanzar en el mismo paso fijo.
signal ticked

const FOUND_OK := 0
const FOUND_ERR_UNKNOWN_NATION := 1
const FOUND_ERR_OUT_OF_BOUNDS := 2
const FOUND_ERR_NOT_LAND := 3
const FOUND_ERR_NOT_OWNED := 4  # la celda no pertenece a la nación que funda
const FOUND_ERR_OCCUPIED := 5  # ya hay una ciudad exactamente ahí
const FOUND_ERR_TOO_CLOSE := 6
const FOUND_ERR_NO_FUNDS := 7
const FOUND_ERR_ENEMY_OCCUPATION := 8  # la celda es propia pero está ocupada por otra nación

const NO_CITY := -1

var _grid: TerritoryGrid
var _economy: Economy
var _occupation: Occupation = null
var _cities: Dictionary = {}  # id -> {"id", "cell", "level", "progress"}
var _by_cell: Dictionary = {}  # Vector2i del centro -> id
var _next_id: int = 1
var _accumulator: float = 0.0


func _init(grid: TerritoryGrid, economy: Economy) -> void:
	_grid = grid
	_economy = economy


## Conecta la ocupación (hito 9). Los cambios de ocupación emiten `changed`: la producción y el
## dibujo de las ciudades dependen de ella. Se llama una sola vez, al montar la partida.
func set_occupation(occupation: Occupation) -> void:
	_occupation = occupation
	if _occupation != null:
		_occupation.changed.connect(_on_occupation_changed)


func _on_occupation_changed() -> void:
	changed.emit()


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func city_count() -> int:
	return _cities.size()


## IDs de todas las ciudades, en orden de creación.
func get_city_ids() -> Array:
	return _cities.keys()


func has_city(city_id: int) -> bool:
	return _cities.has(city_id)


## ¿Está ocupado por otra nación el centro de la ciudad? (producción suspendida; false si no existe)
func is_occupied(city_id: int) -> bool:
	if not _cities.has(city_id) or _occupation == null:
		return false
	return _occupation.is_occupied(_cities[city_id]["cell"])


## Nación propietaria de la ciudad (la de su celda central), o INVALID si la ciudad no existe.
func get_owner(city_id: int) -> int:
	if not _cities.has(city_id):
		return TerritoryGrid.INVALID
	var cell: Vector2i = _cities[city_id]["cell"]
	return _grid.get_cell_owner(cell.x, cell.y)


## Copia de los datos de una ciudad (vacío si no existe): id, owner, cell, level, progress,
## needed (puntos para el siguiente nivel; 0 en el nivel máximo), money_rate y resource_rate
## (por tick; 0 mientras la ciudad está ocupada) y occupied. Modificarla no afecta a la ciudad.
func get_city(city_id: int) -> Dictionary:
	if not _cities.has(city_id):
		return {}
	var city: Dictionary = _cities[city_id]
	var level: int = city["level"]
	var occupied := is_occupied(city_id)
	return {
		"id": city_id,
		"owner": get_owner(city_id),
		"cell": city["cell"],
		"level": level,
		"progress": city["progress"],
		"needed": growth_needed(level),
		"money_rate": 0 if occupied else Balance.MONEY_PER_TICK[level],
		"resource_rate": 0 if occupied else Balance.RESOURCES_PER_TICK[level],
		"occupied": occupied,
	}


## ID de la ciudad cuyo centro está exactamente en la celda, o NO_CITY.
func city_id_at(cell: Vector2i) -> int:
	return _by_cell.get(cell, NO_CITY)


## ID de la ciudad cuya mancha visible (visual_cells) contiene la celda, o NO_CITY.
func city_covering(cell: Vector2i) -> int:
	for city_id: int in _cities:
		if visual_cells(city_id).has(cell):
			return city_id
	return NO_CITY


## Puntos de crecimiento para pasar de `level` al siguiente; 0 si es el nivel máximo.
static func growth_needed(level: int) -> int:
	return 0 if level >= Balance.MAX_LEVEL else Balance.GROWTH_TO_NEXT[level]


## Producción por tick de todas las ciudades activas de la nación: {"money": int, "resources": int}.
## Las ciudades ocupadas no producen.
func income_for(nation_id: int) -> Dictionary:
	var money := 0
	var resources := 0
	for city_id: int in _cities:
		if get_owner(city_id) == nation_id and not is_occupied(city_id):
			var level: int = _cities[city_id]["level"]
			money += Balance.MONEY_PER_TICK[level]
			resources += Balance.RESOURCES_PER_TICK[level]
	return {"money": money, "resources": resources}


func count_owned_by(nation_id: int) -> int:
	var total := 0
	for city_id: int in _cities:
		if get_owner(city_id) == nation_id:
			total += 1
	return total


## Celdas que se dibujan de la ciudad: las de distancia Manhattan <= radio de su nivel al centro
## que además sean tierra de la nación propietaria. Así nunca se pinta fuera de su territorio ni
## se confunde con una expansión. Ciudad inexistente o sin propietario: lista vacía.
func visual_cells(city_id: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var owner_id := get_owner(city_id)
	if owner_id == TerritoryGrid.INVALID or owner_id == TerritoryGrid.OWNER_NONE:
		return cells
	var center: Vector2i = _cities[city_id]["cell"]
	var radius: int = Balance.VISUAL_RADIUS[_cities[city_id]["level"]]
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if absi(dx) + absi(dy) > radius:
				continue
			var x := center.x + dx
			var y := center.y + dy
			if _grid.is_land(x, y) and _grid.get_cell_owner(x, y) == owner_id:
				cells.append(Vector2i(x, y))
	return cells


static func error_message(code: int) -> String:
	match code:
		FOUND_OK:
			return "Ciudad fundada."
		FOUND_ERR_UNKNOWN_NATION:
			return "Nación desconocida."
		FOUND_ERR_OUT_OF_BOUNDS:
			return "Fuera del mapa."
		FOUND_ERR_NOT_LAND:
			return "Solo se puede fundar en tierra."
		FOUND_ERR_NOT_OWNED:
			return "La celda no es de tu territorio."
		FOUND_ERR_OCCUPIED:
			return "Ya hay una ciudad ahí."
		FOUND_ERR_TOO_CLOSE:
			return "Demasiado cerca de otra ciudad (mínimo %d celdas)." % Balance.MIN_CITY_DISTANCE
		FOUND_ERR_NO_FUNDS:
			return "Dinero insuficiente (cuesta %d)." % Balance.FOUND_COST
		FOUND_ERR_ENEMY_OCCUPATION:
			return "La celda está ocupada por otra nación."
	return "Error desconocido."


# ---------------------------------------------------------------------------
# Ciudades iniciales
# ---------------------------------------------------------------------------

## Borra las ciudades y coloca una de nivel 1 por nación con territorio, sin coste. Sitio
## preferido: el punto central de TerritoryGrid.START_SITES. Si no sirve (no es tierra de la
## nación), se toma la primera celda válida buscando por anillos crecientes alrededor de él
## (de arriba abajo y de izquierda a derecha dentro de cada anillo). Una nación sin celdas
## válidas se queda sin ciudad. Devuelve cuántas se crearon. No se llama a sí misma.
func place_initial_cities() -> int:
	_cities = {}
	_by_cell = {}
	_next_id = 1
	_accumulator = 0.0
	for nation_id: int in _grid.get_nation_ids():
		var site: Vector2i = TerritoryGrid.START_SITES[nation_id]["seed"] if TerritoryGrid.START_SITES.has(nation_id) else Vector2i.ZERO
		var cell := _find_initial_cell(nation_id, site)
		if cell != Vector2i(TerritoryGrid.INVALID, TerritoryGrid.INVALID):
			_create_city(cell)
	changed.emit()
	return _cities.size()


func _find_initial_cell(nation_id: int, site: Vector2i) -> Vector2i:
	var none := Vector2i(TerritoryGrid.INVALID, TerritoryGrid.INVALID)
	if _is_valid_initial_cell(nation_id, site):
		return site
	for ring in range(1, maxi(_grid.get_width(), _grid.get_height())):
		# Perímetro del anillo: fila superior, laterales de arriba abajo y fila inferior.
		for dy in range(-ring, ring + 1):
			var step := 1 if absi(dy) == ring else 2 * ring
			for dx in range(-ring, ring + 1, step):
				var cell := site + Vector2i(dx, dy)
				if _is_valid_initial_cell(nation_id, cell):
					return cell
	return none


func _is_valid_initial_cell(nation_id: int, cell: Vector2i) -> bool:
	return _grid.is_land(cell.x, cell.y) and _grid.get_cell_owner(cell.x, cell.y) == nation_id \
			and not _is_too_close(cell)


# ---------------------------------------------------------------------------
# Fundación
# ---------------------------------------------------------------------------

## Comprueba si `nation_id` puede fundar una ciudad en `cell` sin cambiar nada. Devuelve FOUND_OK
## o el primer error, en este orden: nación, límites, tierra, propiedad, ocupación enemiga,
## ciudad existente, distancia mínima y dinero.
func check_founding(nation_id: int, cell: Vector2i) -> int:
	if not _grid.has_nation(nation_id):
		return FOUND_ERR_UNKNOWN_NATION
	if not _grid.is_valid_coord(cell.x, cell.y):
		return FOUND_ERR_OUT_OF_BOUNDS
	if not _grid.is_land(cell.x, cell.y):
		return FOUND_ERR_NOT_LAND
	if _grid.get_cell_owner(cell.x, cell.y) != nation_id:
		return FOUND_ERR_NOT_OWNED
	if _occupation != null and _occupation.is_occupied(cell):
		return FOUND_ERR_ENEMY_OCCUPATION
	if _by_cell.has(cell):
		return FOUND_ERR_OCCUPIED
	if _is_too_close(cell):
		return FOUND_ERR_TOO_CLOSE
	if not _economy.can_afford(nation_id, Balance.FOUND_COST):
		return FOUND_ERR_NO_FUNDS
	return FOUND_OK


## Funda una ciudad de nivel 1 para la nación en la celda, cobrando FOUND_COST. Solo cobra y crea
## si todas las reglas se cumplen; si no, no cambia nada (ni dinero, ni ciudades, ni territorio).
## Devuelve {"ok": bool, "error": int (FOUND_*), "city_id": int (NO_CITY si falló)}.
func found_city(nation_id: int, cell: Vector2i) -> Dictionary:
	var error := check_founding(nation_id, cell)
	if error != FOUND_OK:
		return {"ok": false, "error": error, "city_id": NO_CITY}
	if not _economy.spend_money(nation_id, Balance.FOUND_COST):
		return {"ok": false, "error": FOUND_ERR_NO_FUNDS, "city_id": NO_CITY}
	var city_id := _create_city(cell)
	changed.emit()
	return {"ok": true, "error": FOUND_OK, "city_id": city_id}


## Distancia Chebyshev a alguna ciudad existente menor que MIN_CITY_DISTANCE (cualquier nación).
func _is_too_close(cell: Vector2i) -> bool:
	for city_id: int in _cities:
		var other: Vector2i = _cities[city_id]["cell"]
		if maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < Balance.MIN_CITY_DISTANCE:
			return true
	return false


func _create_city(cell: Vector2i) -> int:
	var city_id := _next_id
	_next_id += 1
	_cities[city_id] = {"id": city_id, "cell": cell, "level": 1, "progress": 0}
	_by_cell[cell] = city_id
	return city_id


# ---------------------------------------------------------------------------
# Tiempo: crecimiento y producción
# ---------------------------------------------------------------------------

## Avanza la simulación `delta` segundos de juego (delta <= 0 se ignora). Ejecuta tantos ticks
## completos como quepan y guarda el resto. Devuelve cuántos ticks se ejecutaron.
func advance(delta: float) -> int:
	if delta <= 0.0:
		return 0
	_accumulator += delta
	var ticks := 0
	while _accumulator >= Balance.TICK_SECONDS:
		_accumulator -= Balance.TICK_SECONDS
		_tick()
		ticks += 1
	return ticks


## Un tick: cada ciudad con propietario (y sin ocupar) produce para él, y todas ganan crecimiento (subiendo de nivel
## al alcanzar el umbral; el sobrante de progreso se conserva). Nunca toca la cuadrícula.
func _tick() -> void:
	var money := {}
	var resources := {}
	var leveled := false
	for city_id: int in _cities:
		var owner_id := get_owner(city_id)
		if owner_id == TerritoryGrid.OWNER_NONE or owner_id == TerritoryGrid.INVALID:
			continue
		var city: Dictionary = _cities[city_id]
		var level: int = city["level"]
		if not is_occupied(city_id):
			money[owner_id] = money.get(owner_id, 0) + Balance.MONEY_PER_TICK[level]
			resources[owner_id] = resources.get(owner_id, 0) + Balance.RESOURCES_PER_TICK[level]
		if level < Balance.MAX_LEVEL:
			city["progress"] += Balance.GROWTH_PER_TICK
			while city["level"] < Balance.MAX_LEVEL and city["progress"] >= growth_needed(city["level"]):
				city["progress"] -= growth_needed(city["level"])
				city["level"] += 1
				leveled = true
			if city["level"] >= Balance.MAX_LEVEL:
				city["progress"] = 0
	for owner_id: int in money:
		_economy.add(owner_id, money[owner_id], resources[owner_id])
	if leveled:
		changed.emit()
	ticked.emit()
