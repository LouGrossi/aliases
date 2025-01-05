# Helper function to run unison with appropriate flags
run_unison() {
  local profile="$1"
  local cmd="$UNISON_PATH $profile -batch -prefer newer -times -perms 0 -auto -ui text -fastcheck true -servercmd \"$UNISON_PATH\""
  
  if [ "$debug" = true ]; then
    cmd="$cmd -debug all"
  fi
  
  if [ "$force" = true ]; then
    cmd="$cmd -force newer"
  fi
  
  eval "$cmd"
}

# Function to show bootstrap usage
show_bootstrap_usage() {
  cat << EOF
Usage: sync bootstrap [localhost|REMOTE_IP]

Bootstrap a local or remote system with sync requirements.

Arguments:
    localhost       Configure the local machine
    REMOTE_IP       IP address of the remote host to configure

Examples:
    sync bootstrap localhost
    sync bootstrap 192.168.1.10

This will:
    - Create necessary configuration
    - Install required packages
    - Set up directories
    - Install man pages
    - Configure shell environment
EOF
}

# Function to show main usage
show_usage() {
  local ips_string="${REMOTE_HOST_IPS[*]}"
  cat << EOF
SYNC(1)                          User Commands                          SYNC(1)

NAME
    sync - Synchronize directories between hosts using Unison

# ... rest of usage text ...
EOF
}

# Function to load ignore patterns
load_ignore_patterns() {
  local ignore_patterns=()
  if [[ -f "$IGNORE_FILE" ]]; then
    while IFS= read -r pattern || [[ -n "$pattern" ]]; do
      [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$pattern" ]] && continue
      ignore_patterns+=("ignore = $pattern")
    done < "$IGNORE_FILE"
  else
    # Default ignore patterns
    ignore_patterns=(
      "ignore = Path .git"
      # ... rest of ignore patterns ...
    )
  fi
  echo "${(j:\n:)ignore_patterns}"
}

# Function to manage config location
manage_config_location() {
  local action="$1"
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sync"
  local config_file="$config_dir/config"
  local script_path="${(%):-%x}"
  
  case "$action" in
    "get")
      # Read the override location if it exists
      if [[ -f "$script_path.config_location" ]]; then
        cat "$script_path.config_location"
      else
        echo "$config_file"
      fi
      ;;
    "set")
      local new_location="$2"
      if [[ -z "$new_location" ]]; then
        echo "❌ Error: New config location not specified"
        return 1
      fi
      # Create directory if it doesn't exist
      mkdir -p "$(dirname "$new_location")"
      # Save the new location
      echo "$new_location" > "$script_path.config_location"
      # If old config exists and new location is different, offer to copy it
      local old_config="$config_file"
      if [[ -f "$old_config" && "$old_config" != "$new_location" ]]; then
        echo "Would you like to copy existing config from $old_config to $new_location? [y/N] "
        read -q response || true
        echo
        if [[ "$response" =~ ^[Yy]$ ]]; then
          mkdir -p "$(dirname "$new_location")"
          cp "$old_config" "$new_location"
          echo "✅ Config copied to new location"
        fi
      fi
      echo "✅ Config location updated to: $new_location"
      ;;
    "init")
      local target="${2:-$config_file}"
      mkdir -p "$(dirname "$target")"
      cat > "$target" << EOF
# sync configuration file

# Remote user configuration
SYNC_REMOTE_USER="lou"
SYNC_REMOTE_IPS="192.168.1.5,192.168.1.6,192.168.1.7"

# Unison configuration
SYNC_UNISON_PATH="/opt/homebrew/bin/unison"
SYNC_UNISON_PREF_DIR="\$HOME/.unison"

# Directory paths
SYNC_GIT_PATH="\$HOME/git"
SYNC_ALIASES_PATH="\$HOME/.config/lib"
SYNC_DOTFILES_PATH="\$HOME/.dotfiles"
SYNC_PROJECTS_PATH="\$HOME/projects"
SYNC_DOCUMENTS_PATH="\$HOME/Documents"

# Additional configuration
SYNC_IGNORE_FILE="\$HOME/.config/sync/ignore"
EOF
      echo "✅ Created default config at: $target"
      # Create default ignore file if it doesn't exist
      local ignore_file="${target%/*}/ignore"
      if [[ ! -f "$ignore_file" ]]; then
        cat > "$ignore_file" << EOF
# Default ignore patterns
Path .git
Name *.log
Name node_modules
Name .DS_Store
Name *.pyc
Name __pycache__
Name .pytest_cache
Name .coverage
Name .idea
Name .vscode
Name dist
Name build
Name *.egg-info
Name .env
Name .venv
Name venv
Name .tox
Name .mypy_cache
Name .next
Name target
Name .gradle
Name .sass-cache
EOF
        echo "✅ Created default ignore file at: $ignore_file"
      fi
      ;;
  esac
}

# Function to install man page
install_man_page() {
  local script_path="${(%):-%x}"
  local script_dir="$(dirname "$script_path")"
  local man_page="$script_dir/sync.1"
  local man_dir="/usr/local/share/man/man1"
  local sys_man_dir="/usr/share/man/man1"

  echo "📚 Installing man page..."
  
  # Create man page content
  cat > "$man_page" << 'EOF'
.TH SYNC 1 "$(date +"%B %Y")" "sync 1.0.0" "User Commands"
# ... rest of existing man page content ...
EOF

  # Try to install in /usr/local first, fall back to /usr if needed
  if sudo mkdir -p "$man_dir" 2>/dev/null; then
    if sudo install -m 644 "$man_page" "$man_dir/"; then
      echo "✅ Man page installed to $man_dir/sync.1"
    else
      echo "⚠️  Failed to install to $man_dir, trying $sys_man_dir..."
      if sudo install -m 644 "$man_page" "$sys_man_dir/"; then
        echo "✅ Man page installed to $sys_man_dir/sync.1"
      else
        echo "❌ Failed to install man page"
        return 1
      fi
    fi
  else
    if sudo install -m 644 "$man_page" "$sys_man_dir/"; then
      echo "✅ Man page installed to $sys_man_dir/sync.1"
    else
      echo "❌ Failed to install man page"
      return 1
    fi
  fi

  # Update man database
  if command -v mandb >/dev/null 2>&1; then
    sudo mandb >/dev/null 2>&1
  elif command -v makewhatis >/dev/null 2>&1; then
    sudo makewhatis >/dev/null 2>&1
  fi

  return 0
}

