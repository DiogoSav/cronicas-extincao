# RTS Kit

Base para criar jogos de estratégia em tempo real 3D no **Godot 4.7**, com todas as
mecânicas e o **multiplayer 1×1 pela internet** do [Star-RTS](https://github.com/DiogoSav/star-rts)
— que vem junto como jogo de exemplo, funcionando de cara.

O kit separa o **motor** (`scripts/`) do **conteúdo** (`data/` e modelos). Para um jogo
novo você mexe em dois arquivos de dados e nos modelos; o motor fica igual.

## Criar um jogo novo

```
novo_jogo.bat medieval-rts "Reinos em Guerra"
```

Cria `H:\Jogos\medieval-rts` com o kit, o nome do projeto, o título e o identificador de
rede já trocados. Depois:

1. `data/game_data.gd` — raças, unidades, prédios, armas, população, IA e mapa.
2. `data/theme.gd` — título, textos, cores, terreno, cenário e menu.
3. `art_src/blender/` — um `.py` por raça com os modelos; `gerar_modelos.bat` gera os `.glb`.
4. `jogar.bat` ou F5 no editor.

Guia completo (cada campo, cada mecânica, multiplayer, Web, testes):
**[docs/MECANICAS.md](docs/MECANICAS.md)**.

## O que vem pronto

- RTS completo: coleta de recurso, energia, produção com fila, população (limite e
  reserva), construção animada, conserto pago, reciclagem (80%), estação de cura, torres,
  névoa de guerra, minimapa, IA em ondas, vitória/derrota, mapas pequeno / médio / grande.
- Controles: mover, atacar andando, patrulha, parar, posturas defender / agressivo,
  grupos (Ctrl + 1..9), ponto de reunião dos prédios produtores, alerta de base atacada
  (pisca no minimapa; Espaço vai até lá). Sons ficam por conta de cada jogo (ver doc).
- Infantaria, veículos e **unidades aéreas** (voo, antiaéreo, queda ao serem abatidas);
  armas com tipos e blindagens; projéteis visíveis.
- Visual 3D: modelos PBR gerados no Blender, shader com linhas de painel / carapaça orgânica,
  cor do time, bloom, partículas, explosões, carcaças; marcha procedural (bípedes e patas),
  rodas, esteiras, larvas e suspensão.
- **Multiplayer 1×1** (WebRTC P2P, anfitrião autoritativo): sala com código, nomes, chat,
  escolha de raça, PRONTO, início sincronizado.
- **Versão Web** (exportação pronta, carimbo contra cache, servidor de teste).

## Arquivos

| | |
|---|---|
| `novo_jogo.bat` | cria um jogo novo a partir do kit |
| `gerar_modelos.bat` | gera os modelos no Blender 5.2 e reimporta no Godot |
| `jogar.bat` | abre o jogo |
| `data/` | conteúdo e tema do jogo |
| `scripts/` | motor |
| `art_src/blender/` | geradores de modelos |
| `tools/` | servidor Web local e carimbo de versão |
| `docs/MECANICAS.md` | documentação técnica |

Requisitos: Godot 4.7.2 (`H:\Jogos\Godot`), Blender 5.2 para os modelos, Node.js para
testar e publicar a versão Web.
