## Datos autoritativos del mapa: provincias, propietario inicial, geometría y vecinas.
## Es la ÚNICA fuente de esta información; el dibujo (province_map.gd) y las
## pruebas (tests/test_province_data.gd) leen de aquí. No depende de nodos.
##
## Formato de cada provincia (Dictionary):
##   id        : identificador ASCII estable (no cambiar: lo usarán partidas y reglas futuras)
##   name      : nombre provisional para mostrar
##   owner     : propietario inicial, OWNER_PLAYER u OWNER_ENEMY
##   polygon   : vértices (Vector2) en coordenadas de la ventana de 1280x720
##   neighbors : ids de las provincias vecinas (la lista debe ser simétrica)
##
## Las provincias comparten vértices con sus vecinas, así el mapa no tiene huecos
## ni solapes. Se usa preload() (sin class_name) para que funcione en modo
## headless sin haber abierto antes el editor.
extends RefCounted

const OWNER_PLAYER := "player"
const OWNER_ENEMY := "enemy"
const OWNERS := [OWNER_PLAYER, OWNER_ENEMY]

const PROVINCES: Array = [
	{
		"id": "costa_norte",
		"name": "Costa Norte",
		"owner": OWNER_PLAYER,
		"polygon": [Vector2(136, 102), Vector2(329, 109), Vector2(353, 256), Vector2(138, 283)],
		"neighbors": ["puerto_alba", "llanura_oeste"],
	},
	{
		"id": "puerto_alba",
		"name": "Puerto Alba",
		"owner": OWNER_PLAYER,
		"polygon": [Vector2(329, 109), Vector2(539, 111), Vector2(520, 268), Vector2(353, 256)],
		"neighbors": ["monte_hierro", "villa_roble", "costa_norte"],
	},
	{
		"id": "monte_hierro",
		"name": "Monte Hierro",
		"owner": OWNER_ENEMY,
		"polygon": [Vector2(539, 111), Vector2(752, 116), Vector2(723, 267), Vector2(520, 268)],
		"neighbors": ["cumbre_gris", "paso_central", "puerto_alba"],
	},
	{
		"id": "cumbre_gris",
		"name": "Cumbre Gris",
		"owner": OWNER_ENEMY,
		"polygon": [Vector2(752, 116), Vector2(944, 116), Vector2(941, 256), Vector2(723, 267)],
		"neighbors": ["alto_rocal", "lago_bruma", "monte_hierro"],
	},
	{
		"id": "alto_rocal",
		"name": "Alto Rocal",
		"owner": OWNER_ENEMY,
		"polygon": [Vector2(944, 116), Vector2(1130, 107), Vector2(1139, 267), Vector2(941, 256)],
		"neighbors": ["canon_rojo", "cumbre_gris"],
	},
	{
		"id": "llanura_oeste",
		"name": "Llanura Oeste",
		"owner": OWNER_PLAYER,
		"polygon": [Vector2(138, 283), Vector2(353, 256), Vector2(348, 431), Vector2(127, 430)],
		"neighbors": ["costa_norte", "villa_roble", "cabo_austral"],
	},
	{
		"id": "villa_roble",
		"name": "Villa Roble",
		"owner": OWNER_PLAYER,
		"polygon": [Vector2(353, 256), Vector2(520, 268), Vector2(521, 453), Vector2(348, 431)],
		"neighbors": ["puerto_alba", "paso_central", "bahia_sal", "llanura_oeste"],
	},
	{
		"id": "paso_central",
		"name": "Paso Central",
		"owner": OWNER_PLAYER,
		"polygon": [Vector2(520, 268), Vector2(723, 267), Vector2(756, 458), Vector2(521, 453)],
		"neighbors": ["monte_hierro", "lago_bruma", "fuerte_ceniza", "villa_roble"],
	},
	{
		"id": "lago_bruma",
		"name": "Lago Bruma",
		"owner": OWNER_ENEMY,
		"polygon": [Vector2(723, 267), Vector2(941, 256), Vector2(930, 420), Vector2(756, 458)],
		"neighbors": ["cumbre_gris", "canon_rojo", "delta_negro", "paso_central"],
	},
	{
		"id": "canon_rojo",
		"name": "Cañón Rojo",
		"owner": OWNER_ENEMY,
		"polygon": [Vector2(941, 256), Vector2(1139, 267), Vector2(1143, 431), Vector2(930, 420)],
		"neighbors": ["alto_rocal", "lago_bruma"],
	},
	{
		"id": "cabo_austral",
		"name": "Cabo Austral",
		"owner": OWNER_PLAYER,
		"polygon": [Vector2(127, 430), Vector2(348, 431), Vector2(327, 595), Vector2(152, 610)],
		"neighbors": ["llanura_oeste", "bahia_sal"],
	},
	{
		"id": "bahia_sal",
		"name": "Bahía Sal",
		"owner": OWNER_PLAYER,
		"polygon": [Vector2(348, 431), Vector2(521, 453), Vector2(539, 594), Vector2(327, 595)],
		"neighbors": ["villa_roble", "fuerte_ceniza", "cabo_austral"],
	},
	{
		"id": "fuerte_ceniza",
		"name": "Fuerte Ceniza",
		"owner": OWNER_ENEMY,
		"polygon": [Vector2(521, 453), Vector2(756, 458), Vector2(744, 594), Vector2(539, 594)],
		"neighbors": ["paso_central", "delta_negro", "bahia_sal"],
	},
	{
		"id": "delta_negro",
		"name": "Delta Negro",
		"owner": OWNER_ENEMY,
		"polygon": [Vector2(756, 458), Vector2(930, 420), Vector2(943, 620), Vector2(744, 594)],
		"neighbors": ["lago_bruma", "fuerte_ceniza"],
	},
]


## Devuelve todas las provincias.
static func all() -> Array:
	return PROVINCES


## Devuelve la provincia con ese id, o un Dictionary vacío si no existe.
static func find(province_id: String) -> Dictionary:
	for province: Dictionary in PROVINCES:
		if province["id"] == province_id:
			return province
	return {}


## Devuelve el id de la provincia cuyo polígono contiene `point` (coordenadas
## locales del mapa, las mismas que usan los polígonos), o "" si no hay ninguna.
## Si un punto cae exactamente sobre una frontera compartida, gana la primera
## provincia de la lista: el resultado es siempre el mismo para el mismo punto.
static func find_at_point(point: Vector2) -> String:
	for province: Dictionary in PROVINCES:
		if Geometry2D.is_point_in_polygon(point, PackedVector2Array(province["polygon"])):
			return province["id"]
	return ""


## Texto en español para mostrar un propietario ("Jugador" o "Enemigo").
static func owner_label(owner_id: String) -> String:
	match owner_id:
		OWNER_PLAYER:
			return "Jugador"
		OWNER_ENEMY:
			return "Enemigo"
	return "Desconocido"


## Cuenta las provincias cuyo propietario inicial es `owner_id`.
static func count_owned_by(owner_id: String) -> int:
	var total := 0
	for province: Dictionary in PROVINCES:
		if province["owner"] == owner_id:
			total += 1
	return total


## Centro aproximado (media de vértices) para colocar la etiqueta.
static func polygon_center(polygon: Array) -> Vector2:
	var sum := Vector2.ZERO
	for point: Vector2 in polygon:
		sum += point
	return sum / polygon.size()
