extends Spatial
# laura_controller.gd
# Coloque na raiz da cena da Laura (filha do Player / KinematicBody).
#
# - Animações: idle / walking / running (troca imediata, sem delay)
# - Cabeça: layer que a câmera do player não desenha (espelho desenha)
# - Braço direito: some (scale nos ossos) quando a lanterna está na mão visível

# ==================== EXPORTS ====================
export var anim_idle    : String = "idle"
export var anim_walking : String = "walking"
export var anim_running : String = "running"

export var move_threshold : float = 0.12

# Layer da cabeça (bit). Layer 10 no editor = bit 9
export var head_layer_bit : int = 9

export var head_name_hints : String = "head,hair,cabelo,cabeca,face,olho,eye"

# Ossos do braço direito (Mixamo). Usados pra esconder o braço.
export var bones_braco_direito : String = "mixamorig:RightArm,mixamorig:RightForeArm,mixamorig:RightHand,mixamorig:RightShoulder"

# ==================== NODES ====================
onready var anim_player : AnimationPlayer = _find_anim_player()
onready var skeleton    : Skeleton        = _find_skeleton()

var player_body : KinematicBody = null
var camera_node : Camera = null

enum AnimState { IDLE, WALKING, RUNNING }
var _anim_state : int = AnimState.IDLE

var _head_meshes : Array = []
var _arm_bone_indices : Array = []
var _right_arm_hidden : bool = false


func _ready() -> void:
	add_to_group("laura_body")

	var n = get_parent()
	while n:
		if n is KinematicBody and n.is_in_group("player"):
			player_body = n
			break
		n = n.get_parent()
	if player_body == null:
		player_body = get_parent() as KinematicBody

	if player_body:
		camera_node = player_body.get_node_or_null("Camera") as Camera

	_coletar_meshes_cabeca()
	_configurar_camada_cabeca()
	_cache_ossos_braco()

	if anim_player:
		_play_anim(anim_idle, true)
	else:
		push_warning("LauraController: AnimationPlayer não encontrado.")


func _physics_process(_delta: float) -> void:
	if player_body == null:
		return
	_atualizar_animacao()
	_atualizar_braco_lanterna()


# ------------------------------------------------------------------
# ANIMAÇÕES — troca imediata
# ------------------------------------------------------------------
func _atualizar_animacao() -> void:
	if anim_player == null:
		return

	# Usa input + sprint pra resposta imediata (não espera velocidade física)
	var input_andando = Input.is_action_pressed("w") or Input.is_action_pressed("a") \
			or Input.is_action_pressed("s") or Input.is_action_pressed("d")
	var vel_h = Vector3(player_body.vel.x, 0.0, player_body.vel.z).length()
	var andando = input_andando or vel_h > move_threshold
	var correndo = player_body.is_sprinting and andando

	var desejado : int = AnimState.IDLE
	if correndo:
		desejado = AnimState.RUNNING
	elif andando:
		desejado = AnimState.WALKING

	if desejado != _anim_state:
		_anim_state = desejado
		match desejado:
			AnimState.IDLE:
				_play_anim(anim_idle, true)
			AnimState.WALKING:
				_play_anim(anim_walking, true)
			AnimState.RUNNING:
				_play_anim(anim_running, true)


func _play_anim(nome: String, loop: bool) -> void:
	if anim_player == null or nome == "":
		return
	if not anim_player.has_animation(nome):
		if nome == anim_running and anim_player.has_animation(anim_walking):
			nome = anim_walking
		else:
			return
	var anim = anim_player.get_animation(nome)
	if anim:
		anim.loop = loop
	if anim_player.current_animation != nome:
		anim_player.play(nome)


# ------------------------------------------------------------------
# CABEÇA — layer
# ------------------------------------------------------------------
func _configurar_camada_cabeca() -> void:
	var head_mask = 1 << head_layer_bit
	for m in _head_meshes:
		if is_instance_valid(m):
			m.layers = head_mask
	if camera_node:
		camera_node.cull_mask = camera_node.cull_mask & ~head_mask
	if _head_meshes.empty():
		push_warning("LauraController: nenhum mesh de cabeça por nome. " +
			"Se for um mesh único, use esconder_cabeca_por_osso(true).")


