#!/bin/zsh
# gcloud-util.zsh
# Author: Lou Grossi
# Company: ncdLabs
# Description: GCloud utility functions for managing GCP resources
#
# FEATURES
# ========
#
# IAM Management
# -------------
# 1. Role Management:
#    - list-roles: List custom IAM roles in projects or organization
#    - describe-role: Get detailed role information including permissions
#    - search-roles: Search for roles across all projects and organization
#      * Search by terms in role names, descriptions, and permissions
#      * Search by principal (find roles assigned to user/service account)
#      * Multiple search terms with AND logic
#      * Name-only search option
#    - merge-roles: Combine multiple roles into a new custom role
#      * Merge roles from different projects/organization
#      * Automatic permission deduplication
#      * Verification screen before creation
#
# 2. User Management:
#    - list-users: List all users and service accounts
#    - describe-user: Get detailed user role assignments
#
# Backup & Restore
# ---------------
# 1. Backup Features:
#    - Backup IAM configurations
#    - Support for project and organization scope
#    - Hierarchical backup structure
#    - Timestamp-based versioning
#
# 2. Restore Features:
#    - Restore from backup files
#    - Support for single file or directory restore
#    - Automatic organization detection
#
# Project Management
# -----------------
# 1. Project Features:
#    - list: List all GCP projects
#    - Filter system projects
#    - Custom output formats
#
# General Features
# ---------------
# 1. Scope Support:
#    - Project-level operations
#    - Organization-level operations
#    - All-scope operations (org + all projects)
#
# 2. Output Formats:
#    - Table (default with ASCII borders)
#    - JSON
#    - YAML
#    - Text
#    - CSV
#
# 3. Safety Features:
#    - Confirmation prompts for destructive operations
#    - Detailed verification screens
#    - Error handling and validation
#
# 4. Help System:
#    - Command-specific help
#    - Subcommand help
#    - Usage examples
#    - Parameter descriptions
#

# Source the output library
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/common/output.lib.zsh"

# Function to print debug messages
function debug_log() {
    if [[ -n "$DEBUG_MODE" ]]; then
        echo "DEBUG: $1" >&2
    fi
}

# Function to show main help
function show_main_help() {
    echo "GCloud Utility Tool - IAM Management"
    echo "\nAvailable commands:"
    echo "  iam             - IAM role and permission management"
    echo "  projects        - GCP projects management"
    echo "  help           - Show this help message"
    echo "\nUsage:"
    echo "  gcloud-util <command> [subcommand] [options]"
    echo "\nGet detailed help:"
    echo "  gcloud-util help           - Show this help"
    echo "  gcloud-util <command> help - Show help for a specific command"
}

# Function to show IAM help
function show_iam_help() {
    echo "GCloud IAM Management Commands"
    echo "\nDescription:"
    echo "  Manage IAM roles and permissions in Google Cloud Platform projects or organizations"
    echo "\nAvailable subcommands:"
    echo "  create-role    - Create a custom role for a specific service"
    echo "  describe-role  - Get detailed information about a specific IAM role"
    echo "  describe-user  - Get detailed information about a specific IAM user"
    echo "  list-roles     - List all custom IAM roles in a project or organization"
    echo "  list-users     - List all IAM users in a project or organization"
    echo "  merge-roles    - Merge multiple IAM roles into a new role"
    echo "  search-roles   - Search for roles across all projects and organization"
    echo "  backup         - Backup IAM configurations"
    echo "  restore        - Restore IAM configurations from backup"
    echo "  help          - Show this help message"
    echo "\nUsage:"
    echo "  gcloud-util iam <subcommand> [options]"
    echo "\nGet detailed help:"
    echo "  gcloud-util iam help                  - Show this help"
    echo "  gcloud-util iam <subcommand> --help   - Show help for a specific subcommand"
    echo "\nExamples:"
    echo "  gcloud-util iam create-role --role my-terraform-role --service terraform --org-id 123456789"
    echo "  gcloud-util iam describe-role --project-id my-project --role roles/editor"
    echo "  gcloud-util iam describe-role --org-id 123456789 --role roles/editor"
    echo "  gcloud-util iam list-roles --project-id my-project"
    echo "  gcloud-util iam describe-user --org-id 123456789 --user user@example.com"
    echo "  gcloud-util iam list-users --project-id my-project"
    echo "  gcloud-util iam backup --project-id my-project --user user@example.com"
    echo "  gcloud-util iam restore --dir /path/to/backup"
}

# Function to show backup help
function show_backup_help() {
    echo "GCloud Backup Commands"
    echo "\nDescription:"
    echo "  Backup GCP resources for disaster recovery or migration"
    echo "\nAvailable subcommands:"
    echo "  iam           - Backup IAM configurations"
    echo "  help          - Show this help message"
    echo "\nUsage:"
    echo "  gcloud-util backup <subcommand> [options]"
    echo "\nGet detailed help:"
    echo "  gcloud-util backup help                - Show this help"
    echo "  gcloud-util backup <subcommand> --help - Show help for a specific subcommand"
}

# Function to show backup IAM help
function show_backup_iam_help() {
    echo "GCloud Backup IAM Command"
    echo "\nDescription:"
    echo "  Creates a backup of IAM configurations"
    echo "\nUsage:"
    echo "  gcloud-util backup iam (--project-id PROJECT_ID | --org-id ORG_ID | --all ORG_ID) --user USER_EMAIL [--output-dir DIR]"
    echo "\nRequired Parameters:"
    echo "  One of the following must be specified:"
    echo "    --project-id PROJECT_ID   : The Google Cloud Project ID"
    echo "    --org-id ORG_ID          : The Google Cloud Organization ID"
    echo "    --all ORG_ID             : Execute on organization and all its projects"
    echo "  And:"
    echo "  --user USER_EMAIL     : The email address of the user to backup"
    echo "\nOptional Parameters:"
    echo "  --output-dir DIR      : Directory to store backup files (default: ./backup_YYYYMMDD_HHMMSS)"
    echo "\nExamples:"
    echo "  gcloud-util backup iam --project-id my-project --user user@example.com"
    echo "  gcloud-util backup iam --org-id 123456789 --user user@example.com"
    echo "  gcloud-util backup iam --all 123456789 --user user@example.com --output-dir /path/to/backup"
}

# Function to show restore help
function show_restore_help() {
    echo "GCloud Restore Command"
    echo "\nDescription:"
    echo "  Restore GCP resources from backup files"
    echo "\nUsage:"
    echo "  gcloud-util restore (--dir BACKUP_DIR | --file BACKUP_FILE)"
    echo "\nRequired Parameters (one of):"
    echo "  --dir BACKUP_DIR    : Directory containing backup files"
    echo "  --file BACKUP_FILE  : Single backup file to restore from"
    echo "\nExamples:"
    echo "  gcloud-util restore --dir ./backup/iam/user/user_at_example.com_20240105"
    echo "  gcloud-util restore --file ./backup/project_my-project_roles.json"
}

