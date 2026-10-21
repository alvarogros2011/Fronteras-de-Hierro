## Pruebas automáticas de ataques, combate determinista, invasiones progresivas, ocupación provisional
## y estado de guerra (hito 9). Sin plugins.
##
## Única definición de las comprobaciones; la usan:
##   - tests/test_combat.gd (consola, headless):
##       godot --headless --path . --script res://tests/test_combat.gd
##   - tests/run_combat_tests.tscn (editor de Godot, F6).
##
## Mapa controlado (load_from_data): tierra x 10..39, y 10..29; jugador x 10..24, IA 1 x 25..34,
## sin reclamar x 35..39; el resto es agua. Las 20 celdas de la IA 1 de la columna x = 25 tocan al
## jugador: sus celdas expuestas son 20 (3 tramos de frontera). Los mundos de prueba NO tienen ciudades
## (salvo que se pida), así que nadie crece, y todas las naciones tienen muchos recursos: nunca hay
## déficit y los soldados solo cambian por los combates. El tiempo avanza con CityManager.advance(n):
## n ticks exactos de 1 s de juego. Los números de los escenarios se contrastaron con una réplica en
## Python de las fórmulas (que no es una prueba de Godot ni la sustituye).
##
## run_all() devuelve [{"name": String, "errors": Array}, ...]   (errors vacío = PASS)
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Economy := preload("res://scripts/world/economy.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Population := preload("res://scripts/world/population.gd")
const Military := preload("res://scripts/world/military.gd")
const Occupation := preload("res://scripts/world/occupation.gd")
const WarState := preload("res://scripts/world/war_state.gd")
const Offensives := preload("res://scripts/world/offensives.gd")
const Combat := preload("res://scripts/world/combat.gd")
const Balance := preload("res://scripts/data/combat_balance.gd")
const EconomyBalance := preload("res://scripts/data/economy_balance.gd")
const MapView := preload("res://scripts/world/territory_map_view.gd")
const SectorLayer := preload("res://scripts/world/sector_layer_view.gd")
const InfoPanel := preload("res://scripts/ui/territory_info_panel.gd")
const MilitaryPanel := preload("res://scripts/ui/military_panel.gd")
const Screen := preload("res://scripts/ui/territory_screen.gd")

const PLAYER := TerritoryGrid.OWNER_PLAYER
const AI_1 := TerritoryGrid.OWNER_AI_1
const AI_2 := TerritoryGrid.OWNER_AI_2
const SCREEN_PATH := "res://scenes/territory_main.tscn"
## Tolerancia al comparar un color float con un píxel de la imagen del mapa. La imagen es RGBA8 y
## Image.set_pixel guarda cada canal en 8 bits TRUNCANDO (0.5525 se lee como 0.549 = 140/255), así que el
## píxel leído puede diferir del color esperado hasta 1/255 por canal. Un color incorrecto, una ocupación
## sin dibujar o una celda desfasada difieren mucho más (el tono de ocupación se aclara un 30 %).
const PIXEL_TOLERANCE := 1.0 / 255.0 + 0.0005
const CITY_A := Vector2i(12, 12)
const BORDER := Vector2i(24, 15)  # origen de los sectores de ataque del jugador (la IA 1 empieza en x = 25)

var _results: Array = []
var _signal_count: int = 0
var _signal_cells: Array = []


func run_all() -> Array:
	_results = []
	_run("fórmulas de combate puras: victoria, empate, derrota, bajas y etiquetas", _test_combat_math)
	_run("defensa local: un fondo común repartido entre tramos, sin contar a todos en cada punto", _test_defense_estimate)
	_run("la previsión es determinista, coincide con el resultado y no cambia nada", _test_forecast)
	_run("inicio, cancelación y reanudación de una ofensiva", _test_start_stop)
	_run("un sector sin soldados no ataca; sin soldados durante el ataque se detiene", _test_no_soldiers)
	_run("victoria: ocupa la celda sin cambiar el propietario y aplica las bajas reales", _test_victory)
	_run("derrota: aplica las bajas, detiene la ofensiva y no ocupa nada", _test_defeat)
	_run("el avance es de una celda por intervalo", _test_advance_timing)
	_run("invasión completa: sin soldados enemigos sigue ocupando y se detiene sin contacto", _test_full_invasion)
	_run("tierra sin reclamar: conquista explícita celda a celda, sin guerra, y se detiene en el agua", _test_unclaimed_and_water)
	_run("se detiene en el límite del mapa", _test_map_edge)
	_run("frente perdido, reanudación desde el origen y conquista posterior de lo ocupado", _test_front_lost_and_resume)
	_run("la ocupación es independiente de la propiedad y se puede consultar", _test_occupation)
	_run("estado de guerra explícito: empieza al atacar a otra nación y sobrevive a detener el ataque", _test_war_state)
	_run("economía: el ocupante no cobra, la ciudad ocupada suspende su producción y no se funda sobre ocupación", _test_economy_rules)
	_run("consistencia de población, soldados, reservas y sectores tras las bajas", _test_consistency)
	_run("varias ofensivas independientes en una frontera comparten un único fondo de defensa", _test_multiple_offensives)
	_run("el paso del tiempo, la economía y las ciudades no cambian territorio ni ocupación", _test_time_changes_nothing)
	_run("eliminar el sector borra la ofensiva pero no las ocupaciones; perder el origen la elimina", _test_sector_removal)
	_run("mapa: las celdas ocupadas se dibujan en tablero y se repintan sin cambiar el propietario", _test_map_view)
	_run("capa de sectores: la cifra del sector en ataque va junto a su frente", _test_sector_layer)
	_run("textos del panel de ataque, de guerra y de ocupación", _test_texts)
	_run("pantalla: previsión, confirmar ataque, avance, detener y reanudar con el mapa actualizado", _test_screen)
	_run("determinismo: el mismo estado y las mismas órdenes dan el mismo resultado", _test_determinism)
	_run("las suites anteriores y los archivos del hito siguen presentes", _test_files_present)
	return _results


func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	_results.append({"name": test_name, "errors": errors})


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


## ¿Coinciden los cuatro canales de dos colores dentro de PIXEL_TOLERANCE?
func _color_near(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) <= PIXEL_TOLERANCE and absf(actual.g - expected.g) <= PIXEL_TOLERANCE \
			and absf(actual.b - expected.b) <= PIXEL_TOLERANCE and absf(actual.a - expected.a) <= PIXEL_TOLERANCE


## Compara un color leído de la imagen (8 bits por canal) con el esperado (float) con tolerancia de 1/255.
func _expect_color(errors: Array, actual: Color, expected: Color, what: String) -> void:
	if not _color_near(actual, expected):
		errors.append("%s: se esperaba %s (±%.4f por canal) y salió %s" % [what, expected, PIXEL_TOLERANCE, actual])


func _count_signal() -> void:
	_signal_count += 1


func _collect_cells(cells: Array) -> void:
	_signal_cells.append_array(cells)


# ---------------------------------------------------------------------------
# Datos controlados
# ---------------------------------------------------------------------------

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


## Como _make_grid, pero con dos celdas sin reclamar entre el jugador y la IA 1 en la fila y = 15:
## (25, 15) y (26, 15). El jugador llega a ellas por conquista y la IA 1 empieza en (27, 15).
func _make_gap_grid() -> TerritoryGrid:
	var base := _make_grid()
	var owners := base.copy_owner_data()
	owners[15 * TerritoryGrid.WIDTH + 25] = TerritoryGrid.OWNER_NONE
	owners[15 * TerritoryGrid.WIDTH + 26] = TerritoryGrid.OWNER_NONE
	var grid := TerritoryGrid.new()
	grid.load_from_data(base.copy_terrain_data(), owners)
	return grid


## Una sola fila de tierra (y = 100, x = 300..319, hasta el borde del mapa); el jugador posee x 310..314.
func _make_strip_grid() -> TerritoryGrid:
	var terrain := PackedByteArray()
	terrain.resize(TerritoryGrid.CELL_COUNT)
	terrain.fill(TerritoryGrid.TERRAIN_WATER)
	var owners := PackedByteArray()
	owners.resize(TerritoryGrid.CELL_COUNT)
	owners.fill(TerritoryGrid.OWNER_NONE)
	for x in range(300, 320):
		terrain[100 * TerritoryGrid.WIDTH + x] = TerritoryGrid.TERRAIN_LAND
		if x >= 310 and x <= 314:
			owners[100 * TerritoryGrid.WIDTH + x] = PLAYER
	var grid := TerritoryGrid.new()
	grid.load_from_data(terrain, owners)
	return grid


## Mundo completo: cuadrícula, economía (muchos recursos: sin déficit), ciudades (ninguna salvo que
## `with_city`: la del jugador en CITY_A), población inyectada, sectores, ocupación, guerra y ofensivas.
func _make_world(initial: Dictionary, grid: TerritoryGrid = null, with_city: bool = false) -> Dictionary:
	if grid == null:
		grid = _make_grid()
	var economy := Economy.new(grid.get_nation_ids())
	for nation_id: int in grid.get_nation_ids():
		economy.add(nation_id, 0, 100000)
	var cities := CityManager.new(grid, economy)
	var occupation := Occupation.new(grid)
	cities.set_occupation(occupation)
	if with_city:
		economy.add(PLAYER, 1000, 0)
		cities.found_city(PLAYER, CITY_A)
	var population := Population.new(cities, economy, grid.get_nation_ids(), initial)
	var military := Military.new(grid, population)
	var wars := WarState.new()
	var offensives := Offensives.new(grid, population, military, cities, occupation, wars)
	# Escenarios celda a celda del hito 9: frente de una sola celda (el frente ancho del hito 11 se prueba en
	# tests/gameplay_tests.gd).
	offensives.front_half_width = 0
	return {"grid": grid, "economy": economy, "cities": cities, "pop": population, "mil": military,
			"occ": occupation, "wars": wars, "off": offensives}


## Mundo de batalla: el jugador (20 soldados) frente a la IA 1 (6 soldados) y un sector del jugador (id 1)
## en BORDER hacia el este con `soldiers` soldados.
func _battle_world(player_soldiers: int = 10, ai_soldiers: int = 6) -> Dictionary:
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": ai_soldiers}})
	var mil: Military = world["mil"]
	var result := mil.create_sector(PLAYER, BORDER, Military.DIR_EAST, player_soldiers)
	world["sid"] = result["id"]
	return world


func _ticks(world: Dictionary, ticks: int) -> void:
	var cities: CityManager = world["cities"]
	cities.advance(float(ticks))


## Todo lo que debe ser reproducible, en un Dictionary comparable.
func _snapshot(world: Dictionary) -> Dictionary:
	var grid: TerritoryGrid = world["grid"]
	var pop: Population = world["pop"]
	var mil: Military = world["mil"]
	var occ: Occupation = world["occ"]
	var wars: WarState = world["wars"]
	var off: Offensives = world["off"]
	var nations: Dictionary = {}
	for nation_id: int in grid.get_nation_ids():
		nations[nation_id] = [pop.workers(nation_id), pop.soldiers(nation_id), mil.assigned_soldiers(nation_id), mil.available_soldiers(nation_id)]
	var sectors: Array = []
	var offensives: Array = []
	for sector_id: int in mil.get_sector_ids():
		sectors.append(mil.get_sector(sector_id))
		offensives.append(off.get_offensive(sector_id))
	var occupied: Array = []
	for cell: Vector2i in occ.get_cells():
		occupied.append([cell, occ.occupier_at(cell), occ.official_owner_at(cell)])
	return {"nations": nations, "sectors": sectors, "offensives": offensives, "occupied": occupied,
			"wars": wars.war_count(), "owners": grid.copy_owner_data()}


# ---------------------------------------------------------------------------
# Pruebas
# ---------------------------------------------------------------------------

func _test_combat_math() -> Array:
	var errors: Array = []
	# Constantes de equilibrio centralizadas, coherentes y enteras.
	_expect(errors, Balance.ADVANCE_INTERVAL_TICKS > 0, true, "el intervalo de avance es positivo")
	_expect(errors, Balance.DEFENSE_BONUS_PERCENT >= 100, true, "la bonificación del defensor no penaliza")
	_expect(errors, Balance.WINNER_LOSS_PERCENT < Balance.LOSER_LOSS_PERCENT, true, "el vencedor pierde menos que el vencido")
	_expect(errors, Balance.DEFENSE_RATIO_PERMILLE < Balance.ADVANTAGE_RATIO_PERMILLE, true, "los umbrales de las etiquetas están ordenados")
	_expect(errors, Balance.CELLS_PER_FRONT > 0 and Balance.MIN_LOCAL_DEFENSE >= 1, true, "tramos y defensa mínima válidos")
	_expect(errors, [Combat.ceil_percent(4, 35), Combat.ceil_percent(0, 35), Combat.ceil_percent(1, 70), Combat.ceil_percent(10, 50)], [2, 0, 1, 5], "porcentajes redondeados hacia arriba")
	# Victoria clara.
	var win := Combat.resolve(10, 4)
	_expect(errors, [win["attacker_wins"], win["attacker_losses"], win["defender_losses"], win["attackers_after"]], [true, 2, 3, 8], "10 contra 4: victoria con 2 y 3 bajas")
	_expect(errors, [win["ratio_permille"], win["category"]], [2083, Combat.CATEGORY_ADVANTAGE], "10 contra 4: relación 2,08 y ventaja atacante")
	# Victoria por poco y la etiqueta «equilibrado».
	var narrow := Combat.resolve(5, 4)
	_expect(errors, [narrow["attacker_wins"], narrow["ratio_permille"], narrow["category"]], [true, 1041, Combat.CATEGORY_BALANCED], "5 contra 4 (defensa efectiva 4,8): gana por poco")
	# Empate exacto: 6 contra 5 (defensa efectiva 6,0) lo gana la defensa; 7 contra 5 lo gana el atacante.
	_expect(errors, [Combat.attacker_wins(6, 5), Combat.attacker_wins(7, 5)], [false, true], "un empate lo gana la defensa")
	_expect(errors, Combat.ratio_permille(6, 5), 1000, "fuerzas efectivas iguales: relación 1,0")
	# Derrota.
	var loss := Combat.resolve(4, 4)
	_expect(errors, [loss["attacker_wins"], loss["attacker_losses"], loss["defender_losses"], loss["attackers_after"], loss["category"]], [false, 3, 2, 1, Combat.CATEGORY_BALANCED], "4 contra 4: derrota equilibrada")
	var crushed := Combat.resolve(3, 4)
	_expect(errors, [crushed["attacker_wins"], crushed["attacker_losses"], crushed["defender_losses"], crushed["attackers_after"], crushed["category"]], [false, 3, 2, 0, Combat.CATEGORY_DEFENSE], "3 contra 4: defensa superior y el atacante cae entero")
	# Umbrales de las etiquetas.
	_expect(errors, [Combat.category(1500), Combat.category(1499), Combat.category(800), Combat.category(799)],
			[Combat.CATEGORY_ADVANTAGE, Combat.CATEGORY_BALANCED, Combat.CATEGORY_BALANCED, Combat.CATEGORY_DEFENSE], "umbrales 1,5 y 0,8")
	_expect(errors, [Combat.ratio_permille(9, 5), Combat.ratio_permille(24, 25), Combat.ratio_permille(23, 25)], [1500, 800, 766], "relaciones en los umbrales")
	# Sin defensa: gana sin bajas; sin atacantes no hay victoria.
	var free := Combat.resolve(1, 0)
	_expect(errors, [free["attacker_wins"], free["attacker_losses"], free["defender_losses"], free["ratio_permille"], free["category"]], [true, 0, 0, Combat.NO_RESISTANCE_RATIO, Combat.CATEGORY_ADVANTAGE], "sin defensa")
	_expect(errors, [Combat.attacker_wins(0, 0), Combat.attacker_wins(0, 3)], [false, false], "sin atacantes no se gana")
	# Las bajas nunca superan a los soldados que hay.
	for attackers in range(0, 40):
		for defense in range(0, 40):
			var result := Combat.resolve(attackers, defense)
			if result["attacker_losses"] > attackers or result["defender_losses"] > defense or result["attacker_losses"] < 0 or result["defender_losses"] < 0:
				errors.append("bajas imposibles con %d contra %d: %s" % [attackers, defense, result])
				break
			if result["attackers_after"] != attackers - result["attacker_losses"]:
				errors.append("atacantes restantes incoherentes con %d contra %d" % [attackers, defense])
				break
	# Pureza: mismas entradas, mismas salidas.
	_expect(errors, Combat.resolve(17, 6) == Combat.resolve(17, 6), true, "resolve es determinista")
	return errors


func _test_defense_estimate() -> Array:
	var errors: Array = []
	_expect(errors, [Combat.front_count(0), Combat.front_count(1), Combat.front_count(8), Combat.front_count(9), Combat.front_count(20), Combat.front_count(25)], [1, 1, 1, 2, 3, 4], "tramos = techo(celdas / 8), al menos 1")
	_expect(errors, [Combat.defense_per_front(6, 20), Combat.defense_per_front(6, 0), Combat.defense_per_front(0, 20), Combat.defense_per_front(1, 100), Combat.defense_per_front(10, 24), Combat.defense_per_front(30, 80)],
			[2, 6, 0, 1, 4, 3], "defensa por tramo (con mínimo 1 si hay soldados y 0 si no hay)")
	# El fondo común no se cuenta entero en cada tramo: la suma de todos los tramos nunca se pasa de
	# los soldados más el redondeo, y con varios tramos cada uno tiene menos que el total.
	for soldiers in range(0, 61):
		for exposed in [0, 1, 7, 8, 9, 20, 64, 100, 400]:
			var fronts := Combat.front_count(exposed)
			var local := Combat.defense_per_front(soldiers, exposed)
			if local > soldiers:
				errors.append("la defensa local (%d) supera a los soldados (%d)" % [local, soldiers])
			if soldiers > 0 and local * fronts >= soldiers + fronts:
				errors.append("se cuenta más de una vez la misma fuerza: %d soldados, %d celdas expuestas, defensa %d en %d tramos" % [soldiers, exposed, local, fronts])
			if soldiers > 1 and fronts > 1 and local >= soldiers:
				errors.append("con %d tramos un solo tramo tiene todos los soldados (%d)" % [fronts, soldiers])
	# Sobre el mapa controlado: la IA 1 tiene 20 celdas expuestas (su columna x = 25 toca al jugador).
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var grid: TerritoryGrid = world["grid"]
	_expect(errors, [off.exposed_cells(AI_1), off.exposed_cells(PLAYER)], [20, 20], "celdas expuestas de cada bando")
	_expect(errors, off.exposed_cells(AI_2), 0, "una nación sin territorio no tiene celdas expuestas")
	var info := off.evaluate(PLAYER, 10, Vector2i(25, 15))
	_expect(errors, [info["kind"], info["defender"], info["defender_soldiers"], info["exposed"], info["fronts"], info["defense"]], [Offensives.KIND_ENEMY, AI_1, 6, 20, 3, 2], "defensa estimada de la IA 1: 6 soldados / 3 tramos")
	# La estimación sale de los soldados REALES: si la IA tiene más, defiende más.
	var strong := _battle_world(10, 30)
	_expect(errors, strong["off"].evaluate(PLAYER, 10, Vector2i(25, 15))["defense"], 10, "con 30 soldados: 10 por tramo")
	var none := _battle_world(10, 0)
	var undefended: Dictionary = none["off"].evaluate(PLAYER, 10, Vector2i(25, 15))
	_expect(errors, [undefended["defense"], undefended["attacker_wins"], undefended["attacker_losses"]], [0, true, 0], "sin soldados no hay defensa")
	# Tierra sin reclamar: UNCLAIMED_DEFENSE (sin resistencia por defecto).
	var open_ground: Dictionary = off.evaluate(AI_1, 5, Vector2i(35, 15))
	_expect(errors, [open_ground["kind"], open_ground["defense"], open_ground["combat"]], [Offensives.KIND_UNCLAIMED, Balance.UNCLAIMED_DEFENSE, true], "tierra sin reclamar")
	# Las celdas expuestas se guardan hasta que cambian los propietarios: una celda del jugador dentro de
	# la IA 1 expone sus 4 vecinas.
	_expect(errors, off.exposed_cells(AI_1), 20, "valor guardado")
	grid.try_set_owner(30, 15, PLAYER)
	_expect(errors, off.exposed_cells(AI_1), 24, "al cambiar un propietario se recalcula (20 + 4 vecinas de la celda nueva)")
	return errors


func _test_forecast() -> Array:
	var errors: Array = []
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var sid: int = world["sid"]
	var before := _snapshot(world)
	var fc := off.forecast(sid)
	_expect(errors, [fc["attackers"], fc["defense"], fc["defender"], fc["kind"], fc["target"]], [10, 2, AI_1, Offensives.KIND_ENEMY, Vector2i(25, 15)], "datos de la previsión")
	_expect(errors, [fc["attacker_wins"], fc["attacker_losses"], fc["defender_losses"], fc["attackers_after"]], [true, 1, 2, 9], "resultado previsto")
	_expect(errors, [fc["ratio_permille"], fc["category"]], [4166, Combat.CATEGORY_ADVANTAGE], "relación y etiqueta")
	_expect(errors, off.forecast(sid) == fc, true, "pedir la previsión dos veces da lo mismo")
	_expect(errors, _snapshot(world) == before, true, "calcular la previsión no cambia nada")
	_expect(errors, off.forecast(999).is_empty(), true, "un sector inexistente no tiene previsión")
	# La previsión usa solo los soldados asignados al sector.
	var mil: Military = world["mil"]
	mil.set_sector_soldiers(sid, 3)
	var weak := off.forecast(sid)
	_expect(errors, [weak["attackers"], weak["attacker_wins"], weak["attacker_losses"], weak["defender_losses"], weak["category"]], [3, true, 1, 2, Combat.CATEGORY_BALANCED], "con 3 soldados: gana por poco (3 contra 2 de defensa, relación 1,25)")
	mil.set_sector_soldiers(sid, 2)
	var tied := off.forecast(sid)
	_expect(errors, [tied["attackers"], tied["attacker_wins"], tied["category"]], [2, false, Combat.CATEGORY_BALANCED], "con 2 soldados: derrota prevista")
	mil.set_sector_soldiers(sid, 10)
	# La previsión coincide con lo que ocurre de verdad en el primer avance.
	var expected := off.forecast(sid)
	var player_before := [world["pop"].soldiers(PLAYER), world["pop"].soldiers(AI_1)]
	off.start_offensive(sid)
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	var clash: Dictionary = off.get_offensive(sid)["last_clash"]
	_expect(errors, [clash["attacker_losses"], clash["defender_losses"], clash["won"], clash["defense"], clash["attackers"]],
			[expected["attacker_losses"], expected["defender_losses"], expected["attacker_wins"], expected["defense"], expected["attackers"]], "el combate real coincide con la previsión")
	_expect(errors, [world["pop"].soldiers(PLAYER), world["pop"].soldiers(AI_1)], [player_before[0] - expected["attacker_losses"], player_before[1] - expected["defender_losses"]], "las bajas reales son las previstas")
	# Una previsión que dice derrota se cumple.
	var losing := _battle_world(3, 12)
	var lfc: Dictionary = losing["off"].forecast(losing["sid"])
	_expect(errors, [lfc["attackers"], lfc["defense"], lfc["attacker_wins"], lfc["attacker_losses"], lfc["defender_losses"], lfc["category"]], [3, 4, false, 3, 2, Combat.CATEGORY_DEFENSE], "previsión de derrota")
	losing["off"].start_offensive(losing["sid"])
	_ticks(losing, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [losing["off"].sector_state(losing["sid"]), losing["off"].get_offensive(losing["sid"])["reason"]], [Offensives.STATE_STOPPED, Offensives.STOP_DEFEAT], "y la derrota se cumple")
	return errors


func _test_start_stop() -> Array:
	var errors: Array = []
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var sid: int = world["sid"]
	_signal_count = 0
	off.changed.connect(_count_signal)
	_expect(errors, [off.sector_state(sid), off.is_active(sid), off.active_count(), off.get_offensive(sid)], [Offensives.STATE_READY, false, 0, {}], "un sector recién creado está preparado")
	_expect(errors, off.stop_offensive(sid), false, "no se puede detener lo que no ataca")
	# Inicio.
	var result := off.start_offensive(sid)
	_expect(errors, [result["ok"], result["error"]], [true, Offensives.START_OK], "inicio válido")
	_expect(errors, [off.sector_state(sid), off.is_active(sid), off.active_count(PLAYER), off.active_count(AI_1)], [Offensives.STATE_ACTIVE, true, 1, 0], "el sector pasa a atacar")
	var data := off.get_offensive(sid)
	_expect(errors, [data["front"], data["next_cell"], data["countdown"], data["reason"]], [BORDER, Vector2i(25, 15), Balance.ADVANCE_INTERVAL_TICKS, Offensives.STOP_NONE], "el frente empieza en el origen y apunta a la celda contigua")
	_expect(errors, _signal_count >= 1, true, "iniciar emite changed")
	# No crea un ejército nuevo: los soldados siguen siendo los del sector.
	_expect(errors, [mil.get_sector(sid)["soldiers"], world["pop"].soldiers(PLAYER), mil.assigned_soldiers(PLAYER)], [10, 20, 10], "atacar no crea ni mueve soldados")
	# Ofensivas incompatibles desde el mismo sector.
	var again := off.start_offensive(sid)
	_expect(errors, [again["ok"], again["error"]], [false, Offensives.START_ERR_ALREADY_ACTIVE], "no se puede iniciar otra ofensiva en el mismo sector")
	_expect(errors, off.active_count(), 1, "sigue habiendo una sola")
	# Un sector duplicado (mismo origen y dirección) ya lo impedía el hito 8.
	_expect(errors, mil.create_sector(PLAYER, BORDER, Military.DIR_EAST)["error"], Military.SECTOR_ERR_DUPLICATE, "no se puede crear otro sector igual")
	# Detener.
	_ticks(world, 2)
	_expect(errors, off.stop_offensive(sid), true, "se puede detener una ofensiva activa")
	_expect(errors, [off.sector_state(sid), off.is_active(sid), off.get_offensive(sid)["reason"]], [Offensives.STATE_STOPPED, false, Offensives.STOP_MANUAL], "detenida por el jugador")
	_expect(errors, off.stop_offensive(sid), false, "detener dos veces no hace nada")
	_expect(errors, [world["occ"].count(), world["pop"].soldiers(PLAYER), world["pop"].soldiers(AI_1)], [0, 20, 6], "detener antes de combatir no deja bajas ni ocupación")
	_ticks(world, 30)
	_expect(errors, [world["occ"].count(), world["pop"].soldiers(PLAYER), off.get_offensive(sid)["front"]], [0, 20, BORDER], "una ofensiva detenida no avanza")
	# Reanudar.
	var resumed := off.start_offensive(sid)
	_expect(errors, [resumed["ok"], off.sector_state(sid), off.get_offensive(sid)["reason"]], [true, Offensives.STATE_ACTIVE, Offensives.STOP_NONE], "se reanuda")
	# Errores de orden.
	var unknown := off.start_offensive(999)
	_expect(errors, [unknown["ok"], unknown["error"]], [false, Offensives.START_ERR_UNKNOWN_SECTOR], "sector inexistente")
	_expect(errors, off.stop_offensive(999), false, "detener un sector inexistente")
	_expect(errors, off.current_target(999), Offensives.NO_CELL, "sin sector no hay objetivo")
	# Detener todas las de una nación.
	var second: int = mil.create_sector(PLAYER, Vector2i(24, 20), Military.DIR_EAST, 3)["id"]
	off.start_offensive(second)
	_expect(errors, [off.active_count(PLAYER), off.stop_all(PLAYER), off.active_count(PLAYER)], [2, 2, 0], "stop_all detiene todas las ofensivas de la nación")
	# Hacia el agua no se puede ni crear el sector (hito 8), así que no hay ofensiva posible.
	var wet := mil.create_sector(PLAYER, Vector2i(10, 15), Military.DIR_WEST, 0)
	_expect(errors, [wet["ok"], wet["error"]], [false, Military.SECTOR_ERR_TARGET_WATER], "el hito 8 ya impide apuntar al agua")
	return errors


func _test_no_soldiers() -> Array:
	var errors: Array = []
	var world := _battle_world(0, 6)
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var sid: int = world["sid"]
	var rejected := off.start_offensive(sid)
	_expect(errors, [rejected["ok"], rejected["error"], off.sector_state(sid), world["wars"].war_count()], [false, Offensives.START_ERR_NO_SOLDIERS, Offensives.STATE_READY, 0], "un sector sin soldados no ataca ni declara la guerra")
	_expect(errors, off.get_offensive(sid), {}, "y no deja rastro")
	# No se pueden comprometer más soldados que los asignados: la fuerza es la asignación del sector.
	mil.set_sector_soldiers(sid, 4)
	_expect(errors, off.forecast(sid)["attackers"], 4, "la fuerza atacante es la asignada al sector")
	_expect(errors, mil.set_sector_soldiers(sid, 999), Military.ASSIGN_ERR_NOT_ENOUGH, "no se pueden asignar más soldados de los disponibles")
	off.start_offensive(sid)
	# Quitar los soldados durante el ataque lo detiene al instante.
	mil.set_sector_soldiers(sid, 0)
	_expect(errors, [off.sector_state(sid), off.get_offensive(sid)["reason"]], [Offensives.STATE_STOPPED, Offensives.STOP_NO_SOLDIERS], "sin soldados la ofensiva se detiene")
	var restart := off.start_offensive(sid)
	_expect(errors, restart["error"], Offensives.START_ERR_NO_SOLDIERS, "y no se puede reanudar sin soldados")
	# Deserción o bajas ajenas al combate (Population) también detienen la ofensiva.
	var other := _battle_world(5, 6)
	var ooff: Offensives = other["off"]
	var opop: Population = other["pop"]
	ooff.start_offensive(other["sid"])
	opop.remove_soldiers(PLAYER, 20)
	_expect(errors, [other["mil"].get_sector(other["sid"])["soldiers"], ooff.sector_state(other["sid"]), ooff.get_offensive(other["sid"])["reason"]], [0, Offensives.STATE_STOPPED, Offensives.STOP_NO_SOLDIERS], "si la nación se queda sin soldados, el sector se queda a 0 y se detiene")
	# Lo mismo para la nación defensora con una ofensiva propia.
	var duel := _battle_world(5, 6)
	var dmil: Military = duel["mil"]
	var ai_sector: int = dmil.create_sector(AI_1, Vector2i(25, 20), Military.DIR_WEST, 3)["id"]
	duel["off"].start_offensive(ai_sector)
	_expect(errors, [duel["off"].is_active(ai_sector), duel["wars"].at_war(PLAYER, AI_1)], [true, true], "la IA también puede atacar con sus sectores (mismas reglas)")
	duel["pop"].remove_soldiers(AI_1, 6)
	_expect(errors, [dmil.get_sector(ai_sector)["soldiers"], duel["off"].get_offensive(ai_sector)["reason"]], [0, Offensives.STOP_NO_SOLDIERS], "el defensor que se queda sin soldados detiene su ofensiva")
	_expect(errors, duel["off"].is_active(duel["sid"]), false, "la ofensiva del otro sector no se tocó (no estaba iniciada)")
	return errors


func _test_victory() -> Array:
	var errors: Array = []
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var occ: Occupation = world["occ"]
	var wars: WarState = world["wars"]
	var grid: TerritoryGrid = world["grid"]
	var sid: int = world["sid"]
	var owners_before := grid.copy_owner_data()
	var terrain_before := grid.copy_terrain_data()
	_expect(errors, wars.at_war(PLAYER, AI_1), false, "antes de atacar no hay guerra")
	off.start_offensive(sid)
	_expect(errors, [wars.at_war(PLAYER, AI_1), wars.at_war(AI_1, PLAYER)], [true, true], "atacar el territorio de otra nación inicia la guerra (simétrica)")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	var cell := Vector2i(25, 15)
	var data := off.get_offensive(sid)
	_expect(errors, [data["occupied"], data["claimed"], data["front"], data["next_cell"]], [1, 0, cell, Vector2i(26, 15)], "ocupó una celda y el frente avanzó")
	_expect(errors, [data["attacker_losses"], data["defender_losses"], data["last_clash"]["won"]], [1, 2, true], "bajas y resultado del enfrentamiento")
	# La propiedad oficial no cambia; la ocupación es aparte.
	_expect(errors, grid.get_cell_owner(cell.x, cell.y), AI_1, "el propietario oficial sigue siendo la IA 1")
	_expect(errors, [occ.occupier_at(cell), occ.official_owner_at(cell), occ.is_occupied(cell), occ.count(PLAYER)], [PLAYER, AI_1, true, 1], "la ocupación registra al jugador como ocupante")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ningún propietario cambió")
	_expect(errors, grid.copy_terrain_data() == terrain_before, true, "el terreno tampoco")
	# Bajas reales.
	_expect(errors, [pop.soldiers(PLAYER), mil.get_sector(sid)["soldiers"], mil.assigned_soldiers(PLAYER), mil.available_soldiers(PLAYER)], [19, 9, 9, 10], "el atacante pierde 1 soldado de la población y del sector")
	_expect(errors, pop.soldiers(AI_1), 4, "el defensor pierde 2 soldados")
	_expect(errors, [pop.workers(PLAYER), pop.workers(AI_1)], [30, 30], "los trabajadores no se tocan")
	_expect(errors, [pop.total_population(PLAYER), pop.total_population(AI_1)], [49, 34], "la población total baja exactamente lo que cayeron los soldados")
	# La ofensiva sigue: la siguiente celda también.
	_expect(errors, off.is_active(sid), true, "tras vencer, la ofensiva continúa")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [occ.get_cells(PLAYER), off.get_offensive(sid)["front"]], [[Vector2i(25, 15), Vector2i(26, 15)], Vector2i(26, 15)], "la segunda celda, a continuación de la primera")
	_expect(errors, [pop.soldiers(PLAYER), pop.soldiers(AI_1), mil.get_sector(sid)["soldiers"]], [18, 2, 8], "bajas del segundo enfrentamiento (defensa 2 otra vez)")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ninguna ocupación cambia el propietario")
	return errors


