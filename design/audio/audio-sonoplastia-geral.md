# Áudio: Sonoplastia Geral — Crônicas da Extinção

Status: aprovado pelo autor em 2026-11-03 (`/team-audio`). Compilado do rascunho do
sound-designer (`production/audio/sonoplastia-geral/sfx-spec.md`). O kit ainda não tem
nenhum som (`assets/audio/` não existe).

## Decisões do autor (2026-11-03)

- **Fontes dos sons: mix sugerido.** S = síntese procedural por script (interface, lasers,
  motores, energia, minério, ambiente); B = biblioteca CC0 (Kenney/Freesound CC0, conferir a
  licença arquivo a arquivo; explosões, impactos, mortes); E = encomenda ou IA de áudio
  (música, locutor de base, rádio da campanha). A coluna "fonte" das tabelas abaixo vale.
- **Acessibilidade: criar aviso visual** para os quatro eventos que hoje só teriam som —
  unidade pronta, coletor atacado fora da tela, prédio perdido fora da tela e veio de minério
  esgotado — com mensagem na tela e pisca no minimapa, como o alerta de base. Entra na mesma
  implementação do áudio.
- **Já têm aviso visual (conferido no código):** fila cheia, recursos insuficientes,
  construção pronta para posicionar, limite de população (`Game.notify`), contagem de 3 s do
  multiplayer (`menu.gd`) e transmissões de rádio (painel de texto de `mission.gd`, que já
  funciona como legenda).

## Pendências

- Convenção de ids (`sfx_` / `vo_` / `mus_` / `amb_`) proposta pelo sound-designer; sem guia
  de nomenclatura de áudio no projeto.
- Contagem de falas de rádio (~170) é estimativa: o roteiro das 21 missões não foi lido.
- Comportamento do áudio na build Web (desbloqueio do contexto de áudio, latência) precisa de
  validação numa build real.
- Orçamento de voz e música (TTS de protótipo ou atuação para Kane e o locutor) e o limite de
  15 MB na Web não foram decididos.
- Não rodaram nesta passada (team.size individual): audio-director, accessibility-specialist,
  technical-artist, godot-specialist (validação da integração no Godot) e gameplay-programmer
  (implementação). As seções de direção, acessibilidade e barramentos foram cobertas pelo
  sound-designer.

---

## 1. Identidade sonora

**Geral.** Guerra de sobrevivência num planeta moribundo (Kharon). Mundo sonoro seco, sujo e opressivo, à la Command & Conquer: pouca reverb, graves presentes, rádio com estática, alertas de base curtos e legíveis. Contraste de timbre entre facções deve ser identificável com a tela desligada, usando 3 famílias: metal/orquestra marcial (Império), síntese fria/digital (Legião), orgânico/úmido/estridente (Enxame). Minério azul = única "nota limpa e cristalina" do jogo: timbre de vidro/sino agudo, reservado a coleta e depósito.

| Facção | Paleta | Timbres | Palavras-chave |
|---|---|---|---|
| Império da Cinza | Aço, pólvora, brass, caixa militar, rádio AM | Tiros secos de estampido grave; motores diesel pesados; vozes humanas em PT-BR, tom de comando | fé, disciplina, aço, solenidade |
| Legião Sintética | Servo, relé, sub-bass, FM/sine, bitcrush leve, vocoder | Passos hidráulicos lentos e pesados; bipes de telemetria; voz do NEXUS sintética, sem emoção | frio, pesado, metódico, inevitável |
| Enxame Abissal | Quitina estalando, líquidos, guinchos, ressonância de ninho, ácido chiando | Cliques e chiados rápidos, camadas numerosas e curtas; sem palavras (só sons de criatura) | enxame, úmido, estridente, vivo |
| Ambiente de Kharon | Vento de cinzas, rumor distante, cristal de minério zumbindo | Cama grave constante + eventos esparsos | árido, vazio, ameaça |

Princípio de mix de fonte por facção: mesmo tipo de arma (rifle, canhão etc.) compartilha o evento base; a facção entra como camada/variante só onde o timbre decide a leitura (ver armas Legião e Enxame).

## 2. Direção de música e ambiente

Música de composição/direção pertence ao audio-director; abaixo é a proposta para ele aprovar.

