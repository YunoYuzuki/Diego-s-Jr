extends Control
# =====================================================================
# Configurações — páginas: Tela / Áudio / Jogabilidade
# Título: KiwiSoda | resto: Minipixel (tamanhos que você aprovou)
# =====================================================================

var veio_do_pause: bool = false

const COR_FUNDO       := Color(0, 0, 0, 1)
const COR_CAMPO       := Color8(48, 20, 90)
const COR_CAMPO_ESC   := Color8(28, 12, 52)
const COR_ROXO        := Color8(120, 50, 180)
const COR_ROXO_CLARO  := Color8(180, 140, 255)
const COR_TEXTO       := Color8(255, 255, 255)
const COR_TEXTO_FRACO := Color8(190, 190, 190)
const COR_ABA_OFF     := Color8(40, 40, 40)

const PATH_MINIPIXEL := "res://assets/fonts/MiniPixel/Minipixel-Regular.ttf"
const PATH_KIWISODA  := "res://assets/fonts/KiwiSoda.tres"

var slider_musica: HSlider
var slider_sfx: HSlider
var check_legendas: CheckBox
var option_resolucao: OptionButton
var check_tela_cheia: CheckBox
var slider_sensibilidade: HSlider
var label_sensibilidade: Label
var check_inverter_y: CheckBox

var _paginas := []
var _botoes_aba := []
var _pagina_atual := 0
var _btn_anterior: Button
var _btn_proxima: Button
var _label_pagina: Label

var _font_data_mini = null
var _font_data_kiwi = null


func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	add_to_group("config_screen")
	if has_node("Vbox"):
		get_node("Vbox").queue_free()
	anchor_right = 1.0
	anchor_bottom = 1.0
	_carregar_fontes()
	_construir_ui()
	_carregar_valores_salvos()


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_fechar()
		get_tree().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_ir_pagina(_pagina_atual - 1)
		get_tree().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_ir_pagina(_pagina_atual + 1)
		get_tree().set_input_as_handled()


# =====================================================================
# FONTES — KiwiSoda só no título; resto Minipixel
# =====================================================================

func _carregar_fontes() -> void:
	if ResourceLoader.exists(PATH_MINIPIXEL):
		_font_data_mini = load(PATH_MINIPIXEL)
	if ResourceLoader.exists(PATH_KIWISODA):
		var t = load(PATH_KIWISODA)
		if t is DynamicFont:
			_font_data_kiwi = t.font_data
		elif t is DynamicFontData:
			_font_data_kiwi = t


func _mk_font(tamanho: int, kiwi: bool = false) -> DynamicFont:
	var f := DynamicFont.new()
	f.size = tamanho
	if kiwi and _font_data_kiwi != null:
		f.font_data = _font_data_kiwi
	elif _font_data_mini != null:
		f.font_data = _font_data_mini
	elif _font_data_kiwi != null:
		f.font_data = _font_data_kiwi
	return f


func _aplicar_fonte(ctrl: Control, tamanho: int, kiwi: bool = false) -> void:
	var f = _mk_font(tamanho, kiwi)
	if f.font_data != null:
		ctrl.add_font_override("font", f)


# =====================================================================
# UI
# =====================================================================

