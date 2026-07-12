#!/usr/bin/env bash
# Agent CLI status line
#
# The Agent CLI sends a JSON payload on stdin for each status-line render. This
# script formats the fields exposed by that payload using only local commands.

# Core sections, enabled by default.
SHOW_MODEL=${SHOW_MODEL:-1}
SHOW_GIT=${SHOW_GIT:-1}
SHOW_CONTEXT=${SHOW_CONTEXT:-1}
SHOW_CWD=${SHOW_CWD:-1}

# Optional sections, disabled by default unless noted.
SHOW_SESSION=${SHOW_SESSION:-0}
SHOW_TOKENS=${SHOW_TOKENS:-0}
SHOW_REMAINING=${SHOW_REMAINING:-0}
SHOW_CURSOR_USAGE=${SHOW_CURSOR_USAGE:-0}
SHOW_VIM=${SHOW_VIM:-1}
SHOW_AUTORUN=${SHOW_AUTORUN:-1}
SHOW_VERSION=${SHOW_VERSION:-0}
SHOW_OUTPUT_STYLE=${SHOW_OUTPUT_STYLE:-0}
SHOW_GIT_AHEAD=${SHOW_GIT_AHEAD:-0}
SHOW_CONTEXT_WARN=${SHOW_CONTEXT_WARN:-0}
CONTEXT_WARN_AT=${CONTEXT_WARN_AT:-80}
CURSOR_USAGE_TTL=${CURSOR_USAGE_TTL:-300}
CURSOR_USAGE_TIMEOUT=${CURSOR_USAGE_TIMEOUT:-2.0}
# pools = Auto/Composer/Grok + API percentages (default)
# legacy = single spend/remaining line from earlier versions
CURSOR_USAGE_FORMAT=${CURSOR_USAGE_FORMAT:-pools}
CURSOR_USAGE_SHOW_DOLLARS=${CURSOR_USAGE_SHOW_DOLLARS:-1}
CURSOR_USAGE_SHOW_SLOW=${CURSOR_USAGE_SHOW_SLOW:-1}

# Appearance.
STATUSLINE_SEP=${STATUSLINE_SEP:-|}
STATUSLINE_ORDER=${STATUSLINE_ORDER:-}
STATUSLINE_THEME=${STATUSLINE_THEME:-}
STATUSLINE_WIDTH=${STATUSLINE_WIDTH:-}

if [ "$STATUSLINE_THEME" = "light" ]; then
  C_MODEL=35
  C_GIT=34
  C_CWD=30
  C_DIM=30
else
  C_MODEL=35
  C_GIT=36
  C_CWD=90
  C_DIM=90
fi

detect_lang() {
  local sys="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  if [ -z "$sys" ] && command -v defaults >/dev/null 2>&1; then
    sys=$(defaults read -g AppleLocale 2>/dev/null)
  fi

  case "$sys" in
    pt*) printf 'pt' ;;
    *) printf 'en' ;;
  esac
}

STATUSLINE_LANG=${STATUSLINE_LANG:-$(detect_lang)}

if [ "$STATUSLINE_LANG" = "pt" ]; then
  L_CONTEXT="Contexto"
  L_REMAINING="restante"
  L_TOKENS="tokens"
  L_INPUT="entrada"
  L_OUTPUT="saida"
  L_AUTORUN="auto"
  L_CURSOR_USAGE="Uso"
  L_USED="usado"
  L_LEFT="sobrando"
  L_AUTO_POOL="auto"
  L_API_POOL="api"
  L_SLOW="lento"
  L_SESSION="sessao"
  L_VERSION="versao"
  L_STYLE="estilo"
  L_MAX="max"
else
  L_CONTEXT="Context"
  L_REMAINING="remaining"
  L_TOKENS="tokens"
  L_INPUT="input"
  L_OUTPUT="output"
  L_AUTORUN="auto"
  L_CURSOR_USAGE="Usage"
  L_USED="used"
  L_LEFT="left"
  L_AUTO_POOL="auto"
  L_API_POOL="api"
  L_SLOW="slow"
  L_SESSION="session"
  L_VERSION="version"
  L_STYLE="style"
  L_MAX="max"
fi

input=$(cat)

jq_get() {
  printf '%s' "$input" | jq -r "$1" 2>/dev/null
}

model=$(jq_get '.model.display_name // .model.id // "?"')
param_summary=$(jq_get '.model.param_summary // empty')
max_mode=$(jq_get '.model.max_mode // false')
cwd=$(jq_get '.workspace.current_dir // .cwd // empty')
session_name=$(jq_get '.session_name // empty')
version=$(jq_get '.version // empty')
output_style=$(jq_get '.output_style.name // empty')
autorun=$(jq_get '.autorun // false')
vim_mode=$(jq_get '.vim.mode // empty')
payload_worktree_name=$(jq_get '.worktree.name // empty')
render_width_chars=$(jq_get '.render_width_chars // empty')

