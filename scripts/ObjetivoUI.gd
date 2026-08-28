extends CanvasLayer

const FONT_PATH    = "res://assets/fonts/MiniPixel/Minipixel-Regular.ttf"
const FONT_SIZE    = 26
const DURACAO      = 6.0
const ANIM_SPEED   = 8.0
const FADE_TEMPO   = 0.6

var _timer      : float = 0.0
var _ativo      : bool  = false
var _fase       : String = ""

onready var container  = $VBoxContainer
onready var label_fala = $VBoxContainer/LabelFala
onready var outline = $MeshInstance

func _ready() -> void:
	add_to_group("objetivo_ui")
	remove_from_group("Persist")
	_aplicar_fonte()
	call_deferred("_tirar_do_viewport")
	container.modulate.a = 0.0
	container.visible    = false
	if outline:
		outline.visible = false

func _aplicar_fonte() -> void:
	var f = DynamicFont.new()
	f.font_data = load(FONT_PATH)
	f.size = FONT_SIZE
	if label_fala:
		label_fala.add_font_override("font", f)

func _tirar_do_viewport() -> void:
	var arvore = get_tree()
	var pai_atual = get_parent()
	if pai_atual:
		pai_atual.remove_child(self)
	arvore.root.add_child(self)

func mostrar_objetivo(fala: String) -> void:
	if _ativo and label_fala.text == fala:
		return
	label_fala.text = fala
	container.visible    = true
	container.modulate.a = 0.0
	_timer  = 0.0
	_fase   = "fadein"
	_ativo  = true
		
func _process(delta: float) -> void:
	if not _ativo:
		return
	_timer += delta
	match _fase:
		"fadein":
			container.modulate.a = min(container.modulate.a + delta / FADE_TEMPO, 1.0)
			if container.modulate.a >= 1.0:
				_fase  = "visivel"
				_timer = 0.0
		"visivel":
			if _timer >= DURACAO:
				_fase  = "fadeout"
				_timer = 0.0
		"fadeout":
			container.modulate.a = max(container.modulate.a - delta / FADE_TEMPO, 0.0)
			if container.modulate.a <= 0.0:
				container.visible = false
				_ativo = false
