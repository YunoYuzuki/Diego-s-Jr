extends StaticBody
export var angulo_aberta    : float = -120.0
export var velocidade_porta : float = 2.5
export var velocidade_maca  : float = 4.5
# Fechamento/abertura pela Sombra (bater) — bem mais rápido, combina com o SFX
export var velocidade_porta_bater : float = 14.0
export var velocidade_maca_bater  : float = 18.0

export var tempo_trancada_min : float = 60.0
export var tempo_trancada_max : float = 120.0

export(AudioStream) var audio_porta            
export(AudioStream) var audio_bater_porta      
export(AudioStream) var audio_porta_trancada   
export var audio_max_distance : float = 45.0
export var audio_unit_db : float = 10.0

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
var _anim_tempo : float = 0.0
var _modo_bater : bool = false  # true = animação rápida (Sombra)
const ANIM_TIMEOUT : float = 4.0  # se a animação travar, libera a porta

var _timer_trancada : Timer
var _audio_player : AudioStreamPlayer3D

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

	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.stream = audio_porta
	_audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	_audio_player.unit_db = audio_unit_db
	_audio_player.unit_size = 10.0
	_audio_player.max_distance = audio_max_distance
	_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(_audio_player)

func set_foco(_ativo: bool):
	pass

func interagir(_player):
	if trancada:
		_tocar_som(audio_porta_trancada)
		return
	if animando:
		return
	_modo_bater = false
	aberta     = !aberta
	alvo_porta = angulo_aberta if aberta else 0.0
	animando   = true
	_anim_tempo = 0.0
	_atualizar_colisoes()
	_tocar_som(audio_porta)

func bater_porta() -> void:
	if animando or trancada:
		return
	# Animação rápida pra combinar com o SFX de bater
	_modo_bater = true
	aberta     = !aberta
	alvo_porta = angulo_aberta if aberta else 0.0
	animando   = true
	_anim_tempo = 0.0
	_atualizar_colisoes()
	_tocar_som(audio_bater_porta)

func _atualizar_colisoes():
	colisao_vao.disabled   = aberta   
	colisao_porta.disabled = !aberta  

func _process(delta):
	if not animando:
		return

	_anim_tempo += delta
	# Safety: se a animação travar (maçaneta nunca chega), libera a porta
	if _anim_tempo >= ANIM_TIMEOUT:
		pivot.rotation_degrees.z = alvo_porta
		animando = false
		_anim_tempo = 0.0
		_atualizar_colisoes()
		return

	var alvo_m1 = alvo_maca1 if aberta else repouso_maca1
	var alvo_m2 = alvo_maca2 if aberta else repouso_maca2
	var vel_maca = velocidade_maca_bater if _modo_bater else velocidade_maca
	var vel_porta = velocidade_porta_bater if _modo_bater else velocidade_porta
	var t_maca  = vel_maca * delta

	machaneta1.rotation_degrees = _lerp_rot(machaneta1.rotation_degrees, alvo_m1, t_maca)
	machaneta2.rotation_degrees = _lerp_rot(machaneta2.rotation_degrees, alvo_m2, t_maca)

	# No modo bater, não espera a maçaneta — porta já se move
	var maca_pronta = _modo_bater or machaneta1.rotation_degrees.distance_to(alvo_m1) < 2.0
	if maca_pronta:
		var rp = pivot.rotation_degrees
		rp.z = lerp(rp.z, alvo_porta, vel_porta * delta)
		pivot.rotation_degrees = rp
		var limiar = 1.5 if _modo_bater else 0.1
		if abs(rp.z - alvo_porta) < limiar:
			pivot.rotation_degrees.z    = alvo_porta
			machaneta1.rotation_degrees = alvo_m1
			machaneta2.rotation_degrees = alvo_m2
			animando = false
			_modo_bater = false
			_anim_tempo = 0.0
			
func _lerp_rot(atual: Vector3, alvo: Vector3, t: float) -> Vector3:
	return Vector3(
		rad2deg(lerp_angle(deg2rad(atual.x), deg2rad(alvo.x), t)),
		rad2deg(lerp_angle(deg2rad(atual.y), deg2rad(alvo.y), t)),
		rad2deg(lerp_angle(deg2rad(atual.z), deg2rad(alvo.z), t))
	)

# SALVAMENTO TOTALMENTE ALINHADO COM O NOVO GERENCIADOR
func save() -> Dictionary:
	return {
		"aberta": aberta,
		"trancada": trancada
	}

func load_data(data: Dictionary) -> void:
	aberta   = data.get("aberta", false)
	trancada = data.get("trancada", false)
	
	# Força o pivô 3D a rotacionar imediatamente para a posição correta
	alvo_porta = angulo_aberta if aberta else 0.0
	if not pivot:
		pivot = $Door/pivot_porta
	pivot.rotation_degrees.z = alvo_porta
	_atualizar_colisoes()



func trancar_externo() -> void:
	if aberta:
		return
	trancada = true
	# Garante timer válido (pode ter sido parado/reiniciado)
	if _timer_trancada == null:
		_timer_trancada = Timer.new()
		_timer_trancada.one_shot = true
		add_child(_timer_trancada)
		if not _timer_trancada.is_connected("timeout", self, "_destrancar"):
			_timer_trancada.connect("timeout", self, "_destrancar")
	var tempo = rand_range(tempo_trancada_min, tempo_trancada_max)
	_timer_trancada.start(tempo)
	_tocar_som(audio_porta_trancada)
	print("🚪 Porta trancada por %.0fs: " % tempo, name)

func _destrancar() -> void:
	trancada = false
	print("🚪 Porta destrancada: ", name)

## API pública usada pela Sombra / outros sistemas (alias de _destrancar)
func destrancar_externo() -> void:
	if _timer_trancada and not _timer_trancada.is_stopped():
		_timer_trancada.stop()
	trancada = false
	print("🚪 Porta destrancada (externo): ", name)

func _tocar_som(stream: AudioStream) -> void:
	if not stream or _audio_player == null:
		return
	_audio_player.stream = stream
	_audio_player.unit_db = audio_unit_db
	_audio_player.max_distance = audio_max_distance
	_audio_player.play()
