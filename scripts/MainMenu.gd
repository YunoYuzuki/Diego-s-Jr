extends Control

onready var music = $Theme_Title
onready var http  = $HTTPRequest
onready var overlay = $LoginOverlay

var save_ui_scene = preload("res://scenes/SaveUI.tscn")

# troque pela URL do Railway quando hospedar
const API = "http://localhost:3000"

func _ready():
	$VBox_Buttons/Carregar.connect("pressed", self, "_on_Btn_Load_pressed")
	$VBox_Buttons/Iniciar.connect("pressed", self, "_on_Btn_Iniciar_pressed")
	$VBox_Buttons/Sair.connect("pressed",   self, "_on_Btn_Sair_pressed")
	http.connect("request_completed", self, "_on_request_completed")
	
	music.stream = preload("res://assets/musics/ambience_theme.mp3")
	music.volume_db = -20
	music.play()

	# se j tem token salvo, pula o login direto
	if SaveManager.token != "":
		overlay.visible = false
	else:
		overlay.visible = true

#  BOTES DO OVERLAY 

func _on_BtnEntrar_pressed():
	var user  = $LoginOverlay/VBoxContainer/LoginUser.text.strip_edges()
	var senha = $LoginOverlay/VBoxContainer/LoginSenha.text

	if user == "" or senha == "":
		_set_msg("preencha todos os campos")
		return

	_set_msg("entrando...")
	$LoginOverlay/VBoxContainer/BtnEntrar.disabled = true

	var body = JSON.print({ "identifier": user, "password": senha })
	var headers = ["Content-Type: application/json"]
	http.request(API + "/api/auth/login", headers, true, HTTPClient.METHOD_POST, body)

func _on_BtnCriarConta_pressed():
	OS.shell_open(API + "?register=true")

func _on_BtnSemConta_pressed():
	overlay.visible = false

#  RESPOSTA DA API 

func _on_request_completed(result, response_code, _headers, body):
	$LoginOverlay/VBoxContainer/BtnEntrar.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_set_msg("erro de conexo com o servidor")
		return

	var json  = JSON.parse(body.get_string_from_utf8())
	if json.error != OK:
		_set_msg("resposta invlida do servidor")
		return

	var data = json.result

	if response_code == 200:
		# salva token e nome no GameState pra usar no resto do jogo
		SaveManager.token     = data.token
		SaveManager.player_name = data.user.name
		overlay.visible = false
		_set_msg("")
	else:
		var msg = data.get("error", "erro desconhecido")
		_set_msg(msg)

#  MENU PRINCIPAL 

func _on_Btn_Iniciar_pressed():
	get_tree().change_scene("res://scenes/casa_ofc.tscn")

func _on_Btn_Load_pressed():
	var ui = save_ui_scene.instance()
	ui.main_menu = true
	get_tree().get_root().add_child(ui)
	yield(get_tree(), "idle_frame")  # espera o _ready rodar
	ui.open()
	
func _on_Btn_Sair_pressed():
	get_tree().quit()

#  HELPER 

func _set_msg(text):
	$LoginOverlay/VBoxContainer/LoginMsg.text = text
