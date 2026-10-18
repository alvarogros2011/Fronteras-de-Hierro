## Pruebas automáticas de ciudades y economía básica (hito 6). Sin plugins.
##
## Única definición de las comprobaciones; la usan:
##   - tests/test_city_economy.gd (consola, headless):
##       godot --headless --path . --script res://tests/test_city_economy.gd
##   - tests/run_city_tests.tscn (editor de Godot, F6).
##
## Mapa controlado (load_from_data): tierra x 10..39, y 10..29; jugador x 10..24, IA 1 x 25..34,
## sin reclamar x 35..39; el resto es agua. IA 2 e IA 3 no tienen celdas.
##
## run_all() devuelve [{"name": String, "errors": Array}, ...]   (errors vacío = PASS)
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Economy := preload("res://scripts/world/economy.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Balance := preload("res://scripts/data/economy_balance.gd")
const Screen := preload("res://scripts/ui/territory_screen.gd")
const InfoPanel := preload("res://scripts/ui/territory_info_panel.gd")

const PLAYER := TerritoryGrid.OWNER_PLAYER
const AI_1 := TerritoryGrid.OWNER_AI_1
const AI_2 := TerritoryGrid.OWNER_AI_2
const SCREEN_PATH := "res://scenes/territory_main.tscn"

var _results: Array = []


func run_all() -> Array:
	_results = []
	_run("las constantes de equilibrio son coherentes", _test_balance_constants)
	_run("ciudades iniciales en el mapa por defecto: una por nación, nivel 1, en su territorio", _test_initial_default)
	_run("ciudades iniciales en un mapa controlado: búsqueda determinista dentro del territorio", _test_initial_fallback)
	_run("saldo inicial de las naciones y economía sin saldos negativos", _test_economy_basics)
	_run("fundación válida: crea la ciudad, cobra exactamente el coste y avisa una vez", _test_valid_founding)
	_run("fundación rechazada en agua, fuera del mapa, territorio ajeno y sin reclamar", _test_invalid_cells)
	_run("fundación rechazada en posición duplicada o demasiado próxima (cualquier nación)", _test_duplicate_and_distance)
	_run("la distancia mínima se mide en Chebyshev y el límite exacto se acepta", _test_distance_boundary)
	_run("fundación rechazada sin dinero suficiente; con el dinero justo se acepta", _test_funds)
	_run("una fundación inválida no descuenta dinero ni cambia territorio ni consume IDs", _test_invalid_changes_nothing)
	_run("nación inexistente rechazada", _test_unknown_nation)
	_run("crecimiento temporal y cambios de nivel con umbrales crecientes", _test_growth_levels)
	_run("el tiempo es independiente de los fotogramas (ticks fijos)", _test_frame_independence)
	_run("crecer no cambia ningún propietario ni sale del territorio", _test_growth_keeps_territory)
	_run("las ciudades producen dinero y recursos según su nivel", _test_production)
	_run("solo produce para su propietario; sin propietario no produce", _test_production_owner_only)
	_run("el cambio de propietario de la celda central se refleja en la ciudad", _test_owner_change)
	_run("mancha visual: tamaño por nivel, límite y solo dentro del territorio propio", _test_visual_cells)
	_run("city_covering e información de la ciudad", _test_city_covering_and_text)
	_run("pantalla: economía, ciudades iniciales y modo de fundación", _test_screen)
	_run("las cuatro suites anteriores siguen presentes", _test_previous_suites_present)
	return _results


func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	_results.append({"name": test_name, "errors": errors})


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


func _make_grid() -> TerritoryGrid:
	var terrain := PackedByteArray()
	terrain.resize(TerritoryGrid.CELL_COUNT)
	terrain.fill(TerritoryGrid.TERRAIN_WATER)
	var owners := PackedByteArray()
	owners.resize(TerritoryGrid.CELL_COUNT)
	owners.fill(TerritoryGrid.OWNER_NONE)
	for y in range(10, 30):
		for x in range(10, 40):
			terrain[y * TerritoryGrid.WIDTH + x] = TerritoryGrid.TERRAIN_LAND
			if x <= 24:
				owners[y * TerritoryGrid.WIDTH + x] = PLAYER
			elif x <= 34:
				owners[y * TerritoryGrid.WIDTH + x] = AI_1
	var grid := TerritoryGrid.new()
	grid.load_from_data(terrain, owners)
	return grid


## Mapa controlado + economía + gestor SIN ciudades iniciales.
func _make_world() -> Dictionary:
	var grid := _make_grid()
	var economy := Economy.new(grid.get_nation_ids())
	var cities := CityManager.new(grid, economy)
	return {"grid": grid, "economy": economy, "cities": cities}


func _test_balance_constants() -> Array:
	var errors: Array = []
	_expect(errors, Balance.FOUND_COST > 0, true, "el coste es positivo")
	_expect(errors, Balance.INITIAL_MONEY < Balance.FOUND_COST, true, "el saldo inicial obliga a ahorrar")
	_expect(errors, Balance.MIN_CITY_DISTANCE > 2 * Balance.VISUAL_RADIUS[Balance.MAX_LEVEL], true, "dos ciudades no se solapan visualmente")
	for table: Array in [Balance.MONEY_PER_TICK, Balance.RESOURCES_PER_TICK, Balance.VISUAL_RADIUS, Balance.GROWTH_TO_NEXT]:
		_expect(errors, table.size(), Balance.MAX_LEVEL + 1, "las tablas tienen una entrada por nivel")
	for level in range(1, Balance.MAX_LEVEL - 1):
		_expect(errors, Balance.GROWTH_TO_NEXT[level + 1] > Balance.GROWTH_TO_NEXT[level], true, "umbral del nivel %d mayor que el anterior" % (level + 1))
	for level in range(1, Balance.MAX_LEVEL):
		_expect(errors, Balance.MONEY_PER_TICK[level + 1] >= Balance.MONEY_PER_TICK[level], true, "el dinero no baja al subir de nivel")
	_expect(errors, Balance.TICK_SECONDS > 0.0, true, "el tick dura algo")
	return errors


func _test_initial_default() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var cities := CityManager.new(grid, Economy.new(grid.get_nation_ids()))
	_expect(errors, cities.city_count(), 0, "antes de colocarlas no hay ciudades")
	_expect(errors, cities.place_initial_cities(), 4, "se crean 4 ciudades")
	var seen := {}
	for nation_id: int in grid.get_nation_ids():
		var found := 0
		for city_id: int in cities.get_city_ids():
			var city := cities.get_city(city_id)
			if city["owner"] != nation_id:
				continue
			found += 1
			var cell: Vector2i = city["cell"]
			_expect(errors, cell, TerritoryGrid.START_SITES[nation_id]["seed"], "posición inicial de la nación %d" % nation_id)
			_expect(errors, grid.is_land(cell.x, cell.y), true, "ciudad de %d en tierra" % nation_id)
			_expect(errors, grid.get_cell_owner(cell.x, cell.y), nation_id, "ciudad de %d en su territorio" % nation_id)
			_expect(errors, [city["level"], city["progress"]], [1, 0], "nivel 1 sin progreso")
			seen[city_id] = true
		_expect(errors, found, 1, "una ciudad para la nación %d" % nation_id)
	_expect(errors, seen.size(), 4, "IDs únicos")
	# Determinista: otra instancia da lo mismo.
	var other := CityManager.new(TerritoryGrid.new(), Economy.new(grid.get_nation_ids()))
	other.place_initial_cities()
	for city_id: int in cities.get_city_ids():
		_expect(errors, other.get_city(city_id)["cell"], cities.get_city(city_id)["cell"], "misma posición en otra instancia")
	return errors


func _test_initial_fallback() -> Array:
	var errors: Array = []
	var world := _make_world()
	var grid: TerritoryGrid = world["grid"]
	var cities: CityManager = world["cities"]
	_expect(errors, cities.place_initial_cities(), 2, "solo las naciones con tierra reciben ciudad")
	for city_id: int in cities.get_city_ids():
		var city := cities.get_city(city_id)
		var cell: Vector2i = city["cell"]
		_expect(errors, grid.get_cell_owner(cell.x, cell.y), city["owner"], "ciudad %d dentro de su territorio" % city_id)
	_expect(errors, cities.count_owned_by(PLAYER), 1, "el jugador tiene una")
	_expect(errors, cities.count_owned_by(AI_2), 0, "IA 2 no tiene tierra ni ciudad")
	var first: Array = []
	for city_id: int in cities.get_city_ids():
		first.append(cities.get_city(city_id)["cell"])
	cities.place_initial_cities()
	var second: Array = []
	for city_id: int in cities.get_city_ids():
		second.append(cities.get_city(city_id)["cell"])
	_expect(errors, second, first, "colocarlas dos veces da las mismas posiciones")
	_expect(errors, cities.get_city_ids(), [1, 2], "al recolocar los IDs vuelven a empezar")
	return errors


func _test_economy_basics() -> Array:
	var errors: Array = []
	var grid := TerritoryGrid.new()
	var economy := Economy.new(grid.get_nation_ids())
	for nation_id: int in grid.get_nation_ids():
		_expect(errors, [economy.get_money(nation_id), economy.get_resources(nation_id)], [Balance.INITIAL_MONEY, Balance.INITIAL_RESOURCES], "saldo inicial de %d" % nation_id)
	_expect(errors, economy.get_money(99), -1, "nación inexistente: -1")
	_expect(errors, economy.spend_money(PLAYER, Balance.INITIAL_MONEY + 1), false, "no se puede gastar más de lo que hay")
	_expect(errors, economy.spend_money(PLAYER, -5), false, "no se puede gastar una cantidad negativa")
	_expect(errors, economy.add(PLAYER, -1, 0), false, "no se puede sumar dinero negativo")
	_expect(errors, economy.add(PLAYER, 0, -1), false, "no se puede sumar recursos negativos")
	_expect(errors, economy.add(99, 1, 1), false, "no se suma a una nación inexistente")
	_expect(errors, economy.get_money(PLAYER), Balance.INITIAL_MONEY, "el dinero no cambió con las operaciones rechazadas")
	_expect(errors, economy.add(PLAYER, 10, 4), true, "suma válida")
	_expect(errors, [economy.get_money(PLAYER), economy.get_resources(PLAYER)], [Balance.INITIAL_MONEY + 10, 4], "saldos tras sumar")
	_expect(errors, economy.spend_money(PLAYER, Balance.INITIAL_MONEY + 10), true, "gastar todo el saldo")
	_expect(errors, economy.get_money(PLAYER), 0, "saldo exactamente 0, nunca negativo")
	var count := [0]
	economy.balances_changed.connect(func() -> void: count[0] += 1)
	economy.spend_money(PLAYER, 1)
	economy.add(PLAYER, -3, 0)
	_expect(errors, count[0], 0, "las operaciones rechazadas no emiten señal")
	economy.add(PLAYER, 5, 0)
	_expect(errors, count[0], 1, "una operación aplicada emite una vez")
	return errors


func _test_valid_founding() -> Array:
	var errors: Array = []
	var world := _make_world()
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	economy.add(PLAYER, 200, 7)
	var money_before := economy.get_money(PLAYER)
	var signals := [0]
	cities.changed.connect(func() -> void: signals[0] += 1)
	var result := cities.found_city(PLAYER, Vector2i(12, 12))
	_expect(errors, result["ok"], true, "fundación válida")
	_expect(errors, result["error"], CityManager.FOUND_OK, "código de resultado")
	_expect(errors, cities.city_count(), 1, "hay una ciudad")
	var city := cities.get_city(result["city_id"])
	_expect(errors, [city["owner"], city["cell"], city["level"], city["progress"]], [PLAYER, Vector2i(12, 12), 1, 0], "datos de la ciudad nueva")
	_expect(errors, economy.get_money(PLAYER), money_before - Balance.FOUND_COST, "se descuenta exactamente el coste")
	_expect(errors, economy.get_resources(PLAYER), 7, "los recursos no se tocan")
	_expect(errors, signals[0], 1, "changed se emite una vez")
	_expect(errors, cities.city_id_at(Vector2i(12, 12)), result["city_id"], "city_id_at encuentra el centro")
	_expect(errors, economy.get_money(AI_1), Balance.INITIAL_MONEY, "otras naciones no pagan")
	return errors


func _test_invalid_cells() -> Array:
	var errors: Array = []
	var world := _make_world()
	var grid: TerritoryGrid = world["grid"]
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	economy.add(PLAYER, 500, 0)
	var cases := [
		[Vector2i(0, 0), CityManager.FOUND_ERR_NOT_LAND, "agua"],
		[Vector2i(5, 5), CityManager.FOUND_ERR_NOT_LAND, "agua junto a la costa"],
		[Vector2i(-1, 5), CityManager.FOUND_ERR_OUT_OF_BOUNDS, "x negativa"],
		[Vector2i(5, 180), CityManager.FOUND_ERR_OUT_OF_BOUNDS, "y fuera"],
		[Vector2i(320, 0), CityManager.FOUND_ERR_OUT_OF_BOUNDS, "x fuera"],
		[Vector2i(30, 20), CityManager.FOUND_ERR_NOT_OWNED, "territorio de la IA 1"],
		[Vector2i(37, 20), CityManager.FOUND_ERR_NOT_OWNED, "tierra sin reclamar"],
	]
	var owners_before := grid.copy_owner_data()
	var money_before := economy.get_money(PLAYER)
	for item: Array in cases:
		var result := cities.found_city(PLAYER, item[0])
		_expect(errors, [result["ok"], result["error"]], [false, item[1]], "rechazo: " + item[2])
		_expect(errors, result["city_id"], CityManager.NO_CITY, "sin ciudad: " + item[2])
	_expect(errors, cities.city_count(), 0, "no se creó ninguna ciudad")
	_expect(errors, economy.get_money(PLAYER), money_before, "no se descontó dinero")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "el territorio no cambió")
	return errors