# Function to show create-role help
function show_create_role_help() {
    echo "GCloud IAM Create Role Command"
    echo "\nDescription:"
    echo "  Creates a custom IAM role for a specific service with predefined permissions"
    echo "\nUsage:"
    echo "  gcloud-util iam create-role --role ROLE_NAME --service SERVICE (--org-id ORG_ID | --project-id PROJECT_ID) [--scan-services]"
    echo "\nRequired Parameters:"
    echo "  --role ROLE_NAME      : Name for the custom role"
    echo "  --service SERVICE     : Service to create role for (e.g., terraform)"
    echo "  One of the following:"
    echo "    --org-id ORG_ID     : Organization ID where the role will be created (recommended)"
    echo "    --project-id PROJ_ID: Project ID where the role will be created"
    echo "\nOptional Parameters:"
    echo "  --scan-services      : When used with --service terraform, scans all enabled services"
    echo "                         in the organization/project and adds required permissions"
    echo "\nSupported Services:"
    echo "  terraform            : Creates a role with all necessary permissions for Terraform operations"
    echo "                         Use --scan-services to automatically detect required permissions"
    echo "\nExamples:"
    echo "  gcloud-util iam create-role --role terraform-admin --service terraform --org-id 123456789"
    echo "  gcloud-util iam create-role --role terraform-admin --service terraform --project-id my-project"
    echo "  gcloud-util iam create-role --role terraform-admin --service terraform --org-id 123456789 --scan-services"
}

# Helper function to get the default organization ID
function get_default_org() {
    # Get the first organization ID from the list
    local org_id=$(gcloud organizations list --format="value(ID)" --limit=1)
    if [[ -z "$org_id" ]]; then
        echo "Error: No organization found. Please specify an organization ID with --all"
        return 1
    fi
    echo "$org_id"
}

# Helper function to get all projects in an organization
function get_org_projects() {
    local org_id=$1
    local all_flag=$2
    # Get all projects in the organization, extract just the project IDs
    if [[ -n "$all_flag" ]]; then
        gcloud projects list --format="value(projectId)"
    else
        gcloud projects list --filter="NOT projectId:(sys-*)" --format="value(projectId)"
    fi
}

# Helper function to execute command across org and projects
function execute_all_scope() {
    local org_id=$1
    local cmd_type=$2
    local output=$3
    local extra_args=$4
    local all_flag=$5
    local search_filter=${6:-"bindings.members~'user:|serviceAccount:'"}

    echo "Executing on organization $org_id..."
    echo "----------------------------------------"
    case "$cmd_type" in
        "list-users")
            format_gcloud_output "gcloud organizations get-iam-policy \"$org_id\" --flatten=\"bindings[].members\" --filter=\"$search_filter\"" "$output" "bindings.members,bindings.role"
            ;;
        "list-roles")
            format_gcloud_output "gcloud iam roles list --organization=\"$org_id\" --filter=\"$extra_args\"" "$output" "name,title,description"
            ;;
        "describe-role")
            format_gcloud_output "gcloud iam roles describe $extra_args --organization=\"$org_id\"" "$output"
            ;;
        "describe-user")
            format_gcloud_output "gcloud organizations get-iam-policy \"$org_id\" --flatten=\"bindings[].members\" --filter=\"bindings.members:$extra_args\"" "$output" "bindings.role"
            ;;
    esac

    # Get all projects and execute on each
    local projects=($(get_org_projects "$org_id" "$all_flag"))
    for project in $projects; do
        echo "\nExecuting on project $project..."
        echo "----------------------------------------"
        case "$cmd_type" in
            "list-users")
                format_gcloud_output "gcloud projects get-iam-policy \"$project\" --flatten=\"bindings[].members\" --filter=\"$search_filter\"" "$output" "bindings.members,bindings.role"
                ;;
            "list-roles")
                format_gcloud_output "gcloud iam roles list --project=\"$project\" --filter=\"$extra_args\"" "$output" "name,title,description"
                ;;
            "describe-role")
                format_gcloud_output "gcloud iam roles describe $extra_args --project=\"$project\"" "$output"
                ;;
            "describe-user")
                format_gcloud_output "gcloud projects get-iam-policy \"$project\" --flatten=\"bindings[].members\" --filter=\"bindings.members:$extra_args\"" "$output" "bindings.role"
                ;;
        esac
    done
}

# Helper function to create backup directory
function create_backup_dir() {
    local command=$1
    local subcommand=$2
    local user=$3
    local output_dir=$4
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    # Create the hierarchical structure
    local backup_base="${output_dir:-./backup}"
    local backup_dir="$backup_base/iam/user"
    
    # For IAM user backups, add the user directory
    if [[ "$command" == "iam" && "$subcommand" == "user" ]]; then
        # Replace @ with _at_ in email for directory name
        local safe_user="${user//@/_at_}"
        backup_dir="$backup_dir/${safe_user}_${timestamp}"
    fi
    
    mkdir -p "$backup_dir"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create backup directory: $backup_dir"
        return 1
    fi
    echo "$backup_dir"
}

# Helper function to restore from a single file
function restore_from_file() {
    local file=$1
    local user=$2
    local org_id=$3
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file"
        return 1
    fi

    echo "Restoring from file: $file"
    
    # Determine if this is an org or project file
    if [[ "$file" == *"org_roles.json" ]]; then
        # Restore organization roles
        echo "Restoring organization roles..."
        local roles=$(cat "$file" | jq -r '.[] | select(.bindings.members) | .bindings.role')
        for role in $roles; do
            echo "Adding role: $role"
            gcloud organizations add-iam-policy-binding "$org_id" \
                --member="user:$user" \
                --role="$role"
        done
    elif [[ "$file" == *"project_"*"_roles.json" ]]; then
        # Extract project ID from filename
        local project=$(echo "$file" | sed 's/.*project_\(.*\)_roles.json/\1/')
        echo "Restoring roles for project: $project"
        local roles=$(cat "$file" | jq -r '.[] | select(.bindings.members) | .bindings.role')
        for role in $roles; do
            echo "Adding role: $role"
            gcloud projects add-iam-policy-binding "$project" \
                --member="user:$user" \
                --role="$role"
        done
    else
        echo "Error: Unrecognized backup file format: $file"
        return 1
    fi
}

