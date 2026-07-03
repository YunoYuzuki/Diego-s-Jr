extends StaticBody3D

# ==================== CONFIGURAES ====================
export var angulo_aberta : float = -110.0     # ngulo que abre (negativo = esquerda)
export var velocidade : float = 5.0           # Velocidade da animao

# ==================== REFERNCIAS ====================
onready var pivot = $pivot_porta

# ==================== VARIVEIS ====================
var aberta : bool = false
var rot_fechada : float = 0.0
var rot_aberta : float = 0.0
var em_foco : bool = false

func _ready():
	add_to_group("interagivel")
	
	if pivot == null:
		push_error("ERRO: N 'pivot_porta' no encontrado na porta!")
		return
	
	rot_fechada = pivot.rotation_degrees.z
	rot_aberta = rot_fechada + angulo_aberta

func interagir(_player):
	aberta = not aberta

func _process(delta):
	if pivot == null:
		return
	
	var alvo = rot_aberta if aberta else rot_fechada
	var rot = pivot.rotation_degrees
	rot.z = lerp(rot.z, alvo, velocidade * delta)
	pivot.rotation_degrees = rot

# ==================== SISTEMA DE FOCO (CROSSHAIR) ====================
func set_foco(_ativo: bool):
	pass