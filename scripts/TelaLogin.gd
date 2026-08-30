extends Control
# =====================================================================
# TelaLogin — login / registro na API do site
# =====================================================================

const API_URL := "https://limbo-of-memories-production.up.railway.app/api"
const SITE_URL := "https://limboofmemories.netlify.app"
const CONTA_CFG := "user://limbo_conta.cfg"
const CENA_MENU := "res://scenes/MainMenu.tscn"

# ---- Paleta do tema (preto + roxo) ----
const COR_FUNDO      := Color8(15, 9, 24)      # bg do Panel, quase preto com base roxa
const COR_CAMPO      := Color8(9, 6, 15)       # bg dos LineEdit, mais escuro que o painel
const COR_BORDA      := Color8(70, 32, 132)    # roxo escuro (borda em repouso)
const COR_BORDA_FOCO := Color8(147, 88, 235)   # roxo vibrante (foco/hover)
const COR_ROXO       := Color8(147, 88, 235)
const COR_ROXO_CLARO := Color8(196, 168, 250)
const COR_TEXTO      := Color8(232, 226, 245)
const COR_TEXTO_FRACO:= Color8(150, 138, 175)

onready var painel: Panel = $Panel
onready var titulo: Label = $Panel/Titulo
onready var vbox: VBoxContainer = $Panel/VBoxContainer
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
	_aplicar_tema()

	if http:
		http.use_threads = true
		http.timeout = 10.0
		http.connect("request_completed", self, "_on_http_done")
	if btn_entrar:
		btn_entrar.connect("pressed", self, "_on_entrar")
	if btn_criar:
		btn_criar.connect("pressed", self, "_on_criar")
	if btn_site:
		btn_site.connect("pressed", self, "_on_site")

	if line_user:
		line_user.connect("text_entered", self, "_on_enter_pressed")
	if line_email:
		line_email.connect("text_entered", self, "_on_enter_pressed")
	if line_pass:
		line_pass.connect("text_entered", self, "_on_enter_pressed")

	if has_node("Panel/BtnPular"):
		btn_pular = $Panel/BtnPular
		_estilizar_botao_fantasma(btn_pular)
		btn_pular.connect("pressed", self, "_on_nao_logar")

	if line_email:
		line_email.visible = false
	if line_pass:
		line_pass.secret = true

	_set_msg("", Color.white)
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("get_web_token") and SaveManager.get_web_token() != "":
		_set_msg("Sessão encontrada. Entrando...", Color(0.6, 1.0, 0.6))
		call_deferred("_ir_pro_menu")


# =====================================================================
# TEMA VISUAL (preto + roxo) — tudo aplicado por código, via overrides
# =====================================================================

func _aplicar_tema() -> void:
	_estilizar_painel()
	_estilizar_titulo()
	_estilizar_campos()
	_estilizar_botao_principal(btn_entrar)
	_estilizar_botao_secundario(btn_criar)
	_estilizar_botao_secundario(btn_site)
	_estilizar_msg()
	if vbox:
		vbox.add_constant_override("separation", 18)


func _sb(bg: Color, borda: Color, largura_borda: int, raio: int, sombra: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = borda
	sb.set_border_width_all(largura_borda)
	sb.set_corner_radius_all(raio)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if sombra:
		sb.shadow_color = Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.28)
		sb.shadow_size = 18
	return sb


func _estilizar_painel() -> void:
	if not painel:
		return
	painel.add_stylebox_override("panel", _sb(COR_FUNDO, COR_BORDA, 2, 0, false))


func _estilizar_titulo() -> void:
	if not titulo:
		return
	titulo.add_color_override("font_color", COR_ROXO_CLARO)
	titulo.add_color_override("font_color_shadow", Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.55))
	titulo.add_constant_override("shadow_offset_x", 0)
	titulo.add_constant_override("shadow_offset_y", 3)
	var fonte_maior := _fonte_com_novo_tamanho(titulo.get_font("font"), 22)
	if fonte_maior:
		titulo.add_font_override("font", fonte_maior)
	# garante legibilidade mesmo se a fonte base for minúscula
	if fonte_maior == null and titulo.get_font("font") is DynamicFont:
		var f2 := titulo.get_font("font").duplicate()
		f2.size = max(f2.size, 34)
		titulo.add_font_override("font", f2)


func _estilizar_campos() -> void:
	for campo in [line_user, line_email, line_pass]:
		if not campo:
			continue
		campo.add_stylebox_override("normal", _sb(COR_CAMPO, COR_BORDA, 1, 8))
		campo.add_stylebox_override("focus", _sb(COR_CAMPO, COR_BORDA_FOCO, 2, 8))
		campo.add_stylebox_override("read_only", _sb(COR_CAMPO, COR_BORDA, 1, 8))
		campo.add_color_override("font_color", COR_TEXTO)
		var fc := _fonte_com_novo_tamanho(campo.get_font("font"), 6)
		if fc:
			campo.add_font_override("font", fc)
		campo.rect_min_size.y = max(campo.rect_min_size.y, 40)
		campo.add_color_override("cursor_color", COR_ROXO_CLARO)
		campo.add_color_override("selection_color", Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.45))


