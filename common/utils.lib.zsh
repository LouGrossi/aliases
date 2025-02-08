#!/bin/zsh
# utils.lib.zsh
# Author: Lou Grossi
# Company: ncdLabs
# Description: Common utility functions for shell scripts

#
# LIBRARY USAGE
# ------------
# This library provides common utility functions for shell scripts, including:
# - Logging with colors and levels
# - Status bar with progress and spinner
# - Color formatting
# - Duration formatting
# - Selection menus
# - Error handling
#
# To use this library in your scripts:
#
# 1. Source the library:
#    source "./common/utils.lib.zsh"
#
# 2. Initialize status bar if needed:
#    init_status_bar
#    trap cleanup EXIT INT TERM
#
# 3. Use the functions as needed:
#    log info "Starting process..."
#    start_spinner "Processing"
#    update_status_bar "Item 1/10" 1 10
#    stop_spinner
#    log success "Process complete"
#

# Color Functions
# --------------

# Get ANSI color code
function get_color() {
    case "$1" in
        black)   echo "\033[30m" ;;
        red)     echo "\033[31m" ;;
        green)   echo "\033[32m" ;;
        yellow)  echo "\033[33m" ;;
        blue)    echo "\033[34m" ;;
        magenta) echo "\033[35m" ;;
        cyan)    echo "\033[36m" ;;
        white)   echo "\033[37m" ;;
        reset)   echo "\033[0m" ;;
        *)       echo "\033[0m" ;;
    esac
}

# Format text with color
function format_color() {
    local color="$1"
    shift
    local text="$*"
    local color_code=$(get_color "$color")
    local reset_code=$(get_color reset)
    echo "${color_code}${text}${reset_code}"
}

# Status Bar Functions
# ------------------

# Initialize status bar
function init_status_bar() {
    # Save cursor position
    tput sc
    
    # Hide cursor
    tput civis
    
    # Initialize status bar variables
    STATUS_BAR_MESSAGE=""
    STATUS_BAR_PROGRESS=0
    STATUS_BAR_TOTAL=0
    STATUS_BAR_SPINNER_CHARS=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    STATUS_BAR_SPINNER_IDX=0
    STATUS_BAR_SPINNER_ACTIVE=false
    STATUS_BAR_LAST_UPDATE=0
    
    # Create status bar area
    printf "\n\n"  # Reserve 2 lines for status bar
}

# Clean up status bar
function cleanup() {
    # Show cursor
    tput cnorm
    
    # Clear status bar area
    tput rc  # Restore cursor position
    tput ed  # Clear to end of screen
    
    # Reset status bar variables
    STATUS_BAR_MESSAGE=""
    STATUS_BAR_PROGRESS=0
    STATUS_BAR_TOTAL=0
    STATUS_BAR_SPINNER_ACTIVE=false
}

# Update status bar with progress
function update_status_bar() {
    local message="$1"
    local current="$2"
    local total="$3"
    
    # Update status bar variables
    STATUS_BAR_MESSAGE="$message"
    STATUS_BAR_PROGRESS=$current
    STATUS_BAR_TOTAL=$total
    
    # Only update if enough time has passed (throttle updates)
    local now=$SECONDS
    if (( now - STATUS_BAR_LAST_UPDATE >= 0.1 )); then
        _draw_status_bar
        STATUS_BAR_LAST_UPDATE=$now
    fi
}

# Internal function to draw status bar
function _draw_status_bar() {
    # Save cursor position
    tput sc
    
    # Move to status bar area (2 lines up from current position)
    tput cuu 2
    
    # Clear status bar area
    tput el  # Clear first line
    tput cud 1  # Move down
    tput el  # Clear second line
    tput cuu 1  # Move back up
    
    # Draw spinner if active
    local spinner=""
    if [[ "$STATUS_BAR_SPINNER_ACTIVE" == true ]]; then
        spinner="${STATUS_BAR_SPINNER_CHARS[$STATUS_BAR_SPINNER_IDX]} "
        STATUS_BAR_SPINNER_IDX=$(( (STATUS_BAR_SPINNER_IDX + 1) % ${#STATUS_BAR_SPINNER_CHARS[@]} ))
    fi
    
    # Draw progress bar if total > 0
    if (( STATUS_BAR_TOTAL > 0 )); then
        local width=50
        local filled=$(( width * STATUS_BAR_PROGRESS / STATUS_BAR_TOTAL ))
        local empty=$(( width - filled ))
        local percentage=$(( 100 * STATUS_BAR_PROGRESS / STATUS_BAR_TOTAL ))
        
        printf "${spinner}${STATUS_BAR_MESSAGE}\n"
        printf "[%s%s] %3d%% (%d/%d)" \
            "$(printf '='%.0s {1..$filled})" \
            "$(printf ' '%.0s {1..$empty})" \
            "$percentage" \
            "$STATUS_BAR_PROGRESS" \
            "$STATUS_BAR_TOTAL"
    else
        printf "${spinner}${STATUS_BAR_MESSAGE}"
    fi
    
    # Restore cursor position
    tput rc
}

# Start spinner with message
function start_spinner() {
    local message="$1"
    STATUS_BAR_MESSAGE="$message"
    STATUS_BAR_SPINNER_ACTIVE=true
    STATUS_BAR_SPINNER_IDX=0
    _draw_status_bar
}

# Stop spinner
function stop_spinner() {
    STATUS_BAR_SPINNER_ACTIVE=false
    _draw_status_bar
}

# Logging Functions
# ---------------

# Log message with level
function log() {
    local level="$1"
    shift
    local message="$*"
    local color=""
    local prefix=""
    
    case "$level" in
        info)
            color=$(get_color blue)
            prefix="INFO"
            ;;
        success)
            color=$(get_color green)
            prefix="SUCCESS"
            ;;
        warning)
            color=$(get_color yellow)
            prefix="WARNING"
            ;;
        error)
            color=$(get_color red)
            prefix="ERROR"
            ;;
        debug)
            [[ "$DEBUG" != "true" ]] && return
            color=$(get_color magenta)
            prefix="DEBUG"
            ;;
        *)
            color=$(get_color reset)
            prefix="LOG"
            ;;
    esac
    
    # Save cursor position
    tput sc
    
    # Print message
    printf "${color}[%s] %s${reset}\n" "$prefix" "$message"
    
    # Redraw status bar
    _draw_status_bar
    
    # If this is an error, exit
    if [[ "$level" == "error" ]]; then
        cleanup
        exit 1
    fi
}

