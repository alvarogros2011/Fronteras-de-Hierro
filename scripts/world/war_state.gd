## Estado de guerra entre naciones (hitos 9 y 10). Sin nodos ni dibujo.
##
## Registro EXPLÍCITO y consultable de qué naciones están en guerra, independiente de que existan
## sectores, ofensivas u ocupaciones. Una guerra empieza sola cuando una ofensiva ataca el territorio
## oficial de otra nación (provisional, GDD D21). Atacar tierra sin reclamar no declara nada.
##
## Hito 10:
##   - Cada guerra es un REGISTRO PROPIO (id, agresor, tick de inicio, bajas y ocupaciones de cada
##     bando), de modo que acabar una guerra no toca los datos de otra guerra independiente. Las
##     ofensivas anotan aquí sus enfrentamientos (record_clash / record_occupation).
##   - Las guerras terminan solo con end_war, que invoca Diplomacy al firmar un tratado. Detener una
##     ofensiva sigue sin terminar la guerra.
##   - TREGUAS: tras un tratado, las dos naciones no pueden volver a declararse la guerra durante un
##     plazo. Se guardan como tick de fin; start_truce / has_truce / truce_remaining. declare_war se
##     niega mientras haya tregua (la restricción vive en la lógica, no solo en la interfaz).
##
## Tiempo: se mide en ticks del reloj único de la simulación (CityManager.tick_count()), así que la
## pausa detiene a la vez la duración de las guerras y el cómputo de las treguas. Sin reloj
## (WarState.new() sin argumentos, como en las pruebas antiguas) el tiempo es siempre 0.
extends RefCounted

const CityManager := preload("res://scripts/world/city_manager.gd")

## Se emite cuando cambia el registro: guerra nueva, guerra terminada, tregua iniciada o caducada.
signal changed

var _clock: CityManager = null
var _wars: Array = []  # [{"id", "a", "b", "aggressor", "start_tick", "casualties", "occupations"}], en orden de declaración
var _truces: Dictionary = {}  # "a:b" (a < b) -> tick en el que termina la tregua
var _next_id: int = 1


func _init(clock: CityManager = null) -> void:
	_clock = clock


## Tiempo de juego actual en ticks (0 sin reloj).
func now() -> int:
	return _clock.tick_count() if _clock != null else 0


static func _pair_key(first_id: int, second_id: int) -> String:
	return "%d:%d" % [mini(first_id, second_id), maxi(first_id, second_id)]


func _find(first_id: int, second_id: int) -> int:
	var low := mini(first_id, second_id)
	var high := maxi(first_id, second_id)
	for index in _wars.size():
		if _wars[index]["a"] == low and _wars[index]["b"] == high:
			return index
	return -1


# ---------------------------------------------------------------------------
# Guerras
# ---------------------------------------------------------------------------

## Declara la guerra entre dos naciones distintas. Devuelve true si es una guerra NUEVA y false si ya
## existía, los datos no valen (misma nación o id <= 0) o hay una tregua vigente entre ambas.
func declare_war(aggressor_id: int, defender_id: int) -> bool:
	if aggressor_id <= 0 or defender_id <= 0 or aggressor_id == defender_id:
		return false
	if at_war(aggressor_id, defender_id) or has_truce(aggressor_id, defender_id):
		return false
	_wars.append({
		"id": _next_id,
		"a": mini(aggressor_id, defender_id),
		"b": maxi(aggressor_id, defender_id),
		"aggressor": aggressor_id,
		"start_tick": now(),
		"casualties": {aggressor_id: 0, defender_id: 0},
		"occupations": {aggressor_id: 0, defender_id: 0},
	})
	_next_id += 1
	changed.emit()
	return true


func at_war(first_id: int, second_id: int) -> bool:
	return _find(first_id, second_id) >= 0


func war_count() -> int:
	return _wars.size()


## Naciones en guerra con la dada, de menor a mayor id.
func enemies_of(nation_id: int) -> Array:
	var enemies: Array = []
	for war: Dictionary in _wars:
		if war["a"] == nation_id:
			enemies.append(war["b"])
		elif war["b"] == nation_id:
			enemies.append(war["a"])
	enemies.sort()
	return enemies


## Nación que declaró la guerra entre ambas, o 0 si no están en guerra.
func aggressor_of(first_id: int, second_id: int) -> int:
	var index := _find(first_id, second_id)
	return _wars[index]["aggressor"] if index >= 0 else 0