used_pct=$(jq_get '.context_window.used_percentage // empty')
remaining_pct=$(jq_get '.context_window.remaining_percentage // empty')
input_tokens=$(jq_get '.context_window.total_input_tokens // empty')
output_tokens=$(jq_get '.context_window.total_output_tokens // empty')
context_size=$(jq_get '.context_window.context_window_size // empty')

color_pct() {
  local raw="$1"
  local val
  val=$(LC_ALL=C awk -v n="$raw" 'BEGIN { if (n == "") exit 1; printf "%.0f", n }') || return

  if [ "$val" -ge 80 ]; then
    printf '\033[31m%s%%\033[0m' "$val"
  elif [ "$val" -ge 50 ]; then
    printf '\033[33m%s%%\033[0m' "$val"
  else
    printf '\033[32m%s%%\033[0m' "$val"
  fi
}

format_count() {
  local n="$1"
  [ -z "$n" ] || [ "$n" = "null" ] && return

  LC_ALL=C awk -v n="$n" '
    BEGIN {
      n += 0
      if (n >= 1000000) {
        printf "%.1fM", n / 1000000
      } else if (n >= 1000) {
        printf "%.1fk", n / 1000
      } else {
        printf "%d", n
      }
    }'
}

format_context_size() {
  local n="$1"
  [ -z "$n" ] || [ "$n" = "null" ] && return
  printf '%s' "$(format_count "$n")"
}

format_cents() {
  local cents="$1"
  [ -z "$cents" ] || [ "$cents" = "null" ] && return

  LC_ALL=C awk -v cents="$cents" 'BEGIN { printf "$%.2f", cents / 100 }'
}

file_mtime() {
  local out
  out=$(stat -f %m "$1" 2>/dev/null)
  case "$out" in
    ''|*[!0-9]*) out=$(stat -c %Y "$1" 2>/dev/null) ;;
  esac
  case "$out" in
    ''|*[!0-9]*) return 1 ;;
    *) printf '%s\n' "$out" ;;
  esac
}

read_cursor_access_token() {
  if [ -n "${CURSOR_ACCESS_TOKEN:-}" ]; then
    printf '%s' "$CURSOR_ACCESS_TOKEN"
    return
  fi

  if command -v security >/dev/null 2>&1; then
    security find-generic-password -s "cursor-access-token" -a "cursor-user" -w 2>/dev/null
  fi
}

