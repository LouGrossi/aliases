#!/bin/zsh
# gcloud-util.zsh
# Author: Lou Grossi
# Company: ncdLabs
# Description: GCloud utility functions for managing GCP resources

# Source the output library
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/common/output.lib.zsh"

# Function to show main help
function show_main_help() {
    echo "GCloud Utility Tool - IAM Management"
    echo "\nAvailable commands:"
    echo "  iam             - IAM role and permission management"
    echo "  projects        - GCP projects management"
    echo "  backup          - Backup GCP resources"
    echo "  restore         - Restore GCP resources from backup"
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
    echo "  describe-role  - Get detailed information about a specific IAM role"
    echo "  describe-user  - Get detailed information about a specific IAM user"
    echo "  list-roles     - List all custom IAM roles in a project or organization"
    echo "  list-users     - List all IAM users in a project or organization"
    echo "  help          - Show this help message"
    echo "\nUsage:"
    echo "  gcloud-util iam <subcommand> [options]"
    echo "\nGet detailed help:"
    echo "  gcloud-util iam help                  - Show this help"
    echo "  gcloud-util iam <subcommand> --help   - Show help for a specific subcommand"
    echo "\nExamples:"
    echo "  gcloud-util iam describe-role --project-id my-project --role roles/editor"
    echo "  gcloud-util iam describe-role --org-id 123456789 --role roles/editor"
    echo "  gcloud-util iam list-roles --project-id my-project"
    echo "  gcloud-util iam describe-user --org-id 123456789 --user user@example.com"
    echo "  gcloud-util iam list-users --project-id my-project"
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

    echo "Executing on organization $org_id..."
    echo "----------------------------------------"
    case "$cmd_type" in
        "list-users")
            format_gcloud_output "gcloud organizations get-iam-policy \"$org_id\" --flatten=\"bindings[].members\" --filter=\"bindings.members~'user:|serviceAccount:'\"" "$output" "bindings.members,bindings.role"
            ;;
        "list-roles")
            format_gcloud_output "gcloud iam roles list --organization=\"$org_id\"" "$output"
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
                format_gcloud_output "gcloud projects get-iam-policy \"$project\" --flatten=\"bindings[].members\" --filter=\"bindings.members~'user:|serviceAccount:'\"" "$output" "bindings.members,bindings.role"
                ;;
            "list-roles")
                format_gcloud_output "gcloud iam roles list --project=\"$project\"" "$output"
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

