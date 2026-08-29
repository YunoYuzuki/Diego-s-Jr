extends CanvasLayer
# =====================================================================
# CARTAS INVENTORY UI — tela de colecionáveis (estilo TLOU / bolsas)
# =====================================================================
# Anexe este script na raiz da cena CartasInventory.tscn
# (CanvasLayer; pode ser só uma tela preta — TODO o resto é criado por código).
#
# Autoload sugerido: CartasInventoryUI (a CENA, não o .gd solto)
#   OU adicione a cena na árvore e chame abrir() / fechar().
#
# Controles:
#   C .............. abre (se tiver cartas) / fecha
#   ESC / Q ........ fecha o inventário
#   E .............. seleciona carta (modo mover)
#   Enter .......... lê a carta selecionada
#   Setas / WASD ... navega; com carta selecionada, reordena
#   Mouse .......... clique = selecionar; arrastar = reordenar; duplo = ler
#
# Pausa o jogo enquanto estiver aberta (pause_mode PROCESS neste nó).
# =====================================================================

signal abriu()
signal fechou()

export var layer_ui: int = 115

const COR_FUNDO := Color(0.03, 0.02, 0.06, 0.92)
const COR_PAINEL := Color(0.08, 0.06, 0.12, 0.95)
const COR_BORDA := Color(0.45, 0.32, 0.62, 0.55)
const COR_BORDA_SEL := Color(0.72, 0.48, 0.95, 0.95)
const COR_TEXTO := Color(0.90, 0.86, 0.96, 1.0)
const COR_TEXTO_DIM := Color(0.55, 0.48, 0.65, 1.0)
const COR_ACCENT := Color(0.62, 0.38, 0.92, 1.0)
const COR_SLOT := Color(0.11, 0.09, 0.16, 0.9)
const COR_SLOT_HOVER := Color(0.16, 0.12, 0.24, 0.95)
const COR_SLOT_SEL := Color(0.22, 0.14, 0.32, 0.98)
const COR_DROP := Color(0.35, 0.22, 0.50, 0.6)

var esta_aberta: bool = false
var _indice_foco: int = 0
var _indice_selecionado: int = -1  # carta "na mão" pra reordenar com teclado
var _arrastando: bool = false
var _drag_index: int = -1
var _drag_preview: Control = null
var _drop_target: int = -1
var _pending_drag: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD := 10.0
var _mouse_antes: int = Input.MOUSE_MODE_CAPTURED
var _pausou_nos: bool = false

# Nós criados em runtime
var _root: Control = null
var _overlay: ColorRect = null
var _painel: Panel = null
var _titulo: Label = null
var _subtitulo: Label = null
var _scroll: ScrollContainer = null
var _lista: VBoxContainer = null
var _hints: Label = null
var _vazio_label: Label = null
var _reader: Control = null
var _reader_titulo: Label = null
var _reader_texto: RichTextLabel = null
var _reader_hint: Label = null
var _slots: Array = []  # Panel de cada carta

var _fonte_titulo: DynamicFont = null
var _fonte_item: DynamicFont = null
var _fonte_hint: DynamicFont = null
var _fonte_body: DynamicFont = null


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	layer = layer_ui
	add_to_group("cartas_inventory_ui")
	add_to_group("ui_bloqueia_pause")
	# NÃO adicionar "ui_persistente": SaveManager.queue_free nesse grupo
	# e Autoload não pode ser destruído.
	_carregar_fontes()
	_construir_ui()
	_esconder()
	set_process_input(true)
	set_process(false)
	if typeof(CartasInventory) != TYPE_NIL and CartasInventory.has_signal("cartas_mudaram"):
		if not CartasInventory.is_connected("cartas_mudaram", self, "_on_cartas_mudaram"):
			CartasInventory.connect("cartas_mudaram", self, "_on_cartas_mudaram")
	# Godot 3: CanvasLayer não tem NOTIFICATION_RESIZED — usa size_changed do viewport
	if not get_viewport().is_connected("size_changed", self, "_reposicionar_painel"):
		get_viewport().connect("size_changed", self, "_reposicionar_painel")


func _carregar_fontes() -> void:
	_fonte_titulo = _mk_font(36, true)
	_fonte_item = _mk_font(22, false)
	_fonte_hint = _mk_font(18, false)
	_fonte_body = _mk_font(20, false)