func _estilizar_botao_principal(btn: Button) -> void:

	var _fb := _fonte_com_novo_tamanho(btn.get_font("font"), 8)
	if _fb:
		btn.add_font_override("font", _fb)
	btn.rect_min_size.y = max(btn.rect_min_size.y, 46)
	if not btn:
		return
	btn.add_stylebox_override("normal", _sb(COR_ROXO, COR_ROXO, 0, 10, true))
	btn.add_stylebox_override("hover", _sb(COR_BORDA_FOCO, COR_BORDA_FOCO, 0, 10, true))
	btn.add_stylebox_override("pressed", _sb(Color8(108, 58, 190), Color8(108, 58, 190), 0, 10))
	btn.add_stylebox_override("disabled", _sb(Color8(45, 35, 60), Color8(45, 35, 60), 0, 10))
	btn.add_stylebox_override("focus", _sb(COR_ROXO, COR_BORDA_FOCO, 2, 10))
	btn.add_color_override("font_color", Color8(255, 255, 255))
	btn.add_color_override("font_color_hover", Color8(255, 255, 255))
	btn.add_color_override("font_color_disabled", COR_TEXTO_FRACO)


func _estilizar_botao_secundario(btn: Button) -> void:

	var _fb := _fonte_com_novo_tamanho(btn.get_font("font"), 6)
	if _fb:
		btn.add_font_override("font", _fb)
	btn.rect_min_size.y = max(btn.rect_min_size.y, 46)
	if not btn:
		return
	btn.add_stylebox_override("normal", _sb(Color(0, 0, 0, 0), COR_BORDA, 1, 8))
	btn.add_stylebox_override("hover", _sb(Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.12), COR_BORDA_FOCO, 1, 8))
	btn.add_stylebox_override("pressed", _sb(Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.22), COR_BORDA_FOCO, 1, 8))
	btn.add_stylebox_override("disabled", _sb(Color(0, 0, 0, 0), Color8(45, 35, 60), 1, 8))
	btn.add_stylebox_override("focus", _sb(Color(0, 0, 0, 0), COR_BORDA_FOCO, 2, 8))
	btn.add_color_override("font_color", COR_ROXO_CLARO)
	btn.add_color_override("font_color_hover", Color8(255, 255, 255))
	btn.add_color_override("font_color_disabled", COR_TEXTO_FRACO)


func _estilizar_botao_fantasma(btn: Button) -> void:

	var _fb := _fonte_com_novo_tamanho(btn.get_font("font"), 4)
	if _fb:
		btn.add_font_override("font", _fb)
	btn.rect_min_size.y = max(btn.rect_min_size.y, 46)
	if not btn:
		return
	var vazio := StyleBoxEmpty.new()
	btn.add_stylebox_override("normal", vazio)
	btn.add_stylebox_override("pressed", vazio)
	btn.add_stylebox_override("disabled", vazio)
	btn.add_stylebox_override("hover", vazio)
	btn.add_stylebox_override("focus", vazio)
	btn.add_color_override("font_color", COR_TEXTO_FRACO)
	btn.add_color_override("font_color_hover", COR_ROXO_CLARO)
	btn.add_color_override("font_color_disabled", COR_TEXTO_FRACO)


func _estilizar_msg() -> void:
	if not msg:
		return
	msg.add_constant_override("shadow_offset_x", 0)
	msg.add_constant_override("shadow_offset_y", 2)


## Duplica a fonte atual (se for DynamicFont) com um tamanho maior,
## mantendo a mesma família/estilo — assim não perde a fonte pixelada do jogo.
func _fonte_com_novo_tamanho(base: Font, extra: int) -> Font:
	if base and base is DynamicFont:
		var nova := DynamicFont.new()
		nova.font_data = base.font_data
		nova.size = max(base.size + extra, 18)
		nova.outline_size = max(base.outline_size, 1)
		nova.outline_color = base.outline_color if base.outline_color.a > 0.0 else Color(0, 0, 0, 0.6)
		return nova
	return null


# =====================================================================
# LÓGICA ORIGINAL (sem mudanças)
# =====================================================================

func _on_site() -> void:
	OS.shell_open(SITE_URL)


func _on_enter_pressed(_texto: String = "") -> void:
	if btn_entrar and btn_entrar.disabled:
		return
	if line_email and line_email.visible:
		_on_criar()
	else:
		_on_entrar()


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
