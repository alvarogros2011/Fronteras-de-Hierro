## Diplomacia (hito 10): propuestas de paz, pagos, tratados, respuesta de la IA y treguas. Sin nodos ni dibujo.
##
## Primera versión jugable: solo existe la paz entre dos naciones EN GUERRA. No hay alianzas, relaciones
## ni diplomacia avanzada. Dos tipos de tratado:
##   - PAZ CON CONQUISTAS (KIND_CONQUESTS): cada parte conserva lo que ocupa. Las celdas ocupadas pasan a
##     ser propiedad del ocupante con operaciones explícitas TerritoryGrid.conquer_cells (una por zona
##     contigua); las ocupaciones restantes se liberan. Una zona ocupada que ya no toca el territorio de su
##     ocupante (no pasaría la validación de conquer_cells) NO se concede: su ocupación se libera y la celda
##     sigue siendo de su dueño. Nunca se concede territorio que no esté bajo ocupación válida.
##   - PAZ BLANCA (KIND_WHITE): no cambia ninguna propiedad. Libera las ocupaciones entre ESAS dos naciones
##     (cada nación recupera el control de sus celdas); no toca las ocupaciones de otras guerras. Una paz
##     blanca no revierte la tierra sin reclamar que alguien conquistó antes: nunca fue del enemigo.
## Ambos pueden llevar un PAGO de dinero (el mismo recurso de Economy, sin recursos nuevos): quién paga y
## cuánto. Los saldos no se tocan al enviar una oferta, solo al aplicar el tratado, y nunca quedan negativos.
##
## Aplicar un tratado (_apply) es ATÓMICO: primero se valida todo sin cambiar nada (guerra vigente, pago
## posible, no en pausa) y se ensaya la transferencia de territorio sobre una copia de la cuadrícula con
## la misma validación real (conquer_cells). Solo si todo es posible se aplica, y en este orden: detener las
## ofensivas entre ambas naciones, pago, transferencias de territorio, liberar ocupaciones restantes, fin de
## la guerra y comienzo de la TREGUA. Si algo fallara a mitad (no debería: ya se ensayó), se deshacen el
## territorio, las ocupaciones y el pago. Con la partida en pausa no se negocia (cambiaría saldos y
## territorio al instante).
##
## TREGUA: tras cualquier tratado empieza una tregua de Balance.TRUCE_TICKS ticks (registro en WarState).
## Durante ella no pueden declararse la guerra ni atacarse (lo impone Offensives/WarState, no la interfaz).
##
## IA (criterio simple y determinista, ver ai_stance y evaluate_terms): la nación IA calcula una
## «reluctancia» = esperanza de ganar - cansancio.
##   esperanza  = (fuerza - 500) * STRENGTH_WEIGHT / 100 + (celdas que ocupa - celdas que le ocupan) * CELL_VALUE
##   fuerza     = soldados propios * 1000 / (propios + rivales)     (500 si ninguno tiene)
##   cansancio  = ticks de guerra * WEARINESS_PER_TICK + bajas propias * CASUALTY_WEIGHT
## Valora un tratado en puntos de dinero: utilidad = (celdas que gana - celdas que pierde) * CELL_VALUE
## (solo en la paz con conquistas) + dinero que recibe - dinero que paga. ACEPTA si utilidad >= reluctancia.
## Si no, y le faltan como mucho COUNTER_MAX_SHORTFALL puntos, CONTRAOFERTA los mismos términos con el pago
## mínimo que sí aceptaría (o una paz blanca si ese pago no es posible); si no, RECHAZA. Una IA que va
## ganando (reluctancia alta) exige dinero o rechaza; una que va perdiendo o está cansada acepta paz blanca
## e incluso paga. Una IA también propone la paz sola (hacia el jugador), como mucho cada
## AI_OFFER_INTERVAL_TICKS, cuando su reluctancia baja de -PEACE_SEEK_MARGIN; la propuesta caduca a los
## PROPOSAL_TIMEOUT_TICKS. Las guerras entre dos IA no generan propuestas (no hay IA estratégica aún).
extends RefCounted

