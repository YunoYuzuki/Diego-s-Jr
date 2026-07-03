extends Panel

# Referncias aos ns (ajuste os caminhos se seu hierarchy for diferente)
onready var slots_container = $VBoxContainer/SlotsContainer
onready var title_label = $TitleLabel
onready var close_button = $CloseButton

var tween : Tween
var original_scale = Vector2.ONE
var is_open = false

func _ready():
	# Cria o Tween uma nica vez
	tween = Tween.new()
	add_child(tween)
	
	# Esconde no incio
	hide()
	modulate.a = 0.0
	rect_scale = Vector2(0.3, 0.3)
	
	# Conecta os botes
	$VBoxContainer/SlotsContainer/Slot1.connect("pressed", self, "_on_slot_pressed", [0])
	$VBoxContainer/SlotsContainer/Slot2.connect("pressed", self, "_on_slot_pressed", [1])
	$VBoxContainer/SlotsContainer/Slot3.connect("pressed", self, "_on_slot_pressed", [2])
	close_button.connect("pressed", self, "close")
	
	# Centraliza o painel na tela (caso no esteja usando Anchor Full Rect)
	rect_pivot_offset = rect_size / 2   # importante pra escala vir do centro

func open():
	if is_open:
		return
	is_open = true
	
	show()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Reset inicial da animao
	rect_scale = Vector2(0.35, 0.35)
	modulate.a = 0.0
	rect_pivot_offset = rect_size / 2   # garante que escala do centro
	
	# Animao principal (bem estilo RE4 - zoom suave com "back")
	tween.stop_all()
	tween.interpolate_property(self, "rect_scale",
		rect_scale, Vector2(1.0, 1.0),
		0.5, Tween.TRANS_BACK, Tween.EASE_OUT)
	
	tween.interpolate_property(self, "modulate:a",
		0.0, 1.0,
		0.4, Tween.TRANS_LINEAR, Tween.EASE_IN)
	
	tween.start()
	

func close():
	if not is_open:
		return
	is_open = false
	
	tween.stop_all()
	
	# Animao de sada (rpida)
	tween.interpolate_property(self, "rect_scale",
		rect_scale, Vector2(0.35, 0.35),
		0.25, Tween.TRANS_BACK, Tween.EASE_IN)
	
	tween.interpolate_property(self, "modulate:a",
		modulate.a, 0.0,
		0.25, Tween.TRANS_LINEAR)
	
	tween.start()
	
	# Espera a animao terminar pra esconder de verdade
	yield(tween, "tween_all_completed")
	
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
	

func _on_slot_pressed(slot: int):
	# Som de tecla de mquina (se voc adicionou o AudioStreamPlayer)
	if has_node("TypewriterSound"):
		$TypewriterSound.play()
	
	SaveManager.save_game(slot)
	
	# Pequeno delay pra sentir o clique antes de fechar
	yield(get_tree().create_timer(0.35), "timeout")
	close()

# Fecha com ESC
func _input(event):
	if is_open and event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		close()
