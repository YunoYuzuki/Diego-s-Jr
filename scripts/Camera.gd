extends Camera

export(Color) var cor = Color.white
export(float) var tamanho = 1.5

#  Cassete 
var fita_tocando  : bool = false
var fita_audio    : AudioStream = null
var fita_nome     : String      = ""

onready var cassete_player = get_node("/root/Spatial/AudioStreamPlayer")
onready var cassete_ui     = $PostProcess/Cassette/CassetteUI
onready var cassete_nome   = $PostProcess/Cassette/CassetteUI/NomeFita
onready var msg_label      = $PostProcess/Cassette/MensagemLabel

export(AudioStream) var audio_fita

#  Hotbar 
var lanterna_atual = null

#  Mouse suave 
export(float) var mouse_sensitivity  = 0.002
export(float) var rotation_smoothing = 10.0

#  Head bobbing 
export(float) var bob_vert_amp     = 0.025
export(float) var bob_horiz_amp    = 0.012
export(float) var bob_roll_amp     = 0.008
export(float) var bob_freq         = 14.0
export(float) var bob_return_speed = 10.0

#  Idle 
export(float) var idle_bob_amp = 0.015
export(float) var idle_freq    = 2.0

#  Holder 
export(float) var holder_delay_time = 0.5
export(float) var holder_sway_amp   = 0.035

#  TutorialManager
var TutorialManager = null

#  Pause 
onready var pause_canvas  = $PauseCanvas
onready var pause_overlay = $PauseCanvas/PauseOverlay
onready var pause_label   = $PauseCanvas/PauseLabel

onready var pos_inicial = translation

var holder_base_trans = Vector3.ZERO
var holder_base_rot   = Vector3.ZERO

onready var ray       = $RayCast
onready var holder    = $Position3D
onready var gif_save  = $PostProcess/Control/gif_savegame
onready var crosshair = $CanvasLayer/CrosshairUI

var objeto_focado = null

#  Mouse 
var target_yaw    = 0.0
var current_yaw   = 0.0
var target_pitch  = 0.0
var current_pitch = 0.0

#  Bob 
var bob_time  = 0.0
var idle_time = 0.0

#  Holder offset 
var holder_target_offset  = Vector3.ZERO
var holder_current_offset = Vector3.ZERO
var holder_target_roll    = 0.0
var holder_current_roll   = 0.0

onready var hotbar_ui          = $CanvasLayer/HotbarContainer
onready var slot_icon          = $CanvasLayer/HotbarContainer/Slot1
onready var slot_highlight     = $CanvasLayer/HotbarContainer/Slot1/Highlight
onready var lanterna_icon_node = $CanvasLayer/HotbarContainer/Slot1/Highlight/LanternaIcon

export(Texture) var lanterna_icon

#  Stamina 
onready var stamina_bar  : ProgressBar = $CanvasLayer/StaminaBar
var stamina_alpha        : float = 0.0
var stamina_alpha_target : float = 0.0
var stamina_fade_speed   : float = 8.0

# 
func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process_input(true)
	add_to_group("camera_player")
	TutorialManager = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	holder_base_trans = holder.translation
	holder_base_rot   = holder.rotation

	if slot_icon:
		slot_icon.visible   = true
		slot_icon.texture   = lanterna_icon
		slot_icon.rect_size = Vector2(80, 80)

	if lanterna_icon_node:
		lanterna_icon_node.visible = false

	if stamina_bar:
		stamina_bar.visible    = true
		stamina_bar.max_value  = get_parent().max_stamina
		stamina_bar.value      = get_parent().current_stamina
		stamina_bar.modulate.a = 0.0

	if pause_canvas:
		pause_canvas.visible  = false
		pause_overlay.visible = false
		pause_label.visible   = false

	cassete_ui.visible = false
	msg_label.visible  = false

	SaveManager.connect("jogo_salvo", self, "_mostrar_salvo")
	gif_save.modulate.a = 0.0

# 
func _input(event):
	#  Mouse 
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		target_yaw   -= event.relative.x * mouse_sensitivity
		target_pitch -= event.relative.y * mouse_sensitivity
		target_pitch  = clamp(target_pitch, -1.48, 1.48)

		var mouse_vel = event.relative * 0.001
		holder_target_offset.x = -mouse_vel.x * holder_sway_amp
		holder_target_offset.y = -mouse_vel.y * holder_sway_amp * 0.7
		holder_target_roll     = -mouse_vel.x * 0.02