- **Menu / sala de espera:** tema sombrio, pad grave + percussão esparsa; sobre ele `amb_menu_ship_flyby` (naves cruzando o fundo: passagem de turbina com Doppler fake, pan esquerda→direita sincronizado à posição da nave). Sala de espera MP reutiliza `mus_menu` (menos arquivos).
- **Briefing:** loop tenso curto, instrumentação mínima; some quando a transmissão fala (ducking) e volta no fim.
- **Partida (adaptativa simples):** por facção, 2 stems loop sincronizados (mesmo BPM/duração, 60–90 s): `calm` e `combat`. Gatilho: combate = ≥1 unidade/prédio do jogador sofrendo ou causando dano nos últimos 8 s; volta ao calm após 20 s sem combate. Crossfade de 3 s (stems tocam em paralelo e o volume troca), sem análise musical. Império: marcha lenta de caixa + metais graves + coral solene. Legião: pulso sintético sequenciado, drones, sem melodia humana. Enxame: percussão orgânica, cordas dissonantes, glissandos agudos.
- **Vitória / derrota:** stingers de 8–15 s (`Game.game_ended`), música da partida cai em 1 s. Vitória: tema da facção em tom maior/resolvido; derrota: queda lenta, silêncio de 2 s.
- **Ambiente do planeta:** cama `amb_kharon_wind_loop` constante no barramento Ambiente (-18 dB), eventos esporádicos a cada 15–40 s aleatórios. Posicionais: zumbido de cristal perto de minério, "rastejar" do Enxame perto de ninhos (só com prédio visível). Ambiente cai 10 dB durante ducking de rádio.

## 3. Lista de eventos sonoros

Colunas: pitch = variação aleatória por disparo; pos = posicional (AudioStreamPlayer2D com atenuação; só toca se visível na câmera + margem, ou dentro de 1,5x o viewport); vozes = limite simultâneo do evento; arq = nº de arquivos (variações); fonte S/B/E.

### 3.1 Combate — armas e impactos (barramento Efeitos/Combate)

Gancho comum: `Entity.fire()` / `Entity._shoot()` (disparo); impacto = chegada do projétil (at/cannon/missile) ou instantâneo no raio (demais). Cooldown anti-metralhadora: dentro do mesmo evento, mínimo 40 ms entre disparos de uma mesma unidade; descartar disparos de unidade fora da tela.

| # | id | Gatilho / gancho | arq | Prio | Vol dB | Pitch | Pos | Vozes | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 1 | sfx_weapon_rifle_fire | rifle "fuzil laser", `_shoot()` | 3 | 2 | -8 | ±6% | Sim | 8 | S |
| 2 | sfx_weapon_smg_fire | smg "curto alcance" | 3 | 3 | -10 | ±8% | Sim | 6 | S |
| 3 | sfx_weapon_mg_fire | mg "fogo rápido" (rajada curta, sem loop) | 3 | 3 | -9 | ±8% | Sim | 6 | S |
| 4 | sfx_weapon_sniper_fire | sniper "precisão" (estalo + cauda) | 2 | 2 | -4 | ±3% | Sim | 3 | S |
| 5 | sfx_weapon_at_fire | at "antiblindagem" (lançamento) | 2 | 2 | -5 | ±4% | Sim | 4 | B |
| 6 | sfx_weapon_cannon_fire | cannon "canhão pesado" | 2 | 1 | -2 | ±4% | Sim | 4 | B |
| 7 | sfx_weapon_missile_launch | missile "mísseis" | 2 | 2 | -4 | ±5% | Sim | 4 | B |
| 8 | sfx_weapon_missile_flight | projétil em voo (loop curto, só míssil) | 1 | 3 | -14 | ±5% | Sim | 3 | S |
| 9 | sfx_weapon_legion_pulse_fire | rifle/mg disparado por unidade da Legião (substitui 1/3 no tom) | 3 | 2 | -8 | ±6% | Sim | 6 | S |
| 10 | sfx_weapon_acid_spit_fire | ataque de unidade do Enxame (cuspe) | 3 | 3 | -10 | ±8% | Sim | 6 | S |
| 11 | sfx_impact_beam | impacto de raio instantâneo (rifle/smg/mg/sniper) | 3 | 3 | -12 | ±8% | Sim | 6 | S |
| 12 | sfx_impact_at | impacto at | 2 | 2 | -5 | ±5% | Sim | 3 | B |
| 13 | sfx_impact_cannon | impacto cannon | 2 | 1 | -3 | ±5% | Sim | 3 | B |
| 14 | sfx_impact_missile | impacto missile | 2 | 2 | -4 | ±5% | Sim | 4 | B |
| 15 | sfx_impact_acid | impacto de ácido (chiado) | 2 | 3 | -12 | ±8% | Sim | 4 | S |

### 3.2 Combate — mortes, explosões, naves caindo

Gancho: `die()` em entity/unit/building.

