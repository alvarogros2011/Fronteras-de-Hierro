## Cuadrícula de territorio: única fuente autoritativa de terreno y propietario por celda.
## Sin nodos ni dibujo: solo datos y reglas, para poder probarlos sin interfaz.
##
## Indexación (única y estable): orden por filas, empezando arriba a la izquierda.
##   index = y * WIDTH + x      x = index % WIDTH      y = index / WIDTH
## con x en [0, WIDTH) e y en [0, HEIGHT). Todo se guarda en dos PackedByteArray
## de WIDTH * HEIGHT elementos: uno de terreno y otro de propietario.
##
## Las fronteras no se guardan: surgirán de comparar el propietario de celdas
## adyacentes cuando exista la representación visual.
##
## Mapa inicial (determinista, sin azar, solo aritmética entera):
##   1. Masa de tierra: elipse centrada en el mapa. El interior (núcleo) es siempre
##      tierra; el borde exterior se irregulariza con dos capas de ruido de valores
##      (retícula gruesa y fina, generada con una función hash entera fija).
##      Las celdas del borde del mapa son siempre agua.
##   2. Se conserva solo la mayor masa de tierra conectada (4 vecinos); el resto pasa a agua.
##   3. Cada nación recibe un círculo de celdas alrededor de un punto fijo del núcleo,
##      y se descartan las celdas que no estén conectadas con ese punto. El resto
##      de la tierra queda sin reclamar.
extends RefCounted

const WIDTH := 320
const HEIGHT := 180
const CELL_COUNT := WIDTH * HEIGHT

const TERRAIN_WATER := 0
const TERRAIN_LAND := 1

const OWNER_NONE := 0
const OWNER_PLAYER := 1
const OWNER_AI_1 := 2
const OWNER_AI_2 := 3
const OWNER_AI_3 := 4

## Valor devuelto por las consultas con coordenadas o índice fuera de límites.
const INVALID := -1

## Códigos de resultado de conquer_cells (campo "error" del resultado).
const ORTHOGONAL_STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const CONQUEST_OK := 0
const CONQUEST_ERR_UNKNOWN_ATTACKER := 1  # no es una nación existente (OWNER_NONE tampoco vale)
const CONQUEST_ERR_EMPTY := 2  # lista de celdas vacía
const CONQUEST_ERR_INVALID_DATA := 3  # un elemento de la lista no es un Vector2i
const CONQUEST_ERR_OUT_OF_BOUNDS := 4
const CONQUEST_ERR_DUPLICATE := 5
const CONQUEST_ERR_WATER := 6
const CONQUEST_ERR_ALREADY_OWNED := 7  # la celda ya es del atacante
const CONQUEST_ERR_NOT_CONTIGUOUS := 8  # la zona no es una sola pieza (vecinos ortogonales)
const CONQUEST_ERR_NO_CONTACT := 9  # la zona no toca ortogonalmente territorio del atacante

## Metadatos de las naciones, indexados por su ID numérico estable.
## "key" es el ID textual estable; los nombres son provisionales.
const NATIONS: Dictionary = {
	OWNER_PLAYER: {"id": OWNER_PLAYER, "key": "player", "name": "Confederación de Alba", "color": Color(0.25, 0.55, 0.90)},
	OWNER_AI_1: {"id": OWNER_AI_1, "key": "ai_1", "name": "Reino de Cobre", "color": Color(0.85, 0.30, 0.30)},
	OWNER_AI_2: {"id": OWNER_AI_2, "key": "ai_2", "name": "República de Bruma", "color": Color(0.90, 0.75, 0.25)},
	OWNER_AI_3: {"id": OWNER_AI_3, "key": "ai_3", "name": "Imperio de Ceniza", "color": Color(0.70, 0.45, 0.85)},
}

## Territorio inicial de cada nación: punto central y radio (en celdas).
const START_SITES: Dictionary = {
	OWNER_PLAYER: {"seed": Vector2i(108, 114), "radius": 12},
	OWNER_AI_1: {"seed": Vector2i(108, 66), "radius": 12},
	OWNER_AI_2: {"seed": Vector2i(212, 66), "radius": 12},
	OWNER_AI_3: {"seed": Vector2i(212, 114), "radius": 12},
}

