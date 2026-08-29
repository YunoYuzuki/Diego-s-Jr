extends Camera

export(Color) var cor = Color.white
export(float) var tamanho = 1.5

#  Audio Emocoes
export(AudioStream) var audio_respiracao
export(AudioStream) var audio_emocional

onready var respiracao_player := AudioStreamPlayer.new()
onready var emocional_player := AudioStreamPlayer.new()

#  Lanterna
onready var som_lanterna = $som_lanterna

#  Cassete 
var fita_tocando  : bool = false
var fita_audio    : AudioStream = null
var fita_nome     : String      = ""
var fita_texto    : String      = ""
var fita_cor      : Color       = Color(1, 1, 1, 1)

var cassete_player = null
onready var cassete_ui     = $hud/Cassette/CassetteUI
onready var cassete_nome   = $hud/Cassette/CassetteUI/NomeFita
onready var msg_label      = $hud/Cassette/MensagemLabel

#  Hotbar 
var lanterna_atual = null

#  Mouse suave 
export(float) var mouse_sensitivity_base  = 0.003
var mouse_sensitivity = 0.003
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

#  Pause 
onready var pause_canvas  = $hud/PauseCanvas
onready var pause_overlay = $hud/PauseCanvas/PauseOverlay
onready var pause_label   = $hud/PauseCanvas/PauseLabel

onready var pos_inicial = translation

var holder_base_trans = Vector3.ZERO
var holder_base_rot   = Vector3.ZERO

onready var ray       = $RayCast
onready var holder    = $Position3D
onready var gif_save  = $hud/Control/gif_savegame
onready var crosshair = $hud/CanvasLayer/CrosshairUI

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

onready var hotbar_ui          = $hud/CanvasLayer/HotbarContainer
onready var slot_icon          = $hud/CanvasLayer/HotbarContainer/Slot1
onready var slot_highlight     = $hud/CanvasLayer/HotbarContainer/Slot1/Highlight
onready var lanterna_icon_node = $hud/CanvasLayer/HotbarContainer/Slot1/Highlight/LanternaIcon

#  Stamina 
onready var stamina_bar  : ProgressBar = $hud/CanvasLayer/StaminaBar
var stamina_alpha        : float = 0.0
var stamina_alpha_target : float = 0.0
var stamina_fade_speed   : float = 8.0

#  Inspeção
export(NodePath) var caminho_ponto_inspecao
onready var ponto_inspecao = get_node(caminho_ponto_inspecao) if caminho_ponto_inspecao else null
export var sensibilidade_rotacao_inspecao := 0.0005

var inspecionando := false
var objeto_inspecionado = null
var pai_original_inspecao = null
var transform_original_inspecao : Transform
var modo_fisico_original_inspecao = null

export var limite_rotacao_horizontal := deg2rad(70) # quanto pode virar pros lados
export var limite_rotacao_vertical   := deg2rad(15) # bem pouco, só leve inclinação

var rotacao_inspecao_x := 0.0
var rotacao_inspecao_y := 0.0

var animando_inspecao := false
onready var tween_inspecao := Tween.new()

var pivot_rotation_original := Vector3.ZERO

#  Emoção (vida emocional da Laura) 
enum Emocao { CALMA, COM_MEDO, ASSUSTADA, EM_CRISE }
var emocao_atual : int = Emocao.CALMA

export var crise_ramp_tempo       : float = 22.0  # segundos até o efeito máximo dentro da crise
export var crise_ramp_volume_max  : float = 10.0   # dB extras no auge (mais alto)
export var crise_ramp_pitch_max   : float = 0.30   # pitch extra no auge

var _tempo_em_crise : float = 0.0

var _tutorial_emocao_ja_mostrado := false
const CENA_TUTORIAL_EMOCAO = preload("res://scenes/Emotion_Tutorial.tscn") 

const NOMES_EMOCAO = {
	Emocao.CALMA:     "Calma",
	Emocao.COM_MEDO:  "Com Medo",
	Emocao.ASSUSTADA: "Assustada",
	Emocao.EM_CRISE:  "Em Crise",
}

# valores-alvo do shader pra cada emoção
const SHADER_POR_EMOCAO = {
	Emocao.CALMA:     {"static_intensity": 0.012, "brilho": 0.97, "vignette_size": 0.28},
	Emocao.COM_MEDO:  {"static_intensity": 0.045, "brilho": 0.86, "vignette_size": 0.40},
	Emocao.ASSUSTADA: {"static_intensity": 0.085, "brilho": 0.72, "vignette_size": 0.58},
	Emocao.EM_CRISE:  {"static_intensity": 0.170, "brilho": 0.48, "vignette_size": 0.88},
}

# Volumes do drone emocional — crise bem mais alta / presente
# O volume real também leva a tensão em conta (ver _atualizar_emocao).
const EMOCIONAL_AUDIO_POR_EMOCAO = {
	Emocao.CALMA:     -80.0,
	Emocao.COM_MEDO:  -20.0,
	Emocao.ASSUSTADA: -10.0,
	Emocao.EM_CRISE:   2.0,    # bem mais alto na crise
}

const VELOCIDADE_MULT_POR_EMOCAO = {
	Emocao.CALMA:     1.0,
	Emocao.COM_MEDO:  0.92,
	Emocao.ASSUSTADA: 0.80,
	Emocao.EM_CRISE:  0.65,
}

var _velocidade_mult_atual : float = 1.0

const RESPIRACAO_MULT_POR_EMOCAO = {
	Emocao.CALMA:     {"amp": 1.0, "freq": 1.0, "tremor": 0.0},
	Emocao.COM_MEDO:  {"amp": 1.5, "freq": 1.3, "tremor": 0.0015},
	Emocao.ASSUSTADA: {"amp": 2.1, "freq": 1.7, "tremor": 0.0035},
	Emocao.EM_CRISE:  {"amp": 3.0, "freq": 2.2, "tremor": 0.0060},
}

var idle_bob_amp_base   : float
var idle_freq_base      : float
var _idle_bob_amp_din   : float
var _idle_freq_din      : float
var _idle_tremor_din    : float = 0.0

export var respiracao_pitch_calma  : float = 0.65  # respiração bem mais lenta em repouso
export var respiracao_pitch_crise  : float = 1.28
export var respiracao_vol_silencio : float = -55.0  # quase muda; respiração principal fica na Sombra
export var respiracao_vol_crise    : float = -18.0  # mais alto na crise
export var respiracao_transicao_speed : float = 0.25  # mais lento que o resto, pra "desacelerar" percebido

export var emocao_transicao_speed : float = 0.6

onready var tween_emocao_label = Tween.new()
export var emocao_fade_duracao : float = 0.6

