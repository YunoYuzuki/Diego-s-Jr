extends StaticBody
export(String) var nome_fita = "Fita 02 - Diario"
export(String) var fita_anterior = "Fita 01 - Primeiro Contato" 
export(AudioStreamMP3) var audio_fita
onready var outline_mesh = $cassette/OutlineMesh
onready var colisao = $CollisionShape

func _ready():
	add_to_group("interagivel")
	add_to_group("fita_cassete")
	add_to_group("Persist_estatico")
	
	if outline_mesh:
		outline_mesh.visible = false
	
	if SaveManager.itens_coletados.has(nome_fita):
		queue_free()
		return
	
	if fita_anterior != "" and not SaveManager.itens_coletados.has(fita_anterior):
		hide()
		colisao.disabled = true
		set_process(true) 
		return

func _process(_delta):
	if fita_anterior == "" or SaveManager.itens_coletados.has(fita_anterior):
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
		print("Fita coletada: ", nome_fita)
	
	if get_parent() and get_parent().has_method("pegar_item"):
		get_parent().pegar_item(self)
	
	player.pegar_fita(self)
	queue_free()

func save() -> Dictionary:
	return {
		"tipo_estatico": "fita_cassete",
		"name": name,
		"parent": get_parent().get_path(),
		"pos_x": translation.x,
		"pos_y": translation.y,
		"pos_z": translation.z,
		"nome_fita": nome_fita
	}

func load_data(_data: Dictionary) -> void:
	print("load_data da fita ", nome_fita, " - lista tem ela? ", SaveManager.itens_coletados.has(nome_fita))
	if SaveManager.itens_coletados.has(nome_fita):
		print(" Removendo fita ", nome_fita, " no load_data")
		queue_free()
