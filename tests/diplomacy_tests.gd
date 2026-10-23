## Pruebas automáticas del hito 10: ataque en un paso, guerra por registro, diplomacia (propuestas, pagos,
## paz con conquistas y paz blanca, respuesta y propuestas de la IA), treguas y pausa de la simulación. Sin plugins.
##
## Única definición de las comprobaciones; la usan:
##   - tests/test_diplomacy.gd (consola, headless):
##       godot --headless --path . --script res://tests/test_diplomacy.gd
##   - tests/run_diplomacy_tests.tscn (editor de Godot, F6).
##
## Mapas controlados (load_from_data) y tiempo simulado con CityManager.advance(n): n ticks exactos de
## 1 s de juego, sin esperas reales ni azar. Los mundos de prueba NO tienen ciudades (salvo que se pida), así
## que nadie crece, y todas las naciones tienen muchos recursos: nunca hay déficit y los soldados solo cambian
## por combate. Dinero inicial de cada nación: 50.
##   - Mapa de duelo: tierra x 10..39, y 10..29; jugador x 10..24, IA 1 x 25..34, sin reclamar x 35..39.
##   - Mapa de tres: tierra x 10..39, y 10..29; jugador x 10..24; IA 1 x 25..39, y 10..19; IA 2 x 25..39, y 20..29.
## Los números de las decisiones de la IA se contrastaron con una réplica en Python de las fórmulas (que no
## es una prueba de Godot ni la sustituye): reluctancia = (fuerza - 500) * 20 / 100 + (celdas que ocupa - celdas
## que le ocupan) * 2 - ticks de guerra - 2 * bajas propias.
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
const Diplomacy := preload("res://scripts/world/diplomacy.gd")
const Balance := preload("res://scripts/data/combat_balance.gd")
const DiplomacyBalance := preload("res://scripts/data/diplomacy_balance.gd")
const EconomyBalance := preload("res://scripts/data/economy_balance.gd")
const MilitaryPanel := preload("res://scripts/ui/military_panel.gd")
const DiplomacyPanel := preload("res://scripts/ui/diplomacy_panel.gd")
const Screen := preload("res://scripts/ui/territory_screen.gd")

const PLAYER := TerritoryGrid.OWNER_PLAYER
const AI_1 := TerritoryGrid.OWNER_AI_1
const AI_2 := TerritoryGrid.OWNER_AI_2
const SCREEN_PATH := "res://scenes/territory_main.tscn"
const CITY_A := Vector2i(12, 12)
const BORDER := Vector2i(24, 15)  # frontera del jugador con la IA 1 en el mapa de duelo (la IA 1 empieza en x = 25)
const DUEL_POP := {PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}}
const TRI_POP := {PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 6}, AI_2: {"workers": 30, "soldiers": 6}}
const WINNING_AI_POP := {PLAYER: {"workers": 30, "soldiers": 6}, AI_1: {"workers": 30, "soldiers": 24}}
const WEAK_AI_POP := {PLAYER: {"workers": 30, "soldiers": 24}, AI_1: {"workers": 30, "soldiers": 6}}
const EVEN_POP := {PLAYER: {"workers": 30, "soldiers": 6}, AI_1: {"workers": 30, "soldiers": 6}}

var _results: Array = []
var _signal_count: int = 0
var _signal_cells: Array = []
var _signal_treaties: Array = []
var _signal_pauses: Array = []


func run_all() -> Array:
	_results = []
	_run("pausa: el reloj único detiene todos los sistemas a la vez y los reanuda sin saltos", _test_pause)
	_run("registro por guerra: duración, bajas, ocupaciones, fin independiente y treguas", _test_war_state)
	_run("ocupación por parejas: consultar y liberar solo entre dos naciones", _test_occupation_pairs)
	_run("ataque en un paso: previsión y ejecución atómica, reutilización y refuerzo del frente", _test_launch_attack)
	_run("ataque en un paso: las órdenes inválidas no consumen soldados ni dejan un frente a medias", _test_launch_invalid)
	_run("propuestas: validación de términos, propuesta pendiente, rechazo y destinatario", _test_proposal_rules)
	_run("paz con conquistas: traspaso de lo ocupado con conquer_cells y liberación de lo demás", _test_conquests_treaty)
	_run("paz blanca: no cambia propietarios y libera las ocupaciones de esa guerra", _test_white_peace)
	_run("guerras independientes: un tratado no toca las ocupaciones ni la guerra de otra nación", _test_independent_wars)
	_run("pagos: solo al aplicar el tratado, nunca saldos negativos y sin cambios si falla", _test_payments)
	_run("un tratado que no se puede aplicar no cambia nada (ni siquiera detiene las ofensivas)", _test_atomic_failure)
	_run("firmar la paz detiene las ofensivas entre ambas y conserva soldados coherentes", _test_peace_stops_offensives)
	_run("tregua: bloquea ataques en la API militar, se cuenta con el reloj y expira", _test_truce)
	_run("IA: decisión determinista (acepta, rechaza y contraoferta) según fuerza, territorio, bajas y duración", _test_ai_decision)
	_run("IA: propone la paz sola sin repetirse, respeta el intervalo y la caducidad", _test_ai_offers)
	_run("panel de diplomacia: guerra, formulario, respuesta de la IA, propuesta entrante y tregua", _test_diplomacy_panel)
	_run("pantalla: botón de pausa, indicador y ataque de un clic con el mapa actualizado", _test_screen)
	_run("determinismo: el mismo estado y las mismas órdenes dan el mismo resultado", _test_determinism)
	_run("las suites anteriores y los archivos del hito siguen presentes", _test_files_present)
	return _results


func _run(test_name: String, test: Callable) -> void:
	var errors: Array = test.call()
	_results.append({"name": test_name, "errors": errors})


