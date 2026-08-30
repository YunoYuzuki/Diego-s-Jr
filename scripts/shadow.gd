extends KinematicBody

# =============================================================
# A SOMBRA — redesign psicológico (Camada 1)
# - Máquina de estados: DORMANT → HINTING → WATCHING → PRESENCE → MANIFEST
# - Eventos de tensão (HINTING) com aparições FALSAS bem mais frequentes
# - Aparições reais mais raras e impactantes
# - Pressão de investigação continua sendo o motor principal
# - Regra "olhar = some" preservada (quebra só em casos raros controlados)
# - Bloqueada até a primeira fita
# =============================================================

signal sombra_manifestou(tipo)
signal sombra_desapareceu
signal sombra_estado_mudou(estado_novo)   # novo: para UI/debug/outros sistemas

onready var nav_agent = get_node_or_null("NavigationAgent")
onready var lamps = get_parent().get_node_or_null("lamps")
onready var spawn_points = get_parent().get_node_or_null("ShadowSpawnPoints")
onready var anim_player = get_node_or_null("AnimationPlayer")

# Modelos visuais (cenas .glb separadas)
var _no_idle : Node = null
var _no_running : Node = null
var _visual_holder : Node = null
var _modo_visual_atual : String = ""  # "idle" | "running"

# --- Temporização de eventos de tensão ---
# Intervalos longos — aparições e “a casa se mexendo” bem mais raros
# Originais: f0 48-95 / f1 90-160 / f2 110-210 | cooldown 55
export var intervalo_min_f0 : float = 55.0
export var intervalo_max_f0 : float = 95.0
export var intervalo_min_f1 : float = 75.0
export var intervalo_max_f1 : float = 130.0
export var intervalo_min_f2 : float = 95.0
export var intervalo_max_f2 : float = 170.0

export var tempo_visivel : float = 9.5    # presença normal
export var tempo_flash : float = 4.5      # flash um pouco mais longo que 1s
export var cooldown_time : float = 40.0   # pausa após aparição
export var cooldown_apos_caca : float = 70.0  # pausa extra depois de uma caçada
export var chance_perto_player : float = 0.14   # original: 0.18

export var chance_silencio_longo : float = 0.38  # mais silêncio = mais tensão
export var silencio_longo_min : float = 60.0
export var silencio_longo_max : float = 130.0

# Tensão (por ficar parado na mesma área)
export var tensao_max : float = 100.0
export var tensao_ganho_parado : float = 1.0
export var tensao_threshold_antecipa : float = 58.0
export var tensao_chance_antecipar : float = 0.50

# =============================================================
# PRESSÃO DE INVESTIGAÇÃO
# =============================================================
export var pressao_max : float = 100.0
export var pressao_ganho_por_segundo : float = 0.38
export var pressao_perda_ao_descobrir : float = 40.0
export var pressao_perda_ao_ouvir_fita : float = 55.0
export var pressao_threshold_agressiva : float = 50.0
export var pressao_threshold_critica : float = 80.0

export var pressao_mult_intervalo_min : float = 0.72  # mesmo sob pressão, não spam
export var pressao_mult_chance_efeito : float = 1.25
export var pressao_mult_chance_aproximar : float = 1.12
export var pressao_mult_chance_investida : float = 1.15

# Visão — some rápido quando olhada
export var look_angle_thresh : float = 0.70
export var look_delay : float = 0.55
export var look_delay_variation : float = 0.25

# Movimento
export var velocidade_drift : float = 2.0
export var velocidade_drift_f0_multiplier : float = 1.9
# Aproximação real (Modo.APROXIMAR): bem lenta, quase imperceptível
export var velocidade_aproximar : float = 0.18
export var velocidade_aproximar_olhando : float = 0.10
export var dist_minima_player : float = 1.7
export var nav_recalculo_intervalo : float = 0.35

# Comportamentos de aparição real (mais observação de longe, menos perseguição próxima)
# Originais: aproximar 0.14 / flash 0.10 / indireta 0.14 / investida 0.10
export var chance_aproximar : float = 0.35
export var chance_flash : float = 0.04
export var chance_indireta : float = 0.06
export var chance_aproximar_f0_bonus : float = 0.06
export var chance_flash_f0_bonus : float = 0.04
export var chance_investida : float = 0.22
export var chance_efeito_no_spawn : float = 0.55

# Porta / luz — bem mais raros (a casa age pouco)
export var chance_bater_porta : float = 0.12
export var chance_trancar_porta : float = 0.02  # quase nunca prende o jogador
export(AudioStream) var som_bater_porta

export var chance_piscar_lanterna : float = 0.05
export var chance_piscar_lanterna_f0_bonus : float = 0.02
export var chance_piscar_ambiente : float = 0.003
export var intervalo_checagem_ambiente : float = 55.0

# Stare down RARO
export var chance_stare_down : float = 0.03
export var velocidade_stare_down : float = 0.40

# Quase nunca atrás — era previsível demais no playtest
export var chance_reaparecer_atras : float = 0.08
export var tempo_reaparecer_min : float = 1.4
export var tempo_reaparecer_max : float = 3.0
export var chance_periferia : float = 0.30

export var distancia_investida : float = 2.6
export var distancia_flash : float = 3.2
export var tempo_indireta_espera : float = 0.5

# Piscar lanterna
export var piscar_duracao_min : float = 3.5
export var piscar_duracao_max : float = 7.5
export var piscar_intervalo : float = 0.11

# --- Áudio da Sombra ---
export(AudioStream) var sussurro_1
export(AudioStream) var sussurro_2
export(AudioStream) var sussurro_3
export(AudioStream) var sussurro_4
export(AudioStream) var sussurro_5
export var peso_sussurro_1 : float = 1.0
export var peso_sussurro_2 : float = 1.0
export var peso_sussurro_3 : float = 1.0
export var peso_sussurro_4 : float = 1.0
export var peso_sussurro_5 : float = 1.0

export(AudioStream) var audio_respiracao
export var respiracao_vol_perto : float = 6.0
export var respiracao_vol_longe : float = -6.0
export var respiracao_dist_max : float = 11.0

export(AudioStream) var som_aparecer
export(AudioStream) var som_sumir
export var volume_aparecer : float = -2.0
export var volume_sumir : float = -12.0

export var chao_group : String = ""
export var chao_collision_mask : int = 0

# --- Sussurros isolados (RAROS — nunca em sequência) ---
export var intervalo_sussurro_min : float = 120.0
export var intervalo_sussurro_max : float = 220.0
export var chance_sussurro_isolado : float = 0.08   # bem mais raro
export var silencio_sussurro_longo_chance : float = 0.55
export var silencio_sussurro_longo_min : float = 160.0
export var silencio_sussurro_longo_max : float = 300.0
export var cooldown_audio_ameaca : float = 45.0   # após qualquer sussurro/passo, bloqueia outro áudio

# --- Passos isolados (agora a sombra ANDA invisível pela casa) ---
export(AudioStream) var som_passos
export var intervalo_passos_min : float = 55.0
export var intervalo_passos_max : float = 120.0
export var chance_passos_isolados : float = 0.20
export var pitch_passos_variacao : float = 0.08
# Caminhada fantasma: nasce longe, aproxima-se, fica invisível o tempo todo
export var passos_dist_inicio_min : float = 14.0
export var passos_dist_inicio_max : float = 22.0
export var passos_dist_fim_min : float = 5.0
export var passos_dist_fim_max : float = 9.0
export var passos_velocidade : float = 2.4
export var passos_intervalo_metros : float = 0.58
export var passos_duracao_max : float = 14.0
export var passos_unit_db : float = 8.0
export var passos_max_distance : float = 50.0

# =============================================================
# Pesos: silêncio manda; aparição visual bem rara; casa age pouco
# =============================================================
export var peso_evento_falso : float = 0.42          # ambiental, porta, passos raros...
export var peso_evento_silencio : float = 0.50       # silêncio é arma (P.T. / Visage)
export var peso_evento_presenca : float = 0.08       # aparição visual ainda mais RARA

# --- Camada 2: alterações ambientais + quebras de regra ---
export var chance_alteracao_ambiental : float = 0.08   # bem raro
export var chance_quebra_regra_olhar : float = 0.03
export var look_delay_crise_mult : float = 1.85
export var intervalo_alteracao_min : float = 140.0
export var intervalo_alteracao_max : float = 280.0

# --- Camada 3: contextual + periferia refinada + sonhos ---
export var chance_periferia_falsa : float = 0.10
export var chance_sonho_na_investida : float = 0.08
export var pressao_minima_sonho : float = 70.0
export var sonho_cena_path : String = ""
export var lookback_janela : float = 2.8
export var lookback_yaw_thresh : float = 0.55

# --- Caçada (running) ---
export(AudioStream) var som_grito_caca
export var volume_grito : float = 10.0
# Caça ocasional (original 0.035). Valores altos = spam de grito.
export var chance_iniciar_caca : float = 0.06
# Chance extra de spawnar LONGE (outro lado da casa) e sair correndo atrás do player
export var chance_corrida_de_longe : float = 0.12  # original: 0.22
export var distancia_minima_corrida : float = 14.0   # só conta como "longe" se nascer >= isso
export var tempo_pra_refugio : float = 14.0      # segundos pra chegar em ZonaLuz
export var blackout_duracao_min : float = 60.0
export var blackout_duracao_max : float = 90.0
export var velocidade_caca : float = 10.5   # um pouco mais lenta = tempo de reação
# Caçada atravessa paredes (entidade, não NPC) — contato ainda por distância
export var caca_atravessa_paredes : bool = true
# Frente vs atrás
export var chance_caca_pela_frente : float = 0.55
# Caça: nasce NA FRENTE ou ATRÁS do player (5–8 m) — nunca em cima / fora da casa
export var dist_spawn_caca_min : float = 5.0
export var dist_spawn_caca_max : float = 8.0
export var dist_contato_caca : float = 1.5     # distância máxima para considerar contato (evita depender só de slide_collision)
export var chance_caca_spawn_longe : float = 0.0  # desligado: caça sempre perto (5–8 m)
export var tempo_min_caca_antes_contato : float = 1.0  # evita "crise" no frame do spawn / colisão instantânea
# Distância mínima final do player após posicionar (nunca nascer em cima)
export var dist_minima_spawn_caca_player : float = 3.8
# Respiração na caçada (rápida + volume sobe pra localizar)
export var respiracao_pitch_caca : float = 1.65
export var respiracao_vol_caca_inicio : float = 2.0
export var respiracao_vol_caca_perto : float = 10.0
export var respiracao_caca_ramp_dist : float = 18.0
# Offset de yaw do mesh GLB (muitos modelos olham +Z; look_at usa -Z → costas pro player)
export var mesh_yaw_offset_deg : float = 180.0

# --- Visual / animações da sombra ---
# Como os .glb vêm em cenas separadas (não dá pra salvar AnimationPlayer neles),
# o sistema troca o modelo: idle vs running.
#
# Opção A (recomendada): coloque as duas cenas como FILHAS do nó Sombra
#   com os nomes abaixo (ou mude os nomes no Inspector).
# Opção B: arraste as PackedScene nos exports cena_idle / cena_running
#   e o script instancia/troca sozinho num nó "VisualHolder".
export var nome_no_idle : String = "idle_shadow"
export var nome_no_running : String = "running_crawl_shadow"
export(PackedScene) var cena_idle
export(PackedScene) var cena_running
# Fallback se algum dia tiver AnimationPlayer unificado
export var anim_idle : String = "idle_shadow"
export var anim_running : String = "running_crawl_shadow"

# =============================================================
var _sussurros : Array = []
var _respiracao_player : AudioStreamPlayer3D = null
var _sfx_player : AudioStreamPlayer3D = null
var _passos_player : AudioStreamPlayer3D = null
var _panner_bus_name : String = "SussurroPan"
# Passos agora são 3D reais (sem bus de pan 2D)

# Caminhada fantasma de passos (invisível)
var _andando_passos : bool = false
var _passos_dist_acumulada : float = 0.0
var _passos_pos_anterior : Vector3 = Vector3.ZERO
var _passos_tempo : float = 0.0
var _passos_alvo_pos : Vector3 = Vector3.ZERO
var _quer_sumir : bool = false  # pediu sumir mas só pode fora da visão
var _flicker_louco : bool = false
var _flicker_louco_timer : float = 0.0

# --- Máquina de estados psicológica ---
enum EstadoSombra {
	DORMANT,     # quase inexistente
	HINTING,     # tensão sem aparição real (falsos)
	WATCHING,    # aparece e observa (regra olhou = some)
	PRESENCE,    # aparece e pode se aproximar
	MANIFEST     # raro / pesado (investida, stare-down forte)
}
var _estado : int = EstadoSombra.DORMANT

# Modos de aparição real (compatibilidade com sistema antigo)
enum Modo { OBSERVAR, APROXIMAR, FLASH, INDIRETA, IGNORAR }
var _modo_atual : int = Modo.OBSERVAR
var _ultimo_modo : String = ""
var _ultimo_efeito : String = ""
var _ultimo_tipo_evento : String = ""
var _ultima_acao : String = ""  # evita repetir mesma porta/luz/etc
var _cooldown_override : float = 0.0  # cooldown maior após caça

var _timer : Timer
var _timer_ambiente : Timer
var _timer_sussurro : Timer
var _timer_passos : Timer
var _ativo : bool = false
var _em_cooldown : bool = false
var _desativada_definitivamente : bool = false
var _desbloqueada : bool = false
var _pos_inicial : Vector3 = Vector3.ZERO
var _olhando_timer : float = 0.0
var _visivel_timer : float = 0.0
var _spawn_atual = null
var _vel : Vector3 = Vector3.ZERO
const _GRAVIDADE : float = 0.0   # sombra NÃO cai — trava no navmesh/chão
var _altura_chao_atual : float = 0.0
var _nav_timer_acumulado : float = 0.0

var _piscando : bool = false
var _piscar_timer : float = 0.0
var _piscar_duracao : float = 0.0
var _piscar_intervalo_timer : float = 0.0

var _tensao : float = 0.0
var _ambiente_anterior_player : String = ""
var _evento_ignorar_disponivel : bool = false

# Pressão de investigação
var _pressao : float = 0.0
var _investigando : bool = true
var _tempo_desde_ultima_descoberta : float = 0.0
var _ultima_descoberta_tipo : String = ""

var _stare_down_ativo : bool = false
var _aguardando_reaparecer : bool = false

var _ultimo_pan_lado : int = 0

# Tracking simples de comportamento do jogador (para contextual futuro)
var _tempo_parado_recente : float = 0.0
var _ultimos_eventos_falsos : Array = []   # evita repetir o mesmo tipo seguido

# Camada 2
var _timer_alteracao : Timer = null
var _quebra_regra_ativa : bool = false     # nesta aparição a regra do olhar está "quebrada"
var _ultima_alteracao_tipo : String = ""
var _camera_ref = null                    # cache da Camera do player

# Camada 3 — tracking contextual do jogador
var _lookback_count : int = 0             # quantas vezes olhou pra trás após passos
var _passos_count : int = 0               # quantos eventos de passos tocaram
var _aguardando_lookback : bool = false
var _lookback_timer : float = 0.0
var _yaw_no_passo : float = 0.0
var _ambientes_tempo : Dictionary = {}    # ambiente -> tempo acumulado
var _ambiente_evitado_preferido : String = ""
var _ultimo_spawn_foi_periferia : bool = false
var _sonho_em_andamento : bool = false
var _pos_antes_sonho : Vector3 = Vector3.ZERO

# Anti-spam de áudio de ameaça (sussurro/passos não em sequência)
var _audio_ameaca_bloqueado_ate : float = 0.0

# Caçada / blackout
var _cacando : bool = false
var _collision_mask_backup : int = -1
var _collision_layer_backup : int = -1
var _caca_pela_frente : bool = false
var _tempo_caca : float = 0.0
var _blackout_ativo : bool = false
var _blackout_restante : float = 0.0
var _luzes_antes_blackout : Dictionary = {}  # path -> visible

