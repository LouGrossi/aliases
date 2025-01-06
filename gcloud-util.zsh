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

# Function to display permissions in table format
function display_permissions_table() {
    local -a permissions=("$@")
    local -a filtered_permissions=()
    
    # Print status messages in color
    print -P "%F{blue}Scanning organization and projects for enabled services...%f"
    
    # Filter out status messages and format rows
    for perm in "${permissions[@]}"; do
        # Skip if permission is empty or contains scanning status messages
        if [[ -z "$perm" || "$perm" =~ ^(Scanning|Found|Analyzing|project:|organization|for|enabled|services|across|all|scanned|unique|required|each|service|[0-9]+|eh-core-|gam-project-|pam-organization-|permissions|projects) ]]; then
            continue
        fi
        
        # Skip if the permission doesn't contain a dot (not a valid permission)
        if [[ ! "$perm" =~ \. ]]; then
            continue
        fi
        
        # Skip if the permission doesn't match the standard format (service.resource.action)
        if [[ ! "$perm" =~ ^[a-z]+\.[a-z]+\.[a-z]+ ]]; then
            continue
        fi
        
        # Add to filtered permissions array
        filtered_permissions+=("$perm")
    done
    
    # Sort permissions by category and name
    filtered_permissions=($(printf "%s\n" "${filtered_permissions[@]}" | sort))
    
    print -P "%F{green}Found ${#filtered_permissions[@]} unique permissions across all scanned services%f\n"
    
    # Create temporary file for table data with headers
    local temp_file=$(mktemp)
    echo "Permission,Category" > "$temp_file"
    
    # Add each permission with its category
    for perm in "${filtered_permissions[@]}"; do
        local category="${perm%%.*}"
        printf "%s,%s\n" "$perm" "$category" >> "$temp_file"
    done
    
    # Use column command to format the table
    echo "\nPermissions Table:"
    echo "----------------"
    column -t -s ',' "$temp_file"
    
    # Cleanup
    rm "$temp_file"
}

# Function to expand wildcard permissions
function expand_wildcard_permissions() {
    local base_perm="$1"
    local -a expanded=()
    
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
    
    echo "${expanded[@]}"
}

