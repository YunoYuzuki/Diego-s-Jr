extends CanvasLayer

onready var label_pct = $Label  # ajuste o caminho

func _process(_delta):
	if typeof(Global) != TYPE_NIL and Global.rodando_como_menu_bg:
		visible = false
		return

	var cams = get_tree().get_nodes_in_group("camera_player")
	if cams.empty() or cams[0].lanterna_atual == null:
		visible = false
		return

	var lanterna = cams[0].lanterna_atual
	if not lanterna.has_method("get_bateria_pct"):
		visible = false
		return

	visible = true
	var pct = int(round(lanterna.get_bateria_pct() * 100.0))
	label_pct.text = "%d%%" % pct