# Function to describe an IAM role in a specific project
function gcloud-util() {
    local command=$1
    local subcommand=$2

    # Show main help if no arguments provided
    if [[ $# -eq 0 ]] || [[ "$1" == "help" ]] || [[ "$1" == "--help" ]]; then
        show_main_help
        return 0
    fi

    case "$command" in
        "projects")
            # Show help if no subcommand provided or help requested
            if [[ $# -eq 1 ]] || [[ "$2" == "help" ]] || [[ "$2" == "--help" ]]; then
                show_projects_help
                return 0
            fi

            case "$subcommand" in
                "list")
                    # Show help if requested
                    if [[ "$3" == "--help" ]] || [[ "$3" == "help" ]]; then
                        show_projects_list_help
                        return 0
                    fi

                    local output=""
                    local all_flag=""
                    
                    # Parse arguments
                    while [[ $# -gt 2 ]]; do
                        case "$3" in
                            --output)
                                output="$4"
                                shift 2
                                ;;
                            --all)
                                all_flag="true"
                                shift 1
                                ;;
                            *)
                                echo "Error: Unknown option: $3"
                                echo "Use 'gcloud-util projects list help' for usage information"
                                return 1
                                ;;
                        esac
                    done

                    # Validate output format if specified
                    if ! validate_output_format "$output"; then
                        return 1
                    fi

                    # Execute the command with or without filter
                    local cmd
                    if [[ -n "$all_flag" ]]; then
                        cmd="gcloud projects list"
                    else
                        cmd="gcloud projects list --filter=\"NOT projectId:(sys-*)\""
                    fi
                    if [[ -n "$output" ]]; then
                        format_gcloud_output "$cmd" "$output" "projectId,name,projectNumber"
                    else
                        format_gcloud_output "$cmd" "table" "projectId,name,projectNumber"
                    fi
                    ;;

                *)
                    echo "Error: Unknown projects subcommand: $subcommand"
                    echo "Available subcommands: list, help"
                    echo "Use 'gcloud-util projects help' for more information"
                    return 1
                    ;;
            esac
            ;;
        "iam")
            # Show IAM help if no subcommand provided or help requested
            if [[ $# -eq 1 ]] || [[ "$2" == "help" ]] || [[ "$2" == "--help" ]]; then
                show_iam_help
                return 0
            fi

            case "$subcommand" in
                "describe-role")
                    # Show help text if requested
                    if [[ "$3" == "--help" ]] || [[ "$3" == "help" ]]; then
                        echo "Description:"
                        echo "  Retrieves detailed information about a specific IAM role in a GCP project or organization"
                        echo "  This includes permissions, stage (GA/BETA/ALPHA), and other role metadata"
                        echo "\nUsage:"
                        echo "  gcloud-util iam describe-role (--project-id PROJECT_ID | --org-id ORG_ID | --all ORG_ID) --role ROLE_NAME [--output FORMAT]"
                        echo "\nRequired Parameters:"
                        echo "  One of the following must be specified:"
                        echo "    --project-id PROJECT_ID   : The Google Cloud Project ID"
                        echo "    --org-id ORG_ID          : The Google Cloud Organization ID"
                        echo "    --all ORG_ID             : Execute on organization and all its projects"
                        echo "  And:"
                        echo "    --role ROLE_NAME         : The name of the role to describe (e.g., 'roles/editor')"
                        echo "\nOptional Parameters:"
                        add_output_format_help
                        echo "\nExamples:"
                        echo "  gcloud-util iam describe-role --project-id my-project --role roles/editor"
                        echo "  gcloud-util iam describe-role --org-id 123456789 --role roles/editor"
                        echo "  gcloud-util iam describe-role --all 123456789 --role roles/editor --output json"
                        return 0
                    fi

                    local project=""
                    local organization=""
                    local all_org=""
                    local role=""
                    local output=""

                    # Parse arguments
                    while [[ $# -gt 2 ]]; do
                        case "$3" in
                            --project-id)
                                project="$4"
                                shift 2
                                ;;
                            --org-id)
                                organization="$4"
                                shift 2
                                ;;
                            --all)
                                if [[ -n "$4" && "$4" != -* ]]; then
                                    all_org="$4"
                                    shift 2
                                else
                                    all_org="auto"
                                    shift 1
                                fi
                                ;;
                            --role)
                                role="$4"
                                shift 2
                                ;;
                            --output)
                                output="$4"
                                shift 2
                                ;;
                            *)
                                echo "Error: Unknown option: $3"
                                echo "Use 'gcloud-util iam describe-role help' for usage information"
                                return 1
                                ;;
                        esac
                    done

                    # Validate output format if specified
                    if ! validate_output_format "$output"; then
                        return 1
                    fi

                    # Validate required parameters
                    local param_count=0
                    [[ -n "$project" ]] && ((param_count++))
                    [[ -n "$organization" ]] && ((param_count++))
                    [[ -n "$all_org" ]] && ((param_count++))

                    if [[ $param_count -ne 1 ]]; then
                        echo "Error: Exactly one of --project-id, --org-id, or --all must be specified"
                        echo "Use 'gcloud-util iam describe-role help' for usage information"
                        return 1
                    fi

                    if [[ -z "$role" ]]; then
                        echo "Error: --role parameter is required"
                        echo "Use 'gcloud-util iam describe-role help' for usage information"
                        return 1
                    fi

                    # Execute the command
                    if [[ -n "$all_org" ]]; then
                        local org_id="$all_org"
                        if [[ "$all_org" == "auto" ]]; then
                            org_id=$(get_default_org)
                            if [[ $? -ne 0 ]]; then
                                return 1
                            fi
                        fi
                        execute_all_scope "$org_id" "describe-role" "$output" "$role" "true"
                    else
                        local cmd=""
                        if [[ -n "$project" ]]; then
                            cmd="gcloud iam roles describe \"$role\" --project=\"$project\""
                        else
                            cmd="gcloud iam roles describe \"$role\" --organization=\"$organization\""
                        fi
                        format_gcloud_output "$cmd" "$output"
                    fi
                    ;;

                "list-roles")
                    # Show help text if requested
                    if [[ "$3" == "--help" ]] || [[ "$3" == "help" ]]; then
                        echo "Description:"
                        echo "  Lists all custom IAM roles defined in a GCP project or organization"
                        echo "  This includes both custom roles and predefined roles available"
                        echo "\nUsage:"
                        echo "  gcloud-util iam list-roles (--project-id PROJECT_ID | --org-id ORG_ID) [--output FORMAT]"
                        echo "\nRequired Parameters (one of):"
                        echo "  --project-id PROJECT_ID   : The Google Cloud Project ID"
                        echo "  --org-id ORG_ID          : The Google Cloud Organization ID"
                        echo "  --all ORG_ID             : Execute on organization and all its projects"
                        echo "\nOptional Parameters:"
                        add_output_format_help
                        echo "\nExamples:"
                        echo "  gcloud-util iam list-roles --project-id my-project"
                        echo "  gcloud-util iam list-roles --org-id 123456789 --output yaml"
                        return 0
                    fi

                    local project=""
                    local organization=""
                    local all_org=""
                    local output=""

                    # Parse arguments
                    while [[ $# -gt 2 ]]; do
                        case "$3" in
                            --project-id)
                                project="$4"
                                shift 2
                                ;;
                            --org-id)
                                organization="$4"
                                shift 2
                                ;;
                            --all)
                                if [[ -n "$4" && "$4" != -* ]]; then
                                    all_org="$4"
                                    shift 2
                                else
                                    all_org="auto"
                                    shift 1
                                fi
                                ;;
                            --output)
                                output="$4"
                                shift 2
                                ;;
                            *)
                                echo "Error: Unknown option: $3"
                                echo "Use 'gcloud-util iam list-roles help' for usage information"
                                return 1
                                ;;
                        esac
                    done

                    # Validate output format if specified
                    if ! validate_output_format "$output"; then
                        return 1
                    fi

                    # Validate required parameters
                    local param_count=0
                    [[ -n "$project" ]] && ((param_count++))
                    [[ -n "$organization" ]] && ((param_count++))
                    [[ -n "$all_org" ]] && ((param_count++))

                    if [[ $param_count -ne 1 ]]; then
                        echo "Error: Exactly one of --project-id, --org-id, or --all must be specified"
                        echo "Use 'gcloud-util iam list-roles help' for usage information"
                        return 1
                    fi

                    # Execute the command
                    if [[ -n "$all_org" ]]; then
                        local org_id="$all_org"
                        if [[ "$all_org" == "auto" ]]; then
                            org_id=$(get_default_org)
                            if [[ $? -ne 0 ]]; then
                                return 1
                            fi
                        fi
                        execute_all_scope "$org_id" "list-roles" "$output"
                    else
                        local cmd=""
                        if [[ -n "$project" ]]; then
                            cmd="gcloud iam roles list --project=\"$project\""
                        else
                            cmd="gcloud iam roles list --organization=\"$organization\""
                        fi
                        format_gcloud_output "$cmd" "$output"
                    fi
                    ;;

                "list-users")
                    # Show help text if requested
                    if [[ "$3" == "--help" ]] || [[ "$3" == "help" ]]; then
                        echo "Description:"
                        echo "  Lists all IAM users and their roles in a GCP project or organization"
                        echo "  This includes service accounts and user accounts with their associated roles"
                        echo "\nUsage:"
                        echo "  gcloud-util iam list-users (--project-id PROJECT_ID | --org-id ORG_ID | --all ORG_ID) [--output FORMAT]"
                        echo "\nRequired Parameters (one of):"
                        echo "  --project-id PROJECT_ID   : The Google Cloud Project ID"
                        echo "  --org-id ORG_ID          : The Google Cloud Organization ID"
                        echo "  --all ORG_ID             : Execute on organization and all its projects"
                        echo "\nOptional Parameters:"
                        add_output_format_help
                        echo "\nExamples:"
                        echo "  gcloud-util iam list-users --project-id my-project"
                        echo "  gcloud-util iam list-users --org-id 123456789"
                        echo "  gcloud-util iam list-users --all 123456789 --output table"
                        return 0
                    fi

                    local project=""
                    local organization=""
                    local all_org=""
                    local output=""

                    # Parse arguments
                    while [[ $# -gt 2 ]]; do
                        case "$3" in
                            --project-id)
                                project="$4"
                                shift 2
                                ;;
                            --org-id)
                                organization="$4"
                                shift 2
                                ;;
                            --all)
                                if [[ -n "$4" && "$4" != -* ]]; then
                                    all_org="$4"
                                    shift 2
                                else
                                    all_org="auto"
                                    shift 1
                                fi
                                ;;
                            --output)
                                output="$4"
                                shift 2
                                ;;
                            *)
                                echo "Error: Unknown option: $3"
                                echo "Use 'gcloud-util iam list-users help' for usage information"
                                return 1
                                ;;
                        esac
                    done

                    # Validate output format if specified
                    if ! validate_output_format "$output"; then
                        return 1
                    fi

                    # Validate required parameters
                    local param_count=0
                    [[ -n "$project" ]] && ((param_count++))
                    [[ -n "$organization" ]] && ((param_count++))
                    [[ -n "$all_org" ]] && ((param_count++))

                    if [[ $param_count -ne 1 ]]; then
                        echo "Error: Exactly one of --project-id, --org-id, or --all must be specified"
                        echo "Use 'gcloud-util iam list-users help' for usage information"
                        return 1
                    fi

                    # Execute the command
                    if [[ -n "$all_org" ]]; then
                        local org_id="$all_org"
                        if [[ "$all_org" == "auto" ]]; then
                            org_id=$(get_default_org)
                            if [[ $? -ne 0 ]]; then
                                return 1
                            fi
                        fi
                        execute_all_scope "$org_id" "list-users" "$output" "" "true"
                    else
                        local cmd=""
                        if [[ -n "$project" ]]; then
                            cmd="gcloud projects get-iam-policy \"$project\" --flatten=\"bindings[].members\" --filter=\"bindings.members~'user:|serviceAccount:'\""
                        else
                            cmd="gcloud organizations get-iam-policy \"$organization\" --flatten=\"bindings[].members\" --filter=\"bindings.members~'user:|serviceAccount:'\""
                        fi
                        format_gcloud_output "$cmd" "$output" "bindings.members,bindings.role"
                    fi
                    ;;

                "describe-user")
                    # Show help text if requested
                    if [[ "$3" == "--help" ]] || [[ "$3" == "help" ]]; then
                        echo "Description:"
                        echo "  Retrieves detailed information about a specific IAM user in a GCP project or organization"
                        echo "  This includes all roles and permissions assigned to the user"
                        echo "\nUsage:"
                        echo "  gcloud-util iam describe-user (--project-id PROJECT_ID | --org-id ORG_ID | --all ORG_ID) --user USER_EMAIL [--output FORMAT]"
                        echo "\nRequired Parameters:"
                        echo "  One of the following must be specified:"
                        echo "    --project-id PROJECT_ID   : The Google Cloud Project ID"
                        echo "    --org-id ORG_ID          : The Google Cloud Organization ID"
                        echo "    --all ORG_ID             : Execute on organization and all its projects"
                        echo "  And:"
                        echo "    --user USER_EMAIL        : The email address of the user (e.g., 'user@example.com')"
                        echo "\nOptional Parameters:"
                        add_output_format_help
                        echo "\nExamples:"
                        echo "  gcloud-util iam describe-user --project-id my-project --user user@example.com"
                        echo "  gcloud-util iam describe-user --org-id 123456789 --user user@example.com"
                        echo "  gcloud-util iam describe-user --all 123456789 --user user@example.com --output yaml"
                        return 0
                    fi

                    local project=""
                    local organization=""
                    local all_org=""
                    local user=""
                    local output=""

                    # Parse arguments
                    while [[ $# -gt 2 ]]; do
                        case "$3" in
                            --project-id)
                                project="$4"
                                shift 2
                                ;;
                            --org-id)
                                organization="$4"
                                shift 2
                                ;;
                            --all)
                                if [[ -n "$4" && "$4" != -* ]]; then
                                    all_org="$4"
                                    shift 2
                                else
                                    all_org="auto"
                                    shift 1
                                fi
                                ;;
                            --user)
                                user="$4"
                                shift 2
                                ;;
                            --output)
                                output="$4"
                                shift 2
                                ;;
                            *)
                                echo "Error: Unknown option: $3"
                                echo "Use 'gcloud-util iam describe-user help' for usage information"
                                return 1
                                ;;
                        esac
                    done

                    # Validate output format if specified
                    if ! validate_output_format "$output"; then
                        return 1
                    fi

                    # Validate required parameters
                    local param_count=0
                    [[ -n "$project" ]] && ((param_count++))
                    [[ -n "$organization" ]] && ((param_count++))
                    [[ -n "$all_org" ]] && ((param_count++))

                    if [[ $param_count -ne 1 ]]; then
                        echo "Error: Exactly one of --project-id, --org-id, or --all must be specified"
                        echo "Use 'gcloud-util iam describe-user help' for usage information"
                        return 1
                    fi

                    if [[ -z "$user" ]]; then
                        echo "Error: --user parameter is required"
                        echo "Use 'gcloud-util iam describe-user help' for usage information"
                        return 1
                    fi

                    # Execute the command
                    if [[ -n "$all_org" ]]; then
                        local org_id="$all_org"
                        if [[ "$all_org" == "auto" ]]; then
                            org_id=$(get_default_org)
                            if [[ $? -ne 0 ]]; then
                                return 1
                            fi
                        fi
                        execute_all_scope "$org_id" "describe-user" "$output" "$user" "true"
                    else
                        local cmd=""
                        if [[ -n "$project" ]]; then
                            cmd="gcloud projects get-iam-policy \"$project\" --flatten=\"bindings[].members\" --filter=\"bindings.members:$user\""
                        else
                            cmd="gcloud organizations get-iam-policy \"$organization\" --flatten=\"bindings[].members\" --filter=\"bindings.members:$user\""
                        fi
                        format_gcloud_output "$cmd" "$output" "bindings.role"
                    fi
                    ;;

                *)
                    echo "Error: Unknown IAM subcommand: $subcommand"
                    echo "Available subcommands: describe-role, describe-user, list-roles, list-users, help"
                    echo "Use 'gcloud-util iam help' for more information"
                    return 1
                    ;;
            esac
            ;;
        "backup")
            # Show backup help if no subcommand provided or help requested
            if [[ $# -eq 1 ]] || [[ "$2" == "help" ]] || [[ "$2" == "--help" ]]; then
                show_backup_help
                return 0
            fi

            case "$subcommand" in
                "iam")
                    # Show help if requested
                    if [[ "$3" == "--help" ]] || [[ "$3" == "help" ]]; then
                        show_backup_iam_help
                        return 0
                    fi

                    local user=""
                    local output_dir=""
                    local project=""
                    local organization=""
                    local all_org=""

                    # Parse arguments
                    while [[ $# -gt 2 ]]; do
                        case "$3" in
                            --project-id)
                                project="$4"
                                shift 2
                                ;;
                            --org-id)
                                organization="$4"
                                shift 2
                                ;;
                            --all)
                                if [[ -n "$4" && "$4" != -* ]]; then
                                    all_org="$4"
                                    shift 2
                                else
                                    all_org="auto"
                                    shift 1
                                fi
                                ;;
                            --user)
                                user="$4"
                                shift 2
                                ;;
                            --output-dir)
                                output_dir="$4"
                                shift 2
                                ;;
                            *)
                                echo "Error: Unknown option: $3"
                                echo "Use 'gcloud-util backup iam help' for usage information"
                                return 1
                                ;;
                        esac
                    done

                    # Validate required parameters
                    local param_count=0
                    [[ -n "$project" ]] && ((param_count++))
                    [[ -n "$organization" ]] && ((param_count++))
                    [[ -n "$all_org" ]] && ((param_count++))

                    if [[ $param_count -ne 1 ]]; then
                        echo "Error: Exactly one of --project-id, --org-id, or --all must be specified"
                        echo "Use 'gcloud-util backup iam help' for usage information"
                        return 1
                    fi

                    if [[ -z "$user" ]]; then
                        echo "Error: --user parameter is required"
                        echo "Use 'gcloud-util backup iam help' for usage information"
                        return 1
                    fi

                    # Create backup directory
                    local backup_dir=$(create_backup_dir "backup" "iam/user" "$user" "$output_dir")
                    if [[ $? -ne 0 ]]; then
                        return 1
                    fi

                    echo "Creating IAM backup for user: $user"
                    echo "Backup directory: $backup_dir"

                    # Handle different scopes
                    if [[ -n "$all_org" ]]; then
                        local org_id="$all_org"
                        if [[ "$all_org" == "auto" ]]; then
                            org_id=$(get_default_org)
                            if [[ $? -ne 0 ]]; then
                                return 1
                            fi
                        fi
                        # Backup organization roles
                        echo "Backing up organization roles..."
                        gcloud organizations get-iam-policy "$org_id" \
                            --flatten="bindings[].members" \
                            --filter="bindings.members:$user" \
                            --format="json" > "$backup_dir/org_roles.json"

                        # Backup project roles
                        echo "Backing up project roles..."
                        local projects=($(get_org_projects "$org_id" "true"))
                        for project in $projects; do
                            echo "Processing project: $project"
                            gcloud projects get-iam-policy "$project" \
                                --flatten="bindings[].members" \
                                --filter="bindings.members:$user" \
                                --format="json" > "$backup_dir/project_${project}_roles.json"
                        done
                    elif [[ -n "$organization" ]]; then
                        # Backup organization roles only
                        echo "Backing up organization roles..."
                        gcloud organizations get-iam-policy "$organization" \
                            --flatten="bindings[].members" \
                            --filter="bindings.members:$user" \
                            --format="json" > "$backup_dir/org_roles.json"
                    else
                        # Backup single project roles
                        echo "Backing up project roles..."
                        gcloud projects get-iam-policy "$project" \
                            --flatten="bindings[].members" \
                            --filter="bindings.members:$user" \
                            --format="json" > "$backup_dir/project_${project}_roles.json"
                    fi

                    echo "Backup completed successfully!"
                    echo "Backup location: $backup_dir"
                    echo "To restore, use: gcloud-util restore --dir $backup_dir"
                    ;;

                *)
                    echo "Error: Unknown backup subcommand: $subcommand"
                    echo "Available subcommands: iam, help"
                    echo "Use 'gcloud-util backup help' for more information"
                    return 1
                    ;;
            esac
            ;;
        "restore")
            # Show help if requested
            if [[ "$1" == "help" ]] || [[ "$1" == "--help" ]]; then
                show_restore_help
                return 0
            fi

            local backup_dir=""
            local backup_file=""

            # Parse arguments
            while [[ $# -gt 1 ]]; do
                case "$2" in
                    --dir)
                        backup_dir="$3"
                        shift 2
                        ;;
                    --file)
                        backup_file="$3"
                        shift 2
                        ;;
                    *)
                        echo "Error: Unknown option: $2"
                        echo "Use 'gcloud-util restore help' for usage information"
                        return 1
                        ;;
                esac
            done

            # Validate parameters
            if [[ -z "$backup_dir" && -z "$backup_file" ]]; then
                echo "Error: Either --dir or --file must be specified"
                echo "Use 'gcloud-util restore help' for usage information"
                return 1
            fi

            if [[ -n "$backup_dir" && -n "$backup_file" ]]; then
                echo "Error: Cannot specify both --dir and --file"
                echo "Use 'gcloud-util restore help' for usage information"
                return 1
            fi

            # Handle directory restore
            if [[ -n "$backup_dir" ]]; then
                if [[ ! -d "$backup_dir" ]]; then
                    echo "Error: Directory not found: $backup_dir"
                    return 1
                fi

                # Extract user email from directory name
                local user_part=$(basename "$backup_dir" | sed 's/\(.*\)_[0-9]\{8\}_[0-9]\{6\}/\1/')
                local user=${user_part/_at_/@}

                # Get organization ID
                local org_id=$(get_default_org)
                if [[ $? -ne 0 ]]; then
                    return 1
                fi

                echo "Restoring permissions for user: $user"
                
                # Process all backup files in directory
                for file in "$backup_dir"/*_roles.json; do
                    if [[ -f "$file" ]]; then
                        restore_from_file "$file" "$user" "$org_id"
                    fi
                done
            else
                # Handle single file restore
                if [[ ! -f "$backup_file" ]]; then
                    echo "Error: File not found: $backup_file"
                    return 1
                fi

                # Get organization ID if needed
                local org_id=""
                if [[ "$backup_file" == *"org_roles.json" ]]; then
                    org_id=$(get_default_org)
                    if [[ $? -ne 0 ]]; then
                        return 1
                    fi
                fi

                # Extract user email from directory path
                local dir_name=$(dirname "$backup_file")
                local user_part=$(basename "$dir_name" | sed 's/\(.*\)_[0-9]\{8\}_[0-9]\{6\}/\1/')
                local user=${user_part/_at_/@}

                restore_from_file "$backup_file" "$user" "$org_id"
            fi

            echo "Restore completed successfully!"
            ;;
        *)
            echo "Error: Unknown command: $command"
            echo "Available commands: iam, projects, backup, restore, help"
            echo "Use 'gcloud-util help' for more information"
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