func _mk_font(tamanho: int, _bold: bool = false) -> DynamicFont:
	var f = DynamicFont.new()
	var path = "res://assets/fonts/MiniPixel/Minipixel-Regular.ttf"
	if ResourceLoader.exists(path):
		f.font_data = load(path)
	elif ResourceLoader.exists("res://assets/fonts/KiwiSoda.tres"):
		var t = load("res://assets/fonts/KiwiSoda.tres")
		if t is DynamicFont:
			f = t.duplicate()
	f.size = tamanho
	return f


func _construir_ui() -> void:
	# Remove filhos antigos (cena pode ter ColorRect preto)
	for c in get_children():
		c.queue_free()

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.focus_mode = Control.FOCUS_NONE
	add_child(_root)

	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = COR_FUNDO
	_overlay.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_overlay)

	# Painel central
	_painel = Panel.new()
	_painel.name = "Painel"
	_painel.rect_min_size = Vector2(520, 480)
	_estilo_painel(_painel, COR_PAINEL, COR_BORDA)
	_root.add_child(_painel)

	var margin = MarginContainer.new()
	margin.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	margin.add_constant_override("margin_left", 28)
	margin.add_constant_override("margin_right", 28)
	margin.add_constant_override("margin_top", 22)
	margin.add_constant_override("margin_bottom", 28)
	_painel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 12)
	margin.add_child(vbox)

	_titulo = Label.new()
	_titulo.text = "CARTAS"
	_titulo.align = Label.ALIGN_CENTER
	if _fonte_titulo:
		_titulo.add_font_override("font", _fonte_titulo)
	_titulo.add_color_override("font_color", COR_ACCENT)
	vbox.add_child(_titulo)

	_subtitulo = Label.new()
	_subtitulo.text = "documentos e notas encontradas"
	_subtitulo.align = Label.ALIGN_CENTER
	if _fonte_hint:
		_subtitulo.add_font_override("font", _fonte_hint)
	_subtitulo.add_color_override("font_color", COR_TEXTO_DIM)
	vbox.add_child(_subtitulo)

	var sep = ColorRect.new()
	sep.color = COR_BORDA
	sep.rect_min_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(sep)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.rect_min_size = Vector2(0, 240)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.scroll_horizontal_enabled = false
	vbox.add_child(_scroll)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_constant_override("separation", 8)
	_scroll.add_child(_lista)

	_vazio_label = Label.new()
	_vazio_label.text = "Você não possui nenhuma carta"
	_vazio_label.align = Label.ALIGN_CENTER
	_vazio_label.valign = Label.VALIGN_CENTER
	_vazio_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _fonte_item:
		_vazio_label.add_font_override("font", _fonte_item)
	_vazio_label.add_color_override("font_color", COR_TEXTO_DIM)
	_vazio_label.visible = false
	vbox.add_child(_vazio_label)

	_hints = Label.new()
	_hints.align = Label.ALIGN_CENTER
	_hints.valign = Label.VALIGN_CENTER
	_hints.autowrap = true
	_hints.rect_min_size = Vector2(0, 48)
	_hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hints.size_flags_vertical = 0  # não expande — fica no rodapé do painel
	if _fonte_hint:
		_hints.add_font_override("font", _fonte_hint)
	_hints.add_color_override("font_color", COR_TEXTO_DIM)
	_hints.text = "[E] Selecionar   [Enter] Ler   [↑↓] Navegar   [Esc] Fechar"
	vbox.add_child(_hints)

	# Reader overlay (leitura dentro do inventário)
	_reader = Control.new()
	_reader.name = "Reader"
	_reader.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_reader.visible = false
	_reader.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_reader)

	var reader_bg = ColorRect.new()
	reader_bg.color = Color(0.01, 0.01, 0.02, 0.96)
	reader_bg.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_reader.add_child(reader_bg)

	var reader_panel = Panel.new()
	reader_panel.name = "ReaderPanel"
	reader_panel.rect_min_size = Vector2(560, 420)
	reader_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilo_painel(reader_panel, COR_PAINEL, COR_BORDA)
	_reader.add_child(reader_panel)
	reader_panel.set_anchors_and_margins_preset(Control.PRESET_CENTER)
	reader_panel.rect_position = Vector2(-280, -210)
	reader_panel.rect_size = Vector2(560, 420)

	var rm = MarginContainer.new()
	rm.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	rm.add_constant_override("margin_left", 32)
	rm.add_constant_override("margin_right", 32)
	rm.add_constant_override("margin_top", 28)
	rm.add_constant_override("margin_bottom", 24)
	reader_panel.add_child(rm)

	var rv = VBoxContainer.new()
	rv.add_constant_override("separation", 14)
	rm.add_child(rv)

	_reader_titulo = Label.new()
	_reader_titulo.align = Label.ALIGN_CENTER
	_reader_titulo.autowrap = true
	if _fonte_titulo:
		_reader_titulo.add_font_override("font", _fonte_titulo)
	_reader_titulo.add_color_override("font_color", COR_ACCENT)
	rv.add_child(_reader_titulo)

	var sep2 = ColorRect.new()
	sep2.color = COR_BORDA
	sep2.rect_min_size = Vector2(0, 1)
	rv.add_child(sep2)

	_reader_texto = RichTextLabel.new()
	_reader_texto.bbcode_enabled = false
	_reader_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_texto.scroll_active = true
	_reader_texto.selection_enabled = false
	_reader_texto.mouse_filter = Control.MOUSE_FILTER_STOP
	_reader_texto.focus_mode = Control.FOCUS_NONE
	if _fonte_body:
		_reader_texto.add_font_override("normal_font", _fonte_body)
	_reader_texto.add_color_override("default_color", COR_TEXTO)
	rv.add_child(_reader_texto)

	_reader_hint = Label.new()
	_reader_hint.text = "[Esc] ou [E] para voltar"
	_reader_hint.align = Label.ALIGN_CENTER
	if _fonte_hint:
		_reader_hint.add_font_override("font", _fonte_hint)
	_reader_hint.add_color_override("font_color", COR_TEXTO_DIM)
	rv.add_child(_reader_hint)

	_reposicionar_painel()