func _expect(errors: Array, actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		errors.append("%s: se esperaba '%s' y salió '%s'" % [what, expected, actual])


func _count_signal() -> void:
	_signal_count += 1


func _collect_cells(cells: Array) -> void:
	_signal_cells.append_array(cells)


func _collect_treaty(treaty: Dictionary) -> void:
	_signal_treaties.append(treaty)


func _collect_pause(paused: bool) -> void:
	_signal_pauses.append(paused)


# ---------------------------------------------------------------------------
# Datos controlados
# ---------------------------------------------------------------------------

func _blank_data() -> Array:
	var terrain := PackedByteArray()
	terrain.resize(TerritoryGrid.CELL_COUNT)
	terrain.fill(TerritoryGrid.TERRAIN_WATER)
	var owners := PackedByteArray()
	owners.resize(TerritoryGrid.CELL_COUNT)
	owners.fill(TerritoryGrid.OWNER_NONE)
	return [terrain, owners]


func _make_duel_grid() -> TerritoryGrid:
	var data := _blank_data()
	var terrain: PackedByteArray = data[0]
	var owners: PackedByteArray = data[1]
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


func _make_tri_grid() -> TerritoryGrid:
	var data := _blank_data()
	var terrain: PackedByteArray = data[0]
	var owners: PackedByteArray = data[1]
	for y in range(10, 30):
		for x in range(10, 40):
			terrain[y * TerritoryGrid.WIDTH + x] = TerritoryGrid.TERRAIN_LAND
			if x <= 24:
				owners[y * TerritoryGrid.WIDTH + x] = PLAYER
			elif y <= 19:
				owners[y * TerritoryGrid.WIDTH + x] = AI_1
			else:
				owners[y * TerritoryGrid.WIDTH + x] = AI_2
	var grid := TerritoryGrid.new()
	grid.load_from_data(terrain, owners)
	return grid


## Mundo completo: cuadrícula, economía (50 de dinero y muchos recursos: sin déficit), ciudades (ninguna salvo que
## `with_city`: la del jugador en CITY_A), población inyectada, sectores, ocupación, guerra con reloj, ofensivas y
## diplomacia.
func _make_world(initial: Dictionary, grid: TerritoryGrid = null, with_city: bool = false) -> Dictionary:
	if grid == null:
		grid = _make_duel_grid()
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
	var wars := WarState.new(cities)
	var offensives := Offensives.new(grid, population, military, cities, occupation, wars)
	# Escenarios celda a celda de los hitos 9 y 10 (el frente ancho del hito 11 está en tests/gameplay_tests.gd).
	offensives.front_half_width = 0
	var diplomacy := Diplomacy.new(grid, economy, cities, population, occupation, wars, offensives)
	return {"grid": grid, "economy": economy, "cities": cities, "pop": population, "mil": military,
			"occ": occupation, "wars": wars, "off": offensives, "dip": diplomacy}


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
	var economy: Economy = world["economy"]
	var cities: CityManager = world["cities"]
	var nations: Dictionary = {}
	for nation_id: int in grid.get_nation_ids():
		nations[nation_id] = [pop.workers(nation_id), pop.soldiers(nation_id), mil.assigned_soldiers(nation_id), mil.available_soldiers(nation_id),
				economy.get_money(nation_id), economy.get_resources(nation_id)]
	var sectors: Array = []
	var offensives: Array = []
	for sector_id: int in mil.get_sector_ids():
		sectors.append(mil.get_sector(sector_id))
		offensives.append(off.get_offensive(sector_id))
	var occupied: Array = []
	for cell: Vector2i in occ.get_cells():
		occupied.append([cell, occ.occupier_at(cell), occ.official_owner_at(cell)])
	var war_records: Array = []
	for pair: Dictionary in wars.war_pairs():
		war_records.append(wars.get_war(pair["a"], pair["b"]))
	return {"nations": nations, "sectors": sectors, "offensives": offensives, "occupied": occupied,
			"wars": war_records, "owners": grid.copy_owner_data(), "ticks": cities.tick_count()}


## Id de la primera propuesta pendiente dirigida a la nación (-1 si no hay): así una prueba que falla no
## termina con un error de índice.
func _pending_id(dip: Diplomacy, nation_id: int) -> int:
	var pending := dip.pending_for(nation_id)
	return pending[0]["id"] if not pending.is_empty() else -1


## Ningún saldo, soldado, trabajador o asignación es negativo y lo asignado cabe en los soldados reales.
func _check_non_negative(errors: Array, world: Dictionary, what: String) -> void:
	var grid: TerritoryGrid = world["grid"]
	var pop: Population = world["pop"]
	var mil: Military = world["mil"]
	var economy: Economy = world["economy"]
	for nation_id: int in grid.get_nation_ids():
		var ok: bool = pop.workers(nation_id) >= 0 and pop.soldiers(nation_id) >= 0 and mil.assigned_soldiers(nation_id) >= 0 \
				and mil.available_soldiers(nation_id) >= 0 and economy.get_money(nation_id) >= 0 and economy.get_resources(nation_id) >= 0 \
				and mil.assigned_soldiers(nation_id) <= pop.soldiers(nation_id)
		if not ok:
			errors.append("%s: la nación %d tiene una cantidad negativa o más soldados asignados que reales" % [what, nation_id])


# ---------------------------------------------------------------------------
# Pruebas
# ---------------------------------------------------------------------------

func _test_pause() -> Array:
	var errors: Array = []
	var world := _make_world(WEAK_AI_POP, null, true)
	var cities: CityManager = world["cities"]
	var pop: Population = world["pop"]
	var mil: Military = world["mil"]
	var off: Offensives = world["off"]
	var occ: Occupation = world["occ"]
	var wars: WarState = world["wars"]
	var dip: Diplomacy = world["dip"]
	var economy: Economy = world["economy"]
	# Estado vivo: ofensiva activa contra la IA 1, movilización, guerra, tregua con la IA 2 y un reloj corriendo.
	var sid: int = mil.create_sector(PLAYER, BORDER, Military.DIR_EAST, 10)["id"]
	off.start_offensive(sid)
	pop.start_mobilization(PLAYER, 25)
	wars.start_truce(PLAYER, AI_2, 100)
	_ticks(world, 2)
	_expect(errors, [cities.is_paused(), cities.tick_count()], [false, 2], "sin pausa el reloj avanza")
	_signal_pauses = []
	cities.pause_changed.connect(_collect_pause)
	cities.set_paused(true)
	cities.set_paused(true)
	_expect(errors, [cities.is_paused(), _signal_pauses], [true, [true]], "pausar emite la señal una sola vez")
	var before := _snapshot(world)
	var city_id: int = cities.city_id_at(CITY_A)
	var city_before := cities.get_city(city_id)
	var duration_before := wars.war_duration(PLAYER, AI_1)
	var truce_before := wars.truce_remaining(PLAYER, AI_2)
	var mobilization_before := pop.get_mobilization(PLAYER)
	_expect(errors, [cities.advance(50.0), cities.advance(0.4), cities.advance(1.0)], [0, 0, 0], "en pausa advance no ejecuta ningún tick, aunque llegue mucho tiempo")
	_expect(errors, _snapshot(world) == before, true, "todo sigue idéntico: territorio, ocupaciones, ofensivas, saldos, población y soldados")
	_expect(errors, [cities.get_city(city_id) == city_before, wars.war_duration(PLAYER, AI_1), wars.truce_remaining(PLAYER, AI_2), pop.get_mobilization(PLAYER) == mobilization_before],
			[true, duration_before, truce_before, true], "tampoco avanzan el crecimiento de la ciudad, la guerra, la tregua ni la movilización")
	_expect(errors, [off.get_offensive(sid)["front"], off.get_offensive(sid)["countdown"], occ.count()], [BORDER, before["offensives"][0]["countdown"], 0], "ni el avance de la ofensiva ni su cuenta atrás")
	# Las órdenes que cambian el mundo al instante se rechazan en pausa; consultar y planificar no.
	var money := economy.get_money(PLAYER)
	var found := cities.found_city(PLAYER, Vector2i(20, 25))
	_expect(errors, [found["ok"], found["error"], economy.get_money(PLAYER), cities.city_count()], [false, CityManager.FOUND_ERR_PAUSED, money, 1], "no se funda ni se cobra en pausa")
	_expect(errors, CityManager.error_message(CityManager.FOUND_ERR_PAUSED) != "Error desconocido.", true, "hay mensaje de pausa")
	var proposal := dip.propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	_expect(errors, [proposal["ok"], proposal["error"], wars.at_war(PLAYER, AI_1)], [false, Diplomacy.ERR_PAUSED, true], "no se negocia en pausa")
	var plan := off.plan_attack(PLAYER, Vector2i(24, 20), Military.DIR_EAST, 3)
	_expect(errors, plan["ok"], true, "se puede consultar la previsión en pausa")
	var launched := off.launch_attack(PLAYER, Vector2i(24, 20), Military.DIR_EAST, 3)
	_expect(errors, [launched["ok"], mil.sector_count()], [true, 2], "y planificar un ataque, que empezará al reanudar")
	_ticks(world, 30)
	_expect(errors, [off.get_offensive(launched["sector_id"])["front"], occ.count(), world["grid"].get_cell_owner(25, 20)], [Vector2i(24, 20), 0, AI_1], "el ataque planificado no avanza mientras dura la pausa")
	# Reanudar: todo continúa desde donde estaba, sin saltos.
	cities.set_paused(false)
	_expect(errors, _signal_pauses, [true, false], "reanudar emite la señal")
	_expect(errors, cities.advance(3.0), 3, "reanudada, los ticks vuelven")
	_expect(errors, [cities.tick_count(), wars.war_duration(PLAYER, AI_1), wars.truce_remaining(PLAYER, AI_2)], [5, 5, 95], "el reloj, la guerra y la tregua siguen desde donde estaban")
	_expect(errors, occ.count() >= 1, true, "las ofensivas vuelven a avanzar")
	_check_non_negative(errors, world, "tras reanudar")
	return errors


func _test_war_state() -> Array:
	var errors: Array = []
	var world := _make_world(DUEL_POP)
	var wars: WarState = world["wars"]
	_ticks(world, 5)
	_expect(errors, wars.declare_war(PLAYER, AI_1), true, "declarar una guerra")
	var war := wars.get_war(PLAYER, AI_1)
	_expect(errors, [war["id"], war["a"], war["b"], war["aggressor"], war["start_tick"], war["duration"]], [1, PLAYER, AI_1, PLAYER, 5, 0], "el registro guarda id, partes, agresor y tick de inicio")
	_ticks(world, 7)
	_expect(errors, [wars.war_duration(PLAYER, AI_1), wars.war_duration(AI_1, PLAYER), wars.war_duration(PLAYER, AI_2)], [7, 7, 0], "la duración se mide con el reloj de juego")
	wars.declare_war(AI_2, PLAYER)
	wars.record_clash(PLAYER, AI_1, 2, 5)
	wars.record_clash(AI_1, PLAYER, 1, 1)
	wars.record_clash(PLAYER, AI_2, 4, 0)
	wars.record_clash(PLAYER, 4, 9, 9)
	_expect(errors, [wars.casualties_of(PLAYER, AI_1), wars.casualties_of(AI_1, PLAYER), wars.casualties_of(PLAYER, AI_2), wars.casualties_of(AI_2, PLAYER)], [3, 6, 4, 0], "las bajas se anotan por guerra y por bando")
	wars.record_occupation(PLAYER, AI_1)
	wars.record_occupation(PLAYER, AI_1)
	wars.record_occupation(AI_1, PLAYER)
	wars.record_occupation(PLAYER, 4)
	_expect(errors, [wars.occupations_by(PLAYER, AI_1), wars.occupations_by(AI_1, PLAYER), wars.occupations_by(PLAYER, AI_2)], [2, 1, 0], "las ocupaciones también")
	# Terminar una guerra no toca otra.
	var ended := wars.end_war(AI_1, PLAYER)
	_expect(errors, [ended["id"], ended["duration"], ended["casualties"][PLAYER], ended["casualties"][AI_1], ended["occupations"][PLAYER]], [1, 7, 3, 6, 2], "end_war devuelve el registro final")
	_expect(errors, [wars.at_war(PLAYER, AI_1), wars.at_war(PLAYER, AI_2), wars.war_count(), wars.enemies_of(PLAYER)], [false, true, 1, [AI_2]], "solo termina esa guerra")
	_expect(errors, [wars.casualties_of(PLAYER, AI_2), wars.get_war(PLAYER, AI_2)["id"]], [4, 2], "la otra guerra conserva su registro")
	_expect(errors, [wars.end_war(PLAYER, AI_1), wars.war_count()], [{}, 1], "terminar una guerra que no existe no cambia nada")
	# Treguas: se cuentan con el reloj y se niegan las guerras.
	_signal_count = 0
	wars.changed.connect(_count_signal)
	_expect(errors, [wars.start_truce(PLAYER, AI_1, 10), wars.start_truce(PLAYER, PLAYER, 10), wars.start_truce(0, AI_1, 10), wars.start_truce(PLAYER, AI_1, 0)], [true, false, false, false], "datos inválidos rechazados")
	_expect(errors, [wars.has_truce(PLAYER, AI_1), wars.has_truce(AI_1, PLAYER), wars.truce_remaining(PLAYER, AI_1), wars.has_truce(PLAYER, AI_2)], [true, true, 10, false], "tregua simétrica y solo entre esas dos")
	_expect(errors, [wars.declare_war(PLAYER, AI_1), wars.declare_war(AI_1, PLAYER), wars.at_war(PLAYER, AI_1)], [false, false, false], "con tregua no se puede declarar la guerra")
	_ticks(world, 4)
	_expect(errors, [wars.truce_remaining(PLAYER, AI_1), wars.truces_of(PLAYER), wars.truces_of(AI_2)], [6, [{"other": AI_1, "remaining": 6}], []], "la tregua cuenta atrás con el reloj")
	_signal_count = 0
	_ticks(world, 6)
	_expect(errors, [wars.has_truce(PLAYER, AI_1), wars.truce_remaining(PLAYER, AI_1), wars.truces_of(PLAYER)], [false, 0, []], "al agotarse deja de contar")
	# Diplomacy cuelga del reloj y limpia las treguas terminadas en el propio tick: ya no queda nada que expirar.
	_expect(errors, [_signal_count, wars.expire_truces()], [1, 0], "el reloj limpia la tregua terminada y avisa una vez")
	# expire_truces en solitario: un WarState con el mismo reloj pero sin Diplomacy, con dos treguas independientes.
	var bare := WarState.new(world["cities"])
	bare.start_truce(PLAYER, AI_1, 3)
	bare.start_truce(PLAYER, AI_2, 10)
	_ticks(world, 3)
	_signal_count = 0
	bare.changed.connect(_count_signal)
	_expect(errors, [bare.has_truce(PLAYER, AI_1), bare.truce_remaining(PLAYER, AI_2)], [false, 7], "sin limpiar, una tregua agotada no cuenta y la otra sigue")
	_expect(errors, [bare.expire_truces(), _signal_count, bare.expire_truces(), _signal_count], [1, 1, 0, 1], "expirar limpia solo la agotada y avisa una vez")
	_expect(errors, [bare.truce_remaining(PLAYER, AI_2), bare.truces_of(PLAYER)], [7, [{"other": AI_2, "remaining": 7}]], "la tregua que no debe expirar se conserva")
	_signal_count = 0
	_expect(errors, [wars.declare_war(PLAYER, AI_1), wars.get_war(PLAYER, AI_1)["id"], wars.casualties_of(PLAYER, AI_1)], [true, 3, 0], "terminada la tregua puede empezar una guerra nueva con registro nuevo")
	# Sin reloj (como en las suites antiguas) todo funciona con tiempo 0.
	var plain := WarState.new()
	plain.declare_war(PLAYER, AI_1)
	_expect(errors, [plain.now(), plain.war_duration(PLAYER, AI_1), plain.at_war(AI_1, PLAYER)], [0, 0, true], "WarState.new() sin reloj sigue valiendo")
	return errors


func _test_occupation_pairs() -> Array:
	var errors: Array = []
	var world := _make_world(TRI_POP, _make_tri_grid())
	var occ: Occupation = world["occ"]
	occ.occupy(PLAYER, Vector2i(25, 12))  # del jugador sobre la IA 1
	occ.occupy(PLAYER, Vector2i(26, 12))
	occ.occupy(PLAYER, Vector2i(25, 22))  # del jugador sobre la IA 2
	occ.occupy(AI_1, Vector2i(24, 12))  # de la IA 1 sobre el jugador
	_expect(errors, [occ.get_cells_between(PLAYER, AI_1), occ.get_cells_between(AI_1, PLAYER), occ.get_cells_between(PLAYER, AI_2), occ.get_cells_between(AI_2, PLAYER)],
			[[Vector2i(25, 12), Vector2i(26, 12)], [Vector2i(24, 12)], [Vector2i(25, 22)], []], "las celdas se consultan por ocupante y propietario")
	_expect(errors, [occ.count_between(PLAYER, AI_1), occ.count_between(AI_1, PLAYER), occ.count_between(AI_2, AI_1)], [2, 1, 0], "y se cuentan")
	var state := occ.export_state()
	_signal_cells = []
	occ.cells_changed.connect(_collect_cells)
	_expect(errors, occ.release_between(AI_1, PLAYER), 3, "release_between libera las de ambos sentidos")
	var released := _signal_cells.duplicate()
	released.sort()
	_expect(errors, released, [Vector2i(24, 12), Vector2i(25, 12), Vector2i(26, 12)], "avisa de las celdas liberadas para repintarlas")
	_expect(errors, [occ.get_cells(), occ.occupier_at(Vector2i(25, 22)), occ.official_owner_at(Vector2i(25, 22))], [[Vector2i(25, 22)], PLAYER, AI_2], "la ocupación de la otra guerra queda intacta")
	_expect(errors, occ.release_between(PLAYER, AI_1), 0, "liberar otra vez no hace nada")
	_expect(errors, world["grid"].get_cell_owner(25, 12), AI_1, "liberar no cambia propietarios")
	occ.import_state(state)
	_expect(errors, [occ.count(), occ.occupier_at(Vector2i(24, 12)), occ.official_owner_at(Vector2i(24, 12))], [4, AI_1, PLAYER], "import_state restaura el estado exportado")
	return errors


func _test_launch_attack() -> Array:
	var errors: Array = []
	var world := _make_world(DUEL_POP)
	var mil: Military = world["mil"]
	var off: Offensives = world["off"]
	var wars: WarState = world["wars"]
	var occ: Occupation = world["occ"]
	var pop: Population = world["pop"]
	var owners_before: PackedByteArray = world["grid"].copy_owner_data()
	# Previsión sin cambiar nada.
	var plan := off.plan_attack(PLAYER, BORDER, Military.DIR_EAST, 10)
	_expect(errors, [plan["ok"], plan["error"], plan["sector_id"], plan["state"], plan["target"], plan["assigned"], plan["max_soldiers"]], [true, Offensives.LAUNCH_OK, Military.NO_SECTOR, Offensives.STATE_READY, Vector2i(25, 15), 0, 20], "la previsión no exige crear el frente")
	var info: Dictionary = plan["info"]
	_expect(errors, [info["kind"], info["defender"], info["defense"], info["attacker_wins"], info["attacker_losses"], info["defender_losses"]], [Offensives.KIND_ENEMY, AI_1, 2, true, 1, 2], "defensa local 2 (6 soldados en 3 tramos): victoria con 1 y 2 bajas")
	_expect(errors, [mil.sector_count(), off.active_count(), wars.war_count(), mil.assigned_soldiers(PLAYER)], [0, 0, 0, 0], "planificar no crea nada, no declara la guerra y no compromete soldados")
	# Ejecución en una sola orden.
	var launched := off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 10)
	_expect(errors, [launched["ok"], launched["created"], launched["error"]], [true, true, Offensives.LAUNCH_OK], "se crea el frente y se lanza")
	var sid: int = launched["sector_id"]
	_expect(errors, [mil.sector_count(), mil.get_sector(sid)["soldiers"], off.is_active(sid), wars.at_war(PLAYER, AI_1), mil.get_summary(PLAYER)], [1, 10, true, true, {"total": 20, "assigned": 10, "available": 10}], "un frente, 10 soldados, ofensiva activa y guerra declarada")
	# La previsión coincide con lo que ocurre.
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	var clash: Dictionary = off.get_offensive(sid)["last_clash"]
	_expect(errors, [clash["won"], clash["attacker_losses"], clash["defender_losses"], clash["defense"]], [true, info["attacker_losses"], info["defender_losses"], info["defense"]], "el combate real aplica exactamente la previsión")
	_expect(errors, [mil.get_sector(sid)["soldiers"], pop.soldiers(PLAYER), pop.soldiers(AI_1), occ.occupier_at(Vector2i(25, 15)), world["grid"].get_cell_owner(25, 15)], [9, 19, 4, PLAYER, AI_1], "bajas reales de la población y ocupación sin cambiar propietario")
	_expect(errors, [wars.casualties_of(PLAYER, AI_1), wars.casualties_of(AI_1, PLAYER), wars.occupations_by(PLAYER, AI_1)], [1, 2, 1], "y quedan anotadas en el registro de la guerra")
	# Con la ofensiva activa, la misma orden solo ajusta los soldados (refuerzo o reducción) sin reiniciar nada.
	var front_before: Vector2i = off.get_offensive(sid)["front"]
	var reinforce := off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 15)
	_expect(errors, [reinforce["ok"], reinforce["created"], reinforce["sector_id"], mil.get_sector(sid)["soldiers"], mil.sector_count()], [true, false, sid, 15, 1], "reforzar reutiliza el mismo frente")
	_expect(errors, [off.get_offensive(sid)["front"], off.get_offensive(sid)["state"], mil.available_soldiers(PLAYER)], [front_before, Offensives.STATE_ACTIVE, 4], "sin reiniciar el avance y tomando de la reserva")
	var reduce := off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 5)
	_expect(errors, [reduce["ok"], mil.get_sector(sid)["soldiers"], mil.available_soldiers(PLAYER), pop.soldiers(PLAYER)], [true, 5, 14, 19], "reducir devuelve soldados a la reserva sin bajas")
	# Detenido, se puede continuar con otra cantidad.
	off.stop_offensive(sid)
	var resume := off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 8)
	_expect(errors, [resume["ok"], resume["created"], off.is_active(sid), mil.get_sector(sid)["soldiers"], mil.sector_count()], [true, false, true, 8, 1], "continuar reanuda el mismo frente con la nueva cantidad")
	# Conservar varios puntos de una misma frontera.
	var second := off.launch_attack(PLAYER, Vector2i(24, 22), Military.DIR_EAST, 4)
	_expect(errors, [second["ok"], second["created"], mil.sector_count(), off.active_count(PLAYER), mil.assigned_soldiers(PLAYER)], [true, true, 2, 2, 12], "se puede atacar desde varios puntos de la misma frontera")
	_expect(errors, world["grid"].copy_owner_data() == owners_before, true, "nada de esto cambió propietarios")
	_check_non_negative(errors, world, "tras los ataques")
	# El atacante no gana solo por enviar muchas tropas: las bajas dependen de la defensa, y con poca fuerza se pierde.
	var weak := _make_world({PLAYER: {"workers": 30, "soldiers": 20}, AI_1: {"workers": 30, "soldiers": 24}})
	var weak_plan: Dictionary = weak["off"].plan_attack(PLAYER, BORDER, Military.DIR_EAST, 3)
	_expect(errors, [weak_plan["ok"], weak_plan["info"]["attacker_wins"], weak_plan["info"]["category"]], [true, false, 2], "con pocos soldados contra una defensa mayor, la previsión anuncia derrota")
	var big_plan: Dictionary = weak["off"].plan_attack(PLAYER, BORDER, Military.DIR_EAST, 20)
	_expect(errors, [big_plan["info"]["attacker_wins"], big_plan["info"]["attacker_losses"] < 20], [true, true], "con una fuerza claramente mayor se vence pagando solo una parte de las bajas")
	return errors


