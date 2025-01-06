#!/usr/bin/env zsh

# Docker utilities for container and image management
# Author: Lou Grossi
# Company: ncdLabs

# Source this file to use the docker-utils function
if [[ $ZSH_EVAL_CONTEXT =~ :file$ ]]; then
    # Being sourced from zsh
    : # Do nothing
elif [[ -n $BASH_VERSION ]] && [[ ${BASH_SOURCE[0]} != $0 ]]; then
    # Being sourced from bash
    : # Do nothing
else
    echo "This file must be sourced" >&2
    return 1 2>/dev/null || exit 1
fi

# Color support - simplified and safer
if [[ -t 1 ]]; then
    # Terminal color definitions using tput with explicit resets
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    BOLD=""
    RESET=""
fi

# Simpler color output helpers
function _format() {
    local color=$1
    shift
    echo -n "${color}$*${RESET}"
}

function _format_bold() {
    local color=$1
    shift
    echo -n "${BOLD}${color}$*${RESET}"
}

# Fallback error handler if the external one isn't available
function _docker_utils_error() {
    local code=$1
    local message=$2
    local suggestion=${3:-}
    
    case $code in
        1) local type="GENERAL_ERROR" ;;
        2) local type="INVALID_ARGUMENT" ;;
        3) local type="PERMISSION_DENIED" ;;
        4) local type="DEPENDENCY_MISSING" ;;
        *) local type="UNKNOWN_ERROR" ;;
    esac
    
    _error_message "$type" "$message" "$suggestion"
    return $code
}

# Version check function
function _check_docker_version() {
    local min_version="20.10.0"
    local current_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    
    if [[ -z "$current_version" ]]; then
        _docker_utils_error 1 "Could not determine Docker version"
        return 1
    fi
    
    # Simple version comparison
    if [[ "$current_version" < "$min_version" ]]; then
        _docker_utils_error 1 "Docker version $current_version is below minimum required version $min_version"
        return 1
    fi
    return 0
}

# Move compose check to top level
function _check_docker_compose() {
    if command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    elif docker compose version &>/dev/null; then
        echo "docker compose"
    else
        _docker_utils_error 1 "Docker Compose not found"
        return 1
    fi
}

# Progress indicator for long-running operations
function _show_progress() {
    local message=$1
    local pid=$2
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local start_time=$(date +%s)

    # Don't show progress if not in terminal or verbose is false
    [[ ! -t 1 ]] || ! $verbose && return

    echo -n "🔄 $message "
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "%c" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b"
        
        # Show elapsed time every second
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if ((elapsed % 10 == 0)); then
            printf "\r⏱️  $message (${elapsed}s) "
        fi
    done
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    echo "✅ done (${total_time}s)"
}

# Add success message function
function _success() {
    echo "$(_format green "✅ $*")"
}

# Standardized verbose output
function _verbose() {
    $verbose && echo "$(_format cyan "📝 [VERBOSE]") $*"
}

# Standardized dry run output
function _dry_run() {
    $dry_run && echo "$(_format blue "🔍 [DRY RUN]") Would $*"
}

# Standardized operation output
function _operation() {
    local operation=$1
    shift
    
    if $dry_run; then
        _dry_run "$operation $*"
        return 0
    fi

    if $verbose; then
        _verbose "Executing: $operation $*"
        eval "$operation $*"
    else
        eval "$operation $*" &>/dev/null &
        local pid=$!
        _show_progress "Executing $operation..." $pid
        wait $pid
    fi
    return $?
}

# Add after other helper functions
function _confirm_action() {
    local action=$1
    local target=$2
    
    # Skip confirmation if force is enabled
    $force && return 0
    
    # Skip confirmation in non-interactive mode
    [[ ! -t 0 ]] && return 0
    
    echo -n "$(_format_bold yellow "⚠️  Are you sure you want to $action $target?") [y/N] "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] && return 0
    return 1
}

# Add after existing helper functions
function _error_message() {
    local error_type=$1
    local message=$2
    local suggestion=${3:-}
    
    echo "$(_format_bold red "❌ Error ($error_type):") $(_format red "$message")" >&2
    [[ -n "$suggestion" ]] && echo "$(_format_bold yellow "💡 Suggestion:") $(_format yellow "$suggestion")" >&2
}

