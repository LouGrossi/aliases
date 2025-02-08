alias file-utils='function _file_utils() {
    # Source error handler if available
    local error_handler="${0:A:h}/../src/utils/error_handler.zsh"
    [[ -f "$error_handler" ]] && source "$error_handler"

    # Show help if requested or no arguments
    if [[ "$1" == "--help" || "$1" == "-h" || $# -eq 0 ]]; then
        _file_utils_help
        return 0
    fi

    local cmd="$1"
    shift

    # Function to show help
    function _file_utils_help() {
        cat << EOF
Usage: file-utils <command> [options] [arguments]

File manipulation and management utilities.

Commands:
  exists <file>              Check if a file exists
  find [-d DIR] [-e] <name>  Find files matching name
  source-dir <directory>     Source all files in directory
  autoload                   Auto-load library files

Global Options:
  --help, -h                Show this help message

For command-specific help:
  file-utils <command> --help

Examples:
  file-utils exists config.yml
  file-utils find -d /etc -e "*.conf"
  file-utils source-dir ~/.config/lib
  file-utils autoload
EOF
    }

    case "$cmd" in
        exists)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: file-utils exists <file>

Check if a file exists in the filesystem.

Arguments:
  file        Path to the file to check

Exit Status:
  0           File exists
  1           File does not exist or error occurred

Example:
  file-utils exists ~/.zshrc
EOF
                return 0
            fi

            if [[ -z "$1" ]]; then
                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No file specified"
                _file_utils_help
                return ${ERROR_CODES[INVALID_ARGUMENT]}
            fi
            [[ -f "$1" ]] && return 0 || return 1
            ;;

        find)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: file-utils find [options] <pattern>

Find files matching a pattern.

Options:
  -d, --directory DIR    Search in specific directory (default: /)
  -e, --exact           Use exact pattern matching
  --help, -h            Show this help message

Arguments:
  pattern               Pattern to search for

Examples:
  file-utils find "*.txt"
  file-utils find -d ~/Documents -e "report.pdf"
  file-utils find -d /etc "*.conf"
EOF
                return 0
            fi

            local directory="/" exact_match=0
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -d|--directory)
                        if [[ -z "$2" ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No directory specified for -d/--directory"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        directory="$2"
                        shift 2
                        ;;
                    -e|--exact)
                        exact_match=1
                        shift
                        ;;
                    -*)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                    *)
                        break
                        ;;
                esac
            done

            if [[ -z "$1" ]]; then
                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No search pattern specified"
                return ${ERROR_CODES[INVALID_ARGUMENT]}
            fi

            if [[ ! -d "$directory" ]]; then
                handle_error ${ERROR_CODES[FILE_NOT_FOUND]} "Directory not found: $directory"
                return ${ERROR_CODES[FILE_NOT_FOUND]}
            fi

            if [[ $exact_match -eq 1 ]]; then
                find "$directory" | grep -x "$1"
            else
                find "$directory" | grep "$1"
            fi
            ;;

        source-dir)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: file-utils source-dir [options] <directory>

Source all files in a directory.

Options:
  -p, --pattern PAT     File pattern to match (default: *)
  -v, --verbose        Show verbose output
  --dry-run           Show what would be loaded
  --help, -h          Show this help message

Arguments:
  directory           Directory to source files from

Examples:
  file-utils source-dir ~/.config/lib
  file-utils source-dir -p "*.zsh" ~/scripts
  file-utils source-dir -v --dry-run ~/.local/lib
EOF
                return 0
            fi

            local directory="" pattern="*" verbose=false dry_run=false
            local load_count=0 error_count=0

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -p|--pattern)
                        if [[ -z "$2" ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No pattern specified for -p/--pattern"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        pattern="$2"
                        shift 2
                        ;;
                    -v|--verbose)
                        verbose=true
                        shift
                        ;;
                    --dry-run)
                        dry_run=true
                        shift
                        ;;
                    -*)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                    *)
                        if [[ -z "$directory" ]]; then
                            directory="$1"
                        else
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unexpected argument: $1"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        shift
                        ;;
                esac
            done

            if [[ -z "$directory" ]]; then
                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No directory specified"
                return ${ERROR_CODES[INVALID_ARGUMENT]}
            fi

            if [[ ! -d "$directory" ]]; then
                handle_error ${ERROR_CODES[FILE_NOT_FOUND]} "Directory not found: $directory"
                return ${ERROR_CODES[FILE_NOT_FOUND]}
            fi

            for file in $(find "$directory" -type f -name "$pattern" ! -path "*/.git/*"); do
                if $verbose; then
                    echo "Loading: $file"
                fi
                
                if ! $dry_run; then
                    if source "$file" 2>/dev/null; then
                        ((load_count++))
                    else
                        handle_error ${ERROR_CODES[PERMISSION_DENIED]} "Failed to load: $file"
                        ((error_count++))
                    fi
                else
                    echo "[DRY RUN] Would load: $file"
                    ((load_count++))
                fi
            done

            if $verbose || $dry_run; then
                echo "Files processed: $load_count"
                [[ $error_count -gt 0 ]] && echo "Files failed: $error_count"
            fi
            ;;

        autoload)
            # Show help if requested
            if [[ "$1" == "--help" || "$1" == "-h" ]]; then
                cat << EOF
Usage: file-utils autoload [options]

Auto-load library files from the default library directory.

Options:
  -d, --directory DIR   Specify library directory (default: ~/.config/lib)
  -p, --pattern PAT    File pattern to match (default: *.zsh)
  -v, --verbose       Show verbose output
  --dry-run          Show what would be loaded
  --help, -h         Show this help message

Examples:
  file-utils autoload
  file-utils autoload -p "*.sh" -v
  file-utils autoload -d ~/scripts --dry-run
EOF
                return 0
            fi

            local lib_dir="${XDG_CONFIG_HOME:-$HOME/.config}/lib"
            local pattern="*.zsh"
            local verbose=false
            local dry_run=false

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -d|--directory)
                        if [[ -z "$2" ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No directory specified for -d/--directory"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        lib_dir="$2"
                        shift 2
                        ;;
                    -p|--pattern)
                        if [[ -z "$2" ]]; then
                            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No pattern specified for -p/--pattern"
                            return ${ERROR_CODES[INVALID_ARGUMENT]}
                        fi
                        pattern="$2"
                        shift 2
                        ;;
                    -v|--verbose)
                        verbose=true
                        shift
                        ;;
                    --dry-run)
                        dry_run=true
                        shift
                        ;;
                    -*)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                    *)
                        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unexpected argument: $1"
                        return ${ERROR_CODES[INVALID_ARGUMENT]}
                        ;;
                esac
            done

            _file_utils source-dir -p "$pattern" ${verbose:+-v} ${dry_run:+--dry-run} "$lib_dir"
            ;;

        *)
            handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown command: $cmd"
            _file_utils_help
            return ${ERROR_CODES[INVALID_ARGUMENT]}
            ;;
    esac
}; _file_utils'

# Maintain backward compatibility with existing aliases
alias file-exists='file-utils exists'
alias file-find='file-utils find'
alias file-source-dir='file-utils source-dir'
alias autoload-libs='file-utils autoload' 
alias pberror='2>&1 | tee /dev/tty | pbcopy'
