extends CanvasLayer

onready var label = $SavingLabel
onready var timer = $HideTimer

var blink_timer: Timer

func _ready():
	visible = false
	
	# Timer pra esconder depois de salvar
	timer.one_shot = true
	timer.connect("timeout", self, "_hide_indicator")
	
	# Timer pra fazer o texto piscar
	blink_timer = Timer.new()
	blink_timer.wait_time = 0.35   # velocidade do pisca-pisca
	blink_timer.one_shot = false
	blink_timer.connect("timeout", self, "_blink")
	add_child(blink_timer)

func show_saving():
	visible = true
	label.modulate.a = 1.0
	blink_timer.start()
	timer.start(2.0)        # tempo total que o indicador fica na tela (ajuste se o save demorar mais)

func _blink():
	# Faz o texto piscar (fade rpido)
	var alpha = 0.3 if label.modulate.a > 0.6 else 1.0
	label.modulate.a = alpha

func _hide_indicator():
	blink_timer.stop()
	visible = false
	label.modulate.a = 1.0
