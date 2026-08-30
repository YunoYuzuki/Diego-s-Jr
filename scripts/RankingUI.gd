extends CanvasLayer
# =====================================================================
# RANKING UI — mostra o ranking do site dentro do jogo, com auto-refresh
# Tema visual: preto + roxo, tudo montado e estilizado 100% por código.
# =====================================================================

const REFRESH_INTERVAL := 15.0

# ---- Paleta do tema (preto + roxo) ----
const COR_FUNDO_OVERLAY := Color(0.02, 0.0, 0.04, 0.82)
const COR_PAINEL      := Color8(15, 9, 24)
const COR_BORDA       := Color8(70, 32, 132)
const COR_ROXO        := Color8(147, 88, 235)
const COR_ROXO_CLARO  := Color8(196, 168, 250)
const COR_TEXTO       := Color8(232, 226, 245)
const COR_TEXTO_FRACO := Color8(150, 138, 175)
const COR_LINHA_PAR   := Color8(22, 14, 34)
const COR_LINHA_IMPAR := Color8(17, 11, 27)
const COR_OURO        := Color8(255, 208, 92)
const COR_PRATA       := Color8(210, 214, 224)
const COR_BRONZE      := Color8(206, 140, 92)
const COR_ONLINE      := Color8(74, 222, 128)
const COR_OFFLINE     := Color8(120, 112, 132)

var esta_aberta := false

var _fundo: ColorRect
var _painel: PanelContainer
var _lista_vbox: VBoxContainer
var _label_titulo: Label
var _label_status: Label
var _http: HTTPRequest
var _timer_refresh: Timer


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	layer = 120
	_construir_ui()
	visible = false
	set_process_input(true)


# ---------------------------------------------------------------------
# Helpers de estilo
# ---------------------------------------------------------------------

func _sb(bg: Color, borda: Color, largura_borda: int, raio: int, sombra: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = borda
	sb.set_border_width_all(largura_borda)
	sb.set_corner_radius_all(raio)
	if sombra:
		sb.shadow_color = Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.3)
		sb.shadow_size = 22
	return sb


func _label(texto: String, cor: Color, alinhamento: int = Label.ALIGN_LEFT, largura_min: float = 0.0) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_color_override("font_color", cor)
	l.align = alinhamento
	if largura_min > 0.0:
		l.rect_min_size = Vector2(largura_min, 0)
	var f := _fonte_com_novo_tamanho(l.get_font("font"), 6)
	if f:
		l.add_font_override("font", f)
	return l


# ---------------------------------------------------------------------
# Construção da UI
# ---------------------------------------------------------------------