onready var emocao_label = $hud/Emocao/EmocaoLabel
var _emocao_timer := Timer.new()
var _emocao_delay_inicial := Timer.new()
var _emocao_liberada := false
onready var post_process_material : ShaderMaterial = $hud/PostProcess/ColorRect.material if $hud/PostProcess/ColorRect.material is ShaderMaterial else null

export(float) var tempo_acalmar = 12.0
export(float) var tempo_subir = 3.0

var emocao_alvo : int = Emocao.CALMA
var _tempo_alvo_estavel : float = 0.0      # espera antes do alvo baixar
var _tempo_transicao_estado : float = 0.0  # espera antes da emoção atual alcançar o alvo
var _emocao_anterior : int = Emocao.CALMA

var sombra_ref = null
var _jumpscare_ativo := false
var fita_e_calmante : bool = false

export var emocao_label_duracao : float = 5.0

export var fadiga_duracao : float = 8.0   # segundos pra fadiga cair de 1.0 até 0.0

var _fadiga_atual     : float = 0.0
var _stamina_anterior : float = 0.0

export var respiracao_pitch_fadiga : float = 1.0  # mais baixo que o de crise (1.20)



func _ready():
	add_child(tween_inspecao)
	add_child(tween_emocao_label)
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process_input(true)

	# No fundo 3D do MainMenu a casa é instanciada só pra visual.
	# Não entra no grupo camera_player pra o InputManager não achar
	# e não permitir pause nas telas de menu/intro.
	var como_menu_bg = typeof(Global) != TYPE_NIL and Global.rodando_como_menu_bg
	if not como_menu_bg:
		add_to_group("camera_player")
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_garantir_listener_3d()
	
	mouse_sensitivity = mouse_sensitivity_base * SaveManager.sensibilidade_mouse

	holder_base_trans = holder.translation
	holder_base_rot   = holder.rotation

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
		
	if get_parent():
		_stamina_anterior = get_parent().current_stamina

	cassete_ui.visible = false
	msg_label.visible  = false

	# Fundo do menu / intro: esconde crosshair e HUD de gameplay
	# hud.gd extends Node (não tem .visible) — esconde os CanvasItem filhos
	if como_menu_bg:
		if crosshair:
			crosshair.visible = false
		if hotbar_ui:
			hotbar_ui.visible = false
		if stamina_bar:
			stamina_bar.visible = false
		var hud_node = get_node_or_null("hud")
		if hud_node:
			_esconder_canvas_recursivo(hud_node)

	SaveManager.connect("jogo_salvo", self, "_mostrar_salvo")
	gif_save.modulate.a = 0.0
	
	var cassetes = get_tree().get_nodes_in_group("cassette_player")
	if cassetes.size() > 0:
		cassete_player = cassetes[0]
			
	var sombras = get_tree().get_nodes_in_group("sombra")
	if sombras.size() > 0:
		sombra_ref = sombras[0]

	if emocao_label:
		emocao_label.text = NOMES_EMOCAO[emocao_atual]
		emocao_label.visible = false
		emocao_label.modulate.a = 0.0

	_emocao_timer.one_shot = true
	_emocao_timer.wait_time = emocao_label_duracao
	add_child(_emocao_timer)
	_emocao_timer.connect("timeout", self, "_on_emocao_timer_timeout")

	_emocao_delay_inicial.one_shot = true
	_emocao_delay_inicial.wait_time = 20.0
	add_child(_emocao_delay_inicial)
	_emocao_delay_inicial.connect("timeout", self, "_on_emocao_liberada")
	_emocao_delay_inicial.start()

	# Se o tutorial de emoção já foi visto num save anterior, não mostra de novo.
	# Usa o Autoload de verdade (antes tinha um var local null que sombreava).
	var tm = _get_tutorial_manager()
	if tm != null and tm.emocao_mostrado:
		_tutorial_emocao_ja_mostrado = true
	
	idle_bob_amp_base = idle_bob_amp
	idle_freq_base    = idle_freq
	_idle_bob_amp_din = idle_bob_amp
	_idle_freq_din    = idle_freq
	
	respiracao_player.stream = audio_respiracao
	respiracao_player.volume_db = -80.0  # desligada: respiração agora é da Sombra
	respiracao_player.pitch_scale = respiracao_pitch_calma
	add_child(respiracao_player)
	# Respiração contínua da câmera DESLIGADA — a Sombra toca quando aparece
	# respiracao_player.connect("finished", self, "_on_respiracao_finished")
	# if audio_respiracao:
	# 	respiracao_player.play()

	emocional_player.stream = audio_emocional
	emocional_player.volume_db = -80.0
	add_child(emocional_player)
	if audio_emocional:
		emocional_player.play()
# 
func _on_respiracao_finished() -> void:
	respiracao_player.play()

func _input(event):
	if inspecionando:
		if event is InputEventMouseMotion and not animando_inspecao:
			rotacao_inspecao_y -= event.relative.x * sensibilidade_rotacao_inspecao
			rotacao_inspecao_x = clamp(
				rotacao_inspecao_x - event.relative.y * sensibilidade_rotacao_inspecao,
				-limite_rotacao_vertical, limite_rotacao_vertical
			)
			_aplicar_rotacao_inspecao()
		return

	# Clique esquerdo também interage (mouse capturado, jogo rodando)
	# InputEventMouseButton não tem .echo no Godot 3
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == BUTTON_LEFT \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED \
			and not get_tree().paused \
			and not _cartas_ui_aberta():
		_interagir()
		get_tree().set_input_as_handled()
		return

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
func _cartas_ui_aberta() -> bool:
	# get() é seguro no Godot 3 — "x" in obj quebra se o autoload ainda for null
	if typeof(CartasUI) != TYPE_NIL and is_instance_valid(CartasUI):
		if CartasUI.get("esta_aberta") == true:
			return true
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("cartas_ui"):
		if is_instance_valid(n) and n.get("esta_aberta") == true:
			return true
	return false


