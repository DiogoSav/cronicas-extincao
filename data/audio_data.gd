class_name AudioData
extends RefCounted
## SONS: eventos sonoros, barramentos e regras de mixagem, lidos por scripts/sfx.gd.
## Spec: design/audio/audio-sonoplastia-geral.md (os números # são os da spec). Arquivos em
## assets/audio/sfx/<id>_<n>.wav, gerados por art_src/audio/gerar_sons.py.
##
## Evento: {files (variações), bus, db (volume relativo), pitch (variação ±, fração),
##          pos (posicional: atenua com a distância à câmera e some na névoa),
##          voices (tocando ao mesmo tempo), prio (1 = nunca cortar, 3 = cortar primeiro),
##          gap (s mínimos entre dois disparos do mesmo evento)}

const DIR := "res://assets/audio/sfx/"

## Barramentos: [nome, envia para, volume dB]. Combate e Ambiente passam por Efeitos.
const BUSES := [
	["Musica", "Master", -6.0],
	["Efeitos", "Master", 0.0],
	["Combate", "Efeitos", -2.0],
	["Ambiente", "Efeitos", -4.0],
	["Interface", "Master", -2.0],
	["Vozes", "Master", 0.0],
]

## Teto de sons tocando ao mesmo tempo (a Web tem menos)
const MAX_VOICES := 32
const MAX_VOICES_WEB := 24
## Atenuação posicional, em múltiplos da distância da câmera (RTSCamera.dist, em células):
## volume cheio até NEAR, cai até FAR_DB em FAR e some depois.
const NEAR := 0.9
const FAR := 2.2
const FAR_DB := -24.0