func _estilo_painel(p: Panel, bg: Color, borda: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = borda
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_stylebox_override("panel", sb)


func _reposicionar_painel() -> void:
	if _painel == null:
		return
	var vp = get_viewport().size
	var w = min(560.0, vp.x * 0.72)
	var h = min(560.0, vp.y * 0.78)
	_painel.rect_size = Vector2(w, h)
	_painel.rect_position = Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5)
	if _reader:
		for c in _reader.get_children():
			if c is Panel:
				var rw = min(600.0, vp.x * 0.78)
				var rh = min(480.0, vp.y * 0.72)
				c.rect_size = Vector2(rw, rh)
				c.rect_position = Vector2((vp.x - rw) * 0.5, (vp.y - rh) * 0.5)


# ---------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------

func abrir() -> void:
	if esta_aberta:
		return
	if typeof(Global) != TYPE_NIL and Global.get("rodando_como_menu_bg"):
		return

	esta_aberta = true
	visible = true
	_root.visible = true
	_reader.visible = false
	_indice_selecionado = -1
	_arrastando = false
	_pending_drag = false
	_keys_held.clear()

	_mouse_antes = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Pausa o jogo (igual pause_game, mas sem abrir o menu de pause)
	if not get_tree().paused:
		get_tree().paused = true
		_pausou_nos = true
	else:
		_pausou_nos = false

	_rebuild_lista()
	_reposicionar_painel()
	_atualizar_hints()
	_notificar_tutoriais(true)
	emit_signal("abriu")
	set_process(true)


func fechar() -> void:
	if not esta_aberta:
		_esconder()
		return
	esta_aberta = false
	_reader.visible = false
	_indice_selecionado = -1
	_arrastando = false
	_limpar_drag_preview()

	if _pausou_nos:
		get_tree().paused = false
		_pausou_nos = false

	Input.set_mouse_mode(_mouse_antes)
	_esconder()
	_notificar_tutoriais(false)
	emit_signal("fechou")
	set_process(false)

	if is_inside_tree():
		for manager in get_tree().get_nodes_in_group("tutorial_manager"):
			if manager.has_method("_processar_fila"):
				manager._processar_fila()


func toggle() -> void:
	if esta_aberta:
		fechar()
	else:
		abrir()