func _construir_ui() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.anchor_right = 1.0
	fundo.anchor_bottom = 1.0
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var margem := MarginContainer.new()
	margem.anchor_right = 1.0
	margem.anchor_bottom = 1.0
	margem.add_constant_override("margin_left", 80)
	margem.add_constant_override("margin_right", 80)
	margem.add_constant_override("margin_top", 48)
	margem.add_constant_override("margin_bottom", 36)
	add_child(margem)

	var vbox := VBoxContainer.new()
	vbox.add_constant_override("separation", 18)
	margem.add_child(vbox)

	# Título — só aqui usa KiwiSoda
	var titulo := Label.new()
	titulo.text = "Configurações"
	titulo.add_color_override("font_color", COR_TEXTO)
	_aplicar_fonte(titulo, 42, true)
	vbox.add_child(titulo)

	var sep := HSeparator.new()
	var sb_sep := StyleBoxFlat.new()
	sb_sep.bg_color = Color8(55, 55, 55)
	sb_sep.content_margin_top = 1
	sb_sep.content_margin_bottom = 1
	sep.add_stylebox_override("separator", sb_sep)
	vbox.add_child(sep)

	# Abas
	var tabs := HBoxContainer.new()
	tabs.add_constant_override("separation", 12)
	vbox.add_child(tabs)

	var nomes := ["Tela", "Audio", "Jogabilidade"]
	for i in range(nomes.size()):
		var btn := Button.new()
		btn.text = nomes[i]
		btn.rect_min_size = Vector2(160, 44)
		btn.toggle_mode = true
		btn.connect("pressed", self, "_on_aba_pressed", [i])
		_estilizar_aba(btn, false)
		tabs.add_child(btn)
		_botoes_aba.append(btn)

	var sep2 := HSeparator.new()
	sep2.add_stylebox_override("separator", sb_sep.duplicate())
	vbox.add_child(sep2)

	# Área das páginas
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(area)

	var p_tela := _criar_pagina_tela()
	var p_audio := _criar_pagina_audio()
	var p_jogo := _criar_pagina_jogabilidade()
	for p in [p_tela, p_audio, p_jogo]:
		p.anchor_right = 1.0
		p.anchor_bottom = 1.0
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		area.add_child(p)
		_paginas.append(p)

	# Rodapé navegação
	var rodape := HBoxContainer.new()
	rodape.add_constant_override("separation", 16)
	vbox.add_child(rodape)

	_btn_anterior = Button.new()
	_btn_anterior.text = "< Anterior"
	_btn_anterior.rect_min_size = Vector2(150, 44)
	_estilizar_botao_nav(_btn_anterior)
	_btn_anterior.connect("pressed", self, "_ir_pagina_rel", [-1])
	rodape.add_child(_btn_anterior)

	_label_pagina = Label.new()
	_label_pagina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_pagina.align = Label.ALIGN_CENTER
	_label_pagina.add_color_override("font_color", COR_TEXTO_FRACO)
	_aplicar_fonte(_label_pagina, 18)
	rodape.add_child(_label_pagina)

	_btn_proxima = Button.new()
	_btn_proxima.text = "Proxima >"
	_btn_proxima.rect_min_size = Vector2(150, 44)
	_estilizar_botao_nav(_btn_proxima)
	_btn_proxima.connect("pressed", self, "_ir_pagina_rel", [1])
	rodape.add_child(_btn_proxima)

	var dica := Label.new()
	dica.text = 'Pressione "Esc" para sair'
	dica.align = Label.ALIGN_RIGHT
	dica.add_color_override("font_color", COR_TEXTO)
	_aplicar_fonte(dica, 18)
	vbox.add_child(dica)

	_ir_pagina(0)


func _criar_pagina_tela() -> VBoxContainer:
	var p := VBoxContainer.new()
	p.add_constant_override("separation", 16)

	p.add_child(_label_campo("Resolucao"))
	option_resolucao = OptionButton.new()
	option_resolucao.rect_min_size = Vector2(0, 40)
	option_resolucao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estilizar_option(option_resolucao)
	option_resolucao.connect("item_selected", self, "_on_Resolucao_selected")
	p.add_child(option_resolucao)

	var esp := Control.new()
	esp.rect_min_size = Vector2(0, 8)
	p.add_child(esp)

	check_tela_cheia = CheckBox.new()
	check_tela_cheia.text = "Tela cheia"
	_estilizar_checkbox(check_tela_cheia)
	check_tela_cheia.connect("toggled", self, "_on_TelaCheia_toggled")
	p.add_child(check_tela_cheia)

	return p


func _criar_pagina_audio() -> VBoxContainer:
	var p := VBoxContainer.new()
	p.add_constant_override("separation", 16)

	p.add_child(_label_campo("Musica"))
	slider_musica = _criar_slider()
	slider_musica.connect("value_changed", self, "_on_Musica_value_changed")
	p.add_child(slider_musica)

	p.add_child(_label_campo("Efeitos Sonoros"))
	slider_sfx = _criar_slider()
	slider_sfx.connect("value_changed", self, "_on_SFX_value_changed")
	p.add_child(slider_sfx)

	return p


func _criar_pagina_jogabilidade() -> VBoxContainer:
	var p := VBoxContainer.new()
	p.add_constant_override("separation", 16)

	p.add_child(_label_campo("Sensibilidade do Mouse"))
	var linha := HBoxContainer.new()
	linha.add_constant_override("separation", 14)
	p.add_child(linha)

	slider_sensibilidade = _criar_slider()
	slider_sensibilidade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_sensibilidade.connect("value_changed", self, "_on_Sensibilidade_value_changed")
	linha.add_child(slider_sensibilidade)

	label_sensibilidade = Label.new()
	label_sensibilidade.text = "50%"
	label_sensibilidade.rect_min_size = Vector2(64, 0)
	label_sensibilidade.add_color_override("font_color", COR_TEXTO)
	_aplicar_fonte(label_sensibilidade, 22)
	linha.add_child(label_sensibilidade)

	var esp := Control.new()
	esp.rect_min_size = Vector2(0, 8)
	p.add_child(esp)

	# Config extra útil: inverter eixo Y (já existia no SaveManager)
	check_inverter_y = CheckBox.new()
	check_inverter_y.text = "Inverter eixo Y do mouse"
	_estilizar_checkbox(check_inverter_y)
	check_inverter_y.connect("toggled", self, "_on_InverterY_toggled")
	p.add_child(check_inverter_y)

	check_legendas = CheckBox.new()
	check_legendas.text = "Legendas"
	_estilizar_checkbox(check_legendas)
	check_legendas.connect("toggled", self, "_on_Legendas_toggled")
	p.add_child(check_legendas)

	return p


