extends StaticBody
onready var mesh    = $chave
onready var outline = $chave/OutlineMesh
var revelada : bool = false
var coletada : bool = false

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
	coletada = true
	TelaPickup.mostrar_item("Chave", "Uma chave... preta? Parece ser uma chave normal, apenas.", preload("res://assets/scenes_pickup/chave_pickup.tscn"))
	_set_visivel(false)
	remove_from_group("interagivel")

# SALVAMENTO CORRIGIDO VIA NODE_PATH
func save() -> Dictionary:
	return {
		"node_path": str(get_path()),
		"revelada": revelada,
		"coletada": coletada
	}

func load_data(data: Dictionary) -> void:
	coletada = data.get("coletada", false)
	if coletada:
		queue_free() # Some do mapa se já foi pega antes
		return

	revelada = data.get("revelada", false)
	_set_visivel(revelada)
