extends KinematicBody

# =============================================================
# A SOMBRA — culpa e remorso da Laura
# Quanto menos fitas coletadas, mais frequente e intensa ela é.
# Quando observada, ela para e sustenta o olhar.
# Quando ignorada, ela se aproxima lentamente.
# =============================================================

onready var lamps        = get_parent().get_node("lamps")
onready var spawn_points = get_parent().get_node("ShadowSpawnPoints")

# --- Temporização por fase (baseada em fitas coletadas) ---
# Fase 0: 0-1 fitas  → mais frequente (culpa no auge)
# Fase 1: 2-3 fitas  → moderada
# Fase 2: 4+ fitas   → mais rara (Laura começa a se reconciliar)
export var intervalo_min_f0 : float = 40.0
export var intervalo_max_f0 : float = 80.0
export var intervalo_min_f1 : float = 70.0
export var intervalo_max_f1 : float = 120.0
export var intervalo_min_f2 : float = 100.0
export var intervalo_max_f2 : float = 160.0

export var tempo_visivel  : float = 8.0
export var cooldown_time  : float = 45.0

# --- Visão ---
export var look_angle_thresh : float = 0.85
# look_delay: quanto tempo o jogador precisa olhar pra ela sumir
# 2s cria tensão — ela sustenta o olhar antes de desaparecer
export var look_delay        : float = 2.0

# --- Movimento (drift em direção ao player quando não observada) ---
export var velocidade_drift    : float = 1.4   # bem lento, perturbador
export var dist_minima_player  : float = 2.5   # nunca invade o espaço físico

# --- Comportamentos ---
# OBSERVAR:       aparece e fica parada olhando
# APROXIMAR:      drift lento em direção ao player quando ele não olha
# FLASH:          aparece por pouquíssimo tempo e some — como um relance
export var chance_aproximar : float = 0.45
export var chance_flash     : float = 0.20
# o resto (1 - aproximar - flash) é OBSERVAR

export var tempo_flash      : float = 1.8   # segundos que o FLASH dura

# --- Ações ao spawnar ---
export var chance_apagar_luzes    : float = 0.10
export var chance_bater_porta     : float = 0.25
export var chance_trancar_porta   : float = 0.10
export var chance_piscar_lanterna : float = 0.30

# --- Piscar lanterna ---
export var piscar_duracao_min : float = 4.0
export var piscar_duracao_max : float = 9.0
export var piscar_intervalo   : float = 0.12

# =============================================================
# Sussurros — arquitetura pronta, áudio a ser adicionado depois
#
# Como usar quando gravar:
#   1. Adicione filhos AudioStreamPlayer a esse node no editor
#   2. Nomeie-os: Sussurro0, Sussurro1, Sussurro2, ...
#   3. Atribua o .mp3/.ogg a cada um no Inspector
#   4. O script detecta automaticamente e toca um aleatório no spawn
#
# Frases sugeridas pra gravar com camadas de sussurro:
#   "É culpa sua"
#   "Você fez tudo isso"
#   "Você deixou seus amigos"
#   "Eles estavam esperando por você"
#   "Você poderia ter ficado"
#   "Por que você foi embora?"
# =============================================================
var _sussurros : Array = []

# --- Estado interno ---
enum Modo { OBSERVAR, APROXIMAR, FLASH }
var _modo_atual : int = Modo.OBSERVAR

var _timer       : Timer
var _ativo       : bool  = false
var _em_cooldown : bool  = false

var _olhando_timer : float = 0.0
var _visivel_timer : float = 0.0
var _spawn_atual   : Spatial = null

var _vel : Vector3 = Vector3.ZERO
const _GRAVIDADE : float = -20.0

var _piscando               : bool  = false
var _piscar_timer           : float = 0.0
var _piscar_duracao         : float = 0.0
var _piscar_intervalo_timer : float = 0.0

# =============================================================

func _ready() -> void:
	hide()
	randomize()
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.connect("timeout", self, "_spawnar")

	# Coleta todos os AudioStreamPlayer filhos como sussurros
	for child in get_children():
		if child is AudioStreamPlayer:
			_sussurros.append(child)

	_schedule_next()

# -------------------------------------------------------------