# Error logging shortcut
function error() {
    log error "$@"
}

# Debug logging shortcut
function debug() {
    log debug "$@"
}

# Utility Functions
# ---------------

# Format duration in seconds to human readable
function format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    seconds=$((seconds % 60))
    
    if ((minutes > 0)); then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Show selection menu
function show_selection_menu() {
    local prompt="$1"
    shift
    local -a options=("$@")
    local selected=1
    local total=${#options[@]}
    
    log info "$prompt"
    
    # Display initial menu
    for ((i = 1; i <= total; i++)); do
        if ((i == selected)); then
            log info "→ ${options[$i]}"
        else
            log info "  ${options[$i]}"
        fi
    done
    
    # Handle user input
    while true; do
        read -sk1 key
        case "$key" in
            $'\x1B')  # ESC sequence
                read -sk1 key
                if [[ "$key" == "[" ]]; then
                    read -sk1 key
                    case "$key" in
                        "A")  # Up arrow
                            if ((selected > 1)); then
                                ((selected--))
                            fi
                            ;;
                        "B")  # Down arrow
                            if ((selected < total)); then
                                ((selected++))
                            fi
                            ;;
                    esac
                fi
                ;;
            "")  # Enter key
                echo
                return $selected
                ;;
        esac
        
        # Clear previous menu
        for ((i = 1; i <= total; i++)); do
            tput cuu1
            tput el
        done
        
        # Redraw menu
        for ((i = 1; i <= total; i++)); do
            if ((i == selected)); then
                log info "→ ${options[$i]}"
            else
                log info "  ${options[$i]}"
            fi
        done
    done
}

# Show confirmation prompt
function show_confirmation() {
    local message="$1"
    local default="${2:-n}"  # Default to 'no' if not specified
    
    log info "$message [y/N] "
    read -q response || true
    echo
    
    [[ "$response" =~ ^[Yy]$ ]]
    return $?
}

# Error Handling Functions
# ----------------------

# Handle command errors
function handle_error() {
    local exit_code=$1
    local error_message=$2
    local command=$3
    
    case $exit_code in
        0)  return 0 ;;
        1)  error "General error: $error_message" ;;
        2)  error "Syntax error: $error_message" ;;
        3)  error "Network error: $error_message" ;;
        130) log warning "Operation cancelled by user" ;;
        *)  error "Unknown error ($exit_code): $error_message" ;;
    esac
}

# Progress Bar Functions
# --------------------

# Show progress bar
function show_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local blue=$(get_color blue)
    local reset=$(get_color reset)
    
    printf -v bar "%${filled}s" ""
    printf -v space "%${empty}s" ""
    bar=${bar// /#}
    space=${space// /-}
    
    printf "${blue}[%s%s] %3d%% (%d/%d)${reset}" "$bar" "$space" "$percentage" "$current" "$total"
}

# Test progress display
function test_progress_display() {
    local total=10
    local timeout_seconds=1
    local status_line="\033[K"
    
    # Color codes
    local blue=$(get_color blue)
    local green=$(get_color green)
    local yellow=$(get_color yellow)
    local reset=$(get_color reset)
    
    # Hide cursor
    tput civis
    
    # Set up trap for cleanup
    trap 'echo "\nTest cancelled"; tput cnorm; return 1' INT TERM
    
    print -P "\n%F{blue}Testing Progress Display...%f"
    local start_time=$SECONDS
    
    for ((i=1; i<=total; i++)); do
        printf "$status_line"  # Clear line
        printf "\r${blue}Processing item: ${yellow}Test Item $i${reset}\n"
        show_progress_bar $i $total
        printf "\n${blue}Time: ${yellow}%s elapsed${reset}${status_line}" \
            "$(format_duration $((SECONDS - start_time)))"
        sleep $timeout_seconds
    done
    
    # Restore cursor
    tput cnorm
    trap - INT TERM
    
    printf "\n${green}✓ Test completed in %s${reset}\n" "$(format_duration $((SECONDS - start_time)))"
} 