func _test_launch_invalid() -> Array:
	var errors: Array = []
	var world := _make_world(DUEL_POP)
	var mil: Military = world["mil"]
	var off: Offensives = world["off"]
	var wars: WarState = world["wars"]
	var owners_before: PackedByteArray = world["grid"].copy_owner_data()
	var before := _snapshot(world)
	var cases: Array = [
		["origen ajeno", PLAYER, Vector2i(30, 15), Military.DIR_WEST, 3, Offensives.LAUNCH_ERR_SECTOR, Military.SECTOR_ERR_ORIGIN_NOT_OWNED],
		["origen fuera del mapa", PLAYER, Vector2i(-1, 5), Military.DIR_EAST, 3, Offensives.LAUNCH_ERR_SECTOR, Military.SECTOR_ERR_ORIGIN_OUT_OF_BOUNDS],
		["objetivo propio", PLAYER, Vector2i(20, 15), Military.DIR_EAST, 3, Offensives.LAUNCH_ERR_SECTOR, Military.SECTOR_ERR_TARGET_OWN],
		["objetivo agua", PLAYER, Vector2i(10, 15), Military.DIR_WEST, 3, Offensives.LAUNCH_ERR_SECTOR, Military.SECTOR_ERR_TARGET_WATER],
		["dirección inválida", PLAYER, BORDER, 7, 3, Offensives.LAUNCH_ERR_SECTOR, Military.SECTOR_ERR_BAD_DIRECTION],
		["nación desconocida", 99, BORDER, Military.DIR_EAST, 3, Offensives.LAUNCH_ERR_UNKNOWN_NATION, Military.SECTOR_OK],
		["cero soldados", PLAYER, BORDER, Military.DIR_EAST, 0, Offensives.LAUNCH_ERR_NO_SOLDIERS, Military.SECTOR_OK],
		["soldados negativos", PLAYER, BORDER, Military.DIR_EAST, -4, Offensives.LAUNCH_ERR_NO_SOLDIERS, Military.SECTOR_OK],
		["más que los disponibles", PLAYER, BORDER, Military.DIR_EAST, 21, Offensives.LAUNCH_ERR_NOT_ENOUGH, Military.SECTOR_OK],
	]
	for case: Array in cases:
		var result := off.launch_attack(case[1], case[2], case[3], case[4])
		_expect(errors, [result["ok"], result["error"], result["sector_error"], result["created"], result["sector_id"]], [false, case[5], case[6], false, Military.NO_SECTOR], "%s se rechaza" % case[0])
		_expect(errors, [mil.sector_count(), mil.assigned_soldiers(PLAYER), off.active_count(), wars.war_count()], [0, 0, 0, 0], "%s no crea un frente ni compromete soldados ni declara la guerra" % case[0])
		_expect(errors, Offensives.launch_error_message(result) != "" and Offensives.launch_error_message(result) != "Error desconocido.", true, "%s tiene mensaje" % case[0])
	_expect(errors, _snapshot(world) == before, true, "tras todas las órdenes inválidas el estado es idéntico")
	# Un avance imposible (agua o borde) se detecta antes de crear nada.
	var strip := _make_world({PLAYER: {"workers": 30, "soldiers": 10}})
	var data := _blank_data()
	var terrain: PackedByteArray = data[0]
	var owners: PackedByteArray = data[1]
	for x in range(300, 320):
		terrain[100 * TerritoryGrid.WIDTH + x] = TerritoryGrid.TERRAIN_LAND
		if x >= 310 and x <= 314:
			owners[100 * TerritoryGrid.WIDTH + x] = PLAYER
	strip["grid"].load_from_data(terrain, owners)
	var edge: Dictionary = strip["off"].launch_attack(PLAYER, Vector2i(314, 100), Military.DIR_NORTH, 4)
	_expect(errors, [edge["ok"], strip["mil"].sector_count()], [false, 0], "el agua no se ataca y no queda frente")
	var unreachable: Dictionary = strip["off"].launch_attack(PLAYER, Vector2i(314, 100), Military.DIR_EAST, 4)
	_expect(errors, [unreachable["ok"], strip["mil"].sector_count(), strip["mil"].assigned_soldiers(PLAYER)], [true, 1, 4], "tierra sin reclamar contigua: se conquista")
	# Un frente existente en otra nación que ya no es atacable no se pierde ni cambia al fallar una orden.
	var sid: int = unreachable["sector_id"]
	var too_many: Dictionary = strip["off"].launch_attack(PLAYER, Vector2i(314, 100), Military.DIR_EAST, 50)
	_expect(errors, [too_many["ok"], too_many["error"], strip["mil"].get_sector(sid)["soldiers"], strip["mil"].sector_count()], [false, Offensives.LAUNCH_ERR_NOT_ENOUGH, 4, 1], "pedir de más con un frente existente no lo toca")
	# La región del plan describe el mismo motivo que la orden.
	var plan := off.plan_attack(PLAYER, BORDER, Military.DIR_EAST, 99)
	_expect(errors, [plan["ok"], plan["error"], plan["max_soldiers"]], [false, Offensives.LAUNCH_ERR_NOT_ENOUGH, 20], "plan_attack y launch_attack dan el mismo veredicto")
	_expect(errors, world["grid"].copy_owner_data() == owners_before, true, "el territorio no cambió")
	return errors


