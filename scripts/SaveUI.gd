extends CanvasLayer
# =====================================================================
# Save / Load — UI montada 100% em código (layout estável e compacto)
# main_menu = true → só Carregar | false → Carregar + Salvar por cima
# =====================================================================

var main_menu : bool = false

var _blur: ColorRect
var _root: Control
var _panel: PanelContainer
var _title: Label
var _slots_box: VBoxContainer
var _slot_btns := []
var _btn_excluir: Button
var _hint: Label

var _popup_dim: ColorRect
var _popup: PanelContainer
var _popup_label: Label
var _btn_load: Button
var _btn_save: Button
var _btn_cancel: Button

var tween: Tween
var current_slot := -1
var modo_exclusao := false

const C_BLUR := Color(0, 0, 0, 0.65)
const C_PANEL := Color(0.06, 0.06, 0.08, 0.97)
const C_SLOT := Color(0.11, 0.11, 0.14, 1)
const C_SLOT_H := Color(0.20, 0.14, 0.30, 1)
const C_PURPLE := Color(0.48, 0.26, 0.78, 1)
const C_PURPLE_H := Color(0.58, 0.34, 0.90, 1)
const C_RED := Color(0.55, 0.14, 0.14, 1)
const C_TEXT := Color(0.95, 0.95, 0.97, 1)
const C_DIM := Color(0.55, 0.55, 0.60, 1)
const C_BORDER := Color(0.55, 0.35, 0.85, 0.45)

const PATH_MINI := "res://assets/fonts/MiniPixel/Minipixel-Regular.ttf"
const PATH_KIWI := "res://assets/fonts/KiwiSoda.tres"
var _fd_mini = null
var _fd_kiwi = null


func _ready():
	add_to_group("save_ui")
	layer = 120
	pause_mode = Node.PAUSE_MODE_PROCESS

	# Esconde tudo que veio da cena (layout antigo)
	for c in get_children():
		if c is CanvasItem:
			c.visible = false

	if not main_menu:
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_load_fonts()
	_build()
	hide()


func _load_fonts() -> void:
	if ResourceLoader.exists(PATH_MINI):
		_fd_mini = load(PATH_MINI)
	if ResourceLoader.exists(PATH_KIWI):
		var t = load(PATH_KIWI)
		if t is DynamicFont:
			_fd_kiwi = t.font_data
		elif t is DynamicFontData:
			_fd_kiwi = t


func _font(size: int, kiwi: bool = false) -> DynamicFont:
	var f = DynamicFont.new()
	f.size = size
	if kiwi and _fd_kiwi:
		f.font_data = _fd_kiwi
	elif _fd_mini:
		f.font_data = _fd_mini
	elif _fd_kiwi:
		f.font_data = _fd_kiwi
	return f


func _apply_font(ctrl: Control, size: int, kiwi: bool = false) -> void:
	var f = _font(size, kiwi)
	if f.font_data:
		ctrl.add_font_override("font", f)


func _style(bg: Color, border: Color = Color(0,0,0,0), bw: int = 0, r: int = 8) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = bw
	sb.border_width_right = bw
	sb.border_width_top = bw
	sb.border_width_bottom = bw
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	return sb


