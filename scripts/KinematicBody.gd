extends KinematicBody

#  Exportáveis 
export var velocity        := 5.5
export var sprint_velocity := 10.5
export var sensi           := 0.1

export var max_stamina                : float = 100.0
export var stamina_drain_rate         : float = 14.3
export var stamina_regen_rate         : float = 5.0
export var stamina_regen_rate_stopped : float = 7.5

#  Nodes 
onready var camera   = $Camera
onready var raycast  : RayCast    = $Camera/RayCast
onready var target   : Position3D = $Camera/Position3D
onready var passos                = $passos

onready var hud = $Camera/hud
onready var post_process = $Camera/PostProcess

#  Movimento 
const dist_range : float = 2.0
var gravity      : float = -20.0
var rot_x        : float = 0.0
var vel          := Vector3.ZERO

var _zonas_luz_count : int = 0
var esta_na_luz : bool = false

# Passos: evita stop/start quando is_on_floor() pisca false por 1 frame
var _chao_grace : float = 0.0
const CHAO_GRACE_TEMPO : float = 0.12
var _quer_passos : bool = false

#  Stamina 
var current_stamina : float = 100.0
var can_sprint      : bool  = true
var is_sprinting    : bool  = false

func _ready():
	add_to_group("Persist")
	add_to_group("player") # Unificado para "player" em minúsculo
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	current_stamina = max_stamina

	var cam = get_node_or_null("Camera")
	if cam:
		cam.target_pitch  = deg2rad(rot_x)
		cam.current_pitch = deg2rad(rot_x)
		# Se o stream NÃO estiver em loop, reinicia sozinho enquanto anda
	if passos and not passos.is_connected("finished", self, "_on_passos_finished"):
		passos.connect("finished", self, "_on_passos_finished")

	_tirar_hud_do_viewport()
	
func _tirar_hud_do_viewport() -> void:
	# No fundo 3D do MainMenu a casa é só visual — não joga o HUD na raiz
	# (isso fazia a crosshair aparecer no menu / loading / intro).
	if typeof(Global) != TYPE_NIL and Global.rodando_como_menu_bg:
		return
	var alvos = get_tree().get_nodes_in_group("reparentar_hud")
	for nodo in alvos:
		var pai_atual = nodo.get_parent()
		if pai_atual:
			pai_atual.remove_child(nodo)
		get_tree().root.call_deferred("add_child", nodo)
	call_deferred("_apos_reparentar", alvos)

func _apos_reparentar(alvos: Array) -> void:
	for nodo in alvos:
		if nodo.has_method("_atualizar_layout"):
			nodo._atualizar_layout()

func _debug_hud() -> void:
	print("HUD dentro da árvore? ", hud.is_inside_tree())
	print("HUD caminho: ", hud.get_path() if hud.is_inside_tree() else "SEM PAI")
	print("HUD pai: ", hud.get_parent())
	for filho in hud.get_children():
		print("-filho: ", filho.name, " | Tipo: ", filho.get_class())
		if filho is CanvasLayer:
			print("layer: ", filho.layer, " | visible: ", filho.visible)
	
func _physics_process(delta):
	if get_tree().paused:
		return
	
	if camera.inspecionando:
		return
	
	var dir = Vector3.ZERO
	if Input.is_action_pressed("w"): dir -= transform.basis.z
	if Input.is_action_pressed("s"): dir += transform.basis.z
	if Input.is_action_pressed("a"): dir -= transform.basis.x
	if Input.is_action_pressed("d"): dir += transform.basis.x
	dir.y = 0
	dir   = dir.normalized()

	var wants_to_sprint = Input.is_action_pressed("shift") and dir.length() > 0.1 and is_on_floor()
	is_sprinting        = wants_to_sprint and can_sprint and current_stamina > 0
	if wants_to_sprint and typeof(TutorialManager) != TYPE_NIL and TutorialManager.has_method("tutorial_correr"):
		TutorialManager.tutorial_correr()
	var mult_emocional  = camera.get_velocidade_mult() if camera and camera.has_method("get_velocidade_mult") else 1.0
	var current_speed   = (sprint_velocity if is_sprinting else velocity) * mult_emocional

	if is_on_floor():
		vel.y = 0.0
		_chao_grace = CHAO_GRACE_TEMPO
	else:
		_chao_grace = max(_chao_grace - delta, 0.0)

	vel.x  = dir.x * current_speed
	vel.z  = dir.z * current_speed
	vel.y += gravity * delta
	move_and_slide(vel, Vector3.UP)

	# Depois do move: se tocou o chão, renova o grace
	if is_on_floor():
		_chao_grace = CHAO_GRACE_TEMPO

	_handle_footsteps(delta, dir)
	_handle_stamina(delta, dir)

func _on_passos_finished() -> void:
	# Stream sem loop: se ainda está andando, toca de novo sem buraco
	if _quer_passos and passos:
		passos.play()

