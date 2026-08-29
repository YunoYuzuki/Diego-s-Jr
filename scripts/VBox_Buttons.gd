extends VBoxContainer

export var deslocamento_hover := 15.0  # quanto o texto anda pro lado, em pixels
export var duracao_animacao := 0.15

onready var tween := Tween.new()

func _ready():
	add_child(tween)
	for botao in get_children():
		if botao is Button:
			botao.connect("mouse_entered", self, "_on_botao_hover", [botao, true])
			botao.connect("mouse_exited", self, "_on_botao_hover", [botao, false])

func _on_botao_hover(botao: Button, entrando: bool) -> void:
	var seta = botao.get_node_or_null("Label")  # <- nome certo agora
	var pos_base = botao.get_meta("pos_base") if botao.has_meta("pos_base") else botao.rect_position.x
	
	if not botao.has_meta("pos_base"):
		botao.set_meta("pos_base", botao.rect_position.x)
		pos_base = botao.rect_position.x

	var pos_alvo = pos_base + deslocamento_hover if entrando else pos_base

	tween.interpolate_property(botao, "rect_position:x",
		botao.rect_position.x, pos_alvo, duracao_animacao,
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.start()

	if seta:
		if entrando:
			seta.visible = true
			tween.interpolate_property(seta, "modulate:a",
				seta.modulate.a, 1.0, duracao_animacao,
				Tween.TRANS_QUAD, Tween.EASE_OUT)
		else:
			tween.interpolate_property(seta, "modulate:a",
				seta.modulate.a, 0.0, duracao_animacao,
				Tween.TRANS_QUAD, Tween.EASE_IN)
		tween.start()
