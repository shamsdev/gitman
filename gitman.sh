#!/usr/bin/env bash
set -eu

# --- load .env ---
load_env() {
  if [ ! -f .env ]; then
    echo "🔴 .env not found" >&2
    exit 1
  fi
  export $(grep -v '^#' .env | xargs)
  : "${GIT_REPO_PATH:?set in .env}"
  : "${GIT_BRANCH:?set in .env}"
  : "${API_KEY:?set in .env}"
  if [ ! -d "$GIT_REPO_PATH/.git" ]; then
    echo "🔴 $GIT_REPO_PATH is not a git repo" >&2
    exit 1
  fi
}

# --- send HTTP response with CORS ---
http_response() {
  local status="$1"         # e.g. "200 OK" or "204 No Content"
  local content_type="$2"  # e.g. "text/plain"
  local body="$3"
  local origin="$4"        # origin to echo (may be empty)

  local content_length=${#body}
  local acao="Access-Control-Allow-Origin: *"
  if [ -n "$origin" ]; then
    acao="Access-Control-Allow-Origin: ${origin}"
  fi

  cat <<EOF
HTTP/1.1 ${status}
${acao}
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, X-API-Key
Access-Control-Max-Age: 86400
Vary: Origin
Content-Type: ${content_type}
Content-Length: ${content_length}
Connection: close

${body}
EOF
}

# --- handle a single request (reads from stdin) ---
handle_request() {
  # read request line
  IFS=$' \t' read -r method raw_path version || return

  # read headers
  origin=""
  client_api_key=""
  host=""
  while read -r header && [ "$header" != $'\r' ]; do
    # log header for debugging
    echo "H: $header" >&2
    case "$header" in
      Origin:*)
        origin=$(echo "$header" | cut -d' ' -f2- | tr -d '\r')
        ;;
      "X-API-Key:"*|"X-Api-Key:"*)
        client_api_key=$(echo "$header" | cut -d' ' -f2- | tr -d '\r')
        ;;
      Host:*)
        host=$(echo "$header" | cut -d' ' -f2- | tr -d '\r')
        ;;
    esac
  done

  # Log request-line for debugging
  echo "=> ${method} ${raw_path} from Origin=${origin} Host=${host}" >&2

  # Normalize path (drop query string)
  path="${raw_path%%\?*}"

  # Handle preflight immediately (no auth, no redirect)
  if [ "$method" = "OPTIONS" ]; then
    http_response "204 No Content" "text/plain" "" "${origin}"
    return
  fi

  # Auth (only for non-OPTIONS)
  if [ "$client_api_key" != "$API_KEY" ]; then
    http_response "401 Unauthorized" "text/plain" "Authentication failed. Provide X-API-Key" "${origin}"
    return
  fi

  case "$path" in
    /logs)
      output=$(git -C "$GIT_REPO_PATH" log "$GIT_BRANCH" -n 3 --pretty=format:'%h - %an, %ar : %s' 2>&1)
      http_response "200 OK" "text/plain; charset=utf-8" "$output" "${origin}"
      ;;
    /branch)
      output=$(git -C "$GIT_REPO_PATH" rev-parse --abbrev-ref HEAD 2>&1)
      http_response "200 OK" "text/plain; charset=utf-8" "$output" "${origin}"
      ;;
    /update)
      output=$(GIT_TERMINAL_PROMPT=0 git -C "$GIT_REPO_PATH" checkout "$GIT_BRANCH" && GIT_TERMINAL_PROMPT=0 git -C "$GIT_REPO_PATH" pull origin "$GIT_BRANCH" 2>&1)
      http_response "200 OK" "text/plain; charset=utf-8" "$output" "${origin}"
      ;;
    *)
      http_response "404 Not Found" "text/plain" "Endpoint not found. Available: /logs /branch /update" "${origin}"
      ;;
  esac
}

main() {
  load_env
  port=${PORT:-8080}
  backpipe=$(mktemp -u)
  mkfifo "$backpipe"
  trap 'rm -f "$backpipe"' EXIT

  echo "🚀 Gitman on http://localhost:$port (listening)" >&2

  while true; do
    # The same fan-in/out trick: cat reads response, nc listens, request piped to handler
    cat "$backpipe" | nc -l -p "$port" | (handle_request > "$backpipe")
  done
}

main