# =============================================================
func _ready() -> void:
	add_to_group("sombra")
	hide()

	# Garante AnimationPlayer mesmo se estiver um nível abaixo (modelo da sombra)
	if anim_player == null or not (anim_player is AnimationPlayer):
		anim_player = find_node("AnimationPlayer", true, false)
	if anim_player != null and not (anim_player is AnimationPlayer):
		anim_player = null  # evita chamar is_playing/stop em Spatial

	_setup_visuais()

	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = dist_minima_player

	randomize()
	_pos_inicial = global_transform.origin

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.connect("timeout", self, "_disparar_evento_tensao")

	_timer_ambiente = Timer.new()
	_timer_ambiente.wait_time = intervalo_checagem_ambiente
	_timer_ambiente.one_shot = false
	add_child(_timer_ambiente)
	_timer_ambiente.connect("timeout", self, "_checar_flicker_ambiente")

	_timer_sussurro = Timer.new()
	_timer_sussurro.one_shot = true
	add_child(_timer_sussurro)
	_timer_sussurro.connect("timeout", self, "_tentar_sussurro_isolado")

	_timer_passos = Timer.new()
	_timer_passos.one_shot = true
	add_child(_timer_passos)
	_timer_passos.connect("timeout", self, "_tentar_passos_isolados")

	_timer_alteracao = Timer.new()
	_timer_alteracao.one_shot = true
	add_child(_timer_alteracao)
	_timer_alteracao.connect("timeout", self, "_tentar_alteracao_ambiental")

	for child in get_children():
		if child is AudioStreamPlayer:
			_sussurros.append(child)
	_criar_sussurros()
	_setup_panner_bus()

	var bus_sfx = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"

	_respiracao_player = AudioStreamPlayer3D.new()
	_respiracao_player.bus = bus_sfx
	_respiracao_player.unit_db = 4.0
	_respiracao_player.unit_size = 10.0
	_respiracao_player.max_distance = 35.0
	_respiracao_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(_respiracao_player)
	if audio_respiracao:
		_respiracao_player.stream = audio_respiracao
		_respiracao_player.connect("finished", self, "_on_respiracao_finished")

	_sfx_player = AudioStreamPlayer3D.new()
	_sfx_player.bus = bus_sfx
	_sfx_player.unit_db = 8.0
	_sfx_player.unit_size = 10.0
	_sfx_player.max_distance = 55.0
	_sfx_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(_sfx_player)

	_passos_player = AudioStreamPlayer3D.new()
	_passos_player.bus = bus_sfx
	_passos_player.unit_db = passos_unit_db
	_passos_player.unit_size = 10.0
	_passos_player.max_distance = passos_max_distance
	_passos_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(_passos_player)

	_aguardar_primeira_fita()

func _criar_sussurros() -> void:
	var streams = [sussurro_1, sussurro_2, sussurro_3, sussurro_4, sussurro_5]
	for stream in streams:
		if stream != null:
			var p = AudioStreamPlayer.new()
			p.stream = stream
			p.bus = _panner_bus_name
			add_child(p)
			_sussurros.append(p)

func _setup_panner_bus() -> void:
	var idx = AudioServer.get_bus_index(_panner_bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, _panner_bus_name)
		var panner = AudioEffectPanner.new()
		panner.pan = 0.0
		AudioServer.add_bus_effect(idx, panner)
	var sfx_idx = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_send(idx, "SFX" if sfx_idx != -1 else "Master")
	for p in _sussurros:
		if p is AudioStreamPlayer:
			p.bus = _panner_bus_name

func _set_sussurro_pan_inteligente() -> void:
	var idx = AudioServer.get_bus_index(_panner_bus_name)
	if idx == -1:
		return
	for i in range(AudioServer.get_bus_effect_count(idx)):
		var fx = AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectPanner:
			var opcoes = [-1, -1, 1, 1, 0]
			if _ultimo_pan_lado != 0:
				opcoes.erase(_ultimo_pan_lado)
			var escolha = opcoes[randi() % opcoes.size()]
			_ultimo_pan_lado = escolha
			if escolha == -1:
				fx.pan = -0.92
			elif escolha == 1:
				fx.pan = 0.92
			else:
				fx.pan = 0.0
			return

# Passos agora usam AudioStreamPlayer3D posicional — bus de pan 2D não é mais necessário.

func _on_respiracao_finished() -> void:
	if _ativo and audio_respiracao and _respiracao_player:
		_respiracao_player.play()

func _get_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _get_camera():
	if _camera_ref != null and is_instance_valid(_camera_ref):
		return _camera_ref
	var player = _get_player()
	if player:
		_camera_ref = player.get_node_or_null("Camera")
	return _camera_ref

## Retorna a emoção atual da Laura (0=CALMA, 1=COM_MEDO, 2=ASSUSTADA, 3=EM_CRISE)
func _get_emocao_laura() -> int:
	var cam = _get_camera()
	if cam and cam.has_method("get_emocao"):
		return cam.get_emocao()
	return 0

func _laura_em_crise() -> bool:
	var cam = _get_camera()
	if cam and cam.has_method("esta_em_crise"):
		return cam.esta_em_crise()
	return false

func _laura_assustada_ou_pior() -> bool:
	var cam = _get_camera()
	if cam and cam.has_method("esta_assustada_ou_pior"):
		return cam.esta_assustada_ou_pior()
	return false

func _get_fase() -> int:
	var total = SaveManager.itens_coletados.size()
	var fase = int(total / 4)
	if fase > 2:
		fase = 2
	if fase < 0:
		fase = 0
	return fase

# =============================================================
# MÁQUINA DE ESTADOS
# =============================================================
func _mudar_estado(novo: int) -> void:
	if _estado == novo:
		return
	_estado = novo
	emit_signal("sombra_estado_mudou", novo)
	match novo:
		EstadoSombra.DORMANT:
			print("🌑 Estado → DORMANT")
		EstadoSombra.HINTING:
			print("🌫️ Estado → HINTING (tensão sem aparição real)")
		EstadoSombra.WATCHING:
			print("👁️ Estado → WATCHING")
		EstadoSombra.PRESENCE:
			print("👤 Estado → PRESENCE")
		EstadoSombra.MANIFEST:
			print("💀 Estado → MANIFEST")

func get_estado() -> int:
	return _estado

func get_estado_nome() -> String:
	match _estado:
		EstadoSombra.DORMANT: return "DORMANT"
		EstadoSombra.HINTING: return "HINTING"
		EstadoSombra.WATCHING: return "WATCHING"
		EstadoSombra.PRESENCE: return "PRESENCE"
		EstadoSombra.MANIFEST: return "MANIFEST"
	return "UNKNOWN"

# =============================================================
# AGENDAMENTO DE EVENTOS DE TENSÃO
# =============================================================
func _schedule_next() -> void:
	_reset_all()
	if _desativada_definitivamente or not _desbloqueada:
		return

	_mudar_estado(EstadoSombra.DORMANT)

	var f = _get_fase()
	var mn = intervalo_min_f0
	var mx = intervalo_max_f0
	if f == 1:
		mn = intervalo_min_f1
		mx = intervalo_max_f1
	elif f == 2:
		mn = intervalo_min_f2
		mx = intervalo_max_f2

	# Pressão alta = intervalos menores
	var fator_pressao = 1.0
	if _pressao >= pressao_threshold_critica:
		fator_pressao = pressao_mult_intervalo_min
	elif _pressao >= pressao_threshold_agressiva:
		var t_norm = (_pressao - pressao_threshold_agressiva) / (pressao_threshold_critica - pressao_threshold_agressiva)
		fator_pressao = lerp(1.0, pressao_mult_intervalo_min, t_norm)

	mn *= fator_pressao
	mx *= fator_pressao

	var t : float
	if randf() < chance_silencio_longo * (0.55 if _pressao > pressao_threshold_agressiva else 1.0):
		t = rand_range(silencio_longo_min, silencio_longo_max)
		print("💀 Sombra em silêncio longo: %.0fs" % t)
	else:
		t = rand_range(mn, mx) + rand_range(-4.0, 6.0)
		t = max(t, 5.0)

	_timer.start(t)
	print("⏱️ Próximo evento de tensão em %.1fs (fase %d) | tensão %.1f | pressão %.1f" % [t, f, _tensao, _pressao])

func _reset_all() -> void:
	_olhando_timer = 0.0
	_visivel_timer = 0.0
	_piscando = false
	_stare_down_ativo = false
	_quebra_regra_ativa = false
	_vel = Vector3.ZERO
	_parar_respiracao()
	hide()
	# Nunca volta pro _pos_inicial se ele estiver fora da casa
	_estacionar_fora_de_jogo()
	_spawn_atual = null
	_ativo = false

# =============================================================
# DISPARO DE EVENTO DE TENSÃO (o coração do redesign)
# Decide entre: falso / silêncio / presença real
# =============================================================
func _disparar_evento_tensao() -> void:
	if _desativada_definitivamente or not _desbloqueada or _ativo or _em_cooldown or _cacando:
		return

	var tipo = _sortear_tipo_evento()
	# Nunca o mesmo tipo 2x seguidas
	if tipo == _ultimo_tipo_evento:
		if tipo == "presenca":
			tipo = "silencio" if randf() < 0.5 else "falso"
		elif tipo == "falso":
			tipo = "silencio"
		else:
			tipo = "falso"
	_ultimo_tipo_evento = tipo

	match tipo:
		"falso":
			_executar_evento_falso()
		"silencio":
			_executar_silencio_dinamico()
		"presenca":
			_spawnar()   # aparição real
		_:
			_executar_evento_falso()

func _sortear_tipo_evento() -> String:
	# Pesos base
	var w_falso = peso_evento_falso
	var w_silencio = peso_evento_silencio
	var w_presenca = peso_evento_presenca

	# Pressão alta aumenta a chance de presença real
	if _pressao >= pressao_threshold_critica:
		w_presenca *= 2.1
		w_falso *= 0.75
	elif _pressao >= pressao_threshold_agressiva:
		w_presenca *= 1.55
		w_falso *= 0.88

	# Tensão alta também empurra para presença
	if _tensao >= tensao_threshold_antecipa:
		w_presenca *= 1.35

	# Estado emocional da Laura (Camada 2)
	# Em crise: mais falsos e silêncios (paranoia) + um pouco mais de presença real
	var emocao = _get_emocao_laura()
	if emocao >= 3:  # EM_CRISE
		w_falso *= 1.25
		w_silencio *= 1.40
		w_presenca *= 1.30
	elif emocao >= 2:  # ASSUSTADA
		w_falso *= 1.15
		w_silencio *= 1.20
		w_presenca *= 1.10
	elif emocao >= 1:  # COM_MEDO
		w_falso *= 1.08
		w_silencio *= 1.10

	# Evita repetir o mesmo tipo
	if _ultimo_tipo_evento == "presenca":
		w_presenca *= 0.25
		w_silencio *= 1.4
	elif _ultimo_tipo_evento == "falso":
		w_falso *= 0.35
		w_silencio *= 1.3
	elif _ultimo_tipo_evento == "silencio":
		w_silencio *= 0.5

	var total = w_falso + w_silencio + w_presenca
	var r = randf() * total
	if r < w_falso:
		return "falso"
	elif r < w_falso + w_silencio:
		return "silencio"
	else:
		return "presenca"

# =============================================================
# EVENTOS FALSOS (HINTING) — o jogador pensa que a Sombra está vindo
# =============================================================
func _executar_evento_falso() -> void:
	_mudar_estado(EstadoSombra.HINTING)
	emit_signal("sombra_manifestou", "hinting_falso")

	# Pool: mais silêncio/nada; porta e luz bem menos frequentes
	var pool = ["silencio_curto", "silencio_curto", "silencio_curto", "nada", "nada", "nada", "nada"]
	if randf() < 0.35:
		pool.append("ambiental")
	if randf() < 0.25:
		pool.append("porta")
	if _audio_ameaca_livre():
		if randf() < 0.40:
			pool.append("passos")
		# Sussurro bem raro nos eventos falsos
		if randf() < 0.10:
			pool.append("sussurro")
	# Periferia falsa desligada por padrão aqui (spawnava fora da casa)
	# if randf() < chance_periferia_falsa: pool.append("periferia_falsa")

	if _ultimos_eventos_falsos.size() > 0:
		var ultimo = _ultimos_eventos_falsos.back()
		if pool.has(ultimo):
			pool.erase(ultimo)

	# periferia_falsa desligada — spawnava fora da casa

	var escolha = pool[randi() % pool.size()]
	_ultimos_eventos_falsos.append(escolha)
	if _ultimos_eventos_falsos.size() > 5:
		_ultimos_eventos_falsos.pop_front()

	print("🌫️ Evento falso: ", escolha)

	match escolha:
		"passos":
			if _audio_ameaca_livre():
				_tocar_passo_assustador()
				_bloquear_audio_ameaca()
		"sussurro":
			if _audio_ameaca_livre():
				_tocar_sussurro()
				_bloquear_audio_ameaca()
		"porta":
			_tentar_bater_porta()
		"silencio_curto":
			yield(get_tree().create_timer(rand_range(3.5, 8.0)), "timeout")
		"ambiental":
			_aplicar_alteracao_ambiental()
		"periferia_falsa":
			_evento_periferia_falsa()
		"nada":
			pass

	# Segundo evento: raro e quase só silêncio/nada (evita spam de porta/luz)
	if randf() < 0.10 and _pressao > 45.0:
		yield(get_tree().create_timer(rand_range(3.0, 6.5)), "timeout")
		if not _ativo and not _desativada_definitivamente:
			var segundo = ["nada", "nada", "ambiental", "porta"][randi() % 4]
			print("🌫️ Segundo falso (casa): ", segundo)
			match segundo:
				"porta": _tentar_bater_porta()
				"ambiental": _aplicar_alteracao_ambiental()
				_: pass

	_schedule_next()

func _executar_silencio_dinamico() -> void:
	_mudar_estado(EstadoSombra.HINTING)
	emit_signal("sombra_manifestou", "silencio_dinamico")
	print("🔇 Silêncio dinâmico (nada acontece)")
	# O silêncio é o próprio evento. O jogador fica esperando.
	# Não tocamos nada. Apenas reagendamos depois.
	yield(get_tree().create_timer(rand_range(4.0, 9.0)), "timeout")
	_schedule_next()

