class_name CampaignData
extends RefCounted
## CAMPANHAS: missões com mapa próprio, bases e unidades iniciais, objetivos, eventos e
## textos de história. Tudo aqui é lido por scripts/mission.gd; o motor da partida é o mesmo
## do modo contra a IA. Roteiro: "referencia facções/Cronicas_da_Extincao_Roteiro_21_Missoes.md".
##
## Missão:
##   "player"/"enemy": raças (FACTIONS); "credits": [jogador, inimigo]
##   "map": {size, seed, rock_count (aglomerados aleatórios), ridges [[de, até, raio]],
##           rocks [[célula, raio]], clear [[célula, raio]], ore [[célula, raio]]}
##   "player_base"/"enemy_base": centros (área livre e alvo da IA)
##   "player_start"/"enemy_start": {"buildings": [[tipo, célula, tag?]], "units": [[id, célula, quantidade]]}
##   "ai": {first_wave (s), wave_size, produce (bool)}
##   "objectives": [{id, text, type, ...}] — tipos que o jogo já sabe verificar:
##       build (building) · army (count) · destroy_tag (tag ou tags) · destroy_all ·
##       survive (t) · have (unit, count)
##   "defeat": {type "lose_building", building}
##   "events": [{at "start" | "time" (t) | "objective" (id), speaker, text, wave?}]
##       wave = {units [[id, n]], from célula, target "player_base" | célula}
##   "briefing", "ending": textos de abertura e encerramento.

const CAMPAIGNS := {
	"hum": {
		"name": "Última Esperança",
		"desc": "General Marcus Kane. Os humanos estão perdendo o controle de Kharon:\nsobreviver à infestação dos insetos e à rebelião das máquinas.",
		"missions": ["H01", "H02", "H03", "H04", "H05", "H06", "H07"],
	},
}

## Títulos das missões ainda não implementadas (aparecem bloqueadas no menu)
const PLANNED := {
	"H03": "Máquinas Fora de Controle", "H04": "Linha de Defesa",
	"H05": "Operação Eclipse", "H06": "A Última Fortaleza", "H07": "Sobrevivência",
}

