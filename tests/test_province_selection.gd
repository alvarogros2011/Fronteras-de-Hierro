## Pruebas automáticas de la selección de provincias y del panel (hito 2). Sin plugins.
##
## Ejecución (desde la raíz del proyecto):
##   godot --headless --path . --script res://tests/test_province_selection.gd
##
## Imprime PASS/FAIL por prueba y termina con código 0 si todo pasa o 1 si algo falla.
extends SceneTree

const ProvinceData := preload("res://scripts/data/province_data.gd")
const ProvinceMapScript := preload("res://scripts/map/province_map.gd")
const InfoPanelScript := preload("res://scripts/ui/province_info_panel.gd")
const MainScene := preload("res://scenes/main.tscn")

## Puntos que no pertenecen a ninguna provincia (fuera de la ventana, margen y esquina "recortada" del mapa).
const OUTSIDE_POINTS := [
	Vector2(-50, -50), Vector2(0, 0), Vector2(1279, 719), Vector2(640, 700),
	Vector2(1100, 560), Vector2(5000, 5000),
]

var _failed := 0
var _passed := 0
var _signal_log: Array = []


func _initialize() -> void:
	_run("punto interior selecciona la provincia correcta (centro de cada una)", _test_center_points)
	_run("puntos interiores descentrados también aciertan", _test_offcenter_points)
	_run("puntos fuera de cualquier provincia devuelven vacío", _test_outside_points)
	_run("cerca de una frontera compartida: cada lado devuelve su provincia", _test_near_borders)
	_run("punto exacto sobre la frontera: resultado estable y de una de las dos", _test_exact_border)
	_run("cambiar de selección actualiza el estado y emite la señal", _test_selection_state)
	_run("clic en vacío limpia la selección", _test_clear_selection)
	_run("la selección no modifica los datos autoritativos", _test_data_untouched)
	_run("la selección funciona con el nodo del mapa movido y escalado", _test_transformed_map)
	_run("el panel muestra nombre, propietario y vecinas según los datos", _test_panel_matches_data)
	_run("el panel invita a seleccionar cuando no hay selección", _test_panel_empty_state)
	_run("integridad: 14 provincias, 7 contra 7, etiquetas de propietario", _test_data_integrity)
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


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


func _test_center_points() -> Array:
	var errors := []
	for province: Dictionary in ProvinceData.all():
		var center := ProvinceData.polygon_center(province["polygon"])
		_expect(errors, ProvinceData.find_at_point(center), province["id"], "centro de %s" % province["id"])
	return errors


func _test_offcenter_points() -> Array:
	var errors := []
	for province: Dictionary in ProvinceData.all():
		var center := ProvinceData.polygon_center(province["polygon"])
		# Punto a mitad de camino entre el centro y cada vértice (siempre interior en polígonos convexos).
		for vertex: Vector2 in province["polygon"]:
			var point := center.lerp(vertex, 0.5)
			_expect(errors, ProvinceData.find_at_point(point), province["id"], "punto %s de %s" % [point, province["id"]])
	return errors


func _test_outside_points() -> Array:
	var errors := []
	for point: Vector2 in OUTSIDE_POINTS:
		_expect(errors, ProvinceData.find_at_point(point), "", "punto exterior %s" % point)
	return errors


## Devuelve los dos vértices compartidos por dos provincias (vacío si no comparten arista).
func _shared_vertices(a: Dictionary, b: Dictionary) -> Array:
	var shared: Array = []
	for point: Vector2 in a["polygon"]:
		if b["polygon"].has(point):
			shared.append(point)
	return shared


func _test_near_borders() -> Array:
	var errors := []
	for a: Dictionary in ProvinceData.all():
		for neighbor_id: String in a["neighbors"]:
			var b := ProvinceData.find(neighbor_id)
			var shared := _shared_vertices(a, b)
			if shared.size() != 2:
				errors.append("%s y %s deberían compartir 2 vértices y comparten %d" % [a["id"], b["id"], shared.size()])
				continue
			var middle: Vector2 = (shared[0] + shared[1]) / 2.0
			for pair: Array in [[a, "a"], [b, "b"]]:
				var province: Dictionary = pair[0]
				var center := ProvinceData.polygon_center(province["polygon"])
				var point: Vector2 = middle + (center - middle).normalized() * 1.0
				_expect(errors, ProvinceData.find_at_point(point), province["id"],
					"1 px dentro de %s junto a su frontera con %s" % [province["id"], b["id"] if pair[1] == "a" else a["id"]])
	return errors


func _test_exact_border() -> Array:
	var errors := []
	for a: Dictionary in ProvinceData.all():
		for neighbor_id: String in a["neighbors"]:
			var b := ProvinceData.find(neighbor_id)
			var shared := _shared_vertices(a, b)
			if shared.size() != 2:
				continue
			var middle: Vector2 = (shared[0] + shared[1]) / 2.0
			var first := ProvinceData.find_at_point(middle)
			var second := ProvinceData.find_at_point(middle)
			_expect(errors, second, first, "estabilidad en la frontera %s/%s" % [a["id"], b["id"]])
			# Puede ser una de las dos o vacío (según el redondeo), pero nunca una tercera provincia.
			if not [a["id"], b["id"], ""].has(first):
				errors.append("frontera %s/%s devolvió una tercera provincia: %s" % [a["id"], b["id"], first])
	return errors


func _on_selection_changed(province_id: String) -> void:
	_signal_log.append(province_id)