docker-utils() {
    # Use built-in error handler directly
    function handle_error() { _docker_utils_error "$@"; }

    # Add version check
    _check_docker_version || return $?

    # Function to show help
    function _docker_utils_help() {
        cat << EOF
Usage: docker-utils <command> [options] [arguments]

Docker utility functions for container and image management.

Core Commands:
  clean <target>     Clean resources (containers|images|volumes|networks|all)
  prune              Remove unused resources
  stats              Show container statistics
  logs               View container logs
  inspect           Inspect container or image

Management Commands:
  network           Manage Docker networks
  volume            Manage volumes
  compose           Docker Compose utilities
  dockerfile        Generate Dockerfile from image

Global Options:
  --help, -h         Show help message
  --verbose, -v      Enable verbose output
  --dry-run         Show what would be done
  --force, -f       Force operations without confirmation

Quick Examples:
  docker-utils clean containers     # Remove all stopped containers
  docker-utils clean images         # Remove unused images
  docker-utils dockerfile nginx     # Generate Dockerfile from nginx image
  docker-utils logs -f myapp        # Follow container logs

For detailed help on any command:
  docker-utils <command> --help
EOF
    }

    # Show help if requested or no arguments
    if [[ "$1" == "--help" || "$1" == "-h" || $# -eq 0 ]]; then
        _docker_utils_help
        return 0
    fi

    # Check for docker dependency
    if ! command -v docker &>/dev/null; then
        handle_error ${ERROR_CODES[DEPENDENCY_MISSING]} "Required command 'docker' not found"
        return ${ERROR_CODES[DEPENDENCY_MISSING]}
    fi

    local cmd="$1"
    shift

    # Common variables
    local verbose=false
    local dry_run=false
    local force=false

    # Parse common options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                verbose=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force|-f)
                force=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    case "$cmd" in
        clean)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: docker-utils clean <target> [options]

Clean Docker resources.

Targets:
  images            Clean unused images
  containers       Clean stopped containers
  volumes          Clean unused volumes
  networks         Clean unused networks
  all              Clean everything

Options:
  --force          Force removal
  --help, -h       Show this help message

Examples:
  docker-utils clean images
  docker-utils clean containers
  docker-utils clean all --force
  docker-utils clean volumes
EOF
                return 0
            fi

            local force=false
            local target=""

            # Get the target first
            if [[ -n "$1" ]]; then
                case "$1" in
                    images|containers|volumes|networks|all)
                        target="$1"
                        shift
                        ;;
                    *)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Invalid target: $1" "Must be: images, containers, volumes, networks, or all"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                esac
            else
                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No target specified"
                return ${ERROR_CODES[INVALID_ARGUMENT]}
            fi

            # Parse remaining options
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --force)
                        force=true
                        shift
                        ;;
                    *)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                esac
            done

            local force_opt=""
            $force && force_opt="--force"

            if ! $dry_run; then
                case "$target" in
                    containers)
                        local containers=($(docker ps -a -q))
                        if [[ ${#containers[@]} -eq 0 ]]; then
                            _verbose "No containers to clean"
                            return 0
                        fi
                        
                        if ! $dry_run; then
                            _confirm_action "remove all" "containers" || return 0
                            for container_id in "${containers[@]}"; do
                                local name=$(docker inspect --format '{{.Name}}' "$container_id" 2>/dev/null)
                                _verbose "Processing container: $name ($container_id)"
                                _operation "docker stop" "$container_id"
                                _operation "docker rm" "$container_id" || \
                                    handle_error ${ERROR_CODES[PERMISSION_DENIED]} "Failed to remove container: $container_id"
                            done
                        else
                            _dry_run "clean ${#containers[@]} containers"
                        fi
                        ;;
                    images)
                        if ! $dry_run; then
                            _verbose "Removing unused images"
                            _operation "docker images -q | xargs -r docker rmi" "$force_opt" || \
                                handle_error ${ERROR_CODES[PERMISSION_DENIED]} "Failed to remove some images"
                        else
                            _dry_run "remove unused images"
                        fi
                        ;;
                    volumes)
                        if docker volume ls -q | xargs -r docker volume rm $force_opt; then
                            $verbose && echo "Removed unused volumes"
                        else
                            handle_error ${ERROR_CODES[PERMISSION_DENIED]} "Failed to remove some volumes"
                        fi
                        ;;
                    networks)
                        if docker network ls -q -f "type=custom" | xargs -r docker network rm; then
                            $verbose && echo "Removed unused networks"
                        else
                            handle_error ${ERROR_CODES[PERMISSION_DENIED]} "Failed to remove some networks"
                        fi
                        ;;
                    all)
                        # Clean in order: containers, images, volumes, networks
                        local containers=($(docker ps -a -q))
                        for container_id in "${containers[@]}"; do
                            if docker stop "$container_id" && docker rm "$container_id"; then
                                $verbose && echo "Removed container: $container_id"
                            fi
                        done

                        if docker images -q | xargs -r docker rmi $force_opt; then
                            $verbose && echo "Removed unused images"
                        fi

                        if docker volume ls -q | xargs -r docker volume rm $force_opt; then
                            $verbose && echo "Removed unused volumes"
                        fi

                        if docker network ls -q -f "type=custom" | xargs -r docker network rm; then
                            $verbose && echo "Removed unused networks"
                        fi
                        ;;
                esac
            else
                echo "[DRY RUN] Would clean $target"
            fi
            ;;

        prune)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: docker-utils prune [options]