func get_painel_visivel() -> bool:
	return esta_aberta


func _esconder() -> void:
	esta_aberta = false
	visible = false
	if _root and is_instance_valid(_root):
		_root.visible = false


func _notificar_tutoriais(bloqueando: bool) -> void:
	if not is_inside_tree():
		return
	for tm in get_tree().get_nodes_in_group("tutorial_manager"):
		if not is_instance_valid(tm):
			continue
		if bloqueando and tm.has_method("esconder_para_pause"):
			tm.esconder_para_pause()
		elif not bloqueando and tm.has_method("mostrar_apos_pause"):
			tm.mostrar_apos_pause()


# ---------------------------------------------------------------------
# Lista / slots
# ---------------------------------------------------------------------

func _on_cartas_mudaram() -> void:
	if esta_aberta:
		_rebuild_lista()


func _cartas() -> Array:
	if typeof(CartasInventory) == TYPE_NIL:
		return []
	return CartasInventory.get_cartas()


func _rebuild_lista() -> void:
	for c in _lista.get_children():
		c.queue_free()
	_slots.clear()

	var cartas = _cartas()
	var vazio = cartas.empty()
	_vazio_label.visible = vazio
	_scroll.visible = not vazio

	if vazio:
		_indice_foco = 0
		_indice_selecionado = -1
		_atualizar_hints()
		return

	for i in range(cartas.size()):
		var slot = _criar_slot(i, cartas[i])
		_lista.add_child(slot)
		_slots.append(slot)

	_indice_foco = clamp(_indice_foco, 0, cartas.size() - 1)
	_aplicar_destaques()
	_atualizar_hints()


func _criar_slot(idx: int, carta: Dictionary) -> Panel:
	var slot = Panel.new()
	slot.rect_min_size = Vector2(0, 52)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.focus_mode = Control.FOCUS_NONE
	slot.set_meta("idx", idx)
	slot.set_meta("carta_id", str(carta.get("id", "")))
	_estilo_slot(slot, false, false)

	var h = HBoxContainer.new()
	h.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	h.add_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# margem interna via Margin
	var m = MarginContainer.new()
	m.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	m.add_constant_override("margin_left", 14)
	m.add_constant_override("margin_right", 14)
	m.add_constant_override("margin_top", 8)
	m.add_constant_override("margin_bottom", 8)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(m)
	m.add_child(h)

	var num = Label.new()
	num.text = "%02d" % (idx + 1)
	num.rect_min_size = Vector2(36, 0)
	if _fonte_hint:
		num.add_font_override("font", _fonte_hint)
	num.add_color_override("font_color", COR_TEXTO_DIM)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(num)

	var nome = Label.new()
	nome.text = str(carta.get("nome", "Carta"))
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.clip_text = true
	if _fonte_item:
		nome.add_font_override("font", _fonte_item)
	nome.add_color_override("font_color", COR_TEXTO)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nome)

	var ico = Label.new()
	ico.text = "✉"
	if _fonte_item:
		ico.add_font_override("font", _fonte_item)
	ico.add_color_override("font_color", COR_ACCENT)
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ico)

	slot.connect("gui_input", self, "_on_slot_gui_input", [idx])
	slot.connect("mouse_entered", self, "_on_slot_hover", [idx, true])
	slot.connect("mouse_exited", self, "_on_slot_hover", [idx, false])
	return slot


func _estilo_slot(slot: Panel, focado: bool, selecionado: bool) -> void:
	var sb = StyleBoxFlat.new()
	if selecionado:
		sb.bg_color = COR_SLOT_SEL
		sb.border_color = COR_BORDA_SEL
		sb.set_border_width_all(2)
	elif focado:
		sb.bg_color = COR_SLOT_HOVER
		sb.border_color = COR_ACCENT
		sb.set_border_width_all(2)
	else:
		sb.bg_color = COR_SLOT
		sb.border_color = COR_BORDA
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	slot.add_stylebox_override("panel", sb)


func _aplicar_destaques() -> void:
	for i in range(_slots.size()):
		if not is_instance_valid(_slots[i]):
			continue
		var focado = (i == _indice_foco)
		var sel = (i == _indice_selecionado)
		_estilo_slot(_slots[i], focado, sel)
		# indicador de drop
		if _arrastando and i == _drop_target and i != _drag_index:
			var sb = _slots[i].get_stylebox("panel").duplicate()
			if sb is StyleBoxFlat:
				sb.bg_color = COR_DROP
				_slots[i].add_stylebox_override("panel", sb)


