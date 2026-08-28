extends Control
onready var video_loading := $VideoPlayer
var loader = null
var carregando = false
var caminho_atual = ""

func _ready():
	_limpar_ui_orfan()
	video_loading.connect("finished", self, "_on_video_loading_finished")
	video_loading.visible = true
	video_loading.play()
	_iniciar_load(Global.cena_destino)

func _limpar_ui_orfan() -> void:
	for n in get_tree().get_nodes_in_group("ui_persistente"):
		if is_instance_valid(n) and n.get_parent() == get_tree().root:
			n.queue_free()
	for n in get_tree().get_nodes_in_group("reparentar_hud"):
		if is_instance_valid(n) and n.get_parent() == get_tree().root:
			n.queue_free()

func _on_video_loading_finished():
	if carregando:
		video_loading.play()

func _iniciar_load(caminho):
	caminho_atual = caminho
	carregando = true
	loader = ResourceLoader.load_interactive(caminho)
	set_process(true)

func _process(delta):
	if loader == null:
		return
	var err = loader.poll()
	if err == ERR_FILE_EOF:
		loader = null
		carregando = false
		if video_loading.is_playing():
			video_loading.stop()

		if Global.slot_para_carregar >= 0:  # ajusta a condição pro seu valor "nenhum slot"
			SaveManager.carregar_dados(Global.slot_para_carregar)
		else:
			SaveManager.iniciar_novo_jogo()
			get_tree().change_scene_to(ResourceLoader.load(caminho_atual))
	elif err != OK:
		push_error("Erro ao carregar: " + caminho_atual)
		loader = null
		carregando = false