Prune Docker system resources.

Options:
  --all              Remove all unused resources
  --volumes         Remove unused volumes
  --force          Force removal without confirmation
  --help, -h       Show this help message

Examples:
  docker-utils prune --all
  docker-utils prune --volumes
EOF
                return 0
            fi

            local prune_all=false
            local prune_volumes=false
            local force=false

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --all)
                        prune_all=true
                        shift
                        ;;
                    --volumes)
                        prune_volumes=true
                        shift
                        ;;
                    --force)
                        force=true
                        shift
                        ;;
                    *)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                esac
            done

            local force_opt=""
            $force && force_opt="--force"

            if ! $dry_run; then
                if $prune_all; then
                    docker system prune -a $force_opt
                elif $prune_volumes; then
                    docker volume prune $force_opt
                else
                    docker system prune $force_opt
                fi
            else
                if $prune_all; then
                    echo "[DRY RUN] Would prune all unused resources"
                elif $prune_volumes; then
                    echo "[DRY RUN] Would prune unused volumes"
                else
                    echo "[DRY RUN] Would prune unused resources"
                fi
            fi
            ;;

        stats)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: docker-utils stats [options] [container]

Show container resource usage statistics.

Options:
  --all              Show all containers
  --no-stream       Disable live streaming
  --format FMT     Output format (table, json)
  --help, -h       Show this help message

Examples:
  docker-utils stats
  docker-utils stats --all
  docker-utils stats mycontainer
EOF
                return 0
            fi

            local show_all=false
            local no_stream=false
            local format=""
            local container=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --all)
                        show_all=true
                        shift
                        ;;
                    --no-stream)
                        no_stream=true
                        shift
                        ;;
                    --format)
                        if [[ -z "$2" || ! "$2" =~ ^(table|json)$ ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Invalid format: $2" "Must be: table or json"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        format="$2"
                        shift 2
                        ;;
                    -*)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                    *)
                        if [[ -z "$container" ]]; then
                            container="$1"
                        else
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unexpected argument: $1"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        shift
                        ;;
                esac
            done

            local cmd_opts=""
            $show_all && cmd_opts+=" --all"
            $no_stream && cmd_opts+=" --no-stream"
            [[ -n "$format" ]] && cmd_opts+=" --format $format"
            [[ -n "$container" ]] && cmd_opts+=" $container"

            if ! $dry_run; then
                eval "docker stats$cmd_opts"
            else
                echo "[DRY RUN] Would show stats with options:$cmd_opts"
            fi
            ;;

        logs)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: docker-utils logs [options] <container>

View container logs.

Options:
  --tail NUM        Number of lines to show
  --follow, -f     Follow log output
  --since TIME     Show logs since timestamp
  --until TIME     Show logs before timestamp
  --help, -h       Show this help message

Examples:
  docker-utils logs myapp
  docker-utils logs --tail 100 myapp
  docker-utils logs -f myapp
