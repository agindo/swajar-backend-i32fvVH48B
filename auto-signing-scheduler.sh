#!/bin/bash

###############################################################################
# Auto Signing Scheduler Script untuk Cron Job
# Script ini dipanggil oleh cron job untuk menjalankan auto signing secara berkala
# 
# Konfigurasi Cron:
# # Jalankan auto signing setiap hari jam 01:00 (status 3 - esign_kedua)
# 0 1 * * * /path/to/auto-signing-scheduler.sh -s 3 -n "NIK" -p "PASSPHRASE" >> /var/log/swajar-auto-signing.log 2>&1
#
# # Jalankan setiap 2 jam dengan limit 20 sertifikat (status 4 - esign_pertama)  
# 0 */2 * * * /path/to/auto-signing-scheduler.sh -s 4 -n "NIK" -p "PASSPHRASE" -l 20 >> /var/log/swajar-auto-signing.log 2>&1
#
# Author: SWAJAR System
# Version: 1.0
###############################################################################

set -e  # Exit on error

# ============================================================================
# Configuration
# ============================================================================

# API Configuration
API_HOST="${API_HOST:-localhost}"
API_PORT="${API_PORT:-8503}"
API_BASE_URL="http://${API_HOST}:${API_PORT}/760JBK6vawB5"

# Default values
STATUS=3
NIK=""
PASSPHRASE=""
LIMIT=""
LOG_FILE="/var/log/swajar-auto-signing.log"
TIMEOUT=300  # 5 minutes timeout

# ============================================================================
# Functions
# ============================================================================

# Function untuk print log dengan timestamp
log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}"
}

# Function untuk print usage
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -s, --status STATUS       Certificate status to process (default: 3)
                             3 = Menunggu esign_kedua
                             4 = Menunggu esign_pertama
    -n, --nik NIK            NIK for electronic signature (required)
    -p, --passphrase PASS    Passphrase for signature (required)
    -l, --limit LIMIT        Maximum number of certificates to process (optional)
    -h, --host HOST          API host (default: localhost)
    -P, --port PORT          API port (default: 8503)
    -L, --log-file FILE      Log file path (default: /var/log/swajar-auto-signing.log)
    --help                   Show this help message

Examples:
    # Basic auto signing for status 3
    $0 -s 3 -n "1234567890" -p "mypassphrase"
    
    # Auto signing with limit
    $0 -s 4 -n "1234567890" -p "mypassphrase" -l 20
    
    # Custom host and port
    $0 -s 3 -n "1234567890" -p "mypassphrase" -h 192.168.1.100 -P 8504

EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
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
        -P|--port)
            API_PORT="$2"
            shift 2
            ;;
        -L|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# ============================================================================
# Validation
# ============================================================================

# Update API_BASE_URL with configured host and port
API_BASE_URL="http://${API_HOST}:${API_PORT}/760JBK6vawB5"

# Validate required parameters
if [[ -z "$NIK" || -z "$PASSPHRASE" ]]; then
    print_usage
    exit 1
fi

# ============================================================================
# Ensure log directory exists
# ============================================================================

LOG_DIR=$(dirname "$LOG_FILE")
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR" || {
        echo "ERROR: Cannot create log directory: $LOG_DIR"
        exit 1
    }
fi

# ============================================================================
# Main Execution
# ============================================================================

{
    log_message "INFO" "=========================================================================="
    log_message "INFO" "SWAJAR AUTO SIGNING SCHEDULER - CRON JOB EXECUTION"
    log_message "INFO" "=========================================================================="
    log_message "INFO" "Start Time: $(date)"
    log_message "INFO" "API Host: $API_HOST"
    log_message "INFO" "API Port: $API_PORT"
    log_message "INFO" "Status: $STATUS"
    log_message "INFO" "Limit: ${LIMIT:-unlimited}"
    log_message "INFO" "=========================================================================="
    
    # Build request URL
    if [[ -z "$LIMIT" ]]; then
        REQUEST_URL="${API_BASE_URL}/cron/auto-sign-by-status?status=${STATUS}&nik=${NIK}&passphrase=${PASSPHRASE}"
        log_message "INFO" "Using endpoint: /cron/auto-sign-by-status"
    else
        REQUEST_URL="${API_BASE_URL}/cron/auto-sign-with-limit?status=${STATUS}&nik=${NIK}&passphrase=${PASSPHRASE}&limit=${LIMIT}"
        log_message "INFO" "Using endpoint: /cron/auto-sign-with-limit"
    fi
    
    log_message "INFO" "Making HTTP request to API..."
    log_message "INFO" "Request URL: ${REQUEST_URL%&passphrase=*}&passphrase=***"
    
    # Make API request with timeout
    START_TIME=$(date +%s)
    
    if RESPONSE=$(curl -s -X POST "$REQUEST_URL" \
                       -H "Content-Type: application/json" \
                       --max-time $TIMEOUT \
                       --connect-timeout 10 \
                       -w "\n%{http_code}"); then
        
        HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
        BODY=$(echo "$RESPONSE" | head -n -1)
        
        ELAPSED_TIME=$(($(date +%s) - START_TIME))
        
        log_message "INFO" "HTTP Response Code: $HTTP_CODE"
        log_message "INFO" "Response Time: ${ELAPSED_TIME}s"
        log_message "INFO" "Response Body:"
        
        # Pretty print JSON if available
        if command -v jq &> /dev/null; then
            echo "$BODY" | jq '.' 2>/dev/null | while IFS= read -r line; do
                log_message "INFO" "  $line"
            done
        else
            echo "$BODY" | while IFS= read -r line; do
                log_message "INFO" "  $line"
            done
        fi
        
        # Check HTTP status code
        if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "202" ]]; then
            log_message "INFO" "✓ Auto signing process initiated successfully"
            log_message "INFO" "=========================================================================="
            log_message "INFO" "End Time: $(date)"
            log_message "INFO" "Status: SUCCESS"
            log_message "INFO" "=========================================================================="
            exit 0
        else
            log_message "ERROR" "✗ API returned error status code: $HTTP_CODE"
            log_message "ERROR" "Response: $BODY"
            log_message "ERROR" "=========================================================================="
            log_message "ERROR" "End Time: $(date)"
            log_message "ERROR" "Status: FAILED"
            log_message "ERROR" "=========================================================================="
            exit 1
        fi
    else
        ELAPSED_TIME=$(($(date +%s) - START_TIME))
        log_message "ERROR" "✗ Failed to connect to API"
        log_message "ERROR" "Host: $API_HOST"
        log_message "ERROR" "Port: $API_PORT"
        log_message "ERROR" "Elapsed Time: ${ELAPSED_TIME}s"
        log_message "ERROR" "=========================================================================="
        log_message "ERROR" "End Time: $(date)"
        log_message "ERROR" "Status: FAILED"
        log_message "ERROR" "=========================================================================="
        exit 1
    fi

} >> "$LOG_FILE" 2>&1

exit $?
