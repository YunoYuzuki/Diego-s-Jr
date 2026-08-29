extends StaticBody

#  Portinha 
const PORTINHA_ABERTA_TRANS  = Vector3(-0.042, -0.017, 1.086)
const PORTINHA_FECHADA_TRANS = Vector3(-0.042, -0.007, 1.086)
const PORTINHA_FECHADA_ROT   = Vector3(0.0, 0.0, -25.0)

export(float) var tween_speed    = 0.3
export(float) var dist_min       = 4.0   # distncia mnima: volume mximo
export(float) var dist_max       = 30.0  # distncia mxima: silncio total

onready var portinha     = $portinha
onready var outline_mesh = $gravador/OutlineMesh
onready var audio_player = $AudioStreamPlayer

var fita_tocando : bool = false
var jogador      : Node = null

# 
func _ready():
	add_to_group("interagivel")
	add_to_group("Persist_estatico")
	if outline_mesh:
		outline_mesh.visible = false
	_set_portinha_aberta(true)

# 
func _process(_delta):
	if not fita_tocando or jogador == null:
		return

	var distancia = global_transform.origin.distance_to(jogador.global_transform.origin)
	var t         = clamp((distancia - dist_min) / (dist_max - dist_min), 0.0, 1.0)
	# t=0  perto  0db | t=1  longe  -80db (silncio)
	audio_player.volume_db = lerp(0.0, -80.0, t)

# 
func set_foco(ativo: bool):
	if outline_mesh:
		outline_mesh.visible = ativo

# 
func interagir(camera):
	if fita_tocando:
		return
	if not Inventory.has_item("fita_cassete"):
		camera._mostrar_mensagem("Voce nao possui nenhuma fita.")
		return
	jogador = camera.get_parent()
	var audio = camera.fita_audio
	var nome  = camera.fita_nome
	Inventory.remove_item("fita_cassete")
	_tocar_fita(camera, audio, nome)

# 
func _tocar_fita(camera, audio: AudioStream, nome: String):
	fita_tocando = true

	_animar_portinha(false)
	yield(get_tree().create_timer(tween_speed + 0.1), "timeout")

	camera.mostrar_cassete_ui(nome)

	audio_player.volume_db = 0.0
	audio_player.stream    = audio
	audio_player.play()

	yield(audio_player, "finished")

	camera.esconder_cassete_ui()
	_animar_portinha(true)
	fita_tocando = false
	jogador      = null

# 
func _animar_portinha(abrir: bool):
	var tween = Tween.new()
	add_child(tween)

	var trans_alvo = PORTINHA_ABERTA_TRANS  if abrir else PORTINHA_FECHADA_TRANS
	var rot_alvo   = Vector3.ZERO           if abrir else PORTINHA_FECHADA_ROT

	tween.interpolate_property(portinha, "translation",
		portinha.translation, trans_alvo,
		tween_speed, Tween.TRANS_SINE, Tween.EASE_IN_OUT)

	tween.interpolate_property(portinha, "rotation_degrees",
		portinha.rotation_degrees, rot_alvo,
		tween_speed, Tween.TRANS_SINE, Tween.EASE_IN_OUT)

	tween.start()
	yield(tween, "tween_all_completed")
	tween.queue_free()

func _set_portinha_aberta(abrir: bool):
	portinha.translation      = PORTINHA_ABERTA_TRANS  if abrir else PORTINHA_FECHADA_TRANS
	portinha.rotation_degrees = Vector3.ZERO           if abrir else PORTINHA_FECHADA_ROT