# Function to get enabled services and their required permissions for Terraform
function get_terraform_service_permissions() {
    local org_id="$1"
    local project_id="$2"
    local -a permissions=()
    local -a services=()
    local temp_file=$(mktemp)

    # Core permissions that Terraform always needs
    print -P "%F{blue}Loading core Terraform permissions...%f"
    local -a core_permissions=(
        # Billing management
        "billing.accounts.get"
        "billing.accounts.list"
        "billing.accounts.getIamPolicy"
        "billing.projectBillingInfo.get"
        "billing.projectBillingInfo.update"

        # Project management
        "resourcemanager.projects.get"
        "resourcemanager.projects.getIamPolicy"
        "resourcemanager.projects.setIamPolicy"
        "resourcemanager.projects.update"
        "resourcemanager.projects.createBillingAssignment"
        "resourcemanager.projects.deleteBillingAssignment"

        # Organization management
        "resourcemanager.organizations.get"
        "resourcemanager.organizations.getIamPolicy"
        "resourcemanager.folders.get"
        "resourcemanager.folders.list"

        # Service management
        "serviceusage.services.enable"
        "serviceusage.services.disable"
        "serviceusage.services.get"
        "serviceusage.services.list"

        # IAM
        "iam.roles.get"
        "iam.roles.list"
        "iam.serviceAccounts.actAs"
        "iam.serviceAccounts.get"
        "iam.serviceAccounts.list"
        "iam.serviceAccounts.getIamPolicy"
        "iam.serviceAccounts.setIamPolicy"
    )

    permissions+=("${core_permissions[@]}")
    print -P "%F{green}Loaded ${#core_permissions[@]} core permissions%f"

    # Get all projects if org_id is provided
    local -a projects=()
    if [[ -n "$org_id" ]]; then
        print -P "%F{blue}Scanning organization $org_id for projects...%f"
        gcloud projects list --filter="parent.id=$org_id" --format="value(projectId)" > "$temp_file" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            print -P "%F{red}Error: Failed to list projects in organization $org_id%f"
            rm "$temp_file"
            return 1
        fi
        # Read projects into array using zsh syntax
        projects=(${(f)"$(<$temp_file)"})
        print -P "%F{green}Found ${#projects[@]} projects in organization%f"
    elif [[ -n "$project_id" ]]; then
        print -P "%F{blue}Using specified project: $project_id%f"
        projects=("$project_id")
    fi

    # Get all enabled services in one go
    print -P "%F{blue}Fetching enabled services for all projects...%f"
    : > "$temp_file"  # Clear temp file
    
    local project_count=0
    for project in "${projects[@]}"; do
        ((project_count++))
        print -P "%F{blue}Scanning project ($project_count/${#projects[@]}): $project%f"
        gcloud services list --project="$project" --format="value(config.name)" >> "$temp_file" 2>/dev/null
    done

    # Read and deduplicate services using zsh syntax
    print -P "%F{blue}Processing service list...%f"
    services=(${(f)"$(<$temp_file)"})
    services=(${(u)services[@]})  # Remove duplicates
    rm "$temp_file"

    print -P "%F{green}Found ${#services[@]} unique services across ${#projects[@]} projects%f"
    print -P "%F{blue}Analyzing permissions for each service...%f"

    # Process services in batches for better performance
    local batch_size=5
    local total_batches=$(( (${#services[@]} + batch_size - 1) / batch_size ))
    local current_batch=0
    local processed_services=0

    while [[ $processed_services -lt ${#services[@]} ]]; do
        ((current_batch++))
        print -P "%F{blue}Processing batch $current_batch of $total_batches...%f"
        
        local end_idx=$((processed_services + batch_size))
        [[ $end_idx -gt ${#services[@]} ]] && end_idx=${#services[@]}
        
        for ((i = processed_services; i < end_idx; i++)); do
            local service="${services[$i]}"
            print -P "%F{blue}Analyzing service $((i + 1))/${#services[@]}: $service%f"
            
            case "$service" in
                # ... (keep existing service cases)
            esac
        done
        
        processed_services=$end_idx
        print -P "%F{green}Processed $processed_services out of ${#services[@]} services%f"
    done

    print -P "%F{blue}Expanding wildcard permissions...%f"
    local expanded_permissions=()
    local -A seen=()
    local wildcard_count=0
    local expanded_count=0
    
    # Process permissions in batches
    local perm_batch_size=100
    local total_perm_batches=$(( (${#permissions[@]} + perm_batch_size - 1) / perm_batch_size ))
    local current_perm_batch=0
    local processed_perms=0

    while [[ $processed_perms -lt ${#permissions[@]} ]]; do
        ((current_perm_batch++))
        print -P "%F{blue}Processing permission batch $current_perm_batch of $total_perm_batches...%f"
        
        local perm_end_idx=$((processed_perms + perm_batch_size))
        [[ $perm_end_idx -gt ${#permissions[@]} ]] && perm_end_idx=${#permissions[@]}
        
        for ((i = processed_perms; i < perm_end_idx; i++)); do
            local perm="${permissions[$i]}"
            if [[ "$perm" == *".*" ]]; then
                ((wildcard_count++))
                local base_perm="${perm%.*}"
                local temp_perms=($(expand_wildcard_permissions "$base_perm"))
                for expanded in "${temp_perms[@]}"; do
                    if [[ -z "${seen[$expanded]}" ]]; then
                        expanded_permissions+=("$expanded")
                        seen[$expanded]=1
                        ((expanded_count++))
                    fi
                done
            else
                if [[ -z "${seen[$perm]}" ]]; then
                    expanded_permissions+=("$perm")
                    seen[$perm]=1
                fi
            fi
        done
        
        processed_perms=$perm_end_idx
        print -P "%F{green}Processed $processed_perms out of ${#permissions[@]} permissions%f"
    done

    print -P "%F{green}Expanded $wildcard_count wildcard permissions into $expanded_count concrete permissions%f"
    print -P "%F{green}Final result: ${#expanded_permissions[@]} unique permissions%f"
    echo "${expanded_permissions[@]}"
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

# Function to display selection menu
function show_selection_menu() {
    local prompt="$1"
    shift
    local -a options=("$@")
    local choice
    
    # Display prompt
    echo "$prompt"
    echo
    
    # Use select for menu
    PS3="Enter selection (1-${#options[@]}): "
    select choice in "${options[@]}"; do
        if [[ -n "$choice" ]]; then
            echo "\nSelected: $choice"
            return $REPLY
        fi
        echo "\nInvalid selection. Please try again."
    done
}

# Function to create role with testing permission handling
function create_role_with_testing_check() {
    local role_name="$1"
    local org_id="$2"
    local project_id="$3"
    local -a permissions=("${@:4}")
    
    # Create the role
    local create_cmd="gcloud iam roles create \"$role_name\""
    if [[ -n "$org_id" ]]; then
        create_cmd+=" --organization=\"$org_id\""
    else
        create_cmd+=" --project=\"$project_id\""
    fi
    
    create_cmd+=" --title=\"Custom Role for $service\""
    create_cmd+=" --description=\"Custom role created for $service service\""
    create_cmd+=" --permissions=\"${(j:,:)permissions}\""
    create_cmd+=" --stage=\"GA\""
    
    echo "\nCreating role..."
    if eval "$create_cmd"; then
        echo "\nSuccess: Role created successfully"
        if [[ -n "$org_id" ]]; then
            echo "Role path: organizations/$org_id/roles/$role_name"
        else
            echo "Role path: projects/$project_id/roles/$role_name"
        fi
        return 0
    else
        echo "\nError: Failed to create role"
        return 1
    fi
}

# Function to handle role creation
function create_role() {
    local role_name=""
    local service=""
    local org_id=""
    local project_id=""
    local scan_services=false
    
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
            *)
                echo "Error: Unknown option $1"
                return 1
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$role_name" ]]; then
        echo "Error: --role parameter is required"
        return 1
    fi

    if [[ -z "$service" ]]; then
        echo "Error: --service parameter is required"
        return 1
    fi

    if [[ -z "$org_id" && -z "$project_id" ]]; then
        echo "Error: Either --org-id or --project-id must be specified"
        return 1
    fi

    if [[ -n "$org_id" && -n "$project_id" ]]; then
        echo "Error: Cannot specify both --org-id and --project-id"
        return 1
    fi

    # Get permissions based on service and scan flag
    local permissions=()
    if [[ "$service" == "terraform" && "$scan_services" == true ]]; then
        echo "Scanning for active services and required permissions..."
        permissions=($(get_terraform_service_permissions "$org_id" "$project_id"))
    else
        # Use predefined permissions (existing code)
        permissions=(
            # Billing
            "billing.accounts.get"
            "billing.accounts.list"
            "billing.accounts.getIamPolicy"
            "billing.accounts.getUsageExportSpec"
            "billing.budgets.create"
            "billing.budgets.delete"
            "billing.budgets.get"
            "billing.budgets.list"
            "billing.budgets.update"
            "billing.projectBillingInfo.get"
            "billing.projectBillingInfo.update"

            # Compute Engine
            "compute.disks.create"
            "compute.disks.delete"
            "compute.disks.get"
            "compute.disks.list"
            "compute.disks.use"
            "compute.firewalls.create"
            "compute.firewalls.delete"
            "compute.firewalls.get"
            "compute.firewalls.list"
            "compute.firewalls.update"
            "compute.globalOperations.get"
            "compute.globalOperations.list"
            "compute.images.get"
            "compute.images.list"
            "compute.images.useReadOnly"
            "compute.instances.create"
            "compute.instances.delete"
            "compute.instances.get"
            "compute.instances.list"
            "compute.instances.setMetadata"
            "compute.instances.setTags"
            "compute.instances.start"
            "compute.instances.stop"
            "compute.instances.update"
            "compute.networks.create"
            "compute.networks.delete"
            "compute.networks.get"
            "compute.networks.list"
            "compute.networks.updatePolicy"
            "compute.regions.get"
            "compute.regions.list"
            "compute.subnetworks.create"
            "compute.subnetworks.delete"
            "compute.subnetworks.get"
            "compute.subnetworks.list"
            "compute.subnetworks.update"
            "compute.subnetworks.use"
            "compute.zones.get"
            "compute.zones.list"
            "compute.addresses.create"
            "compute.addresses.delete"
            "compute.addresses.get"
            "compute.addresses.list"
            "compute.addresses.use"
            "compute.backendServices.create"
            "compute.backendServices.delete"
            "compute.backendServices.get"
            "compute.backendServices.list"
            "compute.backendServices.update"
            "compute.healthChecks.create"
            "compute.healthChecks.delete"
            "compute.healthChecks.get"
            "compute.healthChecks.list"
            "compute.healthChecks.update"
            "compute.instanceGroups.create"
            "compute.instanceGroups.delete"
            "compute.instanceGroups.get"
            "compute.instanceGroups.list"
            "compute.instanceGroups.update"
            "compute.instanceTemplates.create"
            "compute.instanceTemplates.delete"
            "compute.instanceTemplates.get"
            "compute.instanceTemplates.list"
            "compute.targetPools.create"
            "compute.targetPools.delete"
            "compute.targetPools.get"
            "compute.targetPools.list"
            "compute.targetPools.update"
            
            # IAM
            "iam.roles.create"
            "iam.roles.delete"
            "iam.roles.get"
            "iam.roles.list"
            "iam.roles.update"
            "iam.serviceAccounts.actAs"
            "iam.serviceAccounts.create"
            "iam.serviceAccounts.delete"
            "iam.serviceAccounts.get"
            "iam.serviceAccounts.getIamPolicy"
            "iam.serviceAccounts.list"
            "iam.serviceAccounts.setIamPolicy"
            "iam.serviceAccounts.update"
            "iam.serviceAccountKeys.create"
            "iam.serviceAccountKeys.delete"
            "iam.serviceAccountKeys.get"
            "iam.serviceAccountKeys.list"
            
            # Resource Manager
            "resourcemanager.folders.get"
            "resourcemanager.folders.getIamPolicy"
            "resourcemanager.folders.list"
            "resourcemanager.folders.setIamPolicy"
            "resourcemanager.organizations.get"
            "resourcemanager.organizations.getIamPolicy"
            "resourcemanager.projects.create"
            "resourcemanager.projects.delete"
            "resourcemanager.projects.get"
            "resourcemanager.projects.getIamPolicy"
            "resourcemanager.projects.list"
            "resourcemanager.projects.setIamPolicy"
            "resourcemanager.projects.update"
            "resourcemanager.projects.createBillingAssignment"
            "resourcemanager.projects.deleteBillingAssignment"
            
            # Service Usage
            "serviceusage.quotas.get"
            "serviceusage.quotas.update"
            "serviceusage.services.enable"
            "serviceusage.services.get"
            "serviceusage.services.list"
            "serviceusage.services.disable"
            
            # Storage
            "storage.buckets.create"
            "storage.buckets.delete"
            "storage.buckets.get"
            "storage.buckets.getIamPolicy"
            "storage.buckets.list"
            "storage.buckets.setIamPolicy"
            "storage.buckets.update"
            "storage.objects.create"
            "storage.objects.delete"
            "storage.objects.get"
            "storage.objects.getIamPolicy"
            "storage.objects.list"
            "storage.objects.setIamPolicy"
            "storage.objects.update"

            # Cloud KMS
            "cloudkms.cryptoKeys.create"
            "cloudkms.cryptoKeys.get"
            "cloudkms.cryptoKeys.getIamPolicy"
            "cloudkms.cryptoKeys.list"
            "cloudkms.cryptoKeys.setIamPolicy"
            "cloudkms.cryptoKeys.update"
            "cloudkms.keyRings.create"
            "cloudkms.keyRings.delete"
            "cloudkms.keyRings.get"
            "cloudkms.keyRings.getIamPolicy"
            "cloudkms.keyRings.list"
            "cloudkms.keyRings.setIamPolicy"

            # Cloud SQL
            "cloudsql.instances.create"
            "cloudsql.instances.delete"
            "cloudsql.instances.get"
            "cloudsql.instances.list"
            "cloudsql.instances.update"
            "cloudsql.databases.create"
            "cloudsql.databases.delete"
            "cloudsql.databases.get"
            "cloudsql.databases.list"
            "cloudsql.databases.update"
            "cloudsql.users.create"
            "cloudsql.users.delete"
            "cloudsql.users.list"
            "cloudsql.users.update"

            # Cloud Run
            "run.services.create"
            "run.services.delete"
            "run.services.get"
            "run.services.getIamPolicy"
            "run.services.list"
            "run.services.setIamPolicy"
            "run.services.update"
            "run.revisions.delete"
            "run.revisions.get"
            "run.revisions.list"
            "run.revisions.tag"
            "run.routes.get"
            "run.routes.list"
            "run.routes.invoke"
            "run.configurations.get"
            "run.configurations.list"
            "run.locations.list"
            "run.operations.get"
            "run.operations.list"
            "run.jobs.create"
            "run.jobs.delete"
            "run.jobs.get"
            "run.jobs.list"
            "run.jobs.run"
            "run.jobs.update"
            "run.executions.get"
            "run.executions.list"
            "run.tasks.get"
            "run.tasks.list"
            "run.domains.create"
            "run.domains.delete"
            "run.domains.get"
            "run.domains.list"
            "run.domains.update"

            # Additional networking for Cloud Run and GKE
            "compute.networks.get"
            "compute.networks.list"
            "compute.networks.use"
            "compute.networks.useExternalIp"
            "compute.subnetworks.get"
            "compute.subnetworks.list"
            "compute.subnetworks.use"
            "compute.subnetworks.useExternalIp"
            "compute.addresses.get"
            "compute.addresses.list"
            "compute.addresses.use"
            "compute.globalAddresses.get"
            "compute.globalAddresses.list"
            "compute.globalAddresses.use"
            "compute.sslCertificates.create"
            "compute.sslCertificates.delete"
            "compute.sslCertificates.get"
            "compute.sslCertificates.list"
            "compute.targetHttpProxies.create"
            "compute.targetHttpProxies.delete"
            "compute.targetHttpProxies.get"
            "compute.targetHttpProxies.list"
            "compute.targetHttpProxies.update"
            "compute.targetHttpsProxies.create"
            "compute.targetHttpsProxies.delete"
            "compute.targetHttpsProxies.get"
            "compute.targetHttpsProxies.list"
            "compute.targetHttpsProxies.update"
            "compute.urlMaps.create"
            "compute.urlMaps.delete"
            "compute.urlMaps.get"
            "compute.urlMaps.list"
            "compute.urlMaps.update"
        )
    fi

    # Check for testing permissions
    local testing_perms=($(check_testing_permissions "${permissions[@]}"))
    local final_permissions=("${permissions[@]}")

    # Display confirmation screen
    echo "\n=== Role Creation Confirmation ==="
    echo "--------------------------------"
    echo "\nRole Details:"
    echo "  Service: $service"
    echo "  Role Name: $role_name"
    if [[ -n "$org_id" ]]; then
        echo "  Location: Organization Level (org_id: $org_id)"
        echo "  Full Role Path: organizations/$org_id/roles/$role_name"
    else
        echo "  Location: Project Level (project_id: $project_id)"
        echo "  Full Role Path: projects/$project_id/roles/$role_name"
        
        # Warning for project-level terraform roles
        if [[ "$service" == "terraform" ]]; then
            echo "\n⚠️  WARNING: Project-Level Role ⚠️"
            echo "Creating Terraform roles at the project level is not recommended."
            echo "It's better to create them at the organization level for broader access control."
            echo "This ensures consistent management across all projects."
        fi
    fi

    # Show testing permissions warning if any exist
    if [[ ${#testing_perms[@]} -gt 0 ]]; then
        echo "\n⚠️  WARNING: Testing Permissions ⚠️"
        echo "The following permissions are in TESTING stage and may be removed in the future:"
        printf "  - %s\n" "${testing_perms[@]}"
    fi

    echo "\nPermissions Summary:"
    echo "-------------------"
    echo "Total permissions: ${#permissions[@]}"
    if [[ ${#testing_perms[@]} -gt 0 ]]; then
        echo "Testing permissions: ${#testing_perms[@]}"
        echo "Non-testing permissions: $((${#permissions[@]} - ${#testing_perms[@]}))"
    fi

    echo "\nPermissions Table:"
    echo "----------------"
    display_permissions_table "${permissions[@]}"
    
    # Consolidated confirmation with all options
    local -a confirm_options
    if [[ ${#testing_perms[@]} -gt 0 ]]; then
        confirm_options=(
            "Create role with all permissions (including TESTING permissions)"
            "Create role without TESTING permissions"
            "Cancel operation"
        )
    else
        confirm_options=(
            "Create role with specified permissions"
            "Cancel operation"
        )
    fi
    
    echo "\nDo you want to proceed?"
    show_selection_menu "Select an option:" "${confirm_options[@]}"
    local confirm=$?
    
    # Handle selection based on the number of options
    if [[ ${#testing_perms[@]} -gt 0 ]]; then
        case $confirm in
            1)  # Proceed with all permissions
                echo "\nProceeding with all permissions (including ${#testing_perms[@]} testing permissions)..."
                ;;
            2)  # Exclude testing permissions
                echo "\nRemoving ${#testing_perms[@]} testing permissions..."
                # Remove testing permissions from the array
                for test_perm in "${testing_perms[@]}"; do
                    final_permissions=(${final_permissions[@]:#$test_perm})
                done
                echo "Proceeding with ${#final_permissions[@]} non-testing permissions."
                ;;
            3)  # Cancel operation
                echo "Operation cancelled"
                return 1
                ;;
        esac
    else
        case $confirm in
            1)  # Proceed with permissions
                echo "\nProceeding with ${#final_permissions[@]} permissions..."
                ;;
            2)  # Cancel operation
                echo "Operation cancelled"
                return 1
                ;;
        esac
    fi

    # Create the role with final permissions
    create_role_with_testing_check "$role_name" "$org_id" "$project_id" "${final_permissions[@]}"
    return $?
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

# Function to describe an IAM role in a specific project
function gcloud-util() {
    debug_log "Initial args: $*"

    # Handle no arguments
    if [[ $# -eq 0 ]]; then
        show_main_help
        return 0
    fi

    # Handle main help
    if [[ "$1" == "help" || "$1" == "--help" ]]; then
        show_main_help
        return 0
    fi

    # Get command
    local command="$1"
    shift

    # Handle command help
    if [[ $# -eq 0 || "$1" == "help" || "$1" == "--help" ]]; then
        case "$command" in
            iam)
                show_iam_help
                return 0
                ;;
            projects)
                show_projects_help
                return 0
                ;;
            *)
                show_main_help
                return 0
                ;;
        esac
    fi

    # Get subcommand
    local subcommand="$1"
    shift

    # Handle subcommand help
    if [[ $# -gt 0 && "$1" == "help" ]]; then
        case "$command" in
            iam)
                case "$subcommand" in
                    create-role)
                        show_create_role_help
                        return 0
                        ;;
                    merge-roles)
                        show_merge_roles_help
                        return 0
                        ;;
                    *)
                        show_iam_help
                        return 0
                    ;;
                esac
                ;;
            projects)
                case "$subcommand" in
                    list)
                        show_projects_list_help
                        return 0
                        ;;
                esac
                ;;
        esac
    fi

    # Process commands
    case "$command" in
        iam)
            case "$subcommand" in
                create-role)
                    create_role "$@"
                    ;;
                merge-roles)
                    merge_roles "$@"
                    ;;
                *)
                    echo "Error: Unknown subcommand: $subcommand"
                    echo "Run 'gcloud-util iam help' for available subcommands"
                    return 1
                    ;;
            esac
            ;;
        projects)
            case "$subcommand" in
                list)
                    # TODO: Implement projects list functionality
                    ;;
                *)
                    echo "Error: Unknown subcommand: $subcommand"
                    echo "Run 'gcloud-util projects help' for available subcommands"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo "Error: Unknown command: $command"
            echo "Run 'gcloud-util help' for available commands"
            return 1
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

