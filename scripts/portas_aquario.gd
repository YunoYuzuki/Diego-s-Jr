extends StaticBody

export var angulo_aberta    : float = -120.0
export var velocidade_porta : float = 2.5
export var velocidade_maca  : float = 4.5

onready var pivot      = $Door/pivot_porta
onready var machaneta1 = $Door/pivot_porta/Porta/macaneta_1
onready var machaneta2 = $Door/pivot_porta/Porta/macaneta_2
onready var colisao_vao = $CollisionShape
onready var colisao_porta = $Door/pivot_porta/StaticBody/CollisionShape
onready var area = $Door/pivot_porta/Area

var aberta    : bool  = false
var animando  : bool  = false
var alvo_porta: float = 0.0
var repouso_maca1 := Vector3(0.0,    0.0, 180.0)
var alvo_maca1    := Vector3(0.0,   16.0, 180.0)
var repouso_maca2 := Vector3(0.0, -180.0,   0.0)
var alvo_maca2    := Vector3(0.0,  -164.0,   0.0)

func _ready():
	add_to_group("interagivel")
	repouso_maca1 = machaneta1.rotation_degrees
	repouso_maca2 = machaneta2.rotation_degrees
	colisao_porta.disabled = true
	area.add_to_group("interagivel")
	area.set_meta("door_parent", self)

func set_foco(_ativo: bool):
	pass

func interagir(_player):
	if animando:
		return
	aberta     = !aberta
	alvo_porta = angulo_aberta if aberta else 0.0
	animando   = true
	colisao_vao.disabled  = aberta   # vo da parede: ativo quando fechada
	# colisao_porta nunca bloqueia interao, s serve pra fsica

func _process(delta):
	if not animando:
		return

	var alvo_m1 = alvo_maca1 if aberta else repouso_maca1
	var alvo_m2 = alvo_maca2 if aberta else repouso_maca2
	var t_maca  = velocidade_maca * delta

	machaneta1.rotation_degrees = _lerp_rot(machaneta1.rotation_degrees, alvo_m1, t_maca)
	machaneta2.rotation_degrees = _lerp_rot(machaneta2.rotation_degrees, alvo_m2, t_maca)

	var maca_pronta = machaneta1.rotation_degrees.distance_to(alvo_m1) < 2.0
	if maca_pronta:
		var rp = pivot.rotation_degrees
		rp.z = lerp(rp.z, alvo_porta, velocidade_porta * delta)
		pivot.rotation_degrees = rp

		if abs(rp.z - alvo_porta) < 0.1:
			pivot.rotation_degrees.z    = alvo_porta
			machaneta1.rotation_degrees = alvo_m1
			machaneta2.rotation_degrees = alvo_m2
			animando = false

func _lerp_rot(atual: Vector3, alvo: Vector3, t: float) -> Vector3:
	return Vector3(
		rad2deg(lerp_angle(deg2rad(atual.x), deg2rad(alvo.x), t)),
		rad2deg(lerp_angle(deg2rad(atual.y), deg2rad(alvo.y), t)),
		rad2deg(lerp_angle(deg2rad(atual.z), deg2rad(alvo.z), t))
	)