# Estado de Serra Verde (Godot 4.3 · Android)

Mundo aberto offline, ~14,9 × 8,6 km (≈128 km²), gerado a partir do mapa de referência.
Cidades, terreno, rio, lagos, pântano, estradas e vegetação são **procedurais**.

## O que já existe
- **Terreno** em blocos com 4 níveis de detalhe (threads), colisão que segue o jogador, neve/rocha/areia por shader.
- **Água**: mar, lagos, rio e pântano.
- **Estradas** com faixas, acostamento e pistas do aeroporto.
- **Cidades** (Vice Shores, Porto Bahia, Vila Palmeira, aeroporto): quarteirões, torres de vidro, prédios, casas com telhado,
  galpões, contêineres, postes, carros estacionados, janelas acesas à noite. Geradas só perto do jogador.
- **Árvores** (MultiMesh com vento), **céu com ciclo dia/noite**.
- **Jogador** (3ª/1ª pessoa, correr, pular, nadar), **carros** (entrar/sair), **HUD multitoque** e **mapa**.

## Fluxo no celular (Termux)
```bash
./termux/preparar.sh                 # uma vez
gh auth login
gh repo create serra-verde --private --source=. --push
# a cada mudança:
./termux/publicar.sh "mensagem"      # o GitHub Actions gera o APK
```
O APK aparece em **Releases** do repositório (baixe e instale no celular).

## Regerar o terreno
Edite `tools/dados_mapa.py` (lagos, rio, estradas, montanhas, zonas) e rode:
```bash
cd tools && python gerar_mundo.py     # escreve em godot/assets/world/
```
`tools/preview_terreno.png` mostra o resultado; compare com `godot/assets/ui/mapa_referencia.jpg`.

## Ajustes de desempenho
- `scripts/cidade.gd`: `ALCANCE` (alcance das cidades) · `scripts/arvores.gd`: `ESPACO` e `ALCANCE`.
- `scripts/terreno.gd`: `DIST_LOD`.  `project.godot`: `scaling_3d/scale`, `msaa_3d`.

## Trocar por assets reais
- Personagem: coloque `godot/assets/models/personagem.glb` (carrega sozinho).
- Texturas PBR (Poly Haven/ambientCG): troque as cores procedurais em `shaders/terreno.gdshader`.
- Registre tudo em `CREDITS.md`.

## Aviso
Este código **ainda não foi compilado no Godot**. Na primeira execução podem aparecer erros de script/shader:
copie a mensagem completa (aba *Output*/*Debugger* ou o log do Actions) e corrija-se por ali.
