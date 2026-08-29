extends StaticBody
export var distancia_abrir : float = 0.5
export var velocidade : float = 4.0
export(NodePath) var item_dentro

var aberta : bool = false
var pos_fechada : Vector3
var pos_aberta : Vector3
var item : Node
var item_offset : Vector3
var item_pego : bool = false

func _ready():
	add_to_group("interagivel")
	pos_fechada = translation
	pos_aberta = translation - transform.basis.y * distancia_abrir
	
	if item_dentro:
		item = get_node(item_dentro)
		if item:
			item_offset = item.global_translation - global_translation
			item_pego = false

func _process(delta):
	var alvo = pos_aberta if aberta else pos_fechada
	translation = translation.linear_interpolate(alvo, velocidade * delta)
	
	# S move o item se ele ainda no foi pego
	if item and is_instance_valid(item) and not item_pego:
		# Se for fita, verifica se j foi coletada
		if item.is_in_group("fita_cassete"):
			if not SaveManager.itens_coletados.has(item.nome_fita if item.has_method("get_nome") else ""):
				item.global_translation = global_translation + item_offset
			else:
				item_pego = true
		else:
			# Para outros itens (como lanterna)
			if not Inventory.has_item("fita_cassete"):   # ajuste conforme necessrio
				item.global_translation = global_translation + item_offset
			else:
				item_pego = true

func interagir(_camera):
	aberta = not aberta

func set_foco(_ativo: bool):
	pass

# Funo para quando o item  pego (chamada pela fita)
func pegar_item(node_item):
	if item == node_item:
		item_pego = true
		item = null