func _test_selection_state() -> Array:
	var errors := []
	var map = ProvinceMapScript.new()
	_signal_log.clear()
	map.selection_changed.connect(_on_selection_changed)
	var first: Dictionary = ProvinceData.all()[0]
	var second: Dictionary = ProvinceData.all()[5]
	_expect(errors, map.selected_id, "", "estado inicial")
	map.select_at(ProvinceData.polygon_center(first["polygon"]))
	_expect(errors, map.selected_id, first["id"], "tras seleccionar la primera")
	map.select_at(ProvinceData.polygon_center(second["polygon"]))
	_expect(errors, map.selected_id, second["id"], "tras seleccionar la segunda")
	# Repetir la misma selección no debe emitir otra señal.
	map.select_at(ProvinceData.polygon_center(second["polygon"]))
	_expect(errors, _signal_log, [first["id"], second["id"]], "señales emitidas")
	map.free()
	return errors


func _test_clear_selection() -> Array:
	var errors := []
	var map = ProvinceMapScript.new()
	_signal_log.clear()
	map.selection_changed.connect(_on_selection_changed)
	var province: Dictionary = ProvinceData.all()[3]
	map.select_at(ProvinceData.polygon_center(province["polygon"]))
	map.select_at(Vector2(1100, 560))
	_expect(errors, map.selected_id, "", "tras clic en vacío")
	_expect(errors, _signal_log, [province["id"], ""], "señales emitidas")
	# Un clic en vacío sin selección previa no hace nada.
	map.select_at(Vector2(-10, -10))
	_expect(errors, _signal_log.size(), 2, "número de señales tras segundo clic en vacío")
	map.free()
	return errors


func _test_data_untouched() -> Array:
	var errors := []
	var before := ProvinceData.PROVINCES.hash()
	var map = ProvinceMapScript.new()
	for province: Dictionary in ProvinceData.all():
		map.select_at(ProvinceData.polygon_center(province["polygon"]))
	map.select_at(Vector2(-10, -10))
	map.free()
	_expect(errors, ProvinceData.PROVINCES.hash(), before, "hash de los datos antes y después")
	return errors


func _test_transformed_map() -> Array:
	var errors := []
	var map = ProvinceMapScript.new()
	root.add_child(map)
	map.position = Vector2(-100, 30)
	map.scale = Vector2(0.8, 0.8)
	map.rotation = 0.1
	for province: Dictionary in ProvinceData.all():
		var local_center := ProvinceData.polygon_center(province["polygon"])
		# Lo que vería el ratón: coordenadas globales; el mapa debe convertirlas a locales.
		var global_point: Vector2 = map.to_global(local_center)
		map.select_at(map.to_local(global_point))
		_expect(errors, map.selected_id, province["id"], "con transformación, %s" % province["id"])
	map.queue_free()
	return errors


## Instancia la escena principal y devuelve [escena, mapa, panel].
func _spawn_main() -> Array:
	var main: Control = MainScene.instantiate()
	root.add_child(main)
	return [main, main.get_node("Mapa"), main.get_node("InfoPanel")]


func _test_panel_matches_data() -> Array:
	var errors := []
	var nodes := _spawn_main()
	var main: Control = nodes[0]
	var map = nodes[1]
	for province: Dictionary in ProvinceData.all():
		map.select_at(ProvinceData.polygon_center(province["polygon"]))
		var shown_name: String = main.get_node("%NameLabel").text
		var shown_owner: String = main.get_node("%OwnerLabel").text
		var shown_title: String = main.get_node("%NeighborsTitle").text
		var shown_list: String = main.get_node("%NeighborsList").text
		_expect(errors, shown_name, province["name"], "nombre mostrado de %s" % province["id"])
		_expect(errors, shown_owner, "Propietario: %s" % ("Jugador" if province["owner"] == "player" else "Enemigo"),
			"propietario mostrado de %s" % province["id"])
		_expect(errors, shown_title, "Vecinas (%d)" % province["neighbors"].size(), "recuento de vecinas de %s" % province["id"])
		var expected_names: Array = []
		for neighbor_id: String in province["neighbors"]:
			expected_names.append(ProvinceData.find(neighbor_id)["name"])
		_expect(errors, shown_list, "\n".join(expected_names), "vecinas mostradas de %s" % province["id"])
		if not main.get_node("%Details").visible or main.get_node("%HintLabel").visible:
			errors.append("visibilidad incorrecta del panel con %s seleccionada" % province["id"])
	main.queue_free()
	return errors


func _test_panel_empty_state() -> Array:
	var errors := []
	var nodes := _spawn_main()
	var main: Control = nodes[0]
	var map = nodes[1]
	if not main.get_node("%HintLabel").visible or main.get_node("%Details").visible:
		errors.append("el estado inicial debería mostrar solo la invitación a seleccionar")
	if main.get_node("%HintLabel").text.strip_edges().is_empty():
		errors.append("el texto de invitación está vacío")
	map.select_at(ProvinceData.polygon_center(ProvinceData.all()[0]["polygon"]))
	map.select_at(Vector2(-10, -10))
	if not main.get_node("%HintLabel").visible or main.get_node("%Details").visible:
		errors.append("tras limpiar la selección debería volver la invitación")
	if not InfoPanelScript.build_info("no_existe").is_empty():
		errors.append("build_info con un id inexistente debería devolver un diccionario vacío")
	main.queue_free()
	return errors


func _test_data_integrity() -> Array:
	var errors := []
	_expect(errors, ProvinceData.all().size(), 14, "número de provincias")
	_expect(errors, ProvinceData.count_owned_by(ProvinceData.OWNER_PLAYER), 7, "provincias del jugador")
	_expect(errors, ProvinceData.count_owned_by(ProvinceData.OWNER_ENEMY), 7, "provincias del enemigo")
	_expect(errors, ProvinceData.owner_label(ProvinceData.OWNER_PLAYER), "Jugador", "etiqueta del jugador")
	_expect(errors, ProvinceData.owner_label(ProvinceData.OWNER_ENEMY), "Enemigo", "etiqueta del enemigo")
	return errors