| # | id | Gatilho / gancho | arq | Prio | Vol dB | Pitch | Pos | Vozes | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 16 | sfx_death_infantry_human | morte normal de infantaria | 3 | 3 | -10 | ±10% | Sim | 4 | B |
| 17 | sfx_death_infantry_forward | morte caindo para a frente | 2 | 3 | -10 | ±10% | Sim | 3 | B |
| 18 | sfx_death_infantry_explode | morte por explosão | 2 | 2 | -6 | ±8% | Sim | 3 | B |
| 19 | sfx_death_robot | morte de unidade da Legião (curto-circuito + metal) | 3 | 2 | -6 | ±8% | Sim | 4 | S |
| 20 | sfx_death_insect | morte de inseto (estalo úmido) | 3 | 3 | -11 | ±12% | Sim | 5 | S |
| 21 | sfx_explosion_vehicle | morte de veículo/carcaça | 3 | 2 | -4 | ±6% | Sim | 3 | B |
| 22 | sfx_explosion_building_small | prédio pequeno destruído | 2 | 2 | -3 | ±5% | Sim | 2 | B |
| 23 | sfx_explosion_building_large | centro de comando / Núcleo Primordial destruído | 2 | 1 | 0 | ±3% | Sim (alcance amplo) | 1 | B |
| 24 | sfx_explosion_organic_burst | ninho do Enxame destruído (estouro viscoso) | 2 | 2 | -4 | ±6% | Sim | 2 | S |
| 25 | sfx_air_crash_spin | nave abatida girando (loop curto agudo descendo, dura a queda) | 1 | 2 | -8 | desce 30% ao longo da queda | Sim | 2 | S |
| 26 | sfx_air_crash_impact | nave toca o solo | 2 | 1 | -2 | ±5% | Sim | 2 | B |
| 27 | sfx_corpse_burn_loop | carcaça de veículo queimando (loop, some ao desaparecer) | 1 | 3 | -20 | ±5% | Sim | 3 | S |

### 3.3 Unidade — movimento, transporte, cura (barramento Efeitos)

| # | id | Gatilho / gancho | arq | Prio | Vol dB | Pitch | Pos | Vozes | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 28 | sfx_unit_move_tracked_loop | tanque/artilharia/coletor/transporte em movimento (loop, fade 150 ms) | 1 | 3 | -16 | ±5% | Sim | 6 | S |
| 29 | sfx_unit_move_walker_loop | andadores da Legião (passo hidráulico) | 1 | 3 | -15 | ±5% | Sim | 6 | S |
| 30 | sfx_unit_move_skitter_loop | insetos em movimento (limitado a 1 loop por grupo próximo) | 1 | 3 | -18 | ±8% | Sim | 4 | S |
| 31 | sfx_air_fighter_loop | caça em voo | 1 | 3 | -14 | ±4% | Sim | 3 | S |
| 32 | sfx_air_transport_loop | nave de transporte em voo | 1 | 3 | -14 | ±4% | Sim | 2 | S |
| 33 | sfx_air_cruiser_loop | cruzador em voo (grave profundo) | 1 | 2 | -10 | ±3% | Sim | 2 | S |
| 34 | sfx_unit_board | embarcar no transporte | 2 | 3 | -10 | ±6% | Sim | 3 | S |
| 35 | sfx_unit_unload | desembarcar | 2 | 3 | -10 | ±6% | Sim | 3 | S |
| 36 | sfx_unit_heal_medic | cura de médico do Império (zumbido + bip) | 1 | 3 | -14 | ±5% | Sim | 3 | S |
| 37 | sfx_unit_heal_spores | cura por esporos do Enxame (sopro úmido) | 1 | 3 | -14 | ±5% | Sim | 3 | S |

### 3.4 Unidade — seleção e ordens (barramento Vozes; Legião e Enxame sem palavras, no barramento Efeitos)

Gancho: seleção/ordem no controlador de entrada (ordens mover, atacar, patrulha, parar, defender, agressivo). Cooldown: 1 reação a cada 600 ms; ordem em massa toca 1 só.

| # | id | Gatilho | arq | Prio | Vol dB | Pitch | Pos | Vozes | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 38 | vo_unit_imp_select | selecionar unidade do Império (frases curtas "Aguardando ordens") | 4 | 2 | -6 | ±3% | Não | 1 | E |
| 39 | vo_unit_imp_move | ordem de mover | 4 | 2 | -6 | ±3% | Não | 1 | E |
| 40 | vo_unit_imp_attack | ordem de atacar | 3 | 2 | -6 | ±3% | Não | 1 | E |
| 41 | vo_unit_imp_order_other | patrulha / parar / defender / agressivo | 4 | 2 | -6 | ±3% | Não | 1 | E |
| 42 | sfx_unit_leg_select | selecionar unidade da Legião (bipe de telemetria) | 2 | 2 | -10 | ±4% | Não | 1 | S |
| 43 | sfx_unit_leg_order | qualquer ordem (trinado digital) | 3 | 2 | -10 | ±4% | Não | 1 | S |
| 44 | sfx_unit_swarm_select | selecionar unidade do Enxame (chiado curto) | 2 | 2 | -10 | ±8% | Não | 1 | S |
| 45 | sfx_unit_swarm_order | qualquer ordem (guincho) | 3 | 2 | -10 | ±8% | Não | 1 | S |

