#!/bin/bash

#####################################################################
# User Creation Script
# Description: Trigger user creation from course data via REST API
# Usage: ./run-user-creation.sh [year] [monthMod]
# Example: ./run-user-creation.sh 2022 1
# Default: year=2022, monthMod=1
#####################################################################

# Parse command line arguments or use defaults
YEAR="${1:-2022}"
MONTH_MOD="${2:-1}"

# Configuration
API_HOST="http://localhost:8021"
API_ENDPOINT="/api/users/create-from-course?year=${YEAR}&monthMod=${MONTH_MOD}"
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/user-creation.log"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Function to log messages
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} - ${message}" | tee -a "${LOG_FILE}"
}

# Function to print colored output
print_status() {
    local status="$1"
    local message="$2"
    
    case "${status}" in
        "success")
            echo -e "${GREEN}✓ ${message}${NC}"
            ;;
        "error")
            echo -e "${RED}✗ ${message}${NC}"
            ;;
        "info")
            echo -e "${YELLOW}ℹ ${message}${NC}"
            ;;
    esac
}

# Start script
echo ""
echo "========================================"
echo "START - User Creation Process"
echo "========================================"
echo "Parameters: Year=${YEAR}, MonthMod=${MONTH_MOD}"
echo ""

log "Starting user creation process with Year=${YEAR}, MonthMod=${MONTH_MOD}"

# Record start time
START_TIME=$(date +%s)
START_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "Triggering API at ${START_TIMESTAMP}..."
echo ""

# Call the API endpoint
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_HOST}${API_ENDPOINT}")

# Parse response
HTTP_BODY=$(echo "${HTTP_RESPONSE}" | sed '$d')
HTTP_STATUS=$(echo "${HTTP_RESPONSE}" | tail -n1)

# Record end time
END_TIME=$(date +%s)
END_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DURATION=$((END_TIME - START_TIME))

# Check HTTP status
if [ "${HTTP_STATUS}" -eq 200 ]; then
    log "API call successful (HTTP ${HTTP_STATUS})"
    log "Response: ${HTTP_BODY}"
    
    # Parse JSON response (requires jq)
    if command -v jq &> /dev/null; then
        # Extract summary
        TOTAL_RECORDS=$(echo "${HTTP_BODY}" | jq -r '.data.totalCourseRecords // 0')
        TOTAL_PROCESSED=$(echo "${HTTP_BODY}" | jq -r '.data.processedCount // 0')
        TOTAL_CREATED=$(echo "${HTTP_BODY}" | jq -r '.data.createdCount // 0')
        TOTAL_SKIPPED=$(echo "${HTTP_BODY}" | jq -r '.data.skippedCount // 0')
        TOTAL_ERRORS=$(echo "${HTTP_BODY}" | jq -r '.data.errorCount // 0')
        DURATION_MS=$(echo "${HTTP_BODY}" | jq -r '.data.durationMs // 0')
        
        # Display created users
        CREATED_USERS=$(echo "${HTTP_BODY}" | jq -r '.data.createdUsers[]?' 2>/dev/null)
        if [ -n "${CREATED_USERS}" ]; then
            echo "Created Users:"
            while IFS= read -r user; do
                echo "  ${GREEN}✓${NC} ${user}"
            done <<< "${CREATED_USERS}"
            echo ""
        fi
        
        # Display skipped users
        SKIPPED_USERS=$(echo "${HTTP_BODY}" | jq -r '.data.skippedUsers[]?' 2>/dev/null)
        if [ -n "${SKIPPED_USERS}" ]; then
            echo "Skipped Users:"
            while IFS= read -r user; do
                echo "  ${YELLOW}⊘${NC} ${user}"
            done <<< "${SKIPPED_USERS}"
            echo ""
        fi
        
        # Display error users
        ERROR_USERS=$(echo "${HTTP_BODY}" | jq -r '.data.errorUsers[]?' 2>/dev/null)
        if [ -n "${ERROR_USERS}" ]; then
            echo "Error Users:"
            while IFS= read -r user; do
                echo "  ${RED}✗${NC} ${user}"
            done <<< "${ERROR_USERS}"
            echo ""
        fi
        
        # Display summary in README format
        echo "========================================"
        echo "END - User Creation Process"
        echo "Total Records: ${TOTAL_RECORDS}"
        echo "Processed: ${TOTAL_PROCESSED}"
        echo "Created: ${TOTAL_CREATED}"
        echo "Skipped: ${TOTAL_SKIPPED}"
        echo "Errors: ${TOTAL_ERRORS}"
        echo "Duration: ${DURATION_MS} ms ($((DURATION_MS / 1000)) seconds)"
        echo "========================================"
    else
        echo ""
        echo "Response:"
        echo "${HTTP_BODY}"
        echo ""
        echo "========================================"
        echo "END - User Creation Process"
        echo "Duration: ${DURATION} seconds"
        echo "========================================"
        print_status "info" "Install 'jq' for detailed formatted output"
    fi
    
    log "User creation completed successfully"
    exit 0
else
    log "API call failed (HTTP ${HTTP_STATUS})"
    log "Error Response: ${HTTP_BODY}"
    echo ""
    echo "${RED}ERROR: API call failed (HTTP ${HTTP_STATUS})${NC}"
    echo "Error Response:"
    echo "${HTTP_BODY}"
    echo ""
    echo "========================================"
    echo "END - User Creation Process (FAILED)"
    echo "Duration: ${DURATION} seconds"
    echo "========================================"
    exit 1
fi