func _test_duplicate_and_distance() -> Array:
	var errors: Array = []
	var world := _make_world()
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	economy.add(PLAYER, 1000, 0)
	economy.add(AI_1, 1000, 0)
	_expect(errors, cities.found_city(PLAYER, Vector2i(12, 12))["ok"], true, "primera ciudad")
	var money := economy.get_money(PLAYER)
	_expect(errors, cities.found_city(PLAYER, Vector2i(12, 12))["error"], CityManager.FOUND_ERR_OCCUPIED, "misma posición")
	_expect(errors, cities.found_city(PLAYER, Vector2i(13, 12))["error"], CityManager.FOUND_ERR_TOO_CLOSE, "casilla contigua")
	_expect(errors, cities.found_city(PLAYER, Vector2i(18, 18))["error"], CityManager.FOUND_ERR_TOO_CLOSE, "distancia 6 en diagonal")
	# Ciudad de otra nación: también cuenta para la distancia mínima.
	_expect(errors, cities.found_city(AI_1, Vector2i(26, 12))["ok"], true, "ciudad de la IA 1 a distancia 14")
	_expect(errors, cities.found_city(PLAYER, Vector2i(24, 12))["error"], CityManager.FOUND_ERR_TOO_CLOSE, "cerca de una ciudad ajena")
	_expect(errors, economy.get_money(PLAYER), money, "los rechazos no cobraron")
	_expect(errors, cities.city_count(), 2, "solo existen las dos válidas")
	return errors


