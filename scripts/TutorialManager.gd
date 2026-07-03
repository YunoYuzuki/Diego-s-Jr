extends Node

# Flags
var lanterna_mostrado  : bool = false
var interagir_mostrado : bool = false
var tab_mostrado       : bool = false
var ctrl_mostrado      : bool = false   # novo: tutorial do agachar
var exibindo           : bool = false
var fila               : Array = []

var label : Label = null
var fonte: DynamicFont = preload("res://assets/fonts/pixelmix.tres")

func _ready():
	add_to_group("tutorial_manager")
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	label = Label.new()
	label.set("custom_fonts/font", fonte)
	label.align = Label.ALIGN_CENTER
	label.anchor_left   = 0.0
	label.anchor_right  = 1.0
	label.anchor_top    = 1.0
	label.anchor_bottom = 1.0
	label.margin_top    = -60.0
	label.margin_bottom = -20.0
	label.modulate.a    = 0.0
	label.add_color_override("font_color", Color(1, 1, 1, 1))
	canvas.add_child(label)

# ==================== SAVE / LOAD ====================

func save_data() -> Dictionary:
	return {
		"lanterna_mostrado"  : lanterna_mostrado,
		"interagir_mostrado" : interagir_mostrado,
		"tab_mostrado"       : tab_mostrado,
		"ctrl_mostrado"      : ctrl_mostrado,
	}

func load_data(data: Dictionary) -> void:
	lanterna_mostrado  = data.get("lanterna_mostrado",  false)
	interagir_mostrado = data.get("interagir_mostrado", false)
	tab_mostrado       = data.get("tab_mostrado",       false)
	ctrl_mostrado      = data.get("ctrl_mostrado",      false)
	fila.clear()
	exibindo = false
	print("TutorialManager restaurado via Autoload")

# ==================== TUTORIAIS ====================

func tutorial_lanterna():
	if lanterna_mostrado:
		return
	lanterna_mostrado = true
	fila.append("Pressione \"F\" para ligar ou desligar a lanterna")
	_processar_fila()

func tutorial_interagir():
	if interagir_mostrado:
		return
	interagir_mostrado = true
	fila.append("Pressione \"E\" para interagir")
	_processar_fila()

func tutorial_inventario():
	if tab_mostrado:
		return
	tab_mostrado = true
	fila.append("*delay*")
	fila.append("Pressione \"TAB\" para ver o inventário")
	_processar_fila()

func tutorial_agachar():
	if ctrl_mostrado:
		return
	ctrl_mostrado = true
	fila.append("*delay*")
	fila.append("Segure \"CTRL\" para se agachar")
	_processar_fila()

# ==================== FILA ====================

func _processar_fila():
	if exibindo or fila.empty():
		return
	exibindo = true
	_exibir_proximo()

func _exibir_proximo():
	if fila.empty():
		exibindo = false
		return

	var msg = fila.pop_front()
	if msg == "*delay*":
		yield(get_tree().create_timer(3.0), "timeout")
		_exibir_proximo()
		return

	label.text = msg
	_fade(1.0, 0.5)
	yield(get_tree().create_timer(3.0), "timeout")
	_fade(0.0, 0.5)
	yield(get_tree().create_timer(0.5), "timeout")
	_exibir_proximo()

func _fade(alvo: float, duracao: float):
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(label, "modulate:a", label.modulate.a, alvo, duracao, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.queue_free()
