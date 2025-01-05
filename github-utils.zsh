alias github-utils='function _github_utils() {
    # Source error handler if available
    local error_handler="${0:A:h}/../src/utils/error_handler.zsh"
    [[ -f "$error_handler" ]] && source "$error_handler"

    # Function to show help
    function _github_utils_help() {
        cat << EOF
Usage: github-utils <command> [options] [arguments]

GitHub utility functions for authentication and API operations.

Commands:
  auth                  Test GitHub authentication
  user                  Get user information
  repos                 List repositories
  rate                  Check API rate limits

Global Options:
  --help, -h           Show this help message
  --token TOKEN        GitHub token (or use GITHUB_TOKEN env var)
  --api-version VER    GitHub API version (default: 2022-11-28)

For command-specific help:
  github-utils <command> --help

Examples:
  github-utils auth --token "ghp_xxx"
  github-utils user
  github-utils repos --visibility public
  github-utils rate
EOF
    }

    # Show help if requested or no arguments
    if [[ "$1" == "--help" || "$1" == "-h" || $# -eq 0 ]]; then
        _github_utils_help
        return 0
    fi

    local cmd="$1"
    shift

    # Check for curl dependency
    if ! command -v curl &>/dev/null; then
        handle_error ${ERROR_CODES[DEPENDENCY_MISSING]} "Required command 'curl' not found"
        return ${ERROR_CODES[DEPENDENCY_MISSING]}
    fi

    # Common variables
    local token="${GITHUB_TOKEN}"
    local api_version="2022-11-28"
    local api_url="https://api.github.com"

    # Parse common options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --token)
                if [[ -z "$2" ]]; then
                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No token provided for --token"
                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                fi
                token="$2"
                shift 2
                ;;
            --api-version)
                if [[ -z "$2" ]]; then
                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No version provided for --api-version"
                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                fi
                api_version="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done

    # Function to make GitHub API calls
    function _github_api_call() {
        local endpoint="$1"
        local method="${2:-GET}"
        shift 2

        if [[ -z "$token" ]]; then
            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No GitHub token provided" "Set GITHUB_TOKEN env var or use --token"
            return ${ERROR_CODES[INVALID_ARGUMENT]}
        fi

        local response
        response=$(curl --silent --write-out "\n%{http_code}" \
            --request "$method" \
            --url "${api_url}${endpoint}" \
            --header "Authorization: Bearer ${token}" \
            --header "X-GitHub-Api-Version: ${api_version}" \
            --header "Accept: application/vnd.github+json" \
            "$@")

        local status_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | sed \$d)

        if [[ $status_code -ge 400 ]]; then
            handle_error ${ERROR_CODES[NETWORK_ERROR]} "GitHub API error (${status_code})" "$body"
            return ${ERROR_CODES[NETWORK_ERROR]}
        fi

        echo "$body"
    }

    case "$cmd" in
        auth)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: github-utils auth [options]

Test GitHub authentication status.

Options:
  --token TOKEN        GitHub token (or use GITHUB_TOKEN env var)
  --api-version VER    GitHub API version (default: 2022-11-28)
  --help, -h          Show this help message

Example:
  github-utils auth --token "ghp_xxx"
EOF
                return 0
            fi

            _github_api_call "/octocat" || return $?
            echo "Authentication successful!"
            ;;

        user)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: github-utils user [options]

Get authenticated user information.

Options:
  --token TOKEN        GitHub token (or use GITHUB_TOKEN env var)
  --api-version VER    GitHub API version (default: 2022-11-28)
  --help, -h          Show this help message

Example:
  github-utils user
EOF
                return 0
            fi

            _github_api_call "/user" || return $?
            ;;

        repos)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: github-utils repos [options]

List repositories for the authenticated user.

Options:
  --visibility TYPE    Filter by visibility (public, private, all)
  --sort FIELD        Sort by field (created, updated, pushed, full_name)
  --direction DIR     Sort direction (asc, desc)
  --token TOKEN       GitHub token (or use GITHUB_TOKEN env var)
  --api-version VER   GitHub API version (default: 2022-11-28)
  --help, -h         Show this help message

Example:
  github-utils repos --visibility public --sort updated
EOF
                return 0
            fi

            local visibility="" sort="" direction=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --visibility)
                        if [[ -z "$2" || ! "$2" =~ ^(public|private|all)$ ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Invalid visibility: $2" "Must be: public, private, or all"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        visibility="$2"
                        shift 2
                        ;;
                    --sort)
                        if [[ -z "$2" || ! "$2" =~ ^(created|updated|pushed|full_name)$ ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Invalid sort field: $2" "Must be: created, updated, pushed, or full_name"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        sort="$2"
                        shift 2
                        ;;
                    --direction)
                        if [[ -z "$2" || ! "$2" =~ ^(asc|desc)$ ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Invalid direction: $2" "Must be: asc or desc"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        direction="$2"
                        shift 2
                        ;;
                    *)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                esac
            done

            local query_params=""
            [[ -n "$visibility" ]] && query_params+="visibility=$visibility&"
            [[ -n "$sort" ]] && query_params+="sort=$sort&"
            [[ -n "$direction" ]] && query_params+="direction=$direction"
            [[ -n "$query_params" ]] && query_params="?${query_params%&}"

            _github_api_call "/user/repos${query_params}" || return $?
            ;;

        rate)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: github-utils rate [options]

Check GitHub API rate limits.

Options:
  --token TOKEN        GitHub token (or use GITHUB_TOKEN env var)
  --api-version VER    GitHub API version (default: 2022-11-28)
  --help, -h          Show this help message

Example:
  github-utils rate
EOF
                return 0
            fi

            _github_api_call "/rate_limit" || return $?
            ;;

        *)
            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown command: $cmd"
            _github_utils_help
            return ${ERROR_CODES[INVALID_ARGUMENT]}
            ;;
    esac
}; _github_utils'

# Maintain backward compatibility
alias github-auth='github-utils auth' 