func _test_distance_boundary() -> Array:
	var errors: Array = []
	var world := _make_world()
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	economy.add(PLAYER, 1000, 0)
	var d := Balance.MIN_CITY_DISTANCE
	_expect(errors, cities.found_city(PLAYER, Vector2i(10, 10))["ok"], true, "ciudad de referencia")
	# Distancia Chebyshev: la coordenada mayor decide, aunque la otra sea 0.
	_expect(errors, cities.found_city(PLAYER, Vector2i(10 + d - 1, 10))["error"], CityManager.FOUND_ERR_TOO_CLOSE, "distancia mínima - 1 en x")
	_expect(errors, cities.found_city(PLAYER, Vector2i(10, 10 + d - 1))["error"], CityManager.FOUND_ERR_TOO_CLOSE, "distancia mínima - 1 en y")
	_expect(errors, cities.found_city(PLAYER, Vector2i(10 + d - 1, 10 + d - 1))["error"], CityManager.FOUND_ERR_TOO_CLOSE, "distancia mínima - 1 en diagonal")
	_expect(errors, cities.found_city(PLAYER, Vector2i(10 + d, 10))["ok"], true, "distancia mínima exacta en x")
	_expect(errors, cities.found_city(PLAYER, Vector2i(10, 10 + d))["ok"], true, "distancia mínima exacta en y")
	return errors