EOF
                return 0
            fi

            local tail=""
            local follow=false
            local since=""
            local until=""
            local container=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --tail)
                        if [[ -z "$2" || ! "$2" =~ ^[0-9]+$ ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Invalid tail value: $2"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        tail="$2"
                        shift 2
                        ;;
                    --follow|-f)
                        follow=true
                        shift
                        ;;
                    --since)
                        if [[ -z "$2" ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No since time specified"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        since="$2"
                        shift 2
                        ;;
                    --until)
                        if [[ -z "$2" ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No until time specified"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        until="$2"
                        shift 2
                        ;;
                    -*)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                    *)
                        if [[ -z "$container" ]]; then
                            container="$1"
                        else
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unexpected argument: $1"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        shift
                        ;;
                esac
            done

            if [[ -z "$container" ]]; then
                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No container specified"
                return ${ERROR_CODES[INVALID_ARGUMENT]}
            fi

            local cmd_opts=""
            [[ -n "$tail" ]] && cmd_opts+=" --tail $tail"
            $follow && cmd_opts+=" --follow"
            [[ -n "$since" ]] && cmd_opts+=" --since $since"
            [[ -n "$until" ]] && cmd_opts+=" --until $until"

            if ! $dry_run; then
                eval "docker logs$cmd_opts $container"
            else
                echo "[DRY RUN] Would show logs for container $container with options:$cmd_opts"
            fi
            ;;

        inspect)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: docker-utils inspect [options] <target>

Inspect Docker container or image.

Options:
  --format FMT     Output format (json, pretty)
  --type TYPE     Target type (container, image)
  --help, -h      Show this help message

Examples:
  docker-utils inspect mycontainer
  docker-utils inspect --type image myimage
  docker-utils inspect --format pretty mycontainer
EOF
                return 0
            fi

            local format=""
            local type=""
            local target=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --format)
                        if [[ -z "$2" || ! "$2" =~ ^(json|pretty)$ ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Invalid format: $2" "Must be: json or pretty"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        format="$2"
                        shift 2
                        ;;
                    --type)
                        if [[ -z "$2" || ! "$2" =~ ^(container|image)$ ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Invalid type: $2" "Must be: container or image"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        type="$2"
                        shift 2
                        ;;
                    -*)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                    *)
                        if [[ -z "$target" ]]; then
                            target="$1"
                        else
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unexpected argument: $1"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        shift
                        ;;
                esac
            done

            if [[ -z "$target" ]]; then
                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No target specified"
                return ${ERROR_CODES[INVALID_ARGUMENT]}
            fi

            local cmd_opts=""
            [[ "$format" == "pretty" ]] && cmd_opts+=' --format="{{json .}}"'

            if ! $dry_run; then
                if [[ "$format" == "pretty" ]]; then
                    eval "docker inspect$cmd_opts $target | jq ."
                else
                    eval "docker inspect$cmd_opts $target"
                fi
            else
                echo "[DRY RUN] Would inspect $target with options:$cmd_opts"
            fi
            ;;

        network)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: docker-utils network <action> [options]

Manage Docker networks.

Actions:
  list              List networks
  create           Create a network
  rm               Remove network(s)
  prune            Remove unused networks

Options:
  --driver DRV     Network driver
  --subnet NET     Subnet in CIDR format
  --force, -f     Force operation without confirmation
  --help, -h      Show this help message

Examples:
  docker-utils network list
  docker-utils network create --driver bridge mynet
  docker-utils network rm mynet
EOF
                return 0
            fi

            local action="$1"
            shift

            case "$action" in
                list)
                    docker network ls
                    ;;
                create)
                    local name=""
                    local driver=""
                    local subnet=""

                    while [[ $# -gt 0 ]]; do
                        case "$1" in
                            --driver)
                                if [[ -z "$2" ]]; then
                                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No driver specified"
                                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                                fi
                                driver="$2"
                                shift 2
                                ;;
                            --subnet)
                                if [[ -z "$2" ]]; then
                                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No subnet specified"
                                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                                fi
                                subnet="$2"
                                shift 2
                                ;;
                            -*)
                                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                                return ${ERROR_CODES[INVALID_ARGUMENT]}
                                ;;
                            *)
                                if [[ -z "$name" ]]; then
                                    name="$1"
                                else
                                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unexpected argument: $1"
                                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                                fi
                                shift
                                ;;
                        esac
                    done

                    if [[ -z "$name" ]]; then
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No network name specified"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                    fi

                    local cmd_opts=""
                    [[ -n "$driver" ]] && cmd_opts+=" --driver $driver"
                    [[ -n "$subnet" ]] && cmd_opts+=" --subnet $subnet"

                    if ! $dry_run; then
                        eval "docker network create$cmd_opts $name"
                    else
                        echo "[DRY RUN] Would create network $name with options:$cmd_opts"
                    fi
                    ;;
                rm)
                    if [[ -z "$1" ]]; then
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No network specified"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                    fi

                    if ! $dry_run; then
                        docker network rm "$@"
                    else
                        echo "[DRY RUN] Would remove networks: $@"
                    fi
                    ;;
                prune)
                    if ! $dry_run; then
                        docker network prune
                    else
                        echo "[DRY RUN] Would prune unused networks"
                    fi
                    ;;
                *)
                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Invalid network action: $action"
                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                    ;;
            esac
            ;;

        volume)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: docker-utils volume <action> [options]