get_cursor_usage_json() {
  local cache_dir cache now age resp token usage_tmp policy_tmp usage_resp policy_resp
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/agent-status-line"
  cache="$cache_dir/cursor-usage.json"
  now=$(date +%s)

  if [ -n "${CURSOR_USAGE_JSON:-}" ]; then
    printf '%s' "$CURSOR_USAGE_JSON"
    return
  fi

  if [ -f "$cache" ]; then
    age=$((now - $(file_mtime "$cache" 2>/dev/null || echo 0)))
    if [ "$age" -lt "$CURSOR_USAGE_TTL" ] 2>/dev/null; then
      cat "$cache" 2>/dev/null
      return
    fi
  fi

  token=$(read_cursor_access_token)
  [ -z "$token" ] && return

  usage_tmp=$(mktemp 2>/dev/null) || return
  policy_tmp=$(mktemp 2>/dev/null) || {
    rm -f "$usage_tmp"
    return
  }

  curl -sS --max-time "$CURSOR_USAGE_TIMEOUT" \
    -X POST "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "Connect-Protocol-Version: 1" \
    --data '{}' >"$usage_tmp" 2>/dev/null &
  curl -sS --max-time "$CURSOR_USAGE_TIMEOUT" \
    -X POST "https://api2.cursor.sh/aiserver.v1.DashboardService/GetUsageLimitPolicyStatus" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "Connect-Protocol-Version: 1" \
    --data '{}' >"$policy_tmp" 2>/dev/null &
  wait

  if ! jq -e '.planUsage | type == "object"' "$usage_tmp" >/dev/null 2>&1; then
    rm -f "$usage_tmp" "$policy_tmp"
    return
  fi

  if jq -e 'type == "object"' "$policy_tmp" >/dev/null 2>&1; then
    resp=$(jq -n \
      --slurpfile usage "$usage_tmp" \
      --slurpfile policy "$policy_tmp" \
      '
        ($usage[0] // {}) as $u
        | ($policy[0] // {}) as $p
        | $u + {
            policy: {
              isInSlowPool: ($p.isInSlowPool // false),
              allowedModelIds: ($p.allowedModelIds // []),
              errorDetail: ($p.errorDetail // null),
              slownessMs: ($p.slownessMs // null)
            }
          }
      ' 2>/dev/null) || resp=$(cat "$usage_tmp")
  else
    resp=$(cat "$usage_tmp")
  fi
  rm -f "$usage_tmp" "$policy_tmp"

  (umask 077; mkdir -p "$cache_dir" 2>/dev/null)
  chmod 700 "$cache_dir" 2>/dev/null
  (umask 077; printf '%s' "$resp" > "$cache.tmp.$$" 2>/dev/null) && mv -f "$cache.tmp.$$" "$cache" 2>/dev/null
  printf '%s' "$resp"
}

format_cursor_usage_segment() {
  local cursor_usage_json="$1"
  local auto_pct api_pct total_pct usage_used usage_left usage_limit
  local used_label left_label limit_label is_slow parts_text

  auto_pct=$(printf '%s' "$cursor_usage_json" | jq -r '.planUsage.autoPercentUsed // empty' 2>/dev/null)
  api_pct=$(printf '%s' "$cursor_usage_json" | jq -r '.planUsage.apiPercentUsed // empty' 2>/dev/null)
  total_pct=$(printf '%s' "$cursor_usage_json" | jq -r '.planUsage.totalPercentUsed // empty' 2>/dev/null)
  usage_used=$(printf '%s' "$cursor_usage_json" | jq -r '.planUsage.includedSpend // .planUsage.totalSpend // empty' 2>/dev/null)
  usage_left=$(printf '%s' "$cursor_usage_json" | jq -r '.planUsage.remaining // empty' 2>/dev/null)
  usage_limit=$(printf '%s' "$cursor_usage_json" | jq -r '.planUsage.limit // empty' 2>/dev/null)
  is_slow=$(printf '%s' "$cursor_usage_json" | jq -r '.policy.isInSlowPool // false' 2>/dev/null)

  if [ "$CURSOR_USAGE_FORMAT" = "legacy" ]; then
    local usage_pct="$api_pct"
    [ -z "$usage_pct" ] && usage_pct="$total_pct"
    if [ -z "$usage_pct" ] && [ -n "$usage_used" ] && [ -n "$usage_limit" ] && [ "$usage_limit" != "0" ]; then
      usage_pct=$(LC_ALL=C awk -v used="$usage_used" -v limit="$usage_limit" 'BEGIN { printf "%.1f", used * 100 / limit }')
    fi

    used_label=$(format_cents "$usage_used")
    left_label=$(format_cents "$usage_left")

    if [ -z "$used_label" ] && [ -z "$left_label" ] && [ -z "$usage_pct" ]; then
      return
    fi

    parts_text="$L_CURSOR_USAGE:"
    if [ -n "$used_label" ]; then
      parts_text="$parts_text $used_label $L_USED"
    fi
    if [ -n "$left_label" ]; then
      parts_text="$parts_text${used_label:+,} $left_label $L_LEFT"
    fi
    if [ -n "$usage_pct" ]; then
      parts_text="$parts_text ($(color_pct "$usage_pct"))"
    fi
    printf '%s' "$parts_text"
    return
  fi

  # Default: separate first-party (Auto/Composer/Grok) and API pools.
  if [ -z "$auto_pct" ] && [ -z "$api_pct" ] && [ -z "$total_pct" ]; then
    return
  fi

  parts_text="$L_CURSOR_USAGE:"
  if [ -n "$auto_pct" ]; then
    parts_text="$parts_text $L_AUTO_POOL $(color_pct "$auto_pct")"
  fi
  if [ -n "$api_pct" ]; then
    parts_text="$parts_text${auto_pct:+ ·} $L_API_POOL $(color_pct "$api_pct")"
  elif [ -n "$total_pct" ] && [ -z "$auto_pct" ]; then
    parts_text="$parts_text $(color_pct "$total_pct")"
  fi

  if [ "$CURSOR_USAGE_SHOW_DOLLARS" != "0" ]; then
    used_label=$(format_cents "$usage_used")
    limit_label=$(format_cents "$usage_limit")
    left_label=$(format_cents "$usage_left")
    if [ -n "$used_label" ] && [ -n "$limit_label" ]; then
      parts_text="$parts_text ($used_label/$limit_label)"
    elif [ -n "$left_label" ]; then
      parts_text="$parts_text ($left_label $L_LEFT)"
    elif [ -n "$used_label" ]; then
      parts_text="$parts_text ($used_label $L_USED)"
    fi
  fi

  if [ "$CURSOR_USAGE_SHOW_SLOW" != "0" ] && [ "$is_slow" = "true" ]; then
    parts_text="$parts_text $(printf '\033[31m%s\033[0m' "$L_SLOW")"
  fi

  printf '%s' "$parts_text"
}

git_branch=""
git_worktree=""
git_ahead_behind=""

if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$git_branch" ]; then
    git_branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  fi

  if [ -n "$git_branch" ]; then
    wt_top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$payload_worktree_name" ]; then
      git_worktree="$payload_worktree_name"
    elif [ -n "$wt_top" ]; then
      main_top=$(git -C "$cwd" worktree list 2>/dev/null | awk 'NR == 1 { print $1 }')
      if [ -n "$main_top" ] && [ "$wt_top" != "$main_top" ]; then
        git_worktree=$(basename "$wt_top")
      fi
    fi

    if [ "$SHOW_GIT_AHEAD" != "0" ]; then
      counts=$(git -C "$cwd" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
      if [ -n "$counts" ]; then
        behind=$(printf '%s' "$counts" | awk '{ print $1 }')
        ahead=$(printf '%s' "$counts" | awk '{ print $2 }')
        ab=""
        [ "${ahead:-0}" -gt 0 ] 2>/dev/null && ab="$ab↑$ahead"
        [ "${behind:-0}" -gt 0 ] 2>/dev/null && ab="$ab${ab:+ }↓$behind"
        [ -n "$ab" ] && git_ahead_behind="$ab"
      fi
    fi
  fi
fi

seg_model=""
seg_git=""
seg_context=""
seg_cwd=""
seg_session=""
seg_tokens=""
seg_remaining=""
seg_cursor_usage=""
seg_vim=""
seg_autorun=""
seg_version=""
seg_output_style=""

if [ "$SHOW_MODEL" != "0" ]; then
  seg_model=$(printf '\033[%sm%s\033[0m' "$C_MODEL" "$model")
  if [ -n "$param_summary" ]; then
    seg_model="$seg_model$(printf ' \033[%sm(%s)\033[0m' "$C_DIM" "$param_summary")"
  fi
  if [ "$max_mode" = "true" ]; then
    seg_model="$seg_model$(printf ' \033[%sm(%s)\033[0m' "$C_DIM" "$L_MAX")"
  fi
fi

if [ "$SHOW_GIT" != "0" ] && [ -n "$git_branch" ]; then
  seg_git=$(printf '\033[%sm🌿 %s\033[0m' "$C_GIT" "$git_branch")
  if [ -n "$git_ahead_behind" ]; then
    seg_git="$seg_git$(printf ' \033[%sm%s\033[0m' "$C_DIM" "$git_ahead_behind")"
  fi
  if [ -n "$git_worktree" ]; then
    seg_git="$seg_git$(printf ' \033[%sm(📁 %s)\033[0m' "$C_DIM" "$git_worktree")"
  fi
fi

if [ "$SHOW_CONTEXT" != "0" ] && [ -n "$used_pct" ]; then
  warn=""
  if [ "$SHOW_CONTEXT_WARN" != "0" ]; then
    used_int=$(LC_ALL=C awk -v n="$used_pct" 'BEGIN { printf "%.0f", n }')
    [ "$used_int" -ge "$CONTEXT_WARN_AT" ] 2>/dev/null && warn="⚠ "
  fi

  seg_context="$(printf '%s%s: ' "$warn" "$L_CONTEXT")$(color_pct "$used_pct")"
  context_label=$(format_context_size "$context_size")
  if [ -n "$context_label" ]; then
    seg_context="$seg_context$(printf ' \033[%sm/%s\033[0m' "$C_DIM" "$context_label")"
  fi
fi

if [ "$SHOW_CWD" != "0" ] && [ -n "$cwd" ]; then
  seg_cwd=$(printf '\033[%sm📁 %s\033[0m' "$C_CWD" "$(basename "$cwd")")
fi

if [ "$SHOW_SESSION" != "0" ] && [ -n "$session_name" ]; then
  seg_session=$(printf '\033[%sm%s: %s\033[0m' "$C_DIM" "$L_SESSION" "$session_name")
fi

if [ "$SHOW_TOKENS" != "0" ]; then
  token_parts=()
  formatted_input=$(format_count "$input_tokens")
  formatted_output=$(format_count "$output_tokens")
  [ -n "$formatted_input" ] && token_parts+=("$L_INPUT $formatted_input")
  [ -n "$formatted_output" ] && token_parts+=("$L_OUTPUT $formatted_output")
  if [ "${#token_parts[@]}" -gt 0 ]; then
    token_text=""
    for token_part in "${token_parts[@]}"; do
      token_text="${token_text}${token_text:+, }${token_part}"
    done
    seg_tokens=$(printf '\033[%sm%s: %s\033[0m' "$C_DIM" "$L_TOKENS" "$token_text")
  fi
fi

if [ "$SHOW_REMAINING" != "0" ] && [ -n "$remaining_pct" ]; then
  seg_remaining="$L_REMAINING: $(color_pct "$remaining_pct")"
fi

if [ "$SHOW_CURSOR_USAGE" != "0" ]; then
  cursor_usage_json=$(get_cursor_usage_json)
  if [ -n "$cursor_usage_json" ]; then
    seg_cursor_usage=$(format_cursor_usage_segment "$cursor_usage_json")
  fi
fi

if [ "$SHOW_VIM" != "0" ] && [ -n "$vim_mode" ]; then
  seg_vim=$(printf '\033[%sm%s\033[0m' "$C_DIM" "$vim_mode")
fi

if [ "$SHOW_AUTORUN" != "0" ] && [ "$autorun" = "true" ]; then
  seg_autorun=$(printf '\033[%sm%s\033[0m' "$C_DIM" "$L_AUTORUN")
fi

if [ "$SHOW_VERSION" != "0" ] && [ -n "$version" ]; then
  seg_version=$(printf '\033[%sm%s: %s\033[0m' "$C_DIM" "$L_VERSION" "$version")
fi

if [ "$SHOW_OUTPUT_STYLE" != "0" ] && [ -n "$output_style" ]; then
  seg_output_style=$(printf '\033[%sm%s: %s\033[0m' "$C_DIM" "$L_STYLE" "$output_style")
fi

default_order="model git context cursor_usage cwd session tokens remaining vim autorun version output_style"
order="${STATUSLINE_ORDER:-$default_order}"
order="${order//,/ }"

parts=()
for key in $order; do
  case "$key" in
    model) seg="$seg_model" ;;
    git) seg="$seg_git" ;;
    context) seg="$seg_context" ;;
    cwd) seg="$seg_cwd" ;;
    session) seg="$seg_session" ;;
    tokens) seg="$seg_tokens" ;;
    remaining) seg="$seg_remaining" ;;
    cursor_usage) seg="$seg_cursor_usage" ;;
    vim) seg="$seg_vim" ;;
    autorun) seg="$seg_autorun" ;;
    version) seg="$seg_version" ;;
    output_style) seg="$seg_output_style" ;;
    *) seg="" ;;
  esac
  [ -n "$seg" ] && parts+=("$seg")