### 3.5 Prédios (barramento Efeitos)

| # | id | Gatilho / gancho | arq | Prio | Vol dB | Pitch | Pos | Vozes | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 46 | sfx_building_print_loop | prédio "impresso" de baixo para cima, dura até 2,5 s; um arquivo por facção (Império: solda/pistões; Legião: laser + servo; Enxame: crescimento úmido) | 3 | 2 | -8 | ±3% | Sim | 3 | S |
| 47 | sfx_building_print_done | fim da impressão (batida pesada) | 3 | 2 | -5 | ±3% | Sim | 3 | S |
| 48 | sfx_building_recycle | reciclar (faíscas, sem explosão) | 2 | 2 | -8 | ±6% | Sim | 2 | S |
| 49 | sfx_building_repair_loop | conserto 5%/s (solda/estalo, loop) | 1 | 3 | -15 | ±4% | Sim | 3 | S |
| 50 | sfx_building_power_down | energia baixa começa (queda de gerador) | 1 | 1 | -6 | 0 | Não | 1 | S |
| 51 | sfx_building_power_up | energia volta ao normal | 1 | 1 | -6 | 0 | Não | 1 | S |
| 52 | sfx_building_turret_offline | torre desliga por falta de energia | 1 | 2 | -9 | ±5% | Sim | 3 | S |
| 53 | sfx_building_refinery_work_loop | refinaria processando (loop durante descarga) | 1 | 3 | -16 | ±3% | Sim | 2 | S |
| 54 | sfx_building_hum_loop | zumbido de prédio de energia (ambiente, só perto) | 1 | 3 | -24 | 0 | Sim | 2 | S |
| 55 | sfx_building_heal_station_pulse | hospital/estação de cura ativa | 1 | 3 | -14 | ±4% | Sim | 2 | S |
| 56 | sfx_building_unit_spawn | unidade sai da fábrica/quartel/hangar | 2 | 2 | -9 | ±5% | Sim | 3 | S |

### 3.6 Economia (barramento Efeitos; fica no timbre de cristal)

| # | id | Gatilho | arq | Prio | Vol dB | Pitch | Pos | Vozes | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 57 | sfx_eco_harvest_loop | coletor extraindo minério | 1 | 3 | -16 | ±4% | Sim | 3 | S |
| 58 | sfx_eco_harvester_full | coletor cheio (sino curto) | 1 | 3 | -14 | ±4% | Sim | 2 | S |
| 59 | sfx_eco_unload | descarga de minério na refinaria (cascata de cristal) | 2 | 3 | -11 | ±5% | Sim | 3 | S |
| 60 | sfx_eco_deposit_credit | crédito soma ao saldo (tick no HUD, limitado a 1 por 400 ms) | 1 | 3 | -16 | ±5% | Não | 1 | S |
| 61 | sfx_eco_node_depleted | veio de minério esgotado | 1 | 2 | -10 | 0 | Sim | 1 | S |

### 3.7 Alertas e voz do "locutor de base" (barramento Vozes; Império e Legião falados, Enxame só stinger + texto)

