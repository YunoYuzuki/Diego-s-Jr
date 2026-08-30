extends StaticBody
export(String) var nome_fita = ""
export(String) var fita_anterior = "" 
export(AudioStreamMP3) var audio_fita

# Texto e cor da legenda dessa fita específica.
export(String, MULTILINE) var texto_legenda = ""
export(Color) var cor_legenda = Color(1, 1, 1, 1)

onready var outline_mesh = $cassette/OutlineMesh
onready var colisao = $CollisionShape
func _ready():
	add_to_group("interagivel")
	add_to_group("fita_cassete")
	add_to_group("cassette_music")
	add_to_group("Persist")
	add_to_group("Persist_estatico")
	
	if outline_mesh:
		outline_mesh.visible = false
	
	# Se a fita já está na lista global de coletadas, deleta ela do mundo imediatamente
	if SaveManager.itens_coletados.has(nome_fita):
		queue_free()
		return
	
	# Só aparece no mapa depois que a fita anterior TERMINOU de tocar
	if fita_anterior != "" and not _fita_anterior_ja_tocou():
		hide()
		colisao.disabled = true
		set_process(true) 
		return
		
func _fita_anterior_ja_tocou() -> bool:
	if fita_anterior == "":
		return true
	if typeof(SaveManager) == TYPE_NIL:
		return false
	if "fitas_reproduzidas" in SaveManager:
		var fr = SaveManager.fitas_reproduzidas
		if fr is Dictionary and fr.has(fita_anterior) and fr[fita_anterior]:
			return true
		if fr is Array and fr.has(fita_anterior):
			return true
	return false

func _process(_delta):
	if fita_anterior == "" or _fita_anterior_ja_tocou():
		show()
		colisao.disabled = false
		set_process(false)
		
func set_foco(ativo):
	if outline_mesh:
		outline_mesh.visible = ativo
		
func interagir(player):
	if Inventory.has_item("fita_cassete"):
		return
	
	if not SaveManager.itens_coletados.has(nome_fita):
		SaveManager.itens_coletados.append(nome_fita)
	
	if get_parent() and get_parent().has_method("pegar_item"):
		get_parent().pegar_item(self)
	
	player.pegar_fita(self)
	TelaPickup.mostrar_item("Fita Cassete", "Uma fita cassete meio esquisita... tem uma etiqueta nela, mas não consigo ler. Pertence a alguém chamada Laura. Talvez tenha algum lugar para tocar isso por aqui.", preload("res://assets/scenes_pickup/Cassette.obj.tscn"))
	queue_free()
	
# SALVA O ESTADO SEM DEPENDER DE ESTAR NA CENA
func save() -> Dictionary:
	return {
		"node_path": str(get_path()),
		"nome_fita": nome_fita,
		"coletada": SaveManager.itens_coletados.has(nome_fita)
	}
	
func load_data(data: Dictionary) -> void:
	var coletada = data.get("coletada", false)
	if coletada:
		queue_free()