func _test_defeat() -> Array:
	var errors: Array = []
	var world := _battle_world(3, 12)
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var occ: Occupation = world["occ"]
	var grid: TerritoryGrid = world["grid"]
	var sid: int = world["sid"]
	var owners_before := grid.copy_owner_data()
	off.start_offensive(sid)
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	var data := off.get_offensive(sid)
	_expect(errors, [data["state"], data["reason"], data["front"]], [Offensives.STATE_STOPPED, Offensives.STOP_DEFEAT, BORDER], "la derrota detiene la ofensiva y el frente no avanza")
	_expect(errors, [data["occupied"], occ.count(), data["last_clash"]["won"]], [0, 0, false], "no se ocupa nada")
	_expect(errors, [data["attacker_losses"], data["defender_losses"]], [3, 2], "bajas de la derrota")
	_expect(errors, [pop.soldiers(PLAYER), mil.get_sector(sid)["soldiers"], mil.available_soldiers(PLAYER), pop.soldiers(AI_1)], [17, 0, 17, 10], "las bajas son reales: el sector cae a 0 y la reserva sigue válida")
	_expect(errors, [pop.workers(PLAYER), pop.workers(AI_1)], [30, 30], "los trabajadores no se tocan")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "una derrota no cambia territorio")
	_expect(errors, world["wars"].at_war(PLAYER, AI_1), true, "la guerra empezó al atacar y no termina por perder")
	# Con el sector sin soldados no se puede reintentar; reforzado, sí, y desde el mismo frente.
	_expect(errors, off.start_offensive(sid)["error"], Offensives.START_ERR_NO_SOLDIERS, "sin soldados no se reintenta")
	_expect(errors, mil.set_sector_soldiers(sid, 10), Military.ASSIGN_OK, "se refuerza el sector con la reserva")
	_expect(errors, off.start_offensive(sid)["ok"], true, "y se reanuda")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [occ.count(), pop.soldiers(PLAYER), pop.soldiers(AI_1), mil.get_sector(sid)["soldiers"]], [1, 15, 7, 8], "reforzado vence a 4 de defensa: 2 y 3 bajas")
	_expect(errors, off.get_offensive(sid)["attacker_losses"], 5, "las cifras de bajas se acumulan entre intentos")
	return errors


