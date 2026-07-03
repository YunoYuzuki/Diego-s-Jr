extends StaticBody

onready var label_prompt = $CanvasLayer/Label

func _ready():
	add_to_group("interagivel")
	if label_prompt:
		label_prompt.visible = false
		label_prompt.text = "Salvar [E]"

func set_foco(ativo: bool):
	if label_prompt:
		label_prompt.visible = ativo

func interagir(_camera):
	SaveManager.save_game(SaveManager.current_slot)