func _build() -> void:
	tween = Tween.new()
	tween.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(tween)

	# --- blur ---
	_blur = ColorRect.new()
	_blur.color = C_BLUR
	_blur.anchor_right = 1.0
	_blur.anchor_bottom = 1.0
	_blur.mouse_filter = Control.MOUSE_FILTER_STOP
	_blur.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_blur)

	# --- root central ---
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.pause_mode = Node.PAUSE_MODE_PROCESS
	var sb_p = _style(C_PANEL, C_BORDER, 1, 12)
	sb_p.content_margin_left = 28
	sb_p.content_margin_right = 28
	sb_p.content_margin_top = 22
	sb_p.content_margin_bottom = 18
	_panel.add_stylebox_override("panel", sb_p)
	# ~520x largura, centrado
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.margin_left = -260
	_panel.margin_right = 260
	_panel.margin_top = -230
	_panel.margin_bottom = 230
	_root.add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 12)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.text = "Carregar Jogo" if main_menu else "Salvar / Carregar"
	_title.align = Label.ALIGN_CENTER
	_title.add_color_override("font_color", C_TEXT)
	_apply_font(_title, 28, true)
	vbox.add_child(_title)

	var sep = HSeparator.new()
	var sb_sep = StyleBoxFlat.new()
	sb_sep.bg_color = Color(0.3, 0.3, 0.35, 0.6)
	sb_sep.content_margin_top = 1
	sb_sep.content_margin_bottom = 1
	sep.add_stylebox_override("separator", sb_sep)
	vbox.add_child(sep)

	_slots_box = VBoxContainer.new()
	_slots_box.add_constant_override("separation", 8)
	_slots_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_slots_box)

	_slot_btns.clear()
	for i in range(4):
		var b = Button.new()
		b.rect_min_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.align = Button.ALIGN_LEFT
		b.clip_text = false
		_style_slot(b, false)
		_apply_font(b, 15)
		b.add_color_override("font_color", C_TEXT)
		b.add_color_override("font_color_hover", C_TEXT)
		b.connect("pressed", self, "_on_slot", [i])
		_slots_box.add_child(b)
		_slot_btns.append(b)

	var foot = HBoxContainer.new()
	foot.add_constant_override("separation", 12)
	vbox.add_child(foot)

	_btn_excluir = Button.new()
	_btn_excluir.text = "Excluir"
	_btn_excluir.flat = true
	_apply_font(_btn_excluir, 14)
	_btn_excluir.add_color_override("font_color", C_DIM)
	_btn_excluir.add_color_override("font_color_hover", Color(1, 0.4, 0.4))
	_btn_excluir.connect("pressed", self, "_on_excluir")
	foot.add_child(_btn_excluir)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)

	_hint = Label.new()
	_hint.text = 'ESC para sair'
	_hint.add_color_override("font_color", C_DIM)
	_apply_font(_hint, 13)
	foot.add_child(_hint)

	_build_popup()


func _style_slot(b: Button, del_mode: bool) -> void:
	var bg = C_RED if del_mode else C_SLOT
	var hv = Color(0.7, 0.2, 0.2) if del_mode else C_SLOT_H
	var sn = _style(bg, Color(0,0,0,0), 0, 8)
	sn.content_margin_left = 16
	sn.content_margin_right = 16
	sn.content_margin_top = 8
	sn.content_margin_bottom = 8
	var sh = sn.duplicate()
	sh.bg_color = hv
	b.add_stylebox_override("normal", sn)
	b.add_stylebox_override("hover", sh)
	b.add_stylebox_override("pressed", sh)
	b.add_stylebox_override("focus", sh)
	b.add_stylebox_override("disabled", sn)


func _build_popup() -> void:
	_popup_dim = ColorRect.new()
	_popup_dim.color = Color(0, 0, 0, 0.45)
	_popup_dim.anchor_right = 1.0
	_popup_dim.anchor_bottom = 1.0
	_popup_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_dim.pause_mode = Node.PAUSE_MODE_PROCESS
	_popup_dim.visible = false
	add_child(_popup_dim)

	_popup = PanelContainer.new()
	_popup.pause_mode = Node.PAUSE_MODE_PROCESS
	var sb = _style(Color(0.09, 0.09, 0.11, 0.98), C_BORDER, 1, 10)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 16
	_popup.add_stylebox_override("panel", sb)
	_popup.anchor_left = 0.5
	_popup.anchor_right = 0.5
	_popup.anchor_top = 0.5
	_popup.anchor_bottom = 0.5
	_popup.margin_left = -200
	_popup.margin_right = 200
	_popup.margin_top = -90
	_popup.margin_bottom = 90
	_popup.visible = false
	add_child(_popup)

	var pv = VBoxContainer.new()
	pv.add_constant_override("separation", 14)
	_popup.add_child(pv)

	_popup_label = Label.new()
	_popup_label.align = Label.ALIGN_CENTER
	_popup_label.autowrap = true
	_popup_label.add_color_override("font_color", C_TEXT)
	_apply_font(_popup_label, 16)
	pv.add_child(_popup_label)

	var row = HBoxContainer.new()
	row.add_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGN_CENTER
	pv.add_child(row)

	_btn_load = _make_action_btn("Carregar", false)
	_btn_load.connect("pressed", self, "_on_load")
	row.add_child(_btn_load)

	_btn_save = _make_action_btn("Salvar por cima", true)
	_btn_save.connect("pressed", self, "_on_save")
	row.add_child(_btn_save)

	_btn_cancel = _make_action_btn("Cancelar", true)
	_btn_cancel.connect("pressed", self, "_on_cancel")
	row.add_child(_btn_cancel)