func _test_advance_timing() -> Array:
	var errors: Array = []
	var world := _battle_world(10, 0)
	var off: Offensives = world["off"]
	var occ: Occupation = world["occ"]
	var sid: int = world["sid"]
	var interval := Balance.ADVANCE_INTERVAL_TICKS
	off.start_offensive(sid)
	_expect(errors, off.get_offensive(sid)["countdown"], interval, "la cuenta atrás empieza en el intervalo")
	_ticks(world, interval - 1)
	_expect(errors, [occ.count(), off.get_offensive(sid)["countdown"], off.get_offensive(sid)["front"]], [0, 1, BORDER], "un tick antes del intervalo no ha avanzado nada")
	_ticks(world, 1)
	_expect(errors, [occ.count(), off.get_offensive(sid)["front"], off.get_offensive(sid)["countdown"]], [1, Vector2i(25, 15), interval], "al cumplirse el intervalo avanza exactamente una celda")
	for step in range(2, 6):
		_ticks(world, interval)
		_expect(errors, [occ.count(), off.get_offensive(sid)["front"]], [step, Vector2i(24 + step, 15)], "una celda más por intervalo (paso %d)" % step)
	# Un avance por tick fraccionado da lo mismo (el tiempo se mide en ticks, no en fotogramas).
	var fine := _battle_world(10, 0)
	fine["off"].start_offensive(fine["sid"])
	for frame in 60:
		fine["cities"].advance(0.25)
	_expect(errors, [fine["occ"].count(), fine["off"].get_offensive(fine["sid"])["front"]], [5, Vector2i(29, 15)], "15 s en fotogramas de 0,25 s: 5 celdas")
	_expect(errors, fine["occ"].get_cells() == occ.get_cells(), true, "el mismo resultado que con ticks enteros")
	return errors