# =============================================================
# APARECIMENTO REAL
# =============================================================
func _spawnar() -> void:
	if _desativada_definitivamente or not _desbloqueada or _ativo or _em_cooldown:
		return

	var f = _get_fase()
	var modo_str = _sortear_modo(f)
	_ultimo_modo = modo_str

	match modo_str:
		"observar":
			_modo_atual = Modo.OBSERVAR
			_mudar_estado(EstadoSombra.WATCHING)
		"aproximar":
			_modo_atual = Modo.APROXIMAR
			_mudar_estado(EstadoSombra.PRESENCE)
		"flash":
			_modo_atual = Modo.FLASH
			_mudar_estado(EstadoSombra.PRESENCE)
		"indireta":
			_manifestacao_indireta()
			return
		"ignorar":
			_modo_atual = Modo.IGNORAR
			_mudar_estado(EstadoSombra.WATCHING)

	# SOMENTE pontos de ShadowSpawnPoints (nunca offset solto / periferia fora da casa)
	var ponto = _escolher_ponto()
	_ultimo_spawn_foi_periferia = false
	if ponto == null:
		print("⚠️ Sem ponto de spawn interno válido")
		_schedule_next()
		return

	_spawn_atual = ponto if ponto is Spatial else null
	var pos_spawn = Vector3.ZERO
	var pos_original = Vector3.ZERO
	if ponto is Spatial:
		pos_original = ponto.global_transform.origin
		pos_spawn = pos_original
	else:
		pos_original = ponto
		pos_spawn = ponto
	# Só aparece em cima do NavigationMesh (área azul) E dentro da casa
	pos_spawn = _snap_ao_navmesh(pos_spawn)
	if not _pos_esta_no_navmesh(pos_spawn, pos_original):
		print("⚠️ Spawn rejeitado — fora do NavigationMesh")
		_schedule_next()
		return
	# Dupla checagem: se o ponto do editor estiver meio fora, força interno
	var pos_segura = _forcar_posicao_interna(pos_spawn, 8.0)
	if pos_segura == null:
		print("⚠️ Spawn rejeitado — nenhum ponto interno válido")
		_schedule_next()
		return
	pos_spawn = pos_segura
	global_transform.origin = pos_spawn
	_altura_chao_atual = pos_spawn.y

	_parar_todos_sussurros()
	show()
	_ativo = true
	_olhando_timer = 0.0
	_visivel_timer = 0.0
	_stare_down_ativo = false
	_quebra_regra_ativa = false
	_quer_sumir = false
	# Orienta o corpo para o player ANTES de mostrar o mesh (evita nascer de costas)
	var _pl_orient = _get_player()
	if _pl_orient:
		var _look = _pl_orient.global_transform.origin
		_look.y = global_transform.origin.y
		if _look.distance_to(global_transform.origin) > 0.15:
			look_at(_look, Vector3.UP)
	# Força modo visual de novo (reseta cache) e mostra o mesh idle
	_modo_visual_atual = ""
	_mostrar_visual("idle")

	# Camada 2: chance rara de quebra da regra "olhar = some"
	# Só em pressão alta ou Laura assustada/crise — e ainda assim bem raro
	var chance_quebra = chance_quebra_regra_olhar
	if _pressao >= pressao_threshold_critica:
		chance_quebra *= 2.2
	elif _pressao >= pressao_threshold_agressiva:
		chance_quebra *= 1.5
	if _laura_assustada_ou_pior():
		chance_quebra *= 1.4
	if randf() < chance_quebra:
		_quebra_regra_ativa = true
		print("💀 Quebra de regra ativa nesta aparição (olhar demora mais)")

	_iniciar_respiracao()
	_tocar_sfx(som_aparecer, volume_aparecer)
	# Atmosfera só quando o jogador VER de fato (atualizado em _physics_process)
	_set_atmosfera_camera(false)

	var nome_ponto = "?"
	if ponto is Spatial:
		nome_ponto = ponto.name
	var dist_pl = 0.0
	var pl = _get_player()
	if pl:
		dist_pl = global_transform.origin.distance_to(pl.global_transform.origin)
	var perto_longe = "PERTO" if dist_pl < 10.0 else "LONGE"
	var acao = modo_str
	match _modo_atual:
		Modo.OBSERVAR:
			acao = "observando"
		Modo.APROXIMAR:
			acao = "se aproximando"
		Modo.FLASH:
			acao = "flash (rápido)"
		Modo.IGNORAR:
			acao = "ignorando olhar"
	print("💀 Sombra SPAWN | ponto=%s | %s (%.1fm) | modo=%s | ação=%s | fase=%d | pressão=%.0f | estado=%s" % [
		nome_ponto, perto_longe, dist_pl, modo_str, acao, f, _pressao, get_estado_nome()
	])
	emit_signal("sombra_manifestou", modo_str)
	_tentar_iniciar_caca_no_spawn()

	if _modo_atual == Modo.IGNORAR:
		var player = _get_player()
		if player:
			var oposta = global_transform.origin + (global_transform.origin - player.global_transform.origin)
			oposta.y = global_transform.origin.y
			look_at(oposta, Vector3.UP)
		yield(get_tree().create_timer(rand_range(3.0, 5.5)), "timeout")
		_sumir(false)
		return

	var chance_efeito = chance_efeito_no_spawn
	if _pressao >= pressao_threshold_agressiva:
		chance_efeito = min(chance_efeito * pressao_mult_chance_efeito, 0.95)
	if randf() < chance_efeito:
		_disparar_efeito(f)

func _sortear_modo(fase: int) -> String:
	var pool := ["observar", "aproximar", "flash", "indireta"]
	if _evento_ignorar_disponivel:
		pool.append("ignorar")

	var mult_aprox = 1.0
	var mult_flash = 1.0
	if _pressao >= pressao_threshold_agressiva:
		mult_aprox = pressao_mult_chance_aproximar
		mult_flash = 1.25
	if _pressao >= pressao_threshold_critica:
		mult_aprox = pressao_mult_chance_aproximar * 1.15
		mult_flash = 1.40

	# Menos flash (sumia rápido); mais observar/aproximar
	var pesos := {
		"observar": 0.32,
		"aproximar": (chance_aproximar + (chance_aproximar_f0_bonus if fase == 0 else 0.0)) * mult_aprox,
		"flash": (chance_flash + (chance_flash_f0_bonus if fase == 0 else 0.0)) * mult_flash * 0.4,
		"indireta": chance_indireta,
		"ignorar": 0.02
	}

	if pool.size() > 1 and pool.has(_ultimo_modo):
		pool.erase(_ultimo_modo)

	var total := 0.0
	for m in pool:
		total += max(pesos.get(m, 0.1), 0.001)
	var r = randf() * total
	var acc := 0.0
	for m in pool:
		acc += max(pesos.get(m, 0.1), 0.001)
		if r <= acc:
			if m == "ignorar":
				_evento_ignorar_disponivel = false
			return m
	return pool[0]

func _manifestacao_indireta() -> void:
	if not _desbloqueada:
		_schedule_next()
		return
	_mudar_estado(EstadoSombra.HINTING)
	print("💀 Manifestação indireta")
	emit_signal("sombra_manifestou", "indireta")
	_disparar_efeito(_get_fase(), true)
	yield(get_tree().create_timer(tempo_indireta_espera), "timeout")
	_schedule_next()

# =============================================================
func _iniciar_respiracao() -> void:
	if not audio_respiracao or not _respiracao_player:
		return
	_respiracao_player.stream = audio_respiracao
	_respiracao_player.unit_db = respiracao_vol_longe
	_respiracao_player.max_distance = respiracao_dist_max
	if not _respiracao_player.playing:
		_respiracao_player.play()

func _parar_respiracao() -> void:
	if _respiracao_player and _respiracao_player.playing:
		_respiracao_player.stop()
	if _respiracao_player:
		_respiracao_player.unit_db = -40.0

func _tocar_sfx(stream: AudioStream, vol: float = 0.0) -> void:
	if stream == null or _sfx_player == null:
		return
	_sfx_player.stream = stream
	_sfx_player.unit_db = vol
	_sfx_player.play()

# =============================================================
func _atualizar_tensao(delta: float) -> void:
	if _desativada_definitivamente or not _desbloqueada:
		return

	var amb = _get_ambiente_player()
	if amb == _ambiente_anterior_player:
		_tensao = min(_tensao + tensao_ganho_parado * delta, tensao_max)
		_tempo_parado_recente += delta
	else:
		_tensao = max(_tensao - 8.0, 0.0)
		_ambiente_anterior_player = amb
		_tempo_parado_recente = 0.0

	# Camada 3: acumula tempo por ambiente (para preferir spawn perto de onde evita / fica muito)
	if amb != "" and amb != "fora":
		_ambientes_tempo[amb] = float(_ambientes_tempo.get(amb, 0.0)) + delta

	# Camada 3: detecta se o jogador olhou pra trás após passos
	if _aguardando_lookback:
		_lookback_timer -= delta
		var player = _get_player()
		if player:
			var yaw_atual = player.rotation.y
			var delta_yaw = abs(_angulo_diff(_yaw_no_passo, yaw_atual))
			if delta_yaw >= lookback_yaw_thresh:
				_lookback_count += 1
				_aguardando_lookback = false
				print("👀 Jogador olhou pra trás após passos (%d/%d)" % [_lookback_count, max(_passos_count, 1)])
		if _lookback_timer <= 0.0:
			_aguardando_lookback = false

	_tempo_desde_ultima_descoberta += delta
	if _investigando:
		var multiplicador_tempo = 1.0 + clamp(_tempo_desde_ultima_descoberta / 90.0, 0.0, 1.5)
		_pressao = min(_pressao + pressao_ganho_por_segundo * multiplicador_tempo * delta, pressao_max)
	else:
		_pressao = max(_pressao - 4.0 * delta, 0.0)

	# Antecipa evento se tensão ou pressão estiverem altas
	if not _ativo and not _em_cooldown:
		var deve_antecipar = false
		if _tensao >= tensao_threshold_antecipa and randf() < tensao_chance_antecipar * delta:
			deve_antecipar = true
		elif _pressao >= pressao_threshold_agressiva and randf() < 0.32 * delta:
			deve_antecipar = true
		elif _pressao >= pressao_threshold_critica and randf() < 0.50 * delta:
			deve_antecipar = true
		# Camada 3: parado por muito tempo → mais chance de antecipar HINTING
		elif _tempo_parado_recente > 14.0 and randf() < 0.22 * delta:
			deve_antecipar = true

		if deve_antecipar:
			_timer.stop()
			_disparar_evento_tensao()

func _angulo_diff(a: float, b: float) -> float:
	var d = b - a
	while d > PI:
		d -= TAU
	while d < -PI:
		d += TAU
	return d

## Taxa de "olhar pra trás" após passos (0..1). Usado pra inverter direção dos próximos passos.
func _taxa_lookback() -> float:
	if _passos_count < 3:
		return 0.0
	return clamp(float(_lookback_count) / float(_passos_count), 0.0, 1.0)

# =============================================================
func _process(_delta: float) -> void:
	# AnimationPlayer aplica root motion DEPOIS do physics — zera de novo aqui
	if _cacando and _no_running:
		_ancorar_visual(_no_running)
	elif _ativo and _modo_visual_atual == "running" and _no_running:
		_ancorar_visual(_no_running)
	elif _ativo and _modo_visual_atual == "idle" and _no_idle:
		_ancorar_visual(_no_idle)

func _physics_process(delta: float) -> void:
	if not _desbloqueada or _desativada_definitivamente:
		return

	_atualizar_tensao(delta)
	_atualizar_respiracao_por_distancia(delta)
	_processar_blackout(delta)
	_processar_caca(delta)
	if _cacando:
		return

	# Caminhada fantasma de passos (invisível) — roda mesmo sem aparição visual
	if _andando_passos:
		_processar_caminhada_passos(delta)
		_atualizar_flicker_louco(delta, true)  # passos na casa = luzes enlouquecem
		_set_atmosfera_camera(false)
		return

	if _piscando:
		_processar_piscar(delta)

	if not _ativo or _em_cooldown:
		# Sem sombra na tela → tira o efeito de atmosfera
		_set_atmosfera_camera(false)
		return

	var player = _get_player()
	if not player:
		_set_atmosfera_camera(false)
		return
	if _modo_atual == Modo.IGNORAR:
		_set_atmosfera_camera(false)
		return

	var cam = player.get_node_or_null("Camera")
	if cam == null:
		return

	var look_target = player.global_transform.origin
	look_target.y = global_transform.origin.y
	if look_target.distance_to(global_transform.origin) > 0.15:
		look_at(look_target, Vector3.UP)

	var sendo_vista = _checar_visao(cam)

	# Atmosfera da câmera: só enquanto o jogador ESTÁ VENDO a sombra
	_set_atmosfera_camera(sendo_vista)

	if sendo_vista:
		_olhando_timer += delta

		# Stare down bem raro
		if not _stare_down_ativo and randf() < chance_stare_down * delta:
			_stare_down_ativo = true
			_mudar_estado(EstadoSombra.MANIFEST)
			print("💀 Stare down (raro)")

		if _stare_down_ativo:
			var dir = player.global_transform.origin - global_transform.origin
			dir.y = 0.0
			if dir.length() > dist_minima_player:
				dir = dir.normalized()
				_vel.x = dir.x * velocidade_stare_down
				_vel.z = dir.z * velocidade_stare_down
			else:
				_vel.x = 0.0
				_vel.z = 0.0
		elif _modo_atual == Modo.APROXIMAR:
			# Mesmo olhando: continua se aproximando (mais lento) — não fica travada no mesmo canto
			_mover_em_direcao_do_player(player, velocidade_aproximar_olhando)
		else:
			# OBSERVAR / FLASH: parada, só olhando
			_vel.x = 0.0
			_vel.z = 0.0
	else:
		_olhando_timer = 0.0
		_stare_down_ativo = false

		# Só se move no modo APROXIMAR (e não em OBSERVAR/FLASH/IGNORAR)
		if _modo_atual == Modo.APROXIMAR:
			# Quase imperceptível — fase 0 um pouco menos lenta
			var speed = velocidade_aproximar
			if _get_fase() == 0:
				speed = min(velocidade_aproximar * 1.35, 0.28)
			_mover_em_direcao_do_player(player, speed)
		else:
			# OBSERVAR / FLASH / etc: trava no lugar
			_vel.x = 0.0
			_vel.z = 0.0

	# Sem gravidade — não cai pelo chão
	_vel.y = 0.0
	move_and_slide(_vel, Vector3.UP)
	_travar_no_chao()
	# Segurança: se a sombra saiu da casa (navmesh/void), some imediatamente
	if not _posicao_ainda_interna():
		print("⚠️ Sombra saiu da área interna — forçando sumir")
		_sumir(false)
		return
	_atualizar_animacao_movimento()
	# Contra root motion do GLB: mantém o modelo colado no corpo da sombra
	# Força idle fora da caça (nunca running em APROXIMAR)
	if _cacando:
		_mostrar_visual("running")
		_ancorar_visual(_no_running)
	else:
		_mostrar_visual("idle")
		_ancorar_visual(_no_idle)

	# Luzes piscando loucamente enquanto anda / persegue
	_atualizar_flicker_louco(delta, _esta_em_movimento_ameaca())

	# SOME só quando FORA da visão do jogador.
	# Enquanto ele estiver olhando, ela NÃO pode sumir.
	_visivel_timer += delta
	var tempo_max = tempo_flash if _modo_atual == Modo.FLASH else tempo_visivel
	if _visivel_timer >= tempo_max:
		_quer_sumir = true

	if _quer_sumir:
		if sendo_vista:
			# Continua visível / andando até sair do FOV
			pass
		else:
			_sumir(true)
			return

func _atualizar_respiracao_por_distancia(delta: float) -> void:
	if _respiracao_player == null:
		return
	# Durante a caçada a respiração é controlada por _atualizar_respiracao_caca
	if _cacando:
		return
	# 3D nativo: só ajusta pitch e liga/desliga. Volume espacial vem da posição.
	if not _ativo:
		if _respiracao_player.playing:
			_respiracao_player.unit_db = lerp(_respiracao_player.unit_db, -40.0, 5.0 * delta)
			if _respiracao_player.unit_db < -35.0:
				_respiracao_player.stop()
		_respiracao_player.pitch_scale = lerp(_respiracao_player.pitch_scale, 1.0, 3.0 * delta)
		return

	_respiracao_player.max_distance = respiracao_dist_max
	# unit_db fica entre longe/perto conforme distância (complementa a atenuação 3D)
	var player = _get_player()
	if not player:
		return
	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	var t = 1.0 - clamp(dist / respiracao_dist_max, 0.0, 1.0)
	t = t * t
	var vol_alvo = lerp(respiracao_vol_longe, respiracao_vol_perto, t)
	_respiracao_player.unit_db = lerp(_respiracao_player.unit_db, vol_alvo, 4.0 * delta)
	_respiracao_player.pitch_scale = lerp(_respiracao_player.pitch_scale, 1.0, 3.0 * delta)

func _checar_visao(cam) -> bool:
	var player = _get_player()
	if not player:
		return false
	if global_transform.origin.distance_to(cam.global_transform.origin) > 80.0:
		return false
	var cam_pos = cam.global_transform.origin
	var dir_sombra = (global_transform.origin - cam_pos).normalized()
	var dir_camera = -cam.global_transform.basis.z.normalized()
	if dir_camera.dot(dir_sombra) < look_angle_thresh:
		return false
	var result = get_world().direct_space_state.intersect_ray(cam_pos, global_transform.origin, [player, self])
	return result.empty()

## Move em direção ao player via NavigationAgent, com fallback em linha reta.
## Usado no modo APROXIMAR (e evita ficar parada quando o path falha).
func _mover_em_direcao_do_player(player: Node, speed: float) -> void:
	if player == null:
		_vel.x = 0.0
		_vel.z = 0.0
		return
	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	if dist <= dist_minima_player:
		_vel.x = 0.0
		_vel.z = 0.0
		return

	var dir_move = Vector3.ZERO
	if nav_agent:
		_nav_timer_acumulado += get_physics_process_delta_time()
		if _nav_timer_acumulado >= nav_recalculo_intervalo:
			_nav_timer_acumulado = 0.0
			nav_agent.set_target_location(player.global_transform.origin)
		if not nav_agent.is_navigation_finished():
			var proximo = nav_agent.get_next_location()
			dir_move = proximo - global_transform.origin
			dir_move.y = 0.0
			if dir_move.length() < 0.12 and dist > dist_minima_player + 0.5:
				dir_move = Vector3.ZERO

	if dir_move.length() < 0.08:
		dir_move = player.global_transform.origin - global_transform.origin
		dir_move.y = 0.0

	if dir_move.length() > 0.05:
		dir_move = dir_move.normalized()
		_vel.x = dir_move.x * speed
		_vel.z = dir_move.z * speed
	else:
		_vel.x = 0.0
		_vel.z = 0.0