func _construir_ui() -> void:
	_fundo = ColorRect.new()
	_fundo.color = COR_FUNDO_OVERLAY
	_fundo.anchor_right = 1.0
	_fundo.anchor_bottom = 1.0
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	_fundo.connect("gui_input", self, "_on_fundo_input")
	add_child(_fundo)

	_painel = PanelContainer.new()
	_painel.anchor_left = 0.5
	_painel.anchor_right = 0.5
	_painel.anchor_top = 0.5
	_painel.anchor_bottom = 0.5
	_painel.margin_left = -300
	_painel.margin_right = 300
	_painel.margin_top = -280
	_painel.margin_bottom = 280
	_painel.add_stylebox_override("panel", _sb(COR_PAINEL, COR_BORDA, 2, 16, true))
	add_child(_painel)

	var margem := MarginContainer.new()
	margem.add_constant_override("margin_left", 26)
	margem.add_constant_override("margin_right", 26)
	margem.add_constant_override("margin_top", 22)
	margem.add_constant_override("margin_bottom", 22)
	_painel.add_child(margem)

	var vbox_root := VBoxContainer.new()
	vbox_root.rect_min_size = Vector2(548, 496)
	vbox_root.add_constant_override("separation", 10)
	margem.add_child(vbox_root)

	# ---- Cabeçalho ----
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_root.add_child(header)

	_label_titulo = _label("🏆  Ranking — Limbo of Memories", COR_ROXO_CLARO)
	_label_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fonte_titulo := _fonte_com_novo_tamanho(_label_titulo.get_font("font"), 6)
	if fonte_titulo:
		_label_titulo.add_font_override("font", fonte_titulo)
	header.add_child(_label_titulo)

	var btn_fechar := Button.new()
	btn_fechar.text = "X"
	btn_fechar.rect_min_size = Vector2(32, 32)
	btn_fechar.add_stylebox_override("normal", _sb(Color(0, 0, 0, 0), COR_BORDA, 1, 8))
	btn_fechar.add_stylebox_override("hover", _sb(Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.2), COR_ROXO, 1, 8))
	btn_fechar.add_stylebox_override("pressed", _sb(Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.32), COR_ROXO, 1, 8))
	btn_fechar.add_stylebox_override("focus", _sb(Color(0, 0, 0, 0), COR_ROXO, 1, 8))
	btn_fechar.add_color_override("font_color", COR_TEXTO_FRACO)
	btn_fechar.add_color_override("font_color_hover", COR_TEXTO)
	btn_fechar.hint_tooltip = "Fechar (ESC)"
	btn_fechar.connect("pressed", self, "fechar")
	header.add_child(btn_fechar)

	_label_status = _label("Carregando...", COR_TEXTO_FRACO)
	vbox_root.add_child(_label_status)

	var separador := HSeparator.new()
	var sb_sep := StyleBoxFlat.new()
	sb_sep.bg_color = COR_BORDA
	sb_sep.content_margin_top = 1
	sb_sep.content_margin_bottom = 1
	separador.add_stylebox_override("separator", sb_sep)
	vbox_root.add_child(separador)

	# ---- Cabeçalho das colunas ----
	var col_header := HBoxContainer.new()
	col_header.add_constant_override("separation", 6)
	col_header.add_child(_label("  #", COR_TEXTO_FRACO, Label.ALIGN_LEFT, 60))
	col_header.add_child(_label("Jogador", COR_TEXTO_FRACO, Label.ALIGN_LEFT))
	var espaco := Control.new()
	espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_header.add_child(espaco)
	col_header.add_child(_label("Itens", COR_TEXTO_FRACO, Label.ALIGN_RIGHT, 80))
	col_header.add_child(_label("Tempo", COR_TEXTO_FRACO, Label.ALIGN_RIGHT, 90))
	vbox_root.add_child(col_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.rect_min_size = Vector2(0, 360)
	vbox_root.add_child(scroll)

	_lista_vbox = VBoxContainer.new()
	_lista_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_vbox.add_constant_override("separation", 6)
	scroll.add_child(_lista_vbox)

	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 10.0
	add_child(_http)
	_http.connect("request_completed", self, "_on_ranking_recebido")

	_timer_refresh = Timer.new()
	_timer_refresh.wait_time = REFRESH_INTERVAL
	_timer_refresh.one_shot = false
	_timer_refresh.connect("timeout", self, "_buscar_ranking")
	add_child(_timer_refresh)


func abrir() -> void:
	esta_aberta = true
	visible = true
	_buscar_ranking()
	_timer_refresh.start()


func fechar() -> void:
	esta_aberta = false
	visible = false
	_timer_refresh.stop()


func _on_fundo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		fechar()


func _input(event: InputEvent) -> void:
	if not esta_aberta:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.scancode == KEY_ESCAPE:
		fechar()
		get_tree().set_input_as_handled()


func _buscar_ranking() -> void:
	if typeof(SaveManager) == TYPE_NIL or not SaveManager.has_method("get_web_token"):
		_label_status.text = "Erro: SaveManager não encontrado."
		return
	_label_status.text = "Atualizando..."
	var url : String = SaveManager.WEB_API_URL + "/ranking"
	var err := _http.request(url)
	if err != OK:
		_label_status.text = "Falha ao conectar com o servidor."


func _on_ranking_recebido(result: int, response_code: int, _headers: PoolStringArray, body: PoolByteArray) -> void:
	if not esta_aberta:
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_label_status.text = "Sem conexão com o servidor."
		return
	if response_code < 200 or response_code >= 300:
		_label_status.text = "Erro do servidor (HTTP %d)." % response_code
		return

	var data = parse_json(body.get_string_from_utf8())
	if typeof(data) != TYPE_ARRAY:
		_label_status.text = "Resposta inválida do servidor."
		return

	var filtradas := []
	for r in data:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var total = int(r.get("fitas_normais", 0)) + int(r.get("fitas_douradas", 0)) + int(r.get("cartas", 0))
		if total <= 0:
			continue
		var item = r.duplicate()
		item["total"] = total
		filtradas.append(item)
	filtradas.sort_custom(self, "_cmp_ranking")
	_preencher_lista(filtradas)
	_label_status.text = "Atualizado às %s — atualiza sozinho a cada %ds" % [_hora_atual(), int(REFRESH_INTERVAL)]


func _preencher_lista(linhas: Array) -> void:
	for filho in _lista_vbox.get_children():
		filho.queue_free()

	if linhas.empty():
		var vazio := _label("Ninguém no ranking ainda. Seja o primeiro!", COR_TEXTO_FRACO, Label.ALIGN_CENTER)
		vazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lista_vbox.add_child(vazio)
		return

	var medalhas := ["🥇", "🥈", "🥉"]
	var cores_pos := [COR_OURO, COR_PRATA, COR_BRONZE]

	for i in range(linhas.size()):
		var r = linhas[i]
		if typeof(r) != TYPE_DICTIONARY:
			continue

		var eh_top3 := i < 3

		var row_panel := PanelContainer.new()
		var cor_fundo_linha := COR_LINHA_PAR if i % 2 == 0 else COR_LINHA_IMPAR
		var cor_borda_linha = cores_pos[i] if eh_top3 else Color(0, 0, 0, 0)
		var sb_row := _sb(cor_fundo_linha, cor_borda_linha, (2 if eh_top3 else 0), 8)
		row_panel.add_stylebox_override("panel", sb_row)
		_lista_vbox.add_child(row_panel)

		var margem_linha := MarginContainer.new()
		margem_linha.add_constant_override("margin_left", 12)
		margem_linha.add_constant_override("margin_right", 12)
		margem_linha.add_constant_override("margin_top", 6)
		margem_linha.add_constant_override("margin_bottom", 6)
		row_panel.add_child(margem_linha)

		var linha := HBoxContainer.new()
		linha.add_constant_override("separation", 6)
		margem_linha.add_child(linha)

		var posicao := _label((medalhas[i] if eh_top3 else "%dº" % (i + 1)), (cores_pos[i] if eh_top3 else COR_TEXTO_FRACO), Label.ALIGN_LEFT, 48)
		linha.add_child(posicao)

		var esta_online := bool(r.get("is_online", r.get("online", false)))
		var online_dot := _label("●" if esta_online else "○", COR_ONLINE if esta_online else COR_OFFLINE)
		online_dot.hint_tooltip = "Online agora" if esta_online else "Offline"
		linha.add_child(online_dot)

		var nome := _label(" " + String(r.get("nickname", r.get("username", "???"))), (COR_TEXTO if eh_top3 else COR_TEXTO))
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(nome)

		var fn := int(r.get("fitas_normais", 0))
		var fd := int(r.get("fitas_douradas", 0))
		var ct := int(r.get("cartas", 0))
		var total := int(r.get("total", fn + fd + ct))

		var itens := _label("%d / 29" % total, COR_ROXO_CLARO, Label.ALIGN_RIGHT, 80)
		linha.add_child(itens)

		var tempo := _label(_formatar_tempo(int(r.get("playtime_seconds", 0))), COR_TEXTO_FRACO, Label.ALIGN_RIGHT, 90)
		linha.add_child(tempo)


func _cmp_ranking(a, b) -> bool:
	var ta = int(a.get("total", 0))
	var tb = int(b.get("total", 0))
	if ta != tb:
		return ta > tb
	return int(a.get("playtime_seconds", 999999999)) < int(b.get("playtime_seconds", 999999999))


func _formatar_tempo(segundos: int) -> String:
	var h := segundos / 3600
	var m := (segundos % 3600) / 60
	if h > 0:
		return "%dh %dm" % [h, m]
	return "%dm" % m


func _hora_atual() -> String:
	var t := OS.get_time()
	return "%02d:%02d:%02d" % [t.hour, t.minute, t.second]


## Duplica a fonte atual (se for DynamicFont) com um tamanho maior.
func _fonte_com_novo_tamanho(base: Font, extra: int) -> Font:
	if base and base is DynamicFont:
		var nova := DynamicFont.new()
		nova.font_data = base.font_data
		nova.size = max(base.size + extra, 16)
		nova.outline_size = max(base.outline_size, 1)
		nova.outline_color = base.outline_color if base.outline_color.a > 0.0 else Color(0, 0, 0, 0.55)
		return nova
	return null
