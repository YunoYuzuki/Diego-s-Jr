extends Node

# Cenas onde o pause NUNCA deve funcionar
const CENAS_SEM_PAUSE := [
	"res://scenes/MainMenu.tscn",
	"res://scenes/TelaInicial.tscn",
	"res://scenes/TelaCarregamento.tscn",
	"res://scenes/config.tscn",
	"res://scenes/CenaNarrativa.tscn",
]

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS

func _pode_pausar() -> bool:
	# Fundo 3D do menu principal — nunca pausar
	if typeof(Global) != TYPE_NIL and Global.rodando_como_menu_bg:
		return false

	var cena = get_tree().current_scene
	if cena == null:
		return false

	var path := ""
	if "filename" in cena and cena.filename != "":
		path = cena.filename
	elif cena.get_filename() != "":
		path = cena.get_filename()

	# Lista explícita de telas de menu / intro / loading
	if path in CENAS_SEM_PAUSE:
		return false

	# Só permite pause na cena de jogo de verdade
	if typeof(SaveManager) != TYPE_NIL and "CENA_JOGO" in SaveManager:
		if path != "" and path != SaveManager.CENA_JOGO:
			return false

	return true


func _cartas_ui_aberta() -> bool:
	# Autoload CartasUI — usa get() (seguro no Godot 3; "x" in obj quebra com null)
	if typeof(CartasUI) != TYPE_NIL and is_instance_valid(CartasUI):
		if CartasUI.get("esta_aberta") == true:
			return true
		if CartasUI.has_method("get_painel_visivel") and CartasUI.get_painel_visivel():
			return true
	# Qualquer nó do grupo
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("cartas_ui"):
		if is_instance_valid(n) and n.get("esta_aberta") == true:
			return true
	for n in get_tree().get_nodes_in_group("cartas_inventory_ui"):
		if is_instance_valid(n) and n.get("esta_aberta") == true:
			return true
	for n in get_tree().get_nodes_in_group("ui_bloqueia_pause"):
		if is_instance_valid(n) and n.get("esta_aberta") == true:
			return true
	return false


func _input(event) -> void:
	if not event.is_action_pressed("esc") or event.echo:
		return

	var camera = get_tree().get_nodes_in_group("camera_player")

	# Se estiver inspecionando um objeto, o ESC só fecha a inspeção
	if camera.size() > 0 and camera[0].inspecionando:
		camera[0].finalizar_inspecao()
		get_tree().set_input_as_handled()
		return

	var save_uis = get_tree().get_nodes_in_group("save_ui")
	if save_uis.size() > 0:
		save_uis[0].close()
		get_tree().set_input_as_handled()
		return

	# Se o config estiver aberto, é ele quem cuida do ESC (ui_cancel) sozinho
	var configs = get_tree().get_nodes_in_group("config_screen")
	if configs.size() > 0:
		get_tree().set_input_as_handled()
		return

	# Se a tela de pickup de item estiver aberta, é ela quem cuida do ESC sozinha
	if typeof(TelaPickup) != TYPE_NIL and TelaPickup.painel.visible:
		get_tree().set_input_as_handled()
		return

	# CartasUI aberta: ESC NÃO pausa — a própria UI fecha com qualquer tecla
	# (incluindo ESC). Só engole o input pra não abrir o pause.
	if _cartas_ui_aberta():
		get_tree().set_input_as_handled()
		return

	# Bloqueia pause em menu, intro, loading, fundo do menu, etc.
	if not _pode_pausar():
		get_tree().set_input_as_handled()
		return

	if camera.size() > 0:
		if get_tree().paused:
			camera[0].unpause_game()
		else:
			camera[0].pause_game()
		get_tree().set_input_as_handled()