Manage Docker volumes.

Actions:
  list              List volumes
  create           Create a volume
  rm               Remove volume(s)
  prune            Remove unused volumes
  inspect         Inspect volume(s)

Options:
  --driver DRV     Volume driver
  --opt KEY=VAL    Set driver specific options
  --force, -f     Force operation without confirmation
  --help, -h      Show this help message

Examples:
  docker-utils volume list
  docker-utils volume create --driver local myvolume
  docker-utils volume rm myvolume
EOF
                return 0
            fi

            local action="$1"
            shift

            case "$action" in
                list)
                    _operation "docker volume ls"
                    ;;
                create)
                    local name=""
                    local driver=""
                    local -a opts=()

                    while [[ $# -gt 0 ]]; do
                        case "$1" in
                            --driver)
                                if [[ -z "$2" ]]; then
                                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No driver specified"
                                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                                fi
                                driver="$2"
                                shift 2
                                ;;
                            --opt)
                                if [[ -z "$2" ]]; then
                                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No option specified"
                                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                                fi
                                opts+=("$2")
                                shift 2
                                ;;
                            -*)
                                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                                return ${ERROR_CODES[INVALID_ARGUMENT]}
                                ;;
                            *)
                                if [[ -z "$name" ]]; then
                                    name="$1"
                                else
                                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unexpected argument: $1"
                                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                                fi
                                shift
                                ;;
                        esac
                    done

                    if [[ -z "$name" ]]; then
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No volume name specified"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                    fi

                    local cmd_opts=""
                    [[ -n "$driver" ]] && cmd_opts+=" --driver $driver"
                    for opt in "${opts[@]}"; do
                        cmd_opts+=" --opt $opt"
                    done

                    if ! $dry_run; then
                        _operation "docker volume create$cmd_opts" "$name"
                    else
                        echo "[DRY RUN] Would create volume $name with options:$cmd_opts"
                    fi
                    ;;
                rm)
                    if [[ -z "$1" ]]; then
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No volume specified"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                    fi

                    if ! $dry_run; then
                        _confirm_action "remove" "volumes: $*" || return 0
                        _operation "docker volume rm" "$@" || \
                            handle_error ${ERROR_CODES[PERMISSION_DENIED]} "Failed to remove volumes: $*"
                    else
                        _dry_run "remove volumes: $*"
                    fi
                    ;;
                prune)
                    if ! $dry_run; then
                        docker volume prune
                    else
                        echo "[DRY RUN] Would prune unused volumes"
                    fi
                    ;;
                inspect)
                    if [[ -z "$1" ]]; then
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No volume specified"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                    fi

                    if ! $dry_run; then
                        docker volume inspect "$@"
                    else
                        echo "[DRY RUN] Would inspect volumes: $@"
                    fi
                    ;;
                *)
                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Invalid volume action: $action"
                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                    ;;
            esac
            ;;

        compose)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: docker-utils compose <action> [options]

Docker Compose utilities.

Actions:
  up                Start services
  down              Stop services
  ps                List containers
  logs              View service logs
  restart          Restart services

Options:
  --file FILE      Compose file (default: docker-compose.yml)
  --project PRJ    Project name
  --help, -h      Show this help message

Examples:
  docker-utils compose up -d
  docker-utils compose down
  docker-utils compose logs --tail 100