func _get_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _get_fase() -> int:
	var total = SaveManager.itens_coletados.size()
	if total <= 1:
		return 0
	elif total <= 3:
		return 1
	return 2

func _schedule_next() -> void:
	_reset_all()
	var f = _get_fase()
	var mn = intervalo_min_f0
	var mx = intervalo_max_f0
	if f == 1:
		mn = intervalo_min_f1
		mx = intervalo_max_f1
	elif f == 2:
		mn = intervalo_min_f2
		mx = intervalo_max_f2
	var t = rand_range(mn, mx)
	_timer.start(t)
	print("⏱️ Sombra em %.0fs (fase %d)" % [t, f])

func _reset_all() -> void:
	_olhando_timer = 0.0
	_visivel_timer = 0.0
	_piscando      = false
	_piscar_timer  = 0.0
	_vel           = Vector3.ZERO
	hide()
	_spawn_atual = null
	_ativo       = false

# -------------------------------------------------------------

func _spawnar() -> void:
	var ponto = _escolher_ponto()
	if ponto == null:
		_schedule_next()
		return

	_spawn_atual = ponto
	global_transform.origin = ponto.global_transform.origin

	# Escolhe modo
	var r = randf()
	if r < chance_flash:
		_modo_atual = Modo.FLASH
	elif r < chance_flash + chance_aproximar:
		_modo_atual = Modo.APROXIMAR
	else:
		_modo_atual = Modo.OBSERVAR

	show()
	_ativo         = true
	_olhando_timer = 0.0
	_visivel_timer = 0.0
	print("💀 Sombra spawnou | modo: ", ["OBSERVAR","APROXIMAR","FLASH"][_modo_atual])

	# Ações de spawn
	if randf() < chance_bater_porta:
		_tentar_bater_porta()
	if randf() < chance_piscar_lanterna:
		_iniciar_piscar_lanterna()

	# Sussurro aleatório
	_tocar_sussurro()

# -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _ativo or _em_cooldown:
		return

	var player = _get_player()
	if not player:
		return

	var cam = player.get_node("Camera")

	# Sempre encaram o player
	var look_target = player.global_transform.origin
	look_target.y   = global_transform.origin.y
	if look_target.distance_to(global_transform.origin) > 0.1:
		look_at(look_target, Vector3.UP)

	if _piscando:
		_processar_piscar(delta)

	var sendo_vista = _checar_visao(cam)

	if sendo_vista:
		# Sendo observada: para de mover, conta o tempo de olhar
		_vel.x         = 0.0
		_vel.z         = 0.0
		_olhando_timer += delta
	else:
		_olhando_timer = 0.0
		# Drift somente no modo APROXIMAR
		if _modo_atual == Modo.APROXIMAR:
			var dist = global_transform.origin.distance_to(player.global_transform.origin)
			if dist > dist_minima_player:
				var dir = (player.global_transform.origin - global_transform.origin).normalized()
				dir.y  = 0.0
				_vel.x = dir.x * velocidade_drift
				_vel.z = dir.z * velocidade_drift
			else:
				_vel.x = 0.0
				_vel.z = 0.0

	# Gravidade
	_vel.y = 0.0 if is_on_floor() else _vel.y + _GRAVIDADE * delta
	move_and_slide(_vel, Vector3.UP)

	# Condição de sumir ao ser olhada
	if _olhando_timer >= look_delay:
		_sumir()
		return

	# Tempo máximo visível (FLASH some muito mais rápido)
	_visivel_timer += delta
	var tempo_max = tempo_flash if _modo_atual == Modo.FLASH else tempo_visivel
	if _visivel_timer >= tempo_max:
		_sumir()

# -------------------------------------------------------------

func _checar_visao(cam) -> bool:
	var player = _get_player()
	if not player:
		return false
	if global_transform.origin.distance_to(cam.global_transform.origin) > 80.0:
		return false
	var cam_pos    = cam.global_transform.origin
	var dir_sombra = (global_transform.origin - cam_pos).normalized()
	var dir_camera = -cam.global_transform.basis.z.normalized()
	if dir_camera.dot(dir_sombra) < look_angle_thresh:
		return false
	var result = get_world().direct_space_state.intersect_ray(
		cam_pos, global_transform.origin, [player, self])
	return result.empty()