# Parámetros de la masa de tierra. Las distancias a la elipse se miden en milésimas
# (1000 = justo en el borde de la elipse nominal).
const LAND_CENTER := Vector2i(160, 90)
const LAND_SEMI_AXES := Vector2i(125, 68)
const CORE_LIMIT := 600
const FAR_LIMIT := 1400
const COAST_BASE := 1000
const COARSE_SPACING := 24
const COARSE_AMPLITUDE := 250
const COARSE_SALT := 11
const FINE_SPACING := 10
const FINE_AMPLITUDE := 150
const FINE_SALT := 23

var _terrain: PackedByteArray = PackedByteArray()
var _owner: PackedByteArray = PackedByteArray()


func _init() -> void:
	reset_to_default()


## Reconstruye el mapa inicial por defecto. Siempre produce el mismo resultado.
func reset_to_default() -> void:
	_terrain = PackedByteArray()
	_terrain.resize(CELL_COUNT)
	_terrain.fill(TERRAIN_WATER)
	_owner = PackedByteArray()
	_owner.resize(CELL_COUNT)
	_owner.fill(OWNER_NONE)
	_generate_landmass()
	_keep_largest_land_component()
	_claim_start_territories()


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func get_width() -> int:
	return WIDTH


func get_height() -> int:
	return HEIGHT