func _test_proposal_rules() -> Array:
	var errors: Array = []
	var world := _make_world(DUEL_POP)
	var wars: WarState = world["wars"]
	var dip: Diplomacy = world["dip"]
	var economy: Economy = world["economy"]
	# Sin guerra no hay tratado.
	_expect(errors, dip.propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)["error"], Diplomacy.ERR_NOT_AT_WAR, "sin guerra no se puede proponer la paz")
	wars.declare_war(PLAYER, AI_1)
	var before := _snapshot(world)
	var invalid: Array = [
		["misma nación", PLAYER, PLAYER, Diplomacy.KIND_WHITE, 0, 0, Diplomacy.ERR_UNKNOWN_NATION],
		["nación inexistente", PLAYER, 99, Diplomacy.KIND_WHITE, 0, 0, Diplomacy.ERR_UNKNOWN_NATION],
		["tipo desconocido", PLAYER, AI_1, 5, 0, 0, Diplomacy.ERR_BAD_KIND],
		["pago negativo", PLAYER, AI_1, Diplomacy.KIND_WHITE, PLAYER, -5, Diplomacy.ERR_BAD_PAYMENT],
		["pagador ajeno a la guerra", PLAYER, AI_1, Diplomacy.KIND_WHITE, AI_2, 5, Diplomacy.ERR_BAD_PAYMENT],
		["pagador sin dinero", PLAYER, AI_1, Diplomacy.KIND_WHITE, PLAYER, 51, Diplomacy.ERR_NO_FUNDS],
	]
	for case: Array in invalid:
		var result := dip.propose(case[1], case[2], case[3], case[4], case[5])
		_expect(errors, [result["ok"], result["error"], result["response"]], [false, case[6], Diplomacy.RESPONSE_NONE], "%s se rechaza" % case[0])
		_expect(errors, result["message"] != "", true, "%s explica el motivo" % case[0])
	_expect(errors, _snapshot(world) == before, true, "las ofertas inválidas no cambian nada")
	for code in range(Diplomacy.ERR_OK, Diplomacy.ERR_TERRITORY + 1):
		_expect(errors, Diplomacy.error_message(code) != "" and Diplomacy.error_message(code) != "Error desconocido.", true, "mensaje de error %d" % code)
	_expect(errors, Diplomacy.error_message(99), "Error desconocido.", "código desconocido")
	# Una propuesta a un humano queda pendiente sin tocar saldos ni territorio; solo puede haber una.
	var money := [economy.get_money(PLAYER), economy.get_money(AI_1)]
	var pending := dip.propose(AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, PLAYER, 20)
	_expect(errors, [pending["ok"], pending["response"], pending["proposal_id"] > 0], [true, Diplomacy.RESPONSE_PENDING, true], "la propuesta a un humano queda pendiente")
	var proposal_id: int = pending["proposal_id"]
	_expect(errors, [economy.get_money(PLAYER), economy.get_money(AI_1)], money, "enviar una oferta no toca los saldos")
	_expect(errors, [dip.has_pending(PLAYER, AI_1), dip.has_pending(AI_1, PLAYER), dip.pending_for(PLAYER).size(), dip.pending_for(AI_1).size()], [true, true, 1, 0], "la propuesta pendiente se consulta en ambos sentidos y solo la ve el destinatario")
	var stored := dip.get_proposal(proposal_id)
	_expect(errors, [stored["from"], stored["to"], stored["kind"], stored["payer"], stored["amount"], stored["counter"]], [AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, PLAYER, 20, false], "con los términos enviados")
	_expect(errors, dip.proposal_text(stored), "Reino de Cobre propone: Paz con conquistas · Confederación de Alba paga 20", "texto de la propuesta")
	_expect(errors, dip.propose(AI_1, PLAYER, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)["error"], Diplomacy.ERR_PENDING_EXISTS, "no se acumulan propuestas entre las mismas naciones")
	_expect(errors, dip.propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)["error"], Diplomacy.ERR_PENDING_EXISTS, "ni en el otro sentido")
	# Responder: solo el destinatario, y rechazar descarta sin consecuencias.
	_expect(errors, [dip.accept(proposal_id, AI_1)["error"], dip.reject(proposal_id, AI_1)["error"], dip.has_pending(PLAYER, AI_1)], [Diplomacy.ERR_NOT_RECIPIENT, Diplomacy.ERR_NOT_RECIPIENT, true], "el remitente no puede responder su propia propuesta")
	_expect(errors, [dip.accept(999, PLAYER)["error"], dip.reject(999, PLAYER)["error"]], [Diplomacy.ERR_UNKNOWN_PROPOSAL, Diplomacy.ERR_UNKNOWN_PROPOSAL], "una propuesta inexistente se rechaza")
	_signal_count = 0
	dip.changed.connect(_count_signal)
	var rejected := dip.reject(proposal_id, PLAYER)
	_expect(errors, [rejected["ok"], rejected["response"], dip.has_pending(PLAYER, AI_1), wars.at_war(PLAYER, AI_1), _signal_count], [true, Diplomacy.RESPONSE_REJECTED, false, true, 1], "rechazar la descarta, la guerra sigue y se avisa")
	_expect(errors, [economy.get_money(PLAYER), economy.get_money(AI_1)], money, "y los saldos siguen igual")
	_expect(errors, dip.history().size(), 0, "no se firmó ningún tratado")
	return errors


## Mundo de duelo con la guerra declarada y las ocupaciones de los tratados: el jugador ocupa 3 celdas de la IA 1
## contiguas a su territorio más una suelta (30, 25); la IA 1 ocupa 2 celdas contiguas del jugador.
func _treaty_world() -> Dictionary:
	var world := _make_world(DUEL_POP)
	world["wars"].declare_war(PLAYER, AI_1)
	var occ: Occupation = world["occ"]
	for cell in [Vector2i(25, 15), Vector2i(26, 15), Vector2i(25, 16), Vector2i(30, 25)]:
		occ.occupy(PLAYER, cell)
	for cell in [Vector2i(24, 20), Vector2i(23, 20)]:
		occ.occupy(AI_1, cell)
	return world


func _test_conquests_treaty() -> Array:
	var errors: Array = []
	var world := _treaty_world()
	var grid: TerritoryGrid = world["grid"]
	var occ: Occupation = world["occ"]
	var wars: WarState = world["wars"]
	var dip: Diplomacy = world["dip"]
	var off: Offensives = world["off"]
	var owners_before: PackedByteArray = grid.copy_owner_data()
	# La IA 1 ve la guerra como perdida: es débil (6 contra 20 soldados).
	var stance := dip.ai_stance(AI_1, PLAYER)
	_expect(errors, [stance["own_soldiers"], stance["rival_soldiers"], stance["strength"], stance["held_own"], stance["held_other"], stance["hope"], stance["weariness"], stance["reluctance"]],
			[6, 20, 230, 2, 4, -58, 0, -58], "la reluctancia de la IA 1 se calcula con la fórmula documentada")
	# El ensayo no cambia nada y usa la validación real de conquer_cells.
	var plan := dip.plan_treaty(PLAYER, AI_1, Diplomacy.KIND_CONQUESTS)
	_expect(errors, [plan["ok"], plan["steps"].size(), plan["gains"], plan["dropped"], plan["released"]], [true, 2, {PLAYER: 3, AI_1: 2}, 1, 6], "ensayo: 3 celdas para el jugador, 2 para la IA 1, 1 suelta que no se concede")
	if plan["steps"].size() == 2:
		_expect(errors, [plan["steps"][0]["nation"], plan["steps"][0]["cells"].size(), plan["steps"][1]["nation"], plan["steps"][1]["cells"].size()], [PLAYER, 3, AI_1, 2], "en orden: primero la nación de menor id")
	_expect(errors, [grid.copy_owner_data() == owners_before, occ.count()], [true, 6], "ensayar no cambia territorio ni ocupaciones")
	# Firmar.
	_signal_cells = []
	_signal_treaties = []
	dip.territory_changed.connect(_collect_cells)
	dip.treaty_signed.connect(_collect_treaty)
	var result := dip.propose(PLAYER, AI_1, Diplomacy.KIND_CONQUESTS, Diplomacy.NO_PAYER, 0)
	_expect(errors, [result["ok"], result["response"], result["message"].begins_with("Reino de Cobre acepta."), result["treaty"]["gains"]], [true, Diplomacy.RESPONSE_ACCEPTED, true, {PLAYER: 3, AI_1: 2}], "la IA 1 acepta y el tratado se aplica")
	for cell in [Vector2i(25, 15), Vector2i(26, 15), Vector2i(25, 16)]:
		_expect(errors, [grid.get_cell_owner(cell.x, cell.y), occ.is_occupied(cell)], [PLAYER, false], "la celda %s ocupada por el jugador es ahora suya" % cell)
	for cell in [Vector2i(24, 20), Vector2i(23, 20)]:
		_expect(errors, [grid.get_cell_owner(cell.x, cell.y), occ.is_occupied(cell)], [AI_1, false], "la celda %s ocupada por la IA 1 es ahora suya" % cell)
	_expect(errors, [grid.get_cell_owner(30, 25), occ.is_occupied(Vector2i(30, 25))], [AI_1, false], "la celda suelta no se concede: sigue siendo de la IA 1 y se libera")
	var changed_cells := 0
	for index in TerritoryGrid.CELL_COUNT:
		if grid.owner_at(index) != owners_before[index]:
			changed_cells += 1
	_expect(errors, [changed_cells, _signal_cells.size(), occ.count()], [5, 5, 0], "exactamente 5 celdas cambiaron de dueño, se avisó de todas y no queda ocupación")
	_expect(errors, [wars.at_war(PLAYER, AI_1), wars.war_count(), wars.has_truce(PLAYER, AI_1), wars.truce_remaining(PLAYER, AI_1)], [false, 0, true, DiplomacyBalance.TRUCE_TICKS], "no queda guerra activa y empieza la tregua")
	var history := dip.history()
	_expect(errors, [_signal_treaties.size(), history.size()], [1, 1], "se avisó del tratado y quedó en el historial")
	if history.size() == 1:
		_expect(errors, [history[0]["kind"], history[0]["war"]["id"]], [Diplomacy.KIND_CONQUESTS, 1], "con su tipo y el registro de su guerra")
	_expect(errors, dip.treaty_text(result["treaty"]),
			"Paz firmada (Paz con conquistas). Confederación de Alba gana 3 celdas y Reino de Cobre gana 2. Tregua de 60 s.", "texto del resultado")
	_check_non_negative(errors, world, "tras la paz con conquistas")
	# Una celda concedida cambia de verdad el territorio: el ocupante ya puede usarla como propia.
	_expect(errors, grid.conquer_cells(PLAYER, [Vector2i(27, 15)])["ok"], true, "el territorio traspasado cuenta como propio (contacto para futuras conquistas)")
	return errors


func _test_white_peace() -> Array:
	var errors: Array = []
	var world := _treaty_world()
	var grid: TerritoryGrid = world["grid"]
	var occ: Occupation = world["occ"]
	var wars: WarState = world["wars"]
	var dip: Diplomacy = world["dip"]
	var owners_before: PackedByteArray = grid.copy_owner_data()
	var plan := dip.plan_treaty(PLAYER, AI_1, Diplomacy.KIND_WHITE)
	_expect(errors, [plan["ok"], plan["steps"], plan["gains"], plan["dropped"], plan["released"]], [true, [], {PLAYER: 0, AI_1: 0}, 6, 6], "la paz blanca no traspasa nada y libera las 6 ocupaciones")
	_signal_cells = []
	dip.territory_changed.connect(_collect_cells)
	var cells_released: Array = []
	var capture := func(cells: Array) -> void: cells_released.append_array(cells)
	occ.cells_changed.connect(capture)
	var result := dip.propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	_expect(errors, [result["ok"], result["response"], result["message"].begins_with("Reino de Cobre acepta.")], [true, Diplomacy.RESPONSE_ACCEPTED, true], "la IA 1 acepta la paz blanca")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ningún propietario cambió")
	_expect(errors, [occ.count(), cells_released.size(), _signal_cells.size()], [0, 6, 0], "las 6 ocupaciones se liberaron (y se avisó para repintarlas) sin cambios de propiedad")
	_expect(errors, [wars.at_war(PLAYER, AI_1), wars.has_truce(PLAYER, AI_1)], [false, true], "la guerra termina y empieza la tregua")
	_expect(errors, result["message"].contains("Se liberan 6 celdas ocupadas."), true, "el mensaje lo explica")
	# La paz blanca no revierte la tierra sin reclamar conquistada antes: nunca fue del enemigo.
	var world2 := _make_world(DUEL_POP, _make_gap_grid())
	world2["wars"].declare_war(PLAYER, AI_1)
	var conquered: Dictionary = world2["grid"].conquer_cells(PLAYER, [Vector2i(25, 15)])
	_expect(errors, conquered["ok"], true, "el jugador conquista una celda libre durante la guerra")
	var white: Dictionary = world2["dip"].propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	_expect(errors, [white["ok"], world2["grid"].get_cell_owner(25, 15)], [true, PLAYER], "la paz blanca no se la quita")
	return errors