EOF
                return 0
            fi

            local action="$1"
            shift

            local compose_cmd=$(_check_docker_compose)
            if [[ $? -eq 0 ]]; then
                if ! $dry_run; then
                    $compose_cmd "$action" "$@"
                else
                    echo "[DRY RUN] Would execute: $compose_cmd $action $@"
                fi
            fi
            ;;

        rebuild)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: docker-utils rebuild <image> [options]

Rebuild a container image from its Dockerfile.

Options:
  --no-cache       Do not use cache when building the image
  --pull           Always pull newer version of base image
  --help, -h       Show this help message

Examples:
  docker-utils rebuild myapp
  docker-utils rebuild myapp:latest --no-cache
  docker-utils rebuild myapp --pull
EOF
                return 0
            fi

            local image=""
            local no_cache=false
            local pull=false

            # Parse arguments
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --no-cache)
                        no_cache=true
                        shift
                        ;;
                    --pull)
                        pull=true
                        shift
                        ;;
                    -*)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                    *)
                        if [[ -z "$image" ]]; then
                            image="$1"
                        else
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unexpected argument: $1"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        shift
                        ;;
                esac
            done

            if [[ -z "$image" ]]; then
                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No image specified"
                return ${ERROR_CODES[INVALID_ARGUMENT]}
            fi

            # Find Dockerfile location
            local dockerfile=""
            if [[ -f "./Dockerfile" ]]; then
                dockerfile="./Dockerfile"
            elif [[ -f "./docker/Dockerfile" ]]; then
                dockerfile="./docker/Dockerfile"
            else
                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Could not find Dockerfile" "Ensure you're in the correct directory"
                return ${ERROR_CODES[INVALID_ARGUMENT]}
            fi

            # Build command options
            local cmd_opts=""
            $no_cache && cmd_opts+=" --no-cache"
            $pull && cmd_opts+=" --pull"

            if ! $dry_run; then
                _verbose "Rebuilding image $image using $dockerfile"
                _operation "docker build$cmd_opts -t $image -f $dockerfile ." || \
                    handle_error ${ERROR_CODES[PERMISSION_DENIED]} "Failed to rebuild image: $image"
            else
                _dry_run "rebuild image $image using $dockerfile with options:$cmd_opts"
            fi
            ;;

        dockerfile)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: docker-utils dockerfile <image> [options]

Generate a Dockerfile from an existing image.

Options:
  --output FILE    Output file (default: Dockerfile.generated)
  --help, -h      Show this help message

Examples:
  docker-utils dockerfile nginx:latest
  docker-utils dockerfile redis:6 --output Dockerfile.redis
EOF
                return 0
            fi

            local image=""
            local output="Dockerfile.generated"

            # Parse arguments
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --output)
                        if [[ -z "$2" ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No output file specified"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        output="$2"
                        shift 2
                        ;;
                    -*)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                    *)
                        if [[ -z "$image" ]]; then
                            image="$1"
                        else
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unexpected argument: $1"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        shift
                        ;;
                esac
            done

            if [[ -z "$image" ]]; then
                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No image specified"
                return ${ERROR_CODES[INVALID_ARGUMENT]}
            fi

            if [[ -f "$output" ]]; then
                if ! _confirm_action "overwrite" "$output"; then
                    return 0
                fi
            fi

            if ! $dry_run; then
                _verbose "Analyzing image: $image"
                
                # Get base image
                local base_image=$(docker inspect --format='{{.Config.Image}}' "$image" 2>/dev/null)
                if [[ -z "$base_image" ]]; then
                    base_image=$(docker history "$image" | tail -1 | awk '{print $1}')
                fi

                # Start building the Dockerfile
                {
                    echo "# Generated from $image"
                    echo "# Generated on $(date)"
                    echo
                    echo "FROM $base_image"
                    echo

                    # Get environment variables
                    docker inspect --format='{{range .Config.Env}}ENV {{.}}{{"\n"}}{{end}}' "$image"

                    # Get exposed ports
                    docker inspect --format='{{range $port, $_ := .Config.ExposedPorts}}EXPOSE {{$port}}{{"\n"}}{{end}}' "$image"

                    # Get volumes
                    docker inspect --format='{{range $volume, $_ := .Config.Volumes}}VOLUME ["{{$volume}}"]{{"\n"}}{{end}}' "$image"

                    # Get working directory
                    docker inspect --format='{{if .Config.WorkingDir}}WORKDIR {{.Config.WorkingDir}}{{"\n"}}{{end}}' "$image"

                    # Get entrypoint
                    docker inspect --format='{{if .Config.Entrypoint}}ENTRYPOINT {{json .Config.Entrypoint}}{{"\n"}}{{end}}' "$image"

                    # Get cmd
                    docker inspect --format='{{if .Config.Cmd}}CMD {{json .Config.Cmd}}{{"\n"}}{{end}}' "$image"

                    # Get history for RUN commands
                    echo -e "\n# Layer history:"
                    docker history --no-trunc "$image" | \
                        grep -v '^<missing>' | \
                        tail -n +2 | \
                        awk '{$1=$2=$3=$4=""; print $0}' | \
                        sed 's/^    //' | \
                        grep -v '^$' | \
                        while read -r cmd; do
                            if [[ "$cmd" =~ ^/bin/sh\ -c\ #\(nop\) ]]; then
                                # Skip no-op commands
                                continue
                            elif [[ "$cmd" =~ ^/bin/sh\ -c ]]; then
                                echo "RUN ${cmd#/bin/sh -c }"
                            else
                                echo "# $cmd"
                            fi
                        done
                } > "$output"

                _success "Generated Dockerfile at: $output"
            else
                _dry_run "generate Dockerfile from $image to $output"
            fi
            ;;

        *)
            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown command: $cmd"
            _docker_utils_help
            return ${ERROR_CODES[INVALID_ARGUMENT]}
            ;;
    esac
}

