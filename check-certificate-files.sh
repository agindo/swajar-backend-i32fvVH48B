#!/bin/bash

##############################################################################
# Certificate File Check Script
# 
# Script ini untuk check keberadaan file certificate dan update database
# jika file tidak ditemukan (set is_active = 0)
#
# Usage:
#   ./check-certificate-files.sh
#
# Cronjob example (check setiap hari jam 2 pagi):
#   0 2 * * * /path/to/check-certificate-files.sh
##############################################################################

# Configuration
API_URL="http://localhost:8505/760JBK6vawB5/check-files"
LOG_FILE="/var/log/swajar-certificate-check-script-3.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to log messages
log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Function to log separator
log_separator() {
    echo "[$TIMESTAMP] ═══════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
}

# Start
log_separator
log_message "[SCRIPT START] Certificate File Check"
log_separator

# Check if API is reachable
log_message "[INFO] Checking API availability at: $API_URL"

# Execute API call
log_message "[INFO] Executing certificate file check..."

RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Check HTTP response code
if [ "$HTTP_CODE" -eq 200 ]; then
    log_message "[SUCCESS] API call successful (HTTP $HTTP_CODE)"
    log_message "[RESPONSE] $BODY"
    
    # Parse JSON response (requires jq, optional)
    if command -v jq &> /dev/null; then
        TOTAL_CHECKED=$(echo "$BODY" | jq -r '.total_checked')
        FILES_FOUND=$(echo "$BODY" | jq -r '.files_found')
        FILES_NOT_FOUND=$(echo "$BODY" | jq -r '.files_not_found')
        CERTIFICATES_UPDATED=$(echo "$BODY" | jq -r '.certificates_updated')
        
        log_message "[SUMMARY]"
        log_message "  Total Checked: $TOTAL_CHECKED"
        log_message "  Files Found: $FILES_FOUND"
        log_message "  Files Not Found: $FILES_NOT_FOUND"
        log_message "  Certificates Updated: $CERTIFICATES_UPDATED"
    fi
    
    EXIT_CODE=0
else
    log_message "[ERROR] API call failed (HTTP $HTTP_CODE)"
    log_message "[RESPONSE] $BODY"
    EXIT_CODE=1
fi

log_separator
log_message "[SCRIPT END] Exit code: $EXIT_CODE"
log_separator
echo "" >> "$LOG_FILE"

exit $EXIT_CODE
