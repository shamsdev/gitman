#!/bin/bash

# --- Function to load .env file ---
load_env() {
  if [ ! -f .env ]; then
    echo "🔴 Error: .env file not found."
    exit 1
  fi

  # Export variables from .env file
  export $(grep -v '^#' .env | xargs)

  # Validate that necessary variables are set
  if [ -z "$GIT_REPO_PATH" ] || [ -z "$GIT_BRANCH" ] || [ -z "$API_KEY" ]; then
    echo "🔴 Error: GIT_REPO_PATH, GIT_BRANCH, and API_KEY must be set in .env"
    exit 1
  fi

  # Validate the git repository path
  if [ ! -d "$GIT_REPO_PATH/.git" ]; then
      echo "🔴 Error: '$GIT_REPO_PATH' is not a valid git repository."
      exit 1
  fi
}

# --- Function to send a standard HTTP response ---
# Usage: http_response "STATUS_CODE" "CONTENT_TYPE" "BODY"
http_response() {
  local status="$1"
  local content_type="$2"
  local body="$3"
  local content_length=${#body}

  echo -e "HTTP/1.1 ${status}\r\nContent-Type: ${content_type}\r\nContent-Length: ${content_length}\r\nConnection: close\r\n\r\n${body}"
}

# --- Function to handle an incoming API request ---
handle_request() {
  # Read the request method and path
  read -r method path version

  # Extract the API Key from the X-API-Key header
  client_api_key=""
  while read -r header && [ "$header" != $'\r' ]; do
    if [[ "$header" =~ ^X-API-Key: ]]; then
      client_api_key=$(echo "$header" | cut -d' ' -f2- | tr -d '\r')
    fi
  done

  # 1. --- Authentication ---
  if [ "$client_api_key" != "$API_KEY" ]; then
    http_response "401 Unauthorized" "text/plain" "Authentication failed. Provide a valid X-API-Key header."
    return
  fi

  # 2. --- API Routing ---
  case "$path" in
    "/logs")
      # Returns last 3 commits on the specified branch
      output=$(git -C "$GIT_REPO_PATH" log --branch "$GIT_BRANCH" -n 3 --pretty=format:'%h - %an, %ar : %s' 2>&1)
      http_response "200 OK" "text/plain; charset=utf-8" "$output"
      ;;
    "/branch")
      # Shows the current branch of the repository
      output=$(git -C "$GIT_REPO_PATH" rev-parse --abbrev-ref HEAD 2>&1)
      http_response "200 OK" "text/plain; charset=utf-8" "$output"
      ;;
    "/update")
      # Checks out the specified branch and pulls the latest changes
      output=$(git -C "$GIT_REPO_PATH" checkout "$GIT_BRANCH" && git -C "$GIT_REPO_PATH" pull origin "$GIT_BRANCH" 2>&1)
      http_response "200 OK" "text/plain; charset=utf-8" "Update process started...\n\n$output"
      ;;
    *)
      http_response "404 Not Found" "text/plain" "Endpoint not found. Available endpoints: /logs, /branch, /update"
      ;;
  esac
}

# --- Main Server Loop ---
main() {
  load_env
  # Use PORT from .env file, with 8080 as a fallback
  local port=${PORT:-8080}

  echo "🚀 Gitman is running on http://localhost:$port"
  echo "📁 Repository: $GIT_REPO_PATH"
  echo "🌿 Branch: $GIT_BRANCH"
  echo "Press Ctrl+C to stop."

  # The `while true` loop ensures the server stays running.
  # `nc` (netcat) listens for a connection, pipes it to our handler, and sends the response back.
  while true; do
    handle_request | nc -l -p "$port" -q 1
  done
}

# --- Start the Server ---
main