extends CanvasLayer

# UI de objetivo — aparece no canto superior esquerdo.
# Mostra "Novo Objetivo" em verde e a descrição do objetivo.
# Some automaticamente após alguns segundos.

const FONT_PATH    = "res://assets/fonts/pixelmix.tres"
const DURACAO      = 6.0    # segundos visível
const ANIM_SPEED   = 8.0    # velocidade do fade in/out
const FADE_TEMPO   = 0.6    # duração do fade

var _timer      : float = 0.0
var _ativo      : bool  = false
var _fase       : String = ""   # "fadein" | "visivel" | "fadeout"

onready var container  = $MarginContainer
onready var label_novo = $MarginContainer/VBoxContainer/LabelNovo
onready var label_desc = $MarginContainer/VBoxContainer/LabelDesc

func _ready() -> void:
	add_to_group("objetivo_ui")
	remove_from_group("Persist")
	container.modulate.a = 0.0
	container.visible    = false

func mostrar_objetivo(descricao: String) -> void:
	# Evita reativar se já está mostrando o mesmo objetivo
	if _ativo and label_desc.text == descricao:
		return
	label_desc.text = descricao
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