func _test_full_invasion() -> Array:
	var errors: Array = []
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var occ: Occupation = world["occ"]
	var grid: TerritoryGrid = world["grid"]
	var sid: int = world["sid"]
	var owners_before := grid.copy_owner_data()
	off.start_offensive(sid)
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS * 4)
	_expect(errors, [pop.soldiers(AI_1), pop.soldiers(PLAYER), mil.get_sector(sid)["soldiers"], occ.count()], [0, 16, 6, 4], "cuatro enfrentamientos agotan a la IA 1 (4 y 6 bajas)")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS * 6)
	_expect(errors, [occ.count(), off.get_offensive(sid)["front"], off.is_active(sid)], [10, Vector2i(34, 15), true], "sin defensores sigue ocupando sin bajas hasta el fondo de su territorio")
	_expect(errors, [pop.soldiers(PLAYER), off.get_offensive(sid)["attacker_losses"], off.get_offensive(sid)["defender_losses"]], [16, 4, 6], "y sin más bajas")
	var line: Array = []
	for x in range(25, 35):
		line.append(Vector2i(x, 15))
	_expect(errors, occ.get_cells(PLAYER), line, "las celdas ocupadas forman una línea continua desde el origen")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [off.sector_state(sid), off.get_offensive(sid)["reason"], off.get_offensive(sid)["front"]], [Offensives.STATE_STOPPED, Offensives.STOP_CANNOT_CLAIM, Vector2i(34, 15)], "al llegar a tierra sin reclamar sin contacto con territorio propio se detiene")
	_expect(errors, [grid.get_cell_owner(35, 15), occ.count()], [TerritoryGrid.OWNER_NONE, 10], "no reclamó nada y conserva lo ocupado")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "toda la invasión se hizo sin cambiar un solo propietario")
	_expect(errors, off.forecast(sid)["blocked"], true, "la previsión también avisa de que no se puede avanzar")
	var again := off.start_offensive(sid)
	_expect(errors, [again["ok"], again["error"], again["reason"]], [false, Offensives.START_ERR_BLOCKED, Offensives.STOP_CANNOT_CLAIM], "reanudar sigue bloqueado")
	return errors


func _test_unclaimed_and_water() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 10}})
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var occ: Occupation = world["occ"]
	var grid: TerritoryGrid = world["grid"]
	var wars: WarState = world["wars"]
	var sid: int = mil.create_sector(AI_1, Vector2i(34, 15), Military.DIR_EAST, 4)["id"]
	var owners_before := grid.copy_owner_data()
	var ai_cells := grid.count_owned_by(AI_1)
	_signal_count = 0
	_signal_cells = []
	grid.ownership_changed.connect(_count_signal)
	off.territory_changed.connect(_collect_cells)
	_expect(errors, off.forecast(sid)["kind"], Offensives.KIND_UNCLAIMED, "el objetivo es tierra sin reclamar")
	off.start_offensive(sid)
	_expect(errors, wars.war_count(), 0, "atacar tierra sin reclamar no declara ninguna guerra")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [grid.get_cell_owner(35, 15), grid.get_cell_owner(36, 15), occ.count()], [AI_1, TerritoryGrid.OWNER_NONE, 0], "la primera celda se conquistó de forma explícita (no se ocupa)")
	_expect(errors, [off.get_offensive(sid)["claimed"], off.get_offensive(sid)["front"], _signal_cells], [1, Vector2i(35, 15), [Vector2i(35, 15)]], "conquista registrada y anunciada para repintar")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS * 4)
	var claimed: Array = []
	for x in range(35, 40):
		claimed.append(Vector2i(x, 15))
	_expect(errors, _signal_cells, claimed, "cinco celdas conquistadas en orden")
	_expect(errors, [grid.count_owned_by(AI_1), _signal_count], [ai_cells + 5, 5], "solo esas cinco celdas cambiaron y cada conquista emitió una vez ownership_changed")
	var changed_elsewhere := 0
	var now := grid.copy_owner_data()
	for index in TerritoryGrid.CELL_COUNT:
		if now[index] != owners_before[index] and not claimed.has(grid.index_to_coord(index)):
			changed_elsewhere += 1
	_expect(errors, changed_elsewhere, 0, "ninguna otra celda cambió")
	_expect(errors, [pop.soldiers(AI_1), mil.get_sector(sid)["soldiers"], off.get_offensive(sid)["attacker_losses"]], [10, 4, 0], "sin resistencia no hay bajas")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [off.sector_state(sid), off.get_offensive(sid)["reason"], off.get_offensive(sid)["front"]], [Offensives.STATE_STOPPED, Offensives.STOP_WATER, Vector2i(39, 15)], "el agua detiene la ofensiva")
	_expect(errors, [grid.is_land(40, 15), grid.get_cell_owner(40, 15)], [false, TerritoryGrid.OWNER_NONE], "no atravesó el agua ni reclamó nada más")
	_expect(errors, [wars.war_count(), occ.count()], [0, 0], "al final sigue sin haber guerra ni ocupaciones")
	# Lo conquistado ya es propio: marchar por ahí no es un enfrentamiento.
	var info := off.evaluate(AI_1, 4, Vector2i(35, 15))
	_expect(errors, [info["kind"], info["blocked"], info["combat"]], [Offensives.KIND_OWN, false, false], "la celda conquistada es territorio propio")
	return errors


func _test_map_edge() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 10, "soldiers": 10}}, _make_strip_grid())
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var grid: TerritoryGrid = world["grid"]
	var sid: int = mil.create_sector(PLAYER, Vector2i(314, 100), Military.DIR_EAST, 5)["id"]
	off.start_offensive(sid)
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS * 5)
	_expect(errors, [off.get_offensive(sid)["claimed"], off.get_offensive(sid)["front"], grid.get_cell_owner(319, 100)], [5, Vector2i(319, 100), PLAYER], "reclamó la fila hasta el último píxel del mapa")
	_expect(errors, [off.get_offensive(sid)["next_cell"], off.forecast(sid)["blocked"], off.forecast(sid)["reason"]], [Vector2i(320, 100), true, Offensives.STOP_MAP_EDGE], "la siguiente celda cae fuera del mapa")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [off.sector_state(sid), off.get_offensive(sid)["reason"]], [Offensives.STATE_STOPPED, Offensives.STOP_MAP_EDGE], "el borde del mapa detiene la ofensiva")
	_expect(errors, [mil.get_sector(sid)["soldiers"], world["pop"].soldiers(PLAYER)], [5, 10], "sin bajas")
	# Hacia el oeste la fila termina en el agua (x = 299): diez celdas y se detiene.
	var west := _make_world({PLAYER: {"workers": 10, "soldiers": 10}}, _make_strip_grid())
	var wsid: int = west["mil"].create_sector(PLAYER, Vector2i(310, 100), Military.DIR_WEST, 2)["id"]
	west["off"].start_offensive(wsid)
	_ticks(west, Balance.ADVANCE_INTERVAL_TICKS * 10)
	_expect(errors, [west["off"].get_offensive(wsid)["claimed"], west["off"].get_offensive(wsid)["front"], west["off"].is_active(wsid)], [10, Vector2i(300, 100), true], "reclamó las diez celdas hasta el extremo de la fila")
	_ticks(west, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [west["off"].get_offensive(wsid)["reason"], west["grid"].get_cell_owner(299, 100)], [Offensives.STOP_WATER, TerritoryGrid.OWNER_NONE], "el agua detiene la ofensiva hacia el oeste")
	return errors


func _test_front_lost_and_resume() -> Array:
	var errors: Array = []
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var occ: Occupation = world["occ"]
	var pop: Population = world["pop"]
	var grid: TerritoryGrid = world["grid"]
	var sid: int = world["sid"]
	var step := Balance.ADVANCE_INTERVAL_TICKS
	off.start_offensive(sid)
	_ticks(world, step * 2)
	_expect(errors, [occ.count(), off.get_offensive(sid)["front"], pop.soldiers(AI_1)], [2, Vector2i(26, 15), 2], "dos celdas ocupadas")
	# Se pierde el frente (una futura paz restaurando fronteras haría esto): la ofensiva se detiene.
	occ.release(Vector2i(26, 15))
	_ticks(world, step)
	_expect(errors, [off.sector_state(sid), off.get_offensive(sid)["reason"], occ.count()], [Offensives.STATE_STOPPED, Offensives.STOP_FRONT_LOST, 1], "sin frente propio la ofensiva se detiene")
	# Reanudar parte del último frente válido: aquí el origen, porque el frente ya no es suyo.
	_expect(errors, off.start_offensive(sid)["ok"], true, "se puede reanudar")
	_expect(errors, [off.get_offensive(sid)["front"], off.current_target(sid)], [BORDER, Vector2i(25, 15)], "vuelve a empezar desde el origen")
	var soldiers_before := [pop.soldiers(PLAYER), pop.soldiers(AI_1)]
	_ticks(world, step)
	_expect(errors, [off.get_offensive(sid)["front"], [pop.soldiers(PLAYER), pop.soldiers(AI_1)]], [Vector2i(25, 15), soldiers_before], "volver a pasar por una celda ya ocupada es una marcha sin combate ni bajas")
	_ticks(world, step)
	_expect(errors, [occ.count(), off.get_offensive(sid)["front"], pop.soldiers(AI_1)], [2, Vector2i(26, 15), 1], "y la celda liberada se vuelve a combatir (la IA quedaba con 2: defiende 1)")
	# Conquista explícita de una celda ocupada: la ocupación desaparece y la propiedad cambia de verdad.
	var owners_before := grid.copy_owner_data()
	var result := grid.conquer_cells(PLAYER, [Vector2i(25, 15)])
	_expect(errors, result["ok"], true, "conquer_cells sobre una celda ocupada por el propio atacante")
	_expect(errors, [grid.get_cell_owner(25, 15), occ.is_occupied(Vector2i(25, 15)), occ.count()], [PLAYER, false, 1], "ahora es del jugador y ya no figura como ocupada")
	_expect(errors, grid.copy_owner_data() != owners_before, true, "solo una conquista explícita cambió el propietario")
	_expect(errors, off.is_active(sid), true, "la ofensiva continúa")
	_ticks(world, step)
	_expect(errors, [off.get_offensive(sid)["front"], occ.get_cells(PLAYER)], [Vector2i(27, 15), [Vector2i(26, 15), Vector2i(27, 15)]], "avanza a la siguiente")
	return errors


func _test_occupation() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 10}})
	var occ: Occupation = world["occ"]
	var grid: TerritoryGrid = world["grid"]
	var owners_before := grid.copy_owner_data()
	var terrain_before := grid.copy_terrain_data()
	_expect(errors, [occ.count(), occ.get_cells(), occ.occupier_at(Vector2i(26, 15)), occ.is_occupied(Vector2i(26, 15))], [0, [], TerritoryGrid.OWNER_NONE, false], "empieza sin ocupaciones")
	_signal_count = 0
	_signal_cells = []
	occ.changed.connect(_count_signal)
	occ.cells_changed.connect(_collect_cells)
	_expect(errors, occ.occupy(PLAYER, Vector2i(26, 15)), Occupation.OCC_OK, "ocupar tierra de otra nación")
	_expect(errors, [occ.occupier_at(Vector2i(26, 15)), occ.official_owner_at(Vector2i(26, 15)), grid.get_cell_owner(26, 15)], [PLAYER, AI_1, AI_1], "se consulta directamente, sin inferirlo del color")
	_expect(errors, [occ.count(), occ.count(PLAYER), occ.count(AI_1), occ.count_taken_from(AI_1), occ.count_taken_from(PLAYER)], [1, 1, 0, 1, 0], "recuentos")
	_expect(errors, [_signal_count, _signal_cells], [1, [Vector2i(26, 15)]], "emite changed y las celdas afectadas")
	_expect(errors, occ.occupy(PLAYER, Vector2i(26, 15)), Occupation.OCC_OK, "ocupar otra vez la misma celda es inocuo")
	_expect(errors, _signal_count, 1, "y no emite nada")
	_expect(errors, grid.copy_owner_data() == owners_before and grid.copy_terrain_data() == terrain_before, true, "ocupar no toca ni propietarios ni terreno")
	# Validaciones.
	var cases := [
		[PLAYER, Vector2i(36, 15), Occupation.OCC_ERR_NOT_ENEMY_LAND, "tierra sin reclamar (se conquista, no se ocupa)"],
		[PLAYER, Vector2i(12, 12), Occupation.OCC_ERR_NOT_ENEMY_LAND, "tierra propia"],
		[PLAYER, Vector2i(5, 5), Occupation.OCC_ERR_NOT_LAND, "agua"],
		[PLAYER, Vector2i(-1, 15), Occupation.OCC_ERR_OUT_OF_BOUNDS, "fuera del mapa"],
		[TerritoryGrid.OWNER_NONE, Vector2i(26, 15), Occupation.OCC_ERR_UNKNOWN_OCCUPIER, "ocupante OWNER_NONE"],
		[99, Vector2i(26, 15), Occupation.OCC_ERR_UNKNOWN_OCCUPIER, "ocupante 99"],
	]
	for item: Array in cases:
		_expect(errors, [occ.validate(item[0], item[1]), occ.occupy(item[0], item[1])], [item[2], item[2]], "rechazo: " + item[3])
	_expect(errors, [occ.count(), _signal_count], [1, 1], "los rechazos no cambian nada")
	_expect(errors, Occupation.error_message(Occupation.OCC_ERR_NOT_ENEMY_LAND) != "", true, "mensajes de error")
	# Otro ocupante la sustituye.
	_expect(errors, occ.occupy(AI_2, Vector2i(26, 15)), Occupation.OCC_OK, "una tercera nación puede ocupar la misma celda")
	_expect(errors, [occ.occupier_at(Vector2i(26, 15)), occ.official_owner_at(Vector2i(26, 15))], [AI_2, AI_1], "el ocupante cambia, el propietario oficial no")
	# Liberar.
	_expect(errors, [occ.release(Vector2i(26, 15)), occ.release(Vector2i(26, 15)), occ.count()], [true, false, 0], "liberar una celda ocupada y no hacerlo dos veces")
	occ.occupy(PLAYER, Vector2i(26, 15))
	occ.occupy(PLAYER, Vector2i(27, 15))
	occ.occupy(AI_2, Vector2i(28, 15))
	_expect(errors, [occ.release_all_of(PLAYER), occ.get_cells()], [2, [Vector2i(28, 15)]], "restaurar fronteras: libera todo lo de una nación (para tratados futuros)")
	# Una conquista o cambio de propietario descarta la ocupación obsoleta.
	_signal_cells = []
	occ.occupy(PLAYER, Vector2i(25, 15))
	_signal_cells = []
	grid.conquer_cells(PLAYER, [Vector2i(25, 15)])
	_expect(errors, [occ.is_occupied(Vector2i(25, 15)), _signal_cells], [false, [Vector2i(25, 15)]], "conquistar la celda ocupada elimina su ocupación y lo anuncia")
	grid.try_set_owner(28, 15, PLAYER)
	_expect(errors, occ.is_occupied(Vector2i(28, 15)), false, "si cambia el propietario oficial, la ocupación de un tercero queda obsoleta y se descarta")
	_expect(errors, occ.count(), 0, "no quedan ocupaciones")
	return errors