func _atualizar_hints() -> void:
	if _reader and _reader.visible:
		return
	if _cartas().empty():
		_hints.text = "[Esc] Fechar"
		return
	if _indice_selecionado >= 0:
		_hints.text = "[↑↓ / WASD] Mover carta   [E] Soltar   [Enter] Ler   [Esc] Cancelar"
	else:
		_hints.text = "[E] Selecionar   [Enter] Ler   [↑↓] Navegar   arraste p/ reordenar   [Esc] Fechar"


# ---------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------

func _input(event) -> void:
	# Tecla C / action "c" abre/fecha (mesmo fora), se não estiver em menu
	var apertou_c := false
	if event.is_action_pressed("c"):
		apertou_c = true
	elif event is InputEventKey and event.pressed and not event.echo and event.scancode == KEY_C:
		apertou_c = true
	if apertou_c:
		if _pode_abrir_pelo_mundo():
			if esta_aberta:
				# C não fecha a leitura — só ESC/E. C fecha o inventário se não estiver lendo.
				if not _reader.visible:
					fechar()
			else:
				_tentar_abrir_do_mundo()
			get_tree().set_input_as_handled()
			return

	if not esta_aberta:
		return

	# Reader aberto: só ESC / E fecham — scroll do mouse funciona no texto
	if _reader.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.scancode == KEY_ESCAPE or event.scancode == KEY_E or event.scancode == KEY_Q:
				_fechar_reader()
				get_tree().set_input_as_handled()
				return
		# Scroll manual no RichTextLabel (garantido mesmo com pause)
		if event is InputEventMouseButton and _reader_texto:
			if event.button_index == BUTTON_WHEEL_UP and event.pressed:
				_reader_texto.get_v_scroll().value -= 40
				get_tree().set_input_as_handled()
				return
			if event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
				_reader_texto.get_v_scroll().value += 40
				get_tree().set_input_as_handled()
				return
		return

	# Teclas de navegação: tratadas em _process (funciona com pause)

	# Soltar drag
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		if _arrastando:
			_finalizar_drag()
			get_tree().set_input_as_handled()

	if event is InputEventMouseMotion:
		if _pending_drag and not _arrastando:
			if event.global_position.distance_to(_drag_start_pos) >= DRAG_THRESHOLD:
				_arrastando = true
				_pending_drag = false
				_criar_drag_preview(_drag_index, event.global_position)
		if _arrastando:
			_atualizar_drag(event.position)
			get_tree().set_input_as_handled()


func _pode_abrir_pelo_mundo() -> bool:
	if typeof(Global) != TYPE_NIL and Global.get("rodando_como_menu_bg"):
		return false
	# Não abre em cima de outras UIs críticas
	if typeof(CartasUI) != TYPE_NIL and CartasUI.get("esta_aberta") == true:
		return false
	if typeof(TelaPickup) != TYPE_NIL and is_instance_valid(TelaPickup) and TelaPickup.get("painel") and TelaPickup.painel.visible:
		return false
	return true


func _tentar_abrir_do_mundo() -> void:
	if typeof(CartasInventory) != TYPE_NIL and CartasInventory.esta_vazio():
		_flash_sem_cartas()
		return
	abrir()


func _flash_sem_cartas() -> void:
	# Mensagem no canto (não pausa o jogo)
	var layer = CanvasLayer.new()
	layer.layer = 120
	layer.pause_mode = Node.PAUSE_MODE_PROCESS
	var lbl = Label.new()
	lbl.text = "Você não possui nenhuma carta"
	if _fonte_hint:
		lbl.add_font_override("font", _fonte_hint)
	else:
		var f = _mk_font(18)
		lbl.add_font_override("font", f)
	lbl.add_color_override("font_color", Color(1, 1, 1, 0.92))
	lbl.pause_mode = Node.PAUSE_MODE_PROCESS
	layer.add_child(lbl)
	get_tree().root.add_child(layer)
	var vp = get_viewport().size
	lbl.rect_position = Vector2(max(20, vp.x - 340), vp.y - 72)
	# Timer simples pra sumir
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.pause_mode = Node.PAUSE_MODE_PROCESS
	layer.add_child(timer)
	timer.connect("timeout", layer, "queue_free")
	timer.start()
	var tw = Tween.new()
	tw.pause_mode = Node.PAUSE_MODE_PROCESS
	layer.add_child(tw)
	tw.interpolate_property(lbl, "modulate:a", 1.0, 0.0, 0.6, Tween.TRANS_LINEAR, Tween.EASE_IN, 1.4)
	tw.start()


