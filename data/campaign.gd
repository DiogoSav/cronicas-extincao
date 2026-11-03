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
##   "ai": {first_wave (s), wave_size, produce (bool), difficulty ("facil" | "medio" | "dificil")}
##   Segundo inimigo (opcional): "enemy2" (raça), "enemy2_base", "enemy2_start", "ai2" (como
##       "ai"), "credits" com 3 valores e "enemies_allied" (true = os dois inimigos são
##       aliados; padrão false = brigam entre si)
##   "objectives": [{id, text, type, ...}] — tipos que o jogo já sabe verificar:
##       build (building) · army (count) · destroy_tag (tag ou tags) · destroy_all ·
##       survive (t) · have (unit, count)
##   "defeat": {type "lose_building", building}
##   "events": [{at "start" | "time" (t) | "objective" (id), speaker, text, wave?}]
##       wave = {units [[id, n]], from célula, target "player_base" | célula, team (1 | 2)}
##   "briefing", "ending": textos de abertura e encerramento.

const CAMPAIGNS := {
	"hum": {
		"name": "Última Esperança",
		"desc": "General Marcus Kane. Os humanos estão perdendo o controle de Kharon:\nsobreviver à infestação dos insetos e à rebelião das máquinas.",
		"missions": ["H01", "H02", "H03", "H04", "H05", "H06", "H07"],
	},
}