# =============================================================
func _sumir(permitir_efeito_saida: bool) -> void:
	var chance_inv = chance_investida
	if _pressao >= pressao_threshold_agressiva:
		chance_inv = min(chance_inv * pressao_mult_chance_investida, 0.55)
	if permitir_efeito_saida and randf() < chance_inv:
		_investir_e_escurecer()
		return

	# Para TUDO de áudio (grito/respiração) antes de esconder
	if _sfx_player and _sfx_player.playing:
		_sfx_player.stop()
	_parar_respiracao()
	_parar_todos_sussurros()
	_tocar_sfx(som_sumir, volume_sumir)
	_set_atmosfera_camera(false)
	_parar_visuais()
	_parar_flicker_louco()

	hide()
	_ativo = false
	_ativar_atravessar_paredes_caca(false)
	_cacando = false
	_piscando = false
	_stare_down_ativo = false
	_quebra_regra_ativa = false
	_quer_sumir = false
	_vel = Vector3.ZERO
	# NÃO volta pro _pos_inicial se ele for fora da casa (causa grito no void)
	_estacionar_fora_de_jogo()
	_mudar_estado(EstadoSombra.DORMANT)
	emit_signal("sombra_desapareceu")

	if permitir_efeito_saida and not _aguardando_reaparecer and randf() < chance_reaparecer_atras:
		_aguardando_reaparecer = true
		var t = rand_range(tempo_reaparecer_min, tempo_reaparecer_max)
		yield(get_tree().create_timer(t), "timeout")
		_reaparecer_atras_do_player()
		_aguardando_reaparecer = false
		return

	_em_cooldown = true
	var t_cd = cooldown_time
	if _cooldown_override > 0.0:
		t_cd = _cooldown_override
		_cooldown_override = 0.0
	yield(get_tree().create_timer(t_cd), "timeout")
	_em_cooldown = false
	_schedule_next()

func _reaparecer_atras_do_player() -> void:
	var player = _get_player()
	if not player or _desativada_definitivamente or not _desbloqueada:
		_schedule_next()
		return
	var cam = player.get_node_or_null("Camera")
	if not cam:
		_schedule_next()
		return

	var back = cam.global_transform.basis.z.normalized()
	back.y = 0.0
	back = back.normalized()
	var pos_desejada = player.global_transform.origin + back * rand_range(2.0, 3.2)
	# Só aceita posição DENTRO da casa (navmesh + perto de spawn interno)
	var pos = _forcar_posicao_interna(pos_desejada, 4.0)
	if pos == null:
		print("⚠️ Reaparecer atrás cancelado — posição cairia fora da casa")
		_schedule_next()
		return

	global_transform.origin = pos
	look_at(player.global_transform.origin, Vector3.UP)
	_modo_atual = Modo.APROXIMAR
	_ativo = true
	_visivel_timer = 0.0
	_olhando_timer = 0.0
	_stare_down_ativo = false
	_mudar_estado(EstadoSombra.PRESENCE)
	show()
	_iniciar_respiracao()
	_tocar_sfx(som_aparecer, volume_aparecer)
	_set_atmosfera_camera(false)  # só quando o player virar e ver
	print("💀 Sombra reapareceu ATRÁS (posição interna validada)")
	emit_signal("sombra_manifestou", "reaparecer_atras")

func _ponto_periferia_visao():
	var player = _get_player()
	if not player:
		return null
	var cam = player.get_node_or_null("Camera")
	if not cam:
		return null

	var forward = -cam.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right = cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var lado = 1.0 if randf() > 0.5 else -1.0
	# Camada 3: ângulo um pouco mais na borda do FOV (mais sutil)
	var ang = deg2rad(rand_range(72.0, 98.0)) * lado
	var dir = (forward * cos(ang) + right * sin(ang)).normalized()
	var dist = rand_range(3.2, 7.0)
	var pos = player.global_transform.origin + dir * dist
	# Só devolve se a posição for interna (evita silhueta no jardim / rua)
	return _forcar_posicao_interna(pos, 5.0)

## Aparição FALSA na periferia: a Sombra aparece por uma fração de segundo
## no limite do FOV e some ANTES do jogador conseguir olhar de verdade.
## Objetivo: "eu vi alguma coisa?" sem jumpscare.
func _evento_periferia_falsa() -> void:
	if _ativo or _em_cooldown or not _desbloqueada:
		return
	var ponto = _ponto_periferia_visao()
	if ponto == null:
		print("⚠️ Periferia falsa cancelada — cairia fora da casa")
		return

	_ultimo_spawn_foi_periferia = true
	global_transform.origin = ponto
	var player = _get_player()
	if player:
		var look_target = player.global_transform.origin
		look_target.y = global_transform.origin.y
		if look_target.distance_to(global_transform.origin) > 0.15:
			look_at(look_target, Vector3.UP)

	show()
	_ativo = true
	_modo_atual = Modo.OBSERVAR
	_mudar_estado(EstadoSombra.HINTING)
	# SEM respiração e SEM som de aparecer — é só uma silhueta rápida
	print("👁️ Periferia FALSA (silhueta rápida, interna)")
	emit_signal("sombra_manifestou", "periferia_falsa")

	var duracao = rand_range(0.35, 0.85)
	# Se o jogador olhar rápido, some ainda mais cedo
	var t = 0.0
	while t < duracao:
		yield(get_tree(), "idle_frame")
		t += get_process_delta_time()
		var cam = _get_camera()
		if cam and _checar_visao(cam):
			break

	hide()
	_ativo = false
	_parar_respiracao()
	_estacionar_fora_de_jogo()
	_mudar_estado(EstadoSombra.DORMANT)
	emit_signal("sombra_desapareceu")

# =============================================================
func _disparar_efeito(fase: int, forcar: bool = false) -> void:
	if not _desbloqueada:
		return
	var pool := ["bater_porta", "piscar_lanterna", "sussurro", "ambiental", "nenhum"]
	if pool.size() > 1 and pool.has(_ultimo_efeito):
		pool.erase(_ultimo_efeito)

	var efeito = pool[randi() % pool.size()]
	_ultimo_efeito = efeito

	match efeito:
		"bater_porta":
			if randf() < chance_bater_porta or forcar:
				_tentar_bater_porta()
		"piscar_lanterna":
			var bonus = chance_piscar_lanterna_f0_bonus if fase == 0 else 0.0
			if randf() < chance_piscar_lanterna + bonus or forcar:
				_iniciar_piscar_lanterna()
		"sussurro":
			if _audio_ameaca_livre():
				_tocar_sussurro()
				_bloquear_audio_ameaca()
		"ambiental":
			_aplicar_alteracao_ambiental()
		"nenhum":
			pass

# =============================================================
# CAMADA 2 — Alterações ambientais discretas
# A casa muda. O jogo não confirma que foi a Sombra.
# =============================================================
func _schedule_alteracao_ambiental() -> void:
	if _desativada_definitivamente or not _desbloqueada or _timer_alteracao == null:
		return
	# Floor mínimo: Inspector da cena não pode deixar isso spammar
	var mn = max(intervalo_alteracao_min, 80.0)
	var mx = max(intervalo_alteracao_max, mn + 40.0)
	var t = rand_range(mn, mx)
	# Pressão alta = alterações mais frequentes
	if _pressao >= pressao_threshold_agressiva:
		t *= 0.65
	if _laura_assustada_ou_pior():
		t *= 0.80
	_timer_alteracao.start(t)
	print("🏠 Próxima alteração ambiental em %.1fs" % t)

func _tentar_alteracao_ambiental() -> void:
	if _desativada_definitivamente or not _desbloqueada:
		return
	if not _ativo and randf() < min(chance_alteracao_ambiental, 0.20):
		_aplicar_alteracao_ambiental()
	_schedule_alteracao_ambiental()

func _aplicar_alteracao_ambiental() -> void:
	if not _desbloqueada or _cacando or _ativo:
		return

	# Luzes / piscar bem raros: a casa quase nunca mexe em luz sozinha
	# (antes piscava o tempo todo e ficava ruim). Peso alto em nada/porta.
	var pool = ["porta_longe", "nada_ambiental", "nada_ambiental", "nada_ambiental", "nada_ambiental", "nada_ambiental"]
	# Chance baixa de incluir evento de luz nesta alteração
	if randf() < 0.12:
		pool.append("luz_distante")
	if randf() < 0.06:
		pool.append("lamp_maluca")
	if _ultima_alteracao_tipo != "" and pool.has(_ultima_alteracao_tipo):
		pool.erase(_ultima_alteracao_tipo)

	var escolha = pool[randi() % pool.size()]
	_ultima_alteracao_tipo = escolha
	print("🏠 Alteração ambiental: ", escolha)
	emit_signal("sombra_manifestou", "alteracao_" + escolha)

	match escolha:
		"porta_longe":
			_alterar_porta(false)   # porta longe do player
		"porta_perto":
			_alterar_porta(true)    # porta mais próxima
		"luz_distante":
			_alterar_luz_distante()
		"lamp_maluca":
			_tentar_lamp_maluca()
		"nada_ambiental":
			pass

func _alterar_porta(perto: bool) -> void:
	var player = _get_player()
	if not player:
		return
	var candidatas = []
	for node in get_tree().get_nodes_in_group("interagivel"):
		if not node.has_method("bater_porta"):
			continue
		var dist = player.global_transform.origin.distance_to(node.global_transform.origin)
		if perto:
			if dist < 9.0 and dist > 1.5:
				candidatas.append(node)
		else:
			if dist >= 9.0 and dist < 22.0:
				candidatas.append(node)
	if candidatas.empty():
		# fallback: qualquer porta
		for node in get_tree().get_nodes_in_group("interagivel"):
			if node.has_method("bater_porta"):
				candidatas.append(node)
	if candidatas.empty():
		return
	var porta = candidatas[randi() % candidatas.size()]
	porta.bater_porta()
	print("🏠 Porta alterada: ", porta.name)

func _alterar_luz_distante() -> void:
	if not lamps:
		return
	var player = _get_player()
	var candidatas = []
	for luz in lamps.get_children():
		if not (luz is SpotLight or luz is OmniLight):
			continue
		if luz.name == "lamp_quartinho":
			continue
		if player:
			var dist = player.global_transform.origin.distance_to(luz.global_transform.origin)
			if dist > 6.0:  # só luzes relativamente longe
				candidatas.append(luz)
		else:
			candidatas.append(luz)
	if candidatas.empty():
		return
	var luz = candidatas[randi() % candidatas.size()]
	# Toggle discreto + sincroniza mesh do lightswitch
	luz.visible = not luz.visible
	_sincronizar_lightswitch_da_luz(luz, true)
	print("🏠 Luz alterada: ", luz.name, " → ", luz.visible)
	# Às vezes volta depois de alguns segundos (sensação de "alguém passou")
	if randf() < 0.55:
		var t = rand_range(4.0, 11.0)
		yield(get_tree().create_timer(t), "timeout")
		if is_instance_valid(luz):
			luz.visible = not luz.visible
			_sincronizar_lightswitch_da_luz(luz, true)

func _tentar_lamp_maluca() -> void:
	for node in get_tree().get_nodes_in_group("interagivel"):
		if node.has_method("forcar_piscar"):
			node.forcar_piscar()
			print("🏠 lamp_maluca forçada a piscar")
			return
		if node.has_method("tentar_iniciar_piscar"):
			node.tentar_iniciar_piscar()
			print("🏠 lamp_maluca tentou piscar")
			return

## Mantém o mesh do interruptor igual ao estado da luz
func _sincronizar_lightswitch_da_luz(luz: Node, tocar_som: bool = false) -> void:
	if luz == null:
		return
	var nome_luz = luz.name
	for sw in get_tree().get_nodes_in_group("lightswitch"):
		if not is_instance_valid(sw):
			continue
		# Match por export nome_lampada ou pelo node da lâmpada
		var nome_cfg = ""
		if "nome_lampada" in sw:
			nome_cfg = str(sw.nome_lampada)
		if nome_cfg == nome_luz or (sw.get("lampada") == luz):
			if sw.has_method("forcar_estado"):
				sw.forcar_estado(luz.visible, tocar_som)
			elif sw.has_method("sincronizar_com_lampada"):
				sw.sincronizar_com_lampada(tocar_som)
			return

# =============================================================
# Atmosfera na câmera (shader mais escuro/pesado)
# =============================================================
func _set_atmosfera_camera(visivel: bool) -> void:
	var cam = _get_camera()
	if cam == null:
		return
	if cam.has_method("set_sombra_visivel"):
		cam.set_sombra_visivel(visivel)
	elif cam.has_method("aplicar_atmosfera_sombra"):
		cam.aplicar_atmosfera_sombra(visivel)

# =============================================================
# VISUAIS / ANIMAÇÕES (.glb em cenas separadas)
# =============================================================
func _setup_visuais() -> void:
	# Esconde o modelo antigo em T-pose (Armature / Civ001). A partir de agora
	# só idle_shadow / running_crawl_shadow representam a sombra.
	_esconder_modelo_antigo()

	# 1) Filhos já instanciados na cena da Sombra (recomendado)
	_no_idle = get_node_or_null(nome_no_idle)
	_no_running = get_node_or_null(nome_no_running)
	if _no_idle == null:
		_no_idle = find_node(nome_no_idle, true, false)
	if _no_running == null:
		_no_running = find_node(nome_no_running, true, false)

	# Fallback por nome parcial (Godot às vezes trunca no painel)
	if _no_idle == null or _no_running == null:
		for c in get_children():
			var n = String(c.name).to_lower()
			if _no_idle == null and ("idle" in n and "shadow" in n):
				_no_idle = c
			if _no_running == null and ("running" in n or "crawl" in n):
				_no_running = c

	# 2) Se não tem filhos, instancia a partir dos PackedScene exportados
	if _no_idle == null and cena_idle != null:
		_garantir_visual_holder()
		_no_idle = cena_idle.instance()
		_no_idle.name = nome_no_idle
		_visual_holder.add_child(_no_idle)
	if _no_running == null and cena_running != null:
		_garantir_visual_holder()
		_no_running = cena_running.instance()
		_no_running.name = nome_no_running
		_visual_holder.add_child(_no_running)

	# Zera transform local e desliga root motion pra não “andar sozinho”
	_preparar_no_visual(_no_idle)
	_preparar_no_visual(_no_running)

	# Começa escondido (a sombra inteira também começa hide())
	if _no_idle:
		_set_no_visivel(_no_idle, false)
	if _no_running:
		_set_no_visivel(_no_running, false)

	_modo_visual_atual = ""
	if _no_idle or _no_running:
		print("💀 Visuais da sombra OK | idle=%s (%s) | running=%s (%s)" % [
			str(_no_idle != null), str(_no_idle.name) if _no_idle else "-",
			str(_no_running != null), str(_no_running.name) if _no_running else "-"
		])
	else:
		print("💀 AVISO: nenhum visual idle/running encontrado. Coloque as cenas .glb como filhas (idle_shadow / running_crawl_shadow) ou preencha cena_idle / cena_running no Inspector.")

func _esconder_modelo_antigo() -> void:
	# Esconde SÓ o T-pose antigo (filhos diretos do KinematicBody).
	# NUNCA usa find_node recursivo — senão esconde o Armature DENTRO de
	# idle_shadow / running_crawl_shadow e a sombra some (só respiração).
	for c in get_children():
		var nl = String(c.name).to_lower()
		# Não mexe nos modelos animados
		if "idle" in nl or "running" in nl or "crawl" in nl:
			continue
		if not (c is Spatial):
			continue
		# Armature / Civ001 / mesh estático antigo
		if "armature" in nl or "skeleton" in nl or "civ001" in nl or nl == "civ" or c is MeshInstance:
			c.visible = false
			# Também esconde netos óbvios do T-pose (Civ001 dentro do Armature)
			for sub in c.get_children():
				if sub is Spatial:
					var sn = String(sub.name).to_lower()
					if "civ" in sn or sub is MeshInstance:
						sub.visible = false

