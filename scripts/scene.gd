extends StaticBody

var save_ui_scene = preload("res://scenes/SaveUI.tscn")

func _ready():
	add_to_group("interagivel")

func set_foco(ativo: bool):
	pass

func pode_interagir(player) -> bool:
	return true

func interagir(player):
	var ui = save_ui_scene.instance()
	get_tree().get_root().add_child(ui)
	ui.open()
