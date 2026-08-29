extends OmniLight

export(float, 0.0, 100.0) var chance_de_piscar := 10.0  # % de chance
export(String) var palavra_morse := ""  # só use letras curtas: E T I A N M S O
export(float) var unidade_morse := 0.15    # duração base do ponto (traço = 3x isso)

var piscando := false
var timer : Timer

var _codigos_morse := {
	"E": ".", "T": "-", "I": "..", "A": ".-",
	"N": "-.", "M": "--", "S": "...", "O": "---"
}

var _sequencia := []
var _indice := 0

func _ready() -> void:
	timer = Timer.new()
	timer.one_shot = true
	timer.connect("timeout", self, "_proximo_passo")
	add_child(timer)

	_sequencia = _gerar_sequencia(palavra_morse)

	# Detecta quando a luz é ligada/desligada
	connect("visibility_changed", self, "_on_visibility_changed")

	# Caso já comece ligada
	if visible:
		_on_visibility_changed()

func _gerar_sequencia(palavra: String) -> Array:
	var seq = []
	for letra in palavra:
		var codigo = _codigos_morse.get(letra, "")
		for simbolo in codigo:
			var duracao = unidade_morse if simbolo == "." else unidade_morse * 3.0
			seq.append({"on": true, "dur": duracao})
			seq.append({"on": false, "dur": unidade_morse}) # espaço entre símbolos
		if seq.size() > 0:
			seq[seq.size() - 1]["dur"] = unidade_morse * 3.0 # espaço entre letras
	return seq

func _on_visibility_changed() -> void:
	if visible:
		tentar_iniciar_piscar()
	else:
		parar_piscar()

func tentar_iniciar_piscar() -> void:
	if rand_range(0, 100) < chance_de_piscar:
		piscando = true
		_indice = 0
		print("💡 ", name, " piscando em Morse: ", palavra_morse)
		_proximo_passo()
	else:
		piscando = false
		light_energy = 1.0

func _proximo_passo() -> void:
	if not piscando or not visible or _sequencia.empty():
		return

	var passo = _sequencia[_indice]
	light_energy = 1.0 if passo["on"] else 0.0

	_indice = (_indice + 1) % _sequencia.size()
	timer.wait_time = passo["dur"]
	timer.start()

func parar_piscar() -> void:
	piscando = false
	if timer:
		timer.stop()
	light_energy = 1.0 # garante que volte ao normal

# Caso queira forçar manualmente
func forcar_piscar() -> void:
	piscando = true
	_indice = 0
	_proximo_passo()
