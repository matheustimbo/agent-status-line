# agent-status-line

**A status line for Agent CLI / Cursor CLI** inspired by [`claude-status-line`](https://github.com/matheustimbo/claude-status-line). It keeps your active model, git branch/worktree, context usage, and useful session hints visible above the prompt.

[![One-line install](https://img.shields.io/badge/install-one%20line-brightgreen)](#one-line-install)
[![Shell](https://img.shields.io/badge/built%20with-bash%20%2B%20jq-blue)](statusline-command.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)
[![PT-BR](https://img.shields.io/badge/language-PT--BR-green)](README.pt-BR.md)

**EN** · [PT-BR](README.pt-BR.md)

Example:

```text
GPT-5.5 272K Medium (Medium) | 🌿 main | Context: 35% /272.0k | 📁 agent-status-line
```

In a secondary git worktree, the worktree name appears next to the branch:

```text
GPT-5.5 272K Medium (Medium) | 🌿 main (📁 feature-x) | Context: 35% /272.0k | 📁 agent-status-line
```

Green is below 50%, yellow is 50-79%, and red is 80% or above.

## Why?

- Keep the current model and model parameters visible.
- See context window usage before it becomes a problem.
- Avoid working on the wrong branch or worktree.
- Run locally with no API calls and no token cost.

## Requirements

- `bash`
- [`jq`](https://stedolan.github.io/jq/) - `brew install jq` on macOS or `apt install jq` on Debian/Ubuntu.
- `curl` for the one-line installer.

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/matheustimbo/agent-status-line/main/install.sh | bash
```

Then restart Agent CLI / Cursor CLI. The installer downloads the script to `~/.cursor/statusline-command.sh` and adds a `statusLine` block to `~/.cursor/cli-config.json`, preserving the rest of your configuration.

The default configuration uses `padding: 2`, `updateIntervalMs: 1000`, and `timeoutMs: 2000`. Override them with environment variables:

```bash
PADDING=1 UPDATE_INTERVAL_MS=500 TIMEOUT_MS=1500 \
  curl -fsSL https://raw.githubusercontent.com/matheustimbo/agent-status-line/main/install.sh | bash
```

## Manual Install

1. Download the script:

   ```bash
   curl -o ~/.cursor/statusline-command.sh \
     https://raw.githubusercontent.com/matheustimbo/agent-status-line/main/statusline-command.sh
   chmod +x ~/.cursor/statusline-command.sh
   ```

2. Add this block to `~/.cursor/cli-config.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash ~/.cursor/statusline-command.sh",
       "padding": 2,
       "updateIntervalMs": 1000,
       "timeoutMs": 2000
     }
   }
   ```

3. Restart Agent CLI / Cursor CLI.

## Configuration

Configure the status line with environment variables in the `command` field:

```json
{
  "statusLine": {
    "type": "command",
    "command": "STATUSLINE_LANG=en SHOW_VERSION=1 bash ~/.cursor/statusline-command.sh",
    "padding": 2
  }
}
```

### Language

`STATUSLINE_LANG` can be `en` or `pt`. If unset, the script uses your system locale and falls back to English.

### Core Sections

These are shown by default. Set any variable to `0` to hide its section.

| Variable | Section |
| --- | --- |
| `SHOW_MODEL` | Current model, parameter summary, and max-mode marker |
| `SHOW_GIT` | Git branch, detached HEAD, and worktree |
| `SHOW_CONTEXT` | Context window used percentage |
| `SHOW_CWD` | Current directory basename |
| `SHOW_VIM` | Vim mode when present in the payload |
| `SHOW_AUTORUN` | Auto-run marker when enabled |

### Extra Sections

These are hidden by default. Set any variable to `1` to show it.

| Variable | Section |
| --- | --- |
| `SHOW_SESSION` | Session name |
| `SHOW_TOKENS` | Estimated input/output tokens |
| `SHOW_REMAINING` | Context remaining percentage |
| `SHOW_VERSION` | Agent CLI version |
| `SHOW_OUTPUT_STYLE` | Output style name |
| `SHOW_GIT_AHEAD` | Ahead/behind vs upstream, like `↑2 ↓1` |
| `SHOW_CONTEXT_WARN` | Prefixes a warning when context usage is high |
| `CONTEXT_WARN_AT` | Warning threshold, default `80` |

### Appearance

| Variable | Effect |
| --- | --- |
| `STATUSLINE_SEP` | Separator between sections, default `|` |
| `STATUSLINE_ORDER` | Comma-separated section order |
| `STATUSLINE_THEME` | `dark` default or `light` |
| `STATUSLINE_WIDTH` | Force wrapping width. Empty means auto-detect; `0` disables wrapping |

Supported section keys for `STATUSLINE_ORDER`:

```text
model,git,context,cwd,session,tokens,remaining,vim,autorun,version,output_style
```

Example:

```json
{
  "statusLine": {
    "type": "command",
    "command": "STATUSLINE_ORDER=model,context,git SHOW_TOKENS=1 bash ~/.cursor/statusline-command.sh"
  }
}
```

## How It Works

Agent CLI starts the configured command on each status-line update and sends a JSON payload on stdin. The script reads fields such as `model`, `workspace`, `context_window`, `vim`, `autorun`, `version`, and `worktree`, then prints ANSI-colored text to stdout.

Unlike the Claude Code version, this project does not show Claude subscription rate limits or session cost because those fields are not part of the Agent CLI status-line payload.

## Testing

Run the script with mock input:

```bash
echo '{"model":{"display_name":"GPT-5.5","param_summary":"Medium"},"workspace":{"current_dir":"/tmp/repo"},"context_window":{"used_percentage":34.5,"remaining_percentage":65.5,"context_window_size":272000}}' | ./statusline-command.sh
```

Test optional sections:

```bash
echo '{"model":{"display_name":"GPT-5.5"},"version":"1.2.3","context_window":{"used_percentage":34.5,"remaining_percentage":65.5,"total_input_tokens":15234,"total_output_tokens":1200}}' \
  | SHOW_TOKENS=1 SHOW_REMAINING=1 SHOW_VERSION=1 ./statusline-command.sh
```

## License

MIT - use, modify, and share freely.
