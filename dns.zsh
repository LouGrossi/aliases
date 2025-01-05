dns() {
    # Source error handler if available
    local error_handler="${0:A:h}/../src/utils/error_handler.zsh"
    [[ -f "$error_handler" ]] && source "$error_handler"

    # Function to show help
    function _dns_help() {
        cat << EOF
Usage: dns [options] <domain>

Query DNS records for a domain.

Options:
  -a, --all          Query all record types
  -t, --type TYPE    Query specific record type (A, AAAA, MX, NS, TXT, etc.)
  -s, --server SRV   Use specific DNS server
  --help, -h         Show this help message

Examples:
  dns example.com
  dns -a example.com
  dns -t MX example.com
  dns -s 8.8.8.8 example.com

Record Types:
  A     IPv4 addresses
  AAAA  IPv6 addresses
  MX    Mail servers
  NS    Name servers
  TXT   Text records
  CNAME Canonical names
  SOA   Start of authority
EOF
    }

    # Show help if requested or no arguments
    if [[ "$1" == "--help" || "$1" == "-h" || $# -eq 0 ]]; then
        _dns_help
        return 0
    fi

    local query_option=""
    local domain_name=""
    local record_type=""
    local dns_server=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)
                query_option="--all"
                shift
                ;;
            -t|--type)
                if [[ -z "$2" ]]; then
                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No record type specified"
                    _dns_help
                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                fi
                record_type="$2"
                shift 2
                ;;
            -s|--server)
                if [[ -z "$2" ]]; then
                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No DNS server specified"
                    _dns_help
                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                fi
                dns_server="$2"
                shift 2
                ;;
            -*)
                handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unknown option: $1"
                _dns_help
                return ${ERROR_CODES[INVALID_ARGUMENT]}
                ;;
            *)
                if [[ -z "$domain_name" ]]; then
                    domain_name="$1"
                else
                    handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "Unexpected argument: $1"
                    _dns_help
                    return ${ERROR_CODES[INVALID_ARGUMENT]}
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$domain_name" ]]; then
        handle_error ${ERROR_CODES[INVALID_ARGUMENT]} "No domain name specified"
        _dns_help
        return ${ERROR_CODES[INVALID_ARGUMENT]}
    fi

    # Check for required commands
    if ! command -v dig &>/dev/null; then
        handle_error ${ERROR_CODES[DEPENDENCY_MISSING]} "Required command 'dig' not found"
        return ${ERROR_CODES[DEPENDENCY_MISSING]}
    fi

    # Array to store the record types
    local -a record_types
    if [[ -n "$record_type" ]]; then
        record_types=("$record_type")
    elif [[ "$query_option" == "--all" ]]; then
        record_types=("A" "AAAA" "MX" "NS" "TXT" "CNAME" "SOA")
    else
        record_types=("A")
    fi

    echo "------------------------------------"
    echo " DNS Query Results for $domain_name"
    [[ -n "$dns_server" ]] && echo " Using DNS server: $dns_server"
    echo "------------------------------------"

    local server_opt=""
    [[ -n "$dns_server" ]] && server_opt="@$dns_server"

    for type in "${record_types[@]}"; do
        echo
        echo "=== $type Records ==="
        dig +short $server_opt "$domain_name" "$type" || {
            handle_error ${ERROR_CODES[NETWORK_ERROR]} "Failed to query $type records"
            continue
        }
    done
}

# Add completion for dns command if using zsh
if [[ -n "$ZSH_VERSION" ]]; then
    _dns_completion() {
        local -a record_types=(
            "A:IPv4 addresses"
            "AAAA:IPv6 addresses"
            "MX:Mail servers"
            "NS:Name servers"
            "TXT:Text records"
            "CNAME:Canonical names"
            "SOA:Start of authority"
        )

        _arguments \
            '(-a --all)'{-a,--all}'[Query all record types]' \
            '(-t --type)'{-t,--type}'[Query specific record type]:record type:($record_types)' \
            '(-s --server)'{-s,--server}'[Use specific DNS server]:dns server:' \
            '(-h --help)'{-h,--help}'[Show help message]' \
            ':domain name:'
    }
    compdef _dns_completion dns
fi