func _physics_process(delta):
	#  Bobbing 
	var bloqueado = bool(get_parent().get("bloqueado_por_colisao"))
	var movendo = (Input.is_action_pressed("w") or Input.is_action_pressed("a") \
			   or Input.is_action_pressed("d") or Input.is_action_pressed("s")) and not bloqueado

	var bob_offset = Vector3.ZERO
	var bob_roll   = 0.0
	atualizar_foco()

	if inspecionando:
		# Mantém a câmera do overlay alinhada com a principal (mesmo FOV/posição)
		if _inspecao_overlay_ativo:
			_sincronizar_cam_inspecao()
		return
		
	if get_tree().paused:
		return

	# Lendo carta: congela input/movimento sem pausar a árvore
	if _cartas_ui_aberta():
		return

	if Input.is_action_just_pressed("e"):
		_interagir()

	if Input.is_action_just_pressed("f") and lanterna_atual:
		lanterna_atual.alternar()
		# Antes: play() + stop() no mesmo frame → som nunca tocava
		if som_lanterna:
			som_lanterna.play()

	#  Rotação da câmera (original — sem delay de corpo)
	current_yaw   = lerp_angle(current_yaw,   target_yaw,   rotation_smoothing * delta)
	current_pitch = lerp_angle(current_pitch, target_pitch, rotation_smoothing * delta)
	get_parent().rotation.y = current_yaw
	if "rot_x" in get_parent():
		get_parent().rot_x = rad2deg(current_pitch)

	if movendo:
		var sprint_mult = 1.6 if get_parent().is_sprinting else 1.0
		bob_time     += delta * bob_freq * sprint_mult
		bob_offset.y  = sin(bob_time)       * bob_vert_amp * sprint_mult
		bob_offset.x  = cos(bob_time * 0.5) * bob_horiz_amp * sprint_mult
		bob_roll      = sin(bob_time * 0.5) * bob_roll_amp
		idle_time     = 0.0
	else:
		idle_time    += delta
		bob_offset.y  = sin(idle_time * _idle_freq_din) * _idle_bob_amp_din
		if _idle_tremor_din > 0.0:
			bob_offset.x += (randf() - 0.5) * _idle_tremor_din
			bob_offset.y += (randf() - 0.5) * _idle_tremor_din * 0.6
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
	_atualizar_emocao(delta)

# Emocoes
func _atualizar_emocao(delta: float) -> void:
	var player = get_parent()
	if player:
		if _stamina_anterior > 0.0 and player.current_stamina <= 0.0:
			_fadiga_atual = 1.0
		_stamina_anterior = player.current_stamina
	_fadiga_atual = max(_fadiga_atual - delta / fadiga_duracao, 0.0)

	if not sombra_ref:
		var sombras = get_tree().get_nodes_in_group("sombra")
		if sombras.size() > 0:
			sombra_ref = sombras[0]
		else:
			return

	# Alívio de tensão ANTES de calcular a emoção, pra a luz reagir no mesmo frame
	var na_luz = player != null and player.esta_na_luz
	if na_luz:
		# ~20 pts/s → em 5s a tensão some quase toda
		sombra_ref.aliviar_tensao(delta * 20.0)
	# cassete_player pode ser o Gravador (StaticBody) — não tem .playing
	if _cassete_calmante_tocando():
		sombra_ref.aliviar_tensao(delta * 12.0)

	var tensao = sombra_ref.get_tensao()
	var tensao_max = sombra_ref.get_tensao_max()
	var pct = tensao / tensao_max if tensao_max > 0 else 0.0

	# Na luz o alvo emocional também fica mais generoso (precisa de mais tensão pra subir)
	var limiar_medo   = 0.35 if not na_luz else 0.50
	var limiar_assust = 0.55 if not na_luz else 0.70
	var limiar_crise  = 0.80 if not na_luz else 0.90

	var nova_emocao_alvo = Emocao.CALMA
	if pct >= limiar_crise:
		nova_emocao_alvo = Emocao.EM_CRISE
	elif pct >= limiar_assust:
		nova_emocao_alvo = Emocao.ASSUSTADA
	elif pct >= limiar_medo:
		nova_emocao_alvo = Emocao.COM_MEDO

	# Tempo efetivo de acalmar: na luz é bem mais rápido
	var tempo_acalmar_efetivo = tempo_acalmar * (0.12 if na_luz else 1.0)

	# Tensão subiu → medo entra rápido
	if nova_emocao_alvo > emocao_alvo:
		emocao_alvo = nova_emocao_alvo
		_tempo_alvo_estavel = 0.0
	# Tensão baixou → espera um pouco estável antes de baixar o alvo
	elif nova_emocao_alvo < emocao_alvo:
		_tempo_alvo_estavel += delta
		if _tempo_alvo_estavel >= tempo_acalmar_efetivo:
			emocao_alvo = nova_emocao_alvo
			_tempo_alvo_estavel = 0.0
	else:
		_tempo_alvo_estavel = 0.0

	# Transição da emoção atual → alvo
	if emocao_atual != emocao_alvo:
		var subindo = emocao_alvo > emocao_atual
		# Descer é um pouco mais lento que subir, mas usa o tempo efetivo
		_tempo_transicao_estado += delta * (1.0 if subindo else 0.8)

		var limiar_transicao = tempo_subir if subindo else tempo_acalmar_efetivo
		if _tempo_transicao_estado >= limiar_transicao:
			_emocao_anterior = emocao_atual
			emocao_atual = emocao_alvo
			_tempo_transicao_estado = 0.0
			# Mostra o label se já liberou OU se subiu acima de Calma
			if emocao_label and (_emocao_liberada or emocao_atual != Emocao.CALMA):
				emocao_label.text = NOMES_EMOCAO[emocao_atual]
				_mostrar_emocao_com_fade()
	else:
		_tempo_transicao_estado = 0.0

	if post_process_material and not _jumpscare_ativo:
		var alvo  = SHADER_POR_EMOCAO[emocao_atual]
		var fator = 1.0 - exp(-emocao_transicao_speed * delta)
		for chave in alvo.keys():
			var atual = post_process_material.get_shader_param(chave)
			var novo  = lerp(atual, alvo[chave], fator)
			post_process_material.set_shader_param(chave, novo)

		# Depois da emoção, aplica peso extra se a Sombra estiver presente
		_aplicar_blend_sombra_no_shader(delta)

		var mult_alvo = VELOCIDADE_MULT_POR_EMOCAO[emocao_atual]
		_velocidade_mult_atual = lerp(_velocidade_mult_atual, mult_alvo, fator)

		# Respiração / bobbing acompanhando a emoção
		var mult = RESPIRACAO_MULT_POR_EMOCAO[emocao_atual]
		_idle_bob_amp_din = lerp(_idle_bob_amp_din, idle_bob_amp_base * mult["amp"], fator)
		_idle_freq_din    = lerp(_idle_freq_din,    idle_freq_base    * mult["freq"], fator)
		_idle_tremor_din  = lerp(_idle_tremor_din,  mult["tremor"], fator)

		if emocao_atual == Emocao.EM_CRISE:
			_tempo_em_crise += delta
		else:
			_tempo_em_crise = 0.0
		var progresso_crise = clamp(_tempo_em_crise / crise_ramp_tempo, 0.0, 1.0)

		# Respiração: usa o maior entre tensão e fadiga (cai assim que a tensão cai)
		var intensidade_resp = max(pct, _fadiga_atual)
		var fator_resp = 1.0 - exp(-respiracao_transicao_speed * delta)

		var pitch_alvo_resp = lerp(respiracao_pitch_calma, respiracao_pitch_crise, intensidade_resp)
		var vol_alvo_resp = respiracao_vol_silencio if intensidade_resp < 0.03 \
			else lerp(respiracao_vol_silencio, respiracao_vol_crise, intensidade_resp)

		if emocao_atual == Emocao.EM_CRISE:
			vol_alvo_resp   += progresso_crise * crise_ramp_volume_max
			pitch_alvo_resp += progresso_crise * crise_ramp_pitch_max

		# Respiração da câmera permanece muda (a da Sombra cuida da presença)
		respiracao_player.volume_db = -80.0
		# respiracao_player.volume_db   = lerp(respiracao_player.volume_db, vol_alvo_resp, fator_resp)
		# respiracao_player.pitch_scale = lerp(respiracao_player.pitch_scale, pitch_alvo_resp, fator_resp)

		# Áudio emocional: mistura o volume da emoção com a tensão real.
		# Assim o drone some quando a tensão cai, mesmo antes do enum virar CALMA.
		var vol_enum = EMOCIONAL_AUDIO_POR_EMOCAO[emocao_atual]
		if emocao_atual == Emocao.EM_CRISE:
			vol_enum += progresso_crise * crise_ramp_volume_max
		# Interpola entre silêncio (-80) e o volume da emoção conforme a tensão
		var vol_alvo_emo = lerp(-80.0, vol_enum, clamp(pct * 1.35, 0.0, 1.0))
		# Na luz, força o volume a cair mais rápido ainda
		if na_luz:
			vol_alvo_emo = min(vol_alvo_emo, lerp(-80.0, vol_enum, 0.35))
		emocional_player.volume_db = lerp(emocional_player.volume_db, vol_alvo_emo, fator)
		