# Function to handle Linux package installation
install_linux_packages() {
  local distro="$1"
  local pkg_manager=""
  local install_cmd=""
  local update_cmd=""
  local packages="unison"

  case "$distro" in
    "ubuntu"|"debian"|"pop"|"elementary"|"linuxmint"|"raspbian")
      pkg_manager="apt-get"
      install_cmd="sudo apt-get install -y"
      update_cmd="sudo apt-get update"
      ;;
    "fedora"|"rhel"|"centos"|"rocky"|"almalinux")
      pkg_manager="dnf"
      install_cmd="sudo dnf install -y"
      update_cmd="sudo dnf check-update"
      packages="unison unison-gtk"  # Some distributions split the package
      ;;
    "opensuse-tumbleweed"|"opensuse-leap"|"suse"|"sles")
      pkg_manager="zypper"
      install_cmd="sudo zypper install -y"
      update_cmd="sudo zypper refresh"
      ;;
    "arch"|"manjaro"|"endeavouros")
      pkg_manager="pacman"
      install_cmd="sudo pacman -S --noconfirm"
      update_cmd="sudo pacman -Sy"
      ;;
    "alpine")
      pkg_manager="apk"
      install_cmd="sudo apk add"
      update_cmd="sudo apk update"
      ;;
    "void")
      pkg_manager="xbps"
      install_cmd="sudo xbps-install -y"
      update_cmd="sudo xbps-install -S"
      ;;
    "gentoo")
      pkg_manager="emerge"
      install_cmd="sudo emerge -av"
      update_cmd="sudo emerge --sync"
      packages="net-misc/unison"
      ;;
    "nixos")
      pkg_manager="nix"
      install_cmd="nix-env -i"
      update_cmd="nix-channel --update"
      packages="unison"
      ;;
    *)
      echo "❌ Unsupported Linux distribution: $distro"
      echo "Please install Unison manually and try again"
      return 1
      ;;
  esac

  echo "📦 Using package manager: $pkg_manager"
  echo "Updating package lists..."
  eval "$update_cmd"
  
  echo "Installing required packages..."
  eval "$install_cmd $packages"

  # Verify installation
  if ! command -v unison >/dev/null 2>&1; then
    echo "❌ Unison installation failed"
    return 1
  fi

  return 0
}

