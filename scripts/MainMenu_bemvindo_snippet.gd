# --- Cole no MainMenu.gd ---
# Crie um Label no MainMenu chamado LabelBemVindo (canto da tela).
# No _ready() do MainMenu chame: _atualizar_bemvindo()

const CONTA_CFG := "user://limbo_conta.cfg"

func _atualizar_bemvindo() -> void:
	var label = get_node_or_null("LabelBemVindo")
	if label == null:
		return
	var cfg := ConfigFile.new()
	if cfg.load(CONTA_CFG) != OK:
		label.text = ""
		return
	var token_ok := false
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("get_web_token"):
		token_ok = SaveManager.get_web_token() != ""
	if not token_ok:
		label.text = ""
		return
	var nick := str(cfg.get_value("conta", "nickname", ""))
	if nick == "":
		nick = str(cfg.get_value("conta", "username", ""))
	if nick == "":
		label.text = ""
	else:
		label.text = "Bem-vindo, %s" % nick
