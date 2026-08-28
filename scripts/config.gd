extends Control

var veio_do_pause: bool = false  # setado de fora, na hora de instanciar

onready var slider_musica    = $Vbox/Slider_Musica
onready var slider_sfx       = $Vbox/Slider_SFX
onready var check_legendas   = $Vbox/CheckBox_Legendas
onready var option_resolucao = $Vbox/OptionButton_Resolucao
onready var check_tela_cheia = $Vbox/CheckBox_TelaCheia
onready var slider_sensibilidade = $Vbox/Slider_Sensibilidade
onready var label_sensibilidade  = $Vbox/Slider_Sensibilidade/porcent_Mouse

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS  # funciona mesmo com o jogo pausado
	add_to_group("config_screen")  # pra InputManager saber que o config tá aberto e não mexer no pause

	slider_musica.connect("value_changed", self, "_on_Musica_value_changed")
	slider_sfx.connect("value_changed", self, "_on_SFX_value_changed")
	check_legendas.connect("toggled", self, "_on_Legendas_toggled")
	option_resolucao.connect("item_selected", self, "_on_Resolucao_selected")
	check_tela_cheia.connect("toggled", self, "_on_TelaCheia_toggled")
	
	slider_sensibilidade.connect("value_changed", self, "_on_Sensibilidade_value_changed")
	slider_sensibilidade.value = SaveManager.sensibilidade_mouse * 100.0
	label_sensibilidade.text = str(int(slider_sensibilidade.value)) + "%"

	slider_musica.value = SaveManager.volume_musica * 100.0
	slider_sfx.value    = SaveManager.volume_sfx * 100.0
	check_legendas.pressed = SaveManager.legendas_ativadas

	_preencher_opcoes_resolucao()
	option_resolucao.select(SaveManager.resolucao_index)
	check_tela_cheia.pressed = SaveManager.tela_cheia

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_fechar()
		get_tree().set_input_as_handled()

func _fechar() -> void:
	SaveManager.salvar_configuracoes()
	if veio_do_pause:
		var pause_canvas = get_node_or_null("/root/PauseCanvas")
		if pause_canvas == null:
			var cams = get_tree().get_nodes_in_group("camera_player")
			if cams.size() > 0:
				pause_canvas = cams[0].pause_canvas
		if pause_canvas:
			pause_canvas.visible = true
		get_parent().queue_free()   # <-- libera o wrapper (CanvasLayer) inteiro, não só o Control
	else:
		get_tree().change_scene("res://scenes/MainMenu.tscn")

func _on_Musica_value_changed(value):
	SaveManager.volume_musica = value / 100.0
	var idx = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(idx, linear2db(SaveManager.volume_musica))

func _on_SFX_value_changed(value):
	SaveManager.volume_sfx = value / 100.0
	var idx = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(idx, linear2db(SaveManager.volume_sfx))

func _on_Legendas_toggled(pressed):
	SaveManager.legendas_ativadas = pressed
	Legendas.atualizar_visibilidade()

func _preencher_opcoes_resolucao():
	option_resolucao.clear()
	for res in SaveManager.calcular_resolucoes_disponiveis():
		option_resolucao.add_item(res["label"])

func _on_Resolucao_selected(index):
	SaveManager.resolucao_index = index
	SaveManager.aplicar_resolucao()

func _on_TelaCheia_toggled(pressed):
	SaveManager.tela_cheia = pressed
	SaveManager.aplicar_resolucao()
	
func _on_Sensibilidade_value_changed(value):
	SaveManager.sensibilidade_mouse = value / 100.0
	label_sensibilidade.text = str(int(value)) + "%"
	SaveManager.aplicar_sensibilidade()
