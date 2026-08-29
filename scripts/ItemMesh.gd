extends Spatial

var tempo = 0.0
export var amplitude = 0.08
export var velocidade_flutuar = 2.0
export var velocidade_giro = 0.5

func _process(delta):
	tempo += delta * velocidade_flutuar
	translation.y = sin(tempo) * amplitude
	rotation.y += delta * velocidade_giro
