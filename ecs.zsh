ecs_exec() {
  show_help() {
    echo "Usage: ecs_exec <staging|production> [--cluster <custom-cluster>] [--container <custom-container>]"
    echo ""
    echo "Executes an interactive shell inside an ECS container."
    echo ""
    echo "Arguments:"
    echo "  staging | production       Sets the cluster and container name based on environment."
    echo "  --cluster <custom-cluster> Overrides the default cluster name."
    echo "  --container <custom-container> Overrides the default container name."
    echo "  --help, -h                 Show this help message."
    return 0
  }

  if [[ $# -eq 0 || "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    return 0
  fi

  local CLUSTER_NAME=""
  local CONTAINER_NAME=""
  local SERVICE_NAME=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      staging|production)
        CLUSTER_NAME="${1}-backend-ecs-cluster"
        SERVICE_NAME="${1}-backend-service-api"  # Set the service name dynamically
        CONTAINER_NAME="${1}-backend-container-api"  # Default container
        shift
        ;;
      --cluster)
        CLUSTER_NAME="$2"
        shift 2
        ;;
      --container)
        CONTAINER_NAME="$2"
        shift 2
        ;;
      *)
        echo "Error: Invalid argument '$1'"
        show_help
        return 1
        ;;
    esac
  done

  if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Error: Cluster name must be specified either via environment (staging|production) or --cluster flag."
    show_help
    return 1
  fi

  # Get the task ARN for the given service
  local TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --desired-status RUNNING --query "taskArns[0]" --output text)

  if [[ -z "$TASK_ARN" || "$TASK_ARN" == "None" ]]; then
    echo "No running tasks found for service: $SERVICE_NAME in cluster: $CLUSTER_NAME"
    return 1
  fi

  # Auto-detect the correct container name if not provided
  if [[ -z "$CONTAINER_NAME" ]]; then
    CONTAINER_NAME="${1}-backend-container-api"  # Default container if not passed explicitly
  fi

  # Verify that a container was found, otherwise list available containers
  if [[ -z "$CONTAINER_NAME" || "$CONTAINER_NAME" == "None" ]]; then
    echo "Error: No valid container found in task: $TASK_ARN"
    echo "Fetching available containers..."

    local CONTAINERS=($(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --query "tasks[0].containers[*].name" --output text))

    if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
      echo "No containers found for this task. Exiting."
      return 1
    fi

    echo "Available containers:"
    select CONTAINER_NAME in "${CONTAINERS[@]}"; do
      if [[ -n "$CONTAINER_NAME" ]]; then
        break
      else
        echo "Invalid selection. Please try again."
      fi
    done
  fi

  # Display the command that will be run for debugging purposes
  echo "Running command: aws ecs execute-command --cluster \"$CLUSTER_NAME\" --task \"$TASK_ARN\" --container \"$CONTAINER_NAME\" --command /bin/bash --interactive"

  # Execute into the container
  aws ecs execute-command \
    --cluster "$CLUSTER_NAME" \
    --task "$TASK_ARN" \
    --container "$CONTAINER_NAME" \
    --command /bin/bash \
    --interactive

  # If the command fails, display it for debugging purposes
  if [[ $? -ne 0 ]]; then
    echo "Error: The command failed. Here's the command that was attempted:"
    echo "aws ecs execute-command --cluster \"$CLUSTER_NAME\" --task \"$TASK_ARN\" --container \"$CONTAINER_NAME\" --command /bin/bash --interactive"
  fi
}
