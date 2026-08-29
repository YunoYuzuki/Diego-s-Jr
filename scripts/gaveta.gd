extends StaticBody

export var distancia_abrir : float = 0.5
export var velocidade      : float = 4.0

var aberta        : bool  = false
var pos_fechada   : Vector3
var pos_aberta    : Vector3

func _ready():
	add_to_group("interagivel")
	pos_fechada = translation
	pos_aberta  = translation - transform.basis.y * distancia_abrir

func _process(delta):
	var alvo = pos_aberta if aberta else pos_fechada
	translation = translation.linear_interpolate(alvo, velocidade * delta)

func interagir(_camera):
	aberta = not aberta

func set_foco(_ativo: bool):
	pass