const TerritoryGrid := preload("res://scripts/world/territory_grid.gd")
const Economy := preload("res://scripts/world/economy.gd")
const CityManager := preload("res://scripts/world/city_manager.gd")
const Population := preload("res://scripts/world/population.gd")
const Occupation := preload("res://scripts/world/occupation.gd")
const WarState := preload("res://scripts/world/war_state.gd")
const Offensives := preload("res://scripts/world/offensives.gd")
const Balance := preload("res://scripts/data/diplomacy_balance.gd")

## Se emite cuando cambian las propuestas pendientes, las treguas o se firma un tratado. No lleva datos.
signal changed
## Se emite con las celdas (Vector2i) cuyo PROPIETARIO cambió por un tratado; la vista debe repintarlas.
signal territory_changed(cells: Array)
## Se emite al firmarse un tratado, con su resumen (ver _apply).
signal treaty_signed(info: Dictionary)

const KIND_CONQUESTS := 0
const KIND_WHITE := 1
const KIND_NAMES: Array[String] = ["Paz con conquistas", "Paz blanca"]

const NO_PAYER := 0

const RESPONSE_NONE := -1  # la orden se rechazó antes de llegar a nadie (ver error)
const RESPONSE_ACCEPTED := 0
const RESPONSE_REJECTED := 1
const RESPONSE_COUNTER := 2
const RESPONSE_PENDING := 3  # el destinatario es humano: espera su respuesta

const ERR_OK := 0
const ERR_UNKNOWN_NATION := 1
const ERR_NOT_AT_WAR := 2
const ERR_BAD_KIND := 3
const ERR_BAD_PAYMENT := 4  # el pagador no es una de las partes, o la cantidad es negativa
const ERR_NO_FUNDS := 5  # el pagador no tiene tanto dinero
const ERR_PENDING_EXISTS := 6  # ya hay una propuesta pendiente entre ambas naciones
const ERR_PAUSED := 7
const ERR_UNKNOWN_PROPOSAL := 8
const ERR_NOT_RECIPIENT := 9  # solo el destinatario puede aceptar o rechazar
const ERR_TERRITORY := 10  # el traspaso de territorio no es posible (inalcanzable tras ensayarlo)

var _grid: TerritoryGrid
var _economy: Economy
var _cities: CityManager
var _population: Population
var _occupation: Occupation
var _wars: WarState
var _offensives: Offensives
var _proposals: Dictionary = {}  # id -> {"id", "from", "to", "kind", "payer", "amount", "tick", "counter"}
var _next_id: int = 1
var _next_offer: Dictionary = {}  # pareja -> tick a partir del cual la IA puede volver a proponer
var _history: Array = []  # resúmenes de los tratados firmados, en orden


func _init(grid: TerritoryGrid, economy: Economy, cities: CityManager, population: Population,
		occupation: Occupation, wars: WarState, offensives: Offensives) -> void:
	_grid = grid
	_economy = economy
	_cities = cities
	_population = population
	_occupation = occupation
	_wars = wars
	_offensives = offensives
	_cities.ticked.connect(_on_tick)


static func _pair(first_id: int, second_id: int) -> String:
	return "%d:%d" % [mini(first_id, second_id), maxi(first_id, second_id)]


func _is_ai(nation_id: int) -> bool:
	return _grid.get_nation(nation_id).get("controller", "") == "ai"


func _name(nation_id: int) -> String:
	return _grid.get_nation(nation_id).get("name", "?")


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

## ¿Hay una propuesta pendiente entre las dos naciones (en cualquier sentido)?
func has_pending(first_id: int, second_id: int) -> bool:
	return not pending_between(first_id, second_id).is_empty()


## Copia de la propuesta pendiente entre ambas naciones ({} si no hay).
func pending_between(first_id: int, second_id: int) -> Dictionary:
	var key := _pair(first_id, second_id)
	for proposal_id: int in _proposals:
		var proposal: Dictionary = _proposals[proposal_id]
		if _pair(proposal["from"], proposal["to"]) == key:
			return proposal.duplicate()
	return {}


## Copias de las propuestas pendientes dirigidas a la nación, por id.
func pending_for(nation_id: int) -> Array:
	var result: Array = []
	for proposal_id: int in _proposals:
		if _proposals[proposal_id]["to"] == nation_id:
			result.append(_proposals[proposal_id].duplicate())
	return result


func get_proposal(proposal_id: int) -> Dictionary:
	return _proposals[proposal_id].duplicate() if _proposals.has(proposal_id) else {}


## Resúmenes de los tratados firmados (copia), del más antiguo al más reciente.
func history() -> Array:
	return _history.duplicate(true)