# 
func _physics_process(delta):
	atualizar_foco()

	if get_tree().paused:
		return

	if Input.is_action_just_pressed("e"):
		_interagir()

	if Input.is_action_just_pressed("f") and lanterna_atual:
		lanterna_atual.alternar()

	#  Rotação da câmera 
	current_yaw   = lerp_angle(current_yaw,   target_yaw,   rotation_smoothing * delta)
	current_pitch = lerp_angle(current_pitch, target_pitch, rotation_smoothing * delta)
	get_parent().rotation.y = current_yaw
	get_parent().rot_x = rad2deg(current_pitch)

	#  Bobbing 
	var movendo = Input.is_action_pressed("w") or Input.is_action_pressed("a") \
			   or Input.is_action_pressed("d") or Input.is_action_pressed("s")

	var bob_offset = Vector3.ZERO
	var bob_roll   = 0.0

	if movendo:
		bob_time     += delta * bob_freq
		bob_offset.y  = sin(bob_time)       * bob_vert_amp
		bob_offset.x  = cos(bob_time * 0.5) * bob_horiz_amp
		bob_roll      = sin(bob_time * 0.5) * bob_roll_amp
		idle_time     = 0.0
	else:
		idle_time    += delta
		bob_offset.y  = sin(idle_time * idle_freq) * idle_bob_amp
		bob_time      = 0.0

	var target_cam_trans = pos_inicial + bob_offset
	translation = translation.linear_interpolate(target_cam_trans, bob_return_speed * delta)

	var bob_roll_suave = lerp_angle(rotation.z, bob_roll, bob_return_speed * delta)
	rotation = Vector3(current_pitch, 0.0, bob_roll_suave)

	#  Holder sway 
	var weight = 1.0 - exp(-delta / holder_delay_time)
	holder_current_offset = holder_current_offset.linear_interpolate(holder_target_offset, weight)
	holder_current_roll   = lerp_angle(holder_current_roll, holder_target_roll, weight)

	holder.translation = holder_base_trans + holder_current_offset
	holder.rotation    = holder_base_rot
	holder.rotation.z += holder_current_roll

	if holder_target_offset.length() < 0.001:
		holder_current_offset = holder_current_offset.linear_interpolate(Vector3.ZERO, weight * 2.0)
		holder_current_roll   = lerp_angle(holder_current_roll, 0.0, weight * 2.0)

	#  Stamina UI 
	if stamina_bar:
		var player           = get_parent()
		stamina_bar.value    = player.current_stamina
		var should_show      = player.is_sprinting or player.current_stamina < player.max_stamina
		stamina_alpha_target = 1.0 if should_show else 0.0
		stamina_alpha        = lerp(stamina_alpha, stamina_alpha_target, stamina_fade_speed * delta)
		stamina_bar.modulate.a = stamina_alpha

	update_hotbar_ui()

# 
func pause_game():
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if pause_canvas:
		pause_canvas.visible  = true
		pause_overlay.visible = true
		pause_label.visible   = true

func unpause_game():
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if pause_canvas:
		pause_canvas.visible  = false
		pause_overlay.visible = false
		pause_label.visible   = false

# 
func _interagir():
	if ray.is_colliding():
		var alvo = _resolver_alvo(ray.get_collider())
		if alvo.is_in_group("interagivel") and alvo.has_method("interagir"):
			alvo.interagir(self)

func atualizar_foco():
	if objeto_focado and is_instance_valid(objeto_focado):
		objeto_focado.set_foco(false)
		objeto_focado = null

	if ray.is_colliding():
		var alvo = _resolver_alvo(ray.get_collider())
		if alvo and is_instance_valid(alvo) and alvo.has_method("set_foco"):
			objeto_focado = alvo
			objeto_focado.set_foco(true)
			crosshair.set_foco(true)
			_call_tutorial("tutorial_interagir")
			return

	crosshair.set_foco(false)

func _resolver_alvo(alvo) -> Node:
	if alvo is Area and alvo.has_meta("door_parent"):
		return alvo.get_meta("door_parent")
	return alvo

#  Hotbar 
func pegar_lanterna(lanterna):
	if lanterna.get_parent():
		lanterna.get_parent().remove_child(lanterna)
	lanterna.set_foco(false)
	_call_tutorial("tutorial_lanterna")
	_call_tutorial("tutorial_inventario")
	lanterna_atual = lanterna
	_colocar_no_holder(lanterna_atual)
	update_hotbar_ui()
	if lanterna_icon_node:
		lanterna_icon_node.visible = true

func _colocar_no_holder(item):
	if item and not holder.is_a_parent_of(item):
		var col = item.get_node_or_null("CollisionShape")
		if col:
			col.disabled = true
		if item.get_parent():
			item.get_parent().remove_child(item)
		holder.add_child(item)
		item.translation = Vector3.ZERO
		item.rotation    = Vector3.ZERO
		item.scale       = Vector3.ONE

func update_hotbar_ui():
	if slot_icon:
		slot_icon.rect_scale = Vector2(1.2, 1.2)
	if slot_highlight:
		slot_highlight.visible = true

#  Cassete 
func pegar_fita(fita):
	var audio_temp = fita.audio_fita
	var nome_temp  = fita.nome_fita
	Inventory.add_item("fita_cassete")
	_call_tutorial("tutorial_inventario")
	fita.queue_free()
	fita_audio = audio_temp
	fita_nome  = nome_temp

func mostrar_cassete_ui(nome: String):
	cassete_nome.text  = nome
	cassete_ui.visible = true

func esconder_cassete_ui():
	cassete_ui.visible = false

func _mostrar_mensagem(texto: String):
	msg_label.text       = texto
	msg_label.visible    = true
	msg_label.modulate.a = 1.0

	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(msg_label, "modulate:a", 1.0, 0.0, 1.0,
		Tween.TRANS_LINEAR, Tween.EASE_IN, 2.0)
	tween.start()
	yield(tween, "tween_all_completed")
	msg_label.visible = false
	tween.queue_free()

func _mostrar_salvo():
	gif_save.modulate.a = 1.0
	gif_save.frame = 0
	gif_save.play("New Anim")
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(gif_save, "modulate:a", 1.0, 0.0, 2.0,
		Tween.TRANS_LINEAR, Tween.EASE_IN, 1.5)
	tween.start()
	yield(tween, "tween_all_completed")
	tween.queue_free()

func _call_tutorial(method: String) -> void:
	var managers = get_tree().get_nodes_in_group("tutorial_manager")
	for manager in managers:
		if is_instance_valid(manager) and manager.has_method(method):
			manager.call(method)
			return
