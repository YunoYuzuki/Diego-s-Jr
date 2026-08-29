extends RigidBody

onready var luz = $Flashlight/SpotLight
onready var mesh_principal = $Flashlight
onready var outline_mesh = $Flashlight/OutlineMesh
onready var area_colisao = $Area

var ligada = false
var pode_tocar = true
var recuando = false

func _ready():
	add_to_group("interagivel")
	add_to_group("lanterna")
	luz.visible = false
	if outline_mesh:
		outline_mesh.visible = false
	
	area_colisao.add_to_group("interagivel")
	area_colisao.set_meta("door_parent", self)
	area_colisao.connect("body_entered", self, "_on_body_entered")
	area_colisao.connect("body_exited", self, "_on_body_exited")

# ==================== SAVE / LOAD ====================

func save() -> Dictionary:
	return {
		"filename": "res://scenes/Lanterna.tscn",  # ← MUDE pro caminho correto da sua lanterna
		"parent": get_parent().get_path(),
		"name": name,
		"pos_x": translation.x,
		"pos_y": translation.y,
		"pos_z": translation.z,
		"ligada": ligada,
		# Adicione aqui outras variáveis importantes se tiver
	}

func load_data(data: Dictionary) -> void:
	ligada = data.get("ligada", false)
	if ligada:
		luz.visible = true
	else:
		luz.visible = false
	# Recoloca posição se necessário (o sistema já faz, mas por segurança)
	translation = Vector3(
		data.get("pos_x", translation.x),
		data.get("pos_y", translation.y),
		data.get("pos_z", translation.z)
	)

# ==================== RESTO DO CÓDIGO ====================

func _on_body_entered(body):
	if body.is_in_group("player"):
		return
	recuando = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		return
	if area_colisao.get_overlapping_bodies().size() <= 1:
		recuando = false

func _physics_process(delta):
	if recuando:
		translation.z = lerp(translation.z, -5.0, 12.0 * delta)
	else:
		translation.z = lerp(translation.z, 0.0, 12.0 * delta)

func ligar():
	ligada = true
	luz.visible = true

func desligar():
	ligada = false
	luz.visible = false

func alternar():
	ligada = !ligada
	luz.visible = ligada

func set_foco(ativo):
	if outline_mesh:
		outline_mesh.visible = ativo
	pode_tocar = not ativo

func interagir(player):
	if Inventory.has_item("lanterna"):
		return
	Inventory.add_item("lanterna")
	player.pegar_lanterna(self)

func pode_interagir(player):
	return player.lanterna_atual == null

func get_spot() -> SpotLight:
	return luz
