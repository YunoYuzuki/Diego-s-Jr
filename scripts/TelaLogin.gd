extends Control
# =====================================================================
# TelaLogin — login / registro na API do site
# Hierarquia esperada (a que você montou):
# TelaLogin
# └── Panel
#     ├── Titulo
#     ├── VBoxContainer / LineUser, LineEmail, LinePass
#     ├── BtnEntrar, BtnCriar, BtnSite
#     ├── HTTPRequest
#     └── Msg
# Opcional: Panel/BtnPular  ("Não logar agora")
# =====================================================================

const API_URL := "https://limbo-of-memories-production.up.railway.app/api"
const SITE_URL := "https://limboofmemories.netlify.app"
const CONTA_CFG := "user://limbo_conta.cfg"
# Ajuste se o caminho do menu for outro:
const CENA_MENU := "res://scenes/MainMenu.tscn"

onready var line_user: LineEdit = $Panel/VBoxContainer/LineUser
onready var line_email: LineEdit = $Panel/VBoxContainer/LineEmail
onready var line_pass: LineEdit = $Panel/VBoxContainer/LinePass
onready var btn_entrar: Button = $Panel/BtnEntrar
onready var btn_criar: Button = $Panel/BtnCriar
onready var btn_site: Button = $Panel/BtnSite
onready var http: HTTPRequest = $Panel/HTTPRequest
onready var msg: Label = $Panel/Msg

var btn_pular: Button = null

func _ready() -> void:
	if http:
		http.connect("request_completed", self, "_on_http_done")
	if btn_entrar:
		btn_entrar.connect("pressed", self, "_on_entrar")
	if btn_criar:
		btn_criar.connect("pressed", self, "_on_criar")
	if btn_site:
		btn_site.connect("pressed", self, "_on_site")

	if has_node("Panel/BtnPular"):
		btn_pular = $Panel/BtnPular
		btn_pular.connect("pressed", self, "_on_nao_logar")

	if line_email:
		line_email.visible = false
	if line_pass:
		line_pass.secret = true

	_set_msg("", Color.white)
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("get_web_token") and SaveManager.get_web_token() != "":
		_set_msg("Sessão encontrada. Entrando...", Color(0.6, 1.0, 0.6))
		call_deferred("_ir_pro_menu")


func _on_site() -> void:
	OS.shell_open(SITE_URL)


func _on_nao_logar() -> void:
	_ir_pro_menu()


func _on_entrar() -> void:
	if line_email:
		line_email.visible = false
	var user := line_user.text.strip_edges()
	var senha := line_pass.text
	if user == "" or senha == "":
		_set_msg("Preencha usuário e senha.", Color(1.0, 0.4, 0.4))
		return
	_enviar("/login", {"username": user, "password": senha})


func _on_criar() -> void:
	if line_email and not line_email.visible:
		line_email.visible = true
		_set_msg("Preencha usuário, e-mail e senha e clique de novo em Criar Conta.", Color(0.75, 0.8, 1.0))
		return

	var user := line_user.text.strip_edges()
	var email := ""
	if line_email:
		email = line_email.text.strip_edges()
	var senha := line_pass.text
	if user == "" or email == "" or senha == "":
		_set_msg("Preencha usuário, e-mail e senha.", Color(1.0, 0.4, 0.4))
		return
	if senha.length() < 6:
		_set_msg("A senha precisa ter no mínimo 6 caracteres.", Color(1.0, 0.4, 0.4))
		return
	_enviar("/register", {"username": user, "email": email, "password": senha})


func _enviar(path: String, body: Dictionary) -> void:
	_set_botoes(false)
	_set_msg("Conectando...", Color(0.75, 0.75, 0.75))
	var headers := ["Content-Type: application/json"]
	var err := http.request(API_URL + path, headers, true, HTTPClient.METHOD_POST, to_json(body))
	if err != OK:
		_set_botoes(true)
		_set_msg("Falha ao iniciar conexão.", Color(1.0, 0.4, 0.4))


func _on_http_done(result: int, code: int, _headers: PoolStringArray, body: PoolByteArray) -> void:
	_set_botoes(true)
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_msg("Sem conexão com o servidor.", Color(1.0, 0.4, 0.4))
		return

	var data = parse_json(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_set_msg("Resposta inválida do servidor.", Color(1.0, 0.4, 0.4))
		return

	if code < 200 or code >= 300:
		_set_msg(str(data.get("error", "Erro HTTP %d" % code)), Color(1.0, 0.4, 0.4))
		return

	var token := str(data.get("token", ""))
	var user := str(data.get("username", ""))
	var nick := str(data.get("nickname", user))
	if token == "":
		_set_msg("Servidor não devolveu token.", Color(1.0, 0.4, 0.4))
		return

	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("set_web_token"):
		SaveManager.set_web_token(token)

	var cfg := ConfigFile.new()
	cfg.set_value("conta", "username", user)
	cfg.set_value("conta", "nickname", nick)
	cfg.set_value("conta", "role", str(data.get("role", "user")))
	cfg.save(CONTA_CFG)

	_set_msg("Logado! Entrando no menu...", Color(0.5, 1.0, 0.5))
	call_deferred("_ir_pro_menu")


func _ir_pro_menu() -> void:
	get_tree().change_scene(CENA_MENU)


func _set_botoes(habilitado: bool) -> void:
	if btn_entrar:
		btn_entrar.disabled = not habilitado
	if btn_criar:
		btn_criar.disabled = not habilitado
	if btn_site:
		btn_site.disabled = not habilitado
	if btn_pular:
		btn_pular.disabled = not habilitado


func _set_msg(t: String, c: Color) -> void:
	if msg:
		msg.text = t
		msg.modulate = c
