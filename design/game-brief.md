---
status: reverse-documented
source: scripts/, data/, docs/MECANICAS.md, referencia facções/Cronicas_da_Extincao_Roteiro_21_Missoes.md
date: 2026-11-03
verified-by: diogo
---

# Game Brief: Crônicas da Extinção

> **Reverse-documented from implementation** — gerado por `/reverse-document` a partir de
> `scripts/` e `data/` em 2026-11-03, no commit `4f6271d`.
> Registra o que o código **faz**; MVP, multiplayer, áudio, referência, ordem das campanhas,
> salvar no meio da missão e público foram confirmados pelo autor (2026-11-03). Itens marcados `INTENT UNKNOWN` foram inferidos e não confirmados. Onde este
> documento e o código divergirem, não presuma que o documento é o requisito.

**Pitch em uma frase:** RTS de ficção científica sombria em que o Império da Cinza, a Legião
Sintética e o Enxame Abissal disputam o minério do planeta Kharon em três campanhas de sete
missões, com sprites isométricos pré-renderizados.

## Core loop
- Coletar minério com coletores → refinaria converte em créditos.
- Gastar créditos em prédios (energia sustenta produção e população) e em unidades de
  infantaria, veículos e naves.
- Montar o exército e cumprir o objetivo da missão (destruir, defender, sobreviver), contra
  ondas da IA.
- Cada missão vencida libera a próxima e conta mais da história da facção.

## Objetivo do jogador e derrota
- **Campanha:** cumprir todos os objetivos da missão (`build`, `army`, `have`,
  `destroy_tag`, `destroy_all`, `survive`). Perde ao cumprir a condição `defeat` da missão
  (ex.: perder o centro de comando).
- **Escaramuça / 1v1:** vence quem destruir todos os prédios do adversário.

## MVP — o que precisa existir para ser o jogo
- 3 campanhas completas: 21 missões do roteiro (H01–H07, Legião ×7, Enxame ×7), cada uma
  com mapa próprio. *Hoje: campanha humana H01–H07 montada (H03–H07 sem playtest); Legião e
  Enxame sem missões.*
- 3 facções jogáveis e assimétricas (5 de infantaria, 4 veículos, 3 naves e o mesmo
  conjunto de prédios por facção). *Hoje: dados completos; sprites em produção.*
- Escaramuça contra a IA. *Hoje: pronta.*
- Multiplayer 1v1 online (WebRTC, anfitrião autoritativo). *Hoje: pronto, herdado do kit.*
- Salvar e carregar no meio da missão (campanha). *Hoje: o progresso é salvo só por missão
  concluída (`user://campanha.cfg`).*
- Áudio: efeitos (tiros, explosões, alertas de base) e música. *Hoje: efeitos de combate,
  interface e alertas prontos (passo 1 de `design/audio/audio-sonoplastia-geral.md`); sem
  música nem vozes.*
- Versões PC (Windows) e Web.

## Fora de escopo
- Novos recursos econômicos: um único recurso, o Minério (roteiro §1).
- Reconstruir os sistemas do motor: as missões usam as mecânicas existentes e objetivos que
  o jogo já verifica (roteiro §1).
- `INTENT UNKNOWN` — inferido, não confirmado: multiplayer com mais de 2 jogadores, editor de
  mapas.

## Ordem de construção
1. Campanha humana H03–H07 (mais objetivos e eventos com o motor que existe).
2. Salvar e carregar no meio da missão.
3. Campanha da Legião Sintética (7 missões), depois a do Enxame Abissal (7 missões).
4. Áudio: restante da sonoplastia (economia, prédios, música, rádio da campanha).
5. Balanceamento entre as facções para escaramuça e 1v1.
6. Exportação e publicação para PC e Web.

---
**Para quem / o que sente:** jogadores de PC jovens e adultos (15 a 45 anos), majoritariamente
homens, entusiastas de estratégia e de ficção científica militar; querem uma campanha com
história e sentir o desespero de uma guerra pela sobrevivência em Kharon.

**Direção de arte e áudio:** ficção científica sombria, sprites pré-renderizados em
Blender/Cycles numa vista isométrica (30°), pixelizados; cada facção com uma cor (vermelho
do Império, laranja da Legião, verde-ácido do Enxame). Áudio: `design/audio/audio-sonoplastia-geral.md`.

**Jogo de referência:** Command & Conquer (Red Alert / Tiberian). O MVP mantém a economia de
coletor, refinaria e energia, a construção de base e a campanha com briefings e transmissões.
