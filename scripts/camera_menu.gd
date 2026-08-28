extends Camera

func _ready():
	add_to_group("camera_menu")

	if not Global.rodando_como_menu_bg:
		queue_free()
		return

	# Garante que fica visível e pronta; o QuartoMenu define current depois
	visible = true