func esconder_cabeca_por_osso(esconder: bool) -> void:
	if skeleton == null:
		return
	var idx = skeleton.find_bone("mixamorig:Head")
	if idx < 0:
		idx = skeleton.find_bone("Head")
	if idx < 0:
		return
	var t = Transform.IDENTITY
	if esconder:
		t.basis = t.basis.scaled(Vector3(0.01, 0.01, 0.01))
	skeleton.set_bone_pose(idx, t)


# ------------------------------------------------------------------
# BRAÇO DIREITO × LANTERNA (via ossos — funciona com mesh único)
# ------------------------------------------------------------------
func _cache_ossos_braco() -> void:
	_arm_bone_indices.clear()
	if skeleton == null:
		return
	for nome in bones_braco_direito.split(",", false):
		var bone_name = nome.strip_edges()
		if bone_name == "":
			continue
		var idx = skeleton.find_bone(bone_name)
		# tenta sem prefixo também
		if idx < 0 and bone_name.begins_with("mixamorig:"):
			idx = skeleton.find_bone(bone_name.replace("mixamorig:", ""))
		if idx >= 0:
			_arm_bone_indices.append(idx)
	if _arm_bone_indices.empty():
		push_warning("LauraController: nenhum osso de braço direito encontrado. " +
			"Confira os nomes no Skeleton (Viewport Display → Names).")


func _atualizar_braco_lanterna() -> void:
	if camera_node == null or skeleton == null:
		return
	var lanterna = camera_node.lanterna_atual
	var esconder = false
	if lanterna != null and lanterna.equipada:
		if lanterna.has_method("esta_visivel_na_mao"):
			esconder = lanterna.esta_visivel_na_mao()
		else:
			# equipada = esconde o braço (lanterna está na mão)
			esconder = true

	if esconder == _right_arm_hidden:
		# ainda reaplica a pose escondida todo frame (animação sobrescreve ossos)
		if esconder:
			_aplicar_braco_escondido()
		return

	_right_arm_hidden = esconder
	if esconder:
		_aplicar_braco_escondido()
	else:
		_restaurar_braco()


func _aplicar_braco_escondido() -> void:
	# Scale quase zero nos ossos — some visualmente mesmo com animação rodando
	for idx in _arm_bone_indices:
		var t = Transform.IDENTITY
		t.basis = t.basis.scaled(Vector3(0.01, 0.01, 0.01))
		skeleton.set_bone_pose(idx, t)


func _restaurar_braco() -> void:
	for idx in _arm_bone_indices:
		skeleton.set_bone_pose(idx, Transform.IDENTITY)


# ------------------------------------------------------------------
# COLETA
# ------------------------------------------------------------------
func _coletar_meshes_cabeca() -> void:
	_head_meshes.clear()
	var todos = []
	_coletar_mesh_recursivo(self, todos)
	var head_keys = head_name_hints.to_lower().split(",", false)
	for m in todos:
		var n = m.name.to_lower()
		for k in head_keys:
			var key = k.strip_edges()
			if key != "" and key in n:
				_head_meshes.append(m)
				break


func _coletar_mesh_recursivo(nodo: Node, out: Array) -> void:
	if nodo is MeshInstance:
		out.append(nodo)
	for c in nodo.get_children():
		_coletar_mesh_recursivo(c, out)


func _find_anim_player() -> AnimationPlayer:
	if has_node("AnimationPlayer"):
		return $AnimationPlayer as AnimationPlayer
	return _find_por_classe(self, "AnimationPlayer") as AnimationPlayer


func _find_skeleton() -> Skeleton:
	return _find_por_classe(self, "Skeleton") as Skeleton


func _find_por_classe(nodo: Node, classe: String) -> Node:
	if nodo.get_class() == classe:
		return nodo
	for c in nodo.get_children():
		var r = _find_por_classe(c, classe)
		if r:
			return r
	return null
