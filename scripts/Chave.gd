extends StaticBody

onready var mesh    = $chave
onready var outline = $chave/OutlineMesh

var revelada : bool = false

func _ready() -> void:
	add_to_group("interagivel")
	add_to_group("chave_quarto")
	add_to_group("Persist")
	_set_visivel(false)

func revelar() -> void:
	if revelada:
		outline.visible = false
		return
	revelada = true
	_set_visivel(true)
	print("🔑 Chave do quarto revelada no mapa!")

func _set_visivel(ativo: bool) -> void:
	if mesh:
		mesh.visible = ativo
	for child in get_children():
		if child is CollisionShape or child is CollisionPolygon:
			child.disabled = not ativo

func set_foco(ativo: bool) -> void:
	if outline:
		outline.visible = ativo and revelada

func pode_interagir(_player) -> bool:
	return revelada

func interagir(player) -> void:
	if not revelada:
		return
	if Inventory.has_item("chave_quarto"):
		return
	Inventory.add_item("chave_quarto")
	print("🔑 Jogador pegou a chave do quarto!")

	# Tutoriais ao pegar a chave
	TutorialManager.tutorial_inventario()
	TutorialManager.tutorial_agachar()

	# Esconde o objeto do mapa após pegar
	_set_visivel(false)
	remove_from_group("interagivel")

func save() -> Dictionary:
	return {
		"filename": "res://scenes/Chave.tscn",
		"parent":   get_parent().get_path(),
		"name":     name,
		"pos_x":    translation.x,
		"pos_y":    translation.y,
		"pos_z":    translation.z,
		"revelada": revelada
	}

func load_data(data: Dictionary) -> void:
	revelada = data.get("revelada", false)
	_set_visivel(revelada)