## Como el mapa de duelo, con (25, 15) y (26, 15) sin reclamar.
func _make_gap_grid() -> TerritoryGrid:
	var base := _make_duel_grid()
	var owners := base.copy_owner_data()
	owners[15 * TerritoryGrid.WIDTH + 25] = TerritoryGrid.OWNER_NONE
	owners[15 * TerritoryGrid.WIDTH + 26] = TerritoryGrid.OWNER_NONE
	var grid := TerritoryGrid.new()
	grid.load_from_data(base.copy_terrain_data(), owners)
	return grid


func _test_independent_wars() -> Array:
	var errors: Array = []
	var world := _make_world(TRI_POP, _make_tri_grid())
	var grid: TerritoryGrid = world["grid"]
	var occ: Occupation = world["occ"]
	var wars: WarState = world["wars"]
	var dip: Diplomacy = world["dip"]
	wars.declare_war(PLAYER, AI_1)
	wars.declare_war(PLAYER, AI_2)
	occ.occupy(PLAYER, Vector2i(25, 12))  # sobre la IA 1
	occ.occupy(PLAYER, Vector2i(25, 22))  # sobre la IA 2
	occ.occupy(AI_2, Vector2i(24, 25))  # de la IA 2 sobre el jugador
	wars.record_clash(PLAYER, AI_2, 3, 2)
	var owners_before: PackedByteArray = grid.copy_owner_data()
	# Paz blanca con la IA 1: la otra guerra queda tal cual.
	var white := dip.propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	_expect(errors, [white["ok"], white["response"]], [true, Diplomacy.RESPONSE_ACCEPTED], "la IA 1 acepta la paz blanca")
	_expect(errors, [wars.at_war(PLAYER, AI_1), wars.at_war(PLAYER, AI_2), wars.has_truce(PLAYER, AI_1), wars.has_truce(PLAYER, AI_2)], [false, true, true, false], "solo termina la guerra con la IA 1 y solo hay tregua con ella")
	_expect(errors, [occ.count_between(PLAYER, AI_1), occ.count_between(PLAYER, AI_2), occ.count_between(AI_2, PLAYER)], [0, 1, 1], "las ocupaciones de la guerra con la IA 2 siguen intactas")
	_expect(errors, [wars.casualties_of(PLAYER, AI_2), wars.casualties_of(AI_2, PLAYER)], [3, 2], "y su registro de bajas también")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "ni un propietario cambió")
	# Después, la paz con conquistas con la IA 2 traspasa solo lo suyo.
	var conquests := dip.propose(PLAYER, AI_2, Diplomacy.KIND_CONQUESTS, Diplomacy.NO_PAYER, 0)
	_expect(errors, [conquests["ok"], conquests["response"]], [true, Diplomacy.RESPONSE_ACCEPTED], "la IA 2 acepta la paz con conquistas")
	_expect(errors, [grid.get_cell_owner(25, 22), grid.get_cell_owner(24, 25), grid.get_cell_owner(25, 12)], [PLAYER, AI_2, AI_1], "cada celda va a su ocupante y la de la IA 1 no se toca")
	_expect(errors, [occ.count(), wars.war_count(), wars.has_truce(PLAYER, AI_1), wars.has_truce(PLAYER, AI_2), dip.history().size()], [0, 0, true, true, 2], "sin guerras, con dos treguas y dos tratados")
	return errors


func _test_payments() -> Array:
	var errors: Array = []
	# La IA 1 paga (acepta: está perdiendo).
	var world := _treaty_world()
	var economy: Economy = world["economy"]
	var dip: Diplomacy = world["dip"]
	var wars: WarState = world["wars"]
	var total_before: int = economy.get_money(PLAYER) + economy.get_money(AI_1)
	var paid := dip.propose(PLAYER, AI_1, Diplomacy.KIND_CONQUESTS, AI_1, 10)
	_expect(errors, [paid["ok"], paid["response"], economy.get_money(PLAYER), economy.get_money(AI_1)], [true, Diplomacy.RESPONSE_ACCEPTED, 60, 40], "la IA 1 paga 10 al jugador al firmar")
	_expect(errors, [paid["treaty"]["payer"], paid["treaty"]["amount"], economy.get_money(PLAYER) + economy.get_money(AI_1)], [AI_1, 10, total_before], "el dinero se transfiere, no se crea ni se destruye")
	_expect(errors, paid["message"].contains("Reino de Cobre paga 10"), true, "el mensaje dice quién paga y cuánto")
	# El jugador paga.
	var world2 := _treaty_world()
	var paid2: Dictionary = world2["dip"].propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, PLAYER, 30)
	_expect(errors, [paid2["ok"], world2["economy"].get_money(PLAYER), world2["economy"].get_money(AI_1)], [true, 20, 80], "el jugador paga 30 a la IA 1")
	# Pagar más de lo que se tiene se rechaza al proponer, sin tocar nada.
	var world3 := _treaty_world()
	var before3 := _snapshot(world3)
	var too_much: Dictionary = world3["dip"].propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, PLAYER, 51)
	_expect(errors, [too_much["ok"], too_much["error"]], [false, Diplomacy.ERR_NO_FUNDS], "el jugador no puede ofrecer lo que no tiene")
	var too_much_ai: Dictionary = world3["dip"].propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, AI_1, 51)
	_expect(errors, [too_much_ai["ok"], too_much_ai["error"]], [false, Diplomacy.ERR_NO_FUNDS], "ni exigir a la IA 1 más de lo que tiene")
	_expect(errors, _snapshot(world3) == before3, true, "y no cambia ningún saldo ni territorio")
	# Gastar todo el saldo exacto no deja negativos.
	var exact: Dictionary = world3["dip"].propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, PLAYER, 50)
	_expect(errors, [exact["ok"], world3["economy"].get_money(PLAYER), world3["economy"].get_money(AI_1)], [true, 0, 100], "pagar exactamente todo el saldo es válido y lo deja en 0")
	_check_non_negative(errors, world3, "tras pagar todo")
	# Una propuesta a un humano no toca saldos hasta que se acepta.
	var world4 := _treaty_world()
	var offered: Dictionary = world4["dip"].propose(AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, PLAYER, 40)
	_expect(errors, [offered["response"], world4["economy"].get_money(PLAYER), world4["economy"].get_money(AI_1), world4["wars"].at_war(PLAYER, AI_1)], [Diplomacy.RESPONSE_PENDING, 50, 50, true], "pendiente: ni saldos ni guerra cambian")
	var accepted: Dictionary = world4["dip"].accept(offered["proposal_id"], PLAYER)
	_expect(errors, [accepted["ok"], world4["economy"].get_money(PLAYER), world4["economy"].get_money(AI_1), world4["wars"].at_war(PLAYER, AI_1)], [true, 10, 90, false], "al aceptar se paga y se firma")
	_check_non_negative(errors, world4, "tras aceptar")
	return errors


