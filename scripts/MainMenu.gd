extends Control

onready var music = $Theme_Title
onready var viewport_3d = get_node_or_null("Viewport")
var save_ui_scene = preload("res://scenes/SaveUI.tscn")

const API = "https://limbo-of-memories-production.up.railway.app/api"
const CONTA_CFG := "user://limbo_conta.cfg"

func _ready():
	# Voltar do jogo pro menu chega aqui com o mouse ainda CAPTURED
	# (PauseCanvas -> unpause_game()). Cursor invisivel = menu parece travado.
	# Restaurar aqui cobre qualquer caminho que leve ao menu.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_limpar_ui_gameplay_orfan()
	
	$VBox_Buttons/Carregar.connect("pressed", self, "_on_Btn_Load_pressed")
	$VBox_Buttons/Iniciar.connect("pressed", self, "_on_Btn_Iniciar_pressed")
	$VBox_Buttons/Sair.connect("pressed",   self, "_on_Btn_Sair_pressed")
	if has_node("VBox_Buttons/Configurar"):
		$VBox_Buttons/Configurar.connect("pressed", self, "_on_Btn_Configurar_pressed")
	if has_node("VBox_Buttons/Debug"):
		$VBox_Buttons/Debug.connect("pressed", self, "_on_Debug_pressed")
	if has_node("VBox_Buttons/Ranking"):
		$VBox_Buttons/Ranking.connect("pressed", self, "_on_Btn_Ranking_pressed")
	
	if viewport_3d:
		viewport_3d.render_target_v_flip = true
	
	if music:
		music.volume_db = -20
		music.play()

	call_deferred("_garantir_camera_menu")
	call_deferred("_atualizar_bemvindo")
	call_deferred("_garantir_popup_logout")


func _limpar_ui_gameplay_orfan() -> void:
	for n in get_tree().get_nodes_in_group("ui_persistente"):
		if is_instance_valid(n) and n.get_parent() == get_tree().root:
			n.queue_free()
	for n in get_tree().get_nodes_in_group("reparentar_hud"):
		if is_instance_valid(n) and n.get_parent() == get_tree().root:
			n.queue_free()


func _garantir_camera_menu() -> void:
	var cameras = get_tree().get_nodes_in_group("camera_menu")
	if cameras.size() > 0:
		var cam = cameras[0]
		if cam is Spatial:
			cam.visible = true
		for c in get_tree().get_nodes_in_group("camera_player"):
			if c is Camera:
				c.current = false
		cam.current = true
		print("MainMenu: camera_menu garantida → ", cam.get_path())
	else:
		print("MainMenu: nenhuma camera_menu no group (QuartoMenu ainda pode ativar)")


func _atualizar_bemvindo() -> void:
	var label = get_node_or_null("LabelBemVindo")
	if label == null:
		# cria se não existir
		label = Label.new()
		label.name = "LabelBemVindo"
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.anchor_left = 1.0
		label.anchor_right = 1.0
		label.margin_left = -360
		label.margin_right = -16
		label.margin_top = 16
		label.margin_bottom = 48
		label.align = Label.ALIGN_RIGHT
		add_child(label)
	# limpa conexões antigas
	if label.is_connected("gui_input", self, "_on_bemvindo_input"):
		label.disconnect("gui_input", self, "_on_bemvindo_input")
	label.connect("gui_input", self, "_on_bemvindo_input")

	var token_ok := false
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("get_web_token"):
		token_ok = SaveManager.get_web_token() != ""
	var cfg := ConfigFile.new()
	var nick := ""
	if cfg.load(CONTA_CFG) == OK:
		nick = str(cfg.get_value("conta", "nickname", ""))
		if nick == "":
			nick = str(cfg.get_value("conta", "username", ""))
	if token_ok and nick != "":
		label.text = "Bem-vindo, %s" % nick
		label.add_color_override("font_color", Color(0.35, 0.95, 0.45))
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.hint_tooltip = "Clique para sair da conta"
	else:
		label.text = ""
		label.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _on_bemvindo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		_mostrar_popup_sair_conta()


func _garantir_popup_logout() -> void:
	if has_node("PopupSairConta"):
		return
	var pop := ConfirmationDialog.new()
	pop.name = "PopupSairConta"
	pop.dialog_text = "Sair da conta?"
	pop.window_title = "Conta"
	pop.get_ok().text = "Sim"
	pop.get_cancel().text = "Não"
	pop.connect("confirmed", self, "_sair_da_conta")
	add_child(pop)


func _mostrar_popup_sair_conta() -> void:
	var pop = get_node_or_null("PopupSairConta")
	if pop:
		pop.popup_centered()


func _sair_da_conta() -> void:
	if typeof(SaveManager) != TYPE_NIL:
		if SaveManager.has_method("set_web_token"):
			SaveManager.set_web_token("")
		if SaveManager.has_method("encerrar_sessao_web"):
			SaveManager.encerrar_sessao_web()
	var dir := Directory.new()
	if dir.file_exists(CONTA_CFG):
		dir.remove(CONTA_CFG)
	# apaga token file também
	if dir.file_exists("user://limbo_web_token.txt"):
		dir.remove("user://limbo_web_token.txt")
	_atualizar_bemvindo()
	print("MainMenu: saiu da conta")


func _on_Btn_Iniciar_pressed():
	# Novo jogo sempre zera o estado local (tutoriais, itens, etc.)
	Global.rodando_como_menu_bg = false
	Global.slot_para_carregar = -1
	Global.cena_destino = "res://scenes/CenaNarrativa.tscn"
	get_tree().change_scene("res://scenes/TelaCarregamento.tscn")


func _on_Btn_Ranking_pressed():
	if typeof(RankingUI) != TYPE_NIL and RankingUI.has_method("abrir"):
		RankingUI.abrir()


func _on_Btn_Load_pressed():
	var ui = save_ui_scene.instance()
	ui.main_menu = true
	get_tree().get_root().add_child(ui)
	yield(get_tree(), "idle_frame")
	ui.open()


func _on_Btn_Sair_pressed():
	get_tree().quit()


func _on_Btn_Configurar_pressed():
	get_tree().change_scene("res://scenes/config.tscn")


func _on_Debug_pressed():
	get_tree().change_scene("res://scenes/TelaLogin.tscn")
