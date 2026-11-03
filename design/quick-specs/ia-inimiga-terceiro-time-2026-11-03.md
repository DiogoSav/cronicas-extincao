# Quick Design Spec: IA inimiga — terceiro time, reconstrução, defesa e dificuldade

**Type**: Addition
**System**: IA inimiga (`scripts/ai.gd`) e times da partida (`scripts/game_state.gd`, `scripts/mission.gd`)
**GDD Reference**: `design/game-brief.md` (nível `minimal`, sem GDD) — MVP "3 campanhas completas"; roteiro `H:\Jogos\referencia facções\Cronicas_da_Extincao_Roteiro_21_Missoes.md` §1 ("Guerra total") e H04
**Date**: 2026-11-03

## Change Summary

O motor passa a aceitar dois times inimigos numa missão, cada um com sua IA, e a missão
decide se os dois são aliados ou hostis entre si. A IA ganha três comportamentos:
reconstrói e conserta prédios, defende a base quando atacada e tem níveis de dificuldade.

## Motivation

- A H04 "Linha de Defesa" pede robôs pelo norte e insetos pelo sul atacando juntos, e a
  "Guerra total" é um tipo de missão do roteiro. Hoje o motor tem só 2 times fixos.
- A IA atual nunca constrói: destruir o quartel ou a fábrica dela encerra a produção
  daquele tipo para sempre, e a missão fica fácil demais a partir daí.
- A IA não reage a ataques à base: o jogador destrói a base enquanto o exército inimigo
  espera o relógio da próxima onda.
- O roteiro marca dificuldade por missão (Fácil a Alta), mas a IA não tem como variar.

## Design Delta

Hoje (`docs/MECANICAS.md`, "IA"):

> Mantém 2 coletores, produz infantaria/veículos/naves pelos pesos, e ataca em ondas
> (a primeira aos 3 min; depois a cada exército completo ou 2 min).

Times hoje: `Game.PLAYER = 0`, `Game.ENEMY = 1`; `credits`, `production`, `queues` e
`factions` são listas de 2; inimigo = qualquer entidade de outro time (`e.team != team`).

## New Rules / Values

### 1. Terceiro time

1. Times da partida: `0` jogador, `1` inimigo, `2` segundo inimigo (novo). O
   multiplayer continua com 2 times (o time 2 só existe na campanha).
2. `credits`, `production`, `queues` e `factions` passam a ter uma entrada por time em
   uso. Escaramuça e 1v1 continuam com 2.
3. Na missão (`data/campaign.gd`), campos novos e opcionais:
   - `"enemy2"`: facção do segundo inimigo.
   - `"enemy2_base"`, `"enemy2_start"`: como `enemy_base` / `enemy_start`.
   - `"ai2"`: como `"ai"`, para o time 2.
   - `"credits"` aceita 3 valores quando há `enemy2`.
   - `"enemies_allied"`: `true` = os dois inimigos são aliados; `false` (padrão) =
     hostis entre si.
   - Ondas de evento (`events[].wave`) aceitam `"team": 2` (padrão 1).
4. Hostilidade: uma função única `Game.are_enemies(a, b)` substitui as comparações
   `e.team != team` usadas para escolher alvo (`nearest_enemy`, ataques, torres).
   Regra: times iguais nunca são inimigos; 1 e 2 são inimigos só se
   `enemies_allied == false`; o jogador é inimigo de ambos. Cura, conserto e transporte
   continuam exigindo o mesmo time.
5. Cada time inimigo tem uma instância própria de `EnemyAI` com `team` configurável (hoje
   é a constante `TEAM := 1`). O alvo das ondas de cada IA continua sendo o prédio do
   jogador mais perto da base dela. A IA não manda ondas contra o outro inimigo; se forem
   hostis, eles brigam quando se cruzam.
6. Cor do time 2: a cor da facção. Se as facções dos dois inimigos forem a mesma, o time 2
   usa uma variação mais escura (o mapa e o minimapa precisam distinguir).
7. Objetivos: `destroy_all` passa a exigir zero prédios em todos os times inimigos. Os
   objetivos `destroy_tag` já funcionam por tag e não mudam.
8. Névoa, minimapa e seleção já tratam "não é do jogador" como inimigo; o time 2 entra
   nesse caso sem mudança.

### 2. Reconstruir e consertar

1. A IA guarda a lista de prédios que existiam no início da missão (tipo + célula).
2. A cada ciclo de decisão (1,5 s), se um prédio dessa lista não existe mais e há
   dinheiro, a IA produz aquele tipo e o posiciona na mesma célula; se a célula estiver
   ocupada ou bloqueada, na célula livre mais próxima dentro da área de construção.
3. Um prédio reconstruído por vez. Ordem de prioridade: `BUILD_ORDER` de `game_data.gd`
   (energia, refinaria, quartel, fábrica…). O centro de comando (`cy`) não é
   reconstruído: sem ele a IA para de construir.
