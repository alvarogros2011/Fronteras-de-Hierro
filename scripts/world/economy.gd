## Saldos de dinero y recursos de cada nación (hito 6): única fuente de datos económicos.
## Sin nodos ni dibujo. Los saldos son enteros y nunca pueden ser negativos: toda operación
## que los dejaría negativos, o que recibe cantidades negativas, se rechaza sin cambiar nada.
##
## Solo hay dos recursos (dinero y recursos). No conoce ciudades ni territorio: quien produce
## o gasta (CityManager) llama a add / spend_money.
extends RefCounted

const Balance := preload("res://scripts/data/economy_balance.gd")

## Se emite cuando cambia algún saldo (una vez por operación aplicada). No lleva datos.
signal balances_changed

var _money: Dictionary = {}
var _resources: Dictionary = {}


func _init(nation_ids: Array) -> void:
	reset(nation_ids)


## Pone a todas las naciones dadas en el saldo inicial.
func reset(nation_ids: Array) -> void:
	_money = {}
	_resources = {}
	for nation_id: int in nation_ids:
		_money[nation_id] = Balance.INITIAL_MONEY
		_resources[nation_id] = Balance.INITIAL_RESOURCES
	balances_changed.emit()


func has_nation(nation_id: int) -> bool:
	return _money.has(nation_id)


## Dinero de la nación, o -1 si no existe.
func get_money(nation_id: int) -> int:
	return _money.get(nation_id, -1)


## Recursos de la nación, o -1 si no existen.
func get_resources(nation_id: int) -> int:
	return _resources.get(nation_id, -1)


func can_afford(nation_id: int, amount: int) -> bool:
	return amount >= 0 and _money.has(nation_id) and _money[nation_id] >= amount


## Suma dinero y recursos (cantidades >= 0). Devuelve false, sin cambiar nada, si la nación no
## existe o alguna cantidad es negativa.
func add(nation_id: int, money: int, resources: int) -> bool:
	if not _money.has(nation_id) or money < 0 or resources < 0:
		return false
	_money[nation_id] += money
	_resources[nation_id] += resources
	if money > 0 or resources > 0:
		balances_changed.emit()
	return true


## Descuenta dinero. Devuelve false, sin cambiar nada, si la nación no existe, la cantidad es
## negativa o el saldo no alcanza.
func spend_money(nation_id: int, amount: int) -> bool:
	if not can_afford(nation_id, amount):
		return false
	_money[nation_id] -= amount
	if amount > 0:
		balances_changed.emit()
	return true
