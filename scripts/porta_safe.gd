extends StaticBody

export var angulo_aberto : float = 90.0          # quanto a portinha abre
export var velocidade_timao : float = 3.0        # velocidade de rotação do timão
export var velocidade_porta : float = 2.0        # velocidade de abertura da porta

onready var pivot_porta = $Box/Door/pivot_porta
onready var timao = $Box/Door/Lock/Lock_Lock_0
onready var colisao_vao = $CollisionShape
onready var colisao_porta = $Box/Door/Door_Door_0/StaticBody/CollisionShape
onready var area = $Box/Door/pivot_porta/Area

var aberto : bool = false
var animando : bool = false
var girando_timao : bool = false
var alvo_timao : float = 0.0
var alvo_porta : float = 0.0

var repouso_timao := 0.0
var giradas_timao : int = 0   # pra fazer ele dar umas voltas antes de abrir

func _ready():
	add_to_group("Persist_estatico")
	add_to_group("Persist")
	add_to_group("interagivel")
	
	repouso_timao = timao.rotation_degrees.y if timao else 0.0
	alvo_timao = repouso_timao
	
	if area:
		area.add_to_group("interagivel")
		area.set_meta("cofre_parent", self)
	
	_atualizar_colisoes()

func interagir(player):
	if animando or aberto:
		return
	
	# Começa a animação do cofre
	girando_timao = true
	animando = true
	giradas_timao += 1
	
	# Gira o timão (ex: 2 voltas completas + um pouco)
	alvo_timao = repouso_timao - 720 + (giradas_timao * 45)  # 2 voltas + variação
	
	_atualizar_colisoes()

# Chamado pela animação do timão
func _process(delta):
	if not animando:
		return
	
	# Girando o timão
	if girando_timao:
		var rot_atual = timao.rotation_degrees.y
		timao.rotation_degrees.y = lerp_angle(rot_atual, alvo_timao, velocidade_timao * delta)
		
		# Quando o timão terminar de girar
		if abs(rot_atual - alvo_timao) < 2.0:
			timao.rotation_degrees.y = alvo_timao
			girando_timao = false
			
			# Agora abre a portinha
			aberto = true
			alvo_porta = angulo_aberto
			_atualizar_colisoes()
	
	# Abrindo a portinha
	if aberto and not girando_timao:
		var rp = pivot_porta.rotation_degrees
		rp.y = lerp_angle(rp.y, alvo_porta, velocidade_porta * delta)   # usa .y porque geralmente cofres abrem pro lado
		pivot_porta.rotation_degrees = rp
		
		if abs(rp.y - alvo_porta) < 1.0:
			pivot_porta.rotation_degrees.y = alvo_porta
			animando = false

func _atualizar_colisoes():
	if colisao_vao:
		colisao_vao.disabled = aberto
	if colisao_porta:
		colisao_porta.disabled = not aberto

# ====================== SAVE / LOAD ======================

func save() -> Dictionary:
	return {
		"tipo_estatico": "cofre",
		"name": name,
		"parent": get_parent().get_path(),
		"pos_x": translation.x,
		"pos_y": translation.y,
		"pos_z": translation.z,
		"aberto": aberto,
		"giradas_timão": giradas_timao
	}

func load_data(data: Dictionary) -> void:
	aberto = data.get("aberto", false)
	giradas_timao = data.get("giradas_timão", 0)
	
	alvo_porta = angulo_aberto if aberto else 0.0
	alvo_timao = repouso_timao - 720 + (giradas_timao * 45)
	
	if timao:
		timao.rotation_degrees.y = alvo_timao
	if pivot_porta:
		pivot_porta.rotation_degrees.y = alvo_porta
	
	_atualizar_colisoes()

# ====================== OUTROS ======================

func set_foco(_ativo: bool):
	pass  # pode adicionar outline no timão depois se quiser

func bater_porta():   # pra compatibilidade com sombra
	pass