# Function to validate and process role format
function validate_role_format() {
    local role=$1
    local org_id=$2

    debug_log "Validating role: $role"

    # Check if it's a predefined role
    if [[ $role == roles/* ]]; then
        debug_log "Checking predefined role with command: gcloud iam roles describe \"$role\" --format=\"get(includedPermissions[])\""
        # For predefined roles, check if we can get permissions
        if ! gcloud iam roles describe "$role" --format="get(includedPermissions[])" > /dev/null 2>&1; then
            echo "Error: Invalid predefined role: $role"
            return 1
        fi
        debug_log "Predefined role validation successful"
                        return 0
                    fi

    # Check if it's an organization custom role
    if [[ $role == organizations/* ]]; then
        local role_org_id=$(echo $role | cut -d'/' -f2)
        local role_name=$(echo $role | cut -d'/' -f4)
        
        debug_log "Checking org role: org_id=$role_org_id, role_name=$role_name"
        
        if [[ -z "$role_org_id" || -z "$role_name" ]]; then
            echo "Error: Invalid organization role format. Expected: organizations/ORG_ID/roles/ROLE_ID"
                        return 1
                    fi

        # Validate the role exists
        debug_log "Running command: gcloud iam roles describe \"$role_name\" --organization=\"$role_org_id\""
        if ! gcloud iam roles describe "$role_name" --organization="$role_org_id" > /dev/null 2>&1; then
            echo "Error: Organization role not found: $role"
            return 1
        fi
        debug_log "Organization role validation successful"
        return 0
    fi

    echo "Error: Invalid role format. Must be either roles/* or organizations/ORG_ID/roles/ROLE_ID"
                    return 1
}

# Function to get role permissions
function get_role_permissions() {
    local role=$1
    local org_id=$2
    local temp_file=$(mktemp)
    
    debug_log "Getting permissions for role: $role"
    
    if [[ $role == roles/* ]]; then
        debug_log "Running command: gcloud iam roles describe \"$role\" --format=\"get(includedPermissions[])\""
        # For predefined roles, just describe it directly
        gcloud iam roles describe "$role" --format="get(includedPermissions[])" > "$temp_file" 2>/dev/null
        debug_log "Command output saved to: $temp_file"
    elif [[ $role == organizations/* ]]; then
        local role_org_id=$(echo $role | cut -d'/' -f2)
        local role_name=$(echo $role | cut -d'/' -f4)
        debug_log "Running command: gcloud iam roles describe \"$role_name\" --organization=\"$role_org_id\" --format=\"get(includedPermissions[])\""
        gcloud iam roles describe "$role_name" --organization="$role_org_id" --format="get(includedPermissions[])" > "$temp_file" 2>/dev/null
        debug_log "Command output saved to: $temp_file"
    fi
    
    # Read permissions line by line and split on semicolons
    local permissions=()
    while IFS=';' read -r -A line_perms; do
        for perm in "${line_perms[@]}"; do
            # Trim whitespace
            perm="${perm## }"
            perm="${perm%% }"
            if [[ -n "$perm" ]]; then
                permissions+=("$perm")
            fi
        done
    done < "$temp_file"
    
    debug_log "Found ${#permissions[@]} permissions"
    rm "$temp_file"
    
    # Return the permissions array
    echo "${permissions[@]}"
}

# Function to merge IAM roles
function merge_roles() {
    local dest_role=""
    local roles=()
    local org_id=""
    local MAX_PERMISSIONS=3000
    
    debug_log "Starting merge_roles with args: $@"

                    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
                            --role)
                debug_log "Adding role: $2"
                roles+=("$2")
                                shift 2
                                ;;
            --destination-role)
                debug_log "Setting destination role: $2"
                dest_role="$2"
                                shift 2
                                ;;
                            *)
                echo "Error: Unknown option $1"
                                return 1
                                ;;
                        esac
                    done

    # Validate destination role format
    if [[ ! $dest_role =~ ^organizations/[0-9]+/roles/[a-zA-Z0-9_]+$ ]]; then
        echo "Error: Invalid destination role format. Must be organizations/ORG_ID/roles/ROLE_ID"
                        return 1
                    fi

    # Extract org_id and base role name from destination role
    org_id=$(echo $dest_role | cut -d'/' -f2)
    local base_role_name=$(echo $dest_role | cut -d'/' -f4)

    echo "=== Role Merge Verification ==="
    echo "--------------------------------\n"
    echo "Source Roles:"
    echo "-------------\n"

    # Validate and process each role
    local all_permissions=()
    for role in "${roles[@]}"; do
        echo "Processing role: $role"
        echo "Location: $(dirname $role)"
        echo "Role ID: $(basename $role)"
        
        if ! validate_role_format "$role" "$org_id"; then
            continue
        fi

        echo "Permissions:"
        local role_permissions=($(get_role_permissions "$role" "$org_id"))
        if [[ ${#role_permissions[@]} -eq 0 ]]; then
            echo "  Warning: No permissions found for role $role"
            continue
        fi
        
        # Print permissions one per line for better readability
        printf "  - %s\n" "${role_permissions[@]}"
        all_permissions+=("${role_permissions[@]}")
        echo "Total permissions: ${#role_permissions[@]}\n"
    done

    # Remove duplicates while preserving order
    local -A seen=()
    local unique_permissions=()
    for perm in "${all_permissions[@]}"; do
        if [[ -z "${seen[$perm]}" ]]; then
            seen[$perm]=1
            unique_permissions+=("$perm")
        fi
    done
    
    echo "\nMerged Role Summary:"
    echo "-------------------"
    echo "Total Unique Permissions: ${#unique_permissions[@]}"
    
    # Calculate number of roles needed
    local num_roles=$(( (${#unique_permissions[@]} + $MAX_PERMISSIONS - 1) / $MAX_PERMISSIONS ))
    echo "Number of roles needed: $num_roles (maximum $MAX_PERMISSIONS permissions per role)"
    
    # Create roles
    local role_count=0
    local success=true
    while [[ $role_count -lt $num_roles ]]; do
        local start_idx=$(($role_count * $MAX_PERMISSIONS))
        local end_idx=$((($role_count + 1) * $MAX_PERMISSIONS))
        if [[ $end_idx -gt ${#unique_permissions[@]} ]]; then
            end_idx=${#unique_permissions[@]}
        fi
        
        # Calculate the slice of permissions for this role
        local current_permissions=("${unique_permissions[@]:$start_idx:$(($end_idx-$start_idx))}")
        
        # Create role name with sequence number
        local sequence_num=$(($role_count + 1))
        local current_role_name="${base_role_name}-${sequence_num}"
        
        echo "\nCreating role $sequence_num of $num_roles: $current_role_name"
        echo "Number of permissions: ${#current_permissions[@]}"
        echo "Permissions:"
        printf "  - %s\n" "${current_permissions[@]}"
        
        if ! gcloud iam roles create "$current_role_name" \
            --organization="$org_id" \
            --permissions="${(j:,:)current_permissions}" \
            --title="Merged Role $current_role_name" \
            --description="Part $sequence_num of $num_roles - Merged role created from multiple source roles" \
            --stage="GA"; then
            echo "Error: Failed to create role $current_role_name"
            success=false
            break
        fi
        
        ((role_count++))
    done
    
    if [[ "$success" == "true" ]]; then
        echo "\nSuccess: Created $num_roles roles successfully"
        echo "Role names:"
        for ((i=1; i<=num_roles; i++)); do
            echo "  - organizations/$org_id/roles/${base_role_name}-$i"
        done
        return 0
    else
        echo "\nError: Failed to create all roles"
                                    return 1
                                fi
}

# Utility functions
function filter_permissions() {
    local -a permissions=("$@")
    local -a filtered=()
    local -A seen=()
    
    log info "Filtering permissions..."
    local total=${#permissions[@]}
    local processed=0
    
    for perm in "${permissions[@]}"; do
        ((processed++))
        update_status_bar "Processing permission: $perm" "$processed" "$total"
        
        # Skip empty permissions
        [[ -z "$perm" ]] && continue
        
        # Skip duplicates
        if [[ -n "${seen[$perm]}" ]]; then
            continue
        fi
        
        seen[$perm]=1
        filtered+=("$perm")
        sleep 0.1
    done
    
    log success "✓ Filtered ${#filtered[@]} unique permissions from $total total"
    echo "${filtered[@]}"
}

function display_permissions_table() {
    local -a permissions=("$@")
    local total=${#permissions[@]}
    local processed=0
    
    # Calculate maximum permission length for formatting
    local max_length=0
    for perm in "${permissions[@]}"; do
        ((processed++))
        update_status_bar "Calculating format: $perm" "$processed" "$total"
        local length=${#perm}
        if ((length > max_length)); then
            max_length=$length
        fi
    done
    
    # Reset counter for display
    processed=0
    
    # Print header
    log info "+$(printf -- '-%.0s' {1..$((max_length + 4))})+"
    log info "| Permission$(printf ' %.0s' {1..$((max_length - 9))}) |"
    log info "+$(printf -- '-%.0s' {1..$((max_length + 4))})+"
    
    # Print permissions
    for perm in "${permissions[@]}"; do
        ((processed++))
        update_status_bar "Displaying permission: $perm" "$processed" "$total"
        log info "| $perm$(printf ' %.0s' {1..$((max_length - ${#perm}))}) |"
        sleep 0.1
    done
    
    # Print footer
    log info "+$(printf -- '-%.0s' {1..$((max_length + 4))})+"
}

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

function get_predefined_permissions() {
    local service="$1"
    local -a permissions=()
    
    log info "Loading predefined permissions for service: $service"
    start_spinner "Loading permissions"
    
    case "$service" in
        terraform)
            permissions=(
                # Core permissions
                "resourcemanager.organizations.get"
                "resourcemanager.organizations.getIamPolicy"
                "resourcemanager.projects.get"
                "resourcemanager.projects.getIamPolicy"
                "resourcemanager.projects.setIamPolicy"
                "resourcemanager.folders.get"
                "resourcemanager.folders.list"
                
                # Service management
                "serviceusage.services.enable"
                "serviceusage.services.disable"
                "serviceusage.services.get"
                "serviceusage.services.list"
                
                # IAM management
                "iam.roles.get"
                "iam.roles.list"
                "iam.serviceAccounts.actAs"
                "iam.serviceAccounts.get"
                "iam.serviceAccounts.list"
                
                # Billing management
                "billing.accounts.get"
                "billing.accounts.list"
                "billing.projectBillingInfo.get"
                "billing.projectBillingInfo.update"
            )
            ;;
        *)
            stop_spinner
            error "Unknown service: $service"
            ;;
    esac
    
    stop_spinner
    log success "✓ Loaded ${#permissions[@]} predefined permissions"
    echo "${permissions[@]}"
}

# Function to get ANSI color codes
function get_color() {
    case "$1" in
        blue)   echo '\033[34m' ;;
        green)  echo '\033[32m' ;;
        yellow) echo '\033[33m' ;;
        red)    echo '\033[31m' ;;
        reset)  echo '\033[0m' ;;
    esac
}

# Function to display a progress bar
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

# Function to get enabled services and their required permissions for Terraform
function get_terraform_service_permissions() {
    local org_id="$1"
    local project_id="$2"
    local test_mode="$3"
    local -a permissions=()
    local -a services=()
    local temp_file=$(mktemp)
    local timeout_seconds=30
    
    # Initialize status bar
    init_status_bar
    trap cleanup EXIT INT TERM
    
    log info "Loading core Terraform permissions..."
    start_spinner "Loading core permissions"
    
    # Core permissions that Terraform always needs
    local -a core_permissions=(
        # Organization and project management
        "resourcemanager.organizations.get"
        "resourcemanager.organizations.getIamPolicy"
        "resourcemanager.projects.get"
        "resourcemanager.projects.getIamPolicy"
        "resourcemanager.projects.setIamPolicy"
        "resourcemanager.folders.get"
        "resourcemanager.folders.list"
        
        # Service management
        "serviceusage.services.enable"
        "serviceusage.services.disable"
        "serviceusage.services.get"
        "serviceusage.services.list"
        
        # IAM management
        "iam.roles.get"
        "iam.roles.list"
        "iam.serviceAccounts.actAs"
        "iam.serviceAccounts.get"
        "iam.serviceAccounts.list"
        
        # Billing management
        "billing.accounts.get"
        "billing.accounts.list"
        "billing.projectBillingInfo.get"
        "billing.projectBillingInfo.update"
    )
    
    permissions+=("${core_permissions[@]}")
    stop_spinner
    log success "✓ Loaded ${#core_permissions[@]} core permissions"
    
    # Get all projects in the organization
    local -a projects=()
    if [[ -n "$org_id" ]]; then
        log info "Scanning organization $org_id for projects..."
        start_spinner "Listing projects"
        
        if ! timeout $timeout_seconds gcloud projects list --filter="parent.id=$org_id" --format="value(projectId)" > "$temp_file" 2>/dev/null; then
            stop_spinner
            error "Failed to list projects in organization $org_id (timeout after ${timeout_seconds}s)"
        fi
        
        projects=(${(f)"$(<$temp_file)"})
        if [[ "$test_mode" == "true" ]]; then
            projects=(${projects[1,2]})
        fi
        
        stop_spinner
        log success "✓ Found ${#projects[@]} projects in organization"
    elif [[ -n "$project_id" ]]; then
        log info "Using specified project: $project_id"
        projects=("$project_id")
    else
        error "Either organization ID or project ID must be specified"
    fi
    
    log info "Scanning for enabled services..."
    : > "$temp_file"
    
    local project_count=0
    local total_projects=${#projects[@]}
    local start_time=$SECONDS
    local last_update=0
    
    for project in "${projects[@]}"; do
        ((project_count++))
        local elapsed=$((SECONDS - start_time))
        local avg_time=$((elapsed / project_count))
        local remaining=$(((total_projects - project_count) * avg_time))
        
        update_status_bar "Scanning project: $project" "$project_count" "$total_projects"
        
        if ! timeout $timeout_seconds gcloud services list --project="$project" --format="value(config.name)" >> "$temp_file" 2>/dev/null; then
            log warning "⚠ Warning: Timeout scanning services for project $project (skipping)"
            continue
        fi
        
        if (( project_count % 5 == 0 )); then
            local scanned_services=(${(f)"$(<$temp_file)"})
            log info "↻ Progress: Found ${#scanned_services[@]} services so far"
        fi
        
        sleep 0.1
    done
    
    log info "Processing service list..."
    services=(${(f)"$(<$temp_file)"})
    services=(${(u)services[@]})
    if [[ "$test_mode" == "true" ]]; then
        services=(${services[1,5]})
    fi
    rm -f "$temp_file"
    
    log success "✓ Found ${#services[@]} unique services across ${#projects[@]} projects"
    log info "Mapping services to required Terraform permissions..."
    
    local processed_services=0
    local total_services=${#services[@]}
    local start_time=$SECONDS
    
    for service in "${services[@]}"; do
        ((processed_services++))
        update_status_bar "Analyzing service: $service" "$processed_services" "$total_services"
        
        # Map each service to its required Terraform permissions
        case "$service" in
            compute.googleapis.com)
                permissions+=(
                    # ... existing compute permissions ...
                )
                ;;
            container.googleapis.com)
                permissions+=(
                    # ... existing container permissions ...
                )
                ;;
            # ... rest of the service cases ...
        esac
        
        sleep 0.1
    done
    
    log success "✓ Completed scanning in $(format_duration $((SECONDS - start_time)))"
    echo "${permissions[@]}"
}

# Function to check for testing permissions
function check_testing_permissions() {
    local -a permissions=("$@")
    local -a testing_permissions=()
    local temp_file=$(mktemp)
    
    # Get all testable permissions with their stages
    gcloud iam list-testable-permissions "//cloudresourcemanager.googleapis.com/organizations/1" \
        --format="table(name,stage)" > "$temp_file" 2>/dev/null
    
    # Check each permission
    for perm in "${permissions[@]}"; do
        # Skip empty permissions or status messages
        if [[ -z "$perm" || "$perm" =~ ^(Scanning|Found|Analyzing) ]]; then
            continue
        fi
        
        # Check if permission is in TESTING stage
        if grep -q "^${perm}.*TESTING" "$temp_file" 2>/dev/null; then
            testing_permissions+=("$perm")
        fi
    done
    
    rm "$temp_file"
    echo "${testing_permissions[@]}"
}

# Validation and error handling functions
function validate_permissions() {
    local -a permissions=("$@")
    local -a invalid_permissions=()
    local total=${#permissions[@]}
    local processed=0
    
    log info "Validating permissions..."
    
    # Known valid permission prefixes
    local -a valid_prefixes=(
        "billing"
        "compute"
        "container"
        "iam"
        "resourcemanager"
        "storage"
        "serviceusage"
        "bigquery"
        "cloudfunctions"
        "cloudkms"
        "cloudsql"
        "dataflow"
        "logging"
        "monitoring"
        "pubsub"
        "run"
    )
    
    for perm in "${permissions[@]}"; do
        ((processed++))
        update_status_bar "Validating permission: $perm" "$processed" "$total"
        
        # Skip empty permissions
        [[ -z "$perm" ]] && continue
        
        # Check if permission starts with a valid prefix
        local is_valid=false
        for prefix in "${valid_prefixes[@]}"; do
            if [[ "$perm" =~ ^$prefix\. ]]; then
                is_valid=true
                break
            fi
        done
        
        if [[ "$is_valid" == false ]]; then
            invalid_permissions+=("$perm")
        fi
        
        sleep 0.1
    done
    
    if [[ ${#invalid_permissions[@]} -gt 0 ]]; then
        log warning "Found ${#invalid_permissions[@]} invalid permissions:"
        for perm in "${invalid_permissions[@]}"; do
            log warning "  - $perm"
        done
        return 1
    fi
    
    log success "✓ All permissions are valid"
    return 0
}

function expand_wildcard_permissions() {
    local base_perm="$1"
    local -a expanded=()
    
    log info "Expanding wildcard permission: $base_perm"
    start_spinner "Expanding permission"
    
    # Map of known wildcard expansions
    case "$base_perm" in
        "compute.disks")
            expanded=(
                "compute.disks.create"
                "compute.disks.delete"
                "compute.disks.get"
                "compute.disks.list"
                "compute.disks.update"
                "compute.disks.use"
            )
            ;;
        "compute.instances")
            expanded=(
                "compute.instances.create"
                "compute.instances.delete"
                "compute.instances.get"
                "compute.instances.list"
                "compute.instances.update"
                "compute.instances.use"
                "compute.instances.start"
                "compute.instances.stop"
                "compute.instances.setMetadata"
                "compute.instances.setTags"
            )
            ;;
        "compute.networks")
            expanded=(
                "compute.networks.create"
                "compute.networks.delete"
                "compute.networks.get"
                "compute.networks.list"
                "compute.networks.update"
                "compute.networks.use"
                "compute.networks.updatePolicy"
            )
            ;;
        "container.clusters")
            expanded=(
                "container.clusters.create"
                "container.clusters.delete"
                "container.clusters.get"
                "container.clusters.list"
                "container.clusters.update"
                "container.clusters.getCredentials"
            )
            ;;
        "bigquery.datasets")
            expanded=(
                "bigquery.datasets.create"
                "bigquery.datasets.delete"
                "bigquery.datasets.get"
                "bigquery.datasets.getIamPolicy"
                "bigquery.datasets.list"
                "bigquery.datasets.setIamPolicy"
                "bigquery.datasets.update"
            )
            ;;
        "bigquery.tables")
            expanded=(
                "bigquery.tables.create"
                "bigquery.tables.delete"
                "bigquery.tables.export"
                "bigquery.tables.get"
                "bigquery.tables.getData"
                "bigquery.tables.getIamPolicy"
                "bigquery.tables.list"
                "bigquery.tables.setIamPolicy"
                "bigquery.tables.update"
                "bigquery.tables.updateData"
            )
            ;;
        "composer.environments")
            expanded=(
                "composer.environments.create"
                "composer.environments.delete"
                "composer.environments.get"
                "composer.environments.list"
                "composer.environments.update"
                "composer.environments.getIamPolicy"
                "composer.environments.setIamPolicy"
            )
            ;;
        *)
            # For unknown wildcards, return the base permission with common CRUD operations
            expanded=(
                "${base_perm}.create"
                "${base_perm}.delete"
                "${base_perm}.get"
                "${base_perm}.list"
                "${base_perm}.update"
            )
            ;;
    esac
    
    stop_spinner
    log success "✓ Expanded to ${#expanded[@]} permissions"
    echo "${expanded[@]}"
}

function validate_role_name() {
    local role_name="$1"
    
    log info "Validating role name: $role_name"
    start_spinner "Validating name"
    
    # Check length
    if [[ ${#role_name} -gt 64 ]]; then
        stop_spinner
        error "Role name must be 64 characters or less"
    fi
    
    # Check format
    if ! [[ "$role_name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        stop_spinner
        error "Role name must start with a letter and contain only letters, numbers, and underscores"
    fi
    
    stop_spinner
    log success "✓ Role name is valid"
    return 0
}

function validate_project_id() {
    local project_id="$1"
    
    log info "Validating project ID: $project_id"
    start_spinner "Validating project"
    
    # Check if project exists
    if ! gcloud projects describe "$project_id" &>/dev/null; then
        stop_spinner
        error "Project $project_id does not exist or you don't have access to it"
    fi
    
    stop_spinner
    log success "✓ Project ID is valid"
    return 0
}

function validate_org_id() {
    local org_id="$1"
    
    log info "Validating organization ID: $org_id"
    start_spinner "Validating organization"
    
    # Check if organization exists
    if ! gcloud organizations describe "$org_id" &>/dev/null; then
        stop_spinner
        error "Organization $org_id does not exist or you don't have access to it"
    fi
    
    stop_spinner
    log success "✓ Organization ID is valid"
    return 0
}

# Function to create role with testing permission handling
function create_role_with_testing_check() {
    local role_name="$1"
    local org_id="$2"
    local project_id="$3"
    shift 3
    local -a permissions=("$@")
    
    # Filter permissions
    local -a filtered_permissions=($(filter_permissions "${permissions[@]}"))
    
    # Validate permissions
    printf "\nValidating permissions against GCP IAM...\n"
    local -a valid_permissions=($(validate_permissions "${filtered_permissions[@]}"))
    local invalid_count=$((${#filtered_permissions[@]} - ${#valid_permissions[@]}))
    
    if [[ $invalid_count -gt 0 ]]; then
        printf "\n⚠️  WARNING: Found %d invalid permissions that will be excluded\n" "$invalid_count"
        printf "Proceeding with %d valid permissions\n" "${#valid_permissions[@]}"
    fi
    
    # Check for testing permissions
    local -a testing_perms=($(check_testing_permissions "${valid_permissions[@]}"))
    local -a stable_permissions=()
    
    # Separate testing and stable permissions
    for perm in "${valid_permissions[@]}"; do
        if [[ ! " ${testing_perms[@]} " =~ " ${perm} " ]]; then
            stable_permissions+=("$perm")
        fi
    done
    
    # If testing permissions are found, show warning and options
    if [[ ${#testing_perms[@]} -gt 0 ]]; then
        printf "\n⚠️  WARNING: Testing Permissions Detected ⚠️\n"
        printf "The following permissions are in TESTING stage and may be removed in the future:\n"
        printf "  - %s\n" "${testing_perms[@]}"
        printf "\nTotal valid permissions: %d\n" "${#valid_permissions[@]}"
        printf "Testing permissions: %d\n" "${#testing_perms[@]}"
        printf "Stable permissions: %d\n" "${#stable_permissions[@]}"
        
        local -a test_options=(
            "Proceed with all permissions (including TESTING permissions)"
            "Proceed without TESTING permissions"
            "Cancel operation"
        )
        
        printf "\nHow would you like to proceed?\n"
        show_selection_menu "Select an option:" "${test_options[@]}"
        local test_choice=$?
        
        case $test_choice in
            1)  # Use all permissions
                printf "\nProceeding with all permissions (including %d testing permissions)...\n" "${#testing_perms[@]}"
                local use_permissions=("${valid_permissions[@]}")
                local use_quiet=false
                ;;
            2)  # Skip testing permissions
                printf "\nProceeding with stable permissions only (excluding %d testing permissions)...\n" "${#testing_perms[@]}"
                local use_permissions=("${stable_permissions[@]}")
                local use_quiet=true
                ;;
            3)  # Cancel
                printf "Operation cancelled\n"
                return 1
                ;;
        esac
    else
        local use_permissions=("${valid_permissions[@]}")
        local use_quiet=true
    fi
    
    # Create the role
    local create_cmd="gcloud iam roles create \"$role_name\""
    if [[ -n "$org_id" ]]; then
        create_cmd+=" --organization=\"$org_id\""
    else
        create_cmd+=" --project=\"$project_id\""
    fi
    
    create_cmd+=" --title=\"Custom Role for $service\""
    create_cmd+=" --description=\"Custom role created for $service service\""
    create_cmd+=" --permissions=\"${(j:,:)use_permissions}\""
    create_cmd+=" --stage=\"GA\""
    
    # Add quiet flag if appropriate
    if [[ "$use_quiet" == "true" ]]; then
        create_cmd+=" --quiet"
    fi
    
    printf "\nCreating role with %d permissions...\n" "${#use_permissions[@]}"
    if eval "$create_cmd"; then
        printf "\nSuccess: Role created successfully\n"
        if [[ -n "$org_id" ]]; then
            printf "Role path: organizations/$org_id/roles/$role_name\n"
        else
            printf "Role path: projects/$project_id/roles/$role_name\n"
        fi
        return 0
    else
        printf "\nError: Failed to create role\n"
        return 1
    fi
}

# Function to create role
function create_role() {
    local role_name="$1"
    local org_id="$2"
    local project_id="$3"
    local permissions=("${@:4}")
    local test_mode="$5"
    
    init_status_bar
    trap cleanup EXIT INT TERM
    
    # Validate inputs
    if [[ -z "$role_name" ]]; then
        error "Role name is required"
    fi

    if [[ -z "$org_id" && -z "$project_id" ]]; then
        error "Either organization ID or project ID must be specified"
    fi
    
    if [[ ${#permissions[@]} -eq 0 ]]; then
        error "No permissions specified"
    fi
    
    local role_id="custom.${role_name}"
    local parent_flag=""
    local parent_value=""
    
    if [[ -n "$org_id" ]]; then
        parent_flag="--organization"
        parent_value="$org_id"
        log info "Creating organization-level custom role: $role_id"
    else
        parent_flag="--project"
        parent_value="$project_id"
        log info "Creating project-level custom role: $role_id"
    fi
    
    # Check if role already exists
    start_spinner "Checking if role exists"
    if gcloud iam roles describe "$role_id" "$parent_flag" "$parent_value" &>/dev/null; then
        stop_spinner
        error "Role $role_id already exists"
    fi
    stop_spinner
    
    # Format permissions for display
    local formatted_permissions=""
    local total_perms=${#permissions[@]}
    local processed=0
    
    log info "Processing ${total_perms} permissions..."
    
    for perm in "${permissions[@]}"; do
        ((processed++))
        update_status_bar "Formatting permission: $perm" "$processed" "$total_perms"
        formatted_permissions+="$perm,"
        sleep 0.1
    done
    
    # Remove trailing comma
    formatted_permissions="${formatted_permissions%,}"
    
    # Create temporary file for permissions
    local temp_file=$(mktemp)
    echo "$formatted_permissions" > "$temp_file"
    
    log info "Creating role with ${total_perms} permissions..."
    start_spinner "Creating role"
    
    if [[ "$test_mode" == "true" ]]; then
        log warning "TEST MODE: Would create role with command:"
        log info "gcloud iam roles create $role_name $parent_flag $parent_value --permissions-from-file=$temp_file --stage=ALPHA"
    else
        if ! gcloud iam roles create "$role_name" "$parent_flag" "$parent_value" --permissions-from-file="$temp_file" --stage=ALPHA; then
            stop_spinner
            rm -f "$temp_file"
            error "Failed to create role $role_id"
        fi
    fi
    
    stop_spinner
    rm -f "$temp_file"
    
    if [[ "$test_mode" != "true" ]]; then
        log success "✓ Successfully created role: $role_id"
        log info "Verifying role creation..."
        
        start_spinner "Verifying role"
        if ! gcloud iam roles describe "$role_id" "$parent_flag" "$parent_value" &>/dev/null; then
            stop_spinner
            error "Role verification failed: Unable to retrieve newly created role"
        fi
        stop_spinner
        
        log success "✓ Role verification successful"
    else
        log success "✓ Test completed successfully"
    fi
}

# Function to handle help requests
function handle_help() {
    local cmd="$1"
    local subcmd="$2"
    
    case "$cmd" in
        "")
            show_main_help
            return 0
            ;;
        "iam")
            if [[ -z "$subcmd" ]]; then
                show_iam_help
                return 0
            fi
            case "$subcmd" in
                "create-role")
                    show_create_role_help
                    return 0
                    ;;
                "merge-roles")
                    show_merge_roles_help
                    return 0
                    ;;
                *)
                    show_iam_help
                    return 0
                    ;;
            esac
            ;;
        "projects")
            if [[ -z "$subcmd" ]]; then
                show_projects_help
                return 0
            fi
            case "$subcmd" in
                "list")
                    show_projects_list_help
                    return 0
                    ;;
                *)
                    show_projects_help
                    return 0
                    ;;
            esac
            ;;
        *)
            show_main_help
            return 0
            ;;
    esac
}

# Main command handler
function gcloud-util() {
    local command="$1"
    shift

    # Initialize status bar system
    init_status_bar
    trap cleanup EXIT INT TERM
    
        case "$command" in
            iam)
    local subcommand="$1"
    shift

                case "$subcommand" in
                    create-role)
                    local role_name=""
                    local service=""
                    local org_id=""
                    local project_id=""
                    local scan_services=false
                    local test_mode=false
                    
                    # Parse arguments
                    while [[ $# -gt 0 ]]; do
                        case "$1" in
                            --role)
                                role_name="$2"
                                shift 2
                                ;;
                            --service)
                                service="$2"
                                shift 2
                                ;;
                            --org-id)
                                org_id="$2"
                                shift 2
                                ;;
                            --project-id)
                                project_id="$2"
                                shift 2
                                ;;
                            --scan-services)
                                scan_services=true
                                shift
                                ;;
                            --test)
                                test_mode=true
                                shift
                                ;;
                            *)
                                error "Unknown option: $1"
                ;;
        esac
                    done
                    
                    # Validate required parameters
                    if [[ -z "$role_name" ]]; then
                        error "--role parameter is required"
                    fi
                    
                    if [[ -z "$service" ]]; then
                        error "--service parameter is required"
                    fi
                    
                    if [[ -z "$org_id" && -z "$project_id" ]]; then
                        error "Either --org-id or --project-id must be specified"
                    fi
                    
                    if [[ -n "$org_id" && -n "$project_id" ]]; then
                        error "Cannot specify both --org-id and --project-id"
                    fi
                    
                    # Get permissions based on service and scan flag
                    local -a permissions=()
                    if [[ "$service" == "terraform" && "$scan_services" == true ]]; then
                        log info "Scanning for active services and required permissions..."
                        permissions=($(get_terraform_service_permissions "$org_id" "$project_id" "$test_mode"))
                    else
                        log info "Using predefined permissions for service: $service"
                        permissions=($(get_predefined_permissions "$service"))
                    fi
                    
                    # Filter and display permissions
                    local -a filtered_permissions=($(filter_permissions "${permissions[@]}"))
                    
                    # Display confirmation screen
                    log info "=== Role Creation Confirmation ==="
                    log info "--------------------------------"
                    
                    log info "Role Details:"
                    log info "  Service: $service"
                    log info "  Role Name: $role_name"
                    
                    if [[ -n "$org_id" ]]; then
                        log info "  Location: Organization Level (org_id: $org_id)"
                        log info "  Full Role Path: organizations/$org_id/roles/$role_name"
                    else
                        log info "  Location: Project Level (project_id: $project_id)"
                        log info "  Full Role Path: projects/$project_id/roles/$role_name"
                        
                        # Warning for project-level terraform roles
                        if [[ "$service" == "terraform" ]]; then
                            log warning "⚠️  WARNING: Project-Level Role"
                            log warning "Creating Terraform roles at the project level is not recommended."
                            log warning "It's better to create them at the organization level for broader access control."
                            log warning "This ensures consistent management across all projects."
                        fi
                    fi
                    
                    log info "\nPermissions Summary:"
                    log info "-------------------"
                    log info "Total permissions: ${#filtered_permissions[@]}"
                    
                    # Display permissions table
                    display_permissions_table "${filtered_permissions[@]}"
                    
                    # Consolidated confirmation
                    local -a confirm_options=(
                        "Create role with specified permissions"
                        "Cancel operation"
                    )
                    
                    log info "\nDo you want to proceed?"
                    show_selection_menu "Select an option:" "${confirm_options[@]}"
                    local confirm=$?
                    
                    case $confirm in
                        1)  # Proceed with permissions
                            create_role "$role_name" "$org_id" "$project_id" "${filtered_permissions[@]}" "$test_mode"
                            return $?
                            ;;
                        2)  # Cancel operation
                            log warning "Operation cancelled"
                    return 1
                    ;;
            esac
                    ;;
                *)
                    error "Unknown IAM subcommand: $subcommand"
                    ;;
            esac
            ;;
        help)
            show_help
            ;;
        *)
            error "Unknown command: $command"
            ;;
    esac
}

# Add new function to show projects help
function show_projects_help() {
    echo "GCloud Projects Management Commands"
    echo "\nAvailable subcommands:"
    echo "  list          - List GCP projects"
    echo "  help          - Show this help message"
    echo "\nUsage:"
    echo "  gcloud-util projects <subcommand> [options]"
    echo "\nGet detailed help:"
    echo "  gcloud-util projects help                - Show this help"
    echo "  gcloud-util projects <subcommand> --help - Show help for a specific subcommand"
}

# Add new function for projects list help
function show_projects_list_help() {
    echo "GCloud Projects List Command"
    echo "\nDescription:"
    echo "  Lists GCP projects (by default excludes system projects starting with sys-*)"
    echo "\nUsage:"
    echo "  gcloud-util projects list [--all] [--output FORMAT]"
    echo "\nOptional Parameters:"
    echo "  --all            : Include all projects (including sys-* projects)"
    add_output_format_help
    echo "\nExamples:"
    echo "  gcloud-util projects list"
    echo "  gcloud-util projects list --all"
    echo "  gcloud-util projects list --output json"
    echo "  gcloud-util projects list --all --output yaml"
}

# Auto-completion setup
function _gcloud-util() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    # Define the main commands
    local -a commands=(
        'iam:IAM role and permission management'
        'projects:GCP projects management'
        'help:Show help message'
    )

    # Define IAM subcommands
    local -a iam_subcommands=(
        'create-role:Create a custom role for a specific service'
        'describe-role:Get detailed information about a specific IAM role'
        'describe-user:Get detailed information about a specific IAM user'
        'list-roles:List all custom IAM roles in a project or organization'
        'list-users:List all IAM users in a project or organization'
        'merge-roles:Merge multiple IAM roles into a new role'
        'backup:Backup IAM configurations'
        'restore:Restore IAM configurations from backup'
        'help:Show IAM help message'
    )

    # Define projects subcommands
    local -a projects_subcommands=(
        'list:List GCP projects'
        'help:Show projects help message'
    )

    # Define common options
    local -a common_options=(
        '--project-id[The Google Cloud Project ID]:project id'
        '--org-id[The Google Cloud Organization ID]:org id'
        '--all[Execute on organization and all its projects]'
        '--output[Output format (table|json|yaml|text|csv)]:format:(table json yaml text csv)'
    )

    # Define search options
    local -a search_options=(
        '--search[Search term to filter results]:term'
    )

    # Define role options
    local -a role_options=(
        '--role[The name of the role]:role'
    )

    # Define user options
    local -a user_options=(
        '--user[The email address of the user]:email'
    )

    # Define backup options
    local -a backup_options=(
        '--output-dir[Directory to store backup files]:directory:_files -/'
    )

    # Define restore options
    local -a restore_options=(
        '--dir[Directory containing backup files]:directory:_files -/'
        '--file[Single backup file to restore from]:file:_files'
    )

    # Define service options
    local -a service_options=(
        '--service[Service to create role for]:service:(terraform)'
        '--scan-services[Scan enabled services for required permissions]'
    )

    # Main completion logic
    _arguments -C \
        '1: :->command' \
        '2: :->subcommand' \
        '*: :->args' && return 0

    case $state in
        command)
            _describe -t commands 'gcloud-util commands' commands
            ;;
        subcommand)
            case $words[2] in
                iam)
                    _describe -t iam_subcommands 'iam subcommands' iam_subcommands
                    ;;
                projects)
                    _describe -t projects_subcommands 'projects subcommands' projects_subcommands
                    ;;
            esac
            ;;
        args)
            case $words[2] in
                iam)
                    case $words[3] in
                        create-role)
                            _arguments \
                                $common_options \
                                $role_options \
                                $service_options \
                                '--scan-services[Scan enabled services for required permissions]'
                            ;;
                        describe-role)
                            _arguments \
                                $common_options \
                                $role_options
                            ;;
                        describe-user)
                            _arguments \
                                $common_options \
                                $user_options
                            ;;
                        list-roles)
                            _arguments \
                                $common_options \
                                $search_options
                            ;;
                        list-users)
                            _arguments \
                                $common_options \
                                $search_options
                            ;;
                        merge-roles)
                            _arguments \
                                '--role[Source role path]:role path' \
                                '--destination-role[Destination role path]:role path' \
                                $common_options
                            ;;
                        backup)
                            _arguments \
                                $common_options \
                                $user_options \
                                $backup_options
                            ;;
                        restore)
                            _arguments \
                                $restore_options
                            ;;
                    esac
                    ;;
                projects)
                    case $words[3] in
                        list)
                            _arguments \
                                $common_options
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}

# Register the completion function
compdef _gcloud-util gcloud-util

# Function to test progress display
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

# Status bar functions
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

function start_spinner() {
    local message="$1"
    STATUS_BAR_MESSAGE="$message"
    STATUS_BAR_SPINNER_ACTIVE=true
    STATUS_BAR_SPINNER_IDX=0
    _draw_status_bar
}

function stop_spinner() {
    STATUS_BAR_SPINNER_ACTIVE=false
    _draw_status_bar
}

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

function error() {
    log error "$@"
}

function get_color() {
    local color="$1"
    case "$color" in
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

# Help functions
function show_help() {
    log info "gcloud-util - Google Cloud Platform Utility Tool"
    log info "Version: 1.0.0"
    log info ""
    log info "Usage: gcloud-util COMMAND [SUBCOMMAND] [OPTIONS]"
    log info ""
    log info "Commands:"
    log info "  iam         IAM role and permission management"
    log info "  projects    GCP projects management"
    log info "  help        Show this help message"
    log info ""
    log info "For more details on a specific command, run:"
    log info "  gcloud-util COMMAND help"
}

function show_iam_help() {
    log info "IAM Role Management Commands"
    log info ""
    log info "Usage: gcloud-util iam SUBCOMMAND [OPTIONS]"
    log info ""
    log info "Subcommands:"
    log info "  create-role    Create a new custom IAM role"
    log info ""
    log info "For more details on a specific subcommand, run:"
    log info "  gcloud-util iam SUBCOMMAND help"
}

function show_create_role_help() {
    log info "Create Custom IAM Role"
    log info ""
    log info "Usage: gcloud-util iam create-role [OPTIONS]"
    log info ""
    log info "Options:"
    log info "  --role NAME           Name of the role to create (required)"
    log info "  --service NAME        Service to create role for (required)"
    log info "  --org-id ID          Organization ID for org-level role"
    log info "  --project-id ID      Project ID for project-level role"
    log info "  --scan-services      Scan for active services and required permissions"
    log info "  --test               Run in test mode without making changes"
    log info ""
    log info "Examples:"
    log info "  Create organization-level role for Terraform:"
    log info "    gcloud-util iam create-role --role terraform_admin --service terraform --org-id 123456789"
    log info ""
    log info "  Create project-level role with service scanning:"
    log info "    gcloud-util iam create-role --role custom_admin --service terraform --project-id my-project --scan-services"
}

function show_projects_help() {
    log info "Project Management Commands"
    log info ""
    log info "Usage: gcloud-util projects SUBCOMMAND [OPTIONS]"
    log info ""
    log info "Subcommands:"
    log info "  list    List GCP projects"
    log info ""
    log info "For more details on a specific subcommand, run:"
    log info "  gcloud-util projects SUBCOMMAND help"
}

function show_projects_list_help() {
    log info "List GCP Projects"
    log info ""
    log info "Usage: gcloud-util projects list [OPTIONS]"
    log info ""
    log info "Options:"
    log info "  --org-id ID    Organization ID to list projects from"
    log info "  --filter STR   Filter projects by name, ID, or labels"
    log info "  --format FMT   Output format (table, json, yaml)"
    log info ""
    log info "Examples:"
    log info "  List all projects in an organization:"
    log info "    gcloud-util projects list --org-id 123456789"
    log info ""
    log info "  List projects with specific filter:"
    log info "    gcloud-util projects list --filter 'labels.env=prod'"
}