const MISSIONS := {
	"H01": {
		"title": "Primeiro Contato", "map_name": "Setor Alpha", "difficulty": "Fácil",
		"player": "hum", "enemy": "ins", "credits": [4000.0, 2500.0],
		"briefing": "Uma equipe de mineração rompeu uma estrutura subterrânea no Setor Alpha e "
			+ "perdemos contato com ela. Algo despertou lá embaixo.\n\n"
			+ "General Kane, o Comando ordena que o senhor estabeleça uma posição militar no "
			+ "oeste do setor e contenha a ameaça antes que ela se espalhe.",
		"ending": "O último ninho do Setor Alpha queima.\n\n"
			+ "Mas, antes que Kane possa comemorar, chega uma mensagem do Comando: outra "
			+ "instalação mineradora perdeu contato.\n\nA ameaça é maior do que imaginávamos.",
		# Mapa pequeno: base humana a oeste, ninhos a leste, cristas de rocha formando
		# três corredores e o depósito grande no centro, disputado.
		"map": {
			"size": "small", "seed": 1101, "rock_count": 10,
			"ridges": [
				[Vector2i(20, 4), Vector2i(30, 16), 1], [Vector2i(36, 13), Vector2i(44, 6), 1],
				[Vector2i(20, 44), Vector2i(30, 32), 1], [Vector2i(36, 35), Vector2i(44, 42), 1],
			],
			"rocks": [[Vector2i(26, 24), 1], [Vector2i(39, 24), 1], [Vector2i(47, 22), 1]],
			"clear": [[Vector2i(32, 24), 5], [Vector2i(44, 30), 4], [Vector2i(52, 14), 4], [Vector2i(52, 33), 4]],
			"ore": [
				[Vector2i(15, 15), 2], [Vector2i(15, 33), 2],      # perto da base
				[Vector2i(32, 24), 5],                              # centro: grande depósito
				[Vector2i(33, 41), 2], [Vector2i(47, 39), 2],      # sul, mais exposto
			],
		},
		"player_base": Vector2i(8, 24), "enemy_base": Vector2i(56, 24),
		"player_start": {
			"buildings": [["cy", Vector2i(5, 22)], ["power", Vector2i(9, 18)]],
			"units": [["hum_soldado", Vector2i(11, 23), 4], ["hum_tanque", Vector2i(11, 27), 1]],
		},
		"enemy_start": {
			"buildings": [
				["cy", Vector2i(56, 22)], ["power", Vector2i(60, 18)], ["power", Vector2i(60, 27)],
				["barracks", Vector2i(43, 29), "ninho1"], ["turret", Vector2i(41, 28)],
				["barracks", Vector2i(51, 13)], ["barracks", Vector2i(51, 33)],
				["turret", Vector2i(52, 21)], ["turret", Vector2i(52, 26)],
			],
			"units": [
				["ins_rifle", Vector2i(41, 31), 3], ["ins_smg", Vector2i(45, 32), 2],
				["ins_rifle", Vector2i(54, 18), 2], ["ins_mg", Vector2i(54, 29), 2],
			],
		},
		"ai": {"first_wave": 330.0, "wave_size": 5, "produce": true},
		"objectives": [
			{"id": "quartel", "type": "build", "building": "barracks",
				"text": "Construir o Alojamento (produção de infantaria)"},
			{"id": "exercito", "type": "army", "count": 10,
				"text": "Reunir um exército de defesa (10 unidades de combate)"},
			{"id": "ninho1", "type": "destroy_tag", "tag": "ninho1",
				"text": "Destruir o primeiro ninho de insetos (sudeste do centro)"},
			{"id": "regiao", "type": "destroy_all",
				"text": "Eliminar todas as estruturas inimigas da região"},
		],
		"defeat": {"type": "lose_building", "building": "cy",
			"text": "A Base Principal foi destruída."},
		"events": [
			{"at": "start", "speaker": "Comando de Kharon",
				"text": "General Kane, a equipe de mineração do Setor Alpha não responde há seis horas. Último sinal: a leste. Estabeleça a base e prepare suas tropas."},
			{"at": "time", "t": 25.0, "speaker": "Tenente de Engenharia",
				"text": "Há minério perto da base e um depósito enorme no centro do setor. Uma Refinaria nos dará os recursos para a guerra."},
			{"at": "time", "t": 150.0, "speaker": "Vigia avançado",
				"text": "Movimento a leste! Criaturas saindo do chão… estão vindo para a base!",
				"wave": {"units": [["ins_rifle", 4], ["ins_smg", 3]], "from": Vector2i(62, 8),
					"target": "player_base"}},
			{"at": "objective", "id": "exercito", "speaker": "General Kane",
				"text": "Tropas prontas. Avancem para leste e encontrem a origem dessas coisas."},
			{"at": "time", "t": 420.0, "speaker": "Vigia avançado",
				"text": "Nova leva de criaturas pelo corredor sul!",
				"wave": {"units": [["ins_rifle", 4], ["ins_smg", 2], ["ins_mg", 2]], "from": Vector2i(62, 44),
					"target": "player_base"}},
			{"at": "objective", "id": "ninho1", "speaker": "Comando de Kharon",
				"text": "Ninho destruído. Mas os sensores captam outras colônias além deste. General, termine o trabalho: limpe a região inteira."},
		],
	},
	"H02": {
		"title": "Colônia Perdida", "map_name": "Deserto de Cinzas", "difficulty": "Fácil/Média",
		"player": "hum", "enemy": "ins", "credits": [5000.0, 4500.0],
		"briefing": "A colônia mineradora do Deserto de Cinzas parou de responder há dois dias. "
			+ "Os últimos registros falam de tremores e de \"coisas saindo das galerias\".\n\n"
			+ "General Kane, desembarque ao sul, monte uma base militar e avance pelo vale até a "
			+ "colônia. Descubra o que aconteceu com os trabalhadores e retome a região.",
		"ending": "A colmeia do Deserto de Cinzas desmorona sobre as próprias galerias.\n\n"
			+ "Nos registros recuperados da colônia, os geólogos descrevem fósseis do Enxame em "
			+ "camadas de rocha com milhões de anos.\n\nOs insetos já estavam em Kharon muito antes "
			+ "de nós chegarmos.",
		# Mapa médio: base ao sul, portão central entre cristas; vale com as ruínas da colônia
		# no centro-norte, um ninho de cada lado e a estrutura central; colmeia no extremo norte.
		"map": {
			"size": "medium", "seed": 2202, "rock_count": 16,
			"ridges": [
				[Vector2i(4, 45), Vector2i(35, 47), 1], [Vector2i(51, 47), Vector2i(82, 45), 1],   # portão sul
				[Vector2i(27, 30), Vector2i(30, 40), 1], [Vector2i(59, 30), Vector2i(56, 40), 1],  # paredes do vale
				[Vector2i(8, 17), Vector2i(30, 19), 1], [Vector2i(56, 19), Vector2i(78, 17), 1],   # passagem norte
			],
			"rocks": [[Vector2i(43, 39), 1], [Vector2i(37, 14), 1], [Vector2i(49, 14), 1]],
			"clear": [
				[Vector2i(43, 25), 7], [Vector2i(19, 27), 5], [Vector2i(67, 27), 5],          # colônia e ninhos
				[Vector2i(43, 7), 11], [Vector2i(43, 46), 4],                                 # colmeia e portão
			],
			"ore": [
				[Vector2i(34, 56), 2], [Vector2i(53, 57), 2],      # pouco perto da base
				[Vector2i(11, 38), 3], [Vector2i(75, 38), 3],      # laterais, longe e expostas
				[Vector2i(43, 32), 4],                              # centro do vale
				[Vector2i(43, 15), 4],                              # norte, colado na colmeia
			],
		},
		"player_base": Vector2i(43, 57), "enemy_base": Vector2i(43, 6),
		"player_start": {
			"buildings": [["cy", Vector2i(41, 56)], ["power", Vector2i(46, 55)]],
			"units": [
				["hum_soldado", Vector2i(38, 52), 6], ["hum_fuzileiro", Vector2i(46, 51), 2],
				["hum_engenheiro", Vector2i(49, 55), 1], ["hum_medico", Vector2i(37, 55), 1],
				["hum_tanque", Vector2i(41, 52), 2], ["hum_transporte", Vector2i(44, 53), 1],
			],
		},
		"enemy_start": {
			"buildings": [
				["cy", Vector2i(41, 4), "colmeia"], ["power", Vector2i(36, 3)], ["power", Vector2i(48, 3)],
				["barracks", Vector2i(50, 8)], ["barracks", Vector2i(34, 8)], ["refinery", Vector2i(41, 11)],
				["turret", Vector2i(39, 13)], ["turret", Vector2i(46, 13)],
				["medic", Vector2i(42, 23), "estrutura"], ["turret", Vector2i(39, 27)], ["turret", Vector2i(47, 27)],
				["barracks", Vector2i(18, 26), "ninho_oeste"], ["turret", Vector2i(22, 29)],
				["barracks", Vector2i(66, 26), "ninho_leste"], ["turret", Vector2i(64, 29)],
			],
			"units": [
				["ins_rifle", Vector2i(41, 29), 4], ["ins_smg", Vector2i(44, 30), 3],
				["ins_sniper", Vector2i(18, 30), 2], ["ins_mg", Vector2i(66, 30), 2],
				["ins_tank", Vector2i(42, 16), 1], ["ins_rifle", Vector2i(36, 12), 3],
			],
		},
		"ai": {"first_wave": 270.0, "wave_size": 6, "produce": true},
		"objectives": [
			{"id": "base", "type": "build", "building": "factory",
				"text": "Estabelecer a base militar (construir a Mecânica)"},
			{"id": "mineracao", "type": "have", "unit": "hum_coletor", "count": 2,
				"text": "Expandir a coleta de minério (2 Coletores)"},
			{"id": "ninhos", "type": "destroy_tag", "tags": ["ninho_oeste", "ninho_leste"],
				"text": "Destruir os ninhos que bloqueiam o vale (oeste e leste)"},
			{"id": "estrutura", "type": "destroy_tag", "tag": "estrutura",
				"text": "Destruir a estrutura central sobre as ruínas da colônia"},
			{"id": "colmeia", "type": "destroy_tag", "tag": "colmeia",
				"text": "Eliminar a colmeia principal, ao norte"},
		],
		"defeat": {"type": "lose_building", "building": "cy",
			"text": "A Base Principal foi destruída."},
		"events": [
			{"at": "start", "speaker": "Comando de Kharon",
				"text": "General, a colônia está perdida. Nenhum sinal de vida nos últimos dois dias. Recupere a região e descubra o que houve."},
			{"at": "time", "t": 30.0, "speaker": "Tenente de Engenharia",
				"text": "O minério perto da base é pouco. Os depósitos grandes estão nas laterais e no vale da colônia. Vamos precisar de mais Coletores."},
			{"at": "time", "t": 70.0, "speaker": "General Kane",
				"text": "O Transporte Blindado leva seis homens: botão direito nele para embarcar, U para desembarcar. Usem-no para cruzar o vale."},
			{"at": "time", "t": 160.0, "speaker": "Vigia avançado",
				"text": "Criaturas descendo do norte pelo vale! Preparem a defesa no portão!",
				"wave": {"units": [["ins_rifle", 4], ["ins_smg", 3]], "from": Vector2i(43, 20),
					"target": "player_base"}},
			{"at": "time", "t": 400.0, "speaker": "Vigia avançado",
				"text": "Um grupo maior saindo das galerias do norte, com uma criatura enorme na frente!",
				"wave": {"units": [["ins_tank", 1], ["ins_rifle", 4], ["ins_smg", 3], ["ins_mg", 2]],
					"from": Vector2i(43, 20), "target": "player_base"}},
			{"at": "objective", "id": "ninhos", "speaker": "General Kane",
				"text": "O vale está livre. Avancem sobre as ruínas da colônia."},
			{"at": "objective", "id": "estrutura", "speaker": "Comando de Kharon",
				"text": "Kane… os sensores captaram um pulso de energia vindo de baixo da estrutura. Muito profundo. Os registros da colônia chamam a fonte de \"Núcleo Primordial\"."},
			{"at": "objective", "id": "estrutura", "speaker": "General Kane",
				"text": "Primeiro a colmeia. Depois descobrimos o que esse Núcleo é. Avançar para o norte!",
				"wave": {"units": [["ins_smg", 4], ["ins_at", 2]], "from": Vector2i(12, 8),
					"target": "player_base"}},
		],
	},
}
