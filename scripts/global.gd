extends Node

var cena_destino = "res://scenes/MainMenu.tscn"
var slot_para_carregar = -1
var rodando_como_menu_bg := false
# Sombra em blackout: lightswitches não religam
var luzes_bloqueadas := false

func carregar_fase(caminho_cena):
	cena_destino = caminho_cena
	get_tree().change_scene("res://scenes/TelaCarregamento.tscn")
