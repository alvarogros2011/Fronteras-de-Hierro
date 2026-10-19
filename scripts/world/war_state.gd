## Estado de guerra entre naciones (hito 9). Sin nodos ni dibujo.
##
## Registro EXPLÍCITO y consultable de qué naciones están en guerra, independiente de que existan
## sectores, ofensivas u ocupaciones. Provisional: una guerra empieza sola cuando una ofensiva ataca
## el territorio oficial de otra nación (decisión pendiente de confirmar antes del sistema
## diplomático definitivo, ver docs/GDD.md D21). Atacar tierra sin reclamar no declara nada.
##
## Limitación conocida: todavía NO existe forma de terminar una guerra (paz, tregua, rendición). Detener
## una ofensiva no la termina y las ocupaciones tampoco se borran. El siguiente hito diplomático
## añadirá el final de la guerra sobre este mismo registro.
extends RefCounted

## Se emite cuando empieza una guerra nueva. No lleva datos.
signal changed

var _wars: Array = []  # [{"a": int, "b": int, "aggressor": int}], en orden de declaración


## Declara la guerra entre dos naciones distintas. Devuelve true si es una guerra NUEVA y false si ya
## existía o los datos no valen (misma nación o id <= 0).
func declare_war(aggressor_id: int, defender_id: int) -> bool:
	if aggressor_id <= 0 or defender_id <= 0 or aggressor_id == defender_id:
		return false
	if at_war(aggressor_id, defender_id):
		return false
	_wars.append({"a": mini(aggressor_id, defender_id), "b": maxi(aggressor_id, defender_id), "aggressor": aggressor_id})
	changed.emit()
	return true


func at_war(first_id: int, second_id: int) -> bool:
	var low := mini(first_id, second_id)
	var high := maxi(first_id, second_id)
	for war: Dictionary in _wars:
		if war["a"] == low and war["b"] == high:
			return true
	return false


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
	var low := mini(first_id, second_id)
	var high := maxi(first_id, second_id)
	for war: Dictionary in _wars:
		if war["a"] == low and war["b"] == high:
			return war["aggressor"]
	return 0