func get_velocidade_mult() -> float:
	return _velocidade_mult_atual

# =============================================================
# API pública — Estado emocional da Laura (para a Sombra e outros)
# =============================================================
func get_emocao() -> int:
	return emocao_atual

func get_emocao_nome() -> String:
	return NOMES_EMOCAO.get(emocao_atual, "Calma")

func esta_em_crise() -> bool:
	return emocao_atual == Emocao.EM_CRISE

func esta_assustada_ou_pior() -> bool:
	return emocao_atual >= Emocao.ASSUSTADA

## Chamado pela Sombra no impacto da caçada / investida pesada.
## Joga Laura direto em crise (sem esperar a tensão subir aos poucos).
func forcar_crise() -> void:
	emocao_alvo = Emocao.EM_CRISE
	emocao_atual = Emocao.EM_CRISE
	_tempo_em_crise = max(_tempo_em_crise, crise_ramp_tempo * 0.35)
	# Já passou por emoções fortes — tutorial de emoção não deve reaparecer depois
	_tutorial_emocao_ja_mostrado = true
	var tm = _get_tutorial_manager()
	if tm != null:
		tm.emocao_mostrado = true
	if emocao_label:
		emocao_label.text = NOMES_EMOCAO[Emocao.EM_CRISE]
		emocao_label.visible = true
		emocao_label.modulate.a = 1.0
		if _emocao_timer:
			_emocao_timer.start()
	# Empurra o volume emocional pra cima na hora
	if emocional_player:
		var vol = EMOCIONAL_AUDIO_POR_EMOCAO[Emocao.EM_CRISE]
		emocional_player.volume_db = max(emocional_player.volume_db, vol - 4.0)
	print("😰 Laura FORÇADA em crise")

func get_progresso_crise() -> float:
	if emocao_atual != Emocao.EM_CRISE:
		return 0.0
	return clamp(_tempo_em_crise / crise_ramp_tempo, 0.0, 1.0)

# =============================================================
# Atmosfera da Sombra — só quando o jogador ESTÁ VENDO ela
# Leve escurecimento + saturação maior; entra/sai devagar
# =============================================================
var _sombra_visivel_agora : bool = false
var _sombra_peso_suave : float = 0.0
# Alvos SUTIS (não deixa a tela preta)
export var sombra_brilho_alvo : float = 0.88
export var sombra_saturacao_alvo : float = 1.35
export var sombra_vignette_alvo : float = 0.38
export var sombra_static_alvo : float = 0.03
# Velocidade de fade (menor = mais lento). ~0.7 ≈ alguns segundos
export var sombra_atmosfera_speed : float = 0.65
export var sombra_atmosfera_speed_saida : float = 0.9

## Chamado pela Sombra todo frame: true só se ela está ativa E no FOV do player
func set_sombra_visivel(visivel: bool) -> void:
	_sombra_visivel_agora = visivel

## Compat: true = pede presença, false = tira (a visibilidade real decide no blend)
func aplicar_atmosfera_sombra(ativa: bool) -> void:
	if not ativa:
		_sombra_visivel_agora = false

func _aplicar_blend_sombra_no_shader(delta: float) -> void:
	if not post_process_material or _jumpscare_ativo:
		return

	var alvo_p = 1.0 if _sombra_visivel_agora else 0.0
	var spd = sombra_atmosfera_speed if alvo_p > _sombra_peso_suave else sombra_atmosfera_speed_saida
	_sombra_peso_suave = lerp(_sombra_peso_suave, alvo_p, 1.0 - exp(-spd * delta))

	if _sombra_peso_suave < 0.01:
		_sombra_peso_suave = 0.0
		return

	var p = _sombra_peso_suave
	# Blend leve em cima dos valores já setados pela emoção
	var b = post_process_material.get_shader_param("brilho")
	var sat = post_process_material.get_shader_param("saturacao")
	var v = post_process_material.get_shader_param("vignette_size")
	var st = post_process_material.get_shader_param("static_intensity")

	if b != null:
		post_process_material.set_shader_param("brilho", lerp(float(b), sombra_brilho_alvo, p * 0.55))
	if sat != null:
		post_process_material.set_shader_param("saturacao", lerp(float(sat), sombra_saturacao_alvo, p * 0.70))
	if v != null:
		post_process_material.set_shader_param("vignette_size", lerp(float(v), sombra_vignette_alvo, p * 0.40))
	if st != null:
		post_process_material.set_shader_param("static_intensity", lerp(float(st), sombra_static_alvo, p * 0.25))

