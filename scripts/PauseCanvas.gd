extends CanvasLayer
onready var btn_continuar = $VBoxContainer/Continuar
onready var btn_config    = $VBoxContainer/Configurar
onready var btn_menu      = $VBoxContainer/Menu
const CONFIG_SCENE = preload("res://scenes/config.tscn")

func _ready():
	layer = 100   # <-- garante que o pause fica acima da HUD normal
	btn_continuar.connect("pressed", self, "_on_continuar_pressed")
	btn_config.connect("pressed", self, "_on_configuracoes_pressed")
	btn_menu.connect("pressed", self, "_on_menu_pressed")

func _get_camera():
	var cams = get_tree().get_nodes_in_group("camera_player")
	return cams[0] if cams.size() > 0 else null

func _on_continuar_pressed():
	var camera = _get_camera()
	if camera:
		camera.unpause_game()

func _on_configuracoes_pressed():
	visible = false
	var config = CONFIG_SCENE.instance()
	config.veio_do_pause = true

	# Config é um Control puro (canvas layer 0 por padrão), então pra
	# ficar ACIMA do pause (layer 100) precisamos embrulhar ele numa
	# CanvasLayer própria com layer maior.
	var wrapper = CanvasLayer.new()
	wrapper.layer = 110
	wrapper.add_to_group("ui_persistente")  # limpa se o jogador sair pro menu com config aberta
	wrapper.add_child(config)
	get_tree().root.add_child(wrapper)

func _on_menu_pressed():
	var camera = _get_camera()
	if camera:
		camera.unpause_game()
	SaveManager._limpar_uis_do_jogo()   # já limpa tudo do grupo ui_persistente
	get_tree().change_scene("res://scenes/MainMenu.tscn")