func _preparar_no_visual(no: Node) -> void:
	if no == null:
		return
	if no is Spatial:
		# Fica no mesmo ponto do KinematicBody (sem offset herdado do GLB)
		no.translation = Vector3.ZERO
		# GLB costuma olhar +Z; look_at no body usa -Z → precisa compensar 180°
		no.rotation_degrees = Vector3(0.0, mesh_yaw_offset_deg, 0.0)
	# Força loop + remove root motion das animações do modelo
	var ap = no.get_node_or_null("AnimationPlayer")
	if ap == null:
		ap = no.find_node("AnimationPlayer", true, false)
	if ap != null and ap is AnimationPlayer:
		_preparar_animation_player(ap)

func _preparar_animation_player(ap: AnimationPlayer) -> void:
	if ap == null:
		return
	for nome in ap.get_animation_list():
		var anim = ap.get_animation(nome)
		if anim == null:
			continue
		# Loop sempre (animação de 2s não pode parar no meio da caça)
		anim.loop = true
		# Remove tracks de posição/transform na raiz (root motion do GLB)
		# que fazem o mesh "dar um passo e voltar"
		for i in range(anim.get_track_count() - 1, -1, -1):
			var tipo = anim.track_get_type(i)
			var path_str = str(anim.track_get_path(i)).to_lower()
			# Transform tracks no root / armature = root motion
			if tipo == Animation.TYPE_TRANSFORM:
				# Zera posição em todas as keys, mantém rotação/scale da pose
				var kc = anim.track_get_key_count(i)
				for k in range(kc):
					var xf = anim.track_get_key_value(i, k)
					if xf is Transform:
						xf.origin = Vector3.ZERO
						anim.track_set_key_value(i, k, xf)
			# Value tracks de translation
			elif tipo == Animation.TYPE_VALUE:
				if path_str.ends_with(":translation") or path_str.ends_with(":transform:origin"):
					var kc2 = anim.track_get_key_count(i)
					for k2 in range(kc2):
						anim.track_set_key_value(i, k2, Vector3.ZERO)

func _ancorar_visual(no: Node) -> void:
	# A animação de crawl TEM root motion (mesh anda pra frente e no loop volta).
	# Movimento real = KinematicBody. Mesh fica SEMPRE em (0,0,0) local.
	if no == null or not (no is Spatial):
		return
	no.translation = Vector3.ZERO
	no.rotation_degrees.y = mesh_yaw_offset_deg
	_zerar_root_motion_recursivo(no, 0)

func _zerar_root_motion_recursivo(no: Node, profundidade: int) -> void:
	# Zera translation em Armature/Root/Hips (não em bones do Skeleton)
	if no == null or profundidade > 4:
		return
	for c in no.get_children():
		if c is Skeleton:
			# Skeleton: zera só o bone raiz se possível vira bagunça — só translation do node
			continue
		if c is Spatial:
			var cn = String(c.name).to_lower()
			if ("armature" in cn or "root" in cn or "rig" in cn or "hips" in cn
					or "pelvis" in cn or "crawler" in cn or profundidade == 0):
				# Não zera meshs genéricos profundos demais — só raízes de hierarquia
				if profundidade <= 2:
					c.translation = Vector3.ZERO
			_zerar_root_motion_recursivo(c, profundidade + 1)

func _garantir_visual_holder() -> void:
	if _visual_holder != null and is_instance_valid(_visual_holder):
		return
	_visual_holder = get_node_or_null("VisualHolder")
	if _visual_holder == null:
		_visual_holder = Spatial.new()
		_visual_holder.name = "VisualHolder"
		add_child(_visual_holder)

func _set_no_visivel(no: Node, visivel: bool) -> void:
	if no == null:
		return
	if no is Spatial or no is CanvasItem:
		no.visible = visivel
	# Ao mostrar, garante que filhos (Armature/mesh do GLB) não fiquem invisíveis
	# por causa de hide anterior errado
	if visivel:
		_forcar_visivel_recursivo(no)

func _forcar_visivel_recursivo(no: Node) -> void:
	if no == null:
		return
	if no is Spatial or no is CanvasItem:
		no.visible = true
	for c in no.get_children():
		_forcar_visivel_recursivo(c)

func _tocar_anim_no_modelo(no: Node, preferencia: String = "") -> void:
	# Toca animação em LOOP até a sombra sumir / trocar de modo
	if no == null:
		return
	var ap = no.get_node_or_null("AnimationPlayer")
	if ap == null:
		ap = no.find_node("AnimationPlayer", true, false)
	if ap == null:
		return
	var nome = preferencia
	if nome == "" or not ap.has_animation(nome):
		var lista = ap.get_animation_list()
		if lista.empty():
			return
		nome = lista[0]
	# Garante loop mesmo se o import veio sem
	if ap.has_animation(nome):
		var anim = ap.get_animation(nome)
		if anim:
			anim.loop = true
	if ap.current_animation == nome and ap.is_playing():
		return
	ap.play(nome)

func _mostrar_visual(modo: String) -> void:
	# modo: "idle" | "running"
	if modo == _modo_visual_atual:
		# só garante que a animação interna do glb continue tocando
		if modo == "idle" and _no_idle:
			_tocar_anim_no_modelo(_no_idle, anim_idle)
		elif modo == "running" and _no_running:
			_tocar_anim_no_modelo(_no_running, anim_running)
		return

	_modo_visual_atual = modo

	# Garante que o T-pose antigo continue escondido
	_esconder_modelo_antigo()

	if modo == "running":
		if _no_running:
			_ancorar_visual(_no_running)
			_set_no_visivel(_no_running, true)
			_tocar_anim_no_modelo(_no_running, anim_running)
		if _no_idle:
			_set_no_visivel(_no_idle, false)
		# Fallback AnimationPlayer único
		if _no_running == null and anim_player != null and anim_player is AnimationPlayer:
			if anim_player.has_animation(anim_running):
				anim_player.play(anim_running)
	else:
		# idle — parado, só olhando o jogador (rotação fica no KinematicBody)
		if _no_idle:
			_ancorar_visual(_no_idle)
			_set_no_visivel(_no_idle, true)
			_tocar_anim_no_modelo(_no_idle, anim_idle)
		if _no_running:
			_set_no_visivel(_no_running, false)
		if _no_idle == null and anim_player != null and anim_player is AnimationPlayer:
			if anim_player.has_animation(anim_idle):
				anim_player.play(anim_idle)

func _tocar_anim(nome: String) -> void:
	# Compat: chamadas antigas (anim_idle / anim_running) viram troca de visual
	if nome == anim_running or nome == "running" or nome == nome_no_running:
		_mostrar_visual("running")
	else:
		_mostrar_visual("idle")

func _atualizar_animacao_movimento() -> void:
	# Running SÓ na caçada. Aproximar / observar / flash = sempre idle
	# (mesmo andando devagar no modo APROXIMAR)
	if _cacando:
		_mostrar_visual("running")
	else:
		_mostrar_visual("idle")

func _parar_visuais() -> void:
	_modo_visual_atual = ""
	if _no_idle:
		_set_no_visivel(_no_idle, false)
	if _no_running:
		_set_no_visivel(_no_running, false)
	# anim_player pode ter resolvido pra Spatial errado — só chama se for AnimationPlayer de verdade
	if anim_player != null and anim_player is AnimationPlayer:
		if anim_player.is_playing():
			anim_player.stop()

# =============================================================
# CAÇADA + BLACKOUT
# =============================================================
func iniciar_caca() -> void:
	if _cacando or _desativada_definitivamente or not _desbloqueada:
		return
	var player = _get_player()
	if player == null:
		return

	_parar_todos_sussurros()
	_bloquear_audio_ameaca()

	# Posiciona ANTES de ativar grito/visual — se falhar, nem começa
	_caca_pela_frente = randf() < chance_caca_pela_frente
	var pos_antes = global_transform.origin
	_posicionar_para_caca(player, _caca_pela_frente)

	var pos_chk = global_transform.origin
	# Se o posicionamento não moveu a sombra (falhou), aborta
	if pos_chk.distance_to(pos_antes) < 0.05 and spawn_points == null:
		print("⚠️ Caça nem começou — sem ShadowSpawnPoints")
		_estacionar_fora_de_jogo()
		hide()
		_ativo = false
		_cacando = false
		_schedule_next()
		return

	var pos_nav = _snap_ao_navmesh(pos_chk)
	var dist_snap = Vector2(pos_nav.x, pos_nav.z).distance_to(Vector2(pos_chk.x, pos_chk.z))
	if dist_snap > 3.5:
		# Último recurso: Position3D mais perto do player
		var fallback = _spawn_mais_proximo_de(player.global_transform.origin, player.global_transform.origin)
		if fallback == null:
			print("⚠️ Caça nem começou — sem ponto válido (snap %.1fm)" % dist_snap)
			_estacionar_fora_de_jogo()
			hide()
			_ativo = false
			_cacando = false
			_schedule_next()
			return
		pos_nav = _snap_ao_navmesh(fallback.global_transform.origin)
		print("💀 Caça: fallback final no spawn '%s'" % fallback.name)

	global_transform.origin = pos_nav
	_altura_chao_atual = pos_nav.y
	_vel = Vector3.ZERO

	_cacando = true
	_tempo_caca = 0.0
	_quer_sumir = false
	_nav_timer_acumulado = 0.0
	_ativar_atravessar_paredes_caca(true)
	_mudar_estado(EstadoSombra.MANIFEST)
	_ativo = true
	show()
	# FORÇA running (nunca idle na caça)
	_modo_visual_atual = ""
	_mostrar_visual("running")

	# Path pro player JÁ no frame 0 — caça não espera o player chegar perto
	if nav_agent:
		nav_agent.set_target_location(player.global_transform.origin)
	# Garante velocidade inicial na direção do player (fallback até o nav responder)
	var dir0 = player.global_transform.origin - global_transform.origin
	dir0.y = 0.0
	if dir0.length() > 0.1:
		dir0 = dir0.normalized()
		_vel.x = dir0.x * velocidade_caca
		_vel.z = dir0.z * velocidade_caca
	else:
		_vel = Vector3.ZERO

	_iniciar_respiracao_caca()

	if _sfx_player:
		_sfx_player.unit_db = volume_grito
		_sfx_player.max_distance = 60.0
	if _respiracao_player:
		_respiracao_player.max_distance = 40.0

	if _caca_pela_frente:
		if som_grito_caca and _sfx_player:
			_sfx_player.stream = som_grito_caca
			_sfx_player.unit_db = volume_grito
			_sfx_player.play()
		print("💀 CAÇADA PELA FRENTE — grito + respiração!")
		emit_signal("sombra_manifestou", "inicio_caca_frente")
	else:
		print("💀 CAÇADA POR TRÁS — só respiração")
		emit_signal("sombra_manifestou", "inicio_caca_atras")

func _posicionar_para_caca(player: Node, pela_frente: bool) -> void:
	# Estratégia:
	# 1) Tenta nascer 5–8 m NA FRENTE ou ATRÁS do player (direção da câmera)
	# 2) Se a posição final ficar < dist_minima_spawn_caca_player do player
	#    (player em cima do spawn / snap ruim / navmesh) → escolhe outro
	#    Position3D de ShadowSpawnPoints próximo da intenção, NUNCA o que o player está.
	# 3) Sempre valida distância mínima final.
	if player == null:
		return

	var pos_player = player.global_transform.origin
	var dist = rand_range(dist_spawn_caca_min, dist_spawn_caca_max)
	var forward = Vector3(0, 0, -1)
	var cam = player.get_node_or_null("Camera")
	if cam:
		forward = -cam.global_transform.basis.z
	else:
		forward = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.05:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()

	# Frente = na direção do olhar; atrás = oposto
	var dir = forward if pela_frente else -forward
	var pos_desejada = pos_player + dir * dist
	pos_desejada.y = pos_player.y

	var min_ok = dist_minima_spawn_caca_player
	var pos_final = Vector3.ZERO
	var usou_relativo = false

	# Tenta a posição relativa (frente/atrás) se estiver no navmesh E longe o bastante
	var pos_nav = _snap_ao_navmesh(pos_desejada)
	var ok_relativo = _pos_esta_no_navmesh(pos_nav, pos_desejada)
	var d_rel = pos_nav.distance_to(pos_player)
	if ok_relativo and d_rel >= min_ok:
		pos_final = pos_nav
		usou_relativo = true
		print("💀 Spawn caça [%s] relativo ao player (%.1fm)" % [
			"FRENTE" if pela_frente else "ATRÁS", d_rel
		])
	else:
		# Relativo inválido ou player em cima → Position3D seguro (longe do player)
		var ponto = _spawn_mais_proximo_de(pos_desejada, pos_player, min_ok)
		if ponto == null:
			# Última tentativa: qualquer spawn com distância mínima (mesmo se longe da intenção)
			ponto = _spawn_mais_proximo_de(pos_player, pos_player, min_ok)
		if ponto == null:
			print("⚠️ Caça: nenhum ShadowSpawnPoint válido longe do player — abortando")
			return
		var p_nav = _snap_ao_navmesh(ponto.global_transform.origin)
		var d_pl = p_nav.distance_to(pos_player)
		# Se o snap ainda colou no player, tenta o próximo candidato
		if d_pl < min_ok:
			var ponto2 = _spawn_mais_proximo_de(pos_desejada, pos_player, min_ok + 1.5)
			if ponto2 != null and ponto2 != ponto:
				p_nav = _snap_ao_navmesh(ponto2.global_transform.origin)
				d_pl = p_nav.distance_to(pos_player)
				ponto = ponto2
		if d_pl < min_ok * 0.6:
			print("⚠️ Caça: spawn ainda colado no player (%.1fm) — abortando" % d_pl)
			return
		pos_final = p_nav
		print("💀 Spawn caça [%s] via Position3D '%s' (%.1fm do player)" % [
			"FRENTE" if pela_frente else "ATRÁS", ponto.name, d_pl
		])

	# Segurança final: nunca aceitar posição em cima do player
	if pos_final.distance_to(pos_player) < min_ok * 0.55:
		print("⚠️ Caça: posição final inválida (%.1fm) — abortando" % pos_final.distance_to(pos_player))
		return

	global_transform.origin = pos_final
	_altura_chao_atual = pos_final.y

	var look_target = pos_player
	look_target.y = global_transform.origin.y
	if look_target.distance_to(global_transform.origin) > 0.2:
		look_at(look_target, Vector3.UP)

## Escolhe o Position3D de ShadowSpawnPoints mais próximo de `alvo`.
## Nunca escolhe ponto em que o player está (distância < min_dist_player).
## min_dist_player padrão = dist_minima_spawn_caca_player (ou 3.5 se não setado).
func _spawn_mais_proximo_de(alvo: Vector3, pos_player: Vector3 = Vector3.ZERO, min_dist_player: float = -1.0):
	var lista = _listar_todos_spawns()
	if lista.empty():
		return null
	if min_dist_player < 0.0:
		min_dist_player = max(dist_minima_spawn_caca_player, 3.5)

	var melhor = null
	var melhor_d = 99999.0
	var candidatos_ok = []
	for p in lista:
		if not (p is Spatial):
			continue
		var pos = p.global_transform.origin
		# Nunca nascer no mesmo ponto (ou colado) do player
		if pos_player != Vector3.ZERO:
			var d_pl = pos.distance_to(pos_player)
			if d_pl < min_dist_player:
				continue
		candidatos_ok.append(p)
		var d = pos.distance_to(alvo)
		if d < melhor_d:
			melhor_d = d
			melhor = p

	if melhor != null:
		return melhor

	# Se nenhum passou o min_dist, pega o mais LONGE do player (nunca o de baixo dele)
	if pos_player != Vector3.ZERO and lista.size() > 0:
		var mais_longe = null
		var max_d = -1.0
		for p in lista:
			if not (p is Spatial):
				continue
			var d_pl = p.global_transform.origin.distance_to(pos_player)
			if d_pl > max_d:
				max_d = d_pl
				mais_longe = p
		if mais_longe != null and max_d >= 2.0:
			return mais_longe

	# Último recurso: qualquer um
	if lista.size() > 0:
		return lista[0]
	return null

## Todos os Position3D filhos de ShadowSpawnPoints (exceto marcados explicitamente "fora")
func _listar_todos_spawns() -> Array:
	var lista = []
	if spawn_points == null:
		return lista
	for ponto in spawn_points.get_children():
		if not (ponto is Spatial):
			continue
		var amb = _get_ambiente(ponto)
		if amb == "fora":
			continue
		lista.append(ponto)
	return lista

