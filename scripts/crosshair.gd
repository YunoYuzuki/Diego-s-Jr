extends Control

export var cor_normal : Color = Color(1, 1, 1, 0.9)
export var cor_foco   : Color = Color(1, 1, 1, 1.0)

var raio_atual    : float = 0.0
var raio_alvo     : float = 0.0
var alpha_circulo : float = 0.0

const RAIO_CIRCULO : float = 12.0
const VEL_ANIM     : float = 6.0

func _ready():
	anchor_left   = 0.5
	anchor_top    = 0.5
	anchor_right  = 0.5
	anchor_bottom = 0.5
	margin_left   = -50.0
	margin_top    = -50.0
	margin_right  = 50.0
	margin_bottom = 50.0
	rect_size     = Vector2(100.0, 100.0)
	rect_pivot_offset = rect_size / 2.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE

func _process(delta):
	raio_atual    = lerp(raio_atual,    raio_alvo,                VEL_ANIM * delta)
	alpha_circulo = lerp(alpha_circulo, raio_alvo / RAIO_CIRCULO, VEL_ANIM * delta)
	update()

func set_foco(ativo: bool):
	raio_alvo = RAIO_CIRCULO if ativo else 0.0

func _draw():
	var centro = Vector2(50.0, 50.0)
	var raio_ponto = lerp(2.5, 0.0, alpha_circulo)
	draw_circle(centro, raio_ponto, cor_normal)
	if alpha_circulo > 0.01:
		var cor_c = cor_foco
		cor_c.a   = alpha_circulo
		draw_arc(centro, raio_atual, 0, TAU, 48, cor_c, 1.8)