func _test_funds() -> Array:
	var errors: Array = []
	var world := _make_world()
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	_expect(errors, economy.get_money(PLAYER) < Balance.FOUND_COST, true, "el saldo inicial no alcanza")
	var result := cities.found_city(PLAYER, Vector2i(12, 12))
	_expect(errors, [result["ok"], result["error"]], [false, CityManager.FOUND_ERR_NO_FUNDS], "sin dinero se rechaza")
	_expect(errors, [economy.get_money(PLAYER), cities.city_count()], [Balance.INITIAL_MONEY, 0], "nada cambió")
	economy.add(PLAYER, Balance.FOUND_COST - Balance.INITIAL_MONEY - 1, 0)
	_expect(errors, cities.found_city(PLAYER, Vector2i(12, 12))["error"], CityManager.FOUND_ERR_NO_FUNDS, "un punto menos del coste")
	economy.add(PLAYER, 1, 0)
	_expect(errors, cities.found_city(PLAYER, Vector2i(12, 12))["ok"], true, "con el dinero justo se funda")
	_expect(errors, economy.get_money(PLAYER), 0, "queda exactamente 0")
	return errors


func _test_invalid_changes_nothing() -> Array:
	var errors: Array = []
	var world := _make_world()
	var grid: TerritoryGrid = world["grid"]
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	economy.add(PLAYER, 500, 0)
	var terrain_before := grid.copy_terrain_data()
	var owners_before := grid.copy_owner_data()
	var money_before := economy.get_money(PLAYER)
	cities.found_city(PLAYER, Vector2i(0, 0))
	cities.found_city(PLAYER, Vector2i(30, 20))
	_expect(errors, economy.get_money(PLAYER), money_before, "dinero intacto")
	_expect(errors, cities.city_count(), 0, "sin ciudades parciales")
	_expect(errors, grid.copy_owner_data() == owners_before and grid.copy_terrain_data() == terrain_before, true, "cuadrícula intacta")
	var result := cities.found_city(PLAYER, Vector2i(12, 12))
	_expect(errors, result["city_id"], 1, "los fallos no consumen IDs")
	_expect(errors, cities.check_founding(PLAYER, Vector2i(21, 21)), CityManager.FOUND_OK, "check_founding devuelve OK a la distancia mínima exacta (9) de la ciudad en (12, 12)")
	_expect(errors, cities.city_count(), 1, "check_founding no crea nada")
	# Todos los códigos tienen mensaje.
	for code in range(0, 8):
		_expect(errors, CityManager.error_message(code) != "Error desconocido.", true, "mensaje del código %d" % code)
	return errors


