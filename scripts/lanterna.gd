extends RigidBody
onready var luz = $Flashlight/SpotLight
onready var mesh_principal = $Flashlight
onready var outline_mesh = $Flashlight/OutlineMesh
onready var area_colisao = $Area
var ligada = false
var pode_tocar = true
var recuando = false

# --- Equipada na mão / cabeça ---
var equipada : bool = false

# Animação de "sumir pra baixo" (só usada no chão / mundo, NÃO quando equipada)
export var sumir_baixo_amount : float = 0.55
export var sumir_rot_amount   : float = 35.0
export var velocidade_anim    : float = 9.0

var _offset_y_alvo   : float = 0.0
var _offset_y_atual  : float = 0.0
var _rot_x_alvo      : float = 0.0
var _rot_x_atual     : float = 0.0

# Guarda se a lanterna estava ligada antes de sumir (colisao no mundo)
var _estava_ligada_antes : bool = false
var _sumiu_por_colisao   : bool = false

# Contador de colisões sólidas (sem o player)
var _colisao_count : int = 0
var _cooldown_voltar : float = 0.0
const TEMPO_LIVRE_PARA_VOLTAR : float = 0.3

var _energia_base : float = 1.0

func _ready():
	add_to_group("interagivel")
	add_to_group("lanterna")
	add_to_group("Persist")
	luz.visible = false
	_energia_base = luz.light_energy if luz else 1.0
	if outline_mesh:
		outline_mesh.visible = false

	area_colisao.add_to_group("interagivel")
	area_colisao.set_meta("door_parent", self)
	area_colisao.connect("body_entered", self, "_on_body_entered")
	area_colisao.connect("body_exited", self, "_on_body_exited")


## Esconde só os MeshInstance — o SpotLight continua existindo e iluminando.
func _set_meshes_visiveis(visivel: bool) -> void:
	if mesh_principal == null:
		return
	for c in mesh_principal.get_children():
		if c is MeshInstance:
			c.visible = visivel
	# Outline só no mundo / foco
	if outline_mesh and is_instance_valid(outline_mesh):
		if equipada:
			outline_mesh.visible = false
		elif not visivel:
			outline_mesh.visible = false


func marcar_equipada(valor: bool) -> void:
	equipada = valor
	recuando = false
	_sumiu_por_colisao = false
	_colisao_count = 0
	_cooldown_voltar = 0.0
	_offset_y_atual = 0.0
	_offset_y_alvo  = 0.0
	_rot_x_atual    = 0.0
	_rot_x_alvo     = 0.0
	translation.y   = 0.0
	rotation_degrees.x = 0.0
	if mesh_principal:
		mesh_principal.translation.y = 0.0
		mesh_principal.rotation_degrees.x = 0.0

	if valor:
		# Nó continua ativo (luz na cabeça), mas a CÂMERA não vê o mesh
		# — igual corpo da Laura: presente no mundo, invisível em 1ª pessoa.
		visible = true
		if mesh_principal:
			mesh_principal.visible = true  # nó pai precisa existir pro SpotLight
		_set_meshes_visiveis(false)
		# Restaura estado da luz
		if luz:
			luz.visible = ligada
			if ligada:
				luz.light_energy = _energia_base
	else:
		_set_meshes_visiveis(true)
		if luz:
			luz.visible = ligada


func save() -> Dictionary:
	var na_mao = equipada or Inventory.has_item("lanterna")
	return {
		"node_path": str(get_path()),
		"pos_x": translation.x,
		"pos_y": translation.y,
		"pos_z": translation.z,
		"ligada": ligada,
		"equipada": na_mao
	}


func load_data(data: Dictionary) -> void:
	ligada = data.get("ligada", false)
	var estava_equipada = data.get("equipada", false) or Inventory.has_item("lanterna")
	if estava_equipada:
		# Some do chão; a Camera recoloca no holder e chama marcar_equipada
		visible = false
		if luz:
			luz.visible = false
		return
	visible = true
	if luz:
		luz.visible = ligada
		if ligada:
			luz.light_energy = _energia_base
	_set_meshes_visiveis(true)
	translation = Vector3(
		data.get("pos_x", translation.x),
		data.get("pos_y", translation.y),
		data.get("pos_z", translation.z)
	)


func _on_body_entered(body):
	if body.is_in_group("player"):
		return
	# Equipada: mesh já está invisível — não anima sumir
	if equipada:
		return
	recuando = true


func _on_body_exited(body):
	if body.is_in_group("player"):
		return
	if equipada:
		return
	if area_colisao.get_overlapping_bodies().size() <= 1:
		recuando = false


func _physics_process(delta):
	if equipada:
		# Só garante offsets zerados e meshes invisíveis; luz independente
		translation.y = 0.0
		rotation_degrees.x = 0.0
		if mesh_principal:
			mesh_principal.translation.y = 0.0
			mesh_principal.rotation_degrees.x = 0.0
		_set_meshes_visiveis(false)
		if luz:
			luz.visible = ligada
		return

	# No chão / mundo: recuo clássico
	if recuando:
		translation.z = lerp(translation.z, -5.0, 12.0 * delta)
	else:
		translation.z = lerp(translation.z, 0.0, 12.0 * delta)


func ligar():
	ligada = true
	if luz:
		luz.visible = true
		luz.light_energy = _energia_base
	# Mesh continua invisível na 1ª pessoa — só a luz muda


func desligar():
	ligada = false
	if luz:
		luz.visible = false
		luz.light_energy = _energia_base


func alternar():
	if ligada:
		desligar()
	else:
		ligar()


func set_foco(ativo):
	if equipada:
		# Não mostra outline enquanto está na mão
		if outline_mesh:
			outline_mesh.visible = false
		pode_tocar = false
		return
	if outline_mesh:
		outline_mesh.visible = ativo
	pode_tocar = not ativo


func interagir(player):
	if Inventory.has_item("lanterna"):
		return
	Inventory.add_item("lanterna")
	player.pegar_lanterna(self)
	TelaPickup.mostrar_item("Lanterna", "Uma lanterna normal. O nome 'Karen' está escrito nela...", preload("res://assets/scenes_pickup/flashlight_pickup.tscn"))


func pode_interagir(player):
	return player.lanterna_atual == null


func get_spot() -> SpotLight:
	return luz


# Com mesh escondido na mão, "visível na tela" = falsa (só a luz importa)
func esta_visivel_na_mao() -> bool:
	return false
