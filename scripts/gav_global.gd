extends StaticBody

export var distancia_abrir : float = 0.5
export var velocidade : float = 4.0
export(NodePath) var item_dentro
export(AudioStream) var som_gaveta

var aberta : bool = false
var pos_fechada : Vector3
var pos_aberta : Vector3
var item : Node
var item_offset : Vector3
var item_pego : bool = false
var audio_player : AudioStreamPlayer3D

func _ready():
	add_to_group("interagivel")
	pos_fechada = translation
	pos_aberta = translation - transform.basis.y * distancia_abrir

	audio_player = AudioStreamPlayer3D.new()
	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	audio_player.unit_db = 10.0
	audio_player.unit_size = 10.0
	audio_player.max_distance = 40.0
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(audio_player)
	if som_gaveta:
		audio_player.stream = som_gaveta

	if item_dentro:
		item = get_node(item_dentro)
		if item:
			item_offset = item.global_translation - global_translation
			item_pego = false

func _process(delta):
	var alvo = pos_aberta if aberta else pos_fechada
	translation = translation.linear_interpolate(alvo, velocidade * delta)

	_atualizar_item_dentro()

func _atualizar_item_dentro() -> void:
	if item_pego:
		return

	# Item sumiu do mundo (queue_free) → para de seguir
	if item == null or not is_instance_valid(item):
		item_pego = true
		item = null
		return

	# Fita já coletada
	if item.is_in_group("fita_cassete"):
		var nome = ""
		if "nome_fita" in item:
			nome = item.nome_fita
		if nome != "" and SaveManager.itens_coletados.has(nome):
			item_pego = true
			item = null
			return

	# Lanterna já equipada / no inventário
	if item.is_in_group("lanterna"):
		if ("equipada" in item and item.equipada) or Inventory.has_item("lanterna"):
			item_pego = true
			item = null
			return

	# Ainda está na gaveta → acompanha o movimento
	item.global_translation = global_translation + item_offset

func interagir(_camera):
	aberta = not aberta
	if audio_player and audio_player.stream:
		audio_player.play()

func set_foco(_ativo: bool):
	pass

# Chamado pelo item quando o jogador pega (fita / lanterna)
func pegar_item(node_item):
	if item == node_item:
		item_pego = true
		item = null
