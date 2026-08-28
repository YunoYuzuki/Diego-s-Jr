extends Node

# ==================== REFERÊNCIAS ====================
export(NodePath) var player_path = NodePath("Player")
export(NodePath) var vinheta_path = NodePath("../UI/Vinheta")
export(NodePath) var dialogue_label_path = NodePath("../UI/DialogueLabel")

onready var player = get_node(player_path)
onready var camera = player.get_node("Camera")
onready var vinheta = get_node(vinheta_path)
onready var dialogue_label = get_node(dialogue_label_path)

# ==================== CONFIGURAÇÃO DA TIMELINE ====================
enum Stage {
	START,
	EYES_OPENING,
	AWAKE_IDLE,
	LOOK_LEFT,
	LOOK_RIGHT,
	PUSH_UP,
	SITTING,
	OBSERVE,
	STAND_UP,
	BALANCE,
	END
}

var current_stage = Stage.START
var stage_timer = 0.0
var stage_duration = 0.0

# Sistema central de interpolação da câmera
var start_pos = Vector3()
var start_rot = Vector3()
var target_pos = Vector3()
var target_rot = Vector3()
var interp_progress = 0.0
var current_duration = 0.0
var current_ease = Tween.EASE_IN_OUT
var current_trans = Tween.TRANS_CUBIC

# Respiração (camada aditiva)
var breathing_intensity = 0.0
var breathing_time = 0.0

# Estado geral
var is_active = false
var mouse_mode_original = Input.MOUSE_MODE_VISIBLE

# ==================== TIMELINE DE ETAPAS ====================
var timeline = [
	# [Stage, duration, target_pos, target_rot, ease_type, trans_type, breathing_int]
	[Stage.EYES_OPENING, 4.0,  Vector3(0, 0.32, 0),   Vector3(22, 78, 72), Tween.EASE_OUT,   Tween.TRANS_CUBIC,   0.18],
	[Stage.AWAKE_IDLE,   3.5,  Vector3(0, 0.35, 0),   Vector3(19, 75, 65), Tween.EASE_IN_OUT, Tween.TRANS_SINE,    0.25],
	[Stage.LOOK_LEFT,    2.8,  Vector3(0, 0.38, 0),   Vector3(18, 48, 58), Tween.EASE_OUT,   Tween.TRANS_QUAD,    0.22],
	[Stage.LOOK_RIGHT,   3.2,  Vector3(0, 0.37, 0),   Vector3(21, 105, 52),Tween.EASE_OUT,   Tween.TRANS_QUAD,    0.20],
	[Stage.PUSH_UP,      5.5,  Vector3(0, 0.92, 0.08),Vector3(28, 55, 28), Tween.EASE_OUT,   Tween.TRANS_CUBIC,   0.35],
	[Stage.SITTING,      4.8,  Vector3(0, 1.45, 0.06),Vector3(14, 22, 11), Tween.EASE_OUT,   Tween.TRANS_QUAD,    0.28],
	[Stage.OBSERVE,      4.0,  Vector3(0, 1.48, 0.04),Vector3(12, 15, 8),  Tween.EASE_IN_OUT, Tween.TRANS_SINE,    0.22],
	[Stage.STAND_UP,     6.2,  Vector3(0, 1.82, 0.03),Vector3(7, 8, 5),    Tween.EASE_OUT,   Tween.TRANS_CUBIC,   0.30],
	[Stage.BALANCE,      2.8,  Vector3(0, 1.95, 0),   Vector3(2, 3, 2),    Tween.EASE_IN_OUT, Tween.TRANS_SINE,    0.15],
	[Stage.END,          1.5,  Vector3(0, 1.95, 0),   Vector3(0, 0, 0),    Tween.EASE_OUT,   Tween.TRANS_SINE,    0.0]
]

func _ready():
	if SaveManager.cutscene_inicial_vista:
		queue_free()
		return
	
	_setup_cutscene()


