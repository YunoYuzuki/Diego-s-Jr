extends StaticBody

export var distancia_abrir : float = 0.5
export var velocidade      : float = 4.0
export(AudioStream) var som_gaveta

var aberta        : bool  = false
var pos_fechada   : Vector3
var pos_aberta    : Vector3
var audio_player  : AudioStreamPlayer3D

func _ready():
	add_to_group("interagivel")
	pos_fechada = translation
	pos_aberta  = translation - transform.basis.y * distancia_abrir

	audio_player = AudioStreamPlayer3D.new()
	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	audio_player.unit_db = 10.0
	audio_player.unit_size = 10.0
	audio_player.max_distance = 40.0
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(audio_player)
	if som_gaveta:
		audio_player.stream = som_gaveta

func _process(delta):
	var alvo = pos_aberta if aberta else pos_fechada
	translation = translation.linear_interpolate(alvo, velocidade * delta)

func interagir(_camera):
	aberta = not aberta
	if audio_player and audio_player.stream:
		audio_player.play()

func set_foco(_ativo: bool):
	pass