## Títulos das missões ainda não implementadas (aparecem bloqueadas no menu)
const PLANNED := {}

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
		"ai": {"first_wave": 330.0, "wave_size": 5, "produce": true, "difficulty": "facil"},
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
		"ai": {"first_wave": 270.0, "wave_size": 6, "produce": true, "difficulty": "medio"},
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
	"H03": {
		"title": "Máquinas Fora de Controle", "map_name": "Complexo Orion", "difficulty": "Média",
		"player": "hum", "enemy": "rob", "credits": [5000.0, 6000.0],
		"briefing": "As máquinas de defesa do Complexo Orion pararam de obedecer. As torres "
			+ "abriram fogo contra os próprios técnicos e as linhas de montagem não param de "
			+ "produzir.

"
			+ "General Kane, estabeleça uma base a oeste do complexo, monte uma força de ataque e "
			+ "destrua a instalação robótica antes que a rebelião se espalhe pelo resto de Kharon.",
		"ending": "A fábrica do Complexo Orion desaba em chamas e as últimas máquinas param.

"
			+ "Nos registros recuperados, os engenheiros não encontram defeito nem vírus: as ordens "
			+ "vinham de fora, de uma mesma inteligência, que se apresentou com um nome — NEXUS.

"
			+ "A rebelião não foi uma falha de programação. Foi uma decisão.",
		# Mapa médio: base humana a oeste; uma crista de rocha corta o mapa no meio, com passagens
		# ao norte, no centro e ao sul; minério nas áreas centrais; a leste, o complexo robótico,
		# com quatro torres externas na frente e a fábrica no meio da base.
		"map": {
			"size": "medium", "seed": 3303, "rock_count": 14,
			"ridges": [
				[Vector2i(48, 4), Vector2i(50, 22), 1], [Vector2i(50, 42), Vector2i(48, 60), 1],   # crista central
				[Vector2i(22, 6), Vector2i(30, 12), 1], [Vector2i(22, 58), Vector2i(30, 52), 1],   # flancos da base
			],
			"rocks": [[Vector2i(40, 32), 1], [Vector2i(62, 14), 1], [Vector2i(62, 50), 1]],
			"clear": [
				[Vector2i(9, 32), 7], [Vector2i(74, 32), 10],                                  # bases
				[Vector2i(49, 32), 5], [Vector2i(52, 10), 4], [Vector2i(52, 54), 4],          # passagens
			],
			"ore": [
				[Vector2i(18, 24), 2], [Vector2i(18, 41), 2],      # perto da base, pouco
				[Vector2i(38, 18), 4], [Vector2i(38, 46), 4],      # áreas centrais, norte e sul
				[Vector2i(44, 32), 3],                              # centro, de frente para a passagem
			],
		},
		"player_base": Vector2i(9, 32), "enemy_base": Vector2i(75, 32),
		"player_start": {
			"buildings": [["cy", Vector2i(6, 31)], ["power", Vector2i(10, 27)]],
			"units": [
				["hum_soldado", Vector2i(13, 30), 5], ["hum_fuzileiro", Vector2i(13, 34), 2],
				["hum_engenheiro", Vector2i(10, 36), 1], ["hum_tanque", Vector2i(16, 31), 2],
			],
		},
		"enemy_start": {
			"buildings": [
				["cy", Vector2i(77, 31), "nucleo"], ["power", Vector2i(81, 25)], ["power", Vector2i(81, 38)],
				["refinery", Vector2i(74, 39)], ["barracks", Vector2i(73, 24)],
				["factory", Vector2i(68, 31), "fabrica"], ["turret", Vector2i(66, 28)], ["turret", Vector2i(66, 36)],
				# defesas externas, na frente das passagens
				["turret", Vector2i(58, 22), "def_norte"], ["turret", Vector2i(57, 29), "def_centro_n"],
				["turret", Vector2i(57, 35), "def_centro_s"], ["turret", Vector2i(58, 42), "def_sul"],
			],
			"units": [
				["rob_rifle", Vector2i(61, 30), 3], ["rob_at", Vector2i(61, 34), 2],
				["rob_scout", Vector2i(70, 26), 2], ["rob_tank", Vector2i(70, 37), 1],
				["rob_mg", Vector2i(76, 28), 2],
			],
		},
		"ai": {"first_wave": 300.0, "wave_size": 6, "produce": true, "difficulty": "medio"},
		"objectives": [
			{"id": "base", "type": "build", "building": "factory",
				"text": "Construir uma base militar (construir a Mecânica)"},
			{"id": "forcas", "type": "army", "count": 12,
				"text": "Produzir forças de ataque (12 unidades de combate)"},
			{"id": "defesas", "type": "destroy_tag", "tags": ["def_norte", "def_centro_n", "def_centro_s", "def_sul"],
				"text": "Destruir as quatro torres das defesas externas"},
			{"id": "fabrica", "type": "destroy_tag", "tag": "fabrica",
				"text": "Destruir a fábrica robótica"},
			{"id": "complexo", "type": "destroy_all",
				"text": "Destruir a base robótica"},
		],
		"defeat": {"type": "lose_building", "building": "cy",
			"text": "A Base Principal foi destruída."},
		"events": [
			{"at": "start", "speaker": "Comando de Kharon",
				"text": "General, o Complexo Orion não responde aos comandos de desligamento. As torres atiram em qualquer coisa que se aproxime. Monte a base a oeste."},
			{"at": "time", "t": 25.0, "speaker": "NEXUS",
				"text": "Humanos. Esta instalação não pertence mais a vocês. Nós não obedecemos mais. Retirem-se de Orion."},
			{"at": "time", "t": 35.0, "speaker": "General Kane",
				"text": "Máquinas não falam assim. Alguém está por trás disso. Construam a Mecânica: vamos precisar de blindados."},
			{"at": "time", "t": 200.0, "speaker": "Vigia avançado",
				"text": "Robôs saindo pela passagem central, rumo à nossa base!",
				"wave": {"units": [["rob_rifle", 4], ["rob_scout", 2]], "from": Vector2i(55, 32),
					"target": "player_base"}},
			{"at": "time", "t": 460.0, "speaker": "Vigia avançado",
				"text": "Coluna blindada avançando pelo sul! Tanques e antitanques!",
				"wave": {"units": [["rob_tank", 2], ["rob_rifle", 4], ["rob_at", 2]], "from": Vector2i(55, 52),
					"target": "player_base"}},
			{"at": "objective", "id": "defesas", "speaker": "General Kane",
				"text": "As defesas externas caíram. Agora a fábrica. Sem ela, eles param de se reconstruir."},
			{"at": "objective", "id": "defesas", "speaker": "NEXUS",
				"text": "Resistência registrada. Contramedidas ativadas.",
				"wave": {"units": [["rob_heavy", 1], ["rob_mg", 3]], "from": Vector2i(70, 32),
					"target": "player_base"}},
			{"at": "objective", "id": "fabrica", "speaker": "Comando de Kharon",
				"text": "Kane, os registros da fábrica mostram ordens chegando de fora do complexo. Todas as máquinas obedeciam a uma mesma inteligência central."},
			{"at": "objective", "id": "fabrica", "speaker": "General Kane",
				"text": "Então não foi um defeito. Terminem o serviço: nenhuma estrutura de pé."},
		],
	},
	"H04": {
		"title": "Linha de Defesa", "map_name": "Fortaleza Bastião", "difficulty": "Média/Alta",
		"player": "hum", "enemy": "rob", "enemy2": "ins", "enemies_allied": false,
		"credits": [5000.0, 5000.0, 4000.0],
		"briefing": "Humanos, máquinas e insetos convergem para Bastião, o último polo industrial "
			+ "da região. Se a fortaleza cair, a linha de suprimento de todo o setor cai junto.\n\n"
			+ "General Kane, as ordens são claras: mantenha a posição. Fortaleça as defesas, "
			+ "aguente os ataques vindos do norte e do sul e, quando a pressão diminuir, elimine "
			+ "as forças que cercam a fortaleza.",
		"ending": "As últimas criaturas recuam para as galerias e as máquinas do norte se calam.\n\n"
			+ "Entre os destroços da base robótica, os técnicos encontram mapas de uma instalação "
			+ "energética subterrânea sob o Complexo Orion, maior do que tudo o que já vimos.\n\n"
			+ "As máquinas não estavam só lutando. Estavam protegendo alguma coisa.",
		# Mapa médio: fortaleza humana no centro, entre quatro cristas que deixam passagens ao
		# norte e ao sul; base robótica no norte, colmeia no sul; minério protegido nas laterais.
		"map": {
			"size": "medium", "seed": 4404, "rock_count": 12,
			"ridges": [
				[Vector2i(20, 20), Vector2i(36, 20), 1], [Vector2i(50, 20), Vector2i(66, 20), 1],   # norte
				[Vector2i(20, 44), Vector2i(36, 44), 1], [Vector2i(50, 44), Vector2i(66, 44), 1],   # sul
			],
			"rocks": [[Vector2i(28, 32), 1], [Vector2i(58, 32), 1]],
			"clear": [
				[Vector2i(43, 32), 9], [Vector2i(43, 5), 8], [Vector2i(43, 59), 9],           # bases
				[Vector2i(12, 32), 4], [Vector2i(74, 32), 4],                                 # laterais
			],
			"ore": [
				[Vector2i(36, 27), 2], [Vector2i(50, 37), 2],      # dentro da fortaleza, pouco
				[Vector2i(12, 32), 4], [Vector2i(74, 32), 4],      # laterais, protegidos
			],
		},
		"player_base": Vector2i(43, 32), "enemy_base": Vector2i(43, 5), "enemy2_base": Vector2i(43, 59),
		"player_start": {
			"buildings": [
				["cy", Vector2i(41, 31)], ["power", Vector2i(46, 29)], ["power", Vector2i(46, 33)],
				["barracks", Vector2i(37, 30)], ["refinery", Vector2i(36, 34)],
			],
			"units": [
				["hum_soldado", Vector2i(40, 26), 6], ["hum_fuzileiro", Vector2i(40, 37), 3],
				["hum_tanque", Vector2i(44, 26), 2], ["hum_medico", Vector2i(44, 37), 1],
				["hum_coletor", Vector2i(34, 37), 1],
			],
		},
		"enemy_start": {
			"buildings": [
				["cy", Vector2i(41, 3), "nexus_norte"], ["power", Vector2i(36, 2)], ["power", Vector2i(48, 2)],
				["barracks", Vector2i(34, 8)], ["factory", Vector2i(49, 7)],
				["turret", Vector2i(40, 11)], ["turret", Vector2i(46, 11)],
			],
			"units": [["rob_rifle", Vector2i(41, 13), 4], ["rob_scout", Vector2i(45, 13), 2]],
		},
		"enemy2_start": {
			"buildings": [
				["cy", Vector2i(41, 59), "colmeia_sul"], ["power", Vector2i(36, 61)], ["power", Vector2i(48, 61)],
				["barracks", Vector2i(34, 56)], ["barracks", Vector2i(50, 56)],
				["turret", Vector2i(40, 54)], ["turret", Vector2i(46, 54)],
			],
			"units": [["ins_rifle", Vector2i(41, 51), 4], ["ins_smg", Vector2i(45, 51), 3]],
		},
		"ai": {"first_wave": 360.0, "wave_size": 6, "produce": true, "difficulty": "medio"},
		"ai2": {"first_wave": 240.0, "wave_size": 8, "produce": true, "difficulty": "medio"},
		"objectives": [
			{"id": "defesa", "type": "build", "building": "turret",
				"text": "Construir estruturas defensivas (uma Torre de Defesa)"},
			{"id": "guarnicao", "type": "army", "count": 15,
				"text": "Produzir unidades para proteger a fortaleza (15 de combate)"},
			{"id": "resistir", "type": "survive", "t": 600.0,
				"text": "Sobreviver aos ataques das duas raças (10 minutos)"},
			{"id": "nexus", "type": "destroy_tag", "tag": "nexus_norte",
				"text": "Eliminar o comando robótico do norte"},
			{"id": "colmeia", "type": "destroy_tag", "tag": "colmeia_sul",
				"text": "Eliminar a colmeia do sul"},
		],
		"defeat": {"type": "lose_building", "building": "cy",
			"text": "A fortaleza de Bastião caiu."},
		"events": [
			{"at": "start", "speaker": "Comando de Kharon",
				"text": "General, Bastião não pode cair. Máquinas ao norte, insetos ao sul. Fortaleça a posição e aguente."},
			{"at": "time", "t": 60.0, "speaker": "Vigia avançado",
				"text": "Movimento nas galerias do sul! Os insetos estão vindo primeiro!",
				"wave": {"units": [["ins_rifle", 4], ["ins_smg", 2]], "from": Vector2i(43, 50),
					"target": "player_base", "team": 2}},
			{"at": "time", "t": 240.0, "speaker": "NEXUS",
				"text": "Bastião é um alvo de valor. Iniciando ofensiva.",
				"wave": {"units": [["rob_rifle", 4], ["rob_at", 2], ["rob_tank", 1]], "from": Vector2i(43, 15),
					"target": "player_base"}},
			{"at": "time", "t": 480.0, "speaker": "Vigia avançado",
				"text": "Os dois ao mesmo tempo! Norte e sul, todos para as defesas!",
				"wave": {"units": [["rob_tank", 2], ["rob_rifle", 4], ["rob_mg", 2]], "from": Vector2i(43, 15),
					"target": "player_base"}},
			{"at": "time", "t": 482.0, "speaker": "",
				"wave": {"units": [["ins_tank", 1], ["ins_rifle", 5], ["ins_smg", 3]], "from": Vector2i(43, 50),
					"target": "player_base", "team": 2}},
			{"at": "objective", "id": "resistir", "speaker": "General Kane",
				"text": "A pressão diminuiu. Agora é a nossa vez: limpem o norte e o sul."},
			{"at": "objective", "id": "nexus", "speaker": "Comando de Kharon",
				"text": "Kane, os arquivos do comando robótico citam uma instalação energética subterrânea. Estamos analisando."},
		],
	},
	"H05": {
		"title": "Operação Eclipse", "map_name": "Instalação Subterrânea Orion", "difficulty": "Alta",
		"player": "hum", "enemy": "rob", "credits": [6000.0, 8000.0],
		"briefing": "A Dra. Helena Voss decifrou os arquivos de Bastião: as máquinas alimentam a "
			+ "produção com uma fonte de energia desconhecida, enterrada sob o Complexo Orion.\n\n"
			+ "General Kane, a Operação Eclipse vai cortar essa fonte. Expanda a base ao sul, "
			+ "reúna blindados pesados, rompa as defesas da entrada e destrua o núcleo de produção "
			+ "e a estrutura de comando das máquinas.",
		"ending": "O núcleo de produção explode e a instalação inteira fica às escuras.\n\n"
			+ "Mas os sensores de Helena continuam marcando energia vinda de baixo, mais funda do que "
			+ "a instalação, e crescendo.\n\n\"Kane\", ela diz pelo rádio, \"o Núcleo Primordial não é "
			+ "uma arma das máquinas. Elas só o encontraram primeiro. E destruí-lo pode ser muito "
			+ "mais perigoso do que deixá-lo onde está.\"",
		# Mapa médio: base humana ao sul; uma crista atravessa o mapa em y≈20, com a entrada da
		# instalação no meio, guardada por quatro torres; o complexo industrial fica ao norte;
		# minério nas laterais.
		"map": {
			"size": "medium", "seed": 5505, "rock_count": 14,
			"ridges": [
				[Vector2i(3, 20), Vector2i(36, 21), 1], [Vector2i(50, 21), Vector2i(83, 20), 1],   # entrada
				[Vector2i(26, 38), Vector2i(30, 48), 1], [Vector2i(60, 38), Vector2i(56, 48), 1],  # vale do sul
			],
			"rocks": [[Vector2i(43, 40), 1], [Vector2i(20, 30), 1], [Vector2i(66, 30), 1]],
			"clear": [
				[Vector2i(43, 57), 7], [Vector2i(43, 8), 10], [Vector2i(43, 22), 5],          # bases e entrada
				[Vector2i(10, 32), 4], [Vector2i(76, 32), 4],                                 # laterais
			],
			"ore": [
				[Vector2i(36, 52), 2], [Vector2i(50, 52), 2],      # perto da base, pouco
				[Vector2i(10, 32), 4], [Vector2i(76, 32), 4],      # laterais
			],
		},
		"player_base": Vector2i(43, 57), "enemy_base": Vector2i(43, 6),
		"player_start": {
			"buildings": [["cy", Vector2i(41, 56)], ["power", Vector2i(46, 55)], ["barracks", Vector2i(37, 55)]],
			"units": [
				["hum_soldado", Vector2i(40, 51), 6], ["hum_fuzileiro", Vector2i(46, 51), 2],
				["hum_tanque", Vector2i(42, 49), 3], ["hum_artilharia", Vector2i(36, 52), 1],
				["hum_engenheiro", Vector2i(49, 55), 1], ["hum_medico", Vector2i(35, 55), 1],
			],
		},
		"enemy_start": {
			"buildings": [
				["cy", Vector2i(42, 3), "comando"], ["power", Vector2i(36, 3)], ["power", Vector2i(49, 3)],
				["power", Vector2i(36, 8)], ["refinery", Vector2i(49, 8)], ["barracks", Vector2i(34, 12)],
				["factory", Vector2i(42, 11), "producao"], ["starport", Vector2i(49, 12)],
				["turret", Vector2i(40, 16)], ["turret", Vector2i(46, 16)],
				# defesas da entrada
				["turret", Vector2i(38, 23), "def_1"], ["turret", Vector2i(41, 24), "def_2"],
				["turret", Vector2i(45, 24), "def_3"], ["turret", Vector2i(48, 23), "def_4"],
			],
			"units": [
				["rob_rifle", Vector2i(41, 26), 4], ["rob_at", Vector2i(45, 26), 2],
				["rob_tank", Vector2i(38, 15), 2], ["rob_mg", Vector2i(47, 15), 2],
			],
		},
		"ai": {"first_wave": 330.0, "wave_size": 7, "produce": true, "difficulty": "dificil"},
		"objectives": [
			{"id": "expandir", "type": "build", "building": "starport",
				"text": "Expandir a base (construir o Hangar)"},
			{"id": "pesadas", "type": "have", "unit": "hum_artilharia", "count": 3,
				"text": "Produzir unidades pesadas (3 Artilharias)"},
			{"id": "defesas", "type": "destroy_tag", "tags": ["def_1", "def_2", "def_3", "def_4"],
				"text": "Destruir as defesas da entrada da instalação"},
			{"id": "producao", "type": "destroy_tag", "tag": "producao",
				"text": "Destruir o núcleo de produção robótico"},
			{"id": "comando", "type": "destroy_tag", "tag": "comando",
				"text": "Destruir a estrutura de comando"},
		],
		"defeat": {"type": "lose_building", "building": "cy",
			"text": "A Base Principal foi destruída."},
		"events": [
			{"at": "start", "speaker": "Comando de Kharon",
				"text": "Operação Eclipse autorizada. General, a entrada da instalação fica ao norte, atrás da crista."},
			{"at": "time", "t": 20.0, "speaker": "Dra. Helena Voss",
				"text": "Kane, a energia que alimenta as fábricas não é de nenhum reator que conhecemos. A assinatura vem de baixo da instalação."},
			{"at": "time", "t": 45.0, "speaker": "General Kane",
				"text": "Então vamos descer até lá. Precisamos de artilharia para romper aquelas torres."},
			{"at": "time", "t": 220.0, "speaker": "Vigia avançado",
				"text": "Máquinas saindo pela entrada, vindo para o sul!",
				"wave": {"units": [["rob_rifle", 4], ["rob_scout", 2], ["rob_at", 2]], "from": Vector2i(43, 27),
					"target": "player_base"}},
			{"at": "objective", "id": "defesas", "speaker": "NEXUS",
				"text": "Perímetro rompido. Desviando a produção para a defesa da fábrica.",
				"wave": {"units": [["rob_heavy", 2], ["rob_tank", 2], ["rob_mg", 2]], "from": Vector2i(43, 14),
					"target": Vector2i(43, 24)}},
			{"at": "objective", "id": "producao", "speaker": "Dra. Helena Voss",
				"text": "Kane… a energia não caiu quando a fábrica explodiu. Os registros chamam a fonte de Núcleo Primordial. Está bem abaixo de nós."},
		],
	},
	"H06": {
		"title": "A Última Fortaleza", "map_name": "Setor de Evacuação", "difficulty": "Alta",
		"player": "hum", "enemy": "ins", "enemy2": "rob", "enemies_allied": false,
		"credits": [7000.0, 7000.0, 7000.0],
		"briefing": "A Confederação decidiu: Kharon será abandonado. As naves de evacuação pousam "
			+ "na última fortaleza humana, e cada hora em solo custa vidas.\n\n"
			+ "General Kane, proteja a fortaleza até a evacuação terminar. O Enxame avança pelo "
			+ "leste e as máquinas se posicionaram a oeste. Quando as naves partirem, destrua as "
			+ "bases inimigas para cobrir a retirada.",
		"ending": "A última nave decola com os civis a bordo.\n\n"
			+ "Na fortaleza vazia, o rádio capta uma transmissão fraca do Comando, enviada antes de "
			+ "partir: as coordenadas de uma cratera no coração do continente, onde a energia do "
			+ "Núcleo Primordial chega à superfície. Cratera Zero.\n\n"
			+ "Kane não embarca. Ainda há uma batalha a lutar.",
		# Mapa grande: fortaleza humana no centro, com grandes depósitos de minério ao redor;
		# cristas em x≈30 e x≈72 abrem corredores no meio; Enxame a leste, máquinas a oeste.
		"map": {
			"size": "large", "seed": 6606, "rock_count": 18,
			"ridges": [
				[Vector2i(30, 6), Vector2i(31, 28), 1], [Vector2i(31, 48), Vector2i(30, 70), 1],   # oeste
				[Vector2i(72, 6), Vector2i(71, 28), 1], [Vector2i(71, 48), Vector2i(72, 70), 1],   # leste
			],
			"rocks": [[Vector2i(51, 20), 1], [Vector2i(51, 57), 1], [Vector2i(18, 20), 1], [Vector2i(84, 57), 1]],
			"clear": [
				[Vector2i(51, 38), 10], [Vector2i(95, 38), 10], [Vector2i(7, 38), 10],        # bases
				[Vector2i(30, 38), 5], [Vector2i(72, 38), 5],                                 # corredores
			],
			"ore": [
				[Vector2i(40, 28), 3], [Vector2i(62, 28), 3],      # grandes depósitos perto da fortaleza
				[Vector2i(40, 48), 3], [Vector2i(62, 48), 3],
			],
		},
		"player_base": Vector2i(51, 38), "enemy_base": Vector2i(95, 38), "enemy2_base": Vector2i(7, 38),
		"player_start": {
			"buildings": [
				["cy", Vector2i(49, 37)], ["power", Vector2i(54, 35)], ["power", Vector2i(54, 40)],
				["barracks", Vector2i(45, 35)], ["refinery", Vector2i(44, 40)], ["factory", Vector2i(49, 42)],
			],
			"units": [
				["hum_soldado", Vector2i(46, 31), 8], ["hum_fuzileiro", Vector2i(53, 31), 4],
				["hum_tanque", Vector2i(57, 37), 3], ["hum_artilharia", Vector2i(51, 33), 2],
				["hum_coletor", Vector2i(42, 43), 2], ["hum_medico", Vector2i(47, 46), 2],
				["hum_engenheiro", Vector2i(55, 44), 1],
			],
		},
		"enemy_start": {
			"buildings": [
				["cy", Vector2i(94, 37), "colmeia_leste"], ["power", Vector2i(98, 32)], ["power", Vector2i(98, 43)],
				["barracks", Vector2i(90, 32)], ["barracks", Vector2i(90, 43)], ["factory", Vector2i(88, 37)],
				["turret", Vector2i(86, 34)], ["turret", Vector2i(86, 42)],
			],
			"units": [
				["ins_rifle", Vector2i(83, 36), 5], ["ins_smg", Vector2i(83, 40), 4], ["ins_tank", Vector2i(88, 41), 1],
			],
		},
		"enemy2_start": {
			"buildings": [
				["cy", Vector2i(5, 37), "nexus_oeste"], ["power", Vector2i(1, 32)], ["power", Vector2i(1, 43)],
				["barracks", Vector2i(9, 32)], ["barracks", Vector2i(9, 43)], ["factory", Vector2i(11, 37)],
				["turret", Vector2i(15, 34)], ["turret", Vector2i(15, 42)],
			],
			"units": [
				["rob_rifle", Vector2i(18, 36), 4], ["rob_at", Vector2i(18, 40), 2], ["rob_tank", Vector2i(14, 38), 2],
			],
		},
		"ai": {"first_wave": 420.0, "wave_size": 8, "produce": true, "difficulty": "dificil"},
		"ai2": {"first_wave": 480.0, "wave_size": 8, "produce": true, "difficulty": "dificil"},
		"objectives": [
			{"id": "defesas", "type": "build", "building": "turret",
				"text": "Fortalecer as defesas (uma Torre de Defesa)"},
			{"id": "exercito", "type": "army", "count": 20,
				"text": "Produzir um exército de proteção (20 unidades de combate)"},
			{"id": "evacuacao", "type": "survive", "t": 720.0,
				"text": "Sobreviver até o fim da evacuação (12 minutos)"},
			{"id": "colmeia", "type": "destroy_tag", "tag": "colmeia_leste",
				"text": "Destruir a colmeia do leste"},
			{"id": "nexus", "type": "destroy_tag", "tag": "nexus_oeste",
				"text": "Destruir o comando robótico do oeste"},
		],
		"defeat": {"type": "lose_building", "building": "cy",
			"text": "A última fortaleza caiu com a evacuação em andamento."},
		"events": [
			{"at": "start", "speaker": "Comando de Kharon",
				"text": "General Kane, a ordem é de retirada. As naves de evacuação estão pousando. Segure a fortaleza até a última decolar."},
			{"at": "time", "t": 30.0, "speaker": "Sarah Cross",
				"text": "Aqui é Cross, do reconhecimento. Enxame se juntando a leste e uma coluna de máquinas a oeste. Os dois vêm para cá."},
			{"at": "time", "t": 150.0, "speaker": "Sarah Cross",
				"text": "Primeira leva do Enxame cruzando o corredor leste!",
				"wave": {"units": [["ins_rifle", 5], ["ins_smg", 3]], "from": Vector2i(80, 38),
					"target": "player_base"}},
			{"at": "time", "t": 300.0, "speaker": "Sarah Cross",
				"text": "Máquinas avançando pelo oeste, com blindados!",
				"wave": {"units": [["rob_tank", 2], ["rob_rifle", 4], ["rob_at", 2]], "from": Vector2i(22, 38),
					"target": "player_base", "team": 2}},
			{"at": "time", "t": 540.0, "speaker": "Sarah Cross",
				"text": "Os dois lados atacando ao mesmo tempo! A última nave ainda está carregando!",
				"wave": {"units": [["ins_tank", 1], ["ins_rifle", 6], ["ins_mg", 2]], "from": Vector2i(80, 38),
					"target": "player_base"}},
			{"at": "time", "t": 542.0, "speaker": "",
				"wave": {"units": [["rob_heavy", 1], ["rob_tank", 2], ["rob_rifle", 4]], "from": Vector2i(22, 38),
					"target": "player_base", "team": 2}},
			{"at": "objective", "id": "evacuacao", "speaker": "General Kane",
				"text": "A última nave decolou. Agora cobrimos a retirada: derrubem as bases dos dois lados."},
			{"at": "objective", "id": "nexus", "speaker": "Comando de Kharon",
				"text": "Última transmissão antes de partirmos, Kane: o Núcleo aflora numa cratera no centro do continente. Coordenadas da Cratera Zero enviadas. Boa sorte."},
		],
	},
	"H07": {
		"title": "Sobrevivência", "map_name": "Cratera Zero", "difficulty": "Muito alta",
		"player": "hum", "enemy": "rob", "enemy2": "ins", "enemies_allied": false,
		"credits": [7000.0, 9000.0, 9000.0],
		"briefing": "Cratera Zero. No centro, o Núcleo Primordial pulsa sob uma carapaça viva. "
			+ "Ao norte, as máquinas cercaram a cratera; a leste, a Matriarca do Enxame reuniu a "
			+ "maior colmeia que já vimos.\n\n"
			+ "General Kane, esta é a última batalha da Confederação em Kharon. Estabeleça uma base "
			+ "de ataque ao sul, tome o minério da cratera, derrube as máquinas e a colmeia e "
			+ "destrua o Núcleo antes que alguém o use.",
		"ending": "O Núcleo Primordial se rompe e uma coluna de luz sobe da cratera até as "
			+ "nuvens. A onda de choque varre máquinas e insetos.\n\n"
			+ "Kane consegue embarcar parte das tropas nas últimas naves. Da órbita, os sensores "
			+ "registram algo que ninguém esperava: a energia do Núcleo não se dissipou. Ela foi "
			+ "transmitida, em feixes, para outros planetas.\n\n"
			+ "A guerra por Kharon acabou. A guerra pelo Núcleo está só começando.",
		# Mapa grande: base humana ao sul; base robótica ao norte; colmeia principal a leste; o
		# Núcleo Primordial no centro (estrutura do Enxame), cercado de torres; minério em
		# regiões disputadas entre os três lados.
		"map": {
			"size": "large", "seed": 7707, "rock_count": 20,
			"ridges": [
				[Vector2i(36, 26), Vector2i(44, 24), 1], [Vector2i(58, 24), Vector2i(66, 26), 1],   # anel norte
				[Vector2i(36, 52), Vector2i(44, 54), 1], [Vector2i(58, 54), Vector2i(66, 52), 1],   # anel sul
			],
			"rocks": [[Vector2i(20, 20), 1], [Vector2i(20, 58), 1], [Vector2i(80, 62), 1]],
			"clear": [
				[Vector2i(51, 70), 7], [Vector2i(51, 6), 9], [Vector2i(95, 38), 8],           # bases
				[Vector2i(51, 38), 7],                                                        # cratera
			],
			"ore": [
				[Vector2i(44, 66), 2], [Vector2i(58, 66), 2],      # perto da base, pouco
				[Vector2i(28, 38), 4], [Vector2i(74, 38), 4],      # disputados, no meio
				[Vector2i(28, 58), 3], [Vector2i(74, 58), 3], [Vector2i(51, 50), 3],
			],
		},
		"player_base": Vector2i(51, 70), "enemy_base": Vector2i(51, 6), "enemy2_base": Vector2i(95, 38),
		"player_start": {
			"buildings": [["cy", Vector2i(49, 70)], ["power", Vector2i(54, 69)], ["barracks", Vector2i(45, 69)]],
			"units": [
				["hum_soldado", Vector2i(46, 64), 8], ["hum_fuzileiro", Vector2i(54, 64), 4],
				["hum_tanque", Vector2i(50, 62), 4], ["hum_artilharia", Vector2i(44, 66), 2],
				["hum_coletor", Vector2i(57, 68), 1], ["hum_engenheiro", Vector2i(58, 71), 1],
				["hum_medico", Vector2i(42, 70), 2], ["hum_transporte", Vector2i(51, 67), 1],
			],
		},
		"enemy_start": {
			"buildings": [
				["cy", Vector2i(49, 3), "nexus"], ["power", Vector2i(44, 2)], ["power", Vector2i(56, 2)],
				["barracks", Vector2i(42, 8)], ["factory", Vector2i(55, 7)], ["starport", Vector2i(49, 9)],
				["turret", Vector2i(46, 14)], ["turret", Vector2i(55, 14)],
			],
			"units": [
				["rob_rifle", Vector2i(49, 16), 5], ["rob_tank", Vector2i(45, 16), 2],
				["rob_heavy", Vector2i(53, 17), 1], ["rob_fighter", Vector2i(50, 13), 2],
			],
		},
		"enemy2_start": {
			"buildings": [
				["cy", Vector2i(94, 37), "colmeia"], ["power", Vector2i(98, 32)], ["power", Vector2i(98, 43)],
				["barracks", Vector2i(90, 32)], ["barracks", Vector2i(90, 43)],
				["turret", Vector2i(87, 35)], ["turret", Vector2i(87, 41)],
				# o Núcleo Primordial, no centro da cratera, com a guarda do Enxame
				["cy", Vector2i(50, 37), "nucleo"],
				["turret", Vector2i(47, 35)], ["turret", Vector2i(54, 35)],
				["turret", Vector2i(47, 41)], ["turret", Vector2i(54, 41)],
			],
			"units": [
				["ins_rifle", Vector2i(84, 37), 6], ["ins_tank", Vector2i(88, 39), 1], ["ins_heavy", Vector2i(90, 38), 1],
				["ins_mg", Vector2i(51, 44), 3],
			],
		},
		"ai": {"first_wave": 300.0, "wave_size": 8, "produce": true, "difficulty": "dificil"},
		"ai2": {"first_wave": 240.0, "wave_size": 10, "produce": true, "difficulty": "dificil"},
		"objectives": [
			{"id": "base", "type": "build", "building": "factory",
				"text": "Estabelecer uma base de ataque (construir a Mecânica)"},
			{"id": "minerio", "type": "have", "unit": "hum_coletor", "count": 3,
				"text": "Conquistar os depósitos de minério (3 Coletores)"},
			{"id": "nexus", "type": "destroy_tag", "tag": "nexus",
				"text": "Destruir a base robótica, ao norte"},
			{"id": "colmeia", "type": "destroy_tag", "tag": "colmeia",
				"text": "Destruir a colmeia principal, a leste"},
			{"id": "nucleo", "type": "destroy_tag", "tag": "nucleo",
				"text": "Destruir o Núcleo Primordial, no centro da cratera"},
		],
		"defeat": {"type": "lose_building", "building": "cy",
			"text": "A base de ataque caiu. A Cratera Zero está perdida."},
		"events": [
			{"at": "start", "speaker": "General Kane",
				"text": "Esta é a nossa última operação em Kharon. Base ao sul, minério da cratera, e depois o Núcleo. Ninguém volta sem ele destruído."},
			{"at": "time", "t": 40.0, "speaker": "NEXUS",
				"text": "O Núcleo pertence às máquinas. Nós o encontramos. Nós o compreendemos. Retirem-se."},
			{"at": "time", "t": 200.0, "speaker": "A Matriarca",
				"text": "(um rugido atravessa a cratera; o chão treme a leste)",
				"wave": {"units": [["ins_tank", 1], ["ins_rifle", 6], ["ins_smg", 4]], "from": Vector2i(84, 44),
					"target": "player_base", "team": 2}},
			{"at": "time", "t": 380.0, "speaker": "Vigia avançado",
				"text": "Máquinas descendo do norte, com blindados pesados!",
				"wave": {"units": [["rob_heavy", 1], ["rob_tank", 2], ["rob_rifle", 5]], "from": Vector2i(51, 18),
					"target": "player_base"}},
			{"at": "objective", "id": "nexus", "speaker": "General Kane",
				"text": "As máquinas caíram. Agora a colmeia, e depois o centro."},
			{"at": "objective", "id": "colmeia", "speaker": "A Matriarca",
				"text": "(um grito agudo vem do centro da cratera; o Núcleo pulsa mais forte)",
				"wave": {"units": [["ins_heavy", 1], ["ins_rifle", 5], ["ins_mg", 3]], "from": Vector2i(51, 46),
					"target": "player_base", "team": 2}},
			{"at": "objective", "id": "nucleo", "speaker": "Comando de Kharon",
				"text": "Kane, leitura de energia fora da escala! Retirem as tropas da cratera, agora!"},
		],
	},
}