func _test_unknown_nation() -> Array:
	var errors: Array = []
	var world := _make_world()
	var cities: CityManager = world["cities"]
	_expect(errors, cities.found_city(TerritoryGrid.OWNER_NONE, Vector2i(12, 12))["error"], CityManager.FOUND_ERR_UNKNOWN_NATION, "OWNER_NONE")
	_expect(errors, cities.found_city(99, Vector2i(12, 12))["error"], CityManager.FOUND_ERR_UNKNOWN_NATION, "ID 99")
	_expect(errors, cities.city_count(), 0, "sin ciudades")
	return errors


func _test_growth_levels() -> Array:
	var errors: Array = []
	var world := _make_world()
	var cities: CityManager = world["cities"]
	world["economy"].add(PLAYER, 500, 0)
	var id: int = cities.found_city(PLAYER, Vector2i(12, 12))["city_id"]
	var needed1 := Balance.GROWTH_TO_NEXT[1]
	_expect(errors, cities.advance(float(needed1 - 1)), needed1 - 1, "ticks ejecutados")
	_expect(errors, [cities.get_city(id)["level"], cities.get_city(id)["progress"]], [1, needed1 - 1], "justo antes del umbral")
	var signals := [0]
	cities.changed.connect(func() -> void: signals[0] += 1)
	cities.advance(1.0)
	_expect(errors, [cities.get_city(id)["level"], cities.get_city(id)["progress"]], [2, 0], "sube a nivel 2 con el progreso a 0")
	_expect(errors, signals[0], 1, "avisa de la subida de nivel")
	cities.advance(float(Balance.GROWTH_TO_NEXT[2]))
	_expect(errors, cities.get_city(id)["level"], 3, "nivel 3 tras el segundo umbral (mayor)")
	cities.advance(float(Balance.GROWTH_TO_NEXT[3]))
	_expect(errors, cities.get_city(id)["level"], Balance.MAX_LEVEL, "nivel máximo")
	_expect(errors, [cities.get_city(id)["progress"], cities.get_city(id)["needed"]], [0, 0], "en el nivel máximo no hay progreso pendiente")
	cities.advance(1000.0)
	_expect(errors, cities.get_city(id)["level"], Balance.MAX_LEVEL, "no pasa del nivel máximo")
	# Un salto grande sube varios niveles de una vez y conserva el sobrante.
	var world2 := _make_world()
	world2["economy"].add(PLAYER, 500, 0)
	var id2: int = world2["cities"].found_city(PLAYER, Vector2i(12, 12))["city_id"]
	world2["cities"].advance(float(Balance.GROWTH_TO_NEXT[1] + Balance.GROWTH_TO_NEXT[2] + 5))
	_expect(errors, [world2["cities"].get_city(id2)["level"], world2["cities"].get_city(id2)["progress"]], [3, 5], "varios niveles y sobrante")
	return errors


func _test_frame_independence() -> Array:
	var errors: Array = []
	var results: Array = []
	for step in [10.0, 1.0, 0.25]:
		var world := _make_world()
		world["economy"].add(PLAYER, 500, 0)
		var id: int = world["cities"].found_city(PLAYER, Vector2i(12, 12))["city_id"]
		var total := 10.0
		var elapsed := 0.0
		while elapsed < total:
			world["cities"].advance(step)
			elapsed += step
		results.append([world["cities"].get_city(id)["progress"], world["economy"].get_money(PLAYER), world["economy"].get_resources(PLAYER)])
	_expect(errors, results[1], results[0], "pasos de 1 s = un solo paso de 10 s")
	_expect(errors, results[2], results[0], "pasos de 0,25 s = un solo paso de 10 s")
	var world2 := _make_world()
	_expect(errors, world2["cities"].advance(0.0), 0, "delta 0 no hace nada")
	_expect(errors, world2["cities"].advance(-3.0), 0, "delta negativo se ignora")
	_expect(errors, world2["cities"].advance(Balance.TICK_SECONDS * 0.5), 0, "medio tick no ejecuta nada")
	_expect(errors, world2["cities"].advance(Balance.TICK_SECONDS * 0.5), 1, "las fracciones se acumulan")
	return errors


