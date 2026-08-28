extends CanvasLayer

onready var background_panel = $BackgroundPanel
onready var slots = [$BackgroundPanel/VBoxContainer/SlotsContainer/Slot1,
					 $BackgroundPanel/VBoxContainer/SlotsContainer/Slot2,
					 $BackgroundPanel/VBoxContainer/SlotsContainer/Slot3,
					 $BackgroundPanel/VBoxContainer/SlotsContainer/Slot4]
onready var confirmation_popup = $ConfirmationPopup
onready var confirm_label = $ConfirmationPopup/Label
onready var save_btn = $ConfirmationPopup/VBoxContainer/SaveButton
onready var load_btn = $ConfirmationPopup/VBoxContainer/LoadButton
onready var delete_btn = $BackgroundPanel/Excluir

var main_menu : bool = false
var tween : Tween
var current_slot_to_confirm = -1
var modo_exclusao : bool = false

func _ready():
	add_to_group("save_ui")
	
	if not main_menu:
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	pause_mode = Node.PAUSE_MODE_PROCESS
	tween = Tween.new()
	tween.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(tween)
	

	hide()
	confirmation_popup.hide()

	for i in range(4):
		slots[i].connect("pressed", self, "_on_slot_pressed", [i])

	save_btn.connect("pressed", self, "_on_confirm_save")
	load_btn.connect("pressed", self, "_on_confirm_load")
	delete_btn.connect("pressed", self, "_on_toggle_exclusao")

func open():
	show()
	if not main_menu:
		get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_slot_buttons()
	background_panel.rect_pivot_offset = background_panel.rect_size / 2
	background_panel.rect_scale = Vector2(0.35, 0.35)
	tween.stop_all()
	tween.interpolate_property(background_panel, "rect_scale",
		Vector2(0.35, 0.35), Vector2(1.0, 1.0),
		0.45, Tween.TRANS_BACK, Tween.EASE_OUT)
	background_panel.modulate.a = 0.0
	tween.interpolate_property(background_panel, "modulate:a", 0.0, 1.0, 0.35, Tween.TRANS_LINEAR)
	tween.start()

func close():
	modo_exclusao = false
	_update_delete_button()
	tween.stop_all()
	tween.interpolate_property(background_panel, "rect_scale",
		background_panel.rect_scale, Vector2(0.35, 0.35),
		0.25, Tween.TRANS_BACK, Tween.EASE_IN)
	tween.interpolate_property(background_panel, "modulate:a",
		background_panel.modulate.a, 0.0, 0.25, Tween.TRANS_LINEAR)
	tween.start()
	yield(tween, "tween_all_completed")
	hide()
	confirmation_popup.hide()
	if not main_menu:
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()

func _update_slot_buttons():
	for i in range(4):
		var info = SaveManager.get_slot_info(i)
		var nome = "Save Auto." if i == 0 else "Slot %d" % i
		if info.empty:
			slots[i].text = "Slot %d - VAZIO" % (i + 1)
		else:
			slots[i].text = "Slot %d - %s %s" % [(i + 1), info.date, info.time]

func _update_delete_button():
	if modo_exclusao:
		delete_btn.text = "Cancelar Excluso"
		delete_btn.modulate = Color(1, 0.3, 0.3)  # vermelho pra indicar modo ativo
	else:
		delete_btn.text = "Excluir"
		delete_btn.modulate = Color(1, 1, 1)

func _on_toggle_exclusao():
	modo_exclusao = !modo_exclusao
	_update_delete_button()
	# Fecha popup de confirmao se estiver aberto
	if confirmation_popup.visible:
		confirmation_popup.hide()
		current_slot_to_confirm = -1

func _on_slot_pressed(slot: int):
	var info = SaveManager.get_slot_info(slot)

	# Modo exclusão ativo
	if modo_exclusao:
		if not info.empty:
			if SaveManager.delete_save(slot):
				print("Slot ", slot + 1, " excluído!")
			modo_exclusao = false
			_update_delete_button()
			_update_slot_buttons()
		return

	# Modo normal
	if info.empty:
		SaveManager.save_game(slot)
		_update_slot_buttons()
		yield(get_tree().create_timer(0.4), "timeout")
		close()
	else:
		current_slot_to_confirm = slot
		confirm_label.text = "O que voce deseja?"
		confirmation_popup.show()

func _on_confirm_save():
	if current_slot_to_confirm == -1:
		return
	SaveManager.save_game(current_slot_to_confirm)
	_update_slot_buttons()
	confirmation_popup.hide()
	current_slot_to_confirm = -1
	yield(get_tree().create_timer(0.4), "timeout")
	close()

func _on_confirm_load():
	if current_slot_to_confirm == -1:
		return
	SaveManager.load_game(current_slot_to_confirm)
	confirmation_popup.hide()
	current_slot_to_confirm = -1
	close()

func _on_confirm_cancel():
	confirmation_popup.hide()
	current_slot_to_confirm = -1

func _input(event):
	if visible and event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		if modo_exclusao:
			modo_exclusao = false
			_update_delete_button()
		elif confirmation_popup.visible:
			_on_confirm_cancel()
		else:
			close()

func _exit_tree():
	if not main_menu:
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
