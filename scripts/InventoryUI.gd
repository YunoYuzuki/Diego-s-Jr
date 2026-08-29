extends CanvasLayer
const MAX_VISIBLE = 8
const ANIM_SPEED = 10.0
const FADE_REMOVE = 1.2

var is_open: bool = false
onready var container = $VBoxContainer

# Linhas que estão sumindo em vermelho: { row: Node, t: float }
var _removendo: Array = []

func _ready():
	if Global.rodando_como_menu_bg:
		queue_free()
		return
	pause_mode = Node.PAUSE_MODE_PROCESS
	add_to_group("ui_persistente")
	call_deferred("_tirar_do_viewport")

	Inventory.connect("item_added",   self, "_on_item_added")
	Inventory.connect("item_removed", self, "_on_item_removed")
	Inventory.connect("stack_changed", self, "_on_stack_changed")
	_rebuild()

func _tirar_do_viewport() -> void:
	var arvore = get_tree()
	var pai_atual = get_parent()
	if pai_atual:
		pai_atual.remove_child(self)
	arvore.root.add_child(self)
	_atualizar_layout()

func _atualizar_layout() -> void:
	var tela_x = get_viewport().size.x
	var tela_y = get_viewport().size.y
	# Centraliza verticalmente o bloco de itens no lado direito
	var h = max(container.get_combined_minimum_size().y, 28.0 * max(Inventory.items.size(), 1))
	container.rect_position = Vector2(tela_x, (tela_y - h) * 0.5)

func _process(delta):
	var tela_x = get_viewport().size.x
	var tela_y = get_viewport().size.y
	var h = container.rect_size.y
	if h < 1.0:
		h = 28.0 * max(container.get_child_count(), 1)
	var target_y = (tela_y - h) * 0.5
	var target_x = tela_x - 220.0 if is_open else tela_x - 20.0
	container.rect_position.x = lerp(container.rect_position.x, target_x, ANIM_SPEED * delta)
	container.rect_position.y = lerp(container.rect_position.y, target_y, ANIM_SPEED * delta)

	# Fade vermelho de itens removidos
	var i = 0
	while i < _removendo.size():
		var entry = _removendo[i]
		if not is_instance_valid(entry.row):
			_removendo.remove(i)
			continue
		entry.t -= delta
		var a = clamp(entry.t / FADE_REMOVE, 0.0, 1.0)
		entry.row.modulate = Color(1.0, 0.25, 0.25, a)
		if entry.t <= 0.0:
			entry.row.queue_free()
			_removendo.remove(i)
		else:
			_removendo[i] = entry
			i += 1

func _input(event):
	if event.is_action_pressed("inventory_toggle"):
		# Só abre/fecha se tiver item
		if Inventory.esta_vazio() and not is_open:
			return
		if Inventory.esta_vazio() and is_open:
			is_open = false
			_atualizar_dica()
			return
		is_open = !is_open
		_atualizar_dica()
		get_tree().set_input_as_handled()
		return

	# Tecla C → inventário de cartas (CartasInventoryUI)
	if event is InputEventKey and event.pressed and not event.echo and event.scancode == KEY_C:
		if typeof(Global) != TYPE_NIL and Global.get("rodando_como_menu_bg"):
			return
		var ui = _pegar_cartas_inv_ui()
		if ui == null:
			return
		# Se a própria UI já está aberta, ela mesma cuida do C / ESC
		if ui.get("esta_aberta") == true:
			return
		if typeof(CartasInventory) != TYPE_NIL and CartasInventory.esta_vazio():
			_flash_dica("Você não possui nenhuma carta")
			get_tree().set_input_as_handled()
			return
		if ui.has_method("abrir"):
			ui.abrir()
		get_tree().set_input_as_handled()

var _label_dica: Label = null

func _atualizar_dica() -> void:
	if _label_dica == null:
		_label_dica = Label.new()
		_label_dica.add_font_override("font", _fonte_minipixel(26))
		_label_dica.modulate = Color(1, 1, 1, 0.85)
		add_child(_label_dica)
	# Quando o inventário de itens está aberto, mostra dica [C] pras cartas
	if is_open:
		_label_dica.text = "[C]"
		_label_dica.visible = true
		var vp = get_viewport().size
		_label_dica.rect_position = Vector2(vp.x - 70, vp.y * 0.5 + 80)
	else:
		_label_dica.visible = false

func _flash_dica(txt: String) -> void:
	if _label_dica == null:
		_atualizar_dica()
	if _label_dica:
		_label_dica.text = txt
		_label_dica.visible = true
		var vp = get_viewport().size
		_label_dica.rect_position = Vector2(vp.x - 230, vp.y * 0.5 + 80)

func _on_item_added(_item_id = null) -> void:
	_rebuild()
	# NÃO abre sozinho — jogador decide

func _on_item_removed(item_id) -> void:
	# Marca a linha correspondente em vermelho e faz fade
	for row in container.get_children():
		if row.has_meta("item_id") and row.get_meta("item_id") == item_id:
			_removendo.append({"row": row, "t": FADE_REMOVE})
			row.remove_meta("item_id")
			# tira do container lógico mas mantém na árvore pro fade
			# (fica como irmão visual)
			break
	_rebuild_keep_fading()

func _on_stack_changed(_item_id, _q) -> void:
	_rebuild_keep_fading()

func _rebuild() -> void:
	for child in container.get_children():
		# Não mata linhas em fade
		var em_fade = false
		for e in _removendo:
			if e.row == child:
				em_fade = true
				break
		if not em_fade:
			child.queue_free()
	_populate_rows()

func _rebuild_keep_fading() -> void:
	for child in container.get_children():
		var em_fade = false
		for e in _removendo:
			if e.row == child:
				em_fade = true
				break
		if not em_fade:
			child.queue_free()
	_populate_rows()

func _populate_rows() -> void:
	var lista = Inventory.items
	var n = min(lista.size(), MAX_VISIBLE)
	for i in range(n):
		var item_id = lista[i]
		var row = HBoxContainer.new()
		row.rect_min_size = Vector2(200, 28)
		row.set_meta("item_id", item_id)

		var dot = Label.new()
		dot.text = ". "
		if ResourceLoader.exists("res://assets/fonts/KiwiSoda.tres"):
			dot.add_font_override("font", load("res://assets/fonts/KiwiSoda.tres"))
		row.add_child(dot)

		var nome = Label.new()
		nome.text = Inventory.get_item_name(item_id)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.add_font_override("font", _fonte_minipixel())
		row.add_child(nome)

		container.add_child(row)

	# Se esvaziou e estava aberto, fecha
	if Inventory.esta_vazio():
		is_open = false
	_atualizar_dica()

func _fonte_minipixel(tamanho: int = 26) -> DynamicFont:
	var f = DynamicFont.new()
	f.font_data = load("res://assets/fonts/MiniPixel/Minipixel-Regular.ttf")
	f.size = tamanho
	return f


func _pegar_cartas_inv_ui() -> Node:
	# Preferência: grupo (funciona com ou sem Autoload)
	if not is_inside_tree():
		return null
	for n in get_tree().get_nodes_in_group("cartas_inventory_ui"):
		if is_instance_valid(n):
			return n
	# Fallback: raiz da árvore pelo nome comum
	var root = get_tree().root
	for c in root.get_children():
		if c.name == "CartasInventoryUI" or c.get_script() and str(c.get_script().resource_path).ends_with("CartasInventoryUI.gd"):
			return c
	return null