4. Prédio com vida abaixo de `repair_below` é consertado (`Game.request_repair`) se houver
   dinheiro acima de `repair_reserve`.
5. Na escaramuça (sem lista inicial), a lista é preenchida com os prédios que a IA tiver
   ao fim do primeiro minuto. `INTENT UNKNOWN` — a IA da escaramuça construir a base do
   zero não está no escopo.

### 3. Defender a base

1. Quando um prédio da IA é atingido, a IA marca o atacante e a posição.
2. Unidades do exército que não estão numa onda em andamento e estão a menos de
   `defend_radius` da base recebem ordem de atacar-andando até a posição atacada.
3. A defesa termina quando nenhum inimigo está a `defend_radius` da base por 10 s; as
   unidades voltam para a base.
4. Uma onda já enviada não é chamada de volta.

### 4. Níveis de dificuldade

Constante nova `AI_DIFFICULTY` em `data/game_data.gd`; a missão escolhe pelo campo
`"ai": {"difficulty": "facil" | "medio" | "dificil"}` (padrão `medio`). Escaramuça: um
seletor Fácil / Médio / Difícil no menu (padrão Médio) — confirmado pelo autor.

| Parâmetro | Fácil | Médio | Difícil | O que faz |
|---|---|---|---|---|
| `think` | 2,5 s | 1,5 s | 1,0 s | intervalo entre decisões |
| `income_mult` | 0,8 | 1,0 | 1,25 | multiplica o minério descarregado pela IA |
| `wave_growth` | +1 | +2 | +3 | crescimento da onda |
| `wave_max` | 12 | 16 | 22 | onda máxima |
| `wave_interval` | 150 s | 120 s | 90 s | tempo máximo entre ondas |
| `rebuild` | não | sim | sim | liga a reconstrução (seção 2) |
| `defend` | sim | sim | sim | liga a defesa (seção 3) |
| `defend_radius` | 10 cél. | 14 cél. | 18 cél. | alcance da defesa |
| `repair_below` | — | 50% | 70% | vida que dispara o conserto |
| `repair_reserve` | — | 800 | 400 | dinheiro mínimo mantido |

Os valores de `first_wave` e `wave_size` de cada missão continuam valendo e têm
prioridade sobre a dificuldade. Os números acima são ponto de partida para testes, não
balanceamento validado.

## Affected Systems

| System | Impact | Action Required |
|---|---|---|
| `scripts/game_state.gd` | listas por time, `are_enemies`, `destroy_all` | código |
| `scripts/ai.gd` | `team` configurável, reconstruir, defender, dificuldade | código |
| `scripts/mission.gd` | lê `enemy2`, `ai2`, `enemies_allied`, ondas `team` | código |
| `scripts/main.gd` | cria 1 ou 2 IAs | código |
| `scripts/menu.gd` | seletor de dificuldade da escaramuça | código |
| `scripts/entity.gd`, `unit.gd`, `building.gd`, `projectile.gd` | escolha de alvo via `are_enemies` | código |
| `scripts/harvester.gd` | `income_mult` da IA | código |
| `data/game_data.gd` | `AI_DIFFICULTY` | dados |
| `data/campaign.gd` | doc. do formato da missão; H01/H02 ganham `difficulty` | dados |
| `scripts/net.gd` | nenhum (1v1 continua com 2 times) | regressão |
| `docs/MECANICAS.md` | seções "IA" e "Campanha" | atualizar texto |

## Acceptance Criteria

- [ ] Uma missão de teste com `enemy2` cria as bases e unidades dos dois inimigos, cada
      um com sua cor, e as duas IAs mandam ondas contra o jogador.
- [ ] Com `enemies_allied: false`, unidades dos times 1 e 2 que se cruzam se atacam; com
      `true`, se ignoram.
- [ ] `destroy_all` só se cumpre quando os dois inimigos ficam sem prédios.
- [ ] Destruir o quartel da IA (Médio) faz ela reconstruí-lo no mesmo lugar quando tiver
      dinheiro; no Fácil, não.
- [ ] Atacar um prédio da IA faz as unidades paradas perto da base irem até o ataque, e
      elas voltam depois que o ataque acaba.
- [ ] Uma missão com `difficulty: "dificil"` manda ondas maiores e mais frequentes que a
      mesma missão em `"facil"` (medido pelo tamanho das ondas no log).
- [ ] Sem regressão: H01 e H02 continuam jogáveis do começo ao fim; escaramuça contra a IA
      e 1v1 online funcionam com 2 times como antes.
- [ ] Evidência: print de uma missão com três times em `production/qa/evidence/`.

## GDD Update Required?

Não há GDD (nível `minimal`). Atualizar `docs/MECANICAS.md` (seções "IA" e "Campanha")
quando o código entrar.