func _sumir() -> void:
	hide()
	_ativo    = false
	_piscando = false
	_vel      = Vector3.ZERO

	if randf() < chance_apagar_luzes:
		for luz in lamps.get_children():
			if luz is SpotLight or luz is OmniLight:
				luz.visible = false
		print("💀 Sombra apagou as luzes!")

	_em_cooldown = true
	yield(get_tree().create_timer(cooldown_time), "timeout")
	_em_cooldown = false
	_schedule_next()

# --- Sussurros -----------------------------------------------

func _tocar_sussurro() -> void:
	if _sussurros.empty():
		return
	# Filtra os que têm stream carregado e não estão tocando
	var disponiveis = []
	for s in _sussurros:
		if s.stream != null and not s.playing:
			disponiveis.append(s)
	if disponiveis.empty():
		return
	disponiveis[randi() % disponiveis.size()].play()

# --- Bater / Trancar porta -----------------------------------
func _tentar_bater_porta() -> void:
	var candidatas = []
	for node in get_tree().get_nodes_in_group("interagivel"):
		if node.has_method("bater_porta"):
			if global_transform.origin.distance_to(node.global_transform.origin) < 12.0:
				candidatas.append(node)
	
	if candidatas.empty():
		return
	
	var porta = candidatas[randi() % candidatas.size()]
	
	porta.bater_porta()
	print("💀 Sombra bateu a porta: ", porta.name)
	
	# Trancamento temporário (60 segundos)
	if randf() < chance_trancar_porta:
		yield(get_tree().create_timer(1.0), "timeout")
		
		if is_instance_valid(porta) and not porta.aberta:
			porta.trancar_externo()
			print("💀 Sombra trancou a porta por 60 segundos: ", porta.name)
			
			# Timer para destrancar automaticamente
			var timer = Timer.new()
			timer.wait_time = 60.0
			timer.one_shot = true
			add_child(timer)
			timer.connect("timeout", porta, "destrancar_externo", [], CONNECT_ONESHOT)
			timer.start()

# --- Piscar lanterna -----------------------------------------

func _iniciar_piscar_lanterna() -> void:
	var player = _get_player()
	if not player:
		return
	var lanterna = player.get_node("Camera").get_node_or_null("Lanterna")
	if not lanterna or not lanterna.ligada:
		return
	_piscando               = true
	_piscar_duracao         = rand_range(piscar_duracao_min, piscar_duracao_max)
	_piscar_timer           = 0.0
	_piscar_intervalo_timer = 0.0
	print("💀 Sombra piscando a lanterna!")

func _processar_piscar(delta: float) -> void:
	var player = _get_player()
	if not player:
		_piscando = false
		return
	var lanterna = player.get_node("Camera").get_node_or_null("Lanterna")
	if not lanterna or not lanterna.ligada:
		_piscando = false
		return

	_piscar_timer           += delta
	_piscar_intervalo_timer += delta

	if _piscar_intervalo_timer >= piscar_intervalo:
		_piscar_intervalo_timer  = 0.0
		lanterna.luz.visible     = not lanterna.luz.visible

	if _piscar_timer >= _piscar_duracao:
		lanterna.luz.visible = true
		_piscando            = false
		print("💀 Piscar da lanterna terminou.")

# --- Spawn por ambiente --------------------------------------

func _escolher_ponto() -> Spatial:
	var player = _get_player()
	if not player:
		return null
	var todos      = spawn_points.get_children()
	var candidatos = []
	var amb_player = _get_ambiente_player()
	for ponto in todos:
		var amb = _get_ambiente(ponto)
		if amb == "" or amb != amb_player:
			candidatos.append(ponto)
	if candidatos.empty():
		return null
	if candidatos.size() > 1 and _spawn_atual != null:
		candidatos.erase(_spawn_atual)
	return candidatos[randi() % candidatos.size()]

func _get_ambiente(ponto: Spatial) -> String:
	for a in ["quarto", "sala", "cozinha", "lavanderia"]:
		if ponto.is_in_group(a):
			return a
	return ""

func _get_ambiente_player() -> String:
	var player = _get_player()
	if not player:
		return "fora"
	for a in ["quarto", "sala", "cozinha", "lavanderia"]:
		if player.is_in_group(a):
			return a
	return "fora"