func _setup_cutscene():
	mouse_mode_original = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	
	if player.has_method("set_camera_control"):
		player.set_camera_control(false)
	
	vinheta.modulate.a = 1.0
	dialogue_label.visible = false
	
	# Posição inicial (deitada)
	camera.translation = Vector3(0, 0.32, 0)
	camera.rotation_degrees = Vector3(22, 78, 72)
	
	is_active = true
	current_stage = Stage.START
	_advance_to_next_stage()


func _process(delta):
	if not is_active:
		return
	
	stage_timer += delta
	breathing_time += delta
	
	# Atualiza interpolação principal
	_update_camera_interpolation(delta)
	
	# Respiração aditiva (nunca interfere na interpolação principal)
	_apply_breathing()
	
	# Avança estágio quando o tempo acabar
	if stage_timer >= stage_duration:
		_advance_to_next_stage()


func _update_camera_interpolation(delta):
	if current_duration <= 0:
		return
	
	interp_progress = min(interp_progress + delta / current_duration, 1.0)
	
	var t = _ease(interp_progress, current_ease, current_trans)
	
	camera.translation = start_pos.linear_interpolate(target_pos, t)
	camera.rotation_degrees = start_rot.linear_interpolate(target_rot, t)


func _apply_breathing():
	var breath = sin(breathing_time * 2.8) * 0.012 + sin(breathing_time * 6.1) * 0.006
	camera.translation.y += breath * breathing_intensity


func _advance_to_next_stage():
	stage_timer = 0.0
	interp_progress = 0.0
	
	var index = current_stage
	if index >= timeline.size():
		_finish_cutscene()
		return
	
	var step = timeline[index]
	
	current_stage = step[0]
	stage_duration = step[1]
	target_pos = step[2]
	target_rot = step[3]
	current_ease = step[4]
	current_trans = step[5]
	breathing_intensity = step[6]
	
	start_pos = camera.translation
	start_rot = camera.rotation_degrees
	
	# Eventos específicos por estágio
	match current_stage:
		Stage.EYES_OPENING:
			_clarear_vinheta(3.8, 0.78)
		Stage.OBSERVE:
			_clarear_vinheta(2.5, 0.15)
		Stage.BALANCE:
			_clarear_vinheta(2.0, 0.0)
		Stage.END:
			_show_dialogue()


func _ease(t: float, ease_type: int, trans_type: int) -> float:
	# Simulação simples de easing (pode usar Tween se preferir)
	match trans_type:
		Tween.TRANS_CUBIC:
			t = pow(t, 3) if ease_type == Tween.EASE_OUT else 1.0 - pow(1.0 - t, 3)
		Tween.TRANS_QUAD:
			t = t * t if ease_type == Tween.EASE_OUT else 1.0 - (1.0 - t) * (1.0 - t)
		Tween.TRANS_SINE:
			t = 1.0 - cos(t * PI * 0.5) if ease_type == Tween.EASE_OUT else sin(t * PI * 0.5)
	return t


func _clarear_vinheta(duration: float, target_alpha: float):
	var t = Tween.new()
	add_child(t)
	t.interpolate_property(vinheta, "modulate:a", vinheta.modulate.a, target_alpha, duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	t.start()
	t.connect("tween_completed", self, "_on_vinheta_tween_completed", [t])


func _on_vinheta_tween_completed(obj, key, tween):
	tween.queue_free()


func _show_dialogue():
	dialogue_label.visible = true
	var falas = ["...", "O que... aconteceu?", "Onde eu tô?"]
	for fala in falas:
		dialogue_label.text = fala
		yield(get_tree().create_timer(2.2), "timeout")
	_finish_cutscene()


func _finish_cutscene():
	is_active = false
	dialogue_label.visible = false
	vinheta.modulate.a = 0.0
	
	Input.set_mouse_mode(mouse_mode_original)
	player.set_physics_process(true)
	player.set_process_input(true)
	player.set_process_unhandled_input(true)
	
	if player.has_method("set_camera_control"):
		player.set_camera_control(true)
	
	SaveManager.cutscene_inicial_vista = true
	queue_free()
