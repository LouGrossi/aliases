# Define the function without running it immediately
py_init() {
    # Positional argument #1 is the application to run
    APP="$1"
    if [[ -z "$APP" ]]; then
        echo "Usage: py_init <application>"
        return 1
    fi

    # Detect package manager from history
    PKG_MANAGER=""
    if history | grep -q "pipenv"; then
        PKG_MANAGER="pipenv"
    elif history | grep -q "poetry"; then
        PKG_MANAGER="poetry"
    elif history | grep -q "virtualenv"; then
        PKG_MANAGER="virtualenv"
    else
        echo "No package manager detected in history. Please use pipenv, poetry, or virtualenv."
        return 1
    fi

    echo "Detected package manager: $PKG_MANAGER"

    # Ensure virtual environment exists
    if [[ "$PKG_MANAGER" == "pipenv" ]]; then
        if ! pipenv --venv &>/dev/null; then
            read -p "No virtual environment found. Create one? (y/n): " CONFIRM
            if [[ "$CONFIRM" == "y" ]]; then
                pipenv install  # This will create a virtualenv if none exists
            else
                echo "Please create a virtual environment and re-run py_init."
                return 1
            fi
        fi
        pipenv shell  # Only activate if not already activated

    elif [[ "$PKG_MANAGER" == "poetry" ]]; then
        if ! poetry env info &>/dev/null; then
            read -p "No virtual environment found. Create one? (y/n): " CONFIRM
            if [[ "$CONFIRM" == "y" ]]; then
                poetry install  # This will create a virtualenv if none exists
            else
                echo "Please create a virtual environment and re-run py_init."
                return 1
            fi
        fi
        poetry shell  # Only activate if not already activated

    elif [[ "$PKG_MANAGER" == "virtualenv" ]]; then
        if [[ ! -d ".venv" && -z "$VIRTUAL_ENV" ]]; then
            read -p "No virtual environment found. Create one? (y/n): " CONFIRM
            if [[ "$CONFIRM" == "y" ]]; then
                virtualenv .venv && source .venv/bin/activate
            else
                echo "Please create a virtual environment and re-run py_init."
                return 1
            fi
        elif [[ -z "$VIRTUAL_ENV" ]]; then
            source .venv/bin/activate
        fi
    fi

    # Install missing dependencies and run the app in a loop
    while true; do
        if [[ "$PKG_MANAGER" == "pipenv" ]]; then
            pipenv install
        elif [[ "$PKG_MANAGER" == "poetry" ]]; then
            poetry install
        elif [[ "$PKG_MANAGER" == "virtualenv" ]]; then
            pip install -r requirements.txt
        fi

        OUTPUT=$("$APP" 2>&1)
        EXIT_CODE=$?

        if [[ $EXIT_CODE -eq 0 ]]; then
            break
        fi

        MISSING_PKG=$(echo "$OUTPUT" | grep -Eo "No module named '[^']+'" | cut -d"'" -f2)
        if [[ -n "$MISSING_PKG" ]]; then
            echo "Missing package detected: $MISSING_PKG. Installing..."
            if [[ "$PKG_MANAGER" == "pipenv" ]]; then
                pipenv install "$MISSING_PKG"
            elif [[ "$PKG_MANAGER" == "poetry" ]]; then
                poetry add "$MISSING_PKG"
            elif [[ "$PKG_MANAGER" == "virtualenv" ]]; then
                pip install "$MISSING_PKG"
                echo "$MISSING_PKG" >> requirements.txt
            fi
        else
            echo "Application failed with an unexpected error."
            break
        fi
    done
}