## Segundos de juego que quedan de tregua entre ambas (0 si no hay).
func truce_remaining(first_id: int, second_id: int) -> int:
	return _wars.truce_remaining(first_id, second_id)


# ---------------------------------------------------------------------------
# Validación y ensayo
# ---------------------------------------------------------------------------

## Comprueba, sin cambiar nada, si un tratado entre `first_id` y `second_id` con esos términos podría
## aplicarse ahora. Devuelve ERR_OK o el primer motivo (ERR_*): naciones, pausa, guerra, tipo, pago.
## `payer` es una de las dos naciones o NO_PAYER; con `amount` 0 el pagador no importa.
func validate_terms(first_id: int, second_id: int, kind: int, payer: int, amount: int) -> int:
	if first_id == second_id or not _grid.has_nation(first_id) or not _grid.has_nation(second_id):
		return ERR_UNKNOWN_NATION
	if _cities.is_paused():
		return ERR_PAUSED
	if not _wars.at_war(first_id, second_id):
		return ERR_NOT_AT_WAR
	if kind != KIND_CONQUESTS and kind != KIND_WHITE:
		return ERR_BAD_KIND
	if amount < 0:
		return ERR_BAD_PAYMENT
	if amount > 0:
		if payer != first_id and payer != second_id:
			return ERR_BAD_PAYMENT
		if not _economy.can_afford(payer, amount):
			return ERR_NO_FUNDS
	return ERR_OK


## Ensaya el traspaso de territorio del tratado SIN cambiar nada. Devuelve: ok, steps (las conquistas que
## se harían, en orden: [{"nation", "cells"}]), gains ({nación: celdas que ganaría}), dropped (celdas
## ocupadas que no se conceden —o, en la paz blanca, que simplemente se liberan—) y released (todas las
## ocupaciones entre ambas). El ensayo ejecuta las conquistas sobre una COPIA de la cuadrícula con la
## validación real de conquer_cells; una zona sin contacto con el territorio de su ocupante no se concede.
func plan_treaty(first_id: int, second_id: int, kind: int) -> Dictionary:
	var held_first := _occupation.get_cells_between(first_id, second_id)
	var held_second := _occupation.get_cells_between(second_id, first_id)
	var plan := {
		"ok": true, "steps": [], "gains": {first_id: 0, second_id: 0},
		"dropped": 0, "released": held_first.size() + held_second.size(),
	}
	if kind != KIND_CONQUESTS or plan["released"] == 0:
		plan["dropped"] = plan["released"]
		return plan
	var scratch := TerritoryGrid.new()
	if not scratch.load_from_data(_grid.copy_terrain_data(), _grid.copy_owner_data()):
		plan["ok"] = false
		return plan
	var dropped := 0
	var low := mini(first_id, second_id)
	var high := maxi(first_id, second_id)
	for nation_id: int in [low, high]:
		var held: Array = held_first if nation_id == first_id else held_second
		var zones := _zones(held)
		var progress := true
		while progress and not zones.is_empty():
			progress = false
			var left: Array = []
			for zone: Array in zones:
				if scratch.conquer_cells(nation_id, zone)["ok"]:
					plan["steps"].append({"nation": nation_id, "cells": zone})
					plan["gains"][nation_id] += zone.size()
					progress = true
				else:
					left.append(zone)
			zones = left
		for zone: Array in zones:
			dropped += zone.size()
	plan["dropped"] = dropped
	return plan


## Agrupa las celdas en zonas contiguas (vecinos ortogonales), en orden de aparición.
func _zones(cells: Array) -> Array:
	var pending := {}
	for cell: Vector2i in cells:
		pending[cell] = true
	var zones: Array = []
	for start: Vector2i in cells:
		if not pending.has(start):
			continue
		pending.erase(start)
		var zone: Array = [start]
		var index := 0
		while index < zone.size():
			var current: Vector2i = zone[index]
			index += 1
			for step: Vector2i in TerritoryGrid.ORTHOGONAL_STEPS:
				var neighbor := current + step
				if pending.has(neighbor):
					pending.erase(neighbor)
					zone.append(neighbor)
		zones.append(zone)
	return zones


# ---------------------------------------------------------------------------
# Decisión de la IA
# ---------------------------------------------------------------------------

