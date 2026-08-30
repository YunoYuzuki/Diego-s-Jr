extends Control

onready var music = $Theme_Title
onready var viewport_3d = $Viewport
var save_ui_scene = preload("res://scenes/SaveUI.tscn")

const API = "https://limbo-of-memories-production.up.railway.app/api"
const SITE_URL := "https://limboofmemories.netlify.app"
const SITE_RANKING_URL := "https://limboofmemories.netlify.app/#ranking"
const CENA_LOGIN := "res://scenes/TelaLogin.tscn"
const CONTA_CFG := "user://limbo_conta.cfg"

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_limpar_ui_gameplay_orfan()

	_conectar_botao("VBox_Buttons/Carregar", "_on_Btn_Load_pressed")
	_conectar_botao("VBox_Buttons/Iniciar", "_on_Btn_Iniciar_pressed")
	_conectar_botao("VBox_Buttons/Sair", "_on_Btn_Sair_pressed")
	_conectar_botao("VBox_Buttons/Configurar", "_on_Btn_Configurar_pressed")
	_conectar_botao("VBox_Buttons/Ranking", "_on_Btn_Ranking_pressed")
	_conectar_botao("VBox_Buttons/Conta", "_on_Btn_Conta_pressed")
	# Se o botão ainda se chama Debug na cena, mas o texto é "Conta"
	_conectar_botao("VBox_Buttons/Debug", "_on_Btn_Conta_pressed")

	if viewport_3d:
		# false evita a câmera/fundo 3D de cabeça pra baixo quando o CRT
		# (PostProcess) é aplicado por cima do Viewport do menu
		viewport_3d.render_target_v_flip = false
		_corrigir_flip_display_viewport(viewport_3d)

	music.volume_db = -20
	music.play()

	call_deferred("_garantir_camera_menu")
	call_deferred("_atualizar_bemvindo")
	call_deferred("_garantir_popup_logout")


## Conecta pressed se o nó existir e ainda não estiver conectado.
func _conectar_botao(caminho: String, metodo: String) -> void:
	var btn = get_node_or_null(caminho)
	if btn == null:
		return
	if not btn is BaseButton:
		return
	if btn.is_connected("pressed", self, metodo):
		return
	btn.connect("pressed", self, metodo)
	print("MainMenu: conectado ", caminho, " → ", metodo)


func _limpar_ui_gameplay_orfan() -> void:
	for n in get_tree().get_nodes_in_group("ui_persistente"):
		if is_instance_valid(n) and n.get_parent() == get_tree().root:
			n.queue_free()
	for n in get_tree().get_nodes_in_group("reparentar_hud"):
		if is_instance_valid(n) and n.get_parent() == get_tree().root:
			n.queue_free()


## Corrige TextureRect / ViewportContainer que mostram o Viewport —
## com CRT ativo, flip errado deixa o fundo de cabeça pra baixo.
func _corrigir_flip_display_viewport(vp: Viewport) -> void:
	if vp == null:
		return
	var parent = vp.get_parent()
	if parent is ViewportContainer:
		parent.stretch = true
	_fix_flip_recursivo(self)


func _fix_flip_recursivo(node: Node) -> void:
	if node is TextureRect:
		var tr: TextureRect = node
		if tr.texture is ViewportTexture:
			tr.flip_v = false
	for c in node.get_children():
		_fix_flip_recursivo(c)


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
	var label = get_node_or_null("HBoxContainer/Label")
	if label == null:
		label = find_node("Label", true, false)
	if label == null:
		return
	var nick := ""
	var cfg := ConfigFile.new()
	if cfg.load(CONTA_CFG) == OK:
		nick = str(cfg.get_value("conta", "nickname", ""))
	if nick == "":
		label.text = ""
		return
	label.text = "Bem vindo, " + nick
	# Clique no nome abre popup de sair da conta
	if label is Control and not label.is_connected("gui_input", self, "_on_bemvindo_gui_input"):
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.connect("gui_input", self, "_on_bemvindo_gui_input")


func _on_bemvindo_gui_input(event: InputEvent) -> void:
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


func _on_Btn_Ranking_pressed() -> void:
	# Abre o ranking DENTRO do jogo (autoload RankingUI)
	if typeof(RankingUI) != TYPE_NIL and RankingUI.has_method("abrir"):
		RankingUI.abrir()
		print("MainMenu: RankingUI.abrir()")
	else:
		push_warning("MainMenu: RankingUI não encontrado. Adicione RankingUI.gd como Autoload.")
		OS.shell_open(SITE_RANKING_URL)


func _on_Btn_Conta_pressed() -> void:
	# Tela de login / registro da conta
	if ResourceLoader.exists(CENA_LOGIN):
		get_tree().change_scene(CENA_LOGIN)
	else:
		push_warning("MainMenu: cena de login não encontrada: %s" % CENA_LOGIN)
		OS.shell_open(SITE_URL)


func _on_Debug_pressed():
	# Mantido por compatibilidade — agora aponta pra Conta
	_on_Btn_Conta_pressed()
