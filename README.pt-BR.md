# agent-status-line

**Uma status line para Agent CLI / Cursor CLI**, inspirada no [`claude-status-line`](https://github.com/matheustimbo/claude-status-line). Ela deixa modelo ativo, branch/worktree, uso de contexto e detalhes úteis da sessão visíveis acima do prompt.

[![Instalação em uma linha](https://img.shields.io/badge/install-one%20line-brightgreen)](#instalação-em-uma-linha)
[![Shell](https://img.shields.io/badge/built%20with-bash%20%2B%20jq-blue)](statusline-command.sh)
[![Licença](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)
[![EN](https://img.shields.io/badge/language-EN-blue)](README.md)

[EN](README.md) · **PT-BR**

Exemplo:

```text
GPT-5.5 272K Medium (Medium) | 🌿 main | Contexto: 35% /272.0k | 📁 agent-status-line
```

Em uma git worktree secundaria, o nome da worktree aparece ao lado da branch:

```text
GPT-5.5 272K Medium (Medium) | 🌿 main (📁 feature-x) | Contexto: 35% /272.0k | 📁 agent-status-line
```

Verde fica abaixo de 50%, amarelo entre 50-79%, e vermelho em 80% ou mais.

## Por Que?

- Mantem o modelo atual e os parametros sempre visiveis.
- Mostra o uso da janela de contexto antes de virar problema.
- Ajuda a evitar trabalho na branch ou worktree errada.
- Roda localmente, sem chamadas de API e sem custo de tokens.

## Requisitos

- `bash`
- [`jq`](https://stedolan.github.io/jq/) - `brew install jq` no macOS ou `apt install jq` no Debian/Ubuntu.
- `curl` para o instalador em uma linha.

## Instalação Em Uma Linha

```bash
curl -fsSL https://raw.githubusercontent.com/matheustimbo/agent-status-line/main/install.sh | bash
```

Depois reinicie o Agent CLI / Cursor CLI. O instalador baixa o script para `~/.cursor/statusline-command.sh` e adiciona um bloco `statusLine` em `~/.cursor/cli-config.json`, preservando o restante da configuração.

A configuração padrão usa `padding: 2`, `updateIntervalMs: 1000` e `timeoutMs: 2000`. Você pode sobrescrever com variáveis de ambiente:

```bash
PADDING=1 UPDATE_INTERVAL_MS=500 TIMEOUT_MS=1500 \
  curl -fsSL https://raw.githubusercontent.com/matheustimbo/agent-status-line/main/install.sh | bash
```

Ative o uso experimental do plano Cursor durante a instalação:

```bash
ENABLE_CURSOR_USAGE=1 \
  curl -fsSL https://raw.githubusercontent.com/matheustimbo/agent-status-line/main/install.sh | bash
```

## Instalação Manual

1. Baixe o script:

   ```bash
   curl -o ~/.cursor/statusline-command.sh \
     https://raw.githubusercontent.com/matheustimbo/agent-status-line/main/statusline-command.sh
   chmod +x ~/.cursor/statusline-command.sh
   ```

2. Adicione este bloco ao `~/.cursor/cli-config.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.cursor/statusline-command.sh",
       "padding": 2,
       "updateIntervalMs": 1000,
       "timeoutMs": 2000
     }
   }
   ```

3. Reinicie o Agent CLI / Cursor CLI.

## Configuração

Configure a status line com variáveis de ambiente no campo `command`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash -lc 'STATUSLINE_LANG=pt SHOW_VERSION=1 ~/.cursor/statusline-command.sh'",
    "padding": 2
  }
}
```

### Idioma

`STATUSLINE_LANG` pode ser `en` ou `pt`. Se não estiver definido, o script usa o idioma do sistema e cai para inglês quando não reconhecer.

### Seções Principais

Estas aparecem por padrão. Defina qualquer variável como `0` para esconder a seção.

| Variável | Seção |
| --- | --- |
| `SHOW_MODEL` | Modelo atual, resumo de parâmetros e marcador de max mode |
| `SHOW_GIT` | Branch git, HEAD destacado e worktree |
| `SHOW_CONTEXT` | Porcentagem usada da janela de contexto |
| `SHOW_CWD` | Nome do diretório atual |
| `SHOW_VIM` | Modo Vim quando existir no payload |
| `SHOW_AUTORUN` | Marcador quando auto-run estiver ativo |

### Seções Extras

Estas ficam escondidas por padrão. Defina qualquer variável como `1` para mostrar.

| Variável | Seção |
| --- | --- |
| `SHOW_SESSION` | Nome da sessão |
| `SHOW_TOKENS` | Tokens estimados de entrada/saída |
| `SHOW_REMAINING` | Porcentagem restante de contexto |
| `SHOW_CURSOR_USAGE` | Uso do plano Cursor: pools first-party (`auto`) vs API, `$usado/$limite` opcional, marcador de slow queue |
| `SHOW_VERSION` | Versão do Agent CLI |
| `SHOW_OUTPUT_STYLE` | Nome do estilo de saída |
| `SHOW_GIT_AHEAD` | Ahead/behind contra upstream, como `↑2 ↓1` |
| `SHOW_CONTEXT_WARN` | Prefixa um aviso quando o contexto estiver alto |
| `CONTEXT_WARN_AT` | Limiar do aviso, padrão `80` |

### Aparência

| Variável | Efeito |
| --- | --- |
| `STATUSLINE_SEP` | Separador entre seções, padrão `|` |
| `STATUSLINE_ORDER` | Ordem das seções, separada por vírgula |
| `STATUSLINE_THEME` | `dark` por padrão ou `light` |
| `STATUSLINE_WIDTH` | Força largura de quebra. Vazio detecta automaticamente; `0` desliga a quebra |
| `CURSOR_USAGE_TTL` | TTL do cache em segundos para uso do Cursor, padrão `300` |
| `CURSOR_USAGE_TIMEOUT` | Timeout da busca em segundos para uso do Cursor, padrão `2.0` |
| `CURSOR_USAGE_FORMAT` | `pools` (padrão) ou `legacy` |
| `CURSOR_USAGE_SHOW_DOLLARS` | Mostra `$usado/$limite` no formato pools, padrão `1` |
| `CURSOR_USAGE_SHOW_SLOW` | Mostra marcador de slow queue, padrão `1` |

Chaves aceitas em `STATUSLINE_ORDER`:

```text
model,git,context,cursor_usage,cwd,session,tokens,remaining,vim,autorun,version,output_style
```

Exemplo:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash -lc 'STATUSLINE_ORDER=model,context,git SHOW_TOKENS=1 ~/.cursor/statusline-command.sh'"
  }
}
```

## Como Funciona

O Agent CLI inicia o comando configurado a cada atualização da status line e envia um payload JSON via stdin. O script lê campos como `model`, `workspace`, `context_window`, `vim`, `autorun`, `version` e `worktree`, depois imprime texto colorido com ANSI no stdout.

Diferente da versão para Claude Code, este projeto não mostra rate limits de assinatura Claude nem custo da sessão porque esses campos não fazem parte do payload de status line do Agent CLI.

### Uso Experimental Do Cursor

Defina `SHOW_CURSOR_USAGE=1` para mostrar o uso do plano Cursor via API interna do dashboard:

```text
Uso: auto 50.07% · api 100.00% ($400.00/$400.00)
```

- `auto` = pool first-party (Auto, Composer, Grok)
- `api` = pool frontier/API (Claude, GPT, … quando selecionados manualmente)
- valores em dólar = gasto incluso vs limite incluso do ciclo
- `lento` aparece em vermelho quando a conta cai na slow queue

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash -lc 'SHOW_CURSOR_USAGE=1 ~/.cursor/statusline-command.sh'"
  }
}
```

No macOS, o script lê do Keychain o `cursor-access-token` do Agent CLI e chama em paralelo os endpoints internos do dashboard do Cursor:

```text
POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage
POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetUsageLimitPolicyStatus
```

O token fica apenas em memória e nunca é gravado em disco ou impresso. A resposta mesclada é cacheada em `~/.cache/agent-status-line/cursor-usage.json` por `CURSOR_USAGE_TTL` segundos. As buscas respeitam `CURSOR_USAGE_TIMEOUT` para não travar a status line. Esses endpoints não são documentados e podem mudar sem aviso.

Knobs opcionais de uso do Cursor:

| Variável | Efeito |
| --- | --- |
| `CURSOR_USAGE_FORMAT` | `pools` (padrão) ou `legacy` (linha única de gasto) |
| `CURSOR_USAGE_SHOW_DOLLARS` | Inclui `$usado/$limite` (padrão `1`) |
| `CURSOR_USAGE_SHOW_SLOW` | Mostra marcador de slow queue (padrão `1`) |
| `CURSOR_USAGE_JSON` | Injeta JSON para teste offline |

Exemplo com o formato antigo de porcentagem única:

```bash
bash -lc 'SHOW_CURSOR_USAGE=1 CURSOR_USAGE_FORMAT=legacy ~/.cursor/statusline-command.sh'
```

Teste offline:

```bash
echo '{"model":{"display_name":"Grok 4.5"}}' \
  | SHOW_CURSOR_USAGE=1 CURSOR_USAGE_JSON='{"planUsage":{"autoPercentUsed":50.1,"apiPercentUsed":100,"includedSpend":40000,"limit":40000},"policy":{"isInSlowPool":false}}' \
    ./statusline-command.sh
```

## Testes

Rode o script com entrada mockada:

```bash
echo '{"model":{"display_name":"GPT-5.5","param_summary":"Medium"},"workspace":{"current_dir":"/tmp/repo"},"context_window":{"used_percentage":34.5,"remaining_percentage":65.5,"context_window_size":272000}}' | ./statusline-command.sh
```

Teste seções opcionais:

```bash
echo '{"model":{"display_name":"GPT-5.5"},"version":"1.2.3","context_window":{"used_percentage":34.5,"remaining_percentage":65.5,"total_input_tokens":15234,"total_output_tokens":1200}}' \
  | SHOW_TOKENS=1 SHOW_REMAINING=1 SHOW_VERSION=1 ./statusline-command.sh
```

## Licença

MIT - use, modifique e compartilhe livremente.
