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
  local config_file=$(manage_config_location "get")
  local commands=()
  
  # Read commands from config file if it exists
  if [[ -f "$config_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^COMMAND=([[:alnum:]_-]+) ]]; then
        commands+=("${BASH_REMATCH[1]}")
      fi
    done < "$config_file"
  fi
  
  cat << EOF
SYNC(1)                          User Commands                          SYNC(1)

NAME
    sync - Synchronize directories between hosts using Unison

SYNOPSIS
    sync [options] <command>
    sync bootstrap [localhost|REMOTE_IP]
    sync config [get|set|init] [path]

DESCRIPTION
    Synchronize directories between hosts using Unison. This tool provides
    a simple interface for managing file synchronization across multiple
    machines.

COMMANDS
    User-defined commands from config:
EOF

  # List available commands from config
  if [[ ${#commands[@]} -gt 0 ]]; then
    for cmd in "${commands[@]}"; do
      printf "    %-12s %s\n" "$cmd" "User-defined sync target"
    done
  else
    echo "    (No commands defined in config. Run 'sync config init' to create default config)"
  fi

  cat << EOF
    
    Built-in commands:
    bootstrap   Configure local or remote system for sync
    config      Manage sync configuration
    status      Show synchronization status

OPTIONS
    --help, -h           Show this help message
    --version           Show version information
    --debug            Enable debug output
    --force            Force synchronization without confirmation
    --dry-run          Show what would be done without making changes
    
    --user=USER        Override remote username for this run
    --ip=IP           Override remote host IP/hostname for this run
    --unison-path=PATH Override unison executable path
    --pref-dir=DIR    Override unison preferences directory
    --ignore-file=FILE Override ignore patterns file
    --config=FILE      Use alternate config file

CONFIGURATION
    Commands are defined in the configuration file. Each command block specifies:
    - Remote user and hosts
    - Local and remote paths to sync
    - Optional sync options
    
    See the config file for examples and documentation.

FILES
    ~/.config/sync/config     Default configuration file
    ~/.config/sync/ignore     Default ignore patterns
    ~/.unison/               Unison state and profiles

EXAMPLES
    sync config init          Create default configuration
    sync bootstrap localhost  Configure local machine
    sync git                 Run the 'git' sync command
    sync --dry-run shell     Show what 'shell' would sync

AUTHOR
    Written by Lou Grossi (ncdLabs)

REPORTING BUGS
    Report bugs to: https://github.com/ncdlabs/sync/issues

COPYRIGHT
    Copyright © 2024 ncdLabs. License MIT.
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
      mkdir -p "$(dirname "$new_location")"
      echo "$new_location" > "$script_path.config_location"
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
      cat > "$target" << 'EOF'
# Sync Configuration File
# =====================
# This file configures the sync tool's behavior and paths.
# Each command block defines a synchronization target.

# Global Defaults
# --------------
# These values will be used as defaults for any command block that doesn't override them.
# You can use environment variables with ${VAR} syntax.

SYNC_USER=$(whoami)                                           # Default remote user
SYNC_CONFIG=${HOME}/.config/sync/config                       # Config file location
LOCAL_SYNC_UNISON_PATH="/usr/bin/unison"                     # Path to unison on local machine
REMOTE_SYNC_UNISON_PATH="/usr/bin/unison"                    # Path to unison on remote machine
SYNC_UNISON_PREF_DIR="${HOME}/.unison"                       # Unison preferences directory
SYNC_IGNORE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sync/ignore"  # Ignore patterns file

# User Defined Command Blocks
# --------------------------
# Each block defines a synchronization command.
# Values defined here override the global defaults.
# Format:
#   COMMAND=name               # Command name used with 'sync name'
#   REMOTE_USER=user          # SSH user for remote system
#   REMOTE_IPS="ip1,ip2"      # Comma-separated list of IPs/hostnames
#   LOCAL_PATH="/path"        # Local directory to sync
#   REMOTE_PATH="/path"       # Remote directory to sync
#   SYNC_OPTIONS="opts"       # Additional unison options (optional)

# Example: Git repositories sync
COMMAND=git
REMOTE_USER=lou
REMOTE_IPS="  192.168.1.6"
LOCAL_PATH="${HOME}/git"
REMOTE_PATH="${HOME}/git"
SYNC_OPTIONS="-ignore 'Name node_modules' -ignore 'Name .git' -ignore .venv"

# Example: Aliases sync
COMMAND=aliases
REMOTE_USER=lou
REMOTE_IPS="192.168.1.6"
LOCAL_PATH="${HOME}/.config/lib/aliases"
REMOTE_PATH="${HOME}/.config/lib/aliases"
SYNC_OPTIONS="-ignore 'Name .git'"


# Advanced Options
# ---------------
# Uncomment and modify these if you need custom SSH options
# SYNC_SSH_OPTIONS="-p 2222 -i ~/.ssh/custom_key"
EOF
      echo "✅ Created default config at: $target"
      # Create default ignore file if it doesn't exist
      local ignore_file="${target%/*}/ignore"
      if [[ ! -f "$ignore_file" ]]; then
        cat > "$ignore_file" << 'EOF'
# Sync Ignore Patterns
# ===================
# This file defines patterns for files and directories to ignore during synchronization.
# Each line specifies a pattern using Unison's pattern syntax:
#   Name <pattern>  - Ignores files/directories with matching names anywhere
#   Path <pattern>  - Ignores exact paths relative to sync roots
#   Regex <pattern> - Ignores paths matching the regular expression

# Version Control
Path .git
Path .svn
Path .hg

# Build and Dependency Directories
Name node_modules
Name target
Name build
Name dist
Name *.egg-info
Name __pycache__

# Package Manager Files
Name package-lock.json
Name yarn.lock
Name Gemfile.lock
Name poetry.lock

# IDE and Editor Files
Name .idea
Name .vscode
Name *.swp
Name *~
Name .DS_Store

# Temporary and Cache Files
Name *.log
Name .cache
Name .pytest_cache
Name .coverage
Name .sass-cache
Name .mypy_cache
Name .next

# Environment and Configuration
Name .env
Name .env.local
Name .venv
Name venv
Name .tox

# Compiled Files
Name *.pyc
Name *.pyo
Name *.class
Name *.o
Name *.so

# Add your custom ignore patterns below:
# Name *.private
# Path private/files
EOF
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
  
  # Check if man page exists
  if [[ ! -f "$man_page" ]]; then
    echo "❌ Error: Man page file not found at $man_page"
    return 1
  fi

  # Try to install in /usr/local first
  if sudo mkdir -p "$man_dir" 2>/dev/null; then
    if sudo install -m 644 "$man_page" "$man_dir/sync.1" 2>/dev/null; then
      echo "✅ Man page installed to $man_dir/sync.1"
    else
      echo "⚠️  Failed to install to $man_dir, trying $sys_man_dir..."
      # Fall back to /usr/share/man
      if sudo mkdir -p "$sys_man_dir" 2>/dev/null && \
         sudo install -m 644 "$man_page" "$sys_man_dir/sync.1" 2>/dev/null; then
        echo "✅ Man page installed to $sys_man_dir/sync.1"
      else
        echo "❌ Failed to install man page to either location"
        return 1
      fi
    fi
  else
    echo "⚠️  Failed to create $man_dir, trying $sys_man_dir..."
    # Try /usr/share/man directly
    if sudo mkdir -p "$sys_man_dir" 2>/dev/null && \
       sudo install -m 644 "$man_page" "$sys_man_dir/sync.1" 2>/dev/null; then
      echo "✅ Man page installed to $sys_man_dir/sync.1"
    else
      echo "❌ Failed to install man page to either location"
      return 1
    fi
  fi

  # Update man database
  echo "📚 Updating man database..."
  if command -v mandb >/dev/null 2>&1; then
    sudo mandb >/dev/null 2>&1 && echo "✅ Man database updated"
  elif command -v makewhatis >/dev/null 2>&1; then
    sudo makewhatis >/dev/null 2>&1 && echo "✅ Man database updated"
  else
    echo "⚠️  Could not update man database - mandb/makewhatis not found"
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
  local installed=()

  echo "📋 Pre-flight Checklist"
  echo "===================="
  echo
  echo "System Information:"
  echo "  OS Type: $os_type"
  case "$os_type" in
    "Darwin")
      echo "  Package Manager: Homebrew"
      if command -v brew >/dev/null 2>&1; then
        installed+=("• Homebrew package manager")
      else
        changes+=("• Install Homebrew package manager")
        requirements+=("curl")
      fi
      ;;
    "Linux")
      [[ -n "$distro" ]] && echo "  Distribution: $distro"
      case "$distro" in
        "ubuntu"|"debian") echo "  Package Manager: apt" ;;
        "fedora"|"rhel") echo "  Package Manager: dnf" ;;
        "arch") echo "  Package Manager: pacman" ;;
        # ... add other package managers ...
      esac
      ;;
  esac
  echo

  # 1. Check basic system requirements
  if command -v ssh >/dev/null 2>&1; then
    installed+=("• SSH client")
  else
    changes+=("• Install SSH client")
    requirements+=("ssh")
  fi

  # 2. Check unison installation and configuration
  if command -v unison >/dev/null 2>&1; then
    local unison_version
    unison_version=$(unison -version 2>/dev/null | head -n1)
    installed+=("• Unison $unison_version")
    
    # Check unison preferences directory
    local unison_pref_dir="${UNISON:-$HOME/.unison}"
    if [[ -d "$unison_pref_dir" ]]; then
      installed+=("• Unison preferences directory")
    else
      changes+=("• Create Unison preferences directory: $unison_pref_dir")
    fi
  else
    case "$os_type" in
      "Darwin")
        changes+=("• Install Unison via Homebrew")
        ;;
      "Linux")
        case "$distro" in
          "ubuntu"|"debian")
            changes+=("• Install Unison via apt-get")
            requirements+=("sudo" "apt-get")
            ;;
          # ... other distros ...
        esac
        ;;
    esac
  fi

  # 3. Check SSH configuration
  if [[ -f "$HOME/.ssh/id_rsa" || -f "$HOME/.ssh/id_ed25519" ]]; then
    installed+=("• SSH key")
  else
    changes+=("• Generate SSH key (recommended: ed25519)")
  fi

  # 4. Check configuration directory
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sync"
  if [[ -d "$config_dir" ]]; then
    installed+=("• Sync configuration directory")
  else
    changes+=("• Create sync configuration directory: $config_dir")
  fi

  if [[ -f "$config_dir/config" ]]; then
    installed+=("• Sync configuration file")
  else
    changes+=("• Create default configuration file")
  fi

  if [[ -f "$config_dir/ignore" ]]; then
    installed+=("• Sync ignore patterns file")
  else
    changes+=("• Create default ignore patterns file")
  fi

  # 5. Check shell configuration
  local shell_configs=()
  [[ -f ~/.zshrc ]] && shell_configs+=("~/.zshrc")
  [[ -f ~/.bashrc ]] && shell_configs+=("~/.bashrc")
  [[ -f ~/.profile ]] && shell_configs+=("~/.profile")

  if [[ ${#shell_configs[@]} -eq 0 ]]; then
    warnings+=("⚠️  No supported shell configuration files found")
    changes+=("• Create ~/.profile for PATH configuration")
  else
    local needs_path_update=false
    for config in "${shell_configs[@]}"; do
      if ! grep -q "UNISON" "$config" 2>/dev/null; then
        needs_path_update=true
        break
      fi
    done
    if [[ "$needs_path_update" == "true" ]]; then
      changes+=("• Update PATH in: ${shell_configs[*]}")
    else
      installed+=("• Shell PATH configuration")
    fi
  fi

  # 6. Check man page installation
  if man -w sync >/dev/null 2>&1; then
    installed+=("• Sync man page")
  else
    changes+=("• Install sync man page")
    requirements+=("sudo")
  fi
  
  # Output the analysis
  if [[ ${#installed[@]} -gt 0 ]]; then
    echo "Already Installed:"
    printf '  %s\n' "${installed[@]}"
    echo
  fi
  
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
  
  # Initialize configuration if it doesn't exist (only after confirmation)
  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/sync/config"
  if [[ ! -f "$config_file" ]]; then
    echo "📝 Creating default configuration..."
    manage_config_location "init"
    echo "✅ Configuration initialized"
  fi

  # Source the config file to get directory paths
  source "$config_file"

  # Only create sync-specific directories
  echo "📁 Creating sync-specific directories..."
  local sync_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sync"
  local unison_dir="${SYNC_UNISON_PREF_DIR:-$HOME/.unison}"
  
  for dir in "$sync_dir" "$unison_dir"; do
    if [[ ! -d "$dir" ]]; then
      echo "  Creating: $dir"
      mkdir -p "$dir"
    else
      echo "  Already exists: $dir"
    fi
  done
  
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
      
      # Install unison if not already installed
      if ! command -v unison >/dev/null 2>&1; then
        echo "📦 Installing unison..."
        brew install unison --formula
      else
        echo "✅ Unison already installed"
      fi
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

      if ! command -v unison >/dev/null 2>&1; then
        install_linux_packages "$distro"
      else
        echo "✅ Unison already installed"
      fi
      ;;
    *)
      echo "❌ Unsupported operating system: $os_type"
      return 1
      ;;
  esac

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
  if [[ "$host_ip" == "localhost" || "$host_ip" == "local" ]]; then
    bootstrap_local
    return $?
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

  # Initialize configuration if it doesn't exist (only after confirmation)
  local config_file
  config_file=$(manage_config_location "get")
  if [[ ! -f "$config_file" ]]; then
    echo "📝 Creating default configuration..."
    manage_config_location "init"
    # Re-source the config file
    source "$config_file"
    echo "✅ Configuration initialized"
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
        mkdir -p "$(dirname "$new_location")"
        echo "$new_location" > "$script_path.config_location"
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
        cat > "$target" << 'EOF'
# Sync Configuration File
# =====================
# This file configures the sync tool's behavior and paths.
# Each command block defines a synchronization target.

# Global Defaults
# --------------
# These values will be used as defaults for any command block that doesn't override them.
# You can use environment variables with ${VAR} syntax.

SYNC_USER=$(whoami)                                           # Default remote user
SYNC_CONFIG=${HOME}/.config/sync/config                       # Config file location
LOCAL_SYNC_UNISON_PATH="/usr/bin/unison"                     # Path to unison on local machine
REMOTE_SYNC_UNISON_PATH="/usr/bin/unison"                    # Path to unison on remote machine
SYNC_UNISON_PREF_DIR="${HOME}/.unison"                       # Unison preferences directory
SYNC_IGNORE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sync/ignore"  # Ignore patterns file

# User Defined Command Blocks
# --------------------------
# Each block defines a synchronization command.
# Values defined here override the global defaults.
# Format:
#   COMMAND=name               # Command name used with 'sync name'
#   REMOTE_USER=user          # SSH user for remote system
#   REMOTE_IPS="ip1,ip2"      # Comma-separated list of IPs/hostnames
#   LOCAL_PATH="/path"        # Local directory to sync
#   REMOTE_PATH="/path"       # Remote directory to sync
#   SYNC_OPTIONS="opts"       # Additional unison options (optional)

# Example: Git repositories sync
COMMAND=git
REMOTE_USER=lou
REMOTE_IPS="192.168.1.5,192.168.1.6"
LOCAL_PATH="${HOME}/git"
REMOTE_PATH="${HOME}/git"

# Example: Shell configuration sync
COMMAND=shell
REMOTE_USER=lou
REMOTE_IPS="192.168.1.5"
LOCAL_PATH="${HOME}/.config/shell"
REMOTE_PATH="${HOME}/.config/shell"
SYNC_OPTIONS="-ignore 'Name *.zwc'"

# Example: Project files sync
COMMAND=projects
REMOTE_USER=lou
REMOTE_IPS="192.168.1.5"
LOCAL_PATH="${HOME}/projects"
REMOTE_PATH="${HOME}/projects"
SYNC_OPTIONS="-ignore 'Name node_modules' -ignore 'Name .git'"

# Advanced Options
# ---------------
# Uncomment and modify these if you need custom SSH options
# SYNC_SSH_OPTIONS="-p 2222 -i ~/.ssh/custom_key"
EOF
        echo "✅ Created default config at: $target"
        # Create default ignore file if it doesn't exist
        local ignore_file="${target%/*}/ignore"
        if [[ ! -f "$ignore_file" ]]; then
          cat > "$ignore_file" << 'EOF'
# Sync Ignore Patterns
# ===================
# This file defines patterns for files and directories to ignore during synchronization.
# Each line specifies a pattern using Unison's pattern syntax:
#   Name <pattern>  - Ignores files/directories with matching names anywhere
#   Path <pattern>  - Ignores exact paths relative to sync roots
#   Regex <pattern> - Ignores paths matching the regular expression

# Version Control
Path .git
Path .svn
Path .hg

# Build and Dependency Directories
Name node_modules
Name target
Name build
Name dist
Name *.egg-info
Name __pycache__

# Package Manager Files
Name package-lock.json
Name yarn.lock
Name Gemfile.lock
Name poetry.lock

# IDE and Editor Files
Name .idea
Name .vscode
Name *.swp
Name *~
Name .DS_Store

# Temporary and Cache Files
Name *.log
Name .cache
Name .pytest_cache
Name .coverage
Name .sass-cache
Name .mypy_cache
Name .next

# Environment and Configuration
Name .env
Name .env.local
Name .venv
Name venv
Name .tox

# Compiled Files
Name *.pyc
Name *.pyo
Name *.class
Name *.o
Name *.so

# Add your custom ignore patterns below:
# Name *.private
# Path private/files
EOF
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
  
  # Load config file
  local config_file=$(manage_config_location "get")
  if [[ -f "$config_file" ]]; then
    source "$config_file"
  fi
  
  # Parse command line arguments
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
        SYNC_USER="${1#*=}"
        shift
        ;;
      --ip=*)
        REMOTE_IPS="${1#*=}"
        shift
        ;;
      --unison-path=*)
        LOCAL_SYNC_UNISON_PATH="${1#*=}"
        shift
        ;;
      --pref-dir=*)
        SYNC_UNISON_PREF_DIR="${1#*=}"
        shift
        ;;
      --ignore-file=*)
        SYNC_IGNORE_FILE="${1#*=}"
        shift
        ;;
      --config=*)
        config_file="${1#*=}"
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
      --help|-h|help)
        show_usage
        return 0
        ;;
      *)
        # Check if this is a valid command from config
        local is_valid_command=false
        while IFS= read -r line || [[ -n "$line" ]]; do
          if [[ "$line" =~ ^COMMAND=([[:alnum:]_-]+) && "${BASH_REMATCH[1]}" == "$1" ]]; then
            command="$1"
            is_valid_command=true
            break
          fi
        done < "$config_file"
        
        if [[ "$is_valid_command" == "false" ]]; then
          if [[ "$1" == "config" || "$1" == "status" ]]; then
            command="$1"
          else
            echo "Unknown command: $1" >&2
            show_usage
            return 1
          fi
        fi
        shift
        ;;
    esac
  done

  # Handle bootstrap command before any config checks
  if [ "$bootstrap_mode" = true ]; then
    case "$bootstrap_ip" in
      "localhost"|"local")
        bootstrap_local
        return $?
        ;;
      *)
        if [[ -n "$bootstrap_ip" ]]; then
          bootstrap_remote_host "$bootstrap_ip" "${SYNC_USER:-$(whoami)}" "${LOCAL_SYNC_UNISON_PATH:-/usr/bin/unison}"
          return $?
        else
          show_bootstrap_usage
          return 1
        fi
        ;;
    esac
  fi

  # Show help if no command is provided
  if [[ -z "$command" ]]; then
    show_usage
    return 1
  fi

  # Handle built-in commands
  case "$command" in
    "config"|"status")
      # ... existing built-in command handling ...
      ;;
    *)
      # Handle user-defined command
      local cmd_block=""
      local in_block=false
      while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^COMMAND=([[:alnum:]_-]+) ]]; then
          if [[ "${BASH_REMATCH[1]}" == "$command" ]]; then
            in_block=true
            cmd_block="$line"
          else
            in_block=false
          fi
        elif [[ "$in_block" == "true" && ! "$line" =~ ^[[:space:]]*# && ! "$line" =~ ^[[:space:]]*$ ]]; then
          cmd_block="$cmd_block"$'\n'"$line"
        fi
      done < "$config_file"
      
      if [[ -z "$cmd_block" ]]; then
        echo "❌ Error: Command '$command' not found in config"
        return 1
      fi
      
      # Source the command block to get its variables
      eval "$cmd_block"
      
      # Create unison profile for this command
      create_profile "${command}_sync" "$LOCAL_PATH" "ssh://$REMOTE_IPS//$REMOTE_PATH"
      
      # Run unison with any additional options
      if [[ -n "$SYNC_OPTIONS" ]]; then
        UNISON_PATH="$LOCAL_SYNC_UNISON_PATH" run_unison "${command}_sync" "$SYNC_OPTIONS"
      else
        UNISON_PATH="$LOCAL_SYNC_UNISON_PATH" run_unison "${command}_sync"
      fi
      ;;
  esac
}
