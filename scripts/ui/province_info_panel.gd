## Panel con la información básica de la provincia seleccionada.
## Solo consulta ProvinceData; no guarda copias de los datos. Se conecta a la
## señal `selection_changed` del mapa desde la escena (main.tscn).
extends PanelContainer

const ProvinceData := preload("res://scripts/data/province_data.gd")

@onready var _hint: Label = %HintLabel
@onready var _details: VBoxContainer = %Details
@onready var _name_label: Label = %NameLabel
@onready var _owner_label: Label = %OwnerLabel
@onready var _neighbors_title: Label = %NeighborsTitle
@onready var _neighbors_list: Label = %NeighborsList


func _ready() -> void:
	show_province("")


## Muestra la provincia con ese id, o el texto de invitación si el id es "".
func show_province(province_id: String) -> void:
	var info := build_info(province_id)
	_hint.visible = info.is_empty()
	_details.visible = not info.is_empty()
	if info.is_empty():
		return
	_name_label.text = info["name"]
	_owner_label.text = "Propietario: %s" % info["owner_label"]
	_neighbors_title.text = "Vecinas (%d)" % info["neighbor_count"]
	_neighbors_list.text = "\n".join(info["neighbor_names"])


## Información lista para mostrar, leída de ProvinceData. Diccionario vacío si el id no existe.
static func build_info(province_id: String) -> Dictionary:
	var province := ProvinceData.find(province_id)
	if province.is_empty():
		return {}
	var neighbor_names: Array = []
	for neighbor_id: String in province["neighbors"]:
		neighbor_names.append(ProvinceData.find(neighbor_id)["name"])
	return {
		"name": province["name"],
		"owner_label": ProvinceData.owner_label(province["owner"]),
		"neighbor_count": neighbor_names.size(),
		"neighbor_names": neighbor_names,
	}
