#!/bin/bash

################################################################################
# Automatic Certificate Signing Script with Logging
# 
# Usage:
#   ./auto-sign.sh -t <token> -s <status> -n <nik> -p <passphrase> [options]
#
# Parameters:
#   -s, --status             Certificate status (3 or 4) (REQUIRED)
#   -n, --nik                NIK untuk signing (REQUIRED)
#   -p, --passphrase         Passphrase untuk signing (REQUIRED)
#   -l, --limit              Max certificates (Optional)
#   -t, --token              Bearer token (Optional - not required)
#   -h, --host               API host (Default: localhost)
#   --port                   API port (Default: 8503)
#   -v, --verbose            Verbose output
#   --help                   Show help
#
# Examples:
#   ./auto-sign.sh -t "token" -s 3 -n "1234567890" -p "passphrase"
#   ./auto-sign.sh -t "token" -s 3 -n "1234567890" -p "passphrase" -l 10
#
# Crontab:
#   0 1 * * * /path/to/auto-sign.sh -t "token" -s 3 -n "1234567890" -p "pass"
#
################################################################################

set -o pipefail

# Configuration
API_HOST="10.67.0.152"
API_PORT="8503"
LOG_FILE="/var/log/swajar-auto-signing.log"
BEARER_TOKEN=""
STATUS=""
NIK=""
PASSPHRASE=""
LIMIT=""
VERBOSE="false"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SEPARATOR="════════════════════════════════════════════════════════════════════════════════"

# ============================================================================
# Print Help
# ============================================================================
print_help() {
    head -n 32 "$0" | tail -n 30
}

# ============================================================================
# Log Message
# ============================================================================
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local log_entry="[${timestamp}] [${level}] ${message}"
    
    echo "$log_entry" >> "$LOG_FILE" 2>/dev/null
    
    if [ "$VERBOSE" == "true" ]; then
        case "$level" in
            "ERROR")
                echo -e "${RED}${log_entry}${NC}" >&2
                ;;
            "SUCCESS")
                echo -e "${GREEN}${log_entry}${NC}" >&2
                ;;
            *)
                echo "$log_entry" >&2
                ;;
        esac
    fi
}

# ============================================================================
# Mask Sensitive Data
# ============================================================================
mask_data() {
    local data="$1"
    if [ ${#data} -gt 20 ]; then
        echo "${data:0:10}...${data: -10}"
    else
        echo "[MASKED]"
    fi
}

# ============================================================================
# Validate Parameters
# ============================================================================
validate_parameters() {
    if [ -z "$BEARER_TOKEN" ]; then
        log_message "ERROR" "Bearer token is required"
        exit 1
    fi
    
    if [ -z "$STATUS" ]; then
        log_message "ERROR" "Status is required"
        exit 1
    fi
    
    if [ -z "$NIK" ]; then
        log_message "ERROR" "NIK is required"
        exit 1
    fi
    
    if [ -z "$PASSPHRASE" ]; then
        log_message "ERROR" "Passphrase is required"
        exit 1
    fi
    
    if [ "$STATUS" != "3" ] && [ "$STATUS" != "4" ]; then
        log_message "ERROR" "Status must be 3 or 4"
        exit 1
    fi
}

# ============================================================================
# Execute Auto Signing
# ============================================================================
execute_auto_signing() {
    local api_url="http://${API_HOST}:${API_PORT}/OAugBgiqr/auto-sign/trigger"
    api_url="${api_url}?status=${STATUS}"
    api_url="${api_url}&nik=${NIK}"
    api_url="${api_url}&passphrase=${PASSPHRASE}"
    
    if [ -n "$BEARER_TOKEN" ] && [ -z "$BEARER_TOKEN" == false ]; then
        api_url="${api_url}&token=${BEARER_TOKEN}"
    fi
    
    if [ -n "$LIMIT" ] && [ "$LIMIT" -gt 0 ]; then
        api_url="${api_url}&limit=${LIMIT}"
    fi
    
    local safe_url=$(echo "$api_url" | sed "s/token=[^&]*/token=[MASKED]/g" | sed "s/nik=[^&]*/nik=[MASKED]/g" | sed "s/passphrase=[^&]*/passphrase=[MASKED]/g")
    
    log_message "INFO" ""
    log_message "INFO" "$SEPARATOR"
    log_message "INFO" "[REQUEST START]"
    log_message "INFO" "$SEPARATOR"
    log_message "INFO" "Status: $STATUS"
    log_message "INFO" "NIK: $(mask_data "$NIK")"
    if [ -n "$BEARER_TOKEN" ]; then
        log_message "INFO" "Token: $(mask_data "$BEARER_TOKEN")"
    fi
    log_message "INFO" "Limit: ${LIMIT:-unlimited}"
    log_message "INFO" "API URL: $safe_url"
    log_message "INFO" "Making HTTP request..."
    
    local start_time=$(date +%s%N | cut -b1-13)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "$api_url")
    local http_code=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | head -n-1)
    
    local end_time=$(date +%s%N | cut -b1-13)
    local duration_ms=$((end_time - start_time))
    local duration_s=$((duration_ms / 1000))
    
    log_message "INFO" "$SEPARATOR"
    log_message "INFO" "HTTP Status: $http_code"
    log_message "INFO" "Response Time: ${duration_ms}ms (${duration_s}s)"
    log_message "INFO" "Response: $(echo "$response_body" | head -c 200)"
    
    if [ "$http_code" == "200" ] || [ "$http_code" == "202" ]; then
        log_message "SUCCESS" "✓ Signing initiated successfully"
        log_message "INFO" "$SEPARATOR"
        log_message "INFO" "[REQUEST END]"
        log_message "INFO" "Status: SUCCESS"
        log_message "INFO" "Duration: ${duration_s}s"
        log_message "INFO" "$SEPARATOR"
        return 0
    else
        log_message "ERROR" "✗ Signing failed with HTTP $http_code"
        log_message "INFO" "$SEPARATOR"
        log_message "INFO" "[REQUEST END]"
        log_message "INFO" "Status: FAILED"
        log_message "INFO" "Duration: ${duration_s}s"
        log_message "INFO" "$SEPARATOR"
        return 1
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--token)
            BEARER_TOKEN="$2"
            shift 2
            ;;
        -s|--status)
            STATUS="$2"
            shift 2
            ;;
        -n|--nik)
            NIK="$2"
            shift 2
            ;;
        -p|--passphrase)
            PASSPHRASE="$2"
            shift 2
            ;;
        -l|--limit)
            LIMIT="$2"
            shift 2
            ;;
        -h|--host)
            API_HOST="$2"
            shift 2
            ;;
        --port)
            API_PORT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_help
            exit 1
            ;;
    esac
done

# Validate parameters
validate_parameters

# Execute
execute_auto_signing
exit $?
