extends StaticBody

var save_ui_scene = preload("res://scenes/SaveUI.tscn")
onready var outline = $telephone/outline

func _ready():
	add_to_group("interagivel")
	if outline:
		outline.visible = false

func set_foco(ativo: bool):
	pass
	if outline:
		outline.visible = ativo

func pode_interagir(player) -> bool:
	return true

func interagir(player):
	var ui = save_ui_scene.instance()
	get_tree().get_root().add_child(ui)
	ui.open()
