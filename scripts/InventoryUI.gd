extends CanvasLayer

const MAX_VISIBLE = 5
const ANIM_SPEED = 10.0
var is_open: bool = false
onready var container = $VBoxContainer

func _ready():
	var tela_x = get_viewport().size.x
	var tela_y = ProjectSettings.get_setting("display/window/size/height")
	container.rect_position = Vector2(tela_x, tela_y / 2.0 - 60)
	
	Inventory.connect("item_added",   self, "_refresh")
	Inventory.connect("item_removed", self, "_refresh")
	_refresh()

func _input(event):
	if event.is_action_pressed("inventory_toggle"):
		is_open = !is_open

func _process(delta):
	var tela_x = get_viewport().size.x
	var target_x = tela_x - 220.0 if is_open else tela_x - 20.0
	container.rect_position.x = lerp(container.rect_position.x, target_x, ANIM_SPEED * delta)

func _refresh(_item_id = null):
	for child in container.get_children():
		child.queue_free()
	for item_id in Inventory.items.slice(0, MAX_VISIBLE - 1):
		var row = HBoxContainer.new()
		row.rect_min_size = Vector2(200, 28)
		
		var dot = Label.new()
		dot.text = ". "
		dot.add_font_override("font", preload("res://assets/fonts/KiwiSoda.tres"))
		row.add_child(dot)
		
		var nome = Label.new()
		nome.text = Inventory.get_item_name(item_id)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.add_font_override("font", preload("res://assets/fonts/pixelmix.tres"))
		row.add_child(nome)
		
		container.add_child(row)
