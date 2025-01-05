alias ollama-util='function _ollama_util() {
    # Define common binary paths
    local OLLAMA_BINARY="/usr/local/bin/ollama"
    local GREP_BINARY="/usr/bin/grep"
    local DOCKER_BINARY="/usr/local/bin/docker"
    local PGREP_BINARY="/usr/bin/pgrep"
    local FIND_BINARY="/usr/bin/find"
    local AWK_BINARY="/usr/bin/awk"
    local RM_BINARY="/bin/rm"
    local CURL_BINARY="/usr/bin/curl"
    local JQ_BINARY="/opt/homebrew/bin/jq"
    
    # Ensure proper PATH
    export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
    
    # Check for required tools
    for cmd in "$CURL_BINARY" "$JQ_BINARY"; do
        if ! [[ -x "$cmd" ]]; then
            echo "Missing required tool: $cmd"
            echo "Please install curl and jq"
            return 1
        fi
    done
    
    # Check if ollama is installed
    if ! [[ -x "$OLLAMA_BINARY" ]]; then
        echo "Ollama is not installed. Would you like to install it? (y/n)"
        read -q response || return 1
        echo
        
        if command -v brew >/dev/null 2>&1; then
            echo "Installing Ollama via Homebrew..."
            brew install ollama
            
            # Verify installation
            if ! [[ -x "$OLLAMA_BINARY" ]]; then
                echo "Failed to install Ollama"
                return 1
            fi
        else
            echo "Please install Ollama from: https://ollama.ai/download"
            return 1
        fi
    fi
    
    local _OLLAMA_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ollama/config"
    [[ -f "$_OLLAMA_CONFIG" ]] && source "$_OLLAMA_CONFIG"
    
    local _OLLAMA_WEBUI_PORT=3000
    local _OLLAMA_WEBUI_CONTAINER="open-webui"
    local _OLLAMA_CONTEXT_DEFAULT_RECURSIVE=false
    
    # Show help if no arguments or help flag
    [[ "$1" == "--help" || "$1" == "-h" || $# -eq 0 ]] && {
        echo "Usage: ollama-util [command] [options]"
        echo "Commands:"
        echo "  --update-models     Update all installed models"
        echo "  --web              Start the web UI"
        echo "  --restart          Restart the Ollama service"
        echo "  --embed [path]     Generate embeddings for files"
        echo "  --clean            Clean up temporary files and containers"
        echo "  --status           Show Ollama service status"
        return 0
    }
    
    # Check if Ollama service is running
    if ! "$PGREP_BINARY" -f ollama >/dev/null 2>&1; then
        echo "Ollama service is not running. Starting it..."
        if command -v brew >/dev/null 2>&1; then
            brew services start ollama
            echo "Waiting for service to start..."
            sleep 5
        else
            echo "Unable to start Ollama service. Please start it manually."
            return 1
        fi
    fi
    
    case "$1" in
        --update-models)
            echo "Updating installed models..."
            "$OLLAMA_BINARY" list 2>/dev/null | "$AWK_BINARY" "NR>1 {print \$1}" | while read -r model; do
                echo "Updating model: $model"
                "$OLLAMA_BINARY" pull "$model"
            done
            ;;
            
        --web)
            if ! [[ -x "$DOCKER_BINARY" ]]; then
                echo "Docker is not installed. Please install Docker first."
                return 1
            fi
            
            if "$DOCKER_BINARY" ps -a | "$GREP_BINARY" -q "${_OLLAMA_WEBUI_CONTAINER}"; then
                echo "Starting existing web UI container..."
                "$DOCKER_BINARY" start "${_OLLAMA_WEBUI_CONTAINER}"
            else
                echo "Creating new web UI container..."
                "$DOCKER_BINARY" run -d \
                    -p "${_OLLAMA_WEBUI_PORT}:8080" \
                    -v open-webui:/app/backend/data \
                    --network host \
                    --name "${_OLLAMA_WEBUI_CONTAINER}" \
                    ghcr.io/open-webui/open-webui:main
            fi
            
            echo "Web UI available at: http://localhost:${_OLLAMA_WEBUI_PORT}"
            ;;
            
        --restart)
            echo "Restarting Ollama service..."
            if command -v brew >/dev/null 2>&1; then
                brew services restart ollama
                echo "Waiting for service to restart..."
                sleep 5
            else
                echo "Unable to restart Ollama service. Please restart manually."
                return 1
            fi
            ;;
            
        --embed)
            local path="${2:-.}"
            [[ ! -e "$path" ]] && { echo "Path does not exist: $path"; return 1; }
            
            # Check if model is installed for embeddings
            local embed_model="all-minilm"
            if ! "$OLLAMA_BINARY" list 2>/dev/null | "$GREP_BINARY" -q "$embed_model"; then
                echo "Installing $embed_model model for embeddings..."
                "$OLLAMA_BINARY" pull "$embed_model"
            fi
            
            local files=()
            if [[ -d "$path" ]]; then
                if [[ "$_OLLAMA_CONTEXT_DEFAULT_RECURSIVE" == "true" ]]; then
                    files=($("$FIND_BINARY" "$path" -type f -name "*.txt" -o -name "*.md" -o -name "*.csv"))
                else
                    files=($("$FIND_BINARY" "$path" -maxdepth 1 -type f -name "*.txt" -o -name "*.md" -o -name "*.csv"))
                fi
            else
                files=("$path")
            fi
            
            for file in "${files[@]}"; do
                echo "Generating embeddings for: $file"
                # Read file content
                local content=$(<"$file")
                
                # Generate embeddings using API
                "$CURL_BINARY" -X POST http://localhost:11434/api/embeddings \
                    -H "Content-Type: application/json" \
                    -d "{
                        \"model\": \"$embed_model\",
                        \"prompt\": $(printf '%s' "$content" | "$JQ_BINARY" -R -s '.')
                    }" | "$JQ_BINARY" '.' > "${file}.embeddings.json"
                
                echo "Embeddings saved to: ${file}.embeddings.json"
            done
            ;;
            
        --clean)
            echo "Cleaning up Ollama resources..."
            if [[ -x "$DOCKER_BINARY" ]]; then
                "$DOCKER_BINARY" rm -f "${_OLLAMA_WEBUI_CONTAINER}" 2>/dev/null
                "$DOCKER_BINARY" volume rm open-webui 2>/dev/null
            fi
            "$RM_BINARY" -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ollama"/* 2>/dev/null
            echo "Cleanup complete"
            ;;
            
        --status)
            echo "Ollama Service Status:"
            if "$PGREP_BINARY" -f ollama >/dev/null 2>&1; then
                echo "Service: Running"
            else
                echo "Service: Not Running"
            fi
            
            echo -e "\nInstalled Models:"
            "$OLLAMA_BINARY" list 2>/dev/null || echo "No models installed"
            
            if [[ -x "$DOCKER_BINARY" ]] && "$DOCKER_BINARY" ps | "$GREP_BINARY" -q "${_OLLAMA_WEBUI_CONTAINER}"; then
                echo -e "\nWeb UI running at: http://localhost:${_OLLAMA_WEBUI_PORT}"
            fi
            ;;
            
        *)
            echo "Unknown command: $1"
            echo "Use --help to see available commands"
            return 1
            ;;
    esac
}; _ollama_util'
