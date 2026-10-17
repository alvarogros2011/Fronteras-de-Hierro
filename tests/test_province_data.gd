## Pruebas automáticas de los datos del mapa (hito 1). Sin plugins.
##
## Ejecución (desde la raíz del proyecto):
##   godot --headless --path . --script res://tests/test_province_data.gd
##
## Imprime PASS/FAIL por prueba y termina con código 0 si todo pasa o 1 si algo falla.
extends SceneTree

const ProvinceData := preload("res://scripts/data/province_data.gd")

const EXPECTED_PROVINCES := 14
const EXPECTED_PER_OWNER := 7
const VIEWPORT := Rect2(0, 0, 1280, 720)

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_run("hay exactamente 14 provincias", _test_province_count)
	_run("ids únicos, no vacíos y ASCII", _test_ids)
	_run("nombres no vacíos", _test_names)
	_run("propietarios válidos y reparto 7 contra 7", _test_owners)
	_run("geometría renderizable", _test_geometry)
	_run("todos los vecinos existen", _test_neighbors_exist)
	_run("sin autovecinas ni vecinos duplicados", _test_no_self_or_duplicate_neighbors)
	_run("adyacencia simétrica", _test_symmetry)
	_run("mapa conexo (todas alcanzables)", _test_connectivity)
	_run("topología coincide con la geometría (aristas compartidas)", _test_geometry_matches_topology)
	print("")
	print("Resultado: %d PASS, %d FAIL" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Ejecuta una prueba. Cada prueba devuelve un Array de mensajes de error (vacío = PASS).
func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	if errors.is_empty():
		_passed += 1
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		print("FAIL: %s" % test_name)
		for error: String in errors:
			print("      - %s" % error)


func _test_province_count() -> Array:
	var count := ProvinceData.all().size()
	if count != EXPECTED_PROVINCES:
		return ["se esperaban %d provincias y hay %d" % [EXPECTED_PROVINCES, count]]
	return []


func _test_ids() -> Array:
	var errors := []
	var seen := {}
	var regex := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	for province: Dictionary in ProvinceData.all():
		var id: String = province.get("id", "")
		if id.is_empty():
			errors.append("hay una provincia con id vacío")
			continue
		if seen.has(id):
			errors.append("id repetido: %s" % id)
		seen[id] = true
		if regex.search(id) == null:
			errors.append("id no válido (solo a-z, 0-9 y _): %s" % id)
	return errors


func _test_names() -> Array:
	var errors := []
	for province: Dictionary in ProvinceData.all():
		var province_name: String = province.get("name", "")
		if province_name.strip_edges().is_empty():
			errors.append("nombre vacío en %s" % province.get("id", "?"))
	return errors


func _test_owners() -> Array:
	var errors := []
	for province: Dictionary in ProvinceData.all():
		if not ProvinceData.OWNERS.has(province.get("owner", "")):
			errors.append("propietario no válido en %s: '%s'" % [province.get("id", "?"), province.get("owner", "")])
	var players := ProvinceData.count_owned_by(ProvinceData.OWNER_PLAYER)
	var enemies := ProvinceData.count_owned_by(ProvinceData.OWNER_ENEMY)
	if players != EXPECTED_PER_OWNER or enemies != EXPECTED_PER_OWNER:
		errors.append("reparto %d (jugador) contra %d (enemigo); se esperaba 7 contra 7" % [players, enemies])
	return errors


func _test_geometry() -> Array:
	var errors := []
	for province: Dictionary in ProvinceData.all():
		var id: String = province.get("id", "?")
		var polygon: Array = province.get("polygon", [])
		if polygon.size() < 3:
			errors.append("%s: el polígono necesita al menos 3 vértices" % id)
			continue
		for point: Vector2 in polygon:
			if not VIEWPORT.has_point(point):
				errors.append("%s: vértice fuera de la ventana: %s" % [id, point])
		if absf(_signed_area(polygon)) < 1000.0:
			errors.append("%s: área demasiado pequeña o degenerada" % id)
		if Geometry2D.triangulate_polygon(PackedVector2Array(polygon)).is_empty():
			errors.append("%s: el polígono no se puede triangular (inválido o con autointersección)" % id)
	return errors


func _test_neighbors_exist() -> Array:
	var errors := []
	for province: Dictionary in ProvinceData.all():
		for neighbor: String in province.get("neighbors", []):
			if ProvinceData.find(neighbor).is_empty():
				errors.append("%s lista un vecino inexistente: %s" % [province["id"], neighbor])
	return errors


func _test_no_self_or_duplicate_neighbors() -> Array:
	var errors := []
	for province: Dictionary in ProvinceData.all():
		var seen := {}
		for neighbor: String in province.get("neighbors", []):
			if neighbor == province["id"]:
				errors.append("%s es vecina de sí misma" % neighbor)
			if seen.has(neighbor):
				errors.append("%s repite el vecino %s" % [province["id"], neighbor])
			seen[neighbor] = true
	return errors


func _test_symmetry() -> Array:
	var errors := []
	for province: Dictionary in ProvinceData.all():
		for neighbor: String in province.get("neighbors", []):
			var other := ProvinceData.find(neighbor)
			if not other.is_empty() and not other["neighbors"].has(province["id"]):
				errors.append("%s lista a %s, pero %s no lista a %s" % [province["id"], neighbor, neighbor, province["id"]])
	return errors


func _test_connectivity() -> Array:
	var errors := []
	var provinces := ProvinceData.all()
	if provinces.is_empty():
		return ["no hay provincias"]
	# Se recorre el grafo desde CADA provincia (14 recorridos, coste insignificante).
	for start: Dictionary in provinces:
		var visited := {start["id"]: true}
		var pending: Array = [start["id"]]
		while not pending.is_empty():
			var current := ProvinceData.find(pending.pop_back())
			for neighbor: String in current.get("neighbors", []):
				if not visited.has(neighbor) and not ProvinceData.find(neighbor).is_empty():
					visited[neighbor] = true
					pending.append(neighbor)
		if visited.size() != provinces.size():
			errors.append("desde %s solo se alcanzan %d de %d provincias" % [start["id"], visited.size(), provinces.size()])
	return errors


## Dos provincias son vecinas si y solo si comparten una arista (dos vértices iguales).
func _test_geometry_matches_topology() -> Array:
	var errors := []
	var provinces := ProvinceData.all()
	for i in provinces.size():
		for j in range(i + 1, provinces.size()):
			var a: Dictionary = provinces[i]
			var b: Dictionary = provinces[j]
			var shared := 0
			for point: Vector2 in a["polygon"]:
				if b["polygon"].has(point):
					shared += 1
			var shares_edge := shared >= 2
			var declared: bool = a["neighbors"].has(b["id"])
			if shares_edge and not declared:
				errors.append("%s y %s comparten frontera pero no son vecinas en los datos" % [a["id"], b["id"]])
			if declared and not shares_edge:
				errors.append("%s y %s son vecinas en los datos pero no comparten frontera dibujada" % [a["id"], b["id"]])
	return errors


func _signed_area(polygon: Array) -> float:
	var area := 0.0
	for i in polygon.size():
		var p: Vector2 = polygon[i]
		var q: Vector2 = polygon[(i + 1) % polygon.size()]
		area += p.x * q.y - q.x * p.y
	return area / 2.0