func _test_atomic_failure() -> Array:
	var errors: Array = []
	var world := _treaty_world()
	var economy: Economy = world["economy"]
	var dip: Diplomacy = world["dip"]
	var wars: WarState = world["wars"]
	var occ: Occupation = world["occ"]
	var off: Offensives = world["off"]
	var mil: Military = world["mil"]
	# Una ofensiva activa contra la IA 1 que el tratado fallido no debe detener.
	var sid: int = mil.create_sector(PLAYER, Vector2i(24, 22), Military.DIR_EAST, 5)["id"]
	off.start_offensive(sid)
	var offered: Dictionary = dip.propose(AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, PLAYER, 40)
	_expect(errors, offered["response"], Diplomacy.RESPONSE_PENDING, "la IA 1 propone y exige 40")
	economy.spend_money(PLAYER, 30)  # entre la oferta y la respuesta el jugador gasta su dinero: le quedan 20
	var before := _snapshot(world)
	var failed := dip.accept(offered["proposal_id"], PLAYER)
	_expect(errors, [failed["ok"], failed["error"], failed["message"]], [false, Diplomacy.ERR_NO_FUNDS, Diplomacy.error_message(Diplomacy.ERR_NO_FUNDS)], "el pago ya no es posible")
	_expect(errors, _snapshot(world) == before, true, "no cambia nada: ni territorio, ni ocupaciones, ni saldos, ni soldados, ni ofensivas")
	_expect(errors, [wars.at_war(PLAYER, AI_1), wars.has_truce(PLAYER, AI_1), off.is_active(sid), occ.count(), dip.history().size(), dip.has_pending(PLAYER, AI_1)], [true, false, true, 6, 0, true], "la guerra y la ofensiva siguen; la propuesta se conserva para reintentar")
	# Con dinero otra vez, el mismo tratado se aplica.
	economy.add(PLAYER, 25, 0)
	var retried := dip.accept(offered["proposal_id"], PLAYER)
	_expect(errors, [retried["ok"], economy.get_money(PLAYER), economy.get_money(AI_1), wars.at_war(PLAYER, AI_1)], [true, 5, 90, false], "con saldo suficiente se firma")
	# La guerra puede haber terminado entre tanto: aceptar una propuesta obsoleta falla sin cambios.
	var world2 := _treaty_world()
	var stale: Dictionary = world2["dip"].propose(AI_1, PLAYER, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	world2["wars"].end_war(PLAYER, AI_1)
	var before2 := _snapshot(world2)
	var late: Dictionary = world2["dip"].accept(stale["proposal_id"], PLAYER)
	_expect(errors, [late["ok"], late["error"], _snapshot(world2) == before2], [false, Diplomacy.ERR_NOT_AT_WAR, true], "sin guerra no se aplica nada")
	return errors


func _test_peace_stops_offensives() -> Array:
	var errors: Array = []
	var world := _make_world(TRI_POP, _make_tri_grid())
	var grid: TerritoryGrid = world["grid"]
	var mil: Military = world["mil"]
	var off: Offensives = world["off"]
	var occ: Occupation = world["occ"]
	var wars: WarState = world["wars"]
	var dip: Diplomacy = world["dip"]
	var pop: Population = world["pop"]
	var first: int = mil.create_sector(PLAYER, Vector2i(24, 15), Military.DIR_EAST, 8)["id"]  # contra la IA 1
	var second: int = mil.create_sector(PLAYER, Vector2i(24, 25), Military.DIR_EAST, 6)["id"]  # contra la IA 2
	off.start_offensive(first)
	off.start_offensive(second)
	_ticks(world, Balance.ADVANCE_INTERVAL_TICKS)
	_expect(errors, [off.active_count(PLAYER), occ.count_between(PLAYER, AI_1), occ.count_between(PLAYER, AI_2)], [2, 1, 1], "dos guerras y dos ocupaciones en marcha")
	var soldiers_before := pop.soldiers(PLAYER)
	var assigned_first: int = mil.get_sector(first)["soldiers"]
	var owners_before: PackedByteArray = grid.copy_owner_data()
	var result := dip.propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	_expect(errors, [result["ok"], result["response"], result["treaty"]["stopped"]], [true, Diplomacy.RESPONSE_ACCEPTED, 1], "la paz con la IA 1 detuvo una ofensiva")
	_expect(errors, [off.sector_state(first), off.get_offensive(first)["reason"], off.sector_state(second)], [Offensives.STATE_STOPPED, Offensives.STOP_MANUAL, Offensives.STATE_ACTIVE], "solo la dirigida contra la IA 1; la otra sigue")
	_expect(errors, [mil.get_sector(first)["soldiers"], pop.soldiers(PLAYER), mil.available_soldiers(PLAYER)], [assigned_first, soldiers_before, soldiers_before - assigned_first - mil.get_sector(second)["soldiers"]], "los soldados y las reservas siguen coherentes (la paz no los destruye)")
	_expect(errors, [occ.count_between(PLAYER, AI_1), occ.count_between(PLAYER, AI_2)], [0, 1], "la ocupación de la IA 1 desaparece; la de la IA 2 se mantiene")
	_expect(errors, grid.copy_owner_data() == owners_before, true, "la paz blanca no cambió propietarios")
	# Detener o reanudar una invasión nunca cambia la propiedad oficial.
	off.stop_offensive(second)
	off.start_offensive(second)
	_expect(errors, grid.copy_owner_data() == owners_before, true, "detener y reanudar no cambia la propiedad")
	# La ofensiva detenida por el tratado no puede reanudarse contra la IA 1 durante la tregua.
	var resumed := off.start_offensive(first)
	_expect(errors, [resumed["ok"], resumed["error"], resumed["reason"]], [false, Offensives.START_ERR_BLOCKED, Offensives.STOP_TRUCE], "bloqueada por la tregua")
	_check_non_negative(errors, world, "tras la paz")
	return errors


func _test_truce() -> Array:
	var errors: Array = []
	var world := _make_world(DUEL_POP)
	var mil: Military = world["mil"]
	var off: Offensives = world["off"]
	var wars: WarState = world["wars"]
	var dip: Diplomacy = world["dip"]
	var cities: CityManager = world["cities"]
	var sid: int = off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 6)["sector_id"]
	_expect(errors, wars.at_war(PLAYER, AI_1), true, "el ataque declara la guerra")
	var peace := dip.propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	_expect(errors, peace["response"], Diplomacy.RESPONSE_ACCEPTED, "se firma la paz")
	var truce := DiplomacyBalance.TRUCE_TICKS
	_expect(errors, [wars.has_truce(PLAYER, AI_1), dip.truce_remaining(PLAYER, AI_1), dip.truce_remaining(AI_1, PLAYER)], [true, truce, truce], "la tregua es de la duración configurada y simétrica")
	# La API militar impone la tregua, no solo la interfaz.
	var assigned := mil.assigned_soldiers(PLAYER)
	var sectors := mil.sector_count()
	var plan := off.plan_attack(PLAYER, BORDER, Military.DIR_EAST, 3)
	_expect(errors, [plan["ok"], plan["error"], plan["reason"]], [false, Offensives.LAUNCH_ERR_BLOCKED, Offensives.STOP_TRUCE], "la previsión ya avisa de la tregua")
	var by_player := off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 3)
	_expect(errors, [by_player["ok"], by_player["error"], by_player["reason"], by_player["created"]], [false, Offensives.LAUNCH_ERR_BLOCKED, Offensives.STOP_TRUCE, false], "el jugador no puede atacar a la IA 1")
	var fresh := off.launch_attack(PLAYER, Vector2i(24, 20), Military.DIR_EAST, 3)
	_expect(errors, [fresh["ok"], fresh["created"], mil.sector_count(), mil.assigned_soldiers(PLAYER)], [false, false, sectors, assigned], "tampoco desde otro punto: sin frente nuevo ni soldados consumidos")
	var by_ai := off.launch_attack(AI_1, Vector2i(25, 15), Military.DIR_WEST, 3)
	_expect(errors, [by_ai["ok"], by_ai["reason"], wars.at_war(PLAYER, AI_1)], [false, Offensives.STOP_TRUCE, false], "ni la IA 1 al jugador, y no se declara la guerra")
	var direct := off.start_offensive(sid)
	_expect(errors, [direct["ok"], direct["error"], direct["reason"]], [false, Offensives.START_ERR_BLOCKED, Offensives.STOP_TRUCE], "ni reanudando el frente anterior")
	_expect(errors, Offensives.stop_reason_message(Offensives.STOP_TRUCE), "tregua vigente", "mensaje de la tregua")
	_expect(errors, Offensives.launch_error_message(by_player), "No se puede avanzar: tregua vigente.", "y el mensaje de la orden")
	# El reloj la cuenta; la tregua con otra nación no cuenta.
	_ticks(world, truce - 1)
	_expect(errors, [wars.has_truce(PLAYER, AI_1), dip.truce_remaining(PLAYER, AI_1)], [true, 1], "a un tick de acabar sigue vigente")
	_expect(errors, off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 3)["ok"], false, "y sigue bloqueando")
	_ticks(world, 1)
	_expect(errors, [wars.has_truce(PLAYER, AI_1), dip.truce_remaining(PLAYER, AI_1)], [false, 0], "al terminar el plazo la tregua expira")
	var again := off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 3)
	_expect(errors, [again["ok"], again["sector_id"], wars.at_war(PLAYER, AI_1), wars.get_war(PLAYER, AI_1)["id"]], [true, sid, true, 2], "se puede atacar otra vez y empieza una guerra nueva")
	_expect(errors, [wars.casualties_of(PLAYER, AI_1), wars.get_war(PLAYER, AI_1)["start_tick"]], [0, cities.tick_count()], "con un registro nuevo")
	# Una tregua con la IA 1 no impide atacar a otras naciones ni tierra sin reclamar.
	var tri := _make_world(TRI_POP, _make_tri_grid())
	tri["wars"].declare_war(PLAYER, AI_1)
	tri["dip"].propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	var other: Dictionary = tri["off"].launch_attack(PLAYER, Vector2i(24, 25), Military.DIR_EAST, 4)
	_expect(errors, [other["ok"], tri["wars"].at_war(PLAYER, AI_2)], [true, true], "la tregua con la IA 1 no protege a la IA 2")
	return errors


func _test_ai_decision() -> Array:
	var errors: Array = []
	# --- IA que va ganando: 24 soldados contra 6 y 5 celdas del jugador ocupadas ---
	var winning := _winning_world()
	var dip: Diplomacy = winning["dip"]
	var stance := dip.ai_stance(AI_1, PLAYER)
	_expect(errors, [stance["strength"], stance["hope"], stance["reluctance"]], [800, 70, 70], "la IA 1 que va ganando tiene reluctancia 70")
	var white := dip.evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	_expect(errors, [white["response"], white["utility"], white["shortfall"]], [Diplomacy.RESPONSE_REJECTED, 0, 70], "paz blanca gratis: la rechaza (le faltan 70 puntos, más del límite de contraoferta)")
	var conquests := dip.evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, Diplomacy.NO_PAYER, 0)
	_expect(errors, [conquests["response"], conquests["utility"]], [Diplomacy.RESPONSE_REJECTED, 10], "paz con conquistas gratis: vale 10 puntos (5 celdas) y también la rechaza")
	var rejected := dip.propose(PLAYER, AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	_expect(errors, [rejected["ok"], rejected["response"], rejected["message"]], [true, Diplomacy.RESPONSE_REJECTED, "Reino de Cobre rechaza la propuesta: cree que va ganando la guerra."], "mensaje claro del rechazo")
	_expect(errors, [winning["wars"].at_war(PLAYER, AI_1), winning["occ"].count(), dip.history().size(), dip.pending_for(PLAYER).size()], [true, 5, 0, 0], "rechazar no cambia nada")
	winning["economy"].add(PLAYER, 100, 0)
	var boundary := dip.evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, PLAYER, 60)
	_expect(errors, [boundary["response"], boundary["utility"]], [Diplomacy.RESPONSE_ACCEPTED, 70], "pagando 60 por las conquistas llega justo a 70: acepta")
	var near := dip.evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, PLAYER, 59)
	_expect(errors, [near["response"], near["utility"], near["shortfall"], near["counter"]], [Diplomacy.RESPONSE_COUNTER, 69, 1, {"kind": Diplomacy.KIND_CONQUESTS, "payer": PLAYER, "amount": 60}], "con 59 le falta 1: contraoferta los mismos términos pagando 60")
	var counter := dip.propose(PLAYER, AI_1, Diplomacy.KIND_CONQUESTS, PLAYER, 59)
	_expect(errors, [counter["ok"], counter["response"], counter["proposal_id"] > 0], [true, Diplomacy.RESPONSE_COUNTER, true], "la IA contraoferta")
	_expect(errors, counter["message"], "Reino de Cobre contraoferta: Paz con conquistas · Confederación de Alba paga 60.", "mensaje de la contraoferta")
	var offer := dip.get_proposal(counter["proposal_id"])
	_expect(errors, [offer["from"], offer["to"], offer["counter"], offer["amount"], winning["economy"].get_money(PLAYER)], [AI_1, PLAYER, true, 60, 150], "queda como propuesta pendiente de la IA al jugador, sin tocar saldos")
	_expect(errors, dip.proposal_text(offer), "Contraoferta de Reino de Cobre: Paz con conquistas · Confederación de Alba paga 60", "texto para la interfaz")
	var taken := dip.accept(counter["proposal_id"], PLAYER)
	_expect(errors, [taken["ok"], winning["economy"].get_money(PLAYER), winning["economy"].get_money(AI_1), winning["grid"].get_cell_owner(24, 10), winning["wars"].at_war(PLAYER, AI_1)], [true, 90, 110, AI_1, false], "aceptar la contraoferta paga 60 y concede las 5 celdas a la IA 1")
	# Rechazar la contraoferta la descarta sin más.
	var winning2 := _winning_world()
	winning2["economy"].add(PLAYER, 100, 0)
	var counter2: Dictionary = winning2["dip"].propose(PLAYER, AI_1, Diplomacy.KIND_CONQUESTS, PLAYER, 59)
	var declined: Dictionary = winning2["dip"].reject(counter2["proposal_id"], PLAYER)
	_expect(errors, [declined["ok"], winning2["wars"].at_war(PLAYER, AI_1), winning2["economy"].get_money(PLAYER), winning2["occ"].count()], [true, true, 150, 5], "rechazar la contraoferta mantiene la guerra y los saldos")
	# --- Cansancio: la duración y las bajas propias hacen ceder a la IA ---
	var tired := _winning_world()
	_ticks(tired, 31)
	_expect(errors, tired["dip"].ai_stance(AI_1, PLAYER)["reluctance"], 39, "31 ticks de guerra restan 31: reluctancia 39")
	var tired_white: Dictionary = tired["dip"].evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	_expect(errors, [tired_white["response"], tired_white["counter"]], [Diplomacy.RESPONSE_COUNTER, {"kind": Diplomacy.KIND_WHITE, "payer": PLAYER, "amount": 39}], "a los 31 ticks contraoferta la paz blanca pagando 39 (el cansancio acerca la paz)")
	var bloody := _winning_world()
	bloody["wars"].record_clash(PLAYER, AI_1, 0, 20)
	_expect(errors, [bloody["dip"].ai_stance(AI_1, PLAYER)["weariness"], bloody["dip"].ai_stance(AI_1, PLAYER)["reluctance"]], [40, 30], "20 bajas propias de la IA 1 restan 40: reluctancia 30")
	var exhausted := _winning_world()
	exhausted["wars"].record_clash(PLAYER, AI_1, 0, 40)
	_expect(errors, exhausted["dip"].evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)["response"], Diplomacy.RESPONSE_ACCEPTED, "con 40 bajas propias (reluctancia -10) acepta la paz blanca")
	# --- IA que va perdiendo: acepta la paz y puede pagarla ---
	var losing := _make_world(WEAK_AI_POP)
	losing["wars"].declare_war(PLAYER, AI_1)
	for y in range(10, 15):
		losing["occ"].occupy(PLAYER, Vector2i(25, y))
	var ldip: Diplomacy = losing["dip"]
	_expect(errors, ldip.ai_stance(AI_1, PLAYER)["reluctance"], -70, "la IA 1 débil tiene reluctancia -70")
	var asks := ldip.evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, AI_1, 50)
	_expect(errors, [asks["response"], asks["utility"]], [Diplomacy.RESPONSE_ACCEPTED, -60], "acepta pagar 50 por las conquistas (utilidad -60 ≥ -70)")
	losing["economy"].add(AI_1, 100, 0)
	var too_expensive := ldip.evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, AI_1, 61)
	_expect(errors, [too_expensive["response"], too_expensive["utility"], too_expensive["counter"]], [Diplomacy.RESPONSE_COUNTER, -71, {"kind": Diplomacy.KIND_CONQUESTS, "payer": AI_1, "amount": 60}], "exigir 61 le falta 1: contraoferta pagando 60")
	var way_too_much := ldip.evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, AI_1, 140)
	_expect(errors, way_too_much["response"], Diplomacy.RESPONSE_REJECTED, "exigir 140 le falta demasiado: rechaza")
	var deal: Dictionary = ldip.propose(PLAYER, AI_1, Diplomacy.KIND_CONQUESTS, AI_1, 50)
	_expect(errors, [deal["response"], losing["economy"].get_money(PLAYER), losing["economy"].get_money(AI_1), losing["grid"].get_cell_owner(25, 10)], [Diplomacy.RESPONSE_ACCEPTED, 100, 100, PLAYER], "la IA 1 derrotada cede 5 celdas y paga 50")
	# --- Si el pago que haría falta no es posible, la IA rechaza; si la paz blanca sí lo es, la contraoferta cambia de tipo ---
	var poor := _winning_world()
	poor["wars"].record_clash(PLAYER, AI_1, 0, 20)  # reluctancia 30: le faltan 30 con una paz blanca gratis
	poor["economy"].spend_money(PLAYER, 50)
	var poor_eval: Dictionary = poor["dip"].evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0)
	_expect(errors, [poor_eval["response"], poor_eval["shortfall"], poor_eval["counter"]], [Diplomacy.RESPONSE_REJECTED, 30, {}], "el jugador no tiene los 30 que pediría: rechaza en vez de contraofertar algo imposible")
	var fallback := _make_world(WINNING_AI_POP)
	fallback["wars"].declare_war(PLAYER, AI_1)
	for y in range(10, 13):
		fallback["occ"].occupy(PLAYER, Vector2i(25, y))
	_ticks(fallback, 25)
	_expect(errors, fallback["dip"].ai_stance(AI_1, PLAYER)["reluctance"], 29, "IA 1 fuerte, 3 celdas suyas ocupadas y 25 ticks de guerra: reluctancia 29")
	fallback["economy"].spend_money(PLAYER, 20)
	var fallback_eval: Dictionary = fallback["dip"].evaluate_terms(AI_1, PLAYER, Diplomacy.KIND_CONQUESTS, Diplomacy.NO_PAYER, 0)
	_expect(errors, [fallback_eval["response"], fallback_eval["utility"], fallback_eval["counter"]], [Diplomacy.RESPONSE_COUNTER, -6, {"kind": Diplomacy.KIND_WHITE, "payer": PLAYER, "amount": 29}],
			"las conquistas le costarían 3 celdas y pediría 35 (el jugador tiene 30): propone la paz blanca por 29")
	_expect(errors, [winning["economy"].get_money(PLAYER) >= 0, poor["economy"].get_money(PLAYER)], [true, 0], "ningún saldo es negativo")
	# --- Sin soldados ni nadie: la decisión no divide por cero ---
	var empty := _make_world({PLAYER: {"workers": 30, "soldiers": 0}, AI_1: {"workers": 30, "soldiers": 0}})
	empty["wars"].declare_war(PLAYER, AI_1)
	_expect(errors, [empty["dip"].ai_stance(AI_1, PLAYER)["strength"], empty["dip"].ai_stance(AI_1, PLAYER)["reluctance"]], [500, 0], "sin soldados la fuerza es 500 (empate)")
	return errors


