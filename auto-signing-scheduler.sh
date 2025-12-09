#!/bin/bash

################################################################################
# Automatic Signing Scheduler with Bearer Token Authentication
# 
# Usage:
#   ./auto-signing-scheduler.sh -t <bearer-token> -s <status> -n <nik> -P <passphrase> [options]
#
# Parameters:
#   -t, --token              Bearer Token untuk authentication (REQUIRED)
#   -s, --status             Certificate status (3 atau 4) (REQUIRED)
#   -n, --nik                NIK untuk tanda tangan elektronik (REQUIRED)
#   -P, --passphrase         Passphrase untuk tanda tangan elektronik (REQUIRED)
#   -l, --limit              Maximum certificates to process (Optional)
#   -h, --host               API host (Default: localhost)
#   --port                   API port (Default: 8503)
#   -L, --log-file           Log file path (Default: /var/log/swajar-auto-signing.log)
#   --help                   Show this help message
#
# Examples:
#   ./auto-signing-scheduler.sh \
#     -t "eyJhbGciOiJIUzI1NiIsInR..." \
#     -s 3 \
#     -n "1234567890" \
#     -P "mypassphrase"
#
#   ./auto-signing-scheduler.sh \
#     -t "eyJhbGciOiJIUzI1NiIsInR..." \
#     -s 3 \
#     -n "1234567890" \
#     -P "mypassphrase" \
#     -l 20
#
# Crontab Examples:
#   # Daily at 1:00 AM
#   0 1 * * * /path/to/auto-signing-scheduler.sh -t "token" -s 3 -n "1234567890" -P "pass" >> /var/log/swajar-auto-signing.log 2>&1
#
#   # Every 2 hours
#   0 */2 * * * /path/to/auto-signing-scheduler.sh -t "token" -s 4 -n "1234567890" -P "pass" -l 20 >> /var/log/swajar-auto-signing.log 2>&1
#
################################################################################

# Set strict error handling
set -o pipefail

# Configuration
API_HOST="localhost"
API_PORT="8503"
LOG_FILE="/var/log/swajar-auto-signing.log"
BEARER_TOKEN=""
STATUS=""
NIK=""
PASSPHRASE=""
LIMIT=""

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SEPARATOR="════════════════════════════════════════════════════════════════════════════════"

# ============================================================================
# Function: Print Help
# ============================================================================
print_help() {
    head -n 53 "$0" | tail -n 50
}

# ============================================================================
# Function: Log Message
# ============================================================================
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
    
    if [ "$VERBOSE" == "true" ]; then
        case "$level" in
            "ERROR")
                echo -e "${RED}[${timestamp}] [${level}] ${message}${NC}" >&2
                ;;
            "WARN")
                echo -e "${YELLOW}[${timestamp}] [${level}] ${message}${NC}"
                ;;
            "SUCCESS")
                echo -e "${GREEN}[${timestamp}] [${level}] ${message}${NC}"
                ;;
            *)
                echo "[${timestamp}] [${level}] ${message}"
                ;;
        esac
    fi
}

# ============================================================================
# Function: Validate Parameters
# ============================================================================
validate_parameters() {
    if [ -z "$BEARER_TOKEN" ]; then
        log_message "ERROR" "Bearer Token is required (-t or --token)"
        exit 1
    fi
    
    if [ -z "$STATUS" ]; then
        log_message "ERROR" "Status is required (-s or --status)"
        exit 1
    fi
    
    if [ -z "$NIK" ]; then
        log_message "ERROR" "NIK is required (-n or --nik)"
        exit 1
    fi
    
    if [ -z "$PASSPHRASE" ]; then
        log_message "ERROR" "Passphrase is required (-P or --passphrase)"
        exit 1
    fi
    
    # Validate status value
    if [ "$STATUS" != "3" ] && [ "$STATUS" != "4" ]; then
        log_message "ERROR" "Status must be 3 or 4, got: $STATUS"
        exit 1
    fi
    
    # Validate limit if provided
    if [ -n "$LIMIT" ]; then
        if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
            log_message "ERROR" "Limit must be a positive number, got: $LIMIT"
            exit 1
        fi
    fi
}

# ============================================================================
# Function: Ensure Log Directory Exists
# ============================================================================
ensure_log_directory() {
    LOG_DIR=$(dirname "$LOG_FILE")
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        if [ $? -eq 0 ]; then
            log_message "INFO" "Created log directory: $LOG_DIR"
        else
            echo "[ERROR] Failed to create log directory: $LOG_DIR" >&2
            exit 1
        fi
    fi
    
    # Create log file if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        log_message "INFO" "Created log file: $LOG_FILE"
    fi
}

