# Análise de Fase do Projeto

**Data**: 2026-11-03
**Fase**: Produção (observada)
**Confiança da fase**: CONCERNS — a raiz de código que o framework resolve (`src/`, padrão Godot) está vazia; o código real está em `scripts/` e `data/`. Contado à mão, o projeto está claramente em Produção; as ferramentas automáticas (`project-state.sh`, hooks, statusline) veem 0 arquivos e inferem "Conceito".
**Fase configurada**: nenhuma (`project.stage` ausente). No nível `minimal` nada roda `/gate-check`, então isso é esperado.
**Nível de workflow**: `minimal` — sem GDDs, ADRs, épicos ou sprints esperados; o documento de design é `design/game-brief.md`.

## Visão geral
- **Motor**: Godot 4.7.2, GDScript — configurado por `/setup-engine` nesta data (`project.yaml`).
- **Código**: 31 arquivos `.gd`, ~8.200 linhas (`scripts/` = motor, `data/` = conteúdo). Sistemas: unidades/prédios, IA, coleta (harvester), névoa de guerra, minimapa, HUD/menus, campanha (`mission.gd`), rede WebRTC 1v1 (`net.gd`), efeitos e câmera.
- **Conteúdo**: 3 facções (Império da Cinza, Legião Sintética, Enxame Abissal); 36 entradas de unidades/prédios em `data/game_data.gd`; 88 sprites pré-renderizados isométricos em `assets/sprites/` (pipeline Blender → Cycles → pixelização no Godot).
- **Campanha**: humana com H01 e H02 implementadas em `data/campaign.gd` (H03–H07 nomeadas); Legião e Enxame ainda sem missões. Roteiro das 21 missões em `H:\Jogos\referencia facções\`.
- **Design**: sem `design/game-brief.md`. Referências atuais: `docs/MECANICAS.md` (fonte da verdade do motor) e o roteiro de missões.
- **Arquitetura**: 0 ADRs (não exigidos no nível `minimal`).
- **Testes**: nenhum (`tests/` inexistente; gdUnit4 escolhido mas não instalado).
- **Produção**: sem histórias/sprints (não exigidos no `minimal`); progresso medido pela campanha (2 de 21 missões).

## Lacunas identificadas
1. **Falta `design/game-brief.md`** — com 10+ arquivos de código, o caminho é escrevê-lo a partir do que existe. *Decisão do usuário: gerar do código com `/reverse-document design`.*
2. **Raiz de código fora do padrão** — o framework fixa Godot → `src/` (`resolve_code_root` em `.claude/hooks/yaml-helper.sh`), sem chave de configuração. Registrado como comentário em `project.yaml`. Contagens automáticas de código, TODOs e a fase inferida ficarão erradas até que isso seja resolvido (adaptar o helper do framework ou outra solução — decisão do usuário).
3. **Sem testes automatizados** — rodar `/test-setup` para instalar o gdUnit4 e criar `tests/` (também elimina o único DIFFERS da verificação de coerência).

## Próximos passos recomendados
1. `/reverse-document design scripts` — gerar o `design/game-brief.md` do jogo construído.
2. Decidir como fazer o framework enxergar `scripts/` e `data/` como raiz de código.
3. `/test-setup` — gdUnit4 + `tests/`.
4. Seguir com a campanha (H03 em diante) via `/create-stories` → `/dev-story`.