func _test_growth_keeps_territory() -> Array:
	var errors: Array = []
	var world := _make_world()
	var grid: TerritoryGrid = world["grid"]
	var cities: CityManager = world["cities"]
	world["economy"].add(PLAYER, 500, 0)
	cities.place_initial_cities()
	var signals := [0]
	grid.ownership_changed.connect(func() -> void: signals[0] += 1)
	var owners_before := grid.copy_owner_data()
	var terrain_before := grid.copy_terrain_data()
	cities.advance(1000.0)
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ningún propietario cambió")
	_expect(errors, grid.copy_terrain_data() == terrain_before, true, "ningún terreno cambió")
	_expect(errors, signals[0], 0, "crecer no emite ownership_changed")
	for city_id: int in cities.get_city_ids():
		var city := cities.get_city(city_id)
		_expect(errors, city["level"], Balance.MAX_LEVEL, "ciudad %d en nivel máximo" % city_id)
		for cell in cities.visual_cells(city_id):
			_expect(errors, [grid.is_land(cell.x, cell.y), grid.get_cell_owner(cell.x, cell.y)], [true, city["owner"]], "celda %s dentro del territorio propio" % cell)
	return errors


func _test_production() -> Array:
	var errors: Array = []
	var world := _make_world()
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	economy.add(PLAYER, 200, 0)
	var id: int = cities.found_city(PLAYER, Vector2i(12, 12))["city_id"]
	var money := economy.get_money(PLAYER)
	_expect(errors, cities.income_for(PLAYER), {"money": Balance.MONEY_PER_TICK[1], "resources": Balance.RESOURCES_PER_TICK[1]}, "producción por tick del nivel 1")
	cities.advance(5.0)
	_expect(errors, economy.get_money(PLAYER), money + 5 * Balance.MONEY_PER_TICK[1], "dinero tras 5 ticks")
	_expect(errors, economy.get_resources(PLAYER), 5 * Balance.RESOURCES_PER_TICK[1], "recursos tras 5 ticks")
	# Con más ciudades se suma.
	cities.found_city(PLAYER, Vector2i(22, 12))
	money = economy.get_money(PLAYER)
	var resources := economy.get_resources(PLAYER)
	cities.advance(3.0)
	_expect(errors, economy.get_money(PLAYER), money + 3 * 2 * Balance.MONEY_PER_TICK[1], "dos ciudades producen el doble")
	_expect(errors, economy.get_resources(PLAYER), resources + 3 * 2 * Balance.RESOURCES_PER_TICK[1], "recursos de dos ciudades")
	# Al subir de nivel mejora la producción.
	cities.advance(float(Balance.GROWTH_TO_NEXT[1]))
	_expect(errors, cities.get_city(id)["level"], 2, "la primera ciudad subió de nivel")
	_expect(errors, cities.get_city(id)["money_rate"], Balance.MONEY_PER_TICK[2], "tasa de dinero del nivel 2")
	money = economy.get_money(PLAYER)
	var rate: int = cities.income_for(PLAYER)["money"]
	cities.advance(1.0)
	_expect(errors, economy.get_money(PLAYER), money + rate, "el saldo sigue la tasa vigente")
	return errors


func _test_production_owner_only() -> Array:
	var errors: Array = []
	var world := _make_world()
	var grid: TerritoryGrid = world["grid"]
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	economy.add(PLAYER, 200, 0)
	economy.add(AI_1, 200, 0)
	cities.found_city(PLAYER, Vector2i(12, 12))
	var ai_money := economy.get_money(AI_1)
	cities.advance(4.0)
	_expect(errors, economy.get_money(AI_1), ai_money, "otra nación no recibe nada")
	# Si el centro queda sin propietario (try_set_owner), la ciudad queda inactiva.
	var money := economy.get_money(PLAYER)
	grid.try_set_owner(12, 12, TerritoryGrid.OWNER_NONE)
	cities.advance(4.0)
	_expect(errors, economy.get_money(PLAYER), money, "ciudad sin propietario no produce")
	_expect(errors, cities.get_city(1)["progress"], 4, "ni crece")
	_expect(errors, cities.visual_cells(1).size(), 0, "ni se dibuja")
	_expect(errors, cities.has_city(1), true, "pero no se destruye")
	return errors