## Cómo ve la guerra la nación `ai_id` contra `other_id`: soldados propios y rivales, fuerza (0..1000),
## celdas que ocupa y que le ocupan, duración, bajas propias, esperanza, cansancio y reluctancia (>0:
## quiere seguir; <0: está dispuesta a ceder). Solo lee el estado.
@warning_ignore("integer_division")
func ai_stance(ai_id: int, other_id: int) -> Dictionary:
	var own := maxi(0, _population.soldiers(ai_id))
	var rival := maxi(0, _population.soldiers(other_id))
	var strength := 500 if own + rival == 0 else own * 1000 / (own + rival)
	var held_own := _occupation.count_between(ai_id, other_id)
	var held_other := _occupation.count_between(other_id, ai_id)
	var hope: int = (strength - 500) * Balance.STRENGTH_WEIGHT / 100 + (held_own - held_other) * Balance.CELL_VALUE
	var duration := _wars.war_duration(ai_id, other_id)
	var casualties := _wars.casualties_of(ai_id, other_id)
	var weariness: int = duration * Balance.WEARINESS_PER_TICK + casualties * Balance.CASUALTY_WEIGHT
	return {
		"own_soldiers": own, "rival_soldiers": rival, "strength": strength, "held_own": held_own,
		"held_other": held_other, "duration": duration, "casualties": casualties,
		"hope": hope, "weariness": weariness, "reluctance": hope - weariness,
	}


## Dinero que recibe (positivo) o paga (negativo) la nación en unos términos.
static func money_delta(nation_id: int, payer: int, amount: int) -> int:
	if amount <= 0 or payer == NO_PAYER:
		return 0
	return -amount if payer == nation_id else amount


## Respuesta de la IA `ai_id` a unos términos propuestos por `other_id`, sin cambiar nada. Devuelve:
## response (RESPONSE_ACCEPTED / REJECTED / COUNTER), utility, reluctance, shortfall, plan y, si
## contraoferta, counter ({"kind", "payer", "amount"}).
func evaluate_terms(ai_id: int, other_id: int, kind: int, payer: int, amount: int) -> Dictionary:
	var stance := ai_stance(ai_id, other_id)
	var reluctance: int = stance["reluctance"]
	var plan := plan_treaty(ai_id, other_id, kind)
	var territory := _territory_value(plan, ai_id, other_id)
	var utility := territory + money_delta(ai_id, payer, amount)
	var result := {"response": RESPONSE_REJECTED, "utility": utility, "reluctance": reluctance,
			"shortfall": maxi(0, reluctance - utility), "plan": plan, "counter": {}, "stance": stance}
	if utility >= reluctance:
		result["response"] = RESPONSE_ACCEPTED
		return result
	if result["shortfall"] > Balance.COUNTER_MAX_SHORTFALL:
		return result
	var counter := _counter_terms(ai_id, other_id, kind, territory, reluctance)
	if counter.is_empty() and kind == KIND_CONQUESTS:
		counter = _counter_terms(ai_id, other_id, KIND_WHITE, 0, reluctance)
	if not counter.is_empty():
		result["response"] = RESPONSE_COUNTER
		result["counter"] = counter
	return result


## Puntos de territorio del tratado para `ai_id`: (celdas que gana - celdas que pierde) * CELL_VALUE.
func _territory_value(plan: Dictionary, ai_id: int, other_id: int) -> int:
	return (plan["gains"][ai_id] - plan["gains"][other_id]) * Balance.CELL_VALUE


## Pago mínimo con el que la IA aceptaría ese tipo de tratado, o {} si el pagador no puede permitírselo.
func _counter_terms(ai_id: int, other_id: int, kind: int, territory: int, reluctance: int) -> Dictionary:
	var needed := reluctance - territory  # dinero que debe recibir la IA (negativo: puede pagar)
	var payer := other_id if needed >= 0 else ai_id
	var amount := absi(needed)
	if amount == 0:
		return {"kind": kind, "payer": NO_PAYER, "amount": 0}
	if not _economy.can_afford(payer, amount):
		return {}
	return {"kind": kind, "payer": payer, "amount": amount}


# ---------------------------------------------------------------------------
# Órdenes
# ---------------------------------------------------------------------------

