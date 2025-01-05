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
    echo "  help           - Show this help message"
    echo "\nUsage:"
    echo "  gcloud-util <command> [subcommand] [options]"
    echo "\nGet detailed help:"
    echo "  gcloud-util help           - Show this help"
    echo "  gcloud-util <command> help - Show help for a specific command"
    echo "\nExamples:"
    echo "  gcloud-util iam help"
    echo "  gcloud-util iam describe-role --help"
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
    # Get all projects in the organization, extract just the project IDs
    gcloud projects list --filter="parent.id=$org_id" --format="value(projectId)"
}

# Helper function to execute command across org and projects
function execute_all_scope() {
    local org_id=$1
    local cmd_type=$2
    local output=$3
    local extra_args=$4

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
    local projects=($(get_org_projects "$org_id"))
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
                        execute_all_scope "$org_id" "describe-role" "$output" "$role"
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
                        execute_all_scope "$org_id" "list-users" "$output"
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
                        execute_all_scope "$org_id" "describe-user" "$output" "$user"
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
        *)
            echo "Error: Unknown command: $command"
            echo "Available commands: iam, help"
            echo "Use 'gcloud-util help' for more information"
            return 1
            ;;
    esac
}
