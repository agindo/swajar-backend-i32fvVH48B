#!/bin/bash

# Script untuk handle duplicate filenames dan mengecek file certificate
# Usage: ./check-certificate-files.sh [status] [limit] [mode]
# Example: ./check-certificate-files.sh 3 50 flow
# Modes: 
#   - flow: Process dengan alur (default) - 1) Handle duplicates index 1+, 2) Check files index 0
#   - full: Handle duplicates + check files (old version)
#   - duplicates: Only handle duplicate filenames
#   - check: Only check files existence

# Default values
STATUS=${1:-3}
LIMIT=${2:-100}
MODE=${3:-flow}

# API Configuration
BASE_URL="http://localhost:8503/760JBK6vawB5"
LOG_FILE="./certificate-checker.log"

# Function untuk logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Determine API endpoint based on mode
case $MODE in
  flow)
    API_URL="${BASE_URL}/process-with-flow"
    ;;
  duplicates)
    API_URL="${BASE_URL}/handle-duplicates"
    ;;
  check)
    API_URL="${BASE_URL}/check-files"
    ;;
  full)
    API_URL="${BASE_URL}/process-cleanup"
    ;;
  *)
    API_URL="${BASE_URL}/process-with-flow"
    ;;
esac

log_message "========================================="
log_message "Starting certificate cleanup process"
log_message "Mode: $MODE"
log_message "Parameters: status=$STATUS, limit=$LIMIT"

# Panggil API endpoint
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    -X GET "${API_URL}?status=${STATUS}&limit=${LIMIT}")

# Extract HTTP status
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

log_message "HTTP Status: $HTTP_STATUS"
if [ "$HTTP_STATUS" -eq 200 ]; then
    log_message "API call successful"
    
    # Parse JSON response menggunakan jq jika tersedia
    if command -v jq &> /dev/null; then
        if [ "$MODE" == "flow" ]; then
            # Flow process response - Step 1 and Step 2
            TOTAL_CHECKED=$(echo "$BODY" | jq -r '.step1_duplicate_handling.total_checked // 0')
            TOTAL_DUPLICATES=$(echo "$BODY" | jq -r '.step1_duplicate_handling.total_duplicates // 0')
            DUP_UPDATED=$(echo "$BODY" | jq -r '.step1_duplicate_handling.duplicates_updated // 0')
            
            FILE_CHECKED=$(echo "$BODY" | jq -r '.step2_file_checking.total_file_checked // 0')
            FILES_FOUND=$(echo "$BODY" | jq -r '.step2_file_checking.files_found // 0')
            FILES_NOT_FOUND=$(echo "$BODY" | jq -r '.step2_file_checking.files_not_found // 0')
            SET_TO_0=$(echo "$BODY" | jq -r '.step2_file_checking.is_active_set_to_0 // 0')
            SET_TO_3=$(echo "$BODY" | jq -r '.step2_file_checking.is_active_set_to_3 // 0')
            
            log_message "Step 1 - Duplicate Handling: Total=$TOTAL_CHECKED, Duplicates=$TOTAL_DUPLICATES, Updated=$DUP_UPDATED"
            log_message "Step 2 - File Checking: Checked=$FILE_CHECKED, Found=$FILES_FOUND, NotFound=$FILES_NOT_FOUND"
            log_message "Step 2 - is_active Updates: Set to 0=$SET_TO_0, Set to 3=$SET_TO_3"
            
        elif [ "$MODE" == "full" ]; then
            # Full process response
            TOTAL_DUPLICATES=$(echo "$BODY" | jq -r '.duplicate_handling.total_duplicates // 0')
            DUP_UPDATED=$(echo "$BODY" | jq -r '.duplicate_handling.total_updated // 0')
            TOTAL_CHECKED=$(echo "$BODY" | jq -r '.file_checking.total_checked // 0')
            FILES_NOT_FOUND=$(echo "$BODY" | jq -r '.file_checking.files_not_found // 0')
            CERTS_UPDATED=$(echo "$BODY" | jq -r '.file_checking.certificates_updated // 0')
            
            log_message "Duplicate Handling: Found=$TOTAL_DUPLICATES, Updated=$DUP_UPDATED"
            log_message "File Checking: Total=$TOTAL_CHECKED, Not Found=$FILES_NOT_FOUND, Updated=$CERTS_UPDATED"
            
        elif [ "$MODE" == "duplicates" ]; then
            # Duplicates only response
            TOTAL_DUPLICATES=$(echo "$BODY" | jq -r '.total_duplicates // 0')
            TOTAL_UPDATED=$(echo "$BODY" | jq -r '.total_updated // 0')
            
            log_message "Duplicate Handling: Found=$TOTAL_DUPLICATES, Updated=$TOTAL_UPDATED"
            
        else
            # Check files only response
            TOTAL_CHECKED=$(echo "$BODY" | jq -r '.total_checked // 0')
            FILES_NOT_FOUND=$(echo "$BODY" | jq -r '.files_not_found // 0')
            UPDATED=$(echo "$BODY" | jq -r '.certificates_updated // 0')
            
            log_message "File Checking: Total=$TOTAL_CHECKED, Not Found=$FILES_NOT_FOUND, Updated=$UPDATED"
        fi
    else
        log_message "Response: $BODY"
    fi
    
    log_message "Certificate cleanup process completed successfully"
else
    log_message "ERROR: API call failed with status $HTTP_STATUS"
    log_message "Response: $BODY"
fi

log_message "========================================="