## `from_id` propone un tratado a `to_id`. No toca ningún saldo ni el territorio. Si el destinatario es una
## IA responde en el acto (acepta y el tratado se aplica, rechaza o contraoferta); si es humano, la
## propuesta queda pendiente. Devuelve {"ok", "error" (ERR_*), "response" (RESPONSE_*), "message",
## "proposal_id" (la pendiente o la contraoferta; 0 si no hay), "treaty" (resumen si se firmó)}.
func propose(from_id: int, to_id: int, kind: int, payer: int, amount: int) -> Dictionary:
	var paid := payer if amount > 0 else NO_PAYER
	var error := validate_terms(from_id, to_id, kind, paid, amount)
	if error == ERR_OK and has_pending(from_id, to_id):
		error = ERR_PENDING_EXISTS
	if error != ERR_OK:
		return _result(false, error, RESPONSE_NONE, error_message(error))
	if not _is_ai(to_id):
		var pending_id := _store(from_id, to_id, kind, paid, amount, false)
		return _result(true, ERR_OK, RESPONSE_PENDING, "Propuesta enviada a %s." % _name(to_id), pending_id)
	var verdict := evaluate_terms(to_id, from_id, kind, paid, amount)
	var ai_name := _name(to_id)
	match verdict["response"]:
		RESPONSE_ACCEPTED:
			var applied := _apply({"from": from_id, "to": to_id, "kind": kind, "payer": paid, "amount": amount})
			if not applied["ok"]:
				return _result(false, applied["error"], RESPONSE_NONE, error_message(applied["error"]))
			return _result(true, ERR_OK, RESPONSE_ACCEPTED, "%s acepta. %s" % [ai_name, treaty_text(applied["treaty"])], 0, applied["treaty"])
		RESPONSE_COUNTER:
			var counter: Dictionary = verdict["counter"]
			var counter_id := _store(to_id, from_id, counter["kind"], counter["payer"], counter["amount"], true)
			return _result(true, ERR_OK, RESPONSE_COUNTER, "%s contraoferta: %s." % [ai_name, terms_text(counter["kind"], counter["payer"], counter["amount"])], counter_id)
	_next_offer[_pair(from_id, to_id)] = _wars.now() + Balance.AI_OFFER_INTERVAL_TICKS
	var reason := "cree que va ganando la guerra" if verdict["reluctance"] > 0 else "los términos no le compensan"
	return _result(true, ERR_OK, RESPONSE_REJECTED, "%s rechaza la propuesta: %s." % [ai_name, reason])


## El destinatario acepta una propuesta pendiente y se aplica el tratado. Si no se puede aplicar (por
## ejemplo, el pagador ya no tiene el dinero) la propuesta se conserva y no cambia nada. Devuelve
## {"ok", "error", "message", "treaty"}.
func accept(proposal_id: int, by_id: int) -> Dictionary:
	if not _proposals.has(proposal_id):
		return _result(false, ERR_UNKNOWN_PROPOSAL, RESPONSE_NONE, error_message(ERR_UNKNOWN_PROPOSAL))
	var proposal: Dictionary = _proposals[proposal_id]
	if proposal["to"] != by_id:
		return _result(false, ERR_NOT_RECIPIENT, RESPONSE_NONE, error_message(ERR_NOT_RECIPIENT))
	var applied := _apply(proposal)
	if not applied["ok"]:
		return _result(false, applied["error"], RESPONSE_NONE, error_message(applied["error"]))
	return _result(true, ERR_OK, RESPONSE_ACCEPTED, treaty_text(applied["treaty"]), 0, applied["treaty"])


## El destinatario rechaza una propuesta pendiente (se descarta; la IA no volverá a proponer hasta pasado
## el intervalo). No cambia saldos ni territorio.
func reject(proposal_id: int, by_id: int) -> Dictionary:
	if not _proposals.has(proposal_id):
		return _result(false, ERR_UNKNOWN_PROPOSAL, RESPONSE_NONE, error_message(ERR_UNKNOWN_PROPOSAL))
	var proposal: Dictionary = _proposals[proposal_id]
	if proposal["to"] != by_id:
		return _result(false, ERR_NOT_RECIPIENT, RESPONSE_NONE, error_message(ERR_NOT_RECIPIENT))
	_proposals.erase(proposal_id)
	_next_offer[_pair(proposal["from"], proposal["to"])] = _wars.now() + Balance.AI_OFFER_INTERVAL_TICKS
	changed.emit()
	return _result(true, ERR_OK, RESPONSE_REJECTED, "Propuesta de %s rechazada." % _name(proposal["from"]))