const EVENTS := {
	# 3.1 armas e impactos
	"sfx_weapon_rifle_fire": {"files": 3, "bus": "Combate", "db": -8.0, "pitch": 0.06, "pos": true, "voices": 8, "prio": 2, "gap": 0.04},
	"sfx_weapon_smg_fire": {"files": 3, "bus": "Combate", "db": -10.0, "pitch": 0.08, "pos": true, "voices": 6, "prio": 3, "gap": 0.04},
	"sfx_weapon_mg_fire": {"files": 3, "bus": "Combate", "db": -9.0, "pitch": 0.08, "pos": true, "voices": 6, "prio": 3, "gap": 0.04},
	"sfx_weapon_sniper_fire": {"files": 2, "bus": "Combate", "db": -4.0, "pitch": 0.03, "pos": true, "voices": 3, "prio": 2, "gap": 0.04},
	"sfx_weapon_at_fire": {"files": 2, "bus": "Combate", "db": -5.0, "pitch": 0.04, "pos": true, "voices": 4, "prio": 2, "gap": 0.04},
	"sfx_weapon_cannon_fire": {"files": 2, "bus": "Combate", "db": -2.0, "pitch": 0.04, "pos": true, "voices": 4, "prio": 1, "gap": 0.04},
	"sfx_weapon_missile_launch": {"files": 2, "bus": "Combate", "db": -4.0, "pitch": 0.05, "pos": true, "voices": 4, "prio": 2, "gap": 0.04},
	"sfx_weapon_legion_pulse_fire": {"files": 3, "bus": "Combate", "db": -8.0, "pitch": 0.06, "pos": true, "voices": 6, "prio": 2, "gap": 0.04},
	"sfx_weapon_acid_spit_fire": {"files": 3, "bus": "Combate", "db": -10.0, "pitch": 0.08, "pos": true, "voices": 6, "prio": 3, "gap": 0.04},
	"sfx_impact_beam": {"files": 3, "bus": "Combate", "db": -12.0, "pitch": 0.08, "pos": true, "voices": 6, "prio": 3, "gap": 0.03},
	"sfx_impact_at": {"files": 2, "bus": "Combate", "db": -5.0, "pitch": 0.05, "pos": true, "voices": 3, "prio": 2, "gap": 0.03},
	"sfx_impact_cannon": {"files": 2, "bus": "Combate", "db": -3.0, "pitch": 0.05, "pos": true, "voices": 3, "prio": 1, "gap": 0.03},
	"sfx_impact_missile": {"files": 2, "bus": "Combate", "db": -4.0, "pitch": 0.05, "pos": true, "voices": 4, "prio": 2, "gap": 0.03},
	"sfx_impact_acid": {"files": 2, "bus": "Combate", "db": -12.0, "pitch": 0.08, "pos": true, "voices": 4, "prio": 3, "gap": 0.03},
	# 3.2 mortes e explosões
	"sfx_death_infantry_human": {"files": 3, "bus": "Combate", "db": -10.0, "pitch": 0.10, "pos": true, "voices": 4, "prio": 3, "gap": 0.05},
	"sfx_death_infantry_explode": {"files": 2, "bus": "Combate", "db": -6.0, "pitch": 0.08, "pos": true, "voices": 3, "prio": 2, "gap": 0.05},
	"sfx_death_robot": {"files": 3, "bus": "Combate", "db": -6.0, "pitch": 0.08, "pos": true, "voices": 4, "prio": 2, "gap": 0.05},
	"sfx_death_insect": {"files": 3, "bus": "Combate", "db": -11.0, "pitch": 0.12, "pos": true, "voices": 5, "prio": 3, "gap": 0.05},
	"sfx_explosion_vehicle": {"files": 3, "bus": "Combate", "db": -4.0, "pitch": 0.06, "pos": true, "voices": 3, "prio": 2, "gap": 0.05},
	"sfx_explosion_building_small": {"files": 2, "bus": "Combate", "db": -3.0, "pitch": 0.05, "pos": true, "voices": 2, "prio": 2, "gap": 0.1},
	"sfx_explosion_building_large": {"files": 2, "bus": "Combate", "db": 0.0, "pitch": 0.03, "pos": false, "voices": 1, "prio": 1, "gap": 0.1},
	"sfx_explosion_organic_burst": {"files": 2, "bus": "Combate", "db": -4.0, "pitch": 0.06, "pos": true, "voices": 2, "prio": 2, "gap": 0.1},
	# 3.7 alertas (stinger por facção, sem voz por enquanto: o texto vem na tela)
	"sfx_alert_base_attack_sting_hum": {"files": 1, "bus": "Vozes", "db": -4.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 1, "gap": 1.0},
	"sfx_alert_base_attack_sting_rob": {"files": 1, "bus": "Vozes", "db": -4.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 1, "gap": 1.0},
	"sfx_alert_base_attack_sting_ins": {"files": 1, "bus": "Vozes", "db": -4.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 1, "gap": 1.0},
	"sfx_alert_low_power_pulse": {"files": 1, "bus": "Vozes", "db": -8.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 2, "gap": 1.0},
	# 3.9 interface
	"sfx_ui_click": {"files": 3, "bus": "Interface", "db": -10.0, "pitch": 0.03, "pos": false, "voices": 2, "prio": 2, "gap": 0.02},
	"sfx_ui_hover": {"files": 2, "bus": "Interface", "db": -20.0, "pitch": 0.03, "pos": false, "voices": 1, "prio": 3, "gap": 0.05},
	"sfx_ui_back": {"files": 1, "bus": "Interface", "db": -12.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 3, "gap": 0.02},
	"sfx_ui_error": {"files": 1, "bus": "Interface", "db": -10.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 2, "gap": 0.25},
	"sfx_ui_selection_confirm": {"files": 3, "bus": "Interface", "db": -16.0, "pitch": 0.04, "pos": false, "voices": 1, "prio": 3, "gap": 0.05},
	"sfx_ui_order_move_marker": {"files": 1, "bus": "Interface", "db": -14.0, "pitch": 0.04, "pos": false, "voices": 1, "prio": 3, "gap": 0.05},
	"sfx_ui_order_attack_marker": {"files": 1, "bus": "Interface", "db": -12.0, "pitch": 0.04, "pos": false, "voices": 1, "prio": 3, "gap": 0.05},
	"sfx_ui_build_queue_add": {"files": 1, "bus": "Interface", "db": -10.0, "pitch": 0.03, "pos": false, "voices": 1, "prio": 2, "gap": 0.03},
	"sfx_ui_build_queue_cancel": {"files": 1, "bus": "Interface", "db": -12.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 3, "gap": 0.03},
	"sfx_ui_place_ok": {"files": 1, "bus": "Interface", "db": -8.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 2, "gap": 0.05},
	"sfx_ui_place_invalid": {"files": 1, "bus": "Interface", "db": -10.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 2, "gap": 0.2},
	"sfx_ui_message_pop": {"files": 1, "bus": "Interface", "db": -16.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 3, "gap": 0.15},
	"sfx_ui_countdown_tick": {"files": 1, "bus": "Interface", "db": -8.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 1, "gap": 0.2},
	"sfx_ui_countdown_go": {"files": 1, "bus": "Interface", "db": -6.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 1, "gap": 0.2},
	"sfx_ui_minimap_ping": {"files": 1, "bus": "Interface", "db": -10.0, "pitch": 0.0, "pos": false, "voices": 1, "prio": 2, "gap": 0.5},
}

## Arma de cada facção: tipos que trocam de som conforme a raça de quem atira.
const FACTION_WEAPON := {
	"rob": {"rifle": "sfx_weapon_legion_pulse_fire", "smg": "sfx_weapon_legion_pulse_fire", "mg": "sfx_weapon_legion_pulse_fire"},
	"ins": {"rifle": "sfx_weapon_acid_spit_fire", "smg": "sfx_weapon_acid_spit_fire", "mg": "sfx_weapon_acid_spit_fire"},
}
const WEAPON := {
	"rifle": "sfx_weapon_rifle_fire", "smg": "sfx_weapon_smg_fire", "mg": "sfx_weapon_mg_fire",
	"sniper": "sfx_weapon_sniper_fire", "at": "sfx_weapon_at_fire", "cannon": "sfx_weapon_cannon_fire",
	"missile": "sfx_weapon_missile_launch",
}
const IMPACT := {"at": "sfx_impact_at", "cannon": "sfx_impact_cannon", "missile": "sfx_impact_missile"}

## Avisos visuais de acessibilidade (spec seção 5): intervalo mínimo entre repetições (s).
const HARVESTER_ALERT_COOLDOWN := 15.0
const LOW_POWER_REPEAT := 30.0
## Pisca no minimapa: duração (s)
const PING_TIME := 4.0
