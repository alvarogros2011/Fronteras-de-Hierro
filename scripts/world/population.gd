## Población, movilización y mantenimiento (hito 7). Sin nodos ni dibujo.
##
## Modelo (el más simple que conserva los totales): la población es NACIONAL. Por nación solo se
## guardan dos cifras, trabajadores y soldados; la población total y todo lo demás se deriva.
## Las ciudades no guardan población: contribuyen al crecimiento y al tope de su propietario
## según su nivel (el propietario sigue siendo el de la celda central en TerritoryGrid, así que
## una ciudad conquistada pasa a contribuir al nuevo dueño sola). Este sistema nunca escribe en
## la cuadrícula ni en las ciudades: población, economía y mantenimiento no pueden mover fronteras.
##
## Reloj: se engancha a CityManager.ticked, así que avanza en el mismo paso fijo que la
## producción (ya pagada cuando se ejecuta). Orden dentro de un tick, por nación:
##   1. crecimiento de población  2. progreso de la movilización  3. mantenimiento  4. consecuencias
##
## 1. Crecimiento: cada ciudad activa aporta GROWTH_MILLI_PER_LEVEL[nivel] (x2 si es prioritaria).
##    Las milésimas sobrantes se acumulan. Nunca se supera la capacidad (suma de las de sus
##    ciudades activas) y no hay crecimiento mientras algún grupo no se paga. La población nueva
##    se reparte con el porcentaje de soldados vigente; el resto de cada reparto se acumula, de
##    modo que workers + soldados nuevos == personas nacidas siempre.
## 2. Movilización: reserva una cantidad fija de trabajadores y los convierte en soldados a
##    ritmo constante durante MOBILIZATION_TICKS. Solo una a la vez por nación.
## 3. Mantenimiento: cada grupo debe pagar sus recursos (coste por persona en milésimas, con el
##    sobrante acumulado). El grupo de la prioridad de mantenimiento cobra primero; el otro
##    recibe lo que quede. Se descuenta de Economy sin dejar nunca el saldo en negativo. Lo que
##    no se puede pagar queda como DEUDA del grupo (con un límite de DEFICIT_DEBT_LIMIT_TICKS
##    ticks de coste); la deuda se salda antes que el coste nuevo cuando vuelven a sobrar recursos.
## 4. Déficit: un grupo con deuda está en déficit y cuenta ticks seguidos. Tras DEFICIT_GRACE_TICKS
##    pierde DEFICIT_LOSS_PERMILLE (mín. 1 persona) por tick hasta que salda la deuda. Que el
##    déficit se deba a una deuda (y no a un tick suelto sin pagar) evita que un reparto irregular
##    de los recursos entre ticks lo oculte.
##
## Valores de equilibrio: population_balance.gd. Combate, bajas por batalla y reparto de soldados
## entre frentes NO existen todavía.
extends RefCounted