func _result(ok: bool, error: int, response: int, message: String, proposal_id: int = 0, treaty: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "error": error, "response": response, "message": message, "proposal_id": proposal_id, "treaty": treaty}


func _store(from_id: int, to_id: int, kind: int, payer: int, amount: int, counter: bool) -> int:
	var proposal_id := _next_id
	_next_id += 1
	_proposals[proposal_id] = {"id": proposal_id, "from": from_id, "to": to_id, "kind": kind, "payer": payer,
			"amount": amount, "tick": _wars.now(), "counter": counter}
	changed.emit()
	return proposal_id


## Aplica el tratado de forma atómica (ver la cabecera). `proposal` necesita from, to, kind, payer y amount.
## Devuelve {"ok", "error", "treaty"}; si falla, no ha cambiado nada.
func _apply(proposal: Dictionary) -> Dictionary:
	var first_id: int = proposal["from"]
	var second_id: int = proposal["to"]
	var kind: int = proposal["kind"]
	var payer: int = proposal["payer"]
	var amount: int = proposal["amount"]
	var error := validate_terms(first_id, second_id, kind, payer, amount)
	if error != ERR_OK:
		return {"ok": false, "error": error, "treaty": {}}
	var plan := plan_treaty(first_id, second_id, kind)
	if not plan["ok"]:
		return {"ok": false, "error": ERR_TERRITORY, "treaty": {}}
	# A partir de aquí todo está ensayado. Copias para deshacer si, contra lo previsto, algo fallara.
	var terrain := _grid.copy_terrain_data()
	var owners := _grid.copy_owner_data()
	var occupation_backup := _occupation.export_state()
	var receiver := second_id if payer == first_id else first_id
	var stopped := _offensives.stop_between(first_id, second_id)
	if amount > 0:
		_economy.spend_money(payer, amount)
		_economy.add(receiver, amount, 0)
	var changed_cells: Array = []
	for step: Dictionary in plan["steps"]:
		var conquest := _grid.conquer_cells(step["nation"], step["cells"])
		if not conquest["ok"]:
			_grid.load_from_data(terrain, owners)
			_occupation.import_state(occupation_backup)
			if amount > 0:
				_economy.spend_money(receiver, amount)
				_economy.add(payer, amount, 0)
			return {"ok": false, "error": ERR_TERRITORY, "treaty": {}}
		changed_cells.append_array(conquest["changed_cells"])
	_occupation.release_between(first_id, second_id)
	var war := _wars.end_war(first_id, second_id)
	_wars.start_truce(first_id, second_id, Balance.TRUCE_TICKS)
	var treaty := {
		"a": first_id, "b": second_id, "kind": kind, "payer": payer if amount > 0 else NO_PAYER, "amount": amount,
		"gains": plan["gains"], "dropped": plan["dropped"], "released": plan["released"], "stopped": stopped,
		"tick": _wars.now(), "war": war, "truce_ticks": Balance.TRUCE_TICKS,
	}
	_history.append(treaty)
	for proposal_id: int in _proposals.keys():
		if _pair(_proposals[proposal_id]["from"], _proposals[proposal_id]["to"]) == _pair(first_id, second_id):
			_proposals.erase(proposal_id)
	_next_offer[_pair(first_id, second_id)] = _wars.now() + Balance.AI_OFFER_INTERVAL_TICKS
	if not changed_cells.is_empty():
		territory_changed.emit(changed_cells)
	treaty_signed.emit(treaty)
	changed.emit()
	return {"ok": true, "error": ERR_OK, "treaty": treaty}


# ---------------------------------------------------------------------------
# Tiempo
# ---------------------------------------------------------------------------

func _on_tick() -> void:
	var dirty := _wars.expire_truces() > 0
	for proposal_id: int in _proposals.keys():
		if _wars.now() - _proposals[proposal_id]["tick"] >= Balance.PROPOSAL_TIMEOUT_TICKS:
			_proposals.erase(proposal_id)
			dirty = true
	if _make_ai_offers():
		dirty = true
	if dirty:
		changed.emit()


