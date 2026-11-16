# Berry Hoard

Protótipo incremental em primeira pessoa (estilo *One Million Coins*): estufa cheia de berries com física, cesto com capacidade e um upgrade.

## Rodar (WSL)

```bash
cd ~/work/berry-hoard
godot --path .
```

Ou abra a pasta no editor Godot 4.7+.

## Controles

| Tecla / mouse | Ação |
|---------------|------|
| WASD | Andar |
| Espaço | Pular |
| **1 / 2 / 3** | Mão / Colhedor automático / Ímã |
| **Mão** | Clique esquerdo na berry; encosta pra colher |
| **Ímã** | Segurar clique esquerdo para puxar |
| **Colhedor** | Colhe sozinho berries no alcance |
| **P** | Painel de proficiências (upgrades) |
| **E** | Esvaziar cesto (ou na caixa de entrega ao fundo) |
| Esc | Liberar mouse |

## Performance (WSL e física)

O **WSLg** (janela Linux → GPU do Windows) adiciona um pouco de latência, mas o travamento vinha sobretudo de **~200 corpos rígidos** colidindo entre si.

- Berries **não colidem umas com as outras** (só chão + jogador) até termos pooling/MultiMesh.
- Spawn em lotes; SSAO/glow desligados; física a 30 Hz.

Para o máximo de FPS no dev: instale o **Godot 4.7 para Windows** e abra `\\wsl$\Ubuntu\home\batinera\personal\berry-hoard` — o render usa o driver direto, sem WSLg. Mantenha os arquivos no disco do WSL (não em `/mnt/c/`).

## Próximos passos sugeridos

- Hotbar com 3 ferramentas (mão / colhedor / magnético)
- Árvore de proficiências
- `MultiMesh` ou pooling para 5k+ berries sem travar
- NPC ou balcão de venda no fundo da estufa