func jumpscare_escurecer(duracao_escuro: float = 1.0, duracao_retorno: float = 2.5) -> void:
	if not post_process_material or _jumpscare_ativo:
		return
	_jumpscare_ativo = true

	var tween = Tween.new()
	add_child(tween)

	tween.interpolate_property(post_process_material, "shader_param/brilho",
		post_process_material.get_shader_param("brilho"), 0.0, 0.12,
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(post_process_material, "shader_param/static_intensity",
		post_process_material.get_shader_param("static_intensity"), 0.0, 0.12,
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(post_process_material, "shader_param/grain",
		post_process_material.get_shader_param("grain"), 0.0, 0.12,
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")

	yield(get_tree().create_timer(duracao_escuro), "timeout")

	# Volta gradual pro padrão da emoção atual (grain volta pro valor base do shader)
	var alvo = SHADER_POR_EMOCAO[emocao_atual]
	tween.interpolate_property(post_process_material, "shader_param/brilho",
		post_process_material.get_shader_param("brilho"), alvo["brilho"], duracao_retorno,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	tween.interpolate_property(post_process_material, "shader_param/static_intensity",
		post_process_material.get_shader_param("static_intensity"), alvo["static_intensity"], duracao_retorno,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	tween.interpolate_property(post_process_material, "shader_param/grain",
		post_process_material.get_shader_param("grain"), 0.012, duracao_retorno,
		Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	tween.queue_free()

	_jumpscare_ativo = false
	

func pause_game():
	# Segurança extra: nunca pausar no fundo do menu ou fora da cena de jogo
	if typeof(Global) != TYPE_NIL and Global.rodando_como_menu_bg:
		return
	if not is_in_group("camera_player"):
		return

	# Se estava inspecionando, fecha a inspeção antes de pausar
	# (senão o overlay fica preso e o objeto some do mundo)
	if inspecionando and not animando_inspecao:
		finalizar_inspecao()
	if typeof(Legendas) != TYPE_NIL and Legendas.has_method("pausar"):
		Legendas.pausar()

	# Esconde emoção / tutorial por cima do pause
	_esconder_ui_emocao_no_pause()

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if pause_canvas:
		pause_canvas.visible  = true
		pause_overlay.visible = true
		pause_label.visible   = true
		# Garante que o pause fica acima de outras UIs de gameplay
		if pause_canvas is CanvasLayer:
			pause_canvas.layer = 100

func unpause_game():
	get_tree().paused = false
	if typeof(Legendas) != TYPE_NIL and Legendas.has_method("despausar"):
		Legendas.despausar()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if pause_canvas:
		pause_canvas.visible  = false
		pause_overlay.visible = false
		pause_label.visible   = false

func _esconder_ui_emocao_no_pause() -> void:
	# Label de emoção
	if emocao_label:
		emocao_label.visible = false
		emocao_label.modulate.a = 0.0
	if tween_emocao_label:
		tween_emocao_label.remove_all()
	if _emocao_timer:
		_emocao_timer.stop()
	# Canvas da emoção (se for CanvasLayer/Control)
	var em_node = get_node_or_null("hud/Emocao")
	if em_node and em_node is CanvasItem:
		em_node.visible = false

	# Tutorial de emoção aberto: fecha de vez (evita ficar invisível bloqueando input)
	for n in get_tree().get_nodes_in_group("emotion_tutorial"):
		if not is_instance_valid(n):
			continue
		var pai = n.get_parent()
		if pai and pai is CanvasLayer:
			pai.queue_free()
		else:
			n.queue_free()

	# Painel de emoção do TutorialManager
	var tm = _get_tutorial_manager()
	if tm:
		if "painel_emocao" in tm and tm.painel_emocao:
			tm.painel_emocao.visible = false
		if tm.has_method("esconder_para_pause"):
			tm.esconder_para_pause()

# 
func _interagir():
	if ray.is_colliding():
		var alvo = _resolver_alvo(ray.get_collider())
		if alvo.is_in_group("interagivel") and alvo.has_method("interagir"):
			alvo.interagir(self)

# Estabiliza foco (portas abertas faziam a crosshair piscar)
var _foco_candidato: Node = null
var _foco_estavel_frames: int = 0
const FOCO_FRAMES_TROCA := 4

func atualizar_foco():
	# Não processa foco/crosshair no fundo do menu nem sem crosshair
	if typeof(Global) != TYPE_NIL and Global.rodando_como_menu_bg:
		return
	if not is_in_group("camera_player"):
		return

	var novo: Node = null
	if ray.is_colliding():
		var alvo = _resolver_alvo(ray.get_collider())
		if alvo and is_instance_valid(alvo) and alvo.is_in_group("interagivel") and alvo.has_method("set_foco"):
			novo = alvo

	# Mesmo alvo já focado: mantém
	if novo != null and novo == objeto_focado:
		_foco_candidato = null
		_foco_estavel_frames = 0
		if crosshair:
			crosshair.set_foco(true)
		return

	# Candidato novo precisa se manter alguns frames (anti-flicker em portas)
	if novo != null:
		if novo == _foco_candidato:
			_foco_estavel_frames += 1
		else:
			_foco_candidato = novo
			_foco_estavel_frames = 1
		if _foco_estavel_frames < FOCO_FRAMES_TROCA:
			# Mantém estado atual da crosshair enquanto confirma
			return
	else:
		# Perdeu o alvo — também exige alguns frames sem hit pra soltar
		if objeto_focado != null:
			if _foco_candidato == null:
				_foco_estavel_frames += 1
			else:
				_foco_candidato = null
				_foco_estavel_frames = 1
			if _foco_estavel_frames < FOCO_FRAMES_TROCA:
				return
		_foco_candidato = null
		_foco_estavel_frames = 0

	# Aplica troca estável
	if objeto_focado and is_instance_valid(objeto_focado):
		objeto_focado.set_foco(false)
	objeto_focado = novo
	_foco_candidato = null
	_foco_estavel_frames = 0

	if objeto_focado:
		objeto_focado.set_foco(true)
		if crosshair:
			crosshair.set_foco(true)
		_call_tutorial("tutorial_interagir")
	else:
		if crosshair:
			crosshair.set_foco(false)

func _resolver_alvo(alvo) -> Node:
	if alvo == null:
		return null
	# Area da porta → parent
	if alvo is Area and alvo.has_meta("door_parent"):
		return alvo.get_meta("door_parent")
	# Sobe a hierarquia: StaticBody interno da porta, mesh colliders, etc.
	var n = alvo
	var guard = 0
	while n and guard < 8:
		if n.has_meta("door_parent"):
			return n.get_meta("door_parent")
		if n.is_in_group("interagivel") and n.has_method("interagir"):
			return n
		n = n.get_parent()
		guard += 1
	return alvo

func _esconder_canvas_recursivo(node: Node) -> void:
	if node is CanvasItem:
		node.visible = false
	for filho in node.get_children():
		_esconder_canvas_recursivo(filho)

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
	# Ícone da lanterna NÃO aparece mais na HUD
	if lanterna_icon_node:
		lanterna_icon_node.visible = false

func _colocar_no_holder(item):
	if item and not holder.is_a_parent_of(item):
		# trava a física ANTES de mexer no transform, senão o motor
		# continua brigando com você pelo controle da posição
		if item is RigidBody:
			item.mode = RigidBody.MODE_STATIC
			item.linear_velocity  = Vector3.ZERO
			item.angular_velocity = Vector3.ZERO

		var col = item.get_node_or_null("CollisionShape")
		if col:
			col.disabled = true

		# também desliga a Area de interação, pra não disparar o pickup de novo
		if item.has_node("Area"):
			item.get_node("Area").monitoring = false
			item.get_node("Area").monitorable = false

		if item.get_parent():
			item.get_parent().remove_child(item)
		holder.add_child(item)
		item.translation = Vector3.ZERO
		item.rotation    = Vector3.ZERO
		item.scale       = Vector3.ONE
		
		if item.has_method("marcar_equipada"):
			item.call("marcar_equipada", true)
			
				# Mantém monitoring=true pra a lanterna detectar paredes e recuar.
		# Só tira de "interagivel" / monitorable pra não reabrir o pickup.
		if item.has_node("Area"):
			var area_item = item.get_node("Area")
			area_item.monitoring = true
			area_item.monitorable = false
			if area_item.is_in_group("interagivel"):
				area_item.remove_from_group("interagivel")

func update_hotbar_ui():
	# Hotbar/ícone da lanterna ficam ocultos — lanterna só aparece na mão quando ligada
	if lanterna_icon_node:
		lanterna_icon_node.visible = false
	if slot_highlight:
		slot_highlight.visible = false
	if hotbar_ui:
		# Mantém o container se precisar de outros slots no futuro, mas sem ícone de lanterna
		pass

#  Cassete 
func pegar_fita(fita):
	var audio_temp     = fita.audio_fita
	var nome_temp      = fita.nome_fita
	var texto_temp     = fita.texto_legenda
	var cor_temp       = fita.cor_legenda
	var calmante_temp  = fita.is_in_group("cassette_music")
	Inventory.add_item("fita_cassete")
	_call_tutorial("tutorial_inventario")
	fita.queue_free()
	fita_audio      = audio_temp
	fita_nome       = nome_temp
	fita_texto      = texto_temp
	fita_cor        = cor_temp
	fita_e_calmante = calmante_temp

func mostrar_cassete_ui(nome: String):
	cassete_nome.text  = nome
	cassete_ui.visible = true

func esconder_cassete_ui():
	cassete_ui.visible = false

## true se uma fita calmante está tocando no gravador
func _cassete_calmante_tocando() -> bool:
	if not fita_e_calmante:
		return false
	# Resolve gravador se ainda não tem referência
	if cassete_player == null or not is_instance_valid(cassete_player):
		var cassetes = get_tree().get_nodes_in_group("cassette_player")
		if cassetes.empty():
			cassetes = get_tree().get_nodes_in_group("gravador")
		if cassetes.size() > 0:
			cassete_player = cassetes[0]
		else:
			return false
	# Gravador.gd expõe fita_tocando
	if "fita_tocando" in cassete_player:
		return cassete_player.fita_tocando
	# AudioStreamPlayer / 3D
	if cassete_player is AudioStreamPlayer or cassete_player is AudioStreamPlayer3D:
		return cassete_player.playing
	# Filho audio_player do gravador
	if "audio_player" in cassete_player and cassete_player.audio_player != null:
		return cassete_player.audio_player.playing
	return false

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

# A maioria dos objetos do mapa tem o Pivot orientado de forma que
# o giro horizontal fica no eixo Z. O ursinho é a exceção: o mesh
# dele precisa girar no Y pra virar pros lados sem "deitar a cabeça".
func _inspecao_usa_eixo_y(objeto) -> bool:
	if objeto == null or not is_instance_valid(objeto):
		return false
	if objeto.is_in_group("ursinho"):
		return true
	if "inspecao_usa_eixo_y" in objeto and objeto.inspecao_usa_eixo_y:
		return true
	return false

func _aplicar_rotacao_inspecao() -> void:
	if objeto_inspecionado == null or not is_instance_valid(objeto_inspecionado):
		return
	var pivot = objeto_inspecionado.get_node_or_null("Pivot")
	if pivot == null:
		return
	if _inspecao_usa_eixo_y(objeto_inspecionado):
		pivot.rotation = Vector3(rotacao_inspecao_x, rotacao_inspecao_y, 0.0)
	else:
		pivot.rotation = Vector3(rotacao_inspecao_x, 0.0, rotacao_inspecao_y)

# Guarda colliders desativados durante a inspeção pra restaurar depois
var _colisores_inspecao_desativados: Array = []
# Backup das visual layers dos meshes (pra não alterar materiais / olhos)
var _visual_layers_backup: Array = []
var _cull_mask_backup: int = 0

# Layer dedicada só pro objeto inspecionado (bit 19 = layer 20)
const INSPECAO_LAYER_BIT := 19

# Overlay: Viewport que re-renderiza SÓ o objeto inspecionado por cima do jogo
var _inspecao_viewport: Viewport = null
var _inspecao_cam: Camera = null
var _inspecao_ui: CanvasLayer = null
var _inspecao_rect: TextureRect = null
var _inspecao_overlay_ativo: bool = false

func _desativar_colisao_inspecao(objeto: Node) -> void:
	_colisores_inspecao_desativados.clear()
	_desativar_colisao_recursivo(objeto)

func _desativar_colisao_recursivo(node: Node) -> void:
	if node is CollisionShape or node is CollisionPolygon:
		if not node.disabled:
			node.disabled = true
			_colisores_inspecao_desativados.append(node)
	if node is PhysicsBody:
		if not node.has_meta("_inspecao_layer_backup"):
			node.set_meta("_inspecao_layer_backup", node.collision_layer)
			node.set_meta("_inspecao_mask_backup", node.collision_mask)
			node.collision_layer = 0
			node.collision_mask = 0
	for child in node.get_children():
		_desativar_colisao_recursivo(child)

func _reativar_colisao_inspecao(objeto: Node) -> void:
	for col in _colisores_inspecao_desativados:
		if is_instance_valid(col):
			col.disabled = false
	_colisores_inspecao_desativados.clear()
	_reativar_physics_layer_recursivo(objeto)

func _reativar_physics_layer_recursivo(node: Node) -> void:
	if node is PhysicsBody and node.has_meta("_inspecao_layer_backup"):
		node.collision_layer = node.get_meta("_inspecao_layer_backup")
		node.collision_mask = node.get_meta("_inspecao_mask_backup")
		node.remove_meta("_inspecao_layer_backup")
		node.remove_meta("_inspecao_mask_backup")
	for child in node.get_children():
		_reativar_physics_layer_recursivo(child)

# --- Visual layer: objeto some da câmera principal e só aparece no overlay ---
func _aplicar_visual_layer_inspecao(objeto: Node) -> void:
	_visual_layers_backup.clear()
	_aplicar_visual_layer_recursivo(objeto)
	# Câmera principal deixa de ver a layer de inspeção → sem clipping com paredes
	_cull_mask_backup = cull_mask
	cull_mask = cull_mask & ~(1 << INSPECAO_LAYER_BIT)

func _aplicar_visual_layer_recursivo(node: Node) -> void:
	if node is GeometryInstance:
		_visual_layers_backup.append({"node": node, "layers": node.layers})
		node.layers = 1 << INSPECAO_LAYER_BIT
		# Sem sombra no mundo enquanto inspeciona
		if not node.has_meta("_inspecao_shadow_backup"):
			node.set_meta("_inspecao_shadow_backup", node.cast_shadow)
			node.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_aplicar_visual_layer_recursivo(child)

func _restaurar_visual_layer_inspecao(objeto: Node) -> void:
	for entry in _visual_layers_backup:
		var gi = entry.get("node", null)
		if gi != null and is_instance_valid(gi):
			gi.layers = entry["layers"]
			if gi.has_meta("_inspecao_shadow_backup"):
				gi.cast_shadow = gi.get_meta("_inspecao_shadow_backup")
				gi.remove_meta("_inspecao_shadow_backup")
	_visual_layers_backup.clear()
	cull_mask = _cull_mask_backup

func _garantir_overlay_inspecao() -> void:
	if _inspecao_viewport != null and is_instance_valid(_inspecao_viewport):
		return

	_inspecao_ui = CanvasLayer.new()
	_inspecao_ui.layer = 40
	_inspecao_ui.name = "InspecaoOverlay"
	get_tree().root.add_child(_inspecao_ui)

	_inspecao_viewport = Viewport.new()
	_inspecao_viewport.name = "InspecaoViewport"
	_inspecao_viewport.transparent_bg = true
	_inspecao_viewport.handle_input_locally = false
	_inspecao_viewport.render_target_v_flip = true
	_inspecao_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	_inspecao_viewport.size = get_viewport().size
	# Mesmo World da cena → vê o objeto no ponto_inspecao
	_inspecao_viewport.world = get_world()
	_inspecao_ui.add_child(_inspecao_viewport)

	_inspecao_cam = Camera.new()
	_inspecao_cam.name = "InspecaoCam"
	_inspecao_cam.cull_mask = 1 << INSPECAO_LAYER_BIT
	_inspecao_cam.current = true
	_inspecao_viewport.add_child(_inspecao_cam)
	# Environment da cena (ambient real) — sem OmniLight inventada
	_aplicar_environment_da_cena()

	_inspecao_rect = TextureRect.new()
	_inspecao_rect.name = "InspecaoRect"
	_inspecao_rect.expand = true
	_inspecao_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_inspecao_rect.anchor_left = 0
	_inspecao_rect.anchor_top = 0
	_inspecao_rect.anchor_right = 1
	_inspecao_rect.anchor_bottom = 1
	_inspecao_rect.margin_left = 0
	_inspecao_rect.margin_top = 0
	_inspecao_rect.margin_right = 0
	_inspecao_rect.margin_bottom = 0
	_inspecao_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspecao_rect.texture = _inspecao_viewport.get_texture()
	_inspecao_ui.add_child(_inspecao_rect)

	_inspecao_ui.visible = false

func _aplicar_environment_da_cena() -> void:
	if _inspecao_cam == null or not is_instance_valid(_inspecao_cam):
		return
	var env: Environment = null
	# 1) Environment da câmera do player, se existir
	if environment != null:
		env = environment.duplicate()
	# 2) WorldEnvironment da cena (iluminação ambiente do jogo)
	if env == null and get_tree().current_scene:
		var we = get_tree().current_scene.find_node("WorldEnvironment", true, false)
		if we and we.environment:
			env = we.environment.duplicate()
	if env == null:
		env = Environment.new()
	# Só troca o fundo pra transparente no overlay; ambient/tonemap ficam iguais
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	_inspecao_cam.environment = env

func _ativar_overlay_inspecao() -> void:
	_garantir_overlay_inspecao()
	# Reaplica o environment atual da cena (pode ter mudado)
	_aplicar_environment_da_cena()
	# Garante que as luzes do mapa iluminam a layer de inspeção
	_garantir_luzes_na_layer_inspecao()
	_sincronizar_cam_inspecao()
	_inspecao_ui.visible = true
	_inspecao_overlay_ativo = true

# Backup das layers das luzes pra restaurar depois
var _luzes_layers_backup: Array = []

func _garantir_luzes_na_layer_inspecao() -> void:
	_luzes_layers_backup.clear()
	var bit = 1 << INSPECAO_LAYER_BIT
	# Percorre a cena em busca de luzes e inclui a layer de inspeção
	var raiz = get_tree().current_scene
	if raiz == null:
		return
	_garantir_luzes_recursivo(raiz, bit)

func _garantir_luzes_recursivo(node: Node, bit: int) -> void:
	if node is Light:
		var l: Light = node
		_luzes_layers_backup.append({"node": l, "layers": l.layers})
		l.layers = l.layers | bit
	for child in node.get_children():
		_garantir_luzes_recursivo(child, bit)

func _restaurar_luzes_layer_inspecao() -> void:
	for entry in _luzes_layers_backup:
		var l = entry.get("node", null)
		if l != null and is_instance_valid(l):
			l.layers = entry["layers"]
	_luzes_layers_backup.clear()

func _desativar_overlay_inspecao() -> void:
	_inspecao_overlay_ativo = false
	if _inspecao_ui != null and is_instance_valid(_inspecao_ui):
		_inspecao_ui.visible = false

func _sincronizar_cam_inspecao() -> void:
	if _inspecao_cam == null or not is_instance_valid(_inspecao_cam):
		return
	_inspecao_cam.global_transform = global_transform
	_inspecao_cam.fov = fov
	_inspecao_cam.near = near
	_inspecao_cam.far = far
	_inspecao_cam.keep_aspect = keep_aspect
	if _inspecao_viewport != null and is_instance_valid(_inspecao_viewport):
		var vp = get_viewport()
		if vp:
			_inspecao_viewport.size = vp.size

func iniciar_inspecao(objeto) -> void:
	if inspecionando or animando_inspecao or not ponto_inspecao:
		return

	inspecionando = true
	animando_inspecao = true
	objeto_inspecionado = objeto

	pai_original_inspecao = objeto.get_parent()
	transform_original_inspecao = objeto.global_transform

	if objeto is RigidBody:
		modo_fisico_original_inspecao = objeto.mode
		objeto.mode = RigidBody.MODE_STATIC

	# Colisão off + layer visual dedicada (materiais intactos → olhos continuam pretos)
	_desativar_colisao_inspecao(objeto)
	_aplicar_visual_layer_inspecao(objeto)
	_ativar_overlay_inspecao()

	pai_original_inspecao.remove_child(objeto)
	ponto_inspecao.add_child(objeto)

	# Mantém a rotação EXATA de como estava no mapa -- o objeto nunca gira sozinho
	var transform_local_inicial = ponto_inspecao.global_transform.affine_inverse() * transform_original_inspecao
	objeto.transform = transform_local_inicial

	# Pivot assume a rotação livre a partir da pose original (sem estalar pra zero)
	var pivot = objeto.get_node("Pivot")
	pivot_rotation_original = pivot.rotation
	rotacao_inspecao_x = pivot_rotation_original.x
	# Ursinho usa eixo Y pro horizontal; o resto dos objetos usa Z
	if _inspecao_usa_eixo_y(objeto):
		rotacao_inspecao_y = pivot_rotation_original.y
	else:
		rotacao_inspecao_y = pivot_rotation_original.z

	if objeto.has_method("set_foco"):
		objeto.set_foco(false)

	tween_inspecao.remove_all()
	tween_inspecao.interpolate_property(objeto, "translation",
		transform_local_inicial.origin, Vector3.ZERO, 0.35,
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween_inspecao.start()

	yield(tween_inspecao, "tween_all_completed")
	animando_inspecao = false


func finalizar_inspecao() -> void:
	if animando_inspecao or not inspecionando:
		return
	animando_inspecao = true

	var objeto = objeto_inspecionado
	var pivot  = objeto.get_node("Pivot")
	var transform_local_final = ponto_inspecao.global_transform.affine_inverse() * transform_original_inspecao

	tween_inspecao.remove_all()
	tween_inspecao.interpolate_property(objeto, "translation",
		objeto.translation, transform_local_final.origin, 0.3,
		Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_inspecao.interpolate_property(pivot, "rotation",
		pivot.rotation, pivot_rotation_original, 0.3,
		Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_inspecao.start()

	yield(tween_inspecao, "tween_all_completed")

	ponto_inspecao.remove_child(objeto)
	pai_original_inspecao.add_child(objeto)
	objeto.global_transform = transform_original_inspecao
	pivot.rotation = pivot_rotation_original

	if objeto is RigidBody and modo_fisico_original_inspecao != null:
		objeto.mode = modo_fisico_original_inspecao

	_desativar_overlay_inspecao()
	_restaurar_luzes_layer_inspecao()
	_restaurar_visual_layer_inspecao(objeto)
	_reativar_colisao_inspecao(objeto)

	inspecionando = false
	animando_inspecao = false
	objeto_inspecionado = null

	
func _on_emocao_timer_timeout() -> void:
	if not emocao_label:
		return
	tween_emocao_label.remove_all()
	tween_emocao_label.interpolate_property(emocao_label, "modulate:a",
		emocao_label.modulate.a, 0.0, emocao_fade_duracao,
		Tween.TRANS_SINE, Tween.EASE_IN)
	tween_emocao_label.start()
	yield(tween_emocao_label, "tween_all_completed")
	emocao_label.visible = false
		
func _on_emocao_liberada() -> void:
	_emocao_liberada = true
	if emocao_label:
		emocao_label.text = NOMES_EMOCAO[emocao_atual]
		_mostrar_emocao_com_fade()
	
func _mostrar_emocao_com_fade() -> void:
	if not emocao_label:
		return
	# Nunca mostra emoção por cima do pause
	if get_tree().paused:
		return
	_emocao_timer.stop()
	tween_emocao_label.remove_all()
	emocao_label.visible = true
	tween_emocao_label.interpolate_property(emocao_label, "modulate:a",
		emocao_label.modulate.a, 1.0, emocao_fade_duracao,
		Tween.TRANS_SINE, Tween.EASE_OUT)
	tween_emocao_label.start()
	yield(tween_emocao_label, "tween_all_completed")
	# Se pausou no meio do fade, esconde e sai
	if get_tree().paused:
		emocao_label.visible = false
		emocao_label.modulate.a = 0.0
		return
	_emocao_timer.start()

	# Tutorial de emoção: UMA ÚNICA vez no jogo inteiro.
	# Nunca reabre ao voltar de crise → calma.
	if emocao_atual != Emocao.CALMA:
		return
	var tm = _get_tutorial_manager()
	if _tutorial_emocao_ja_mostrado:
		return
	if tm != null and tm.emocao_mostrado:
		_tutorial_emocao_ja_mostrado = true
		return
	# Primeira vez de verdade
	_tutorial_emocao_ja_mostrado = true
	if tm != null:
		tm.emocao_mostrado = true
		if tm.has_method("salvar") or tm.has_method("save"):
			pass  # persiste no fluxo normal de save
	_abrir_tutorial_emocao()

func _get_tutorial_manager() -> Node:
	# Preferência: grupo (funciona mesmo se o nome do Autoload mudar)
	var managers = get_tree().get_nodes_in_group("tutorial_manager")
	for m in managers:
		if is_instance_valid(m):
			return m
	# Fallback: Autoload em /root
	var root = get_tree().root
	if root:
		return root.get_node_or_null("TutorialManager")
	return null

func _abrir_tutorial_emocao() -> void:
	if CENA_TUTORIAL_EMOCAO == null:
		push_error("[Camera] CENA_TUTORIAL_EMOCAO não carregou. Confira o path do preload.")
		return
	# Não abre tutorial de emoção em cima do menu de pause
	if get_tree().paused:
		return

	var tut = CENA_TUTORIAL_EMOCAO.instance()

	# Layer abaixo do pause (100) — se pause abrir, pause fica por cima
	var wrapper = CanvasLayer.new()
	wrapper.layer = 90
	wrapper.pause_mode = Node.PAUSE_MODE_PROCESS
	wrapper.add_child(tut)
	get_tree().root.add_child(wrapper)

func set_sensibilidade_mult(mult: float) -> void:
	mouse_sensitivity = mouse_sensitivity_base * mult

# Garante Listener 3D na câmera do player (Godot 3.x).
# AudioStreamPlayer3D só espacializa se existir um Listener current
# no mesmo World/Viewport que as fontes.
func _garantir_listener_3d() -> void:
	var listener = get_node_or_null("Listener")
	if listener == null:
		# Procura qualquer Listener filho (pode ter outro nome)
		for c in get_children():
			if c is Listener:
				listener = c
				break
	if listener == null:
		listener = Listener.new()
		listener.name = "Listener"
		add_child(listener)
		print("🔊 Listener 3D criado em ", get_path())
	if listener is Listener:
		listener.current = true
