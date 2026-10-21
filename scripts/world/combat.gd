## Reglas puras del combate determinista (hito 9). Sin nodos, sin estado y sin azar: solo funciones
## estáticas sobre enteros, para poder probarlas sin partida ni interfaz. Valores: combat_balance.gd.
##
## Un ENFRENTAMIENTO enfrenta a `attackers` soldados contra una defensa local de `defense` soldados:
##   - Defensa efectiva = defensa * DEFENSE_BONUS_PERCENT / 100.
##   - El atacante vence si attackers * 100 > defensa * DEFENSE_BONUS_PERCENT (empate: vence la defensa).
##     Sin defensa (0) vence siempre que haya atacantes, sin bajas.
##   - Bajas del vencedor = WINNER_LOSS_PERCENT de la fuerza del vencido; bajas del vencido =
##     LOSER_LOSS_PERCENT de la suya. Redondeo hacia arriba, nunca más soldados de los que hay.
##   - Relación = atacantes / defensa efectiva (en milésimas). Solo sirve para etiquetar la previsión:
##     ventaja atacante (>= 1,5), equilibrado o defensa superior (< 0,8). El resultado lo decide la
##     regla de arriba, no la etiqueta.
## La previsión ES esta misma función aplicada al estado actual: no es una probabilidad estadística.
##
## Hito 11: ratio_permille, attacker_wins y resolve aceptan una bonificación de defensa distinta (por
## defecto DEFENSE_BONUS_PERCENT); Offensives la sube cerca de las ciudades del defensor
## (DEFENSE_BONUS_PERCENT + CITY_DEFENSE_BONUS_PERCENT).
extends RefCounted

const Balance := preload("res://scripts/data/combat_balance.gd")

const CATEGORY_ADVANTAGE := 0  # ventaja atacante
const CATEGORY_BALANCED := 1  # enfrentamiento equilibrado
const CATEGORY_DEFENSE := 2  # defensa superior

## Relación que se asigna cuando no hay defensa (evita dividir entre 0).
const NO_RESISTANCE_RATIO := 1000000


## amount * percent / 100 redondeado hacia arriba (amount y percent >= 0).
@warning_ignore("integer_division")
static func ceil_percent(amount: int, percent: int) -> int:
	return (amount * percent + 99) / 100


## Tramos de frontera de una nación con `exposed_cells` celdas expuestas (al menos 1).
@warning_ignore("integer_division")
static func front_count(exposed_cells: int) -> int:
	return maxi(1, (exposed_cells + Balance.CELLS_PER_FRONT - 1) / Balance.CELLS_PER_FRONT)


## Defensa local estimada en un tramo: el fondo común de la nación (DEFENSE_POOL_PERCENT de sus
## soldados) repartido a partes iguales entre sus tramos, redondeando hacia arriba, con un mínimo
## de MIN_LOCAL_DEFENSE si tiene soldados y sin superar nunca sus soldados. Sin soldados: 0.
@warning_ignore("integer_division")
static func defense_per_front(defender_soldiers: int, exposed_cells: int) -> int:
	if defender_soldiers <= 0:
		return 0
	var pool: int = defender_soldiers * Balance.DEFENSE_POOL_PERCENT / 100
	var fronts := front_count(exposed_cells)
	var share: int = (pool + fronts - 1) / fronts
	return clampi(maxi(share, Balance.MIN_LOCAL_DEFENSE), 0, defender_soldiers)


## Relación atacantes / defensa efectiva en milésimas (1000 = fuerzas iguales).
@warning_ignore("integer_division")
static func ratio_permille(attackers: int, defense: int, bonus_percent: int = Balance.DEFENSE_BONUS_PERCENT) -> int:
	if defense <= 0:
		return NO_RESISTANCE_RATIO if attackers > 0 else 0
	return attackers * 100000 / (defense * bonus_percent)


## CATEGORY_* correspondiente a una relación.
static func category(ratio: int) -> int:
	if ratio >= Balance.ADVANTAGE_RATIO_PERMILLE:
		return CATEGORY_ADVANTAGE
	if ratio >= Balance.DEFENSE_RATIO_PERMILLE:
		return CATEGORY_BALANCED
	return CATEGORY_DEFENSE


## ¿Vence el atacante? (regla exacta con enteros; un empate lo gana la defensa)
static func attacker_wins(attackers: int, defense: int, bonus_percent: int = Balance.DEFENSE_BONUS_PERCENT) -> bool:
	if attackers <= 0:
		return false
	return defense <= 0 or attackers * 100 > defense * bonus_percent


## Resuelve un enfrentamiento: {"attacker_wins", "attacker_losses", "defender_losses",
## "attackers_after", "ratio_permille", "category"}. Pura y determinista.
static func resolve(attackers: int, defense: int, bonus_percent: int = Balance.DEFENSE_BONUS_PERCENT) -> Dictionary:
	var wins := attacker_wins(attackers, defense, bonus_percent)
	var attacker_losses := 0
	var defender_losses := 0
	if defense > 0 and attackers > 0:
		if wins:
			attacker_losses = ceil_percent(defense, Balance.WINNER_LOSS_PERCENT)
			defender_losses = ceil_percent(defense, Balance.LOSER_LOSS_PERCENT)
		else:
			attacker_losses = ceil_percent(attackers, Balance.LOSER_LOSS_PERCENT)
			defender_losses = ceil_percent(attackers, Balance.WINNER_LOSS_PERCENT)
	attacker_losses = mini(attacker_losses, attackers)
	defender_losses = mini(defender_losses, defense)
	var ratio := ratio_permille(attackers, defense, bonus_percent)
	return {
		"attacker_wins": wins,
		"attacker_losses": attacker_losses,
		"defender_losses": defender_losses,
		"attackers_after": attackers - attacker_losses,
		"ratio_permille": ratio,
		"category": category(ratio),
	}