func _iniciar_respiracao_caca() -> void:
	if not audio_respiracao or not _respiracao_player:
		return
	_respiracao_player.bus = "SFX"  # 3D espacial — sem pan bus artificial
	_respiracao_player.stream = audio_respiracao
	_respiracao_player.pitch_scale = respiracao_pitch_caca
	_respiracao_player.unit_db = respiracao_vol_caca_inicio
	_respiracao_player.max_distance = max(respiracao_caca_ramp_dist * 1.4, 16.0)
	if not _respiracao_player.playing:
		_respiracao_player.play()

func _atualizar_respiracao_caca(delta: float, dist: float) -> void:
	if _respiracao_player == null or not audio_respiracao:
		return
	# Volume sobe conforme se aproxima — a posição 3D já localiza o som
	var t = 1.0 - clamp(dist / max(respiracao_caca_ramp_dist, 0.1), 0.0, 1.0)
	t = t * t  # curva mais agressiva perto
	var vol_alvo = lerp(respiracao_vol_caca_inicio, respiracao_vol_caca_perto, t)
	_respiracao_player.unit_db = lerp(_respiracao_player.unit_db, vol_alvo, 3.5 * delta)
	_respiracao_player.pitch_scale = lerp(_respiracao_player.pitch_scale, respiracao_pitch_caca, 4.0 * delta)

func _set_respiracao_pan_caca() -> void:
	# Usa o bus de pan dos sussurros se existir; senão ignora
	var idx = AudioServer.get_bus_index(_panner_bus_name)
	if idx == -1:
		return
	var player = _get_player()
	if player == null:
		return
	# Só redireciona o player de respiração pro bus de pan durante a caça
	if _respiracao_player and _respiracao_player.bus != _panner_bus_name:
		_respiracao_player.bus = _panner_bus_name
	var to_sombra = global_transform.origin - player.global_transform.origin
	to_sombra.y = 0.0
	var cam = player.get_node_or_null("Camera")
	var right = Vector3(1, 0, 0)
	if cam:
		right = cam.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
	var pan = 0.0
	if to_sombra.length() > 0.1:
		pan = clamp(to_sombra.normalized().dot(right), -1.0, 1.0)
	for i in range(AudioServer.get_bus_effect_count(idx)):
		var fx = AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectPanner:
			fx.pan = pan
			break

func _processar_caca(delta: float) -> void:
	if not _cacando:
		return
	_tempo_caca += delta
	var player = _get_player()
	if player == null:
		return
	_ativo = true
	show()
	_tocar_anim(anim_running)
	_atualizar_flicker_louco(delta, true)

	var dir = player.global_transform.origin - global_transform.origin
	dir.y = 0.0
	var dist = dir.length()
	_atualizar_respiracao_caca(delta, dist)

	# Contato ANTES de continuar andando — evita a sombra empurrar/arrastar o player
	if _tempo_caca >= tempo_min_caca_antes_contato:
		if _detectou_contato_player(player, dist):
			_vel = Vector3.ZERO
			_impacto_caca()
			return

	# --- Movimento contínuo até o player (NavigationMesh + fallback) ---
	# A animação só visualiza o crawl; o KinematicBody é quem anda de verdade.
	# IMPORTANTE: se o nav não devolver path, SEMPRE vai em linha reta pro player
	# (antes só fazia isso com dist < 6m → ficava parada com anim running longe).
	var dir_move = Vector3.ZERO
	if nav_agent:
		_nav_timer_acumulado += delta
		# Recalcula path com frequência; no começo da caça força já no 1º frame
		if _nav_timer_acumulado >= 0.08 or _tempo_caca < 0.2:
			_nav_timer_acumulado = 0.0
			nav_agent.set_target_location(player.global_transform.origin)
		if not nav_agent.is_navigation_finished():
			var proximo = nav_agent.get_next_location()
			dir_move = proximo - global_transform.origin
			dir_move.y = 0.0
			# Path “parado” (próximo ponto colado nela) enquanto player ainda longe → ignora
			if dir_move.length() < 0.12 and dist > 1.2:
				dir_move = Vector3.ZERO
	# Atravessando paredes: sempre linha reta pro player (navmesh só atrapalha)
	if caca_atravessa_paredes:
		dir_move = dir
	# Fallback SEMPRE: sem path útil, corre em linha reta atrás do player (qualquer distância)
	elif dir_move.length() < 0.08:
		dir_move = dir
	if dir_move.length() > 0.05:
		dir_move = dir_move.normalized()
		_vel.x = dir_move.x * velocidade_caca
		_vel.z = dir_move.z * velocidade_caca
	else:
		# Quase em cima: ainda empurra um pouco pra garantir contato
		if dist > 0.3 and dir.length() > 0.05:
			var d = dir.normalized()
			_vel.x = d.x * velocidade_caca
			_vel.z = d.z * velocidade_caca
		else:
			_vel.x = 0.0
			_vel.z = 0.0

	var look_target = player.global_transform.origin
	look_target.y = global_transform.origin.y
	if look_target.distance_to(global_transform.origin) > 0.2:
		look_at(look_target, Vector3.UP)

	# Sem gravidade — trava Y no chão/navmesh
	_vel.y = 0.0
	if caca_atravessa_paredes:
		# Entidade: atravessa paredes em linha reta até o player
		global_translate(Vector3(_vel.x * delta, 0.0, _vel.z * delta))
	else:
		move_and_slide(_vel, Vector3.UP)
	_travar_no_chao()

	# Segurança: caça não pode continuar fora da casa
	if not _posicao_ainda_interna():
		print("⚠️ Caça abortada — sombra saiu da área interna")
		_vel = Vector3.ZERO
		_ativar_atravessar_paredes_caca(false)
		_cacando = false
		_sumir(false)
		return

	# Sempre running durante a caça
	_mostrar_visual("running")
	_ancorar_visual(_no_running)

	# Checagem de novo depois do slide (pega colisão física deste frame)
	if _tempo_caca >= tempo_min_caca_antes_contato:
		if _detectou_contato_player(player, global_transform.origin.distance_to(player.global_transform.origin)):
			_vel = Vector3.ZERO
			_impacto_caca()
			return
	# Caça NÃO acaba por tempo nem por luz — só por contato

func _detectou_contato_player(player: Node, dist: float) -> bool:
	if player == null:
		return false

	# 1) Colisão no KinematicBody da sombra (CollisionShape tem que ser FILHO DESTE body)
	for i in range(get_slide_count()):
		var col = get_slide_collision(i)
		if col == null or col.collider == null:
			continue
		if _collider_eh_player(col.collider, player):
			print("💀 Contato via slide_collision")
			return true

	# 2) Area de contato no próprio body (ex.: nó "ContatoArea")
	for n in get_children():
		if not (n is Area):
			continue
		if not n.monitoring:
			continue
		for b in n.get_overlapping_bodies():
			if _collider_eh_player(b, player):
				print("💀 Contato via Area no body")
				return true

	# 3) Area dentro do visual running (se collision_layer/mask estiverem certos)
	if _no_running:
		for n in _no_running.get_children():
			if not (n is Area):
				continue
			if not n.monitoring:
				continue
			for b in n.get_overlapping_bodies():
				if _collider_eh_player(b, player):
					print("💀 Contato via Area no running")
					return true

	# 4) Fallback de distância (bem apertado) — garante o impacto mesmo se slide/Area falharem
	if dist <= dist_contato_caca:
		print("💀 Contato via distância (%.2fm <= %.2f)" % [dist, dist_contato_caca])
		return true

	return false

func _collider_eh_player(c: Node, player: Node) -> bool:
	if c == null:
		return false
	if c == player:
		return true
	if c.is_in_group("player"):
		return true
	var p = c.get_parent()
	var guard = 0
	while p and guard < 8:
		if p == player or p.is_in_group("player"):
			return true
		p = p.get_parent()
		guard += 1
	return false

func _impacto_caca() -> void:
	# Contato na caçada = tela preta → crise
	print("💀 IMPACTO DA CAÇADA — tela preta + crise!")
	_ativar_atravessar_paredes_caca(false)
	_cacando = false
	_tempo_caca = 0.0
	if _sfx_player and _sfx_player.playing:
		_sfx_player.stop()
	_parar_respiracao()
	_parar_flicker_louco()
	if _respiracao_player:
		_respiracao_player.pitch_scale = 1.0
		_respiracao_player.bus = "SFX"

	var player = _get_player()
	var cam = null
	if player:
		cam = player.get_node_or_null("Camera")

	_tensao = tensao_max
	if cam:
		# Crise ANTES do fade pra quando a tela voltar já estar em EM_CRISE
		if cam.has_method("forcar_crise"):
			cam.forcar_crise()
		if cam.has_method("jumpscare_escurecer"):
			# Preto um pouco mais longo + retorno gradual
			cam.jumpscare_escurecer(1.4, 3.2)

	_apagar_luzes_exceto_quartinho()
	_fechar_e_trancar_quartinho()
	_iniciar_blackout()

	emit_signal("sombra_manifestou", "caca_impacto")
	_cooldown_override = cooldown_apos_caca
	_sumir(false)

func _encerrar_caca(escapou: bool) -> void:
	_ativar_atravessar_paredes_caca(false)
	_cacando = false
	_tempo_caca = 0.0
	_caca_pela_frente = false
	if _sfx_player and _sfx_player.playing:
		_sfx_player.stop()
	_parar_flicker_louco()
	_tocar_anim(anim_idle)
	if _respiracao_player:
		_respiracao_player.pitch_scale = 1.0
		_respiracao_player.bus = "SFX"
	# Tempo esgotado: some sem prender / sem blackout forçado
	print("💀 Caçada encerrada (tempo)")
	emit_signal("sombra_manifestou", "caca_tempo")
	_cooldown_override = cooldown_apos_caca
	_sumir(false)

func _iniciar_blackout() -> void:
	# Apaga as luzes UMA vez (exceto quartinho), mas NÃO bloqueia o jogador
	# de religar — ele precisa achar luz pra sair da crise.
	_blackout_ativo = true
	_blackout_restante = rand_range(blackout_duracao_min, blackout_duracao_max)
	_luzes_antes_blackout.clear()
	_apagar_luzes_exceto_quartinho()
	# Nunca bloqueia os interruptores — o player precisa se acalmar na luz
	if typeof(Global) != TYPE_NIL:
		Global.luzes_bloqueadas = false
	print("💀 Blackout visual (luzes apagadas, interruptores LIVRES) por %.0fs" % _blackout_restante)

func _processar_blackout(delta: float) -> void:
	if not _blackout_ativo:
		return
	_blackout_restante -= delta
	# Garante quartinho sempre aceso durante o blackout
	_garantir_luz_quartinho_acesa()
	if _blackout_restante <= 0.0:
		_blackout_ativo = false
		if typeof(Global) != TYPE_NIL:
			Global.luzes_bloqueadas = false
		_garantir_luz_quartinho_acesa()
		print("💀 Blackout acabou — interruptores livres")
		emit_signal("sombra_manifestou", "fim_blackout")

func esta_em_blackout() -> bool:
	return _blackout_ativo

# Chance rara de iniciar caçada ao spawnar presença.
# Se nasceu LONGE (outro lado da casa), chance bem maior de sair correndo/gritando.
func _tentar_iniciar_caca_no_spawn() -> void:
	if _cacando or _blackout_ativo:
		return
	var player = _get_player()
	if player == null:
		return

	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	var nasceu_longe = dist >= distancia_minima_corrida

	# Corrida de longe: nasceu no outro lado da casa → chance dedicada de sair gritando atrás
	if nasceu_longe and _pressao >= pressao_threshold_agressiva * 0.7:
		if randf() < chance_corrida_de_longe:
			print("💀 CORRIDA DE LONGE (%.1fm) — sombra vem gritando!" % dist)
			iniciar_caca()
			return

	# Caçada normal (mais rara) — só com pressão alta
	if _pressao < pressao_threshold_agressiva:
		return
	if randf() < chance_iniciar_caca:
		iniciar_caca()

func _parar_todos_sussurros() -> void:
	for s in _sussurros:
		if s != null and s.playing:
			s.stop()
	# Para também nós filhos legados
	for child in get_children():
		if child is AudioStreamPlayer and "sussurro" in String(child.name).to_lower():
			if child.playing:
				child.stop()

func _tocar_sussurro() -> void:
	# Durante aparição/caça: sem sussurro (já tem respiração/grito)
	if _ativo or _cacando:
		return
	if _sussurros.empty():
		print("💀 Nenhum sussurro configurado")
		return
	# Nunca empilha sussurros
	_parar_todos_sussurros()
	var disponiveis = []
	for s in _sussurros:
		if s.stream != null and not s.playing:
			disponiveis.append(s)
	if disponiveis.empty():
		return

	_set_sussurro_pan_inteligente()

	var porcentagens = [peso_sussurro_1, peso_sussurro_2, peso_sussurro_3, peso_sussurro_4, peso_sussurro_5]
	var total := 0.0
	for i in range(disponiveis.size()):
		var idx = _sussurros.find(disponiveis[i])
		var pct = porcentagens[idx] if idx < porcentagens.size() else 0.0
		total += max(pct, 0.0)

	if total <= 0.0:
		disponiveis[randi() % disponiveis.size()].play()
		print("💀 Sussurro (pan inteligente)")
		return

	var r = randf() * total
	var acc := 0.0
	for i in range(disponiveis.size()):
		var idx = _sussurros.find(disponiveis[i])
		var pct = porcentagens[idx] if idx < porcentagens.size() else 0.0
		acc += max(pct, 0.0)
		if r <= acc:
			disponiveis[i].play()
			print("💀 Sussurro (pan inteligente)")
			return
	disponiveis.back().play()

# --- Sussurro isolado ---
func _schedule_sussurro_isolado() -> void:
	if _desativada_definitivamente or not _desbloqueada:
		return
	var t : float
	if randf() < silencio_sussurro_longo_chance:
		t = rand_range(silencio_sussurro_longo_min, silencio_sussurro_longo_max)
	else:
		t = rand_range(intervalo_sussurro_min, intervalo_sussurro_max)
	_timer_sussurro.start(t)
	print("🎧 Próximo sussurro isolado em %.1fs" % t)

func _audio_ameaca_livre() -> bool:
	return OS.get_ticks_msec() * 0.001 >= _audio_ameaca_bloqueado_ate

func _bloquear_audio_ameaca() -> void:
	_audio_ameaca_bloqueado_ate = OS.get_ticks_msec() * 0.001 + cooldown_audio_ameaca

func _tentar_sussurro_isolado() -> void:
	if _desativada_definitivamente or not _desbloqueada:
		_schedule_sussurro_isolado()
		return
	# Nunca durante aparição, caça, blackout ou cooldown de áudio
	if _ativo or _cacando or _blackout_ativo or _em_cooldown or not _audio_ameaca_livre():
		_schedule_sussurro_isolado()
		return
	if randf() < chance_sussurro_isolado:
		_tocar_sussurro()
		_bloquear_audio_ameaca()
		print("🎧 Sussurro isolado — próximo áudio bloqueado %.0fs" % cooldown_audio_ameaca)
	_schedule_sussurro_isolado()

# --- Passos isolados ---
func _schedule_passos_isolados() -> void:
	if _desativada_definitivamente or not _desbloqueada:
		return
	var t = rand_range(intervalo_passos_min, intervalo_passos_max)
	_timer_passos.start(t)
	print("👣 Próximo passo em %.1fs" % t)

func _tentar_passos_isolados() -> void:
	if _desativada_definitivamente or not _desbloqueada:
		return
	if not _ativo and not _em_cooldown and _audio_ameaca_livre() and randf() < chance_passos_isolados:
		_tocar_passo_assustador()
		_bloquear_audio_ameaca()
	_schedule_passos_isolados()

func _tocar_passo_assustador() -> void:
	# A sombra ANDA de verdade pela casa (invisível), gerando passos 3D
	# que se aproximam do jogador. Sem pan/volume manual.
	if som_passos == null or _passos_player == null:
		return
	if _andando_passos or _ativo or _cacando:
		return
	_iniciar_caminhada_passos()