func _label_campo(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_color_override("font_color", COR_TEXTO)
	_aplicar_fonte(l, 26)
	return l


func _criar_slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 1
	s.rect_min_size = Vector2(0, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb_slider := StyleBoxFlat.new()
	sb_slider.bg_color = COR_CAMPO_ESC
	sb_slider.corner_radius_top_left = 4
	sb_slider.corner_radius_top_right = 4
	sb_slider.corner_radius_bottom_left = 4
	sb_slider.corner_radius_bottom_right = 4
	sb_slider.content_margin_top = 6
	sb_slider.content_margin_bottom = 6

	var sb_area := StyleBoxFlat.new()
	sb_area.bg_color = COR_ROXO
	sb_area.corner_radius_top_left = 4
	sb_area.corner_radius_top_right = 4
	sb_area.corner_radius_bottom_left = 4
	sb_area.corner_radius_bottom_right = 4

	s.add_stylebox_override("slider", sb_slider)
	s.add_stylebox_override("grabber_area", sb_area)
	s.add_stylebox_override("grabber_area_highlight", sb_area)
	return s


func _sb(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _estilizar_aba(btn: Button, ativa: bool) -> void:
	_aplicar_fonte(btn, 20)
	if ativa:
		btn.add_stylebox_override("normal", _sb(COR_ROXO, COR_ROXO, 0, 6))
		btn.add_stylebox_override("hover", _sb(COR_ROXO_CLARO, COR_ROXO_CLARO, 0, 6))
		btn.add_stylebox_override("pressed", _sb(COR_ROXO, COR_ROXO, 0, 6))
		btn.add_color_override("font_color", COR_TEXTO)
	else:
		btn.add_stylebox_override("normal", _sb(COR_ABA_OFF, Color8(70, 70, 70), 1, 6))
		btn.add_stylebox_override("hover", _sb(Color8(55, 55, 55), COR_ROXO, 1, 6))
		btn.add_stylebox_override("pressed", _sb(COR_CAMPO, COR_ROXO, 1, 6))
		btn.add_color_override("font_color", COR_TEXTO_FRACO)
	btn.add_stylebox_override("focus", _sb(COR_ABA_OFF, COR_ROXO, 2, 6))
	btn.pressed = ativa


func _estilizar_botao_nav(btn: Button) -> void:
	_aplicar_fonte(btn, 18)
	btn.add_stylebox_override("normal", _sb(Color(0, 0, 0, 0), COR_ROXO, 1, 6))
	btn.add_stylebox_override("hover", _sb(Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.2), COR_ROXO, 1, 6))
	btn.add_stylebox_override("pressed", _sb(Color(COR_ROXO.r, COR_ROXO.g, COR_ROXO.b, 0.35), COR_ROXO, 1, 6))
	btn.add_stylebox_override("focus", _sb(Color(0, 0, 0, 0), COR_ROXO_CLARO, 2, 6))
	btn.add_stylebox_override("disabled", _sb(Color(0, 0, 0, 0), Color8(50, 50, 50), 1, 6))
	btn.add_color_override("font_color", COR_ROXO_CLARO)
	btn.add_color_override("font_color_hover", COR_TEXTO)
	btn.add_color_override("font_color_disabled", Color8(80, 80, 80))


func _estilizar_option(btn: OptionButton) -> void:
	_aplicar_fonte(btn, 20)
	var sb := _sb(COR_ROXO, COR_ROXO, 0, 2)
	btn.add_stylebox_override("normal", sb)
	btn.add_stylebox_override("hover", sb)
	btn.add_stylebox_override("pressed", sb)
	btn.add_stylebox_override("focus", sb)
	btn.add_color_override("font_color", COR_TEXTO)

	# Dropdown (PopupMenu) — o cinza padrão do Godot
	var popup = btn.get_popup()
	if popup == null:
		return
	popup.pause_mode = Node.PAUSE_MODE_PROCESS

	var sb_panel := StyleBoxFlat.new()
	sb_panel.bg_color = Color8(18, 12, 28)  # quase preto, levemente roxo
	sb_panel.border_color = COR_ROXO
	sb_panel.border_width_left = 1
	sb_panel.border_width_right = 1
	sb_panel.border_width_top = 1
	sb_panel.border_width_bottom = 1
	sb_panel.corner_radius_top_left = 4
	sb_panel.corner_radius_top_right = 4
	sb_panel.corner_radius_bottom_left = 4
	sb_panel.corner_radius_bottom_right = 4
	sb_panel.content_margin_left = 8
	sb_panel.content_margin_right = 8
	sb_panel.content_margin_top = 6
	sb_panel.content_margin_bottom = 6
	popup.add_stylebox_override("panel", sb_panel)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = COR_ROXO
	sb_hover.corner_radius_top_left = 2
	sb_hover.corner_radius_top_right = 2
	sb_hover.corner_radius_bottom_left = 2
	sb_hover.corner_radius_bottom_right = 2
	popup.add_stylebox_override("hover", sb_hover)

	var sb_sep := StyleBoxFlat.new()
	sb_sep.bg_color = Color8(60, 40, 90)
	popup.add_stylebox_override("separator", sb_sep)

	popup.add_color_override("font_color", COR_TEXTO)
	popup.add_color_override("font_color_hover", COR_TEXTO)
	popup.add_color_override("font_color_disabled", COR_TEXTO_FRACO)
	popup.add_color_override("font_color_accel", COR_ROXO_CLARO)
	# radio / check branco sobre o roxo
	popup.add_color_override("font_color_hover", Color(1, 1, 1))

	_aplicar_fonte(popup, 18)


func _estilizar_checkbox(cb: CheckBox) -> void:
	_aplicar_fonte(cb, 22)
	cb.add_color_override("font_color", COR_TEXTO)
	cb.add_color_override("font_color_hover", COR_ROXO_CLARO)
	cb.add_color_override("font_color_pressed", COR_ROXO_CLARO)


# =====================================================================
# Navegação por páginas
# =====================================================================

func _on_aba_pressed(idx: int) -> void:
	_ir_pagina(idx)


func _ir_pagina_rel(delta: int) -> void:
	_ir_pagina(_pagina_atual + delta)


func _ir_pagina(idx: int) -> void:
	if _paginas.empty():
		return
	idx = int(clamp(idx, 0, _paginas.size() - 1))
	_pagina_atual = idx
	for i in range(_paginas.size()):
		_paginas[i].visible = (i == idx)
	for i in range(_botoes_aba.size()):
		_estilizar_aba(_botoes_aba[i], i == idx)
	if _label_pagina:
		_label_pagina.text = "%d / %d" % [idx + 1, _paginas.size()]
	if _btn_anterior:
		_btn_anterior.disabled = (idx <= 0)
	if _btn_proxima:
		_btn_proxima.disabled = (idx >= _paginas.size() - 1)


# =====================================================================
# Lógica / valores
# =====================================================================

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
		get_parent().queue_free()
	else:
		get_tree().change_scene("res://scenes/MainMenu.tscn")


func _carregar_valores_salvos() -> void:
	if slider_sensibilidade:
		slider_sensibilidade.value = SaveManager.sensibilidade_mouse * 100.0
		label_sensibilidade.text = str(int(slider_sensibilidade.value)) + "%"
	if slider_musica:
		slider_musica.value = SaveManager.volume_musica * 100.0
	if slider_sfx:
		slider_sfx.value = SaveManager.volume_sfx * 100.0
	if check_legendas:
		check_legendas.pressed = SaveManager.legendas_ativadas
	if check_inverter_y:
		check_inverter_y.pressed = SaveManager.inverter_mouse_y
	_preencher_opcoes_resolucao()
	if option_resolucao:
		option_resolucao.select(SaveManager.resolucao_index)
	if check_tela_cheia:
		check_tela_cheia.pressed = SaveManager.tela_cheia


func _preencher_opcoes_resolucao() -> void:
	option_resolucao.clear()
	for res in SaveManager.calcular_resolucoes_disponiveis():
		option_resolucao.add_item(res["label"])


func _on_Musica_value_changed(value):
	SaveManager.volume_musica = value / 100.0
	var idx = AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear2db(SaveManager.volume_musica))


func _on_SFX_value_changed(value):
	SaveManager.volume_sfx = value / 100.0
	var idx = AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear2db(SaveManager.volume_sfx))


func _on_Legendas_toggled(pressed):
	SaveManager.legendas_ativadas = pressed
	if typeof(Legendas) != TYPE_NIL and Legendas.has_method("atualizar_visibilidade"):
		Legendas.atualizar_visibilidade()


func _on_InverterY_toggled(pressed):
	SaveManager.inverter_mouse_y = pressed


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