## Cada IA en guerra con una nación humana puede enviarle una propuesta de paz si su reluctancia es lo
## bastante baja, sin repetirla antes del intervalo y sin tener ya una pendiente. Devuelve si creó alguna.
func _make_ai_offers() -> bool:
	var created := false
	for pair: Dictionary in _wars.war_pairs():
		var first_id: int = pair["a"]
		var second_id: int = pair["b"]
		if has_pending(first_id, second_id) or _wars.now() < _next_offer.get(_pair(first_id, second_id), 0):
			continue
		for ai_id: int in [first_id, second_id]:
			var other_id := second_id if ai_id == first_id else first_id
			if not _is_ai(ai_id) or _is_ai(other_id):
				continue
			var offer := _best_ai_offer(ai_id, other_id)
			if offer.is_empty():
				continue
			_store(ai_id, other_id, offer["kind"], NO_PAYER, 0, false)
			_next_offer[_pair(first_id, second_id)] = _wars.now() + Balance.AI_OFFER_INTERVAL_TICKS
			created = true
			break
	return created


## Qué paz sin pago ofrecería la IA por iniciativa propia: {} si prefiere seguir luchando; si no, la paz con
## conquistas cuando le da más que la paz blanca (y la acepta ella misma), y la paz blanca en caso contrario.
func _best_ai_offer(ai_id: int, other_id: int) -> Dictionary:
	var reluctance: int = ai_stance(ai_id, other_id)["reluctance"]
	if reluctance > -Balance.PEACE_SEEK_MARGIN:
		return {}
	var conquests := _territory_value(plan_treaty(ai_id, other_id, KIND_CONQUESTS), ai_id, other_id)
	if conquests > 0 and conquests >= reluctance:
		return {"kind": KIND_CONQUESTS}
	return {"kind": KIND_WHITE}


# ---------------------------------------------------------------------------
# Textos
# ---------------------------------------------------------------------------

static func error_message(code: int) -> String:
	match code:
		ERR_OK:
			return "Hecho."
		ERR_UNKNOWN_NATION:
			return "Nación desconocida."
		ERR_NOT_AT_WAR:
			return "No estáis en guerra."
		ERR_BAD_KIND:
			return "Tipo de tratado desconocido."
		ERR_BAD_PAYMENT:
			return "Pago no válido."
		ERR_NO_FUNDS:
			return "El pagador no tiene dinero suficiente."
		ERR_PENDING_EXISTS:
			return "Ya hay una propuesta pendiente: respóndela primero."
		ERR_PAUSED:
			return "La partida está en pausa: reanúdala para negociar."
		ERR_UNKNOWN_PROPOSAL:
			return "La propuesta ya no existe."
		ERR_NOT_RECIPIENT:
			return "Solo el destinatario puede responder."
		ERR_TERRITORY:
			return "No se pudo traspasar el territorio: no se ha cambiado nada."
	return "Error desconocido."


## «Paz con conquistas · Reino de Cobre paga 12» o «Paz blanca».
func terms_text(kind: int, payer: int, amount: int) -> String:
	var text: String = KIND_NAMES[kind] if kind >= 0 and kind < KIND_NAMES.size() else "Tratado"
	if amount > 0 and payer != NO_PAYER:
		text += " · %s paga %d" % [_name(payer), amount]
	return text


## Propuesta pendiente en una línea: «Reino de Cobre propone: Paz blanca».
func proposal_text(proposal: Dictionary) -> String:
	var terms := terms_text(proposal["kind"], proposal["payer"], proposal["amount"])
	if proposal.get("counter", false):
		return "Contraoferta de %s: %s" % [_name(proposal["from"]), terms]
	return "%s propone: %s" % [_name(proposal["from"]), terms]


## Resumen de un tratado firmado: tipo, celdas ganadas por cada parte, pago y tregua.
func treaty_text(treaty: Dictionary) -> String:
	var first_id: int = treaty["a"]
	var second_id: int = treaty["b"]
	var text := "Paz firmada (%s)." % terms_text(treaty["kind"], treaty["payer"], treaty["amount"])
	if treaty["kind"] == KIND_CONQUESTS:
		text += " %s gana %d celdas y %s gana %d." % [_name(first_id), treaty["gains"][first_id], _name(second_id), treaty["gains"][second_id]]
	elif treaty["released"] > 0:
		text += " Se liberan %d celdas ocupadas." % treaty["released"]
	return text + " Tregua de %d s." % int(treaty["truce_ticks"])