## IA 1 con 24 soldados contra los 6 del jugador, que tiene 5 celdas ocupadas por la IA 1 en (24, 10..14).
func _winning_world() -> Dictionary:
	var world := _make_world(WINNING_AI_POP)
	world["wars"].declare_war(PLAYER, AI_1)
	for y in range(10, 15):
		world["occ"].occupy(AI_1, Vector2i(24, y))
	return world


func _test_ai_offers() -> Array:
	var errors: Array = []
	# --- IA débil: propone la paz sola ---
	var world := _make_world(WEAK_AI_POP)
	var dip: Diplomacy = world["dip"]
	var wars: WarState = world["wars"]
	var cities: CityManager = world["cities"]
	wars.declare_war(PLAYER, AI_1)
	for y in range(10, 15):
		world["occ"].occupy(PLAYER, Vector2i(25, y))
	_signal_count = 0
	dip.changed.connect(_count_signal)
	_expect(errors, dip.pending_for(PLAYER).size(), 0, "mientras no pasa tiempo no hay propuesta")
	_ticks(world, 1)
	var offers := dip.pending_for(PLAYER)
	_expect(errors, offers.size(), 1, "al primer tick la IA 1 (reluctancia -71) propone la paz")
	var first_id: int = _pending_id(dip, PLAYER)
	if offers.size() == 1:
		_expect(errors, [offers[0]["from"], offers[0]["kind"], offers[0]["payer"], offers[0]["amount"], offers[0]["counter"]], [AI_1, Diplomacy.KIND_WHITE, Diplomacy.NO_PAYER, 0, false], "paz blanca sin pago: las conquistas no le convienen (cedería 5 celdas)")
	_expect(errors, _signal_count >= 1, true, "se avisa de la propuesta")
	var created_at := cities.tick_count()
	# No se repite en cada actualización.
	_ticks(world, 20)
	_expect(errors, [dip.pending_for(PLAYER).size(), _pending_id(dip, PLAYER)], [1, first_id], "20 ticks después sigue siendo la misma, no se acumulan ofertas")
	# Rechazarla bloquea nuevas ofertas durante el intervalo.
	_expect(errors, dip.reject(first_id, PLAYER)["ok"], true, "el jugador la rechaza")
	var rejected_at := cities.tick_count()
	_ticks(world, DiplomacyBalance.AI_OFFER_INTERVAL_TICKS - 1)
	_expect(errors, dip.pending_for(PLAYER).size(), 0, "durante el intervalo la IA no insiste")
	_ticks(world, 1)
	var second_offers := dip.pending_for(PLAYER)
	_expect(errors, [second_offers.size(), _pending_id(dip, PLAYER) != first_id, cities.tick_count() - rejected_at], [1, true, DiplomacyBalance.AI_OFFER_INTERVAL_TICKS], "pasado el intervalo vuelve a proponer")
	# Una propuesta sin respuesta caduca y se sustituye por una nueva (nunca hay dos a la vez).
	var second_id: int = _pending_id(dip, PLAYER)
	var second_at := cities.tick_count()
	_ticks(world, DiplomacyBalance.PROPOSAL_TIMEOUT_TICKS - 1)
	_expect(errors, [dip.pending_for(PLAYER).size(), _pending_id(dip, PLAYER)], [1, second_id], "antes del plazo sigue pendiente")
	_ticks(world, 1)
	_expect(errors, [dip.pending_for(PLAYER).size(), _pending_id(dip, PLAYER) != second_id, cities.tick_count() - second_at], [1, true, DiplomacyBalance.PROPOSAL_TIMEOUT_TICKS], "al caducar se descarta y, pasado el intervalo, la IA vuelve a ofrecer")
	# Aceptarla firma la paz.
	var third_id: int = _pending_id(dip, PLAYER)
	var signed := dip.accept(third_id, PLAYER)
	_expect(errors, [signed["ok"], wars.at_war(PLAYER, AI_1), wars.has_truce(PLAYER, AI_1), world["occ"].count(), dip.pending_for(PLAYER).size()], [true, false, true, 0, 0], "aceptar la propuesta de la IA firma la paz blanca y empieza la tregua")
	_ticks(world, 200)
	_expect(errors, dip.pending_for(PLAYER).size(), 0, "sin guerra la IA no propone nada")
	# --- Margen: una guerra igualada solo genera propuesta cuando el cansancio supera el margen ---
	var even := _make_world(EVEN_POP)
	even["wars"].declare_war(PLAYER, AI_1)
	_ticks(even, 14)
	_expect(errors, [even["dip"].ai_stance(AI_1, PLAYER)["reluctance"], even["dip"].pending_for(PLAYER).size()], [-14, 0], "con reluctancia -14 todavía no ofrece")
	_ticks(even, 1)
	_expect(errors, [even["dip"].ai_stance(AI_1, PLAYER)["reluctance"], even["dip"].pending_for(PLAYER).size()], [-15, 1], "con -15 sí")
	# --- Una IA que va ganando no ofrece la paz ---
	var strong := _winning_world()
	_ticks(strong, 60)
	_expect(errors, strong["dip"].pending_for(PLAYER).size(), 0, "la IA 1 que va ganando no propone la paz")
	# --- Guerras entre dos IA no generan propuestas ---
	var tri := _make_world(TRI_POP, _make_tri_grid())
	tri["wars"].declare_war(AI_1, AI_2)
	_ticks(tri, 100)
	_expect(errors, [tri["dip"].pending_for(PLAYER).size(), tri["dip"].pending_for(AI_1).size(), tri["dip"].pending_for(AI_2).size(), tri["wars"].at_war(AI_1, AI_2)], [0, 0, 0, true], "no hay IA estratégica: la guerra entre IA se queda como está")
	# --- En pausa no hay propuestas ni caducidades ---
	var paused := _make_world(WEAK_AI_POP)
	paused["wars"].declare_war(PLAYER, AI_1)
	paused["cities"].set_paused(true)
	_ticks(paused, 100)
	_expect(errors, paused["dip"].pending_for(PLAYER).size(), 0, "en pausa la IA no propone")
	paused["cities"].set_paused(false)
	_ticks(paused, 1)
	_expect(errors, paused["dip"].pending_for(PLAYER).size(), 1, "al reanudar propone al primer tick")
	paused["cities"].set_paused(true)
	_ticks(paused, 200)
	_expect(errors, paused["dip"].pending_for(PLAYER).size(), 1, "y en pausa la propuesta no caduca")
	return errors