func _test_owner_change() -> Array:
	var errors: Array = []
	var world := _make_world()
	var grid: TerritoryGrid = world["grid"]
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	economy.add(PLAYER, 200, 0)
	var id: int = cities.found_city(PLAYER, Vector2i(24, 12))["city_id"]
	cities.advance(10.0)
	var before := cities.get_city(id)
	_expect(errors, before["owner"], PLAYER, "empieza siendo del jugador")
	_expect(errors, cities.count_owned_by(PLAYER), 1, "una ciudad del jugador")
	var result := grid.conquer_cells(AI_1, [Vector2i(24, 12)])
	_expect(errors, result["ok"], true, "la IA 1 conquista la celda central")
	var after := cities.get_city(id)
	_expect(errors, after["owner"], AI_1, "la ciudad pasa a la IA 1")
	_expect(errors, [after["level"], after["progress"], after["cell"]], [before["level"], before["progress"], before["cell"]], "no se destruye ni pierde datos")
	_expect(errors, [cities.count_owned_by(PLAYER), cities.count_owned_by(AI_1)], [0, 1], "recuento por nación")
	_expect(errors, cities.income_for(PLAYER)["money"], 0, "el jugador deja de producir con ella")
	_expect(errors, cities.income_for(AI_1)["money"], Balance.MONEY_PER_TICK[1], "la IA 1 produce con ella")
	var player_money := economy.get_money(PLAYER)
	var ai_money := economy.get_money(AI_1)
	cities.advance(2.0)
	_expect(errors, economy.get_money(PLAYER), player_money, "el antiguo dueño no cobra")
	_expect(errors, economy.get_money(AI_1), ai_money + 2 * Balance.MONEY_PER_TICK[1], "el nuevo dueño cobra")
	# La mancha visual pasa a limitarse al nuevo territorio.
	for cell in cities.visual_cells(id):
		_expect(errors, grid.get_cell_owner(cell.x, cell.y), AI_1, "celda visual %s del nuevo dueño" % cell)
	# La conquista no vuelve a cambiar su dueño por el crecimiento.
	cities.advance(200.0)
	_expect(errors, cities.get_city(id)["owner"], AI_1, "el dueño solo cambia por conquista")
	return errors


func _test_visual_cells() -> Array:
	var errors: Array = []
	var world := _make_world()
	var grid: TerritoryGrid = world["grid"]
	var cities: CityManager = world["cities"]
	world["economy"].add(PLAYER, 500, 0)
	# Centro (17, 20): todo el rombo de radio 4 cabe dentro del territorio del jugador (x 10..24, y 10..29).
	var id: int = cities.found_city(PLAYER, Vector2i(17, 20))["city_id"]
	var expected_sizes := {1: 5, 2: 13, 3: 25, 4: 41}
	for level in range(1, Balance.MAX_LEVEL + 1):
		_expect(errors, cities.visual_cells(id).size(), expected_sizes[level], "píxeles del nivel %d" % level)
		cities.advance(float(Balance.GROWTH_TO_NEXT[level]))
	_expect(errors, cities.visual_cells(id).size() <= 2 * Balance.VISUAL_RADIUS[Balance.MAX_LEVEL] * (Balance.VISUAL_RADIUS[Balance.MAX_LEVEL] + 1) + 1, true, "tamaño visual acotado")
	_expect(errors, cities.visual_cells(id).has(Vector2i(17, 20)), true, "incluye el centro")
	# Ciudad pegada al borde del territorio: las celdas ajenas, sin reclamar y de agua no se dibujan.
	var edge_id: int = cities.found_city(PLAYER, Vector2i(24, 29))["city_id"]
	cities.advance(1000.0)
	for cell in cities.visual_cells(edge_id):
		_expect(errors, [grid.is_land(cell.x, cell.y), grid.get_cell_owner(cell.x, cell.y)], [true, PLAYER], "celda %s de tierra del jugador" % cell)
	_expect(errors, cities.visual_cells(edge_id).has(Vector2i(25, 29)), false, "no invade la IA 1")
	_expect(errors, cities.visual_cells(edge_id).has(Vector2i(24, 30)), false, "no se dibuja en agua")
	_expect(errors, cities.visual_cells(edge_id).size() < 41, true, "el borde recorta la mancha")
	_expect(errors, cities.visual_cells(99).size(), 0, "ciudad inexistente: sin celdas")
	return errors


func _test_city_covering_and_text() -> Array:
	var errors: Array = []
	var world := _make_world()
	var grid: TerritoryGrid = world["grid"]
	var cities: CityManager = world["cities"]
	world["economy"].add(PLAYER, 500, 0)
	var id: int = cities.found_city(PLAYER, Vector2i(17, 20))["city_id"]
	_expect(errors, cities.city_covering(Vector2i(17, 20)), id, "centro")
	_expect(errors, cities.city_covering(Vector2i(18, 20)), id, "celda de la mancha")
	_expect(errors, cities.city_covering(Vector2i(19, 20)), CityManager.NO_CITY, "fuera de la mancha de nivel 1")
	_expect(errors, cities.city_id_at(Vector2i(18, 20)), CityManager.NO_CITY, "city_id_at solo el centro exacto")
	var text := InfoPanel.describe_city(grid, cities, id)
	_expect(errors, text.contains("Confederación de Alba"), true, "el texto incluye el propietario")
	_expect(errors, text.contains("nivel 1"), true, "el texto incluye el nivel")
	_expect(errors, text.contains("+%d dinero/s" % Balance.MONEY_PER_TICK[1]), true, "el texto incluye el dinero por segundo")
	_expect(errors, text.contains("+%d recursos/s" % Balance.RESOURCES_PER_TICK[1]), true, "el texto incluye los recursos por segundo")
	_expect(errors, text.contains("0/%d" % Balance.GROWTH_TO_NEXT[1]), true, "el texto incluye el crecimiento")
	cities.advance(1000.0)
	_expect(errors, InfoPanel.describe_city(grid, cities, id).contains("nivel máximo"), true, "nivel máximo indicado")
	return errors


