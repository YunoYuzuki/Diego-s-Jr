extends Control

onready var canvas     = $CanvasLayer
onready var color_rect = $CanvasLayer/ColorRect
onready var titulo     = $CanvasLayer/Title_Emotion
onready var corpo      = $CanvasLayer/Label

var _seta : Label = null
var _seta_y_base : float = 0.0
var _tempo_seta : float = 0.0
var _aberto : bool = false
var _pode_fechar : bool = false
var _fechando : bool = false

export var alpha_escuro : float = 0.65
export var duracao_fade : float = 0.35
export var amplitude_seta : float = 8.0
export var velocidade_seta : float = 3.5

func _ready() -> void:
	add_to_group("emotion_tutorial")
	pause_mode = Node.PAUSE_MODE_PROCESS
	mouse_filter = Control.MOUSE_FILTER_STOP

	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	margin_left = 0
	margin_top = 0
	margin_right = 0
	margin_bottom = 0

	if color_rect:
		color_rect.anchor_left = 0
		color_rect.anchor_top = 0
		color_rect.anchor_right = 1
		color_rect.anchor_bottom = 1
		color_rect.margin_left = 0
		color_rect.margin_top = 0
		color_rect.margin_right = 0
		color_rect.margin_bottom = 0
		if color_rect.color.a >= 0.99:
			color_rect.color = Color(0, 0, 0, 0)
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	_criar_seta()
	_abrir()

func _criar_seta() -> void:
	_seta = canvas.get_node_or_null("SetaContinuar") as Label
	if _seta == null:
		_seta = Label.new()
		_seta.name = "SetaContinuar"
		_seta.text = "v"
		_seta.align = Label.ALIGN_CENTER
		_seta.anchor_left = 0.5
		_seta.anchor_right = 0.5
		_seta.anchor_top = 1.0
		_seta.anchor_bottom = 1.0
		_seta.margin_left = -40
		_seta.margin_right = 40
		_seta.margin_top = -70
		_seta.margin_bottom = -40
		_seta.add_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
		if corpo and corpo.get("custom_fonts/font"):
			_seta.set("custom_fonts/font", corpo.get("custom_fonts/font"))
		canvas.add_child(_seta)

	_seta_y_base = _seta.margin_top
	_seta.modulate.a = 0.0

func _abrir() -> void:
	_aberto = true
	_pode_fechar = true
	_fechando = false

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	modulate.a = 1.0
	if color_rect:
		var c = color_rect.color
		c.a = 1.0
		color_rect.color = c

	var tween = Tween.new()
	tween.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(tween)

	tween.interpolate_property(self, "modulate:a", 0.0, 1.0, duracao_fade,
		Tween.TRANS_SINE, Tween.EASE_OUT)

	if color_rect:
		var cor_final = color_rect.color
		cor_final.a = alpha_escuro
		tween.interpolate_property(color_rect, "color",
			color_rect.color, cor_final, duracao_fade,
			Tween.TRANS_SINE, Tween.EASE_OUT)

	if _seta:
		tween.interpolate_property(_seta, "modulate:a", 0.0, 1.0, duracao_fade,
			Tween.TRANS_SINE, Tween.EASE_OUT)

	tween.start()
	yield(tween, "tween_all_completed")
	tween.queue_free()

func _process(delta: float) -> void:
	if not _aberto or _seta == null:
		return
	_tempo_seta += delta * velocidade_seta
	var offset = sin(_tempo_seta) * amplitude_seta
	_seta.margin_top = _seta_y_base + offset
	_seta.margin_bottom = _seta_y_base + 30.0 + offset

func _input(event) -> void:
	if not _aberto or not _pode_fechar or _fechando:
		return

	var confirmou := false

	if event.is_action_pressed("ui_cancel"):
		confirmou = true
	elif event is InputEventKey and event.pressed and not event.echo and event.scancode == KEY_ESCAPE:
		confirmou = true
	elif event.is_action_pressed("e") or event.is_action_pressed("ui_accept"):
		confirmou = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_E or event.scancode == KEY_ENTER or event.scancode == KEY_SPACE:
			confirmou = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		confirmou = true

	if confirmou:
		get_tree().set_input_as_handled()  # bloqueia o InputManager
		_fechar()

func _fechar() -> void:
	if not _aberto or _fechando:
		return
	_fechando = true
	_pode_fechar = false
	_aberto = false

	var tween = Tween.new()
	tween.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(tween)

	tween.interpolate_property(self, "modulate:a", modulate.a, 0.0, 0.25,
		Tween.TRANS_SINE, Tween.EASE_IN)

	if color_rect:
		var cor_fim = color_rect.color
		cor_fim.a = 0.0
		tween.interpolate_property(color_rect, "color",
			color_rect.color, cor_fim, 0.25,
			Tween.TRANS_SINE, Tween.EASE_IN)

	tween.start()
	yield(tween, "tween_all_completed")
	tween.queue_free()

	if is_in_group("emotion_tutorial"):
		remove_from_group("emotion_tutorial")

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