# ============================================================================
# Function: Build API URL
# ============================================================================
build_api_url() {
    local url="http://${API_HOST}:${API_PORT}/760JBK6vawB5/auto-sign/execute"
    
    url="${url}?status=${STATUS}"
    url="${url}&nik=${NIK}"
    url="${url}&passphrase=${PASSPHRASE}"
    
    if [ -n "$LIMIT" ] && [ "$LIMIT" -gt 0 ]; then
        url="${url}&limit=${LIMIT}"
        log_message "INFO" "Using endpoint WITH limit: $LIMIT"
    else
        log_message "INFO" "Using endpoint WITHOUT limit"
    fi
    
    echo "$url"
}

# ============================================================================
# Function: Mask Sensitive Data for Logging
# ============================================================================
mask_sensitive_data() {
    local url="$1"
    # Mask token, nik, and passphrase in URL for safe logging
    echo "$url" | sed "s/Bearer [^ ]*/Bearer [MASKED]/g" | \
                  sed "s/nik=[^&]*/nik=[MASKED]/g" | \
                  sed "s/passphrase=[^&]*/passphrase=[MASKED]/g"
}

# ============================================================================
# Function: Execute Auto Signing
# ============================================================================
execute_auto_signing() {
    local api_url=$(build_api_url)
    local safe_url=$(mask_sensitive_data "$api_url")
    
    log_message "INFO" "$SEPARATOR"
    log_message "INFO" "AUTO SIGNING SCHEDULER - CRON JOB EXECUTION"
    log_message "INFO" "$SEPARATOR"
    log_message "INFO" "Start Time: $(date '+%a %b %d %H:%M:%S %Z %Y')"
    log_message "INFO" "API Host: ${API_HOST}"
    log_message "INFO" "API Port: ${API_PORT}"
    log_message "INFO" "Status: ${STATUS}"
    log_message "INFO" "NIK: [MASKED]"
    log_message "INFO" "Limit: ${LIMIT:-unlimited}"
    log_message "INFO" "$SEPARATOR"
    log_message "INFO" "Making HTTP request to Signing API..."
    log_message "INFO" "Request URL: ${safe_url}"
    
    # Get start time for duration calculation
    local start_epoch=$(date +%s)
    
    # Make HTTP request with Bearer Token
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST "$api_url" \
        -H "Authorization: Bearer ${BEARER_TOKEN}" \
        -H "Content-Type: application/json")
    
    # Extract HTTP status code (last line)
    local http_code=$(echo "$response" | tail -n1)
    # Extract response body (all but last line)
    local response_body=$(echo "$response" | head -n-1)
    
    # Calculate duration
    local end_epoch=$(date +%s)
    local duration=$((end_epoch - start_epoch))
    
    log_message "INFO" "$SEPARATOR"
    log_message "INFO" "HTTP Response Code: ${http_code}"
    log_message "INFO" "Response Time: ${duration}s"
    log_message "INFO" "Response Body:"
    
    # Log each line of response with indentation
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            log_message "INFO" "  ${line}"
        fi
    done <<< "$response_body"
    
    # Check if request was successful
    if [ "$http_code" == "200" ] || [ "$http_code" == "202" ]; then
        log_message "SUCCESS" "✓ Auto signing process initiated successfully"
        log_message "INFO" "$SEPARATOR"
        log_message "INFO" "End Time: $(date '+%a %b %d %H:%M:%S %Z %Y')"
        log_message "INFO" "Status: SUCCESS"
        log_message "INFO" "Duration: ${duration}s"
        log_message "INFO" "$SEPARATOR"
        return 0
    else
        log_message "ERROR" "✗ Auto signing request failed with HTTP status: ${http_code}"
        log_message "INFO" "$SEPARATOR"
        log_message "INFO" "End Time: $(date '+%a %b %d %H:%M:%S %Z %Y')"
        log_message "INFO" "Status: FAILED"
        log_message "INFO" "Duration: ${duration}s"
        log_message "INFO" "$SEPARATOR"
        return 1
    fi
}

# ============================================================================
# Main Script Execution
# ============================================================================

# Parse command line arguments
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
        -P|--passphrase)
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
        -L|--log-file)
            LOG_FILE="$2"
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

# Ensure log directory and file exist
ensure_log_directory

# Validate all required parameters
validate_parameters

# Execute auto signing
execute_auto_signing
exit $?
