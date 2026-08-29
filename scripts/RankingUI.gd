extends CanvasLayer
# =====================================================================
# RANKING UI — mostra o ranking do site dentro do jogo, com auto-refresh
# =====================================================================
# Diferente de CartasUI/InventoryUI, essa UI é montada TODA por código —
# não precisa de .tscn. Registre este .gd DIRETO como Autoload
# (nome sugerido: "RankingUI"), sem cena nenhuma associada.
#
# Uso: de qualquer lugar (ex: botão no MainMenu), chame:
#       RankingUI.abrir()
#
# "Tempo real": não temos WebSocket no backend, então isso é feito com
# polling — busca o ranking de novo a cada REFRESH_INTERVAL segundos
# enquanto a tela estiver aberta. Pra real-time de verdade (push do
# servidor) precisaria de suporte a WebSocket no backend.
# =====================================================================

const REFRESH_INTERVAL := 15.0

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


func _construir_ui() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.75)
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
	_painel.margin_left = -280
	_painel.margin_right = 280
	_painel.margin_top = -260
	_painel.margin_bottom = 260
	add_child(_painel)

	var vbox_root := VBoxContainer.new()
	vbox_root.rect_min_size = Vector2(560, 520)
	_painel.add_child(vbox_root)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_root.add_child(header)

	_label_titulo = Label.new()
	_label_titulo.text = "Ranking — Limbo of Memories"
	_label_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_label_titulo)

	var btn_fechar := Button.new()
	btn_fechar.text = "Fechar (ESC)"
	btn_fechar.connect("pressed", self, "fechar")
	header.add_child(btn_fechar)

	_label_status = Label.new()
	_label_status.text = "Carregando..."
	_label_status.modulate = Color(0.7, 0.7, 0.75)
	vbox_root.add_child(_label_status)

	var separador := HSeparator.new()
	vbox_root.add_child(separador)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.rect_min_size = Vector2(0, 400)
	vbox_root.add_child(scroll)

	_lista_vbox = VBoxContainer.new()
	_lista_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		return  # fechou antes da resposta chegar; ignora
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

	_preencher_lista(data)
	_label_status.text = "Atualizado às %s — atualiza sozinho a cada %ds" % [_hora_atual(), int(REFRESH_INTERVAL)]


func _preencher_lista(linhas: Array) -> void:
	for filho in _lista_vbox.get_children():
		filho.queue_free()

	if linhas.empty():
		var vazio := Label.new()
		vazio.text = "Ninguém no ranking ainda."
		_lista_vbox.add_child(vazio)
		return

	var medalhas := ["🥇", "🥈", "🥉"]
	for i in range(linhas.size()):
		var r = linhas[i]
		if typeof(r) != TYPE_DICTIONARY:
			continue

		var linha := HBoxContainer.new()
		_lista_vbox.add_child(linha)

		var posicao := Label.new()
		posicao.text = (medalhas[i] if i < 3 else "%dº" % (i + 1))
		posicao.rect_min_size = Vector2(44, 0)
		linha.add_child(posicao)

		var esta_online := bool(r.get("online", false))
		var online_dot := Label.new()
		online_dot.text = "●" if esta_online else "○"
		online_dot.modulate = Color(0.29, 0.87, 0.5) if esta_online else Color(0.55, 0.55, 0.6)
		online_dot.hint_tooltip = "Online agora" if esta_online else "Offline"
		linha.add_child(online_dot)

		var nome := Label.new()
		nome.text = " " + String(r.get("nickname", r.get("username", "???")))
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(nome)

		var fn := int(r.get("fitas_normais", 0))
		var fd := int(r.get("fitas_douradas", 0))
		var ct := int(r.get("cartas", 0))
		var total := fn + fd + ct

		var itens := Label.new()
		itens.text = "%d / 29" % total
		itens.rect_min_size = Vector2(80, 0)
		itens.align = Label.ALIGN_RIGHT
		linha.add_child(itens)

		var tempo := Label.new()
		tempo.text = _formatar_tempo(int(r.get("playtime_seconds", 0)))
		tempo.rect_min_size = Vector2(90, 0)
		tempo.align = Label.ALIGN_RIGHT
		linha.add_child(tempo)


func _formatar_tempo(segundos: int) -> String:
	var h := segundos / 3600
	var m := (segundos % 3600) / 60
	if h > 0:
		return "%dh %dm" % [h, m]
	return "%dm" % m


func _hora_atual() -> String:
	var t := OS.get_time()
	return "%02d:%02d:%02d" % [t.hour, t.minute, t.second]