func is_valid_coord(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT


func is_valid_index(index: int) -> bool:
	return index >= 0 and index < CELL_COUNT


## Índice lineal de (x, y), o INVALID si está fuera de límites.
func coord_to_index(x: int, y: int) -> int:
	if not is_valid_coord(x, y):
		return INVALID
	return y * WIDTH + x


## Coordenadas de un índice lineal, o Vector2i(-1, -1) si está fuera de límites.
@warning_ignore("integer_division")
func index_to_coord(index: int) -> Vector2i:
	if not is_valid_index(index):
		return Vector2i(INVALID, INVALID)
	return Vector2i(index % WIDTH, index / WIDTH)


## TERRAIN_WATER o TERRAIN_LAND; INVALID si (x, y) está fuera de límites.
func get_cell_terrain(x: int, y: int) -> int:
	if not is_valid_coord(x, y):
		return INVALID
	return _terrain[y * WIDTH + x]


## ID de la nación propietaria (OWNER_NONE si nadie); INVALID si está fuera de límites.
func get_cell_owner(x: int, y: int) -> int:
	if not is_valid_coord(x, y):
		return INVALID
	return _owner[y * WIDTH + x]


## Igual que get_cell_terrain pero con índice lineal (útil para recorrer todo el mapa).
func terrain_at(index: int) -> int:
	if not is_valid_index(index):
		return INVALID
	return _terrain[index]


## Igual que get_cell_owner pero con índice lineal.
func owner_at(index: int) -> int:
	if not is_valid_index(index):
		return INVALID
	return _owner[index]


func is_land(x: int, y: int) -> bool:
	return get_cell_terrain(x, y) == TERRAIN_LAND


func has_nation(nation_id: int) -> bool:
	return NATIONS.has(nation_id)


## Metadatos de la nación (id, key, name, color), o un Dictionary vacío si no existe.
func get_nation(nation_id: int) -> Dictionary:
	if not NATIONS.has(nation_id):
		return {}
	return NATIONS[nation_id]


## IDs de todas las naciones, en orden estable.
func get_nation_ids() -> Array:
	return NATIONS.keys()


## ID numérico de la nación con ese ID textual, o INVALID si no existe.
func get_nation_id_by_key(key: String) -> int:
	for nation_id: int in NATIONS:
		if NATIONS[nation_id]["key"] == key:
			return nation_id
	return INVALID


## Número de celdas del propietario dado (OWNER_NONE cuenta también el agua). Recorre todo el mapa.
func count_owned_by(owner_id: int) -> int:
	var total := 0
	for index in CELL_COUNT:
		if _owner[index] == owner_id:
			total += 1
	return total


## Número de celdas de tierra. Recorre todo el mapa.
func count_land() -> int:
	var total := 0
	for index in CELL_COUNT:
		if _terrain[index] == TERRAIN_LAND:
			total += 1
	return total


## Copia independiente de los datos de terreno (modificarla no afecta a la cuadrícula).
func copy_terrain_data() -> PackedByteArray:
	return _terrain.duplicate()


## Copia independiente de los datos de propietario.
func copy_owner_data() -> PackedByteArray:
	return _owner.duplicate()


# ---------------------------------------------------------------------------
# Modificación controlada
# ---------------------------------------------------------------------------

## Asigna un propietario a una celda. Devuelve true si se aplicó y false si se rechazó,
## en cuyo caso el estado no cambia. Se rechaza si:
##   - (x, y) está fuera de límites,
##   - owner_id no es OWNER_NONE ni una nación conocida,
##   - la celda es agua y owner_id no es OWNER_NONE.
## Esta operación no valida reglas de juego (adyacencia, costes…): para eso existe conquer_cells,
## que es la vía que debe usar el juego.
func try_set_owner(x: int, y: int, owner_id: int) -> bool:
	if not is_valid_coord(x, y):
		return false
	if owner_id != OWNER_NONE and not NATIONS.has(owner_id):
		return false
	var index := y * WIDTH + x
	if _terrain[index] == TERRAIN_WATER and owner_id != OWNER_NONE:
		return false
	_owner[index] = owner_id
	return true


## Carga terreno y propietarios completos (para pruebas con mapas controlados y, más adelante,
## partidas guardadas). Devuelve true si se aplicó; si algo no es válido devuelve false y no
## cambia nada. Se rechaza si: algún array no mide CELL_COUNT, el terreno no es agua/tierra,
## el propietario no es OWNER_NONE ni una nación conocida, o una celda de agua tiene propietario.
func load_from_data(terrain: PackedByteArray, owners: PackedByteArray) -> bool:
	if terrain.size() != CELL_COUNT or owners.size() != CELL_COUNT:
		return false
	for index in CELL_COUNT:
		var cell_terrain := terrain[index]
		var cell_owner := owners[index]
		if cell_terrain != TERRAIN_WATER and cell_terrain != TERRAIN_LAND:
			return false
		if cell_owner != OWNER_NONE and not NATIONS.has(cell_owner):
			return false
		if cell_terrain == TERRAIN_WATER and cell_owner != OWNER_NONE:
			return false
	_terrain = terrain.duplicate()
	_owner = owners.duplicate()
	return true


## ÚNICA vía prevista del juego para cambiar propietarios: una conquista ya resuelta.
## (El combate decidirá en otro hito CUÁNDO y QUÉ celdas; esto solo valida y aplica.)
##
## attacker_id: nación conquistadora. cells: Array de Vector2i (x, y) con las celdas a conquistar.
## Conquista tierra sin reclamar o de otra nación; no cambia el terreno ni ninguna otra celda.
##
## Se valida TODO antes de tocar nada; si una celda falla no cambia ninguna. Reglas:
##   1. attacker_id es una nación existente (OWNER_NONE no vale).
##   2. cells no está vacía y todos sus elementos son Vector2i.
##   3. Cada celda está dentro del mapa, no se repite, es tierra y no es ya del atacante.
##   4. La zona es contigua (una sola pieza por vecinos ortogonales; la diagonal no cuenta).
##   5. Alguna celda de la zona toca ortogonalmente territorio actual del atacante.
##
## Devuelve un Dictionary:
##   "ok": bool                    true si se aplicó.
##   "changed": int                celdas cambiadas (0 si falló).
##   "error": int                  CONQUEST_OK o un CONQUEST_ERR_*.
##   "bad_index": int              posición en `cells` de la primera celda inválida, o -1.
##   "changed_cells": Array        las celdas cambiadas (Vector2i); la vista debe llamar a
##                                 refresh_cell(x, y) con cada una (vacío si falló).
func conquer_cells(attacker_id: int, cells: Array) -> Dictionary:
	var failure := _validate_conquest(attacker_id, cells)
	if not failure.is_empty():
		return _conquest_result(failure["error"], failure["bad_index"], [])
	var changed: Array = []
	for cell: Vector2i in cells:
		_owner[cell.y * WIDTH + cell.x] = attacker_id
		changed.append(cell)
	return _conquest_result(CONQUEST_OK, INVALID, changed)


func _conquest_result(error: int, bad_index: int, changed: Array) -> Dictionary:
	return {
		"ok": error == CONQUEST_OK,
		"changed": changed.size(),
		"error": error,
		"bad_index": bad_index,
		"changed_cells": changed,
	}


## Diccionario vacío si la conquista es válida; si no, {"error": código, "bad_index": int}.
func _validate_conquest(attacker_id: int, cells: Array) -> Dictionary:
	if not NATIONS.has(attacker_id):
		return {"error": CONQUEST_ERR_UNKNOWN_ATTACKER, "bad_index": INVALID}
	if cells.is_empty():
		return {"error": CONQUEST_ERR_EMPTY, "bad_index": INVALID}
	var targets := {}
	for i in cells.size():
		if typeof(cells[i]) != TYPE_VECTOR2I:
			return {"error": CONQUEST_ERR_INVALID_DATA, "bad_index": i}
		var cell: Vector2i = cells[i]
		if not is_valid_coord(cell.x, cell.y):
			return {"error": CONQUEST_ERR_OUT_OF_BOUNDS, "bad_index": i}
		if targets.has(cell):
			return {"error": CONQUEST_ERR_DUPLICATE, "bad_index": i}
		var index := cell.y * WIDTH + cell.x
		if _terrain[index] == TERRAIN_WATER:
			return {"error": CONQUEST_ERR_WATER, "bad_index": i}
		if _owner[index] == attacker_id:
			return {"error": CONQUEST_ERR_ALREADY_OWNED, "bad_index": i}
		targets[cell] = true
	if not _is_contiguous(cells, targets):
		return {"error": CONQUEST_ERR_NOT_CONTIGUOUS, "bad_index": INVALID}
	for cell: Vector2i in cells:
		for step: Vector2i in ORTHOGONAL_STEPS:
			var n := cell + step
			if is_valid_coord(n.x, n.y) and _owner[n.y * WIDTH + n.x] == attacker_id:
				return {}
	return {"error": CONQUEST_ERR_NO_CONTACT, "bad_index": INVALID}


## True si todas las celdas forman una sola pieza por vecinos ortogonales.
## `targets` es el conjunto (Dictionary) de las mismas celdas.
func _is_contiguous(cells: Array, targets: Dictionary) -> bool:
	var visited := {cells[0]: true}
	var stack: Array = [cells[0]]
	while not stack.is_empty():
		var current: Vector2i = stack.pop_back()
		for step: Vector2i in ORTHOGONAL_STEPS:
			var n := current + step
			if targets.has(n) and not visited.has(n):
				visited[n] = true
				stack.append(n)
	return visited.size() == targets.size()


# ---------------------------------------------------------------------------
# Generación del mapa por defecto (privado)
# ---------------------------------------------------------------------------

@warning_ignore("integer_division")
func _generate_landmass() -> void:
	var coarse_cols := WIDTH / COARSE_SPACING + 2
	var fine_cols := WIDTH / FINE_SPACING + 2
	var coarse := _build_lattice(COARSE_SPACING, COARSE_SALT)
	var fine := _build_lattice(FINE_SPACING, FINE_SALT)
	var axis_x := LAND_SEMI_AXES.x * LAND_SEMI_AXES.x
	var axis_y := LAND_SEMI_AXES.y * LAND_SEMI_AXES.y
	# El borde del mapa (fila/columna 0 y última) se queda siempre como agua.
	for y in range(1, HEIGHT - 1):
		var dy := y - LAND_CENTER.y
		var dy_part := dy * dy * 1000 / axis_y
		for x in range(1, WIDTH - 1):
			var dx := x - LAND_CENTER.x
			var distance := dx * dx * 1000 / axis_x + dy_part
			if distance >= FAR_LIMIT:
				continue
			var is_land_cell := distance < CORE_LIMIT
			if not is_land_cell:
				var limit := COAST_BASE
				limit += _value_noise(x, y, COARSE_SPACING, coarse_cols, coarse) * COARSE_AMPLITUDE / 1000
				limit += _value_noise(x, y, FINE_SPACING, fine_cols, fine) * FINE_AMPLITUDE / 1000
				is_land_cell = distance < limit
			if is_land_cell:
				_terrain[y * WIDTH + x] = TERRAIN_LAND


## Hash entero determinista (sin desbordamientos de 64 bits). Devuelve un valor de 0 a 65535.
func _hash_lattice(ix: int, iy: int, salt: int) -> int:
	var h: int = (ix * 1103515245 + iy * 12345 + salt * 2654435761) & 0xFFFFFFFF
	h = (((h >> 16) ^ h) * 0x45d9f3b) & 0xFFFFFFFF
	h = (((h >> 16) ^ h) * 0x45d9f3b) & 0xFFFFFFFF
	return (h >> 16) ^ h


## Retícula de valores de ruido (0 a 1023) con un punto cada `spacing` celdas.
@warning_ignore("integer_division")
func _build_lattice(spacing: int, salt: int) -> PackedInt32Array:
	var cols := WIDTH / spacing + 2
	var rows := HEIGHT / spacing + 2
	var lattice := PackedInt32Array()
	lattice.resize(cols * rows)
	for i in cols * rows:
		lattice[i] = _hash_lattice(i % cols, i / cols, salt) & 1023
	return lattice


## Ruido de valores con interpolación bilineal entera. Devuelve de -1000 a 1000.
@warning_ignore("integer_division")
func _value_noise(x: int, y: int, spacing: int, cols: int, lattice: PackedInt32Array) -> int:
	var ix := x / spacing
	var iy := y / spacing
	var fx := x % spacing
	var fy := y % spacing
	var top := lattice[iy * cols + ix] * (spacing - fx) + lattice[iy * cols + ix + 1] * fx
	var bottom := lattice[(iy + 1) * cols + ix] * (spacing - fx) + lattice[(iy + 1) * cols + ix + 1] * fx
	var value := top * (spacing - fy) + bottom * fy
	return value * 2000 / (1023 * spacing * spacing) - 1000


## Deja como tierra solo la mayor masa conectada (adyacencia ortogonal); lo demás pasa a agua.
func _keep_largest_land_component() -> void:
	var visited := PackedByteArray()
	visited.resize(CELL_COUNT)
	visited.fill(0)
	var largest := PackedInt32Array()
	for start in CELL_COUNT:
		if _terrain[start] != TERRAIN_LAND or visited[start] == 1:
			continue
		var component := _collect_connected(start, visited, _terrain, TERRAIN_LAND)
		if component.size() > largest.size():
			largest = component
	_terrain.fill(TERRAIN_WATER)
	for index in largest:
		_terrain[index] = TERRAIN_LAND


## Asigna a cada nación su círculo inicial y descarta lo que no esté conectado con su centro.
func _claim_start_territories() -> void:
	for nation_id: int in START_SITES:
		var site: Dictionary = START_SITES[nation_id]
		var center: Vector2i = site["seed"]
		var radius: int = site["radius"]
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if not is_valid_coord(x, y):
					continue
				var dx := x - center.x
				var dy := y - center.y
				if dx * dx + dy * dy > radius * radius:
					continue
				var index := y * WIDTH + x
				if _terrain[index] == TERRAIN_LAND and _owner[index] == OWNER_NONE:
					_owner[index] = nation_id
		_trim_to_connected(nation_id, center.y * WIDTH + center.x)


## Libera las celdas de la nación que no estén conectadas con la celda `seed_index`.
func _trim_to_connected(nation_id: int, seed_index: int) -> void:
	if _owner[seed_index] != nation_id:
		return
	var visited := PackedByteArray()
	visited.resize(CELL_COUNT)
	visited.fill(0)
	_collect_connected(seed_index, visited, _owner, nation_id)
	for index in CELL_COUNT:
		if _owner[index] == nation_id and visited[index] == 0:
			_owner[index] = OWNER_NONE


## Relleno por inundación (4 vecinos) desde `start` sobre las celdas de `cells` con ese `value`.
## Marca las celdas alcanzadas en `visited` y devuelve sus índices.
@warning_ignore("integer_division")
func _collect_connected(start: int, visited: PackedByteArray, cells: PackedByteArray, value: int) -> PackedInt32Array:
	var component := PackedInt32Array()
	var stack := PackedInt32Array([start])
	visited[start] = 1
	while not stack.is_empty():
		var index: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		component.append(index)
		var x := index % WIDTH
		var y := index / WIDTH
		if x > 0:
			_push_if_unvisited(index - 1, visited, cells, value, stack)
		if x < WIDTH - 1:
			_push_if_unvisited(index + 1, visited, cells, value, stack)
		if y > 0:
			_push_if_unvisited(index - WIDTH, visited, cells, value, stack)
		if y < HEIGHT - 1:
			_push_if_unvisited(index + WIDTH, visited, cells, value, stack)
	return component


func _push_if_unvisited(index: int, visited: PackedByteArray, cells: PackedByteArray, value: int, stack: PackedInt32Array) -> void:
	if visited[index] == 0 and cells[index] == value:
		visited[index] = 1
		stack.append(index)