func _test_war_state() -> Array:
	var errors: Array = []
	var wars := WarState.new()
	_signal_count = 0
	wars.changed.connect(_count_signal)
	_expect(errors, [wars.war_count(), wars.at_war(PLAYER, AI_1), wars.enemies_of(PLAYER)], [0, false, []], "empieza la paz")
	_expect(errors, wars.declare_war(PLAYER, AI_1), true, "declarar una guerra nueva")
	_expect(errors, [wars.at_war(PLAYER, AI_1), wars.at_war(AI_1, PLAYER), wars.at_war(PLAYER, AI_2), wars.war_count()], [true, true, false, 1], "es simétrica y solo entre esas dos")
	_expect(errors, [wars.aggressor_of(PLAYER, AI_1), wars.aggressor_of(AI_1, PLAYER), wars.aggressor_of(PLAYER, AI_2)], [PLAYER, PLAYER, 0], "se recuerda quién la empezó")
	_expect(errors, [wars.declare_war(PLAYER, AI_1), wars.declare_war(AI_1, PLAYER), wars.war_count(), _signal_count], [false, false, 1, 1], "no se duplica ni se repite la señal")
	_expect(errors, [wars.declare_war(PLAYER, PLAYER), wars.declare_war(0, AI_1), wars.declare_war(PLAYER, -1)], [false, false, false], "datos inválidos rechazados")
	wars.declare_war(AI_2, PLAYER)
	_expect(errors, [wars.enemies_of(PLAYER), wars.enemies_of(AI_1), wars.aggressor_of(PLAYER, AI_2)], [[AI_1, AI_2], [PLAYER], AI_2], "enemigos ordenados y agresor")
	# Con ofensivas: empieza al atacar a otra nación, no por tener sectores, y detener no la termina.
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var occ: Occupation = world["occ"]
	var sid: int = world["sid"]
	_expect(errors, world["wars"].war_count(), 0, "tener un sector no es estar en guerra")
	off.start_offensive(sid)
	_expect(errors, [world["wars"].at_war(PLAYER, AI_1), world["wars"].aggressor_of(PLAYER, AI_1)], [true, PLAYER], "el ataque declara la guerra")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS * 2)
	off.stop_offensive(sid)
	_expect(errors, [world["wars"].at_war(PLAYER, AI_1), occ.count()], [true, 2], "detener el ataque no firma la paz ni borra las ocupaciones")
	_ticks(world, 60)
	_expect(errors, [world["wars"].at_war(PLAYER, AI_1), occ.count(), world["wars"].war_count()], [true, 2, 1], "con el paso del tiempo todo sigue igual")
	# Con dos celdas sin reclamar entre ambos, la guerra empieza al llegar al territorio de la IA 1, no antes.
	var march := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}}, _make_gap_grid())
	var msid: int = march["mil"].create_sector(PLAYER, BORDER, Military.DIR_EAST, 10)["id"]
	march["off"].start_offensive(msid)
	_expect(errors, march["wars"].war_count(), 0, "apuntar a tierra sin reclamar no declara nada")
	_ticks(march, Balance.ADVANCE_INTERVAL_TICKS * 2)
	_expect(errors, [march["off"].get_offensive(msid)["front"], march["off"].get_offensive(msid)["claimed"], march["wars"].at_war(PLAYER, AI_1)], [Vector2i(26, 15), 2, false], "tras conquistar las dos celdas libres sigue sin haber guerra")
	# Hito 11: una expansión (objetivo: tierra sin reclamar) nunca ataca; al tocar a la IA 1 se detiene.
	_ticks(march, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [march["off"].sector_state(msid), march["off"].get_offensive(msid)["reason"], march["wars"].at_war(PLAYER, AI_1), march["occ"].count()],
			[Offensives.STATE_STOPPED, Offensives.STOP_CONTACT, false, 0], "la expansión llega a la IA 1 y se detiene sin declarar la guerra")
	# Atacar es una orden explícita: reanudar ahora tiene como objetivo a la IA 1 y declara la guerra.
	_expect(errors, march["off"].start_offensive(msid)["ok"], true, "se ordena el ataque")
	_expect(errors, [march["wars"].at_war(PLAYER, AI_1), march["off"].goal_of(msid)], [true, AI_1], "la orden explícita declara la guerra")
	_ticks(march, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [march["off"].get_offensive(msid)["front"], march["wars"].at_war(PLAYER, AI_1), march["occ"].get_cells()], [Vector2i(27, 15), true, [Vector2i(27, 15)]], "y se ocupa la celda")
	return errors


func _test_economy_rules() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}}, null, true)
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	var occ: Occupation = world["occ"]
	var grid: TerritoryGrid = world["grid"]
	var ai_city_cell := Vector2i(30, 20)
	economy.add(AI_1, 1000, 0)
	var found := cities.found_city(AI_1, ai_city_cell)
	_expect(errors, found["ok"], true, "la IA 1 funda su ciudad")
	var ai_city: int = found["city_id"]
	var player_city: int = cities.city_id_at(CITY_A)
	_expect(errors, [cities.income_for(PLAYER), cities.income_for(AI_1)], [{"money": 2, "resources": 1}, {"money": 2, "resources": 1}], "producción previa de ambas ciudades")
	# El ocupante no obtiene nada por ocupar.
	var player_money := economy.get_money(PLAYER)
	var ai_money := economy.get_money(AI_1)
	var ai_progress: int = cities.get_city(ai_city)["progress"]
	var growth_before: int = world["pop"].growth_milli(AI_1)
	_expect(errors, occ.occupy(PLAYER, ai_city_cell), Occupation.OCC_OK, "el jugador ocupa el centro de la ciudad de la IA 1")
	_expect(errors, [cities.is_occupied(ai_city), cities.get_owner(ai_city), grid.get_cell_owner(ai_city_cell.x, ai_city_cell.y)], [true, AI_1, AI_1], "la ciudad sigue siendo de la IA 1 (propietario oficial)")
	_expect(errors, [cities.income_for(AI_1), cities.income_for(PLAYER)], [{"money": 0, "resources": 0}, {"money": 2, "resources": 1}], "la ciudad ocupada no produce y el ocupante no recibe su producción")
	var data := cities.get_city(ai_city)
	_expect(errors, [data["occupied"], data["money_rate"], data["resource_rate"]], [true, 0, 0], "los datos de la ciudad reflejan la suspensión")
	_expect(errors, cities.get_city(player_city)["occupied"], false, "la ciudad del jugador no está ocupada")
	var worker_money_before: int = world["pop"].get_stats(PLAYER)["worker_money"]
	_ticks(world, 5)
	_expect(errors, economy.get_money(AI_1), ai_money, "la ciudad ocupada no cobra mientras dura la ocupación (ni sus trabajadores: sin puestos)")
	var worker_money: int = world["pop"].get_stats(PLAYER)["worker_money"] - worker_money_before
	_expect(errors, economy.get_money(PLAYER), player_money + 10 + worker_money, "el jugador solo cobra lo de su propia ciudad (2 por tick) y lo de sus trabajadores (hito 11)")
	_expect(errors, cities.get_city(ai_city)["progress"], ai_progress + 5, "el crecimiento de nivel de la ciudad sigue (regla provisional documentada)")
	_expect(errors, world["pop"].growth_milli(AI_1), growth_before, "y su contribución a la población también (regla provisional documentada)")
	_expect(errors, grid.get_cell_owner(ai_city_cell.x, ai_city_cell.y), AI_1, "el paso del tiempo no transfiere la ciudad")
	# Fundar ciudades sobre celdas ocupadas.
	var spot := Vector2i(34, 29)
	occ.occupy(PLAYER, spot)
	var money_before := economy.get_money(PLAYER)
	var ai_before := economy.get_money(AI_1)
	var count_before := cities.city_count()
	_expect(errors, cities.found_city(PLAYER, spot)["error"], CityManager.FOUND_ERR_NOT_OWNED, "el ocupante no puede fundar en tierra que sigue siendo de otra nación")
	_expect(errors, cities.found_city(AI_1, spot)["error"], CityManager.FOUND_ERR_ENEMY_OCCUPATION, "el dueño tampoco mientras esté ocupada")
	_expect(errors, cities.check_founding(AI_1, spot), CityManager.FOUND_ERR_ENEMY_OCCUPATION, "check_founding avisa del mismo motivo")
	_expect(errors, [economy.get_money(PLAYER), economy.get_money(AI_1), cities.city_count()], [money_before, ai_before, count_before], "los intentos rechazados no cobran ni crean nada")
	_expect(errors, CityManager.error_message(CityManager.FOUND_ERR_ENEMY_OCCUPATION) != "", true, "hay mensaje para el jugador")
	occ.release(spot)
	_expect(errors, cities.found_city(AI_1, spot)["ok"], true, "liberada la celda, el dueño ya puede fundar")
	# Reanudación de la producción.
	ai_money = economy.get_money(AI_1)
	occ.release(ai_city_cell)
	_expect(errors, [cities.is_occupied(ai_city), cities.income_for(AI_1)["money"] >= 2, cities.get_city(ai_city)["money_rate"]], [false, true, 2], "al terminar la ocupación la producción se reanuda")
	_ticks(world, 3)
	_expect(errors, economy.get_money(AI_1) - ai_money >= 6, true, "y vuelve a cobrar (al menos 2 por tick de la ciudad desocupada)")
	# La ciudad cambia de dueño solo por una conquista explícita, no por ocupar.
	var transfer := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}}, null, true)
	transfer["economy"].add(AI_1, 1000, 0)
	var tcity: int = transfer["cities"].found_city(AI_1, Vector2i(26, 15))["city_id"]
	transfer["occ"].occupy(PLAYER, Vector2i(26, 15))
	_ticks(transfer, 100)
	_expect(errors, transfer["cities"].get_owner(tcity), AI_1, "100 ticks de ocupación no cambian al dueño de la ciudad")
	_expect(errors, transfer["cities"].get_city(tcity)["level"] >= 2, true, "aunque la ciudad siga creciendo de nivel")
	return errors