func _test_screen() -> Array:
	var errors: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	var scene: PackedScene = load(SCREEN_PATH)
	_expect(errors, scene != null, true, "la escena %s carga" % SCREEN_PATH)
	if scene == null:
		return errors
	var screen: Screen = scene.instantiate()
	tree.root.add_child(screen)
	var grid: TerritoryGrid = screen.grid
	var economy: Economy = screen.economy
	var cities: CityManager = screen.cities
	var label: Label = screen.get_node("%Economia")
	var message: Label = screen.get_node("%Mensaje")
	var button: Button = screen.get_node("%BotonFundar")
	var view = screen.get_node("%Mapa")
	_expect(errors, cities.city_count(), 4, "la pantalla arranca con 4 ciudades")
	_expect(errors, label.text, Screen.economy_summary(economy, cities, PLAYER), "el HUD muestra la economía del jugador")
	_expect(errors, label.text.contains("Dinero %d" % Balance.INITIAL_MONEY), true, "el HUD muestra el dinero inicial")
	_expect(errors, screen.is_processing(), false, "sin cambios no se recalcula")
	# Modo de fundación: botón y cancelación.
	_expect(errors, screen.founding_mode, false, "el modo empieza desactivado")
	button.pressed.emit()
	_expect(errors, screen.founding_mode, true, "el botón activa el modo")
	_expect(errors, button.text.contains("Esc"), true, "el botón indica cómo cancelar")
	button.pressed.emit()
	_expect(errors, screen.founding_mode, false, "pulsarlo de nuevo cancela")
	# Clic inválido: no cobra, no crea y el modo sigue activo.
	var owners_before := grid.copy_owner_data()
	economy.add(PLAYER, 500, 0)
	var money := economy.get_money(PLAYER)
	screen.begin_founding()
	view.pointer_pressed(view.cell_center_global(Vector2i(1, 1)))
	_expect(errors, [economy.get_money(PLAYER), cities.city_count()], [money, 4], "clic inválido: sin cobro ni ciudad")
	_expect(errors, message.text != "", true, "clic inválido: hay mensaje")
	_expect(errors, screen.founding_mode, true, "clic inválido: el modo sigue activo para reintentar")
	_expect(errors, view.selected_cell, Vector2i(-1, -1), "en modo fundación el clic no selecciona")
	# Clic válido: celda del jugador lejos de las ciudades.
	var target := Vector2i(-1, -1)
	for index in TerritoryGrid.CELL_COUNT:
		var cell := grid.index_to_coord(index)
		if grid.get_cell_owner(cell.x, cell.y) == PLAYER and cities.check_founding(PLAYER, cell) == CityManager.FOUND_OK:
			target = cell
			break
	_expect(errors, target != Vector2i(-1, -1), true, "existe una celda válida del jugador")
	view.pointer_pressed(view.cell_center_global(target))
	_expect(errors, cities.city_count(), 5, "clic válido: se funda la ciudad")
	_expect(errors, economy.get_money(PLAYER), money - Balance.FOUND_COST, "clic válido: se cobra el coste")
	_expect(errors, screen.founding_mode, false, "tras fundar termina el modo")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "el territorio no cambió")
	_expect(errors, label.text, Screen.economy_summary(economy, cities, PLAYER), "el HUD se actualiza tras fundar")
	# Fuera del modo el clic vuelve a seleccionar.
	view.pointer_pressed(view.cell_center_global(target))
	_expect(errors, view.selected_cell, target, "fuera del modo, el clic selecciona")
	screen.free()
	return errors


func _test_previous_suites_present() -> Array:
	var errors: Array = []
	for path: String in ["res://tests/territory_grid_tests.gd", "res://tests/territory_map_view_tests.gd",
			"res://tests/territory_conquest_tests.gd", "res://tests/territory_hud_tests.gd",
			"res://tests/run_territory_tests.tscn", "res://tests/run_view_tests.tscn",
			"res://tests/run_conquest_tests.tscn", "res://tests/run_hud_tests.tscn"]:
		_expect(errors, FileAccess.file_exists(path), true, "existe " + path)
	return errors