done

vislen() {
  local s
  s=$(printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g')
  local base=${#s}
  local leaf=$'\xf0\x9f\x8c\xbf'
  local folder=$'\xf0\x9f\x93\x81'
  local warn=$'\xe2\x9a\xa0'
  local t_leaf=${s//"$leaf"/}
  local t_folder=${s//"$folder"/}
  local t_warn=${s//"$warn"/}
  printf '%s' $((base + (base - ${#t_leaf}) + (base - ${#t_folder}) + (base - ${#t_warn})))
}

width="$STATUSLINE_WIDTH"
if [ -z "$width" ]; then
  if [ -n "$render_width_chars" ] && [ "$render_width_chars" -gt 0 ] 2>/dev/null; then
    width="$render_width_chars"
  elif [ "${COLUMNS:-0}" -gt 0 ] 2>/dev/null; then
    width="$COLUMNS"
  else
    width=$(tput cols 2>/dev/null || echo 0)
  fi
fi
[ -z "$width" ] && width=0
[ "$width" -gt 0 ] 2>/dev/null && width=$((width - 1))

sep=$(printf ' \033[%sm%s\033[0m ' "$C_DIM" "$STATUSLINE_SEP")
sep_len=$(vislen "$sep")

out=""
line=""
line_len=0
for seg in "${parts[@]}"; do
  seg_len=$(vislen "$seg")
  if [ -z "$line" ]; then
    line="$seg"
    line_len="$seg_len"
  elif [ "$width" -gt 0 ] && [ $((line_len + sep_len + seg_len)) -gt "$width" ]; then
    out="$out$line"$'\n'
    line="$seg"
    line_len="$seg_len"
  else
    line="$line$sep$seg"
    line_len=$((line_len + sep_len + seg_len))
  fi
done

out="$out$line"
printf '%s\n' "$out"
