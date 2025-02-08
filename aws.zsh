cf-wait() {
    # Usage: cf-wait <STACK_NAME> <COMMAND_TO_ISSUE_AFTER>
    if [ $# -lt 2 ]; then
        echo "Usage: cf-wait <STACK_NAME> <COMMAND_TO_ISSUE_AFTER>"
        return 1
    fi

    local STACK_NAME=$1
    shift  # Remove the first argument (stack name)
    local COMMAND="$@"

    local TERMINAL_STATES=("UPDATE_ROLLBACK_COMPLETE" "ROLLBACK_COMPLETE")
    local INTERVAL=10  # Polling interval in seconds

    echo "Waiting for stack '$STACK_NAME' to exit UPDATE_ROLLBACK_IN_PROGRESS..."

    while true; do
        # Get the current stack status
        STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
            --query "Stacks[0].StackStatus" --output text)

        echo "Current status: $STATUS"

        # Check if the stack is in a terminal state
        if [[ " ${TERMINAL_STATES[@]} " =~ " ${STATUS} " ]]; then
            echo "Stack has reached a terminal state: $STATUS"
            break
        elif [[ $STATUS == *_FAILED ]]; then
            echo "Stack entered a failure state: $STATUS"
            return 1
        fi

        # Sleep for the polling interval
        sleep $INTERVAL
    done

    # Execute the command after the stack is ready
    echo "Executing command: $COMMAND"
    eval "$COMMAND"
}
