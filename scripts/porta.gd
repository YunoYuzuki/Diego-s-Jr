extends StaticBody
export var angulo_aberta    : float = -120.0
export var velocidade_porta : float = 2.5
export var velocidade_maca  : float = 4.5

export var tempo_trancada_min : float = 60.0
export var tempo_trancada_max : float = 120.0

export(AudioStream) var audio_porta            # NOVO: arraste o áudio da porta no Inspector
export var audio_max_distancia : float = 15.0  # NOVO: distância máxima de escuta
export var audio_volume_max_db : float = 0.0   # NOVO: volume quando perto

onready var pivot         = $Door/pivot_porta
onready var machaneta1    = $Door/pivot_porta/Porta/macaneta_1
onready var machaneta2    = $Door/pivot_porta/Porta/macaneta_2
onready var colisao_vao   = $CollisionShape
onready var colisao_porta = $Door/pivot_porta/StaticBody/CollisionShape
onready var area          = $Door/pivot_porta/Area

var aberta    : bool  = false
var animando  : bool  = false
var alvo_porta: float = 0.0
var trancada  : bool  = false

var _timer_trancada : Timer
var _audio_player : AudioStreamPlayer   # NOVO

var repouso_maca1 := Vector3(0.0,    0.0, 180.0)
var alvo_maca1    := Vector3(0.0,   16.0, 180.0)
var repouso_maca2 := Vector3(0.0, -180.0,   0.0)
var alvo_maca2    := Vector3(0.0, -164.0,   0.0)

func _ready():
	add_to_group("Persist_estatico")
	add_to_group("Persist")
	add_to_group("interagivel")
	repouso_maca1 = machaneta1.rotation_degrees
	repouso_maca2 = machaneta2.rotation_degrees
	area.add_to_group("interagivel")
	area.set_meta("door_parent", self)
	_atualizar_colisoes()

	_timer_trancada = Timer.new()
	_timer_trancada.one_shot = true
	add_child(_timer_trancada)
	_timer_trancada.connect("timeout", self, "_destrancar")

	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = audio_porta
	add_child(_audio_player)

func set_foco(_ativo: bool):
	pass

func interagir(_player):
	if animando or trancada:
		return
	aberta     = !aberta
	alvo_porta = angulo_aberta if aberta else 0.0
	animando   = true
	_atualizar_colisoes()
	_tocar_som_porta()

func bater_porta() -> void:
	if animando or trancada:
		return
	aberta     = !aberta
	alvo_porta = angulo_aberta if aberta else 0.0
	animando   = true
	_atualizar_colisoes()
	_tocar_som_porta()

func _atualizar_colisoes():
	colisao_vao.disabled   = aberta   # vão livre quando aberta
	colisao_porta.disabled = !aberta  # porta com colisão quando aberta

func _process(delta):
	if not animando:
		return

	var alvo_m1 = alvo_maca1 if aberta else repouso_maca1
	var alvo_m2 = alvo_maca2 if aberta else repouso_maca2
	var t_maca  = velocidade_maca * delta

	machaneta1.rotation_degrees = _lerp_rot(machaneta1.rotation_degrees, alvo_m1, t_maca)
	machaneta2.rotation_degrees = _lerp_rot(machaneta2.rotation_degrees, alvo_m2, t_maca)

	var maca_pronta = machaneta1.rotation_degrees.distance_to(alvo_m1) < 2.0
	if maca_pronta:
		var rp = pivot.rotation_degrees
		rp.z = lerp(rp.z, alvo_porta, velocidade_porta * delta)
		pivot.rotation_degrees = rp
		if abs(rp.z - alvo_porta) < 0.1:
			pivot.rotation_degrees.z    = alvo_porta
			machaneta1.rotation_degrees = alvo_m1
			machaneta2.rotation_degrees = alvo_m2
			animando = false
			

func _lerp_rot(atual: Vector3, alvo: Vector3, t: float) -> Vector3:
	return Vector3(
		rad2deg(lerp_angle(deg2rad(atual.x), deg2rad(alvo.x), t)),
		rad2deg(lerp_angle(deg2rad(atual.y), deg2rad(alvo.y), t)),
		rad2deg(lerp_angle(deg2rad(atual.z), deg2rad(alvo.z), t))
	)

func save() -> Dictionary:
	return {
		"tipo_estatico": "porta",
		"name":   name,
		"parent": get_parent().get_path(),
		"pos_x":  translation.x,
		"pos_y":  translation.y,
		"pos_z":  translation.z,
		"aberta": aberta
	}

func load_data(data: Dictionary) -> void:
	aberta     = data.get("aberta", false)
	alvo_porta = angulo_aberta if aberta else 0.0
	pivot.rotation_degrees.z = alvo_porta
	_atualizar_colisoes()

func trancar_externo() -> void:
	if aberta:
		return
	trancada = true
	var tempo = rand_range(tempo_trancada_min, tempo_trancada_max)
	_timer_trancada.start(tempo)
	print("🔒 Porta trancada por ", int(tempo), "s")

func _destrancar() -> void:
	trancada = false
	print("🔓 Porta destrancou sozinha")

func _tocar_som_porta() -> void:
	if not audio_porta:
		return
	var players = get_tree().get_nodes_in_group("player")
	if players.empty():
		return
	var jogador = players[0]
	var dist = global_transform.origin.distance_to(jogador.global_transform.origin)
	if dist > audio_max_distancia:
		return
	var t = clamp(dist / audio_max_distancia, 0.0, 1.0)
	_audio_player.volume_db = lerp(audio_volume_max_db, -40.0, t)
	_audio_player.stream = audio_porta
	_audio_player.play()
