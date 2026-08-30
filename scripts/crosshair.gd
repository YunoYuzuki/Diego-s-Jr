extends Control

export var cor_normal : Color = Color(1, 1, 1, 0.9)
export var cor_foco   : Color = Color(1, 1, 1, 1.0)

var raio_atual    : float = 0.0
var raio_alvo     : float = 0.0
var alpha_circulo : float = 0.0

const RAIO_CIRCULO : float = 12.0
const RAIO_PONTO   : float = 1.4   # era 2.5 ("bola") — agora é um ponto de verdade
const VEL_ANIM     : float = 6.0

# Shader que inverte a cor da tela exatamente onde a crosshair é desenhada
# (o que tá branco atrás dela fica preto, o que tá preto fica branco, etc).
# Só a cor entra no shader — o alpha desenhado em _draw() continua
# controlando o formato (ponto ou anel), então as cores exportadas acima
# (cor_normal/cor_foco) só importam pelo canal alpha delas agora.
const SHADER_INVERTE := """
shader_type canvas_item;

void fragment() {
	vec4 tela = texture(SCREEN_TEXTURE, SCREEN_UV);
	COLOR.rgb = vec3(1.0) - tela.rgb;
}
"""

# Cenas onde a crosshair NUNCA deve aparecer
const CENAS_SEM_CROSSHAIR := [
	"res://scenes/MainMenu.tscn",
	"res://scenes/TelaInicial.tscn",
	"res://scenes/TelaCarregamento.tscn",
	"res://scenes/config.tscn",
	"res://scenes/CenaNarrativa.tscn",
]

func _ready():
	# Não entra em ui_persistente sozinha — o HUD pai já cuida disso.
	# Evita cópias "órfãs" da crosshair na raiz após troca de cena.
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

	var shader := Shader.new()
	shader.code = SHADER_INVERTE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	material = mat

	_atualizar_visibilidade()

func _process(delta):
	_atualizar_visibilidade()
	if not visible:
		return
	raio_atual    = lerp(raio_atual,    raio_alvo,                VEL_ANIM * delta)
	alpha_circulo = lerp(alpha_circulo, raio_alvo / RAIO_CIRCULO, VEL_ANIM * delta)
	update()

func set_foco(ativo: bool):
	if not _pode_mostrar():
		raio_alvo = 0.0
		return
	raio_alvo = RAIO_CIRCULO if ativo else 0.0

func _pode_mostrar() -> bool:
	# Fundo 3D do menu
	if typeof(Global) != TYPE_NIL and Global.rodando_como_menu_bg:
		return false

	# Sem câmera de gameplay ativa
	var cams = get_tree().get_nodes_in_group("camera_player")
	if cams.empty():
		return false

	# Cenas de menu / intro / loading / narrativa
	var cena = get_tree().current_scene
	if cena == null:
		return false
	var path := ""
	if "filename" in cena and cena.filename != "":
		path = cena.filename
	elif cena.has_method("get_filename") and cena.get_filename() != "":
		path = cena.get_filename()
	if path in CENAS_SEM_CROSSHAIR:
		return false

	return true

func _atualizar_visibilidade() -> void:
	var ok = _pode_mostrar()
	if visible != ok:
		visible = ok
	if not ok:
		raio_alvo = 0.0
		raio_atual = 0.0
		alpha_circulo = 0.0

func _draw():
	if not visible:
		return
	var centro = Vector2(50.0, 50.0)

	# Ponto central só quando NÃO está em foco.
	# Assim some de verdade dentro do círculo de interação.
	if alpha_circulo < 0.2:
		var t = 1.0 - (alpha_circulo / 0.2)
		var raio_ponto = RAIO_PONTO * t
		if raio_ponto > 0.15:
			var cor_p = cor_normal
			cor_p.a = cor_normal.a * t
			draw_circle(centro, raio_ponto, cor_p)

	if alpha_circulo > 0.01:
		var cor_c = cor_foco
		cor_c.a   = alpha_circulo
		draw_arc(centro, raio_atual, 0, TAU, 48, cor_c, 1.8)