func _make_action_btn(txt: String, secondary: bool) -> Button:
	var b = Button.new()
	b.text = txt
	b.rect_min_size = Vector2(120, 36)
	_apply_font(b, 14)
	b.add_color_override("font_color", C_TEXT)
	var bg = Color(0.15, 0.15, 0.18) if secondary else C_PURPLE
	var hv = Color(0.22, 0.18, 0.30) if secondary else C_PURPLE_H
	var sn = _style(bg, C_BORDER if secondary else Color(0,0,0,0), 1 if secondary else 0, 6)
	sn.content_margin_left = 12
	sn.content_margin_right = 12
	sn.content_margin_top = 8
	sn.content_margin_bottom = 8
	var sh = sn.duplicate()
	sh.bg_color = hv
	b.add_stylebox_override("normal", sn)
	b.add_stylebox_override("hover", sh)
	b.add_stylebox_override("pressed", sh)
	b.add_stylebox_override("focus", sh)
	return b


# =====================================================================
# API
# =====================================================================

func open():
	show()
	if not main_menu:
		get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_title.text = "Carregar Jogo" if main_menu else "Salvar / Carregar"
	_btn_save.visible = not main_menu
	_refresh_slots()

	_blur.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.rect_scale = Vector2(0.96, 0.96)
	_panel.rect_pivot_offset = Vector2(260, 230)
	tween.stop_all()
	tween.interpolate_property(_blur, "modulate:a", 0.0, 1.0, 0.22, Tween.TRANS_SINE)
	tween.interpolate_property(_panel, "modulate:a", 0.0, 1.0, 0.22, Tween.TRANS_SINE)
	tween.interpolate_property(_panel, "rect_scale", Vector2(0.96, 0.96), Vector2.ONE, 0.28, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.start()


func close():
	modo_exclusao = false
	_hide_popup()
	tween.stop_all()
	tween.interpolate_property(_blur, "modulate:a", _blur.modulate.a, 0.0, 0.18, Tween.TRANS_SINE)
	tween.interpolate_property(_panel, "modulate:a", _panel.modulate.a, 0.0, 0.18, Tween.TRANS_SINE)
	tween.start()
	yield(tween, "tween_all_completed")
	hide()
	if not main_menu:
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()


func _refresh_slots() -> void:
	for i in range(4):
		var info = SaveManager.get_slot_info(i)
		var b: Button = _slot_btns[i]
		_style_slot(b, modo_exclusao and not info.empty)
		if info.empty:
			b.text = "  Slot %d\n  Vazio" % (i + 1)
			b.add_color_override("font_color", C_DIM)
		else:
			var cap = str(info.get("capitulo", ""))
			var pt = str(info.get("playtime", ""))
			var data = "%s  %s" % [info.date, info.time]
			var l2 = cap
			if pt != "":
				l2 = (cap + "  ·  " + pt) if cap != "" else pt
			b.text = "  Slot %d  —  %s\n  %s" % [i + 1, data, l2]
			b.add_color_override("font_color", C_TEXT)

	if modo_exclusao:
		_btn_excluir.text = "Cancelar"
		_btn_excluir.add_color_override("font_color", Color(1, 0.4, 0.4))
	else:
		_btn_excluir.text = "Excluir"
		_btn_excluir.add_color_override("font_color", C_DIM)


func _on_excluir():
	modo_exclusao = not modo_exclusao
	_hide_popup()
	_refresh_slots()


func _on_slot(i: int):
	var info = SaveManager.get_slot_info(i)
	if modo_exclusao:
		if not info.empty:
			SaveManager.delete_save(i)
			modo_exclusao = false
			_refresh_slots()
		return

	if info.empty:
		if main_menu:
			return
		SaveManager.save_game(i)
		_refresh_slots()
		yield(get_tree().create_timer(0.25), "timeout")
		close()
		return

	current_slot = i
	var cap = str(info.get("capitulo", ""))
	if cap != "":
		_popup_label.text = "Slot %d — %s\nO que você deseja?" % [i + 1, cap]
	else:
		_popup_label.text = "Slot %d\nO que você deseja?" % (i + 1)
	_btn_save.visible = not main_menu
	_popup_dim.visible = true
	_popup.visible = true


func _hide_popup():
	current_slot = -1
	if _popup:
		_popup.visible = false
	if _popup_dim:
		_popup_dim.visible = false


func _on_load():
	if current_slot < 0:
		return
	var s = current_slot
	_hide_popup()
	SaveManager.load_game(s)
	close()


func _on_save():
	if current_slot < 0 or main_menu:
		return
	SaveManager.save_game(current_slot)
	_hide_popup()
	_refresh_slots()
	yield(get_tree().create_timer(0.25), "timeout")
	close()


func _on_cancel():
	_hide_popup()


func _input(event):
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		if _popup and _popup.visible:
			_on_cancel()
		elif modo_exclusao:
			modo_exclusao = false
			_refresh_slots()
		else:
			close()
		get_tree().set_input_as_handled()


func _exit_tree():
	if not main_menu:
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
