extends StaticBody
export(String) var nome_lampada = "lamp_lavanderia"
var ligada  = false
var lampada = null
onready var lightswitch  = $Lightswitch
onready var lightswitch2 = $Lightswitch2
onready var outline1     = $Lightswitch/OutlineMesh
onready var outline2     = $Lightswitch2/OutlineMesh
onready var label        = $Lightswitch/CanvasLayer/Label

func _ready():
	add_to_group("Persist_estatico")
	add_to_group("Persist")
	add_to_group("interagivel")
	lampada = get_tree().get_root().find_node(nome_lampada, true, false)
	lightswitch.visible  = true
	lightswitch2.visible = false
	outline1.visible     = false
	outline2.visible     = false
	if lampada:
		lampada.visible = false

func set_foco(ativo):
	if ligada:
		outline2.visible = ativo
	else:
		outline1.visible = ativo

func interagir(player):
	if not lampada:
		print("Lampada '", nome_lampada, "' nao encontrada na cena!")
		return
	ligada = not ligada
	if ligada:
		lightswitch.visible  = false
		lightswitch2.visible = true
		lampada.visible      = true
	else:
		lightswitch2.visible = false
		lightswitch.visible  = true
		lampada.visible      = false

func save() -> Dictionary:
	return {
		"tipo_estatico": "interruptor",
		"name":   name,
		"parent": get_parent().get_path(),
		"pos_x":  translation.x,
		"pos_y":  translation.y,
		"pos_z":  translation.z,
		"ligada": ligada
	}

func load_data(data: Dictionary) -> void:
	ligada = data.get("ligada", false)
	if ligada:
		lightswitch.visible  = false
		lightswitch2.visible = true
		if lampada:
			lampada.visible = true
	else:
		lightswitch.visible  = true
		lightswitch2.visible = false
		if lampada:
			lampada.visible = false