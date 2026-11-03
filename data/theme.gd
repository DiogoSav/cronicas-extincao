class_name GameTheme
extends RefCounted
## TEMA DO JOGO: nome, textos, cores da interface, terreno, cenário e vitrine do menu.
## Junto com data/game_data.gd é tudo o que muda de um jogo para outro (fora os modelos).

## Nome do jogo (menu e barra lateral) e subtítulo do menu
const TITLE := "CRÔNICAS DA EXTINÇÃO"
const SUBTITLE := "Império da Cinza  ×  Legião Sintética  ×  Enxame Abissal"

## Dinheiro e recurso coletado (aparecem no HUD, nas mensagens e no painel de seleção)
const CURRENCY := "Recursos"
const RESOURCE := "minério"
## Modelo instanciado nos campos de recurso (encolhe conforme é extraído)
const RESOURCE_MODEL := "ore_crystal"

## Interface: metal escuro, bordas vermelho-ferrugem e destaque em brasa
const ACCENT := Color(1.0, 0.42, 0.22)
const TEXT := Color(0.88, 0.84, 0.8)
const BORDER := Color(0.42, 0.12, 0.08)
const PANEL := Color(0.055, 0.045, 0.045, 0.94)

## Terreno (shader procedural): planeta devastado de rocha, cinza e terra queimada;
## o minério é cristal azul, reconhecível em qualquer mapa
const GROUND_DARK := Color(0.075, 0.07, 0.065)
const GROUND_MID := Color(0.27, 0.23, 0.17)
const GROUND_LIGHT := Color(0.42, 0.38, 0.3)
const RESOURCE_GROUND := Color(0.1, 0.18, 0.3)
const RESOURCE_GLOW := Color(0.2, 0.6, 1.0)
## Minimapa: chão, obstáculos, recurso
const MINIMAP_GROUND := Color(0.22, 0.19, 0.15)
const MINIMAP_ROCK := Color(0.08, 0.075, 0.07)
const MINIMAP_RESOURCE := Color(0.3, 0.65, 1.0)

## Cenário nas células intransponíveis: [modelo, peso do sorteio]
const PROPS := [
	["prop_rock_a", 4], ["prop_rock_b", 4], ["prop_rock_c", 3], ["prop_spire_a", 2],
	["prop_spire_b", 1], ["prop_plant", 2], ["prop_deadtree", 2], ["prop_ruin", 2],
	["prop_wreck", 1], ["prop_debris", 1], ["prop_crystal", 1],
]

## Nomes dos tipos de arma no painel de seleção
const WEAPON_NAMES := {"rifle": "fuzil laser", "smg": "curto alcance", "mg": "fogo rápido",
		"sniper": "precisão", "at": "antiblindagem", "cannon": "canhão pesado", "missile": "mísseis"}

## Menu: três modelos em destaque na tela de título e as naves que cruzam o fundo
## [modelo, posição inicial, velocidade, escala]
const MENU_SHOWCASE := ["hum_tanque", "rob_heavy", "ins_heavy"]
const MENU_FLYBY := [
	["hum_cruzador", Vector3(-9, 1.6, -3.0), 0.45, 1.6],
	["hum_caca", Vector3(-6, 2.3, -2.0), 1.6, 1.4],
	["hum_caca", Vector3(-6.8, 2.0, -1.4), 1.6, 1.4],
	["rob_gunship", Vector3(-14, 0.4, -5.0), 0.4, 1.8],
	["rob_fighter", Vector3(-3, 3.0, -4.0), 1.2, 1.4],
	["ins_gunship", Vector3(-20, 2.4, -7.0), 0.5, 2.2],
	["ins_fighter", Vector3(-11, 1.0, 0.5), 1.9, 1.2],
	["ins_fighter", Vector3(-12, 1.3, 1.0), 1.9, 1.2],
]
