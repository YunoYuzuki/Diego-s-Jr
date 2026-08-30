extends Control

onready var video_logo := $VideoLogo
onready var tela_preta := $TelaPreta
onready var aviso_save := $TelaPreta/AvisoAutoSave

const TEMPO_PRE_LOGO = 2.0
const TEMPO_POS_LOGO = 2.0
const TEMPO_AVISO_SAVE = 2.9

func _ready():
	video_logo.visible = false
	aviso_save.visible = false
	tela_preta.visible = true
	_limpar_ui_orfan()
	_tocar_intro()

func _limpar_ui_orfan() -> void:
	for n in get_tree().get_nodes_in_group("ui_persistente"):
		if is_instance_valid(n) and n.get_parent() == get_tree().root:
			n.queue_free()
	for n in get_tree().get_nodes_in_group("reparentar_hud"):
		if is_instance_valid(n) and n.get_parent() == get_tree().root:
			n.queue_free()

func _tocar_intro():
	yield(get_tree().create_timer(TEMPO_PRE_LOGO), "timeout")
	tela_preta.visible = false

	video_logo.visible = true
	video_logo.play()
	yield(video_logo, "finished")
	video_logo.visible = false

	tela_preta.visible = true
	yield(get_tree().create_timer(TEMPO_POS_LOGO), "timeout")

	aviso_save.visible = true
	yield(get_tree().create_timer(TEMPO_AVISO_SAVE), "timeout")
	aviso_save.visible = false

	get_tree().change_scene("res://scenes/TelaLogin.tscn")