func _mover_foco(dir: int) -> void:
	var n = _cartas().size()
	if n == 0:
		return
	var novo = clamp(_indice_foco + dir, 0, n - 1)
	if novo == _indice_foco:
		return

	# Se tem carta selecionada, reordena
	if _indice_selecionado >= 0:
		_reordenar(_indice_selecionado, novo)
		_indice_selecionado = novo
		_indice_foco = novo
	else:
		_indice_foco = novo
	_aplicar_destaques()
	_garantir_visivel(_indice_foco)


func _toggle_selecao_teclado() -> void:
	if _cartas().empty():
		return
	if _indice_selecionado == _indice_foco:
		_indice_selecionado = -1
	else:
		_indice_selecionado = _indice_foco
	_aplicar_destaques()
	_atualizar_hints()


func _ler_foco() -> void:
	var cartas = _cartas()
	if cartas.empty() or _indice_foco < 0 or _indice_foco >= cartas.size():
		return
	var c = cartas[_indice_foco]
	_abrir_reader(str(c.get("nome", "")), str(c.get("conteudo", "")))


func _abrir_reader(nome: String, conteudo: String) -> void:
	_reader_titulo.text = nome
	_reader_texto.text = conteudo
	_reader.visible = true
	_reader_texto.scroll_to_line(0)


func _fechar_reader() -> void:
	_reader.visible = false
	_atualizar_hints()


# ---------------------------------------------------------------------
# Drag & drop
# ---------------------------------------------------------------------

func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not esta_aberta or _reader.visible:
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			_indice_foco = idx
			_aplicar_destaques()
			if event.doubleclick:
				_pending_drag = false
				_arrastando = false
				_limpar_drag_preview()
				_ler_foco()
				get_tree().set_input_as_handled()
				return
			# Não inicia drag na hora — espera movimento (libera duplo-clique)
			_pending_drag = true
			_drag_index = idx
			_drop_target = idx
			_drag_start_pos = event.global_position
			get_tree().set_input_as_handled()
		else:
			_pending_drag = false
			if _arrastando:
				_finalizar_drag()
				get_tree().set_input_as_handled()


func _on_slot_hover(idx: int, entrou: bool) -> void:
	if not esta_aberta or _arrastando:
		if _arrastando and entrou:
			_drop_target = idx
			_aplicar_destaques()
		return
	if entrou:
		_indice_foco = idx
		_aplicar_destaques()


func _criar_drag_preview(idx: int, pos: Vector2) -> void:
	_limpar_drag_preview()
	if idx < 0 or idx >= _slots.size():
		return
	var src = _slots[idx]
	_drag_preview = Panel.new()
	_drag_preview.rect_size = src.rect_size
	_drag_preview.modulate = Color(1, 1, 1, 0.75)
	_estilo_slot(_drag_preview, true, true)
	var lbl = Label.new()
	var cartas = _cartas()
	if idx < cartas.size():
		lbl.text = str(cartas[idx].get("nome", ""))
	if _fonte_item:
		lbl.add_font_override("font", _fonte_item)
	lbl.add_color_override("font_color", COR_TEXTO)
	lbl.rect_position = Vector2(14, 14)
	_drag_preview.add_child(lbl)
	_root.add_child(_drag_preview)
	_drag_preview.rect_global_position = pos - Vector2(40, 20)
	# some o slot original visualmente
	src.modulate.a = 0.35


func _atualizar_drag(pos: Vector2) -> void:
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.rect_global_position = pos - Vector2(40, 20)
	# Detecta slot sob o mouse
	var local = _lista.get_global_transform().affine_inverse() * pos
	var y = 0.0
	_drop_target = _drag_index
	for i in range(_slots.size()):
		var s = _slots[i]
		if not is_instance_valid(s):
			continue
		var h = s.rect_size.y + 8
		if local.y >= y and local.y < y + h:
			_drop_target = i
			break
		y += h
	_aplicar_destaques()