func _iniciar_caminhada_passos() -> void:
	var player = _get_player()
	if player == null:
		return

	_passos_count += 1
	_yaw_no_passo = player.rotation.y
	_aguardando_lookback = true
	_lookback_timer = lookback_janela

	var origem = _escolher_origem_passos(player)
	var dist_fim = rand_range(passos_dist_fim_min, passos_dist_fim_max)
	var dir_para_player = (player.global_transform.origin - origem)
	dir_para_player.y = 0.0
	if dir_para_player.length() < 0.1:
		dir_para_player = Vector3(1, 0, 0)
	dir_para_player = dir_para_player.normalized()
	_passos_alvo_pos = player.global_transform.origin - dir_para_player * dist_fim
	_passos_alvo_pos.y = origem.y

	global_transform.origin = _snap_ao_chao(origem)
	_passos_pos_anterior = global_transform.origin
	_passos_dist_acumulada = 0.0
	_passos_tempo = 0.0
	_andando_passos = true

	# Invisível o tempo todo — só o som trai a presença
	hide()
	_set_no_visivel(_no_idle, false)
	_set_no_visivel(_no_running, false)

	if nav_agent:
		nav_agent.set_target_location(_passos_alvo_pos)

	_passos_player.stream = som_passos
	_passos_player.unit_db = passos_unit_db
	_passos_player.max_distance = passos_max_distance
	print("👣 Caminhada fantasma (invisível) de %.1fm até ~%.1fm do player" % [
		origem.distance_to(player.global_transform.origin), dist_fim
	])

func _escolher_origem_passos(player: Node) -> Vector3:
	# Só pontos internos + no NavigationMesh
	var candidatos = []
	for p in _listar_spawns_internos():
		if p is Spatial:
			var pos = _snap_ao_navmesh(p.global_transform.origin)
			if not _pos_esta_no_navmesh(pos, p.global_transform.origin):
				continue
			var d = pos.distance_to(player.global_transform.origin)
			if d >= passos_dist_inicio_min * 0.5 and d <= passos_dist_inicio_max + 8.0:
				candidatos.append(pos)
	if not candidatos.empty():
		return candidatos[randi() % candidatos.size()]

	var internos = _listar_spawns_internos()
	for p in internos:
		if p is Spatial:
			var pos2 = _snap_ao_navmesh(p.global_transform.origin)
			if _pos_esta_no_navmesh(pos2, p.global_transform.origin):
				return pos2

	# Sem ponto válido: usa posição atual da sombra (já deve estar no mesh)
	return global_transform.origin

func _processar_caminhada_passos(delta: float) -> void:
	if not _andando_passos:
		return
	if _ativo or _cacando:
		_encerrar_caminhada_passos()
		return

	var player = _get_player()
	if player == null:
		_encerrar_caminhada_passos()
		return

	_passos_tempo += delta
	if _passos_tempo >= passos_duracao_max:
		_encerrar_caminhada_passos()
		return

	var para_player = player.global_transform.origin - global_transform.origin
	para_player.y = 0.0
	var dist_atual = para_player.length()
	if dist_atual <= passos_dist_fim_min:
		_encerrar_caminhada_passos()
		return

	if nav_agent:
		if _passos_tempo < 0.05 or int(_passos_tempo * 2.0) != int((_passos_tempo - delta) * 2.0):
			var dist_fim = rand_range(passos_dist_fim_min, passos_dist_fim_max)
			var dir = para_player.normalized() if dist_atual > 0.1 else Vector3(1, 0, 0)
			_passos_alvo_pos = player.global_transform.origin - dir * dist_fim
			_passos_alvo_pos.y = global_transform.origin.y
			nav_agent.set_target_location(_passos_alvo_pos)

		if not nav_agent.is_navigation_finished():
			var proximo = nav_agent.get_next_location()
			var dir = proximo - global_transform.origin
			dir.y = 0.0
			if dir.length() > 0.05:
				dir = dir.normalized()
				_vel.x = dir.x * passos_velocidade
				_vel.z = dir.z * passos_velocidade
			else:
				_vel.x = 0.0
				_vel.z = 0.0
		else:
			_vel.x = 0.0
			_vel.z = 0.0
	else:
		var dir = para_player.normalized()
		_vel.x = dir.x * passos_velocidade
		_vel.z = dir.z * passos_velocidade

	_vel.y = 0.0
	_vel = move_and_slide(_vel, Vector3.UP)
	_travar_no_chao()

	var desloc = global_transform.origin.distance_to(_passos_pos_anterior)
	_passos_dist_acumulada += desloc
	_passos_pos_anterior = global_transform.origin
	if _passos_dist_acumulada >= passos_intervalo_metros:
		_passos_dist_acumulada = 0.0
		_tocar_passo_3d()

	if visible:
		hide()

func _tocar_passo_3d() -> void:
	if som_passos == null or _passos_player == null:
		return
	_passos_player.stream = som_passos
	_passos_player.unit_db = passos_unit_db
	_passos_player.max_distance = passos_max_distance
	_passos_player.pitch_scale = 1.0 + rand_range(-pitch_passos_variacao, pitch_passos_variacao)
	_passos_player.play()

func _encerrar_caminhada_passos() -> void:
	if not _andando_passos:
		return
	_andando_passos = false
	_vel = Vector3.ZERO
	_parar_flicker_louco()
	hide()
	print("👣 Caminhada fantasma encerrada")

func _esta_em_movimento_ameaca() -> bool:
	if _cacando:
		return true
	if _andando_passos:
		return true
	if not _ativo:
		return false
	# Andando em direção ao player (aproximar) ou já pediu pra sumir e está saindo
	if _modo_atual == Modo.APROXIMAR:
		return true
	if _quer_sumir:
		return true
	return false

func _atualizar_flicker_louco(delta: float, ativo: bool) -> void:
	if not ativo:
		if _flicker_louco:
			_parar_flicker_louco()
		return
	_flicker_louco = true
	_flicker_louco_timer -= delta
	if _flicker_louco_timer > 0.0:
		return
	# Intervalo bem curto = pisca rápido / louco
	_flicker_louco_timer = rand_range(0.04, 0.12)
	if not lamps:
		return
	for luz in lamps.get_children():
		if _eh_luz_quartinho(luz):
			# Quartinho nunca pisca — fica aceso
			if "visible" in luz:
				luz.visible = true
			continue
		if luz is Light or ("visible" in luz):
			# Só mexe em visible da LUZ — NÃO mexe no lightswitch
			if randf() < 0.72:
				luz.visible = not luz.visible

func _parar_flicker_louco() -> void:
	if not _flicker_louco:
		return
	_flicker_louco = false
	_flicker_louco_timer = 0.0
	# Restaura cada lâmpada pelo estado REAL do interruptor (ligada true/false)
	_restaurar_luzes_pelos_switches()
	_garantir_luz_quartinho_acesa()

## Depois do flicker: luz ligada/desligada conforme a posição do lightswitch
func _restaurar_luzes_pelos_switches() -> void:
	for sw in get_tree().get_nodes_in_group("lightswitch"):
		if not is_instance_valid(sw):
			continue
		# Preferência: método dedicado (não altera o estado do switch)
		if sw.has_method("aplicar_estado_na_lampada"):
			sw.aplicar_estado_na_lampada()
			continue
		# Fallback: usa a flag `ligada` do switch
		if not ("ligada" in sw):
			continue
		var lamp = sw.get("lampada")
		if lamp == null and "nome_lampada" in sw:
			lamp = get_tree().get_root().find_node(str(sw.nome_lampada), true, false)
		if lamp != null and ("visible" in lamp):
			lamp.visible = sw.ligada
		# Atualiza mesh do interruptor sem mudar `ligada`
		if sw.has_method("_atualizar_estado_visual"):
			sw._atualizar_estado_visual()

func _tentar_bater_porta() -> void:
	if not _desbloqueada or _cacando:
		return
	# Não repete a mesma porta duas vezes seguidas
	var candidatas = []
	for node in get_tree().get_nodes_in_group("interagivel"):
		if node.has_method("bater_porta"):
			if _ultima_acao == "porta:" + node.name:
				continue
			if global_transform.origin.distance_to(node.global_transform.origin) < 16.0:
				candidatas.append(node)
	if candidatas.empty():
		return
	var porta = candidatas[randi() % candidatas.size()]
	porta.bater_porta()
	_ultima_acao = "porta:" + porta.name
	if som_bater_porta:
		_tocar_sfx(som_bater_porta, -4.0)
	print("💀 Bateu porta: ", porta.name)
	# Quase nunca tranca — prender o jogador quebra o jogo
	if randf() < chance_trancar_porta:
		yield(get_tree().create_timer(0.8), "timeout")
		if is_instance_valid(porta) and ("aberta" in porta) and not porta.aberta:
			if porta.has_method("trancar_externo"):
				porta.trancar_externo()
				var timer = Timer.new()
				timer.wait_time = 12.0  # tranca curta
				timer.one_shot = true
				add_child(timer)
				timer.connect("timeout", porta, "destrancar_externo", [], CONNECT_ONESHOT)
				timer.start()

func _iniciar_piscar_lanterna() -> void:
	if not _desbloqueada:
		return
	var player = _get_player()
	if not player:
		return
	var lanterna = player.get("lanterna_atual")
	if not lanterna or not is_instance_valid(lanterna) or not lanterna.ligada:
		return
	_piscando = true
	_piscar_duracao = rand_range(piscar_duracao_min, piscar_duracao_max)
	_piscar_timer = 0.0
	_piscar_intervalo_timer = 0.0
	print("💀 Piscando lanterna")

func _checar_flicker_ambiente() -> void:
	if not _desbloqueada or _piscando or _ativo or _desativada_definitivamente:
		return
	if SaveManager.fitas_reproduzidas.size() < 1:
		return
	if randf() < chance_piscar_ambiente:
		_iniciar_piscar_lanterna()

func _processar_piscar(delta: float) -> void:
	var player = _get_player()
	if not player:
		_piscando = false
		return
	var lanterna = player.get("lanterna_atual")
	if not lanterna or not is_instance_valid(lanterna) or not lanterna.ligada:
		_piscando = false
		return
	_piscar_timer += delta
	_piscar_intervalo_timer += delta
	if _piscar_intervalo_timer >= piscar_intervalo:
		_piscar_intervalo_timer = 0.0
		if lanterna.get("luz"):
			lanterna.luz.visible = not lanterna.luz.visible
	if _piscar_timer >= _piscar_duracao:
		if lanterna.get("luz"):
			lanterna.luz.visible = true
		_piscando = false

# =============================================================
func _investir_e_escurecer() -> void:
	if not _desbloqueada:
		return
	var player = _get_player()
	if not player:
		return
	var cam = player.get_node_or_null("Camera")
	if not cam or not cam.has_method("jumpscare_escurecer"):
		return

	print("💀 INVESTIDA")
	_mudar_estado(EstadoSombra.MANIFEST)
	_ativo = false
	_parar_respiracao()
	show()

	var origem = global_transform.origin
	var alvo = cam.global_transform.origin - cam.global_transform.basis.z.normalized() * distancia_investida
	alvo.y = player.global_transform.origin.y
	alvo = _snap_ao_chao(alvo)
	look_at(cam.global_transform.origin, Vector3.UP)

	# Susto visual (tela preta) — crise SÓ no contato em modo caça
	cam.jumpscare_escurecer(1.4, 3.2)
	_apagar_luzes_exceto_quartinho()
	_fechar_e_trancar_quartinho()

	var dash_tween = Tween.new()
	add_child(dash_tween)
	dash_tween.interpolate_property(self, "global_transform:origin",
		origem, alvo, 0.14, Tween.TRANS_EXPO, Tween.EASE_OUT)
	dash_tween.start()
	yield(dash_tween, "tween_all_completed")
	dash_tween.queue_free()

	yield(get_tree().create_timer(0.45), "timeout")

	# Camada 3: chance rara de transportar para sonho/pesadelo
	# Só se pressão alta + Laura em crise/assustada + caminho configurado
	if _deve_tentar_sonho():
		_iniciar_sonho()
		return

	_sumir(false)

# =============================================================
# CAMADA 3 — Sistema base de Sonhos / Pesadelos
# =============================================================
func _deve_tentar_sonho() -> bool:
	if _sonho_em_andamento:
		return false
	if sonho_cena_path == "" or sonho_cena_path == null:
		return false
	if _pressao < pressao_minima_sonho:
		return false
	if not _laura_assustada_ou_pior():
		return false
	var chance = chance_sonho_na_investida
	if _laura_em_crise():
		chance *= 1.6
	if _pressao >= pressao_threshold_critica:
		chance *= 1.3
	return randf() < chance

## Inicia o transporte para o sonho.
## Por enquanto: emite sinal + escurece + tenta carregar a cena se o path existir.
## Você pode conectar o sinal "sombra_manifestou" com tipo "inicio_sonho" em outros scripts.
func _iniciar_sonho() -> void:
	_sonho_em_andamento = true
	var player = _get_player()
	if player:
		_pos_antes_sonho = player.global_transform.origin

	print("🌙 INICIANDO SONHO/PESADELO → ", sonho_cena_path)
	emit_signal("sombra_manifestou", "inicio_sonho")
	_mudar_estado(EstadoSombra.MANIFEST)

	# Esconde a sombra e limpa estado antes da transição
	hide()
	_ativo = false
	_parar_respiracao()
	_quebra_regra_ativa = false

	# Pequena pausa no escuro antes de trocar de cena
	yield(get_tree().create_timer(0.8), "timeout")

	if sonho_cena_path != "" and ResourceLoader.exists(sonho_cena_path):
		if typeof(Global) != TYPE_NIL and Global.has_method("carregar_fase"):
			Global.carregar_fase(sonho_cena_path)
		else:
			get_tree().change_scene(sonho_cena_path)
	else:
		# Path não configurado ou cena ainda não existe — só registra e volta ao fluxo normal
		print("🌙 Sonho: cena não encontrada ou path vazio. Continuando na casa.")
		_sonho_em_andamento = false
		_em_cooldown = true
		yield(get_tree().create_timer(cooldown_time), "timeout")
		_em_cooldown = false
		_schedule_next()

## Chame isso ao VOLTAR do sonho para a casa (do script do sonho ou do loading).
func ao_voltar_do_sonho() -> void:
	_sonho_em_andamento = false
	_pressao = max(_pressao - 25.0, 0.0)
	_tensao = max(_tensao - 30.0, 0.0)
	print("🌙 Voltou do sonho — pressão/tensão aliviadas um pouco")
	emit_signal("sombra_manifestou", "fim_sonho")
	_mudar_estado(EstadoSombra.DORMANT)
	_schedule_next()

func esta_em_sonho() -> bool:
	return _sonho_em_andamento

func get_pos_antes_sonho() -> Vector3:
	return _pos_antes_sonho

func _eh_luz_quartinho(luz: Node) -> bool:
	if luz == null:
		return false
	var n = String(luz.name).to_lower()
	if n == "lamp_quartinho" or n.find("quartinho") != -1:
		return true
	if luz.is_in_group("lamp_quartinho") or luz.is_in_group("luz_quartinho"):
		return true
	return false

func _apagar_luzes_exceto_quartinho() -> void:
	if not lamps:
		return
	for luz in lamps.get_children():
		if _eh_luz_quartinho(luz):
			# Nunca apaga — força acesa
			if luz is Light or "visible" in luz:
				luz.visible = true
			continue
		if luz is SpotLight or luz is OmniLight or luz is Light:
			luz.visible = false
			if has_method("_sincronizar_lightswitch_da_luz"):
				_sincronizar_lightswitch_da_luz(luz, false)
	_garantir_luz_quartinho_acesa()

func _garantir_luz_quartinho_acesa() -> void:
	if not lamps:
		return
	for luz in lamps.get_children():
		if _eh_luz_quartinho(luz):
			if luz is Light or "visible" in luz:
				luz.visible = true
			if has_method("_sincronizar_lightswitch_da_luz"):
				_sincronizar_lightswitch_da_luz(luz, false)

func _fechar_e_trancar_quartinho() -> void:
	# NÃO tranca o jogador no quartinho — só fecha a porta por poucos segundos
	for node in get_tree().get_nodes_in_group("interagivel"):
		if node.name == "porta_quartinho":
			if "aberta" in node and node.aberta and node.has_method("bater_porta"):
				node.bater_porta()  # fecha rápido
			# destranca se estava trancada
			if node.has_method("destrancar_externo"):
				node.destrancar_externo()
			return