# Function to check system state
check_system_state() {
  local os_type="$1"
  local distro="$2"
  local changes=()
  local warnings=()
  local requirements=()

  # 1. Check basic system requirements
  if ! command -v ssh >/dev/null 2>&1; then
    changes+=("• Install SSH client")
    requirements+=("ssh")
  fi

  # 2. Check package manager (needed for installing unison)
  case "$os_type" in
    "Darwin")
      if ! command -v brew >/dev/null 2>&1; then
        changes+=("• Install Homebrew package manager")
        requirements+=("curl")
      fi
      ;;
    "Linux")
      case "$distro" in
        "ubuntu"|"debian"|"pop"|"elementary"|"linuxmint"|"raspbian")
          if ! command -v apt-get >/dev/null 2>&1; then
            warnings+=("⚠️  apt-get not found - system may not be supported")
          fi
          ;;
        "fedora"|"rhel"|"centos"|"rocky"|"almalinux")
          if ! command -v dnf >/dev/null 2>&1; then
            warnings+=("⚠️  dnf not found - system may not be supported")
          fi
          ;;
        # ... similar checks for other package managers ...
      esac
      ;;
  esac

  # 3. Check unison installation and configuration
  if ! command -v unison >/dev/null 2>&1; then
    case "$os_type" in
      "Darwin")
        changes+=("• Install Unison via Homebrew")
        ;;
      "Linux")
        case "$distro" in
          "ubuntu"|"debian"|"pop"|"elementary"|"linuxmint"|"raspbian")
            changes+=("• Install Unison via apt-get")
            requirements+=("sudo" "apt-get")
            ;;
          "fedora"|"rhel"|"centos"|"rocky"|"almalinux")
            changes+=("• Install Unison and Unison-GTK via dnf")
            requirements+=("sudo" "dnf")
            ;;
          "opensuse-tumbleweed"|"opensuse-leap"|"suse"|"sles")
            changes+=("• Install Unison via zypper")
            requirements+=("sudo" "zypper")
            ;;
          "arch"|"manjaro"|"endeavouros")
            changes+=("• Install Unison via pacman")
            requirements+=("sudo" "pacman")
            ;;
          "alpine")
            changes+=("• Install Unison via apk")
            requirements+=("sudo" "apk")
            ;;
          "void")
            changes+=("• Install Unison via xbps")
            requirements+=("sudo" "xbps-install")
            ;;
          "gentoo")
            changes+=("• Install Unison via emerge")
            requirements+=("sudo" "emerge")
            ;;
          "nixos")
            changes+=("• Install Unison via nix-env")
            requirements+=("nix-env")
            ;;
          *)
            warnings+=("⚠️  Unsupported Linux distribution: $distro")
            warnings+=("   You will need to install Unison manually")
            ;;
        esac
        ;;
    esac
  else
    # Check unison version if installed
    local unison_version
    unison_version=$(unison -version 2>/dev/null | head -n1)
    echo "✓ Unison installed (version: $unison_version)"
    
    # Check unison preferences directory
    local unison_pref_dir="${UNISON:-$HOME/.unison}"
    if [[ ! -d "$unison_pref_dir" ]]; then
      changes+=("• Create Unison preferences directory: $unison_pref_dir")
    fi
  fi

  # 4. Check SSH configuration
  if [[ ! -f "$HOME/.ssh/id_rsa" && ! -f "$HOME/.ssh/id_ed25519" ]]; then
    changes+=("• Generate SSH key (recommended: ed25519)")
  fi

  # 5. Check configuration directory
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sync"
  if [[ ! -d "$config_dir" ]]; then
    changes+=("• Create sync configuration directory: $config_dir")
  fi

  if [[ ! -f "$config_dir/config" ]]; then
    changes+=("• Create default configuration file")
  fi

  if [[ ! -f "$config_dir/ignore" ]]; then
    changes+=("• Create default ignore patterns file")
  fi

  # 6. Check shell configuration
  local shell_configs=()
  [[ -f ~/.zshrc ]] && shell_configs+=("~/.zshrc")
  [[ -f ~/.bashrc ]] && shell_configs+=("~/.bashrc")
  [[ -f ~/.profile ]] && shell_configs+=("~/.profile")

  if [[ ${#shell_configs[@]} -eq 0 ]]; then
    warnings+=("⚠️  No supported shell configuration files found")
    changes+=("• Create ~/.profile for PATH configuration")
  else
    changes+=("• Update PATH in: ${shell_configs[*]}")
  fi

  # 7. Check man page installation
  if ! man -w sync >/dev/null 2>&1; then
    changes+=("• Install sync man page")
    requirements+=("sudo")
  fi

  # Output the analysis in a clear, ordered format
  echo "📋 Pre-flight Checklist"
  echo "===================="
  echo
  echo "System Information:"
  echo "  OS Type: $os_type"
  [[ -n "$distro" ]] && echo "  Distribution: $distro"
  echo
  
  if [[ ${#requirements[@]} -gt 0 ]]; then
    echo "Required Dependencies:"
    printf '  %s\n' "${requirements[@]}"
    echo
  fi
  
  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "Warnings:"
    printf '%s\n' "${warnings[@]}"
    echo
  fi
  
  if [[ ${#changes[@]} -gt 0 ]]; then
    echo "Required Changes:"
    printf '%s\n' "${changes[@]}"
    echo
  else
    echo "✅ All checks passed! System is ready for sync operations."
    echo
  fi
  
  # Return true if there are changes to be made
  [[ ${#changes[@]} -gt 0 ]]
}

# Function to check host status
check_host_status() {
  local host_ip="$1"
  local user="$2"
  local unison_path="$3"
  
  echo "🔍 Checking host status for ${user}@${host_ip}..."
  
  # Check if host is up
  if ! ping -c 1 -W 1 "$host_ip" &>/dev/null; then
    echo "❌ Host ${host_ip} is DOWN"
    return 1
  fi
  echo "✅ Host is UP"
  
  # Check SSH connectivity
  if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${user}@${host_ip}" "echo 'SSH connection successful'" &>/dev/null; then
    echo "❌ SSH connection failed - check your SSH keys"
    return 1
  fi
  echo "✅ SSH connection successful"
  
  # Check Unison installation and version
  local remote_unison_version
  if ! remote_unison_version=$(ssh -o BatchMode=yes "${user}@${host_ip}" "$unison_path -version" 2>/dev/null); then
    echo "❌ Unison not found or not executable at $unison_path on remote system"
    return 1
  fi
  local local_unison_version
  local_unison_version=$("$unison_path" -version)
  echo "✅ Unison is installed"
  echo "   Local version: $local_unison_version"
  echo "   Remote version: $remote_unison_version"
  
  # Check if versions match
  if [ "$local_unison_version" != "$remote_unison_version" ]; then
    echo "⚠️  Warning: Unison versions do not match"
    return 2
  fi
  echo "✅ Unison versions match"
  
  return 0
}

# Function to bootstrap local machine
bootstrap_local() {
  echo "🔍 Analyzing local system..."
  
  local os_type="$(uname)"
  local distro=""
  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/sync/config"
  
  # Detect Linux distribution
  if [[ "$os_type" == "Linux" ]]; then
    if [ -f "/etc/os-release" ]; then
      . /etc/os-release
      distro="$ID"
    elif [ -f "/etc/redhat-release" ]; then
      distro="rhel"
    elif [ -f "/etc/arch-release" ]; then
      distro="arch"
    elif [ -f "/etc/gentoo-release" ]; then
      distro="gentoo"
    elif [ -f "/etc/alpine-release" ]; then
      distro="alpine"
    elif [ -f "/etc/nixos/configuration.nix" ]; then
      distro="nixos"
    fi
  fi

  # Check system state and required changes
  if ! check_system_state "$os_type" "$distro"; then
    echo "✅ System is already bootstrapped!"
    return 0
  fi

  echo "Continue with these changes? [y/N] "
  read -q response || true
  echo
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Bootstrap cancelled."
    return 1
  fi

  echo "🔧 Bootstrapping local machine..."
  
  # Initialize configuration first if it doesn't exist
  if [[ ! -f "$config_file" ]]; then
    echo "📝 Creating default configuration..."
    manage_config_location "init"
    # Re-source the config file
    source "$config_file"
    echo "✅ Configuration initialized"
  fi
  
  case "$os_type" in
    "Darwin")
      echo "🍎 macOS detected"
      # Install Homebrew if needed
      if ! command -v brew >/dev/null 2>&1; then
        echo "🍺 Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
      fi
      
      # Install unison
      echo "📦 Installing unison..."
      brew install unison
      ;;
    "Linux")
      echo "🐧 Linux detected"
      local distro=""
      
      # Try multiple methods to detect distribution
      if [ -f "/etc/os-release" ]; then
        . /etc/os-release
        distro="$ID"
      elif [ -f "/etc/redhat-release" ]; then
        distro="rhel"
      elif [ -f "/etc/arch-release" ]; then
        distro="arch"
      elif [ -f "/etc/gentoo-release" ]; then
        distro="gentoo"
      elif [ -f "/etc/alpine-release" ]; then
        distro="alpine"
      elif [ -f "/etc/nixos/configuration.nix" ]; then
        distro="nixos"
      else
        echo "❌ Could not determine Linux distribution"
        echo "Please install Unison manually and try again"
        return 1
      fi

      install_linux_packages "$distro"
      ;;
    *)
      echo "❌ Unsupported operating system: $os_type"
      return 1
      ;;
  esac

  # Create required directories
  echo "📁 Creating required directories..."
  mkdir -p "$GIT_PATH" "$ALIASES_PATH" "$UNISON_PREF_DIR" "$DOTFILES_PATH" "$PROJECTS_PATH" "$DOCUMENTS_PATH"

  # Install man page
  install_man_page

  echo "
🎉 Local bootstrap complete! Your system is ready for synchronization.
    Man page installed - try: man sync
    "
  return 0
}

# Function to bootstrap remote host
bootstrap_remote_host() {
  local host_ip="$1"
  local user="$2"
  local unison_path="$3"
  
  # Handle localhost specially
  if [[ "$host_ip" == "localhost" ]]; then
    bootstrap_local
    return $?
  fi
  
  # Initialize configuration first if it doesn't exist
  local config_file
  config_file=$(manage_config_location "get")
  if [[ ! -f "$config_file" ]]; then
    echo "📝 No configuration found, creating default configuration..."
    manage_config_location "init"
    # Re-source the config file
    source "$config_file"
    echo "✅ Configuration initialized"
  fi
  
  echo "🔧 Analyzing remote host ${user}@${host_ip}..."
  
  # Check basic connectivity first
  if ! ping -c 1 -W 1 "$host_ip" &>/dev/null; then
    echo "❌ Host ${host_ip} is not reachable"
    return 1
  fi
  
  if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${user}@${host_ip}" "echo 'SSH connection successful'" &>/dev/null; then
    echo "❌ SSH connection failed - please ensure SSH key is set up first"
    echo "    Run: ssh-copy-id ${user}@${host_ip}"
    return 1
  fi

  # Get remote system information
  local remote_os
  remote_os=$(ssh -o BatchMode=yes "${user}@${host_ip}" "uname")
  
  local remote_distro=""
  if [[ "$remote_os" == "Linux" ]]; then
    remote_distro=$(ssh -o BatchMode=yes "${user}@${host_ip}" '
      if [ -f "/etc/os-release" ]; then
        . /etc/os-release
        echo "$ID"
      elif [ -f "/etc/redhat-release" ]; then
        echo "rhel"
      elif [ -f "/etc/arch-release" ]; then
        echo "arch"
      elif [ -f "/etc/gentoo-release" ]; then
        echo "gentoo"
      elif [ -f "/etc/alpine-release" ]; then
        echo "alpine"
      elif [ -f "/etc/nixos/configuration.nix" ]; then
        echo "nixos"
      fi
    ')
  fi

  # Create a temporary script to check remote system state
  local temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
# Paste the check_system_state function here
EOF
  
  # Transfer and execute the check on the remote system
  scp "$temp_script" "${user}@${host_ip}:/tmp/check_system_state.sh"
  ssh -o BatchMode=yes "${user}@${host_ip}" "
    source /tmp/check_system_state.sh
    check_system_state '$remote_os' '$remote_distro'
  "
  local check_status=$?
  
  # Clean up
  rm -f "$temp_script"
  ssh -o BatchMode=yes "${user}@${host_ip}" "rm -f /tmp/check_system_state.sh"

  if [[ $check_status -eq 0 ]]; then
    echo "✅ Remote system is already bootstrapped!"
    return 0
  fi

  echo "Continue with these changes? [y/N] "
  read -q response || true
  echo
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Bootstrap cancelled."
    return 1
  fi

  echo "🔧 Bootstrapping remote host..."
  # Rest of existing bootstrap_remote_host code...
}

# Main sync function
sync() {
  # Config management function
  manage_config_location() {
    local action="$1"
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sync"
    local config_file="$config_dir/config"
    local script_path="${(%):-%x}"  # Get the path of the current script
    
    case "$action" in
      "get")
        # Read the override location if it exists
        if [[ -f "$script_path.config_location" ]]; then
          cat "$script_path.config_location"
        else
          echo "$config_file"
        fi
        ;;
      "set")
        local new_location="$2"
        if [[ -z "$new_location" ]]; then
          echo "❌ Error: New config location not specified"
          return 1
        fi
        # Create directory if it doesn't exist
        mkdir -p "$(dirname "$new_location")"
        # Save the new location
        echo "$new_location" > "$script_path.config_location"
        # If old config exists and new location is different, offer to copy it
        local old_config="$config_file"
        if [[ -f "$old_config" && "$old_config" != "$new_location" ]]; then
          echo "Would you like to copy existing config from $old_config to $new_location? [y/N] "
          read -q response || true
          echo
          if [[ "$response" =~ ^[Yy]$ ]]; then
            mkdir -p "$(dirname "$new_location")"
            cp "$old_config" "$new_location"
            echo "✅ Config copied to new location"
          fi
        fi
        echo "✅ Config location updated to: $new_location"
        ;;
      "init")
        local target="${2:-$config_file}"
        mkdir -p "$(dirname "$target")"
        cat > "$target" << EOF
# sync configuration file

# Remote user configuration
SYNC_REMOTE_USER="lou"
SYNC_REMOTE_IPS="192.168.1.5,192.168.1.6,192.168.1.7"

# Unison configuration
SYNC_UNISON_PATH="/opt/homebrew/bin/unison"
SYNC_UNISON_PREF_DIR="\$HOME/.unison"

# Directory paths
SYNC_GIT_PATH="\$HOME/git"
SYNC_ALIASES_PATH="\$HOME/.config/lib"
SYNC_DOTFILES_PATH="\$HOME/.dotfiles"
SYNC_PROJECTS_PATH="\$HOME/projects"
SYNC_DOCUMENTS_PATH="\$HOME/Documents"

# Additional configuration
SYNC_IGNORE_FILE="\$HOME/.config/sync/ignore"
EOF
        echo "✅ Created default config at: $target"
        # Create default ignore file if it doesn't exist
        local ignore_file="${target%/*}/ignore"
        if [[ ! -f "$ignore_file" ]]; then
          cat > "$ignore_file" << EOF
# Default ignore patterns
Path .git
Name *.log
Name node_modules
Name .DS_Store
Name *.pyc
Name __pycache__
Name .pytest_cache
Name .coverage
Name .idea
Name .vscode
Name dist
Name build
Name *.egg-info
Name .env
Name .venv
Name venv
Name .tox
Name .mypy_cache
Name .next
Name target
Name .gradle
Name .sass-cache
EOF
          echo "✅ Created default ignore file at: $ignore_file"
        fi
        ;;
    esac
  }

  # Handle config management commands first
  case "$1" in
    "config")
      case "$2" in
        "set")
          manage_config_location "set" "$3"
          return $?
          ;;
        "init")
          manage_config_location "init" "$3"
          return $?
          ;;
        "get")
          manage_config_location "get"
          return $?
          ;;
        *)
          echo "Usage: sync config [get|set|init] [path]"
          echo "  get           Show current config location"
          echo "  set PATH      Set config location to PATH"
          echo "  init [PATH]   Create default config file at PATH
                               (or default location)"
          return 1
          ;;
      esac
      ;;
  esac

  # Parse arguments first
  local debug=false
  local bootstrap_mode=false
  local bootstrap_ip=""
  local command=""
  local force=false
  local dry_run=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      bootstrap)
        bootstrap_mode=true
        shift
        if [[ $# -gt 0 ]]; then
          bootstrap_ip="$1"
          shift
        else
          show_bootstrap_usage
          return 1
        fi
        ;;
      --user=*)
        REMOTE_HOST_USER="${1#*=}"
        shift
        ;;
      --ip=*)
        REMOTE_HOST_IPS=("${1#*=}")
        shift
        ;;
      --unison-path=*)
        UNISON_PATH="${1#*=}"
        shift
        ;;
      --pref-dir=*)
        UNISON_PREF_DIR="${1#*=}"
        shift
        ;;
      --git-path=*)
        GIT_PATH="${1#*=}"
        shift
        ;;
      --aliases-path=*)
        ALIASES_PATH="${1#*=}"
        shift
        ;;
      --dotfiles-path=*)
        DOTFILES_PATH="${1#*=}"
        shift
        ;;
      --projects-path=*)
        PROJECTS_PATH="${1#*=}"
        shift
        ;;
      --documents-path=*)
        DOCUMENTS_PATH="${1#*=}"
        shift
        ;;
      --ignore-file=*)
        IGNORE_FILE="${1#*=}"
        shift
        ;;
      --config=*)
        local config_file="${1#*=}"
        if [[ -f "$config_file" ]]; then
          source "$config_file"
        else
          echo "⚠️  Warning: Config file not found: $config_file"
        fi
        shift
        ;;
      --debug)
    debug=true
    shift
        ;;
      --force)
        force=true
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --version)
        echo "sync version 1.0.0"
        return 0
        ;;
      --help|-h)
        show_usage
        return 0
        ;;
      git|aliases|status|dotfiles|projects|documents)
        command="$1"
        shift
        ;;
      *)
        echo "Unknown option: $1" >&2
        show_usage
        return 1
        ;;
    esac
  done

  # Handle bootstrap command before any config checks
  if [ "$bootstrap_mode" = true ]; then
    case "$bootstrap_ip" in
      "localhost")
        bootstrap_local
        return $?
        ;;
      *)
        if [[ -n "$bootstrap_ip" ]]; then
          bootstrap_remote_host "$bootstrap_ip" "${SYNC_REMOTE_USER:-lou}" "${SYNC_UNISON_PATH:-/opt/homebrew/bin/unison}"
          return $?
        else
          show_bootstrap_usage
          return 1
        fi
        ;;
    esac
  fi

  # Get config file location
  local config_file
  config_file=$(manage_config_location "get")

  # Load config file if it exists
  if [[ ! -f "$config_file" ]]; then
    echo "❌ System not configured. Please run: sync bootstrap localhost"
    return 1
  fi
  source "$config_file"

  # Initialize with values from config
  local REMOTE_HOST_USER="${SYNC_REMOTE_USER}"
  local -a REMOTE_HOST_IPS=(${(s:,:)SYNC_REMOTE_IPS})
  local REMOTE_HOST_IP=""
  local UNISON_PATH="${SYNC_UNISON_PATH}"
  local UNISON_PREF_DIR="${SYNC_UNISON_PREF_DIR}"
  local GIT_PATH="${SYNC_GIT_PATH}"
  local ALIASES_PATH="${SYNC_ALIASES_PATH}"
  local DOTFILES_PATH="${SYNC_DOTFILES_PATH}"
  local PROJECTS_PATH="${SYNC_PROJECTS_PATH}"
  local DOCUMENTS_PATH="${SYNC_DOCUMENTS_PATH}"
  local IGNORE_FILE="${SYNC_IGNORE_FILE}"

  # Default configuration from environment variables with fallbacks
  local DEFAULT_REMOTE_USER="${SYNC_REMOTE_USER:-lou}"
  local -a DEFAULT_REMOTE_IPS=(${(s:,:)SYNC_REMOTE_IPS:-"192.168.1.5,192.168.1.6,192.168.1.7"})
  local DEFAULT_UNISON_PATH="${SYNC_UNISON_PATH:-/opt/homebrew/bin/unison}"
  local DEFAULT_UNISON_PREF_DIR="${SYNC_UNISON_PREF_DIR:-$HOME/.unison}"
  local DEFAULT_GIT_PATH="${SYNC_GIT_PATH:-$HOME/git}"
  local DEFAULT_ALIASES_PATH="${SYNC_ALIASES_PATH:-$HOME/.config/lib}"
  local DEFAULT_CONFIG_PATH="${SYNC_CONFIG_PATH:-$HOME/.config/sync/config}"
  local DEFAULT_IGNORE_FILE="${SYNC_IGNORE_FILE:-$HOME/.config/sync/ignore}"

  # Additional sync targets with environment variable support
  local DEFAULT_DOTFILES_PATH="${SYNC_DOTFILES_PATH:-$HOME/.dotfiles}"
  local DEFAULT_PROJECTS_PATH="${SYNC_PROJECTS_PATH:-$HOME/projects}"
  local DEFAULT_DOCUMENTS_PATH="${SYNC_DOCUMENTS_PATH:-$HOME/Documents}"

  # Function to load ignore patterns
  load_ignore_patterns() {
    local ignore_patterns=()
    if [[ -f "$IGNORE_FILE" ]]; then
      while IFS= read -r pattern || [[ -n "$pattern" ]]; do
        [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$pattern" ]] && continue
        ignore_patterns+=("ignore = $pattern")
      done < "$IGNORE_FILE"
    else
      # Default ignore patterns
      ignore_patterns=(
        "ignore = Path .git"
        "ignore = Name *.log"
        "ignore = Name node_modules"
        "ignore = Name .DS_Store"
        "ignore = Name *.pyc"
        "ignore = Name __pycache__"
        "ignore = Name .pytest_cache"
        "ignore = Name .coverage"
        "ignore = Name .idea"
        "ignore = Name .vscode"
        "ignore = Name dist"
        "ignore = Name build"
        "ignore = Name *.egg-info"
        "ignore = Name .env"
        "ignore = Name .venv"
        "ignore = Name venv"
        "ignore = Name .tox"
        "ignore = Name .mypy_cache"
        "ignore = Name .next"
        "ignore = Name target"
        "ignore = Name .gradle"
        "ignore = Name .sass-cache"
      )
    fi
    echo "${(j:\n:)ignore_patterns}"
  }

  # Function to show bootstrap usage
  show_bootstrap_usage() {
    cat << EOF
Usage: sync bootstrap [localhost|REMOTE_IP]

Bootstrap a local or remote system with sync requirements.

Arguments:
    localhost       Configure the local machine
    REMOTE_IP       IP address of the remote host to configure

Examples:
    sync bootstrap localhost
    sync bootstrap 192.168.1.10

This will:
    - Create necessary configuration
    - Install required packages
    - Set up directories
    - Install man pages
    - Configure shell environment
EOF
  }

  # Function to install man page
  install_man_page() {
    local script_path="${(%):-%x}"
    local script_dir="$(dirname "$script_path")"
    local man_page="$script_dir/sync.1"
    local man_dir="/usr/local/share/man/man1"
    local sys_man_dir="/usr/share/man/man1"

    echo "📚 Installing man page..."
    
    # Create man page content
    cat > "$man_page" << 'EOF'
.TH SYNC 1 "$(date +"%B %Y")" "sync 1.0.0" "User Commands"
# ... rest of existing man page content ...
EOF

    # Try to install in /usr/local first, fall back to /usr if needed
    if sudo mkdir -p "$man_dir" 2>/dev/null; then
      if sudo install -m 644 "$man_page" "$man_dir/"; then
        echo "✅ Man page installed to $man_dir/sync.1"
      else
        echo "⚠️  Failed to install to $man_dir, trying $sys_man_dir..."
        if sudo install -m 644 "$man_page" "$sys_man_dir/"; then
          echo "✅ Man page installed to $sys_man_dir/sync.1"
        else
          echo "❌ Failed to install man page"
          return 1
        fi
      fi
    else
      if sudo install -m 644 "$man_page" "$sys_man_dir/"; then
        echo "✅ Man page installed to $sys_man_dir/sync.1"
      else
        echo "❌ Failed to install man page"
        return 1
      fi
    fi

    # Update man database
    if command -v mandb >/dev/null 2>&1; then
      sudo mandb >/dev/null 2>&1
    elif command -v makewhatis >/dev/null 2>&1; then
      sudo makewhatis >/dev/null 2>&1
    fi

    return 0
  }

  # Function to handle Linux package installation
  install_linux_packages() {
    local distro="$1"
    local pkg_manager=""
    local install_cmd=""
    local update_cmd=""
    local packages="unison"

    case "$distro" in
      "ubuntu"|"debian"|"pop"|"elementary"|"linuxmint"|"raspbian")
        pkg_manager="apt-get"
        install_cmd="sudo apt-get install -y"
        update_cmd="sudo apt-get update"
        ;;
      "fedora"|"rhel"|"centos"|"rocky"|"almalinux")
        pkg_manager="dnf"
        install_cmd="sudo dnf install -y"
        update_cmd="sudo dnf check-update"
        packages="unison unison-gtk"  # Some distributions split the package
        ;;
      "opensuse-tumbleweed"|"opensuse-leap"|"suse"|"sles")
        pkg_manager="zypper"
        install_cmd="sudo zypper install -y"
        update_cmd="sudo zypper refresh"
        ;;
      "arch"|"manjaro"|"endeavouros")
        pkg_manager="pacman"
        install_cmd="sudo pacman -S --noconfirm"
        update_cmd="sudo pacman -Sy"
        ;;
      "alpine")
        pkg_manager="apk"
        install_cmd="sudo apk add"
        update_cmd="sudo apk update"
        ;;
      "void")
        pkg_manager="xbps"
        install_cmd="sudo xbps-install -y"
        update_cmd="sudo xbps-install -S"
        ;;
      "gentoo")
        pkg_manager="emerge"
        install_cmd="sudo emerge -av"
        update_cmd="sudo emerge --sync"
        packages="net-misc/unison"
        ;;
      "nixos")
        pkg_manager="nix"
        install_cmd="nix-env -i"
        update_cmd="nix-channel --update"
        packages="unison"
        ;;
      *)
        echo "❌ Unsupported Linux distribution: $distro"
        echo "Please install Unison manually and try again"
        return 1
        ;;
    esac

    echo "📦 Using package manager: $pkg_manager"
    echo "Updating package lists..."
    eval "$update_cmd"
    
    echo "Installing required packages..."
    eval "$install_cmd $packages"

    # Verify installation
    if ! command -v unison >/dev/null 2>&1; then
      echo "❌ Unison installation failed"
      return 1
    fi

    return 0
  }

  # Function to check system state
  check_system_state() {
    local os_type="$1"
    local distro="$2"
    local changes=()
    local warnings=()
    local requirements=()

    # 1. Check basic system requirements
    if ! command -v ssh >/dev/null 2>&1; then
      changes+=("• Install SSH client")
      requirements+=("ssh")
    fi

    # 2. Check package manager (needed for installing unison)
    case "$os_type" in
      "Darwin")
        if ! command -v brew >/dev/null 2>&1; then
          changes+=("• Install Homebrew package manager")
          requirements+=("curl")
        fi
        ;;
      "Linux")
        case "$distro" in
          "ubuntu"|"debian"|"pop"|"elementary"|"linuxmint"|"raspbian")
            if ! command -v apt-get >/dev/null 2>&1; then
              warnings+=("⚠️  apt-get not found - system may not be supported")
            fi
            ;;
          "fedora"|"rhel"|"centos"|"rocky"|"almalinux")
            if ! command -v dnf >/dev/null 2>&1; then
              warnings+=("⚠️  dnf not found - system may not be supported")
            fi
            ;;
          # ... similar checks for other package managers ...
        esac
        ;;
    esac

    # 3. Check unison installation and configuration
    if ! command -v unison >/dev/null 2>&1; then
      case "$os_type" in
        "Darwin")
          changes+=("• Install Unison via Homebrew")
          ;;
        "Linux")
          case "$distro" in
            "ubuntu"|"debian"|"pop"|"elementary"|"linuxmint"|"raspbian")
              changes+=("• Install Unison via apt-get")
              requirements+=("sudo" "apt-get")
              ;;
            "fedora"|"rhel"|"centos"|"rocky"|"almalinux")
              changes+=("• Install Unison and Unison-GTK via dnf")
              requirements+=("sudo" "dnf")
              ;;
            "opensuse-tumbleweed"|"opensuse-leap"|"suse"|"sles")
              changes+=("• Install Unison via zypper")
              requirements+=("sudo" "zypper")
              ;;
            "arch"|"manjaro"|"endeavouros")
              changes+=("• Install Unison via pacman")
              requirements+=("sudo" "pacman")
              ;;
            "alpine")
              changes+=("• Install Unison via apk")
              requirements+=("sudo" "apk")
              ;;
            "void")
              changes+=("• Install Unison via xbps")
              requirements+=("sudo" "xbps-install")
              ;;
            "gentoo")
              changes+=("• Install Unison via emerge")
              requirements+=("sudo" "emerge")
              ;;
            "nixos")
              changes+=("• Install Unison via nix-env")
              requirements+=("nix-env")
              ;;
            *)
              warnings+=("⚠️  Unsupported Linux distribution: $distro")
              warnings+=("   You will need to install Unison manually")
              ;;
          esac
          ;;
      esac
    else
      # Check unison version if installed
      local unison_version
      unison_version=$(unison -version 2>/dev/null | head -n1)
      echo "✓ Unison installed (version: $unison_version)"
      
      # Check unison preferences directory
      local unison_pref_dir="${UNISON:-$HOME/.unison}"
      if [[ ! -d "$unison_pref_dir" ]]; then
        changes+=("• Create Unison preferences directory: $unison_pref_dir")
      fi
    fi

    # 4. Check SSH configuration
    if [[ ! -f "$HOME/.ssh/id_rsa" && ! -f "$HOME/.ssh/id_ed25519" ]]; then
      changes+=("• Generate SSH key (recommended: ed25519)")
    fi

    # 5. Check configuration directory
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sync"
    if [[ ! -d "$config_dir" ]]; then
      changes+=("• Create sync configuration directory: $config_dir")
    fi

    if [[ ! -f "$config_dir/config" ]]; then
      changes+=("• Create default configuration file")
    fi

    if [[ ! -f "$config_dir/ignore" ]]; then
      changes+=("• Create default ignore patterns file")
    fi

    # 6. Check shell configuration
    local shell_configs=()
    [[ -f ~/.zshrc ]] && shell_configs+=("~/.zshrc")
    [[ -f ~/.bashrc ]] && shell_configs+=("~/.bashrc")
    [[ -f ~/.profile ]] && shell_configs+=("~/.profile")

    if [[ ${#shell_configs[@]} -eq 0 ]]; then
      warnings+=("⚠️  No supported shell configuration files found")
      changes+=("• Create ~/.profile for PATH configuration")
    else
      changes+=("• Update PATH in: ${shell_configs[*]}")
    fi

    # 7. Check man page installation
    if ! man -w sync >/dev/null 2>&1; then
      changes+=("• Install sync man page")
      requirements+=("sudo")
    fi

    # Output the analysis in a clear, ordered format
    echo "📋 Pre-flight Checklist"
    echo "===================="
    echo
    echo "System Information:"
    echo "  OS Type: $os_type"
    [[ -n "$distro" ]] && echo "  Distribution: $distro"
    echo
    
    if [[ ${#requirements[@]} -gt 0 ]]; then
      echo "Required Dependencies:"
      printf '  %s\n' "${requirements[@]}"
      echo
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
      echo "Warnings:"
      printf '%s\n' "${warnings[@]}"
      echo
    fi
    
    if [[ ${#changes[@]} -gt 0 ]]; then
      echo "Required Changes:"
      printf '%s\n' "${changes[@]}"
      echo
    else
      echo "✅ All checks passed! System is ready for sync operations."
      echo
    fi
    
    # Return true if there are changes to be made
    [[ ${#changes[@]} -gt 0 ]]
  }

  # Function to bootstrap local machine
  bootstrap_local() {
    echo "🔍 Analyzing local system..."
    
    local os_type="$(uname)"
    local distro=""
    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/sync/config"
    
    # Detect Linux distribution
    if [[ "$os_type" == "Linux" ]]; then
      if [ -f "/etc/os-release" ]; then
        . /etc/os-release
        distro="$ID"
      elif [ -f "/etc/redhat-release" ]; then
        distro="rhel"
      elif [ -f "/etc/arch-release" ]; then
        distro="arch"
      elif [ -f "/etc/gentoo-release" ]; then
        distro="gentoo"
      elif [ -f "/etc/alpine-release" ]; then
        distro="alpine"
      elif [ -f "/etc/nixos/configuration.nix" ]; then
        distro="nixos"
      fi
    fi

    # Check system state and required changes
    if ! check_system_state "$os_type" "$distro"; then
      echo "✅ System is already bootstrapped!"
      return 0
    fi

    echo "Continue with these changes? [y/N] "
    read -q response || true
    echo
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo "Bootstrap cancelled."
      return 1
    fi

    echo "🔧 Bootstrapping local machine..."
    
    # Initialize configuration first if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
      echo "📝 Creating default configuration..."
      manage_config_location "init"
      # Re-source the config file
      source "$config_file"
      echo "✅ Configuration initialized"
    fi
    
    case "$os_type" in
      "Darwin")
        echo "🍎 macOS detected"
        # Install Homebrew if needed
        if ! command -v brew >/dev/null 2>&1; then
          echo "🍺 Installing Homebrew..."
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
          eval "$(/opt/homebrew/bin/brew shellenv)"
          echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        fi
        
        # Install unison
        echo "📦 Installing unison..."
        brew install unison
        ;;
      "Linux")
        echo "🐧 Linux detected"
        local distro=""
        
        # Try multiple methods to detect distribution
        if [ -f "/etc/os-release" ]; then
          . /etc/os-release
          distro="$ID"
        elif [ -f "/etc/redhat-release" ]; then
          distro="rhel"
        elif [ -f "/etc/arch-release" ]; then
          distro="arch"
        elif [ -f "/etc/gentoo-release" ]; then
          distro="gentoo"
        elif [ -f "/etc/alpine-release" ]; then
          distro="alpine"
        elif [ -f "/etc/nixos/configuration.nix" ]; then
          distro="nixos"
        else
          echo "❌ Could not determine Linux distribution"
          echo "Please install Unison manually and try again"
          return 1
        fi

        install_linux_packages "$distro"
        ;;
      *)
        echo "❌ Unsupported operating system: $os_type"
        return 1
        ;;
    esac

    # Create required directories
    echo "📁 Creating required directories..."
    mkdir -p "$GIT_PATH" "$ALIASES_PATH" "$UNISON_PREF_DIR" "$DOTFILES_PATH" "$PROJECTS_PATH" "$DOCUMENTS_PATH"

    # Install man page
    install_man_page

    echo "
🎉 Local bootstrap complete! Your system is ready for synchronization.
    Man page installed - try: man sync
    "
    return 0
  }

  # Function to bootstrap remote host
  bootstrap_remote_host() {
    local host_ip="$1"
    local user="$2"
    local unison_path="$3"
    
    # Handle localhost specially
    if [[ "$host_ip" == "localhost" ]]; then
      bootstrap_local
      return $?
    fi
    
    # Initialize configuration first if it doesn't exist
    local config_file
    config_file=$(manage_config_location "get")
    if [[ ! -f "$config_file" ]]; then
      echo "📝 No configuration found, creating default configuration..."
      manage_config_location "init"
      # Re-source the config file
      source "$config_file"
      echo "✅ Configuration initialized"
    fi
    
    echo "🔧 Analyzing remote host ${user}@${host_ip}..."
    
    # Check basic connectivity first
    if ! ping -c 1 -W 1 "$host_ip" &>/dev/null; then
      echo "❌ Host ${host_ip} is not reachable"
      return 1
    fi
    
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${user}@${host_ip}" "echo 'SSH connection successful'" &>/dev/null; then
      echo "❌ SSH connection failed - please ensure SSH key is set up first"
      echo "    Run: ssh-copy-id ${user}@${host_ip}"
      return 1
    fi

    # Get remote system information
    local remote_os
    remote_os=$(ssh -o BatchMode=yes "${user}@${host_ip}" "uname")
    
    local remote_distro=""
    if [[ "$remote_os" == "Linux" ]]; then
      remote_distro=$(ssh -o BatchMode=yes "${user}@${host_ip}" '
        if [ -f "/etc/os-release" ]; then
          . /etc/os-release
          echo "$ID"
        elif [ -f "/etc/redhat-release" ]; then
          echo "rhel"
        elif [ -f "/etc/arch-release" ]; then
          echo "arch"
        elif [ -f "/etc/gentoo-release" ]; then
          echo "gentoo"
        elif [ -f "/etc/alpine-release" ]; then
          echo "alpine"
        elif [ -f "/etc/nixos/configuration.nix" ]; then
          echo "nixos"
        fi
      ')
    fi

    # Create a temporary script to check remote system state
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
# Paste the check_system_state function here
EOF
    
    # Transfer and execute the check on the remote system
    scp "$temp_script" "${user}@${host_ip}:/tmp/check_system_state.sh"
    ssh -o BatchMode=yes "${user}@${host_ip}" "
      source /tmp/check_system_state.sh
      check_system_state '$remote_os' '$remote_distro'
    "
    local check_status=$?
    
    # Clean up
    rm -f "$temp_script"
    ssh -o BatchMode=yes "${user}@${host_ip}" "rm -f /tmp/check_system_state.sh"

    if [[ $check_status -eq 0 ]]; then
      echo "✅ Remote system is already bootstrapped!"
      return 0
    fi

    echo "Continue with these changes? [y/N] "
    read -q response || true
    echo
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo "Bootstrap cancelled."
      return 1
    fi

    echo "🔧 Bootstrapping remote host..."
    # Rest of existing bootstrap_remote_host code...
  }

  # Show help if no command is provided
  if [[ -z "$command" ]]; then
    show_usage
    return 1
  fi

  # Ensure unison preferences directory exists
  mkdir -p "$UNISON_PREF_DIR"

  # Set unison environment
  export UNISON="$UNISON_PREF_DIR"
  export PATH="/opt/homebrew/bin:$PATH"

  # Check local unison installation
  if [ ! -x "$UNISON_PATH" ]; then
    echo "❌ Error: Unison not found at $UNISON_PATH"
    return 1
  fi
  echo "✅ Local Unison installation found"

  # Check all hosts and find the first available one
  local found_available_host=false
  for ip in "${REMOTE_HOST_IPS[@]}"; do
    echo "Checking host $ip..."
    if check_host_status "$ip" "$REMOTE_HOST_USER" "$UNISON_PATH"; then
      REMOTE_HOST_IP="$ip"
      found_available_host=true
      echo "✅ Found available host: $ip"
      break
    fi
    echo "---"
  done

  if [ "$found_available_host" = false ]; then
    echo "❌ No available hosts found. Aborting sync."
    return 1
  fi

  # Create profile files if they don't exist
  create_profile() {
    local profile_name="$1"
    local src="$2"
    local dest="$3"
    local profile_file="$UNISON_PREF_DIR/${profile_name}.prf"
    
    if [ ! -f "$profile_file" ]; then
      {
        echo "root = $src"
        echo "root = $dest"
        echo "times = true"
        echo "perms = 0"
        echo "prefer = newer"
        load_ignore_patterns
        echo "sshcmd = ssh"
        echo "sshargs = -o BatchMode=yes"
        echo "servercmd = $UNISON_PATH"
        echo "auto = true"
        echo "batch = true"
        echo "confirmbigdel = true"
        echo "fastcheck = true"
        [ "$dry_run" = true ] && echo "testonly = true"
      } > "$profile_file"
    fi
  }

  # Check if unison exists on remote using the full path
  if ! ssh -o BatchMode=yes "$REMOTE_HOST_USER@$REMOTE_HOST_IP" "command -v $UNISON_PATH"; then
    echo "Error: Unison not found at $UNISON_PATH on remote system"
    return 1
  fi

  case $command in
    git)
      create_profile "git_sync" "$GIT_PATH" "ssh://$REMOTE_HOST_IP//$GIT_PATH"
      run_unison "git_sync"
    ;;
    aliases)
      create_profile "aliases_sync" "$ALIASES_PATH" "ssh://$REMOTE_HOST_IP//$ALIASES_PATH"
      run_unison "aliases_sync"
      ;;
    dotfiles)
      create_profile "dotfiles_sync" "$DOTFILES_PATH" "ssh://$REMOTE_HOST_IP//$DOTFILES_PATH"
      run_unison "dotfiles_sync"
      ;;
    projects)
      create_profile "projects_sync" "$PROJECTS_PATH" "ssh://$REMOTE_HOST_IP//$PROJECTS_PATH"
      run_unison "projects_sync"
      ;;
    documents)
      create_profile "documents_sync" "$DOCUMENTS_PATH" "ssh://$REMOTE_HOST_IP//$DOCUMENTS_PATH"
      run_unison "documents_sync"
      ;;
    status)
      return 0
      ;;
    *)
      show_usage
      return 1
    ;;
  esac
}