func _test_consistency() -> Array:
	var errors: Array = []
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var sid: int = world["sid"]
	# La IA 1 tiene su propio sector (id 2) con 4 de sus 6 soldados.
	var ai_sector: int = mil.create_sector(AI_1, Vector2i(25, 20), Military.DIR_WEST, 4)["id"]
	_expect(errors, [mil.get_summary(AI_1)], [{"total": 6, "assigned": 4, "available": 2}], "la IA 1 reparte 4 de sus 6 soldados")
	off.start_offensive(sid)
	var lost_player := 0
	var lost_ai := 0
	for tick in 40:
		_ticks(world, 1)
		for nation_id: int in [PLAYER, AI_1]:
			var summary := mil.get_summary(nation_id)
			if summary["total"] < 0 or summary["assigned"] < 0 or summary["available"] < 0:
				errors.append("cifras negativas en el tick %d (nación %d): %s" % [tick + 1, nation_id, summary])
			if summary["assigned"] > summary["total"]:
				errors.append("más soldados asignados (%d) que existentes (%d) en el tick %d" % [summary["assigned"], summary["total"], tick + 1])
			if summary["available"] != summary["total"] - summary["assigned"]:
				errors.append("la reserva no es total - asignados en el tick %d" % (tick + 1))
			if pop.total_population(nation_id) != pop.workers(nation_id) + pop.soldiers(nation_id):
				errors.append("la población total no suma trabajadores y soldados en el tick %d" % (tick + 1))
			if pop.workers(nation_id) != 30:
				errors.append("cambiaron los trabajadores de la nación %d en el tick %d: %d" % [nation_id, tick + 1, pop.workers(nation_id)])
		for sector_id: int in mil.get_sector_ids():
			if mil.get_sector(sector_id)["soldiers"] < 0:
				errors.append("sector %d con soldados negativos" % sector_id)
	var data := off.get_offensive(sid)
	lost_player = 20 - pop.soldiers(PLAYER)
	lost_ai = 6 - pop.soldiers(AI_1)
	_expect(errors, [lost_player, lost_ai], [data["attacker_losses"], data["defender_losses"]], "las bajas contadas son exactamente las que desaparecieron de la población")
	_expect(errors, [pop.soldiers(PLAYER), pop.soldiers(AI_1), pop.workers(PLAYER), pop.workers(AI_1)], [16, 0, 30, 30], "resultado final: 4 y 6 bajas; los trabajadores intactos")
	_expect(errors, mil.get_sector(sid)["soldiers"], 6, "el sector atacante conserva 10 - 4")
	# Los sectores del defensor se ajustaron de forma determinista (más nuevo primero) al perder soldados.
	_expect(errors, [mil.get_sector(ai_sector)["soldiers"], mil.get_summary(AI_1)], [0, {"total": 0, "assigned": 0, "available": 0}], "con 0 soldados, el sector de la IA 1 quedó a 0 sin salir negativo")
	# Ajuste intermedio: la IA 1 pierde 3 de sus 6 soldados con 6 asignados a dos sectores.
	var step := _battle_world(10, 6)
	var smil: Military = step["mil"]
	var older: int = smil.create_sector(AI_1, Vector2i(25, 20), Military.DIR_WEST, 4)["id"]
	var newer: int = smil.create_sector(AI_1, Vector2i(25, 25), Military.DIR_WEST, 2)["id"]
	_expect(errors, smil.get_summary(AI_1), {"total": 6, "assigned": 6, "available": 0}, "todos los soldados de la IA 1 asignados")
	step["pop"].remove_soldiers(AI_1, 3)
	_expect(errors, [smil.get_sector(older)["soldiers"], smil.get_sector(newer)["soldiers"]], [3, 0], "el exceso (3) se quita del sector más nuevo y luego del anterior")
	_expect(errors, smil.get_summary(AI_1), {"total": 3, "assigned": 3, "available": 0}, "asignados y totales vuelven a cuadrar")
	# Si la pérdida cabe en la reserva, ningún sector se toca.
	var reserve := _battle_world(10, 6)
	var rmil: Military = reserve["mil"]
	var rsid: int = rmil.create_sector(AI_1, Vector2i(25, 20), Military.DIR_WEST, 2)["id"]
	reserve["pop"].remove_soldiers(AI_1, 3)
	_expect(errors, [rmil.get_sector(rsid)["soldiers"], rmil.get_summary(AI_1)], [2, {"total": 3, "assigned": 2, "available": 1}], "las bajas salen primero de la reserva")
	# remove_soldiers: límites.
	var p: Population = reserve["pop"]
	_expect(errors, [p.remove_soldiers(AI_1, 100), p.soldiers(AI_1), p.workers(AI_1)], [3, 0, 30], "no se quitan más soldados de los que hay y nunca trabajadores")
	_expect(errors, [p.remove_soldiers(AI_1, 0), p.remove_soldiers(AI_1, -4), p.remove_soldiers(99, 3)], [0, 0, 0], "cantidades no positivas o nación inexistente: nada")
	return errors


func _test_multiple_offensives() -> Array:
	var errors: Array = []
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}})
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var pop: Population = world["pop"]
	var occ: Occupation = world["occ"]
	var first: int = mil.create_sector(PLAYER, Vector2i(24, 12), Military.DIR_EAST, 5)["id"]
	var second: int = mil.create_sector(PLAYER, Vector2i(24, 17), Military.DIR_EAST, 5)["id"]
	_expect(errors, [off.forecast(first)["defense"], off.forecast(second)["defense"]], [2, 2], "las dos previsiones ven la misma defensa local")
	off.start_offensive(first)
	off.start_offensive(second)
	_expect(errors, off.active_count(PLAYER), 2, "dos ofensivas independientes a la vez")
	var step := Balance.ADVANCE_INTERVAL_TICKS
	_ticks(world, step)
	# La IA 1 tiene 6 soldados EN TOTAL: el primer sector (id menor) la deja en 4 y el segundo ya combate
	# contra esos 4, no contra otros 6.
	_expect(errors, [pop.soldiers(AI_1), mil.get_sector(first)["soldiers"], mil.get_sector(second)["soldiers"], pop.soldiers(PLAYER)], [2, 4, 4, 18], "tras el primer intervalo: la IA 1 quedó con 2, cada sector con 4")
	_expect(errors, [occ.get_cells(PLAYER), off.get_offensive(first)["front"], off.get_offensive(second)["front"]], [[Vector2i(25, 12), Vector2i(25, 17)], Vector2i(25, 12), Vector2i(25, 17)], "cada frente en su fila")
	_ticks(world, step)
	_expect(errors, [pop.soldiers(AI_1), mil.get_sector(first)["soldiers"], mil.get_sector(second)["soldiers"]], [0, 3, 3], "tras el segundo, la IA 1 se quedó sin soldados: nunca perdió más de los que tenía")
	_expect(errors, off.get_offensive(first)["defender_losses"] + off.get_offensive(second)["defender_losses"], 6, "las bajas del defensor suman exactamente sus 6 soldados")
	# Detener una no detiene la otra.
	off.stop_offensive(first)
	_ticks(world, step)
	_expect(errors, [off.get_offensive(first)["front"], off.get_offensive(second)["front"], off.is_active(second)], [Vector2i(26, 12), Vector2i(27, 17), true], "la otra sigue avanzando sola")
	_expect(errors, off.get_offensive(first)["occupied"], 2, "la detenida conserva lo ocupado")
	_expect(errors, [mil.assigned_soldiers(PLAYER) <= pop.soldiers(PLAYER), mil.available_soldiers(PLAYER)], [true, pop.soldiers(PLAYER) - 6], "las reservas cuadran")
	return errors


func _test_time_changes_nothing() -> Array:
	var errors: Array = []
	# Con sectores creados y asignados pero sin ofensivas, 300 ticks no mueven una frontera.
	var world := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}}, null, true)
	var mil: Military = world["mil"]
	var grid: TerritoryGrid = world["grid"]
	var owners_before := grid.copy_owner_data()
	mil.create_sector(PLAYER, BORDER, Military.DIR_EAST, 10)
	world["pop"].start_mobilization(PLAYER, 30)
	world["pop"].set_city_priority(PLAYER, 1, true)
	_ticks(world, 300)
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ciudades, población y economía no mueven fronteras")
	_expect(errors, [world["occ"].count(), world["wars"].war_count(), world["off"].active_count()], [0, 0, 0], "ni crean ocupaciones, guerras u ofensivas")
	_expect(errors, world["cities"].get_city(1)["level"], EconomyBalance.MAX_LEVEL, "la ciudad creció hasta el nivel máximo sin conquistar nada")
	# Una ofensiva detenida deja de cambiar cosas: ocupaciones y propietarios quedan fijos.
	var battle := _battle_world(10, 6)
	battle["off"].start_offensive(battle["sid"])
	_ticks(battle, Balance.ADVANCE_INTERVAL_TICKS * 3)
	battle["off"].stop_offensive(battle["sid"])
	var frozen := _snapshot(battle)
	_ticks(battle, 400)
	_expect(errors, _snapshot(battle) == frozen, true, "tras detener el ataque, 400 ticks no cambian ocupación, bajas ni propietarios")
	# Una ocupación no se convierte en propiedad por el tiempo, aunque dure muchísimo.
	var owners: PackedByteArray = battle["grid"].copy_owner_data()
	for cell: Vector2i in battle["occ"].get_cells():
		_expect(errors, [battle["grid"].get_cell_owner(cell.x, cell.y), battle["occ"].occupier_at(cell)], [AI_1, PLAYER], "la celda %s sigue ocupada y de la IA 1" % cell)
	_expect(errors, owners == battle["grid"].copy_owner_data(), true, "propietarios fijos")
	return errors


func _test_sector_removal() -> Array:
	var errors: Array = []
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var occ: Occupation = world["occ"]
	var grid: TerritoryGrid = world["grid"]
	var sid: int = world["sid"]
	off.start_offensive(sid)
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, occ.count(), 1, "una celda ocupada")
	mil.remove_sector(sid)
	_expect(errors, [off.sector_state(sid), off.get_offensive(sid), off.active_count()], [Offensives.STATE_READY, {}, 0], "al eliminar el sector desaparece su ofensiva")
	_expect(errors, [occ.count(), world["wars"].at_war(PLAYER, AI_1)], [1, true], "pero la ocupación y la guerra se conservan")
	_expect(errors, mil.get_summary(PLAYER), {"total": 19, "assigned": 0, "available": 19}, "los soldados que quedaron vuelven a la reserva (las bajas ya no existen)")
	_ticks(world, 30)
	_expect(errors, occ.count(), 1, "sin ofensiva no se ocupa más")
	_expect(errors, grid.get_cell_owner(25, 15), AI_1, "y el propietario sigue siendo el oficial")
	# Perder la celda de origen elimina el sector y su ofensiva.
	var second := _battle_world(10, 6)
	var ssid: int = second["sid"]
	second["off"].start_offensive(ssid)
	var result: Dictionary = second["grid"].conquer_cells(AI_1, [BORDER])
	_expect(errors, result["ok"], true, "la IA 1 conquista el origen")
	_expect(errors, [second["mil"].has_sector(ssid), second["off"].sector_state(ssid), second["off"].active_count()], [false, Offensives.STATE_READY, 0], "sin origen no hay sector ni ofensiva")
	return errors


func _test_map_view() -> Array:
	var errors: Array = []
	var grid := _make_grid()
	var occ := Occupation.new(grid)
	var view := MapView.new()
	view.set_grid(grid)
	var plain_even := view.cell_color(25, 15)
	var plain_odd := view.cell_color(26, 15)
	var plain_far := view.cell_color(27, 15)
	var player_color: Color = grid.get_nation(PLAYER)["color"]
	var ai_color: Color = grid.get_nation(AI_1)["color"]
	view.occupation = occ
	_expect(errors, [view.cell_color(25, 15), view.cell_color(26, 15)], [plain_even, plain_odd], "una ocupación vacía no cambia ningún color")
	occ.occupy(PLAYER, Vector2i(25, 15))
	occ.occupy(PLAYER, Vector2i(26, 15))
	var owners_before := grid.copy_owner_data()
	var even := view.cell_color(25, 15)
	var odd := view.cell_color(26, 15)
	_expect(errors, even, player_color.lightened(MapView.OCCUPATION_LIGHTEN), "las celdas pares del tablero se ven en el tono claro del ocupante")
	_expect(errors, [even != player_color, even != ai_color, even != plain_even], [true, true, true], "el color de ocupación no es el de la propiedad definitiva de nadie")
	_expect(errors, odd, plain_odd, "las celdas impares conservan el color del propietario oficial")
	_expect(errors, view.cell_color(27, 15), plain_far, "las celdas no ocupadas se pintan como siempre")
	_expect(errors, [grid.get_cell_owner(25, 15), grid.get_cell_owner(26, 15), view.is_border(25, 15)], [AI_1, AI_1, true], "el propietario y las fronteras no cambian")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "pintar la ocupación no toca la cuadrícula")
	# La imagen (RGBA8) solo cambia al repintar la celda. Se compara con tolerancia de cuantización.
	_expect_color(errors, view.get_image_pixel(25, 15), plain_even, "antes de repintar, la imagen sigue como estaba")
	_expect(errors, _color_near(view.get_image_pixel(25, 15), even), false, "antes de repintar, la imagen no muestra todavía la ocupación")
	view.refresh_cell(25, 15)
	_expect_color(errors, view.get_image_pixel(25, 15), even, "tras refresh_cell la celda par ocupada se ve en el tono claro del ocupante")
	_expect_color(errors, view.get_image_pixel(26, 15), odd, "y su vecina impar conserva el color del propietario (no queda desfasada)")
	_expect(errors, _color_near(view.get_image_pixel(25, 15), plain_even), false, "la tolerancia no oculta el cambio: la celda ocupada ya no tiene el color del propietario")
	_expect(errors, _color_near(view.get_image_pixel(25, 15), ai_color), false, "ni el color liso de la IA 1")
	_expect(errors, _color_near(view.get_image_pixel(25, 15), Color(1, 0, 1)), false, "y un color incorrecto sí se detecta")
	occ.release(Vector2i(25, 15))
	view.refresh_cell(25, 15)
	_expect_color(errors, view.get_image_pixel(25, 15), plain_even, "al liberar y repintar vuelve al color del propietario")
	_expect_color(errors, view.get_image_pixel(26, 15), odd, "la vecina sigue sin cambios")
	_expect(errors, _color_near(view.get_image_pixel(25, 15), even), false, "y ya no queda el tono de ocupación")
	# Sin ocupación asignada el dibujo es el de siempre.
	view.occupation = null
	_expect(errors, view.cell_color(26, 15), plain_odd, "sin sistema de ocupación el color es el de siempre")
	view.free()
	return errors