# =============================================================
func _escolher_ponto():
	var player = _get_player()
	if not player or not spawn_points:
		return null
	# SOMENTE pontos internos da casa
	var todos = _listar_spawns_internos()
	if todos.empty():
		print("⚠️ Nenhum spawn interno encontrado em ShadowSpawnPoints")
		return null
	var amb_player = _get_ambiente_player()
	var perto = randf() < chance_perto_player

	# Camada 3: contextual (raro agora — sombra prefere ficar longe observando)
	var amb_contexto = _escolher_ambiente_contextual()
	if amb_contexto != "" and amb_contexto != "fora" and randf() < 0.22:
		var ctx = []
		for ponto in todos:
			if _get_ambiente(ponto) == amb_contexto:
				ctx.append(ponto)
		if ctx.size() > 0:
			if ctx.size() > 1 and _spawn_atual != null:
				ctx.erase(_spawn_atual)
			if ctx.size() > 0:
				print("📍 Spawn contextual no ambiente: ", amb_contexto)
				return ctx[randi() % ctx.size()]

	var candidatos = []
	for ponto in todos:
		var amb = _get_ambiente(ponto)
		if perto:
			if amb == amb_player and amb != "" and amb != "fora":
				candidatos.append(ponto)
		else:
			# Prefere outro ambiente interno / outro lado da casa
			if amb != amb_player:
				candidatos.append(ponto)

	if candidatos.empty():
		candidatos = todos.duplicate()
	if candidatos.empty():
		return null
	if candidatos.size() > 1 and _spawn_atual != null:
		candidatos.erase(_spawn_atual)

	# Entre os candidatos de longe, favorece os MAIS distantes (outro lado da casa)
	if not perto and candidatos.size() > 1:
		var longe = []
		for p in candidatos:
			var d = player.global_transform.origin.distance_to(p.global_transform.origin)
			if d >= distancia_minima_corrida * 0.75:
				longe.append(p)
		if longe.size() > 0:
			return longe[randi() % longe.size()]

	return candidatos[randi() % candidatos.size()]

## Escolhe um ambiente com base no tempo que o jogador passou em cada um.
## Ambientes com MUITO tempo (fica parado) e com POUCO tempo (evita) são candidatos.
func _escolher_ambiente_contextual() -> String:
	if _ambientes_tempo.empty():
		return ""
	var max_t = 0.0
	var min_t = 999999.0
	var amb_max = ""
	var amb_min = ""
	for amb in _ambientes_tempo.keys():
		var t = float(_ambientes_tempo[amb])
		if t > max_t:
			max_t = t
			amb_max = amb
		if t < min_t:
			min_t = t
			amb_min = amb
	# Alterna entre "onde você fica" e "onde você evita"
	if randf() < 0.55 and amb_max != "":
		return amb_max
	return amb_min

# Ambientes internos válidos — sombra NÃO deve ir para "fora"
const AMBIENTES_INTERNOS := ["quarto", "sala", "cozinha", "lavanderia", "quartinho", "banheiro", "corredor", "hall"]

func _get_ambiente(ponto) -> String:
	if ponto == null:
		return ""
	# Nome do nó também conta (ex.: Spawn_Sala, ponto_quartinho)
	var nome = ""
	if ponto is Node:
		nome = String(ponto.name).to_lower()
	for a in AMBIENTES_INTERNOS:
		if ponto.is_in_group(a):
			return a
		if nome.find(a) != -1:
			return a
	# Explicitamente exterior
	if ponto.is_in_group("fora") or nome.find("fora") != -1 or nome.find("outside") != -1 or nome.find("jardim") != -1 or nome.find("exterior") != -1:
		return "fora"
	return ""

func _ponto_eh_interno(ponto) -> bool:
	var amb = _get_ambiente(ponto)
	return amb != "" and amb != "fora"

func _listar_spawns_internos() -> Array:
	# Casa ainda não tem "lado de fora" modelado: usa TODOS os Position3D
	# de ShadowSpawnPoints, exceto os explicitamente marcados "fora".
	return _listar_todos_spawns()

## Garante que uma posição desejada está DENTRO da casa.
## 1) snap no NavigationMesh
## 2) precisa estar razoavelmente perto de algum ShadowSpawnPoint interno
## Se falhar, tenta o spawn interno mais próximo da posição desejada.
## Retorna Vector3 válido ou null se não houver nenhum ponto interno.

func _ativar_atravessar_paredes_caca(ativo: bool) -> void:
	if not caca_atravessa_paredes and ativo:
		return
	if ativo:
		if _collision_mask_backup < 0:
			_collision_mask_backup = collision_mask
			_collision_layer_backup = collision_layer
		# Não colide com cenário — só "existe" pra lógica de contato por distância
		collision_mask = 0
		# Mantém layer 0 também evita empurrar o player fisicamente
		collision_layer = 0
		print("💀 Caça: atravessando paredes (collision off)")
	else:
		if _collision_mask_backup >= 0:
			collision_mask = _collision_mask_backup
			collision_layer = _collision_layer_backup
			_collision_mask_backup = -1
			_collision_layer_backup = -1
			print("💀 Caça: colisão restaurada")

func _forcar_posicao_interna(pos_desejada: Vector3, raio_max: float = 6.0):
	var pos_nav = _snap_ao_navmesh(pos_desejada)
	var no_mesh = _pos_esta_no_navmesh(pos_nav, pos_desejada)
	var internos = _listar_spawns_internos()
	if internos.empty():
		# Sem spawns internos conhecidos: só confia no navmesh
		if no_mesh:
			return pos_nav
		return null

	# Distância ao spawn interno mais próximo
	var mais_perto_dist = 99999.0
	var mais_perto_pos = Vector3.ZERO
	var achou = false
	for p in internos:
		if not (p is Spatial):
			continue
		var p_nav = _snap_ao_navmesh(p.global_transform.origin)
		if not _pos_esta_no_navmesh(p_nav, p.global_transform.origin):
			continue
		var d = Vector2(pos_nav.x, pos_nav.z).distance_to(Vector2(p_nav.x, p_nav.z))
		if d < mais_perto_dist:
			mais_perto_dist = d
			mais_perto_pos = p_nav
			achou = true

	if not achou:
		return null

	# Aceita a posição desejada se está no mesh E perto de um spawn interno
	if no_mesh and mais_perto_dist <= raio_max:
		return pos_nav

	# Caso contrário: usa o spawn interno mais próximo da intenção
	# (ainda "atrás" / periferia relativa, mas sempre dentro da casa)
	print("📍 Posição ajustada para spawn interno (dist=%.1fm do desejado)" % mais_perto_dist)
	return mais_perto_pos

## true se a posição atual da sombra ainda está em área interna da casa
func _posicao_ainda_interna() -> bool:
	var pos = global_transform.origin
	var pos_nav = _snap_ao_navmesh(pos)
	# Longe do navmesh = void / fora
	if not _pos_esta_no_navmesh(pos_nav, pos):
		return false
	var internos = _listar_spawns_internos()
	if internos.empty():
		return true  # sem referência: confia só no mesh
	var min_d = 99999.0
	for p in internos:
		if not (p is Spatial):
			continue
		var d = Vector2(pos.x, pos.z).distance_to(Vector2(p.global_transform.origin.x, p.global_transform.origin.z))
		if d < min_d:
			min_d = d
	# Tolerância generosa: casa inteira + margem (não só o cômodo do spawn)
	return min_d <= 28.0

func _get_ambiente_player() -> String:
	var player = _get_player()
	if not player:
		return "fora"
	for a in AMBIENTES_INTERNOS:
		if player.is_in_group(a):
			return a
	return "fora"

## Trava a sombra no chão do NavigationMesh (não cai pro void)
func _travar_no_chao() -> void:
	var pos = global_transform.origin
	var nav = _get_navigation()
	if nav:
		var closest = nav.get_closest_point(pos)
		# Se o closest está razoável no plano XZ, usa o Y dele
		var d_xz = Vector2(closest.x, closest.z).distance_to(Vector2(pos.x, pos.z))
		if d_xz <= 3.0:
			pos.y = closest.y
			_altura_chao_atual = closest.y
			global_transform.origin = pos
			return
	# Fallback: mantém última altura conhecida / raycast
	if _altura_chao_atual != 0.0:
		pos.y = _altura_chao_atual
		global_transform.origin = pos
		return
	var no_chao = _snap_ao_chao(pos)
	_altura_chao_atual = no_chao.y
	global_transform.origin = no_chao

## Esconde a sombra num ponto interno válido (nunca no void fora da casa)
func _estacionar_fora_de_jogo() -> void:
	if _sfx_player and _sfx_player.playing:
		_sfx_player.stop()
	var internos = _listar_spawns_internos()
	if not internos.empty() and internos[0] is Spatial:
		var p = _snap_ao_navmesh(internos[0].global_transform.origin)
		global_transform.origin = p
		_altura_chao_atual = p.y
		return
	# Último recurso: fica onde está, só não usa _pos_inicial se for lá fora
	var pos_ini_nav = _snap_ao_navmesh(_pos_inicial)
	if _pos_esta_no_navmesh(pos_ini_nav, _pos_inicial):
		global_transform.origin = pos_ini_nav
		_altura_chao_atual = pos_ini_nav.y

func _get_navigation() -> Navigation:
	# Procura nó Navigation na cena (Godot 3)
	var n = get_node_or_null("../Navigation")
	if n is Navigation:
		return n
	var cena = get_tree().current_scene
	if cena:
		n = cena.find_node("Navigation", true, false)
		if n is Navigation:
			return n
	# Sobe a hierarquia
	var p = get_parent()
	while p:
		if p is Navigation:
			return p
		n = p.get_node_or_null("Navigation")
		if n is Navigation:
			return n
		p = p.get_parent()
	return null

## Projeta a posição no NavigationMesh (área azul). Se não houver nav, devolve o snap de chão.
func _snap_ao_navmesh(pos: Vector3) -> Vector3:
	var nav = _get_navigation()
	if nav:
		var closest = nav.get_closest_point(pos)
		# Mantém altura sensata
		if closest != Vector3.ZERO or pos.length() < 0.1:
			return closest
		return closest
	return _snap_ao_chao(pos)

## true se a posição projetada ainda está "perto" do ponto pedido (está no mesh)
func _pos_esta_no_navmesh(pos_nav: Vector3, pos_original: Vector3) -> bool:
	var nav = _get_navigation()
	if nav == null:
		# Sem Navigation na cena — não bloqueia (evita sombra nunca spawnar)
		return true
	# Se o closest point ficou longe do original, o ponto não está no mesh
	var d = Vector2(pos_nav.x, pos_nav.z).distance_to(Vector2(pos_original.x, pos_original.z))
	return d <= 2.5

func _snap_ao_chao(pos: Vector3) -> Vector3:
	var player = _get_player()
	var y_fallback = player.global_transform.origin.y if player else pos.y
	var from = Vector3(pos.x, max(pos.y, y_fallback) + 4.0, pos.z)
	var to   = Vector3(pos.x, min(pos.y, y_fallback) - 12.0, pos.z)
	var excluir = [self]
	if player:
		excluir.append(player)

	var space_state = get_world().direct_space_state

	if chao_group == "":
		var result = space_state.intersect_ray(from, to, excluir)
		if result:
			return Vector3(pos.x, result.position.y + 0.15, pos.z)
		return Vector3(pos.x, y_fallback + 0.15, pos.z)

	for tentativa in range(8):
		var result
		if chao_collision_mask > 0:
			result = space_state.intersect_ray(from, to, excluir, chao_collision_mask)
		else:
			result = space_state.intersect_ray(from, to, excluir)
		if result.empty():
			break
		var collider = result.collider
		if collider != null and collider.is_in_group(chao_group):
			return Vector3(pos.x, result.position.y + 0.15, pos.z)
		if collider == null:
			break
		excluir.append(collider)

	return Vector3(pos.x, y_fallback + 0.15, pos.z)

func _aguardar_primeira_fita() -> void:
	print("💀 Sombra bloqueada — aguardando primeira fita...")
	while SaveManager.fitas_reproduzidas.size() < 1:
		yield(get_tree().create_timer(1.0), "timeout")
	_desbloqueada = true
	print("💀 Sombra desbloqueada — primeira fita terminou de tocar")
	_timer_ambiente.start()
	_schedule_next()
	_schedule_sussurro_isolado()
	_schedule_passos_isolados()
	_schedule_alteracao_ambiental()

# =============================================================
func habilitar_evento_ignorar() -> void:
	_evento_ignorar_disponivel = true

func sombra_perder_controle() -> void:
	if not _desbloqueada:
		return
	print("💀 Sombra perdeu o controle")
	emit_signal("sombra_manifestou", "colapso_fita_dourada")
	_timer.stop()
	_parar_respiracao()
	hide()
	_ativo = false
	_mudar_estado(EstadoSombra.MANIFEST)
	if lamps:
		for luz in lamps.get_children():
			if luz is SpotLight or luz is OmniLight:
				luz.visible = false
		yield(get_tree().create_timer(0.35), "timeout")
		for luz in lamps.get_children():
			if luz is SpotLight or luz is OmniLight:
				luz.visible = true
		yield(get_tree().create_timer(0.25), "timeout")
		for luz in lamps.get_children():
			if luz is SpotLight or luz is OmniLight:
				luz.visible = false
	for node in get_tree().get_nodes_in_group("interagivel"):
		if node.has_method("bater_porta") and randf() < 0.55:
			node.bater_porta()
	yield(get_tree().create_timer(0.5), "timeout")
	if lamps:
		for luz in lamps.get_children():
			if luz is SpotLight or luz is OmniLight:
				luz.visible = true
	_tensao = 0.0
	_mudar_estado(EstadoSombra.DORMANT)
	_timer.start(silencio_longo_min)

func sombra_desativar_definitivamente() -> void:
	print("💀 Sombra desativada")
	_desativada_definitivamente = true
	_timer.stop()
	_timer_ambiente.stop()
	if _timer_sussurro:
		_timer_sussurro.stop()
	if _timer_passos:
		_timer_passos.stop()
	if _timer_alteracao:
		_timer_alteracao.stop()
	_ativo = false
	_piscando = false
	_quebra_regra_ativa = false
	_parar_respiracao()
	_set_atmosfera_camera(false)
	hide()
	_mudar_estado(EstadoSombra.DORMANT)
	set_physics_process(false)

func aliviar_tensao(quantidade: float) -> void:
	_tensao = max(_tensao - quantidade, 0.0)

func get_tensao() -> float:
	return _tensao

func get_tensao_max() -> float:
	return tensao_max

# =============================================================
# API PÚBLICA — Pressão de Investigação (mantida 100% compatível)
# =============================================================
func set_investigando(ativo: bool) -> void:
	_investigando = ativo
	if not ativo:
		print("💀 Pressão: investigação pausada")
	else:
		print("💀 Pressão: investigação ativa")

func aumentar_pressao(quantidade: float) -> void:
	_pressao = min(_pressao + quantidade, pressao_max)
	print("💀 Pressão aumentou → %.1f" % _pressao)

func aliviar_pressao(quantidade: float = -1.0) -> void:
	if quantidade < 0.0:
		quantidade = pressao_perda_ao_descobrir
	_pressao = max(_pressao - quantidade, 0.0)
	_tempo_desde_ultima_descoberta = 0.0
	print("💀 Pressão aliviada → %.1f" % _pressao)

func reagir_a_descoberta(tipo: String = "pista") -> void:
	_ultima_descoberta_tipo = tipo
	_tempo_desde_ultima_descoberta = 0.0

	match tipo:
		"fita", "memoria":
			aliviar_pressao(pressao_perda_ao_ouvir_fita)
			_investigando = false
			yield(get_tree().create_timer(12.0), "timeout")
			if not _desativada_definitivamente:
				_investigando = true
		"foto", "pato", "pista", "estante", "kit":
			aliviar_pressao(pressao_perda_ao_descobrir)
			if _desbloqueada and not _ativo and not _em_cooldown and randf() < 0.55:
				_timer.stop()
				if randf() < 0.55:
					_manifestacao_indireta()
				else:
					_disparar_efeito(_get_fase(), true)
		_:
			aliviar_pressao(pressao_perda_ao_descobrir * 0.7)

	emit_signal("sombra_manifestou", "reacao_descoberta_" + tipo)
	print("💀 Sombra reagiu à descoberta: ", tipo)

func ao_ouvir_fita() -> void:
	reagir_a_descoberta("fita")

func get_pressao() -> float:
	return _pressao

func get_pressao_max() -> float:
	return pressao_max

func get_pressao_normalizada() -> float:
	return _pressao / pressao_max if pressao_max > 0.0 else 0.0