func _finalizar_drag() -> void:
	if not _arrastando:
		return
	var from = _drag_index
	var to = _drop_target
	_arrastando = false
	_limpar_drag_preview()
	# restaura alpha
	for s in _slots:
		if is_instance_valid(s):
			s.modulate.a = 1.0
	if from >= 0 and to >= 0 and from != to:
		_reordenar(from, to)
		_indice_foco = to
		_indice_selecionado = -1
	_drag_index = -1
	_drop_target = -1
	_aplicar_destaques()
	_atualizar_hints()


func _limpar_drag_preview() -> void:
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null


func _reordenar(from: int, to: int) -> void:
	if typeof(CartasInventory) == TYPE_NIL:
		return
	if CartasInventory.has_method("mover_carta"):
		CartasInventory.mover_carta(from, to)
	else:
		# fallback local se o autoload ainda não tiver o método
		var arr = CartasInventory.cartas
		if from < 0 or from >= arr.size() or to < 0 or to >= arr.size():
			return
		var item = arr[from]
		arr.remove(from)
		arr.insert(to, item)
		if CartasInventory.has_signal("cartas_mudaram"):
			CartasInventory.emit_signal("cartas_mudaram")
	_rebuild_lista()


func _garantir_visivel(idx: int) -> void:
	if idx < 0 or idx >= _slots.size():
		return
	var slot = _slots[idx]
	if not is_instance_valid(slot):
		return
	# Scroll aproximado
	var y = 0.0
	for i in range(idx):
		if is_instance_valid(_slots[i]):
			y += _slots[i].rect_size.y + 8
	_scroll.scroll_vertical = int(max(0, y - 40))


# --- detecção de tecla "acabou de apertar" (edge) ---
var _keys_held: Dictionary = {}

func _atualizar_edges() -> void:
	var watch = [
		KEY_ESCAPE, KEY_Q, KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE,
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D, KEY_C
	]
	for sc in watch:
		var now = Input.is_key_pressed(sc)
		var was = _keys_held.get(sc, false)
		# guarda "just pressed" em chave negativa
		_keys_held[-(sc + 1000)] = now and not was
		_keys_held[sc] = now
	# mouse
	var mnow = Input.is_mouse_button_pressed(BUTTON_LEFT)
	var mwas = _keys_held.get("mouse", false)
	_keys_held["mouse_just"] = mnow and not mwas
	_keys_held["mouse"] = mnow


func _key_just(scancode: int) -> bool:
	return _keys_held.get(-(scancode + 1000), false) == true


func _process(_delta: float) -> void:
	if not esta_aberta:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_atualizar_edges()

	# Reader aberto: só ESC / E / Q fecham (scroll do mouse livre)
	if _reader.visible:
		if (Input.is_action_just_pressed("ui_cancel")
				or _key_just(KEY_ESCAPE) or _key_just(KEY_E) or _key_just(KEY_Q)):
			_fechar_reader()
		return

	# ESC / Q — fechar ou cancelar seleção
	if Input.is_action_just_pressed("ui_cancel") or _key_just(KEY_ESCAPE) or _key_just(KEY_Q):
		if _indice_selecionado >= 0:
			_indice_selecionado = -1
			_aplicar_destaques()
			_atualizar_hints()
		else:
			fechar()
		return

	# E — selecionar / soltar
	if _key_just(KEY_E):
		_toggle_selecao_teclado()
		return

	# Enter — ler
	if Input.is_action_just_pressed("ui_accept") or _key_just(KEY_ENTER) or _key_just(KEY_KP_ENTER):
		_ler_foco()
		return

	# Navegação
	if _key_just(KEY_UP) or _key_just(KEY_W):
		_mover_foco(-1)
		return
	if _key_just(KEY_DOWN) or _key_just(KEY_S):
		_mover_foco(1)
		return
	if _indice_selecionado >= 0:
		if _key_just(KEY_LEFT) or _key_just(KEY_A):
			_mover_foco(-1)
			return
		if _key_just(KEY_RIGHT) or _key_just(KEY_D):
			_mover_foco(1)
			return