func _test_diplomacy_panel() -> Array:
	var errors: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	var scene: PackedScene = load(SCREEN_PATH)
	_expect(errors, scene != null, true, "la escena %s carga" % SCREEN_PATH)
	if scene == null:
		return errors
	var screen: Screen = scene.instantiate()
	tree.root.add_child(screen)
	screen.ai.enabled = false  # sin decisiones de la IA estratégica (hito 11): escenario controlado
	var panel: DiplomacyPanel = screen.get_node("%Diplomacia")
	var dip: Diplomacy = screen.diplomacy
	var wars: WarState = screen.wars
	var economy: Economy = screen.economy
	var occ: Occupation = screen.occupation
	_expect(errors, panel != null and dip != null, true, "la pantalla crea la diplomacia y su panel")
	if panel == null or dip == null:
		screen.free()
		return errors
	_expect(errors, panel.mouse_filter, Control.MOUSE_FILTER_STOP, "el panel captura el clic")
	var names := ["EstadoDiplomacia", "SelectorEnemigo", "PropuestaEntrante", "BotonAceptarPropuesta", "BotonRechazarPropuesta", "FormularioPaz", "TipoPaz",
			"PagoQuien", "CantidadPago", "SliderPago", "ResumenTratado", "BotonProponer", "AvisoPausaDiplomacia", "MensajeDiplomacia"]
	for node_name: String in names:
		if panel.find_child(node_name, true, false) == null:
			errors.append("falta el control %s" % node_name)
	if not errors.is_empty():
		screen.free()
		return errors
	var status: Label = panel.find_child("EstadoDiplomacia", true, false)
	var incoming: Label = panel.find_child("PropuestaEntrante", true, false)
	var accept: Button = panel.find_child("BotonAceptarPropuesta", true, false)
	var decline: Button = panel.find_child("BotonRechazarPropuesta", true, false)
	var form: Control = panel.find_child("FormularioPaz", true, false)
	var propose: Button = panel.find_child("BotonProponer", true, false)
	var payment_label: Label = panel.find_child("CantidadPago", true, false)
	var summary: Label = panel.find_child("ResumenTratado", true, false)
	var pause_notice: Label = panel.find_child("AvisoPausaDiplomacia", true, false)
	var message: Label = panel.find_child("MensajeDiplomacia", true, false)
	var slider: HSlider = panel.find_child("SliderPago", true, false)
	var ai_name: String = screen.grid.get_nation(AI_1)["name"]
	_expect(errors, panel.visible, false, "sin guerra, propuestas ni treguas el panel no aparece")
	# Textos puros.
	_expect(errors, DiplomacyPanel.status_text([]), "Sin conflictos.", "sin líneas")
	_expect(errors, DiplomacyPanel.war_text("Reino de Cobre", 35, 3, 1, 4, 7), "En guerra con Reino de Cobre (35 s)\nOcupas 3 · Te ocupan 1\nBajas: tuyas 4 · suyas 7", "línea de guerra")
	_expect(errors, DiplomacyPanel.truce_text("Reino de Cobre", 42), "Tregua con Reino de Cobre: 42 s", "línea de tregua")
	_expect(errors, [DiplomacyPanel.payment_text(DiplomacyPanel.PAYER_NONE, 0, 50), DiplomacyPanel.payment_text(DiplomacyPanel.PAYER_ME, 12, 40), DiplomacyPanel.payment_text(DiplomacyPanel.PAYER_THEM, 12, 30)],
			["Sin pago", "Pagas 12 (tienes 40)", "Pagan ellos: 12 (tienen 30)"], "textos del pago")
	_expect(errors, [DiplomacyPanel.treaty_summary_text(Diplomacy.KIND_CONQUESTS, 3, 1), DiplomacyPanel.treaty_summary_text(Diplomacy.KIND_WHITE, 3, 1)],
			["Cada parte se queda lo que ocupa: ganas hasta 3 celdas y pierdes hasta 1.", "Nadie cambia de dueño. Se liberan 4 celdas ocupadas."], "resumen del tratado")
	# Guerra: aparece el panel con su estado y el formulario.
	wars.declare_war(PLAYER, AI_1)
	_expect(errors, [panel.visible, form.visible, incoming.visible, accept.visible, panel.chosen_enemy()], [true, true, false, false, AI_1], "al empezar la guerra aparece el panel con el formulario")
	_expect(errors, status.text, DiplomacyPanel.war_text(ai_name, 0, 0, 0, 0, 0), "estado de la guerra")
	_expect(errors, [panel.chosen_kind(), panel.chosen_payer_mode(), panel.payment(), propose.disabled, payment_label.text], [Diplomacy.KIND_CONQUESTS, DiplomacyPanel.PAYER_NONE, 0, false, "Sin pago"], "por defecto: paz con conquistas, sin pago")
	# Pago: el deslizador nunca ofrece más del saldo del pagador.
	panel.set_payer_mode(DiplomacyPanel.PAYER_ME)
	_expect(errors, [slider.max_value, slider.editable], [float(economy.get_money(PLAYER)), true], "el máximo es el dinero del pagador")
	panel.set_payment(1000)
	_expect(errors, [panel.payment(), payment_label.text], [economy.get_money(PLAYER), DiplomacyPanel.payment_text(DiplomacyPanel.PAYER_ME, economy.get_money(PLAYER), economy.get_money(PLAYER))], "no se ofrece más de lo que se tiene")
	panel.set_payer_mode(DiplomacyPanel.PAYER_NONE)
	_expect(errors, [panel.payment(), slider.editable], [0, false], "sin pagador no hay cantidad")
	# Proponer paz blanca: la IA 1 (igualada, sin tiempo transcurrido) acepta.
	panel.set_kind(Diplomacy.KIND_WHITE)
	_expect(errors, summary.text, DiplomacyPanel.treaty_summary_text(Diplomacy.KIND_WHITE, 0, 0), "el resumen sigue al tipo")
	var money := [economy.get_money(PLAYER), economy.get_money(AI_1)]
	propose.pressed.emit()
	_expect(errors, message.text.begins_with("%s acepta." % ai_name), true, "el panel muestra la respuesta de la IA")
	_expect(errors, [wars.at_war(PLAYER, AI_1), wars.has_truce(PLAYER, AI_1), [economy.get_money(PLAYER), economy.get_money(AI_1)]], [false, true, money], "la guerra termina, empieza la tregua y no hubo pago")
	_expect(errors, [panel.visible, form.visible, status.text], [true, false, DiplomacyPanel.truce_text(ai_name, DiplomacyBalance.TRUCE_TICKS)], "queda visible la tregua con su tiempo y sin formulario")
	screen.cities.advance(10.0)
	_expect(errors, status.text, DiplomacyPanel.truce_text(ai_name, DiplomacyBalance.TRUCE_TICKS - 10), "la tregua cuenta atrás en pantalla")
	screen.cities.advance(float(DiplomacyBalance.TRUCE_TICKS))
	_expect(errors, [panel.visible, status.text], [false, "Sin conflictos."], "al acabar la tregua el panel vuelve a ocultarse")
	# Propuesta entrante de la IA: una guerra larga cansa a la IA 1.
	wars.declare_war(AI_1, PLAYER)
	_expect(errors, [panel.visible, form.visible], [true, true], "nueva guerra")
	screen.cities.advance(30.0)
	_expect(errors, dip.pending_for(PLAYER).size(), 1, "cansada, la IA 1 propone la paz")
	if dip.pending_for(PLAYER).is_empty():
		screen.free()
		return errors
	var proposal := dip.pending_for(PLAYER)[0]
	_expect(errors, [incoming.visible, incoming.text, accept.visible, decline.visible, form.visible], [true, dip.proposal_text(proposal), true, true, false], "el panel muestra la propuesta con Aceptar/Rechazar y oculta el formulario")
	decline.pressed.emit()
	_expect(errors, [dip.pending_for(PLAYER).size(), incoming.visible, form.visible, wars.at_war(PLAYER, AI_1)], [0, false, true, true], "rechazar la quita y la guerra continúa")
	screen.cities.advance(float(DiplomacyBalance.AI_OFFER_INTERVAL_TICKS))
	_expect(errors, [dip.pending_for(PLAYER).size(), incoming.visible], [1, true], "la IA vuelve a proponer pasado el intervalo")
	# En pausa no se acepta ni se propone, y el panel lo dice.
	screen.cities.set_paused(true)
	_expect(errors, [accept.disabled, pause_notice.visible], [true, true], "en pausa «Aceptar» se desactiva y el panel avisa")
	accept.pressed.emit()
	_expect(errors, [wars.at_war(PLAYER, AI_1), message.text], [true, Diplomacy.error_message(Diplomacy.ERR_PAUSED)], "forzar el botón en pausa no firma nada")
	screen.cities.set_paused(false)
	accept.pressed.emit()
	_expect(errors, [wars.at_war(PLAYER, AI_1), wars.has_truce(PLAYER, AI_1), dip.history().size()], [false, true, 2], "reanudada la partida, aceptar firma la paz")
	screen.free()
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
	screen.ai.enabled = false  # sin decisiones de la IA estratégica (hito 11): escenario controlado
	var cities: CityManager = screen.cities
	var pause_button: Button = screen.get_node("%BotonPausa")
	var indicator: Label = screen.get_node("%IndicadorPausa")
	_expect(errors, [pause_button != null, indicator != null], [true, true], "la pantalla tiene botón de pausa e indicador")
	if pause_button == null or indicator == null:
		screen.free()
		return errors
	_expect(errors, [pause_button.text, indicator.text, cities.is_paused()], ["Pausa (Espacio)", "", false], "empieza en marcha")
	var before := [cities.tick_count(), screen.economy.get_money(TerritoryGrid.OWNER_PLAYER)]
	pause_button.pressed.emit()
	_expect(errors, [cities.is_paused(), pause_button.text, indicator.text], [true, "Reanudar (Espacio)", "EN PAUSA"], "el botón pausa la simulación y lo indica")
	cities.advance(30.0)
	_expect(errors, [cities.tick_count(), screen.economy.get_money(TerritoryGrid.OWNER_PLAYER)], before, "en pausa no pasa el tiempo ni cambia la economía")
	# La interfaz sigue respondiendo: se puede seleccionar una celda y consultar.
	var view = screen.get_node("%Mapa")
	var info = screen.get_node("%Info")
	var cell: Vector2i = TerritoryGrid.START_SITES[TerritoryGrid.OWNER_PLAYER]["seed"]
	view.pointer_pressed(view.cell_center_global(cell))
	_expect(errors, view.selected_cell, cell, "en pausa se puede seleccionar y consultar el mapa")
	var founded: Dictionary = screen.try_found_at(Vector2i(cell.x + 10, cell.y))
	_expect(errors, [founded["ok"], founded["error"]], [false, CityManager.FOUND_ERR_PAUSED], "no se funda en pausa")
	_expect(errors, info != null, true, "el panel de información existe")
	screen.toggle_pause()
	_expect(errors, [cities.is_paused(), pause_button.text, indicator.text], [false, "Pausa (Espacio)", ""], "reanudar restaura el botón")
	cities.advance(2.0)
	_expect(errors, cities.tick_count(), before[0] + 2, "y el tiempo vuelve a correr")
	# La barra espaciadora también pausa.
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	screen._unhandled_key_input(key)
	_expect(errors, cities.is_paused(), true, "la barra espaciadora pausa")
	screen.set_paused(false)
	_expect(errors, cities.is_paused(), false, "set_paused(false) reanuda")
	screen.free()
	return errors


func _test_determinism() -> Array:
	var errors: Array = []
	var results: Array = []
	for run in 2:
		var world := _make_world(DUEL_POP, null, true)
		var off: Offensives = world["off"]
		var dip: Diplomacy = world["dip"]
		off.launch_attack(PLAYER, BORDER, Military.DIR_EAST, 10)
		_ticks(world, 7)
		off.launch_attack(PLAYER, Vector2i(24, 22), Military.DIR_EAST, 4)
		_ticks(world, 20)
		dip.propose(PLAYER, AI_1, Diplomacy.KIND_CONQUESTS, Diplomacy.NO_PAYER, 0)
		_ticks(world, 11)
		results.append(_snapshot(world))
		results.append(dip.history().size())
	_expect(errors, results[0] == results[2], true, "dos partidas idénticas dan exactamente el mismo estado final")
	_expect(errors, [results[0]["occupied"].size() + results[1] > 0], [true], "y el escenario hizo algo (ocupaciones o un tratado)")
	return errors


func _test_files_present() -> Array:
	var errors: Array = []
	for path: String in ["res://tests/territory_grid_tests.gd", "res://tests/territory_map_view_tests.gd",
			"res://tests/territory_conquest_tests.gd", "res://tests/territory_hud_tests.gd",
			"res://tests/city_economy_tests.gd", "res://tests/population_tests.gd", "res://tests/military_tests.gd", "res://tests/combat_tests.gd",
			"res://tests/run_territory_tests.tscn", "res://tests/run_view_tests.tscn",
			"res://tests/run_conquest_tests.tscn", "res://tests/run_hud_tests.tscn",
			"res://tests/run_city_tests.tscn", "res://tests/run_population_tests.tscn", "res://tests/run_military_tests.tscn",
			"res://tests/run_combat_tests.tscn", "res://tests/test_combat.gd", "res://tests/test_diplomacy.gd", "res://tests/run_diplomacy_tests.tscn",
			"res://scripts/world/diplomacy.gd", "res://scripts/world/war_state.gd", "res://scripts/world/offensives.gd", "res://scripts/world/occupation.gd",
			"res://scripts/data/diplomacy_balance.gd", "res://scripts/ui/diplomacy_panel.gd", "res://scripts/ui/military_panel.gd",
			"res://tests/test_province_data.gd", "res://tests/test_province_selection.gd",
			"res://scripts/data/province_data.gd", "res://scripts/map/province_map.gd", "res://scenes/main.tscn"]:
		_expect(errors, FileAccess.file_exists(path), true, "existe " + path)
	return errors