## Copia del registro de la guerra entre ambas ({} si no están en guerra): id, a, b, aggressor,
## start_tick, casualties y occupations (ambos {id de nación: cantidad}), más duration (ticks).
func get_war(first_id: int, second_id: int) -> Dictionary:
	var index := _find(first_id, second_id)
	if index < 0:
		return {}
	var war: Dictionary = _wars[index].duplicate(true)
	war["duration"] = now() - war["start_tick"]
	return war


## Pares de naciones en guerra como [{"a", "b"}], en orden de declaración.
func war_pairs() -> Array:
	var pairs: Array = []
	for war: Dictionary in _wars:
		pairs.append({"a": war["a"], "b": war["b"]})
	return pairs


## Ticks que lleva la guerra entre ambas (0 si no están en guerra).
func war_duration(first_id: int, second_id: int) -> int:
	var index := _find(first_id, second_id)
	return now() - _wars[index]["start_tick"] if index >= 0 else 0


## Bajas acumuladas de `nation_id` en su guerra contra `other_id` (0 si no están en guerra).
func casualties_of(nation_id: int, other_id: int) -> int:
	var index := _find(nation_id, other_id)
	return _wars[index]["casualties"].get(nation_id, 0) if index >= 0 else 0


## Celdas ocupadas en total por `nation_id` durante su guerra contra `other_id` (0 si no hay guerra).
func occupations_by(nation_id: int, other_id: int) -> int:
	var index := _find(nation_id, other_id)
	return _wars[index]["occupations"].get(nation_id, 0) if index >= 0 else 0


## Anota las bajas de un enfrentamiento en el registro de la guerra entre ambas (si existe).
func record_clash(attacker_id: int, defender_id: int, attacker_losses: int, defender_losses: int) -> void:
	var index := _find(attacker_id, defender_id)
	if index < 0:
		return
	var casualties: Dictionary = _wars[index]["casualties"]
	casualties[attacker_id] = casualties.get(attacker_id, 0) + maxi(0, attacker_losses)
	casualties[defender_id] = casualties.get(defender_id, 0) + maxi(0, defender_losses)


## Anota una celda ocupada por `attacker_id` a `defender_id` en su guerra (si existe).
func record_occupation(attacker_id: int, defender_id: int) -> void:
	var index := _find(attacker_id, defender_id)
	if index < 0:
		return
	var occupations: Dictionary = _wars[index]["occupations"]
	occupations[attacker_id] = occupations.get(attacker_id, 0) + 1


## Termina la guerra entre ambas y devuelve su registro final (con duration); {} y sin cambios si no
## están en guerra. No toca otras guerras, ocupaciones ni territorio: eso lo decide el tratado.
func end_war(first_id: int, second_id: int) -> Dictionary:
	var index := _find(first_id, second_id)
	if index < 0:
		return {}
	var war: Dictionary = _wars[index].duplicate(true)
	war["duration"] = now() - war["start_tick"]
	_wars.remove_at(index)
	changed.emit()
	return war


# ---------------------------------------------------------------------------
# Treguas
# ---------------------------------------------------------------------------

## Inicia (o renueva) la tregua entre dos naciones distintas durante `ticks` ticks. Devuelve false, sin
## cambiar nada, si los datos no valen o ticks <= 0.
func start_truce(first_id: int, second_id: int, ticks: int) -> bool:
	if first_id <= 0 or second_id <= 0 or first_id == second_id or ticks <= 0:
		return false
	_truces[_pair_key(first_id, second_id)] = now() + ticks
	changed.emit()
	return true


func has_truce(first_id: int, second_id: int) -> bool:
	return truce_remaining(first_id, second_id) > 0


## Ticks que le quedan a la tregua entre ambas (0 si no hay).
func truce_remaining(first_id: int, second_id: int) -> int:
	var key := _pair_key(first_id, second_id)
	if not _truces.has(key):
		return 0
	return maxi(0, _truces[key] - now())


## Treguas vigentes de la nación como [{"other": id, "remaining": ticks}], por id de la otra nación.
func truces_of(nation_id: int) -> Array:
	var result: Array = []
	for key: String in _truces:
		var parts := key.split(":")
		var low := int(parts[0])
		var high := int(parts[1])
		if low != nation_id and high != nation_id:
			continue
		var remaining := maxi(0, _truces[key] - now())
		if remaining > 0:
			result.append({"other": high if low == nation_id else low, "remaining": remaining})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left["other"] < right["other"])
	return result


## Borra las treguas ya terminadas y devuelve cuántas (emite changed si hubo alguna).
func expire_truces() -> int:
	var expired: Array = []
	for key: String in _truces:
		if _truces[key] - now() <= 0:
			expired.append(key)
	for key: String in expired:
		_truces.erase(key)
	if not expired.is_empty():
		changed.emit()
	return expired.size()