func _test_sector_layer() -> Array:
	var errors: Array = []
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	var sid: int = world["sid"]
	var layer := SectorLayer.new()
	layer.setup(world["grid"], mil, PLAYER, off)
	_expect(errors, layer.label_cell(sid), mil.get_sector(sid)["target"], "preparado: la cifra va junto al objetivo del sector")
	off.start_offensive(sid)
	_expect(errors, layer.label_cell(sid), Vector2i(25, 15), "atacando sin avanzar: junto a la celda a la que apunta")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS * 2)
	_expect(errors, [off.current_target(sid), layer.label_cell(sid)], [Vector2i(27, 15), Vector2i(27, 15)], "tras avanzar, la cifra sigue al frente")
	var layout := layer.label_layout(Vector2(1.0, 2.0))
	_expect(errors, layout.has(sid) and layout[sid].position.x > 27.0, true, "la cifra se coloca a la derecha de la celda siguiente al frente")
	off.stop_offensive(sid)
	_expect(errors, layer.label_cell(sid), Vector2i(27, 15), "detenida: la cifra se queda en el frente")
	mil.remove_sector(sid)
	_expect(errors, layer.label_layout(Vector2(1.0, 2.0)).is_empty(), true, "sin sectores no hay cifras")
	# Sin ofensivas conectadas la capa se comporta como en el hito 8.
	var old_layer := SectorLayer.new()
	var other := _battle_world(10, 6)
	old_layer.setup(other["grid"], other["mil"], PLAYER)
	_expect(errors, old_layer.label_cell(other["sid"]), Vector2i(25, 15), "sin ofensivas: junto al objetivo")
	layer.free()
	old_layer.free()
	return errors