const Economy := preload("res://scripts/world/economy.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Balance := preload("res://scripts/data/population_balance.gd")

## Se emite tras cada tick y tras cada orden aceptada. No lleva datos: se consultan.
signal changed

## Grupos de población (también índices de los arrays internos).
const GROUP_WORKERS := 0
const GROUP_SOLDIERS := 1

## Prioridad de mantenimiento: qué grupo cobra primero cuando faltan recursos.
const MAINT_WORKERS_FIRST := 0
const MAINT_SOLDIERS_FIRST := 1

## Etapa del déficit: 0 = mantenimiento cubierto; 1 = algún grupo sin pagar, crecimiento
## detenido (dentro del plazo de gracia); 2 = pérdidas de población en curso.
const STAGE_OK := 0
const STAGE_SHORTAGE := 1
const STAGE_ATTRITION := 2

const MOB_OK := 0
const MOB_ERR_UNKNOWN_NATION := 1
const MOB_ERR_ACTIVE := 2  # ya hay una movilización en curso
const MOB_ERR_PERCENT := 3  # fuera de 1..MOBILIZATION_MAX_PERCENT
const MOB_ERR_NOTHING := 4  # el porcentaje no llega a una persona

var _cities: CityManager
var _economy: Economy
var _initial: Dictionary
var _nations: Dictionary = {}  # id de nación -> datos (ver _new_nation_data)
var _priority: Dictionary = {}  # id de ciudad -> nación que la marcó como prioritaria


## `nation_ids`: naciones con población. `initial`: {id: {"workers": int, "soldiers": int}};
## por defecto Balance.INITIAL_POPULATION (las naciones que falten empiezan en 0).
func _init(cities: CityManager, economy: Economy, nation_ids: Array, initial: Dictionary = Balance.INITIAL_POPULATION) -> void:
	_cities = cities
	_economy = economy
	_initial = initial
	_cities.ticked.connect(_on_tick)
	reset(nation_ids)


## Vuelve a la población inicial de las naciones dadas, sin prioridades ni movilizaciones.
func reset(nation_ids: Array) -> void:
	_nations = {}
	_priority = {}
	for nation_id: int in nation_ids:
		_nations[nation_id] = _new_nation_data(nation_id)
	changed.emit()


func _new_nation_data(nation_id: int) -> Dictionary:
	var start: Dictionary = _initial.get(nation_id, {})
	return {
		"workers": maxi(0, int(start.get("workers", 0))),
		"soldiers": maxi(0, int(start.get("soldiers", 0))),
		"new_soldier_percent": Balance.INITIAL_NEW_SOLDIER_PERCENT,
		"growth_carry": 0,  # milésimas de persona pendientes (< 1000)
		"split_carry": 0,  # resto del reparto de nuevos soldados (< 100)
		"maintenance_priority": MAINT_WORKERS_FIRST,
		"upkeep_carry": [0, 0],  # milésimas de recurso pendientes por grupo (< 1000)
		"debt": [0, 0],  # recursos enteros que no se pudieron pagar, por grupo
		"short_ticks": [0, 0],  # ticks seguidos con deuda, por grupo
		"mob_active": false,
		"mob_total": 0,  # trabajadores reservados por la orden
		"mob_converted": 0,
		"mob_elapsed": 0,
	}


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func has_nation(nation_id: int) -> bool:
	return _nations.has(nation_id)


## -1 si la nación no existe.
func workers(nation_id: int) -> int:
	return _nations[nation_id]["workers"] if _nations.has(nation_id) else -1


## -1 si la nación no existe.
func soldiers(nation_id: int) -> int:
	return _nations[nation_id]["soldiers"] if _nations.has(nation_id) else -1


## Trabajadores + soldados (-1 si la nación no existe).
func total_population(nation_id: int) -> int:
	return workers(nation_id) + soldiers(nation_id) if _nations.has(nation_id) else -1


## Trabajadores que no están reservados por una movilización en curso (-1 si no existe).
func available_workers(nation_id: int) -> int:
	return workers(nation_id) - pending_mobilization(nation_id) if _nations.has(nation_id) else -1


## Trabajadores reservados que aún no se han convertido en soldados (0 sin movilización).
func pending_mobilization(nation_id: int) -> int:
	if not _nations.has(nation_id) or not _nations[nation_id]["mob_active"]:
		return 0
	return _nations[nation_id]["mob_total"] - _nations[nation_id]["mob_converted"]


## Porcentaje de la población nueva que va a soldados (-1 si la nación no existe).
func new_soldier_percent(nation_id: int) -> int:
	return _nations[nation_id]["new_soldier_percent"] if _nations.has(nation_id) else -1


## Porcentaje de la población nueva que va a trabajadores: siempre 100 - soldados.
func new_worker_percent(nation_id: int) -> int:
	return 100 - new_soldier_percent(nation_id) if _nations.has(nation_id) else -1


func maintenance_priority(nation_id: int) -> int:
	return _nations[nation_id]["maintenance_priority"] if _nations.has(nation_id) else -1


## Población máxima de la nación: suma de las capacidades de sus ciudades activas.
func capacity(nation_id: int) -> int:
	var total := 0
	for city_id: int in _cities.get_city_ids():
		if _cities.get_owner(city_id) == nation_id:
			total += Balance.CAPACITY_PER_LEVEL[_cities.get_city(city_id)["level"]]
	return total


## ¿Es prioritaria la ciudad? Solo cuenta si su propietario actual es quien la marcó: si cambia
## de dueño por una conquista, la prioridad del anterior deja de aplicarse.
func is_city_priority(city_id: int) -> bool:
	return _priority.has(city_id) and _priority[city_id] == _cities.get_owner(city_id)


## Crecimiento que aporta la ciudad por tick, en milésimas de persona (0 si no tiene dueño).
## No tiene en cuenta el tope de capacidad ni el déficit: es la contribución bruta.
@warning_ignore("integer_division")
func city_growth_milli(city_id: int) -> int:
	var owner_id := _cities.get_owner(city_id)
	if not _nations.has(owner_id):
		return 0
	var base: int = Balance.GROWTH_MILLI_PER_LEVEL[_cities.get_city(city_id)["level"]]
	if is_city_priority(city_id):
		return base * Balance.PRIORITY_GROWTH_PERCENT / 100
	return base


## Suma bruta de las contribuciones de las ciudades de la nación (milésimas por tick).
func growth_milli(nation_id: int) -> int:
	var total := 0
	for city_id: int in _cities.get_city_ids():
		if _cities.get_owner(city_id) == nation_id:
			total += city_growth_milli(city_id)
	return total


## Coste de mantenimiento por tick en milésimas de recurso, por grupo:
## {"workers": int, "soldiers": int, "total": int}.
func upkeep_milli(nation_id: int) -> Dictionary:
	if not _nations.has(nation_id):
		return {"workers": 0, "soldiers": 0, "total": 0}
	var worker_cost: int = _nations[nation_id]["workers"] * Balance.WORKER_UPKEEP_MILLI
	var soldier_cost: int = _nations[nation_id]["soldiers"] * Balance.SOLDIER_UPKEEP_MILLI
	return {"workers": worker_cost, "soldiers": soldier_cost, "total": worker_cost + soldier_cost}


## Resumen de la población de la nación (vacío si no existe): total, workers, soldiers,
## workers_free (sin reservar), pending (en movilización), capacity, growth_milli (efectivo en
## el próximo tick: 0 si hay déficit o no queda capacidad), new_soldier_percent y new_worker_percent.
func get_summary(nation_id: int) -> Dictionary:
	if not _nations.has(nation_id):
		return {}
	var data: Dictionary = _nations[nation_id]
	var total_capacity := capacity(nation_id)
	var effective := growth_milli(nation_id)
	if _stage_of(data) != STAGE_OK or total_population(nation_id) >= total_capacity:
		effective = 0
	return {
		"total": total_population(nation_id),
		"workers": data["workers"],
		"soldiers": data["soldiers"],
		"workers_free": available_workers(nation_id),
		"pending": pending_mobilization(nation_id),
		"capacity": total_capacity,
		"growth_milli": effective,
		"new_soldier_percent": data["new_soldier_percent"],
		"new_worker_percent": 100 - data["new_soldier_percent"],
	}


## Estado de la movilización: active, total (reservados), converted, pending, elapsed_ticks,
## duration_ticks y progress_percent (convertidos sobre reservados, 0..100).
@warning_ignore("integer_division")
func get_mobilization(nation_id: int) -> Dictionary:
	if not _nations.has(nation_id):
		return {}
	var data: Dictionary = _nations[nation_id]
	var total: int = data["mob_total"] if data["mob_active"] else 0
	var converted: int = data["mob_converted"] if data["mob_active"] else 0
	return {
		"active": data["mob_active"],
		"total": total,
		"converted": converted,
		"pending": total - converted,
		"elapsed_ticks": data["mob_elapsed"] if data["mob_active"] else 0,
		"duration_ticks": Balance.MOBILIZATION_TICKS,
		"progress_percent": 0 if total == 0 else converted * 100 / total,
	}


## Estado del mantenimiento (vacío si la nación no existe): priority, cost_milli (por tick, por
## grupo: workers, soldiers, total), debt (recursos sin pagar, por grupo: workers, soldiers, total),
## workers_covered / soldiers_covered (el grupo no tiene deuda), worker_short_ticks /
## soldier_short_ticks (ticks seguidos con deuda), stage (STAGE_*) e in_deficit.
func get_maintenance(nation_id: int) -> Dictionary:
	if not _nations.has(nation_id):
		return {}
	var data: Dictionary = _nations[nation_id]
	var stage := _stage_of(data)
	return {
		"priority": data["maintenance_priority"],
		"cost_milli": upkeep_milli(nation_id),
		"debt": {"workers": data["debt"][GROUP_WORKERS], "soldiers": data["debt"][GROUP_SOLDIERS],
				"total": data["debt"][GROUP_WORKERS] + data["debt"][GROUP_SOLDIERS]},
		"workers_covered": data["short_ticks"][GROUP_WORKERS] == 0,
		"soldiers_covered": data["short_ticks"][GROUP_SOLDIERS] == 0,
		"worker_short_ticks": data["short_ticks"][GROUP_WORKERS],
		"soldier_short_ticks": data["short_ticks"][GROUP_SOLDIERS],
		"stage": stage,
		"in_deficit": stage != STAGE_OK,
	}


func _stage_of(data: Dictionary) -> int:
	var worst: int = maxi(data["short_ticks"][GROUP_WORKERS], data["short_ticks"][GROUP_SOLDIERS])
	if worst == 0:
		return STAGE_OK
	return STAGE_ATTRITION if worst > Balance.DEFICIT_GRACE_TICKS else STAGE_SHORTAGE


static func mobilization_error_message(code: int) -> String:
	match code:
		MOB_OK:
			return "Movilización iniciada."
		MOB_ERR_UNKNOWN_NATION:
			return "Nación desconocida."
		MOB_ERR_ACTIVE:
			return "Ya hay una movilización en curso."
		MOB_ERR_PERCENT:
			return "El porcentaje debe estar entre 1 y %d." % Balance.MOBILIZATION_MAX_PERCENT
		MOB_ERR_NOTHING:
			return "No hay trabajadores suficientes para movilizar ese porcentaje."
	return "Error desconocido."


# ---------------------------------------------------------------------------
# Órdenes
# ---------------------------------------------------------------------------

## Fija el porcentaje de la población NUEVA que va a soldados (0..100; el resto va a
## trabajadores, así que suman siempre 100). No toca a nadie que ya exista. Devuelve false, sin
## cambiar nada, si la nación no existe o el valor está fuera de rango.
func set_new_soldier_percent(nation_id: int, percent: int) -> bool:
	if not _nations.has(nation_id) or percent < 0 or percent > 100:
		return false
	if _nations[nation_id]["new_soldier_percent"] != percent:
		_nations[nation_id]["new_soldier_percent"] = percent
		changed.emit()
	return true


## Activa o desactiva la prioridad de crecimiento de una ciudad de la nación. Devuelve false, sin
## cambiar nada, si la nación o la ciudad no existen o la ciudad no es de esa nación. No cambia
## propietarios, dinero ni niveles: solo multiplica el crecimiento de población de esa ciudad.
func set_city_priority(nation_id: int, city_id: int, enabled: bool) -> bool:
	if not _nations.has(nation_id) or not _cities.has_city(city_id) or _cities.get_owner(city_id) != nation_id:
		return false
	var was := _priority.has(city_id) and _priority[city_id] == nation_id
	if enabled:
		_priority[city_id] = nation_id
	else:
		_priority.erase(city_id)
	if was != enabled:
		changed.emit()
	return true


## Elige qué grupo cobra primero el mantenimiento (MAINT_*). false si nación o valor no valen.
func set_maintenance_priority(nation_id: int, priority: int) -> bool:
	if not _nations.has(nation_id) or (priority != MAINT_WORKERS_FIRST and priority != MAINT_SOLDIERS_FIRST):
		return false
	if _nations[nation_id]["maintenance_priority"] != priority:
		_nations[nation_id]["maintenance_priority"] = priority
		changed.emit()
	return true


## Inicia la movilización del `percent` % de los trabajadores actuales (1..MOBILIZATION_MAX_PERCENT,
## redondeado hacia abajo). Reserva ya esa cantidad y la convierte en soldados repartida en
## MOBILIZATION_TICKS; la población total no cambia. Solo se admite una movilización a la vez por
## nación, y no hay movilización si no sale al menos una persona. Devuelve MOB_OK o el motivo
## (MOB_ERR_*) sin cambiar nada.
@warning_ignore("integer_division")
func start_mobilization(nation_id: int, percent: int) -> int:
	if not _nations.has(nation_id):
		return MOB_ERR_UNKNOWN_NATION
	var data: Dictionary = _nations[nation_id]
	if data["mob_active"]:
		return MOB_ERR_ACTIVE
	if percent < 1 or percent > Balance.MOBILIZATION_MAX_PERCENT:
		return MOB_ERR_PERCENT
	var count: int = data["workers"] * percent / 100
	if count < 1:
		return MOB_ERR_NOTHING
	data["mob_active"] = true
	data["mob_total"] = count
	data["mob_converted"] = 0
	data["mob_elapsed"] = 0
	changed.emit()
	return MOB_OK


# ---------------------------------------------------------------------------
# Tiempo
# ---------------------------------------------------------------------------

func _on_tick() -> void:
	for nation_id: int in _nations:
		var data: Dictionary = _nations[nation_id]
		_grow(nation_id, data)
		_progress_mobilization(data)
		_maintain(nation_id, data)
		_apply_deficit(data)
	changed.emit()


@warning_ignore("integer_division")
func _grow(nation_id: int, data: Dictionary) -> void:
	if _stage_of(data) != STAGE_OK:
		return
	var pending: int = data["growth_carry"] + growth_milli(nation_id)
	var room := maxi(0, capacity(nation_id) - data["workers"] - data["soldiers"])
	var born := mini(pending / 1000, room)
	pending -= born * 1000
	data["growth_carry"] = mini(pending, 999)
	if born <= 0:
		return
	var split: int = data["split_carry"] + born * data["new_soldier_percent"]
	var new_soldiers := split / 100
	data["split_carry"] = split % 100
	data["soldiers"] += new_soldiers
	data["workers"] += born - new_soldiers


@warning_ignore("integer_division")
func _progress_mobilization(data: Dictionary) -> void:
	if not data["mob_active"]:
		return
	data["mob_elapsed"] += 1
	var target: int = data["mob_total"] * mini(data["mob_elapsed"], Balance.MOBILIZATION_TICKS) / Balance.MOBILIZATION_TICKS
	var step := clampi(target - data["mob_converted"], 0, data["workers"])
	data["workers"] -= step
	data["soldiers"] += step
	data["mob_converted"] += step
	if data["mob_elapsed"] >= Balance.MOBILIZATION_TICKS or data["mob_converted"] >= data["mob_total"]:
		data["mob_active"] = false
		data["mob_total"] = 0
		data["mob_converted"] = 0
		data["mob_elapsed"] = 0


@warning_ignore("integer_division")
func _maintain(nation_id: int, data: Dictionary) -> void:
	var cost := [data["workers"] * Balance.WORKER_UPKEEP_MILLI, data["soldiers"] * Balance.SOLDIER_UPKEEP_MILLI]
	var order := [GROUP_WORKERS, GROUP_SOLDIERS]
	if data["maintenance_priority"] == MAINT_SOLDIERS_FIRST:
		order = [GROUP_SOLDIERS, GROUP_WORKERS]
	var demand := [0, 0]
	for group: int in order:
		var owed: int = data["upkeep_carry"][group] + cost[group]
		data["upkeep_carry"][group] = owed % 1000
		demand[group] = data["debt"][group] + owed / 1000
	var available := _economy.get_resources(nation_id)
	var spent := 0
	for group: int in order:
		var paid := mini(demand[group], available)
		available -= paid
		spent += paid
		var debt_limit: int = (Balance.DEFICIT_DEBT_LIMIT_TICKS * cost[group] + 999) / 1000
		data["debt"][group] = mini(demand[group] - paid, debt_limit)
	if spent > 0:
		_economy.spend_resources(nation_id, spent)


func _apply_deficit(data: Dictionary) -> void:
	for group in [GROUP_WORKERS, GROUP_SOLDIERS]:
		if data["debt"][group] > 0:
			data["short_ticks"][group] += 1
		else:
			data["short_ticks"][group] = 0
	for group in [GROUP_WORKERS, GROUP_SOLDIERS]:
		if data["short_ticks"][group] > Balance.DEFICIT_GRACE_TICKS:
			_lose_people(data, group)


## Quita a un grupo sin pagar DEFICIT_LOSS_PERMILLE de sus miembros (mín. 1, nunca más de los que
## hay). Si pierde trabajadores, la reserva de una movilización en curso se recorta para no
## reservar más gente de la que queda.
@warning_ignore("integer_division")
func _lose_people(data: Dictionary, group: int) -> void:
	var key := "workers" if group == GROUP_WORKERS else "soldiers"
	var size: int = data[key]
	var lost := clampi(maxi(1, size * Balance.DEFICIT_LOSS_PERMILLE / 1000), 0, size)
	data[key] = size - lost
	if group == GROUP_WORKERS and data["mob_active"]:
		data["mob_total"] = mini(data["mob_total"], data["mob_converted"] + data["workers"])
