#!/bin/bash

# ============================================
# Delete Peserta by ID Script
# ============================================

# Configuration
API_URL="http://localhost:8093/api/peserta/delete-peserta-by-id"
LOG_FILE="delete-peserta.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to log without timestamp (for log file compatibility)
log_simple() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Clear previous log
> "$LOG_FILE"

log_simple "╔════════════════════════════════════════════════════════════════════════════════╗"
log_simple "║              DELETE PESERTA BY ID AUTOMATION SCRIPT                            ║"
log_simple "╚════════════════════════════════════════════════════════════════════════════════╝"
log ""

# Check if the API is accessible
log "Checking API availability..."
if curl -s -o /dev/null -w "%{http_code}" "$API_URL" | grep -q "200\|500"; then
    log "${GREEN}✓ API is accessible${NC}"
else
    log "${RED}✗ API is not accessible. Please ensure the application is running on port 8092${NC}"
    exit 1
fi

log ""
log "─────────────────────────────────────────────────────────────────────────────────"
log "Calling API: $API_URL"
log "─────────────────────────────────────────────────────────────────────────────────"
log ""

# Make API call and capture response
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$API_URL")

# Extract HTTP status and body
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

# Log response
log "HTTP Status: $HTTP_STATUS"
log ""
log "Response Body:"
log_simple "$RESPONSE_BODY"
log ""

# Check if request was successful
if [ "$HTTP_STATUS" -eq 200 ]; then
    log "${GREEN}✓ Delete peserta process completed successfully${NC}"
    
    # Parse summary from response
    DELETED=$(echo "$RESPONSE_BODY" | grep -o '"deletedCount":[0-9]*' | cut -d':' -f2)
    PROCESSED=$(echo "$RESPONSE_BODY" | grep -o '"processedNipCount":[0-9]*' | cut -d':' -f2)
    ERRORS=$(echo "$RESPONSE_BODY" | grep -o '"errorCount":[0-9]*' | cut -d':' -f2)
    
    log ""
    log "═════════════════════════════════════════════════════════════════════════════════"
    log "                           SUMMARY                                                "
    log "═════════════════════════════════════════════════════════════════════════════════"
    log "NIPs Processed: ${PROCESSED:-N/A}"
    log "Peserta Deleted: ${DELETED:-N/A}"
    log "Errors: ${ERRORS:-N/A}"
    log "═════════════════════════════════════════════════════════════════════════════════"
else
    log "${RED}✗ Delete peserta process failed with HTTP status: $HTTP_STATUS${NC}"
    exit 1
fi

log ""
log "${GREEN}Script execution completed. Check $LOG_FILE for details.${NC}"