Locutor: Império = voz feminina/masculina de comando (PT-BR); Legião = voz NEXUS sintética; Enxame = sem palavras (usa o stinger não verbal #72 e o texto). Um arquivo por facção para cada evento falado (2 arquivos/evento). Fila de voz: toca uma por vez, no máximo 2 pendentes, descartando por prioridade.

| # | id | Gatilho / gancho | arq | Prio | Vol dB | Pitch | Pos | Vozes | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 62 | vo_alert_base_under_attack | `Game.base_alert(building)`; cooldown 12 s (igual ao motor) | 2 | 1 | -3 | 0 | Não | 1 | E |
| 63 | vo_alert_harvester_attacked | coletor sofrendo dano, cooldown 15 s | 2 | 1 | -3 | 0 | Não | 1 | E |
| 64 | vo_alert_low_power | energia baixa (junto de #50), repete a cada 30 s enquanto durar | 2 | 1 | -3 | 0 | Não | 1 | E |
| 65 | vo_alert_power_restored | energia restaurada | 2 | 2 | -3 | 0 | Não | 1 | E |
| 66 | vo_alert_unit_ready | unidade pronta | 2 | 2 | -4 | 0 | Não | 1 | E |
| 67 | vo_alert_building_ready | construção pronta para posicionar | 2 | 1 | -3 | 0 | Não | 1 | E |
| 68 | vo_alert_queue_full | tentativa com fila cheia | 2 | 3 | -4 | 0 | Não | 1 | E |
| 69 | vo_alert_insufficient_funds | recursos insuficientes | 2 | 2 | -3 | 0 | Não | 1 | E |
| 70 | vo_alert_pop_limit | limite de população | 2 | 2 | -3 | 0 | Não | 1 | E |
| 71 | vo_alert_building_lost | prédio destruído | 2 | 2 | -3 | 0 | Não | 1 | E |
| 72 | sfx_alert_base_attack_sting | stinger não verbal antes/depois da fala; único alerta do Enxame (um arquivo por facção) | 3 | 1 | -4 | 0 | Não | 1 | S |
| 73 | sfx_alert_low_power_pulse | pulso curto acompanhando o aviso piscando, a cada piscada | 1 | 2 | -12 | 0 | Não | 1 | S |

### 3.8 Campanha e rádio (barramento Vozes)

Gancho: `Game.message(text)` para texto de transmissão; briefing e objetivos no `scripts/mission.gd`; `Game.game_ended(player_won)`.
Estimativa de falas: 7 missões × 3 facções × ~8 falas = ~170 falas. Missões H01 e H02 já estão prontas, então começa por elas (~16 falas).

| # | id | Gatilho | arq | Prio | Vol dB | Pitch | Pos | Vozes | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 74 | vo_radio_kane | General Kane (Império) | ~40 | 1 | -2 | 0 | Não | 1 | E |
| 75 | vo_radio_kharon | Comando de Kharon | ~30 | 1 | -2 | 0 | Não | 1 | E |
| 76 | vo_radio_vigia | Vigia avançado | ~20 | 1 | -2 | 0 | Não | 1 | E |
| 77 | vo_radio_tenente | Tenente de Engenharia | ~20 | 1 | -2 | 0 | Não | 1 | E |
| 78 | vo_radio_nexus | NEXUS (Legião) | ~35 | 1 | -2 | 0 | Não | 1 | E |
| 79 | vo_radio_hive | Núcleo Primordial (Enxame, voz-colmeia processada) | ~25 | 1 | -2 | 0 | Não | 1 | E |
| 80 | sfx_radio_open | início da transmissão (squelch) | 2 | 1 | -8 | ±3% | Não | 1 | S |
| 81 | sfx_radio_close | fim da transmissão | 2 | 1 | -8 | ±3% | Não | 1 | S |
| 82 | sfx_radio_static_loop | estática sob a fala (cama de -26 dB) | 1 | 3 | -26 | 0 | Não | 1 | S |
| 83 | sfx_ui_briefing_type | tick de texto "digitando" no briefing | 2 | 3 | -18 | ±6% | Não | 1 | S |
| 84 | sfx_ui_objective_complete | objetivo cumprido | 1 | 1 | -4 | 0 | Não | 1 | S |
| 85 | sfx_ui_objective_new | novo objetivo | 1 | 2 | -6 | 0 | Não | 1 | S |
| 86 | sfx_ui_mission_start | início de partida (corte do briefing) | 1 | 2 | -6 | 0 | Não | 1 | S |
| 87 | vo_alert_mission_accomplished | vitória (`game_ended(true)`), por facção | 2 | 1 | -2 | 0 | Não | 1 | E |
| 88 | vo_alert_mission_failed | derrota (`game_ended(false)`), por facção | 2 | 1 | -2 | 0 | Não | 1 | E |

### 3.9 Interface (barramento Interface)

| # | id | Gatilho | arq | Prio | Vol dB | Pitch | Pos | Vozes | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 89 | sfx_ui_click | clique de botão | 3 | 2 | -10 | ±3% | Não | 2 | S |
| 90 | sfx_ui_hover | passar sobre botão | 2 | 3 | -20 | ±3% | Não | 1 | S |
| 91 | sfx_ui_back | voltar/cancelar menu | 1 | 3 | -12 | 0 | Não | 1 | S |
| 92 | sfx_ui_error | ação inválida (sem recurso, fila cheia) | 1 | 2 | -10 | 0 | Não | 1 | S |
| 93 | sfx_ui_selection_confirm | seleção de unidade/caixa de seleção (clique seco) | 3 | 3 | -16 | ±4% | Não | 1 | S |
| 94 | sfx_ui_order_move_marker | marcador de mover no chão | 1 | 3 | -14 | ±4% | Não | 1 | S |
| 95 | sfx_ui_order_attack_marker | marcador de atacar | 1 | 3 | -12 | ±4% | Não | 1 | S |
| 96 | sfx_ui_build_queue_add | item entra na fila | 1 | 2 | -10 | ±3% | Não | 1 | S |
| 97 | sfx_ui_build_queue_cancel | cancelar item da fila | 1 | 3 | -12 | 0 | Não | 1 | S |
| 98 | sfx_ui_place_ok | posicionar prédio (confirmar) | 1 | 2 | -8 | 0 | Não | 1 | S |
| 99 | sfx_ui_place_invalid | posição inválida | 1 | 2 | -10 | 0 | Não | 1 | S |
| 100 | sfx_ui_message_pop | `Game.message(text)` aparece na tela | 1 | 3 | -16 | 0 | Não | 1 | S |
| 101 | sfx_ui_chat_message | chat MP recebido | 1 | 3 | -14 | 0 | Não | 1 | S |
| 102 | sfx_ui_countdown_tick | contagem de 3 s MP (3, 2, 1) | 1 | 1 | -8 | 0 | Não | 1 | S |
| 103 | sfx_ui_countdown_go | fim da contagem | 1 | 1 | -6 | 0 | Não | 1 | S |
| 104 | sfx_ui_lobby_join | jogador entra na sala | 1 | 3 | -12 | 0 | Não | 1 | S |
| 105 | sfx_ui_lobby_leave | jogador sai da sala | 1 | 3 | -12 | 0 | Não | 1 | S |
| 106 | sfx_ui_ready_toggle | marcar "pronto" | 1 | 3 | -12 | 0 | Não | 1 | S |
| 107 | sfx_ui_pause | pausa/retomar | 1 | 2 | -10 | 0 | Não | 1 | S |
| 108 | sfx_ui_minimap_ping | pulso do minimapa no `base_alert` | 1 | 2 | -10 | 0 | Não | 1 | S |
| 109 | sfx_ui_group_assign | atribuir grupo de controle | 1 | 3 | -14 | 0 | Não | 1 | S |

### 3.10 Música (barramento Música)

Streaming (não carregar em memória). Loops 60–90 s a 64 kbps estéreo.

| # | id | Uso | arq | Prio | Vol dB | Fonte |
|---|---|---|---|---|---|---|
| 110 | mus_menu | menu e sala de espera | 1 | 2 | -10 | E |
| 111 | mus_briefing | briefing | 1 | 2 | -12 | E |
| 112 | mus_match_imp_calm | partida Império, calma | 1 | 2 | -12 | E |
| 113 | mus_match_imp_combat | partida Império, combate | 1 | 2 | -12 | E |
| 114 | mus_match_leg_calm | Legião, calma | 1 | 2 | -12 | E |
| 115 | mus_match_leg_combat | Legião, combate | 1 | 2 | -12 | E |
| 116 | mus_match_enx_calm | Enxame, calma | 1 | 2 | -12 | E |
| 117 | mus_match_enx_combat | Enxame, combate | 1 | 2 | -12 | E |
| 118 | mus_victory | stinger de vitória (3 variações por facção opcional, 1 no mínimo) | 1 | 1 | -8 | E |
| 119 | mus_defeat | stinger de derrota | 1 | 1 | -8 | E |

### 3.11 Ambiente (barramento Efeitos/Ambiente)

| # | id | Uso | arq | Prio | Vol dB | Pitch | Pos | Vozes | Fonte |
|---|---|---|---|---|---|---|---|---|---|
| 120 | amb_kharon_wind_loop | cama de vento/cinza da partida (loop 30 s) | 1 | 3 | -18 | 0 | Não | 1 | S |
| 121 | amb_kharon_detail | eventos esparsos (rumor, estrondo distante, rajada), 15–40 s | 4 | 3 | -22 | ±10% | Não (pan aleatório) | 1 | B |
| 122 | amb_ore_crystal_hum | zumbido do minério (perto da câmera) | 1 | 3 | -24 | ±3% | Sim | 3 | S |
| 123 | amb_swarm_creep_loop | rastejar perto de ninho visível | 1 | 3 | -22 | ±4% | Sim | 2 | S |
| 124 | amb_menu_ship_flyby | naves cruzando o fundo do menu | 3 | 3 | -12 | ±5% | Não (pan acompanha a nave) | 2 | S |

### 3.12 Regras gerais de voz simultânea e orçamento de CPU

- Teto global: 32 vozes de efeito (reduzir a 24 na Web), contando loops. Quando passar do teto, cortar prioridade 3 mais distante primeiro, depois prioridade 2.
- Loops de movimento/trabalho: um loop por tipo por "cluster" de unidades dentro de ~200 px, em vez de um por unidade; volume sobe 1,5 dB por unidade adicional até +4 dB.
- Tudo posicional usa atenuação linear + filtro passa-baixa conforme a distância: distância mínima = metade da tela, máxima = 1,5x o viewport. Explosão grande (#23) tem alcance cheio. Prioridade 1 ignora o corte por distância.
- Sem reverb nos efeitos (mantém seco e barato na Web); um único reverb curto (0,6 s) no barramento Vozes para dar sensação de rádio/sala, a ser decidido pelo audio-director.

## 4. Barramentos e ducking

```
Master
├── Música        (-6 dB)  — streaming
├── Efeitos       (0 dB)
│   ├── Combate   (-2 dB)  — armas, impactos, explosões, movimento
│   └── Ambiente  (-4 dB)  — camas, zumbidos, vento
├── Interface     (-2 dB)  — UI, marcadores, contagem
└── Vozes         (0 dB)   — locutor de base, rádio, reações de unidades
```

Limitador no Master (-1 dB) para evitar clipping em batalhas grandes. Sliders do jogador: Master, Música, Efeitos, Interface, Vozes.

| Gatilho | Abaixa | Quantidade | Ataque / Release |
|---|---|---|---|
| Transmissão de rádio (#74–79) | Música | -10 dB | 100 ms / 1000 ms |
| Transmissão de rádio | Combate | -6 dB | 100 ms / 800 ms |
| Transmissão de rádio | Ambiente | -10 dB | 100 ms / 1000 ms |
| Alerta do locutor (#62–71) | Música | -5 dB | 60 ms / 600 ms |
| Alerta do locutor | Combate | -3 dB, só se prioridade 3 | 60 ms / 500 ms |
| Explosão grande (#23, #26) | Música + Ambiente | -4 dB, 1,2 s | 20 ms / 800 ms |
| Vitória/derrota (#118–119) | Música da partida, Combate, Ambiente | silêncio em 1 s | 200 ms / sem retorno |
| Pausa | Música: passa-baixa 800 Hz, -6 dB; Combate/Ambiente mudo | | 100 ms |

Prioridade entre vozes: rádio de campanha > alerta prioridade 1 > alerta prioridade 2 > reação de unidade. Rádio em curso segura os alertas por até 6 s; depois eles são descartados (o texto na tela continua).
Implementação (para o programador que a audio-director designar): sidechain via efeito de compressor no barramento de Música com origem em Vozes, ou volume animado por script; a escolha técnica fica com o technical-artist/programador, nenhum código aqui.

Orçamento técnico Godot/Web: efeitos curtos em WAV de baixa taxa decodificados na carga ou OGG mono 44,1 kHz q3 (o spec abaixo assume OGG); música em streaming. Validar em build Web que o modo de reprodução de áudio escolhido não degrade a latência e que o contexto de áudio só inicia depois do primeiro clique (o menu cobre isso, pois o primeiro som vem de um clique do usuário).

## 5. Acessibilidade

Princípio: nenhum som é o único canal de uma informação de jogo. Equivalentes visuais do projeto, conforme informado: mensagem na tela (`Game.message`), pisca no minimapa por 4 s (`base_alert`), aviso piscando de energia baixa. O que não foi confirmado no código está marcado "verificar" (não li o código de HUD nesta rodada; a classificação abaixo precisa de checagem do programador).

| Som | Informação carregada | Equivalente visual | Situação |
|---|---|---|---|
| vo_alert_base_under_attack (#62), sfx_ui_minimap_ping (#108) | base atacada | mensagem + pisca no minimapa 4 s | Existe |
| vo_alert_low_power (#64), #50, #73 | energia baixa, produção pela metade | aviso piscando | Existe |
| vo_alert_power_restored (#65), #51 | energia voltou | aviso para de piscar | Existe (verificar mensagem) |
| vo_alert_harvester_attacked (#63) | coletor atacado, possivelmente fora da tela | nenhum | **BLOCKING** (falta ping de minimapa e mensagem) |
| vo_alert_building_lost (#71), #22/#23 | prédio destruído fora da tela | nenhum garantido | **BLOCKING** (mensagem "Prédio perdido" + ping de minimapa) |
| vo_alert_unit_ready (#66) | unidade pronta | verificar barra/ícone de fila | **BLOCKING até confirmar** (precisa de mensagem curta ou piscar do botão) |
| vo_alert_building_ready (#67) | construção pronta para posicionar | verificar ícone "pronto" | **BLOCKING até confirmar** (botão piscando "pronto") |
| vo_alert_queue_full (#68), sfx_ui_error (#92) | fila cheia | verificar mensagem | **BLOCKING até confirmar** (mensagem via `Game.message`) |
| vo_alert_insufficient_funds (#69) | sem recursos | verificar mensagem; contador em vermelho | **BLOCKING até confirmar** |
| vo_alert_pop_limit (#70) | limite de população | verificar mensagem | **BLOCKING até confirmar** |
| sfx_eco_node_depleted (#61) | veio esgotado | nenhum | **BLOCKING** (mensagem ou marca no mapa; ver se o veio some visualmente) |
| sfx_eco_harvester_full (#58) | coletor cheio | indicador visual no coletor? | Falta/verificar, não crítico |
| vo_radio_* (#74–79), #87–88 | roteiro e objetivos da missão | texto da transmissão com nome do interlocutor | **BLOCKING para falas sem legenda**: toda fala precisa de legenda com nome do interlocutor, mesmo texto que `Game.message`, tempo mínimo de exibição calculado pelo tamanho |
| sfx_ui_objective_complete (#84), #85 | objetivo cumprido/novo | texto de objetivo + marca | Verificar |
| sfx_ui_countdown_tick/go (#102–103) | contagem de 3 s no MP | verificar número na tela | **BLOCKING até confirmar** |
| sfx_ui_chat_message (#101) | mensagem de chat | texto no chat | Existe |
| sfx_ui_lobby_join/leave (#104–105) | jogador entrou/saiu | verificar lista da sala | Verificar |
| sfx_ui_place_invalid (#99) | posição inválida | verificar cor do fantasma (vermelho) | Verificar |
| mus_victory / mus_defeat, #87–88 | fim de jogo | tela de vitória/derrota | Existe (`game_ended`) |
| Tiros, impactos, mortes, motores (#1–37) | combate fora da tela | pisca/ping de minimapa só para base | Não crítico, informação redundante com visão; o ataque a base é coberto |
| Seleção e ordens (#38–45, #93–95) | confirmação | marcador no chão e brilho da seleção | Existe (confirmar) |

Itens exigidos independentemente do áudio: opção de legendas ligada por padrão nas transmissões; sliders por barramento; opção de áudio mono; o aviso de energia baixa não pode depender só de cor (usar ícone + texto); sem sons acima de -1 dBFS.

## 6. Contagem, tamanho Web e ordem de produção

**Eventos: 124** (armas/impactos 15, mortes/explosões 12, unidade/movimento 10, vozes e sons de ordem 8, prédios 11, economia 5, alertas 12, campanha/rádio 15, interface 21, música 10, ambiente 5).

**Arquivos estimados: ~375** (≈150 efeitos/UI/ambiente de variações curtas; ≈40 falas do locutor de base [10 eventos × 2 facções + 15 do Império nas reações + stingers]; ≈170 falas de rádio; 10 músicas; resto de variantes de ambiente/UI).

**Tamanho estimado (OGG; mono nos efeitos e vozes; música estéreo 64 kbps):**

| Grupo | Arquivos | MB |
|---|---|---|
| Efeitos, UI, loops, ambiente | ~150 | 2,0 |
| Locutor de base e reações Império | ~55 | 0,7 |
| Rádio de campanha (~6 s por fala, 32 kbps) | ~170 | 4,0 |
| Música (8 loops de 60–90 s + menu/briefing e 2 stingers) | 10 | 6,5 |
| **Total** | ~375 | **~13 MB** |

Recomendação Web: limite total 15 MB. Carregamento inicial ≤ 4 MB (UI + armas + alertas do Império/Legião + `mus_menu`); o restante carregado por facção/missão em pacotes: rádio só da missão atual, música só da facção escolhida. Isso corta a carga de uma sessão típica para ~7 MB. Em build desktop, tudo no pacote.

**Recomendação de mix de fontes** (contagem aproximada de eventos): S ≈ 66 eventos (UI, loops de motor, armas laser/ácido, energia, minério, rádio estática, ambiente: tudo barato, sem licença, coerente com a estética sintética); B ≈ 26 eventos (explosões, impactos de blindagem/projétil, mortes humanas, estrondos de ambiente, onde textura real vende), todos CC0 com licença registrada em `assets/audio/LICENSES.md`; E ≈ 32 eventos (música, locutor, rádio de campanha: onde síntese não serve). Na prática: sintetize tudo o que for de interface e máquina; compre/gere apenas voz e música; use biblioteca só para os 'grandes estouros'. Voz por IA (TTS) em PT-BR é aceitável para protótipo e para Legião/NEXUS (já deve soar sintética); Império e Kane merecem voz real/atuada se houver verba.

**Ordem de produção (maior ganho primeiro):**
1. Núcleo de combate e leitura: #1–7, #11–14, #21–23, #16/#19/#20 (armas, impactos, explosões, mortes). Maior ganho de "sensação" por poucos arquivos (S+B).
2. Interface e retorno: #89–100, #98–99, #102–103 (cliques, fila, posicionar, contagem). Tudo S, rápido.
3. Alertas críticos e seus equivalentes visuais BLOCKING (seção 5): #62–73 com texto + stingers (#72) sem voz primeiro; falas depois.
4. Economia e prédios: #46–53, #57–61 (minério como assinatura sonora).
5. Música: `mus_menu` + 1 par calm/combat do Império + vitória/derrota (#110, #112–113, #118–119), depois Legião e Enxame.
6. Rádio de campanha H01 e H02 (~16 falas) + #80–86; depois o restante por missão.
7. Movimento, naves, transporte, cura (#28–37), reações de unidade (#38–45), ambiente (#120–124), polimento.
