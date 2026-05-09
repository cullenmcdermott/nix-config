#!/bin/bash
# Reference copy for linting — the real handler is generated inline by pomp.nix.
# JQ, POMP_BRIDGE_TOKEN, and op are resolved differently in the real script.
set -euo pipefail
JQ="jq"  # Real script uses Nix store path

while IFS= read -r line; do
  token=$("$JQ" -r '.token // empty' <<< "$line")
  if [ "$token" != "$POMP_BRIDGE_TOKEN" ]; then
    printf '{"ok":false,"error":"invalid token"}\n'
    continue
  fi

  msg_type=$("$JQ" -r '.type' <<< "$line")
  case "$msg_type" in
    open_url)
      url=$("$JQ" -r '.url' <<< "$line")
      case "$url" in
        http://*|https://*) open "$url" 2>/dev/null; printf '{"ok":true}\n' ;;
        *) printf '{"ok":false,"error":"blocked non-http scheme"}\n' ;;
      esac
      ;;
    secret)
      ref=$("$JQ" -r '.ref' <<< "$line")
      case "$ref" in
        op://*)
          if value=$(op read "$ref" 2>/dev/null); then
            printf '{"ok":true,"value":%s}\n' "$("$JQ" -Rs . <<< "$value")"
          else
            printf '{"ok":false,"error":"failed to read secret"}\n'
          fi
          ;;
        *) printf '{"ok":false,"error":"invalid ref format (must start with op://)"}\n' ;;
      esac
      ;;
    *)
      printf '{"ok":false,"error":"unknown type: %s"}\n' "$msg_type"
      ;;
  esac
done
