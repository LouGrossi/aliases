#!/bin/zsh
# output.lib.zsh
# Author: Lou Grossi
# Company: ncdLabs
# Description: Common output formatting library for GCloud utilities

#
# LIBRARY USAGE
# ------------
# This library provides consistent output formatting for GCloud commands, supporting
# multiple output formats with proper validation and formatting.
#
# To use this library in your scripts:
#
# 1. Source the library:
#    source "./common/output.lib.zsh"
#
# 2. Available functions:
#
#    a) validate_output_format <format>
#       Validates if the provided format is supported
#       Example:
#         if ! validate_output_format "json"; then
#           return 1
#         fi
#
#    b) format_gcloud_output <cmd> <format> [columns]
#       Formats and executes a gcloud command with specified output format
#       Parameters:
#         - cmd: The gcloud command to execute (without format flags)
#         - format: Output format (json|yaml|text|table)
#         - columns: Optional comma-separated list of columns for table/text format
#       Examples:
#         format_gcloud_output "gcloud projects list" "table" "projectId,name"
#         format_gcloud_output "gcloud iam roles list" "json"
#
#    c) add_output_format_help
#       Adds standardized help text for output format option
#       Example:
#         echo "Usage: my-command [options]"
#         add_output_format_help
#
# 3. Supported output formats:
#    - table: ASCII-bordered table format (default)
#    - json:  JSON format
#    - yaml:  YAML format
#    - text:  Plain text format
#    - csv:   Comma-separated values format
#
# 4. Example usage in a script:
#    ```
#    #!/bin/zsh
#    source "./common/output.lib.zsh"
#    
#    function my_command() {
#      local output=""
#      
#      # Parse arguments
#      while [[ $# -gt 0 ]]; do
#        case "$1" in
#          --output)
#            output="$2"
#            shift 2
#            ;;
#        esac
#      done
#      
#      # Validate output format
#      if ! validate_output_format "$output"; then
#        return 1
#      fi
#      
#      # Execute command with formatting
#      local cmd="gcloud projects list"
#      format_gcloud_output "$cmd" "$output" "projectId,name,projectNumber"
#    }
#    ```
#
# 5. Table Format Features:
#    - ASCII borders around the table
#    - Title row with "Results"
#    - Column headers
#    - Automatic column width adjustment
#
# 6. Notes:
#    - Default format is 'table' if none specified
#    - Table format requires explicit column specifications
#    - Commands are executed using eval, ensure proper quoting
#    - The library handles --format flag addition automatically
#

# Valid output formats
VALID_OUTPUT_FORMATS=("json" "yaml" "text" "table" "csv")

# Function to validate output format
function validate_output_format() {
    local format=$1
    if [[ -z "$format" ]]; then
        return 0  # Default format is fine
    fi
    
    if [[ ! " ${VALID_OUTPUT_FORMATS[@]} " =~ " ${format} " ]]; then
        echo "Error: Invalid output format: $format"
        echo "Valid formats are: ${VALID_OUTPUT_FORMATS[*]}"
        return 1
    fi
    return 0
}

# Function to format gcloud command output
function format_gcloud_output() {
    local cmd=$1
    local format=$2
    local columns="${3:-bindings.members,bindings.role}"  # Default columns if not specified
    
    # If no format specified, use default (table with borders)
    if [[ -z "$format" ]]; then
        eval "$cmd --format='table[box,title=Results]($columns)'"
        return $?
    fi
    
    case "$format" in
        "json")
            eval "$cmd --format=json"
            ;;
        "yaml")
            eval "$cmd --format=yaml"
            ;;
        "text")
            eval "$cmd --format='value($columns)'"
            ;;
        "csv")
            # First row will be headers, followed by data in CSV format
            eval "$cmd --format='csv($columns)'"
            ;;
        "table")
            # Add box borders and title to table
            eval "$cmd --format='table[box,title=Results]($columns)'"
            ;;
        *)
            echo "Error: Unsupported format: $format"
            return 1
            ;;
    esac
    return $?
}

# Function to add output format parameter help
function add_output_format_help() {
    echo "  --output FORMAT         : Output format (optional, default: table)"
    echo "                           Valid formats: json, yaml, text, table, csv"
    echo "                           Table format includes ASCII borders"
    echo "                           CSV format includes headers"
} 