extends Node

var cena_destino = "res://scenes/MainMenu.tscn"
var slot_para_carregar = -1
var rodando_como_menu_bg := false
# Sombra em blackout: lightswitches não religam
var luzes_bloqueadas := false

func carregar_fase(caminho_cena):
	cena_destino = caminho_cena
	get_tree().change_scene("res://scenes/TelaCarregamento.tscn")


# ponytail: os .ogv do repo ainda sao placeholders de 0 byte, e o decoder
# Theora do Godot 3.6 trava dentro de VideoPlayer.play() quando o arquivo
# esta vazio — sem erro, sem sinal "finished", o jogo simplesmente congela.
# Quem for tocar video pergunta aqui antes. Some quando os videos reais entrarem.
func video_tem_conteudo(player) -> bool:
	if player == null or player.stream == null:
		return false
	var arquivo := File.new()
	if arquivo.open(player.stream.resource_path, File.READ) != OK:
		return false
	var tamanho := arquivo.get_len()
	arquivo.close()
	return tamanho > 0