func _test_texts() -> Array:
	var errors: Array = []
	var world := _battle_world(10, 6)
	var off: Offensives = world["off"]
	var grid: TerritoryGrid = world["grid"]
	var sid: int = world["sid"]
	var ai_name: String = grid.get_nation(AI_1)["name"]
	var sector: Dictionary = world["mil"].get_sector(sid)
	_expect(errors, [MilitaryPanel.list_item_text(sector), MilitaryPanel.list_item_text(sector, false), MilitaryPanel.list_item_text(sector, true)],
			["#1 (24,15) E · 10", "#1 (24,15) E · 10", "#1 (24,15) E · 10 · ATQ"], "línea de la lista con la marca de ataque")
	_expect(errors, [MilitaryPanel.ratio_text(2083), MilitaryPanel.ratio_text(4166), MilitaryPanel.ratio_text(1000), MilitaryPanel.ratio_text(Combat.NO_RESISTANCE_RATIO)], ["2,0 a 1", "4,1 a 1", "1,0 a 1", "sin defensa"], "relación")
	_expect(errors, [MilitaryPanel.category_text(Combat.CATEGORY_ADVANTAGE), MilitaryPanel.category_text(Combat.CATEGORY_BALANCED), MilitaryPanel.category_text(Combat.CATEGORY_DEFENSE)],
			["Ventaja atacante", "Combate equilibrado", "Defensa superior"], "etiquetas de la previsión")
	_expect(errors, MilitaryPanel.forecast_text(off.forecast(sid), ai_name),
			"Siguiente celda (25, 15) · Reino de Cobre\nAtacantes 10\nDefensa local ~2 (6 soldados en 3 tramos de frontera)\nVentaja atacante (4,1 a 1)\nVictoria prevista: ocupas la celda; sigue siendo de Reino de Cobre\nBajas aprox.: propias 1 · enemigas 2\nCálculo determinista, no una probabilidad.", "previsión completa")
	var losing := _battle_world(3, 12)
	var losing_text := MilitaryPanel.forecast_text(losing["off"].forecast(losing["sid"]), ai_name)
	_expect(errors, [losing_text.contains("Defensa superior"), losing_text.contains("Derrota prevista: el ataque se detiene"), losing_text.contains("no una probabilidad")], [true, true, true], "previsión de derrota")
	_expect(errors, MilitaryPanel.forecast_text({}, ""), "", "sin previsión no hay texto")
	var own := MilitaryPanel.forecast_text(world["off"].evaluate(PLAYER, 10, Vector2i(20, 15)), "")
	_expect(errors, own, "Siguiente celda (20, 15) · propia\nAvance sin combate.", "celda propia")
	var open_text := MilitaryPanel.forecast_text(off.evaluate(AI_1, 4, Vector2i(35, 15)), "")
	_expect(errors, open_text, "Siguiente celda (35, 15) · sin reclamar\nAtacantes 4\nSin resistencia: reclamas la celda, sin bajas.", "tierra sin reclamar")
	var blocked := MilitaryPanel.forecast_text(off.evaluate(AI_1, 4, Vector2i(40, 15)), "")
	_expect(errors, blocked.contains("el frente llega al agua"), true, "bloqueada por el agua")
	# Estado de la ofensiva.
	_expect(errors, MilitaryPanel.state_text(Offensives.STATE_READY, {}), "Preparado (sin atacar)", "preparado")
	off.start_offensive(sid)
	_expect(errors, MilitaryPanel.state_text(Offensives.STATE_ACTIVE, off.get_offensive(sid)),
			"ATACANDO · próximo avance en 3 s\nFrente (24, 15) → (25, 15)\nSoldados 10\nCeldas: 0 ocupadas · 0 reclamadas\nBajas: propias 0 · enemigas 0", "atacando")
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	off.stop_offensive(sid)
	var stopped := MilitaryPanel.state_text(Offensives.STATE_STOPPED, off.get_offensive(sid))
	_expect(errors, stopped,
			"Detenido: detenida por el jugador\nFrente (25, 15) → (26, 15)\nSoldados 9\nCeldas: 1 ocupadas · 0 reclamadas\nBajas: propias 1 · enemigas 2\nÚltimo: victoria en (25, 15) · bajas 1 / 2", "detenida tras una victoria")
	for reason in [Offensives.STOP_MANUAL, Offensives.STOP_NO_SOLDIERS, Offensives.STOP_WATER, Offensives.STOP_MAP_EDGE, Offensives.STOP_DEFEAT, Offensives.STOP_FRONT_LOST, Offensives.STOP_CANNOT_CLAIM, Offensives.STOP_TRUCE]:
		_expect(errors, Offensives.stop_reason_message(reason) != "" and Offensives.stop_reason_message(reason) != "motivo desconocido", true, "mensaje para el motivo %d" % reason)
	_expect(errors, Offensives.start_error_message(Offensives.START_ERR_NO_SOLDIERS), "El sector no tiene soldados.", "mensaje de inicio sin soldados")
	_expect(errors, Offensives.start_error_message(Offensives.START_ERR_BLOCKED, Offensives.STOP_WATER), "No se puede avanzar: el frente llega al agua.", "mensaje de inicio bloqueado")
	# Botón principal, objetivo y cantidad (hito 10).
	_expect(errors, [MilitaryPanel.main_button_text(Offensives.STATE_READY), MilitaryPanel.main_button_text(Offensives.STATE_ACTIVE), MilitaryPanel.main_button_text(Offensives.STATE_STOPPED)],
			["Atacar", "Detener", "Continuar"], "una sola acción principal por estado")
	var fresh := _battle_world(10, 6)
	var fresh_plan: Dictionary = fresh["off"].plan_attack(PLAYER, Vector2i(24, 16), Military.DIR_EAST, 4)
	_expect(errors, MilitaryPanel.target_text(MilitaryPanel.NO_CELL, MilitaryPanel.NO_DIRECTION, {}, ""), "Pulsa en el mapa tu frontera o la celda que quieres atacar.", "sin celda elegida")
	_expect(errors, MilitaryPanel.target_text(Vector2i(24, 16), MilitaryPanel.NO_DIRECTION, {}, ""), "Desde (24, 16)\nElige una dirección.", "sin dirección")
	_expect(errors, MilitaryPanel.target_text(Vector2i(24, 16), Military.DIR_EAST, fresh_plan, ai_name), "Desde (24, 16) hacia el Este → (25, 16)\nReino de Cobre", "objetivo válido y su dueño")
	var own_plan: Dictionary = fresh["off"].plan_attack(PLAYER, Vector2i(20, 16), Military.DIR_EAST, 4)
	_expect(errors, MilitaryPanel.target_text(Vector2i(20, 16), Military.DIR_EAST, own_plan, "Tu territorio"), "Desde (20, 16) hacia el Este → (21, 16)\n" + Military.attack_target_error_message(Military.SECTOR_ERR_TARGET_OWN), "objetivo propio: el motivo sustituye al dueño")
	var greedy_plan: Dictionary = fresh["off"].plan_attack(PLAYER, Vector2i(24, 16), Military.DIR_EAST, 999)
	_expect(errors, MilitaryPanel.target_text(Vector2i(24, 16), Military.DIR_EAST, greedy_plan, ai_name).ends_with("No hay tantos soldados disponibles (máximo 10)."), true, "más soldados de los posibles")
	_expect(errors, MilitaryPanel.amount_text(3, 6), "Soldados: 3 de 6", "cantidad elegida")
	# Guerra y ocupación.
	_expect(errors, [MilitaryPanel.war_text([], 0, 0), MilitaryPanel.war_text([ai_name], 3, 0), MilitaryPanel.war_text(["A", "B"], 0, 2)],
			["", "Guerra con: Reino de Cobre\nCeldas ocupadas por ti: 3", "Guerra con: A, B\nTu territorio ocupado: 2"], "línea de conflicto")
	# Información de celda.
	var occ: Occupation = world["occ"]
	_expect(errors, InfoPanel.describe_occupation(grid, occ, Vector2i(25, 15)), "Ocupada por Confederación de Alba (provisional)", "celda ocupada en el panel de información")
	_expect(errors, [InfoPanel.describe_occupation(grid, occ, Vector2i(30, 15)), InfoPanel.describe_occupation(grid, null, Vector2i(25, 15)), InfoPanel.describe_occupation(null, occ, Vector2i(25, 15))], ["", "", ""], "sin ocupación no hay línea")
	_expect(errors, InfoPanel.describe(grid, Vector2i(25, 15)).ends_with("Propietario: Reino de Cobre"), true, "el propietario oficial se muestra aparte y no cambia")
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
	for nation_id: int in grid.get_nation_ids():
		screen.economy.add(nation_id, 0, 100000)  # sin déficit: los soldados solo caen en combate
	var mil: Military = screen.military
	var pop: Population = screen.population
	var off: Offensives = screen.offensives
	var occ: Occupation = screen.occupation
	var wars: WarState = screen.wars
	var panel: MilitaryPanel = screen.get_node("%Militar")
	# Escenario celda a celda sin decisiones de la IA (hito 11: se prueban en tests/gameplay_tests.gd).
	if off != null:
		off.front_half_width = 0
	screen.ai.enabled = false
	var layer = screen.get_node("%Sectores")
	var view = screen.get_node("%Mapa")
	_expect(errors, off != null and occ != null and wars != null, true, "la pantalla crea las ofensivas, la ocupación y el estado de guerra")
	if off == null or occ == null or wars == null or panel == null:
		screen.free()
		return errors
	var names := ["GuerraMilitar", "ObjetivoAtaque", "CantidadAtaque", "SliderAtaque", "EstadoOfensiva", "PrevisionAtaque", "BotonAtacar", "BotonAjustar",
			"BotonRetirar", "BotonPorcentaje25", "BotonPorcentaje50", "BotonPorcentaje75", "BotonPorcentaje100", "ListaSectores", "DesplazamientoMilitar", "MensajeMilitar"]
	for node_name: String in names:
		if panel.find_child(node_name, true, false) == null:
			errors.append("falta el control %s" % node_name)
	for old_name: String in ["BotonCrearSector", "SliderNuevo", "SliderEdicion", "BotonAplicar", "BotonLiberarSector", "EdicionSector", "PlanSector"]:
		if panel.find_child(old_name, true, false) != null:
			errors.append("sigue existiendo el control del flujo antiguo %s" % old_name)
	if not errors.is_empty():
		screen.free()
		return errors
	# Mapa controlado: el jugador y la IA 1 en contacto (la partida por defecto empieza con las naciones separadas).
	var control := _make_grid()
	grid.load_from_data(control.copy_terrain_data(), control.copy_owner_data())
	view.refresh_all()
	var war_label: Label = panel.find_child("GuerraMilitar", true, false)
	var target_label: Label = panel.find_child("ObjetivoAtaque", true, false)
	var state_label: Label = panel.find_child("EstadoOfensiva", true, false)
	var forecast_label: Label = panel.find_child("PrevisionAtaque", true, false)
	var attack: Button = panel.find_child("BotonAtacar", true, false)
	var adjust: Button = panel.find_child("BotonAjustar", true, false)
	var withdraw: Button = panel.find_child("BotonRetirar", true, false)
	var slider: HSlider = panel.find_child("SliderAtaque", true, false)
	var list: ItemList = panel.find_child("ListaSectores", true, false)
	var message: Label = panel.find_child("MensajeMilitar", true, false)
	var summary_label: Label = panel.find_child("ResumenMilitar", true, false)
	var ai_name: String = grid.get_nation(AI_1)["name"]
	var owners_before := grid.copy_owner_data()
	_expect(errors, [state_label.visible, war_label.visible, adjust.visible, withdraw.visible], [false, false, false, false], "sin frente elegido no hay estado, aviso de guerra ni botones de frente")
	_expect(errors, [attack.text, attack.disabled], ["Atacar", true], "hay un único botón principal y está desactivado sin objetivo")
	# Un clic en la celda enemiga basta: el origen propio contiguo y la dirección se deducen.
	view.pointer_pressed(view.cell_center_global(Vector2i(25, 15)))
	_expect(errors, [panel.chosen_origin(), panel.chosen_direction()], [BORDER, Military.DIR_EAST], "pulsar la celda enemiga deduce el origen y la dirección")
	_expect(errors, [mil.sector_count(), off.active_count(), wars.war_count(), occ.count()], [0, 0, 0, 0], "elegir el objetivo no crea ningún frente ni inicia nada")
	_expect(errors, [slider.min_value, slider.max_value, slider.value], [1.0, 6.0, 3.0], "el deslizador ofrece de 1 a todos los soldados y propone la mitad")
	_expect(errors, target_label.text, "Desde (24, 15) hacia el Este → (25, 15)\n" + ai_name, "el objetivo se explica con palabras")
	for pair: Array in [[25, 2], [50, 3], [75, 5], [100, 6]]:
		panel.find_child("BotonPorcentaje%d" % pair[0], true, false).pressed.emit()
		_expect(errors, panel.amount(), pair[1], "el acceso rápido %d %% elige %d soldados" % [pair[0], pair[1]])
	panel.set_amount(1000)
	_expect(errors, panel.amount(), 6, "no se pueden comprometer más soldados que los disponibles")
	panel.set_amount(-3)
	_expect(errors, panel.amount(), 1, "ni menos de 1")
	panel.set_amount(6)
	var plan := off.plan_attack(PLAYER, BORDER, Military.DIR_EAST, 6)
	_expect(errors, forecast_label.text, MilitaryPanel.forecast_text(plan["info"], ai_name), "la previsión sale de los datos reales")
	_expect(errors, [forecast_label.text.contains("Atacantes 6"), forecast_label.text.contains("Defensa local ~2"), forecast_label.text.contains("Ventaja atacante"), forecast_label.text.contains("Victoria prevista"), forecast_label.text.contains("Bajas aprox."), forecast_label.text.contains("no una probabilidad")],
			[true, true, true, true, true, true], "muestra atacantes, defensa estimada, etiqueta, resultado, bajas y aviso")
	_expect(errors, [attack.text, attack.disabled], ["Atacar", false], "con el objetivo elegido se puede atacar")
	# Una sola pulsación crea el frente, le asigna los soldados y lanza la ofensiva.
	attack.pressed.emit()
	_expect(errors, mil.sector_count(), 1, "el juego creó el frente internamente")
	var sid: int = mil.get_sector_ids(PLAYER)[0]
	_expect(errors, [off.is_active(sid), mil.get_sector(sid)["soldiers"], panel.selected_sector(), layer.highlighted_sector()], [true, 6, sid, sid], "ataca con 6 soldados y el frente queda elegido y resaltado")
	_expect(errors, message.text, "Ataque en marcha con 6 soldados.", "se avisa")
	_expect(errors, [attack.text, state_label.visible, state_label.text.begins_with("ATACANDO"), withdraw.visible, adjust.visible], ["Detener", true, true, true, false], "el botón principal pasa a «Detener» y aparece el estado")
	_expect(errors, list.get_item_text(0), MilitaryPanel.list_item_text(mil.get_sector(sid), true), "la lista marca el frente que ataca")
	_expect(errors, [war_label.visible, war_label.text.contains(ai_name), wars.at_war(PLAYER, AI_1)], [true, true, true], "aparece discretamente el conflicto activo")
	# Avance: una celda ocupada, mapa y panel actualizados.
	screen.cities.advance(float(Balance.ADVANCE_INTERVAL_TICKS))
	var cell := Vector2i(25, 15)
	_expect(errors, [occ.occupier_at(cell), grid.get_cell_owner(cell.x, cell.y), off.get_offensive(sid)["front"]], [PLAYER, AI_1, cell], "ocupó la primera celda sin cambiar su propietario")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ni un propietario cambió")
	var ai_color: Color = grid.get_nation(AI_1)["color"]
	_expect_color(errors, view.get_image_pixel(cell.x, cell.y), view.cell_color(cell.x, cell.y), "el mapa repintó la celda ocupada (con tolerancia de cuantización)")
	_expect(errors, _color_near(view.get_image_pixel(cell.x, cell.y), ai_color), false, "y no la pinta como territorio de la IA 1")
	_expect_color(errors, view.get_image_pixel(cell.x + 1, cell.y), view.cell_color(cell.x + 1, cell.y), "ni deja su vecina desfasada")
	_expect(errors, summary_label.text, MilitaryPanel.summary_text(mil.get_summary(PLAYER)), "el resumen de soldados se actualizó con las bajas")
	_expect(errors, [mil.get_sector(sid)["soldiers"], pop.soldiers(PLAYER)], [5, 5], "el frente y la nación perdieron 1 soldado")
	_expect(errors, [state_label.text.contains("1 ocupadas"), state_label.text.contains("Soldados 5")], [true, true], "el panel muestra las celdas ocupadas, el frente y los soldados que quedan")
	_expect(errors, war_label.text, MilitaryPanel.war_text([ai_name], 1, 0), "y el recuento de ocupaciones")
	_expect(errors, layer.label_cell(sid), off.current_target(sid), "la cifra del mapa sigue al frente")
	# Reforzar o reducir con el mismo deslizador, sin cambiar el estado.
	panel.set_amount(2)
	_expect(errors, [adjust.visible, adjust.text, mil.get_sector(sid)["soldiers"]], [true, "Ajustar a 2", 5], "mover el deslizador no cambia nada hasta ajustar")
	adjust.pressed.emit()
	_expect(errors, [mil.get_sector(sid)["soldiers"], pop.soldiers(PLAYER), mil.available_soldiers(PLAYER), off.is_active(sid)], [2, 5, 3, true], "reducir devuelve soldados a la reserva sin bajas y sin detener el ataque")
	panel.set_amount(5)
	adjust.pressed.emit()
	_expect(errors, [mil.get_sector(sid)["soldiers"], mil.available_soldiers(PLAYER), adjust.visible], [5, 0, false], "reforzar toma de la reserva")
	# Detener y continuar con el mismo botón.
	attack.pressed.emit()
	_expect(errors, [off.sector_state(sid), state_label.text.begins_with("Detenido"), attack.text, attack.disabled], [Offensives.STATE_STOPPED, true, "Continuar", false], "detenido: se puede continuar")
	_expect(errors, [occ.count(), wars.at_war(PLAYER, AI_1)], [1, true], "detener no borra la ocupación ni termina la guerra")
	screen.cities.advance(10.0)
	_expect(errors, occ.count(), 1, "detenido, no avanza")
	attack.pressed.emit()
	_expect(errors, [off.is_active(sid), attack.text, mil.sector_count()], [true, "Detener", 1], "continuar reanuda el mismo frente sin crear otro")
	# Retirar el frente: los soldados vuelven a la reserva y la ocupación se conserva.
	withdraw.pressed.emit()
	_expect(errors, [mil.sector_count(), off.sector_state(sid), occ.count(), state_label.visible, withdraw.visible], [0, Offensives.STATE_READY, 1, false, false], "sin frente no hay estado; la ocupación se conserva")
	_expect(errors, mil.get_summary(PLAYER), {"total": 5, "assigned": 0, "available": 5}, "todos los soldados vivos vuelven a la reserva")
	# Órdenes inválidas: no consumen soldados ni dejan un frente a medias.
	var own_cell := Vector2i(12, 12)
	view.pointer_pressed(view.cell_center_global(own_cell))
	_expect(errors, [panel.chosen_origin(), panel.chosen_direction(), attack.disabled], [own_cell, MilitaryPanel.NO_DIRECTION, true], "una celda interior no da a tierra atacable: no hay dirección y no se puede atacar")
	attack.pressed.emit()
	_expect(errors, [mil.sector_count(), mil.assigned_soldiers(PLAYER)], [0, 0], "forzar el botón sin objetivo no hace nada")
	panel.find_child("BotonDireccionEste", true, false).pressed.emit()
	_expect(errors, [attack.disabled, target_label.text.contains(Military.attack_target_error_message(Military.SECTOR_ERR_TARGET_OWN))], [true, true], "apuntar a territorio propio no se puede y se explica")
	attack.pressed.emit()
	_expect(errors, [mil.sector_count(), mil.assigned_soldiers(PLAYER), message.text], [0, 0, Military.attack_target_error_message(Military.SECTOR_ERR_TARGET_OWN)], "ni siquiera forzándolo se crea un frente o se consumen soldados")
	view.pointer_pressed(view.cell_center_global(Vector2i(60, 60)))
	_expect(errors, [panel.chosen_origin(), attack.disabled], [MilitaryPanel.NO_CELL, true], "el agua no se puede atacar")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ningún control cambió el territorio")
	screen.free()
	return errors


func _test_determinism() -> Array:
	var errors: Array = []
	var results: Array = []
	for run in 2:
		var world := _battle_world(10, 6)
		var mil: Military = world["mil"]
		var off: Offensives = world["off"]
		var second: int = mil.create_sector(PLAYER, Vector2i(24, 22), Military.DIR_EAST, 4)["id"]
		off.start_offensive(world["sid"])
		_ticks(world, 7)
		off.start_offensive(second)
		_ticks(world, 20)
		off.stop_offensive(world["sid"])
		_ticks(world, 11)
		results.append(_snapshot(world))
	_expect(errors, results[0] == results[1], true, "dos partidas idénticas dan exactamente el mismo estado final")
	_expect(errors, results[0]["occupied"].size() > 0, true, "y el escenario hizo algo (hay ocupaciones)")
	return errors


func _test_files_present() -> Array:
	var errors: Array = []
	for path: String in ["res://tests/territory_grid_tests.gd", "res://tests/territory_map_view_tests.gd",
			"res://tests/territory_conquest_tests.gd", "res://tests/territory_hud_tests.gd",
			"res://tests/city_economy_tests.gd", "res://tests/population_tests.gd", "res://tests/military_tests.gd",
			"res://tests/run_territory_tests.tscn", "res://tests/run_view_tests.tscn",
			"res://tests/run_conquest_tests.tscn", "res://tests/run_hud_tests.tscn",
			"res://tests/run_city_tests.tscn", "res://tests/run_population_tests.tscn", "res://tests/run_military_tests.tscn",
			"res://tests/test_population.gd", "res://tests/test_military.gd", "res://tests/test_combat.gd", "res://tests/run_combat_tests.tscn",
			"res://tests/diplomacy_tests.gd", "res://tests/test_diplomacy.gd", "res://tests/run_diplomacy_tests.tscn", "res://scripts/world/diplomacy.gd",
			"res://scripts/world/combat.gd", "res://scripts/world/offensives.gd", "res://scripts/world/occupation.gd",
			"res://scripts/world/war_state.gd", "res://scripts/data/combat_balance.gd",
			"res://scripts/world/military.gd", "res://scripts/world/sector_layer_view.gd", "res://scripts/ui/military_panel.gd",
			"res://tests/test_province_data.gd", "res://tests/test_province_selection.gd",
			"res://scripts/data/province_data.gd", "res://scripts/map/province_map.gd", "res://scenes/main.tscn"]:
		_expect(errors, FileAccess.file_exists(path), true, "existe " + path)
	return errors