func _handle_footsteps(_delta: float, dir: Vector3) -> void:
	if not passos:
		return

	var input_andando = Vector3(dir.x, 0, dir.z).length() > 0.1
	# Usa velocidade real no chão (mais estável que só o input)
	var vel_horizontal = Vector3(vel.x, 0, vel.z).length()
	var no_chao = _chao_grace > 0.0
	_quer_passos = input_andando and no_chao and vel_horizontal > 0.15

	if _quer_passos:
		if not passos.playing:
			passos.play()
		var mult_emocional = camera.get_velocidade_mult() if camera and camera.has_method("get_velocidade_mult") else 1.0
		var pitch_base = 1.6 if is_sprinting else 1.0
		var pitch_alvo = pitch_base * mult_emocional
		# Só atualiza se mudou de verdade (evita glitch em alguns backends de áudio)
		if abs(passos.pitch_scale - pitch_alvo) > 0.02:
			passos.pitch_scale = pitch_alvo
	else:
		if passos.playing:
			passos.stop()

func _handle_stamina(delta: float, dir: Vector3):
	var andando = Vector3(dir.x, 0, dir.z).length() > 0.1

	if is_sprinting:
		current_stamina -= stamina_drain_rate * delta
		if current_stamina <= 0:
			current_stamina = 0
			is_sprinting    = false
			can_sprint      = false
	else:
		var regen_rate   = stamina_regen_rate_stopped if not andando else stamina_regen_rate
		current_stamina += regen_rate * delta
		if current_stamina >= max_stamina * 0.3:
			can_sprint = true

	current_stamina = clamp(current_stamina, 0, max_stamina)

func entrar_zona_luz() -> void:
	_zonas_luz_count += 1
	esta_na_luz = _zonas_luz_count > 0

func sair_zona_luz() -> void:
	_zonas_luz_count = max(_zonas_luz_count - 1, 0)
	esta_na_luz = _zonas_luz_count > 0

# SAVE DO PLAYER OTIMIZADO PARA INJEÇÃO DIRETA
func save():
	var lanterna_ligada = false
	if camera.lanterna_atual != null and "ligada" in camera.lanterna_atual:
		lanterna_ligada = camera.lanterna_atual.ligada
	return {
		"node_path"         : str(get_path()), # Usa o caminho do nó absoluto
		"pos_x"             : translation.x,
		"pos_y"             : translation.y,
		"pos_z"             : translation.z,
		"scale_x"           : scale.x,
		"scale_y"           : scale.y,
		"scale_z"           : scale.z,
		"current_stamina"   : current_stamina,
		"rot_x"             : rot_x,               # pitch (olhar cima/baixo), em graus
		"rot_y"             : camera.target_yaw,    # yaw (girar esquerda/direita), em radianos
		"inventory"         : Inventory.get_save_data() if Inventory.has_method("get_save_data") else [],
		"lanterna_equipada" : camera.lanterna_atual != null,
		"lanterna_ligada"   : lanterna_ligada,
		"fita_nome"         : camera.fita_nome,
		"fita_audio_path"   : (camera.fita_audio_path if ("fita_audio_path" in camera and str(camera.fita_audio_path) != "") else (camera.fita_audio.resource_path if camera.fita_audio else "")),
		"fita_texto"        : camera.fita_texto,
		"fita_cor_r"        : camera.fita_cor.r,
		"fita_cor_g"        : camera.fita_cor.g,
		"fita_cor_b"        : camera.fita_cor.b,
		"fita_cor_a"        : camera.fita_cor.a,
		"fita_e_calmante"   : camera.fita_e_calmante,
	}

# LOAD DO PLAYER — faltava esse método, por isso a posição/rotação
# não voltavam de fato ao carregar o save.
func load_data(data: Dictionary) -> void:
	if data.has("scale_x"):
		scale = Vector3(
			data.get("scale_x", scale.x),
			data.get("scale_y", scale.y),
			data.get("scale_z", scale.z)
		)

	current_stamina = data.get("current_stamina", current_stamina)

	var pitch_deg = data.get("rot_x", 0.0)
	var yaw_rad   = data.get("rot_y", 0.0)

	rot_x = pitch_deg
	rotation.y = yaw_rad # aplica o giro imediatamente no corpo do personagem

	# IMPORTANTE: a câmera controla sua própria rotação todo frame via
	# current_pitch/current_yaw (interpolados em _physics_process). Só
	# setar rotation_degrees de fora não funciona — precisa alinhar o
	# alvo E o valor atual, senão ela volta pro ângulo padrão sozinha.
	if camera:
		camera.target_pitch  = deg2rad(pitch_deg)
		camera.current_pitch = deg2rad(pitch_deg)
		camera.target_yaw    = yaw_rad
		camera.current_yaw   = yaw_rad

	# Restaura fita do inventário (nome + áudio) pro gravador funcionar após load
	if camera and str(data.get("fita_nome", "")) != "":
		camera.fita_nome = str(data.get("fita_nome", ""))
		camera.fita_texto = str(data.get("fita_texto", ""))
		camera.fita_e_calmante = bool(data.get("fita_e_calmante", false))
		camera.fita_cor = Color(
			float(data.get("fita_cor_r", 1.0)),
			float(data.get("fita_cor_g", 1.0)),
			float(data.get("fita_cor_b", 1.0)),
			float(data.get("fita_cor_a", 1.0))
		)
		var ap = str(data.get("fita_audio_path", ""))
		if "fita_audio_path" in camera:
			camera.fita_audio_path = ap
		if ap != "":
			var stream = load(ap)
			if stream:
				camera.fita_audio = stream
