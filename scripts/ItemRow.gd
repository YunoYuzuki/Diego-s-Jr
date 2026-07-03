extends HBoxContainer

onready var nome_label = $NomeLabel
onready var dot_label  = $DotLabel

func setup(item_id: String):
	nome_label.text      = Inventory.get_item_name(item_id)
	nome_label.modulate.a = 0.0  # comea invisvel

func set_aberto(aberto: bool, delta: float, velocidade: float):
	nome_label.modulate.a = lerp(nome_label.modulate.a,
		1.0 if aberto else 0.0, velocidade * delta)