# Maintain backward compatibility
alias docker-clean='docker-utils clean'

# Common operation aliases
alias docker-clean-all='docker-utils clean all'
alias docker-clean-containers='docker-utils clean containers'
alias docker-clean-images='docker-utils clean images'
alias docker-clean-volumes='docker-utils clean volumes'
alias docker-clean-networks='docker-utils clean networks'

# Command completion
function _docker_utils() {
    local -a commands
    commands=(
        'clean:Clean Docker resources'
        'prune:Prune system resources'
        'stats:Show container statistics'
        'logs:View container logs'
        'inspect:Inspect container or image'
        'network:Manage networks'
        'volume:Manage volumes'
        'compose:Docker Compose utilities'
        'rebuild:Rebuild container from image'
        'dockerfile:Generate Dockerfile from existing image'
    )

    local -a clean_targets
    clean_targets=(
        'images:Clean unused images'
        'containers:Clean stopped containers'
        'volumes:Clean unused volumes'
        'networks:Clean unused networks'
        'all:Clean everything'
    )

    local -a network_actions
    network_actions=(
        'list:List networks'
        'create:Create a network'
        'rm:Remove network(s)'
        'prune:Remove unused networks'
    )

    local -a volume_actions
    volume_actions=(
        'list:List volumes'
        'create:Create a volume'
        'rm:Remove volume(s)'
        'prune:Remove unused volumes'
        'inspect:Inspect volume(s)'
    )

    local -a compose_actions
    compose_actions=(
        'up:Start services'
        'down:Stop services'
        'ps:List containers'
        'logs:View service logs'
        'restart:Restart services'
    )

    _arguments \
        '(-h --help)'{-h,--help}'[Show help information]' \
        '(-v --verbose)'{-v,--verbose}'[Enable verbose output]' \
        '--dry-run[Show what would be done]' \
        '(-f --force)'{-f,--force}'[Force operations without confirmation]' \
        '1: :->command' \
        '*:: :->args'

    case $state in
        command)
            _describe -t commands 'docker-utils commands' commands
            ;;
        args)
            case $words[1] in
                clean)
                    _describe -t clean_targets 'clean targets' clean_targets
                    ;;
                network)
                    _describe -t network_actions 'network actions' network_actions
                    ;;
                volume)
                    _describe -t volume_actions 'volume actions' volume_actions
                    ;;
                compose)
                    _describe -t compose_actions 'compose actions' compose_actions
                    ;;
                rebuild)
                    _describe -t compose_actions 'compose actions' compose_actions
                    ;;
                dockerfile)
                    _describe -t compose_actions 'compose actions' compose_actions
                    ;;
            esac
            ;;
    esac
}

# Register completion
compdef _docker_utils docker-utils 
