#!/bin/bash

###############################################################################
# Peserta Creation - Manual Execution Script
# Purpose: Create peserta records from course data via BKN API
# Usage: ./run-peserta-creation.sh [year] [monthMod]
# Example: ./run-peserta-creation.sh 2022 1
###############################################################################

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
API_HOST="http://localhost:8071"
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/peserta-creation.log"

# Parameters (with defaults)
YEAR="${1:-2022}"
MONTH_MOD="${2:-1}"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    log "ERROR: $1"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
    log "INFO: $1"
}

# Start
echo "═══════════════════════════════════════════════════════════════="
echo "═══════════════════════════════════════════════════════════════=" >> "${LOG_FILE}"
print_info "Starting Peserta Creation Process"
print_info "Year: ${YEAR}"
echo "═══════════════════════════════════════════════════════════════="
echo "═══════════════════════════════════════════════════════════════=" >> "${LOG_FILE}"

# Check if API is reachable
print_info "Checking API health..."
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "${API_HOST}/api/peserta/health")

if [ "$HEALTH_CHECK" != "200" ]; then
    print_error "API is not reachable (HTTP ${HEALTH_CHECK}). Please check if the application is running."
    exit 1
fi

print_success "API is healthy"

# Execute peserta creation
print_info "Calling peserta creation API..."
print_info "Endpoint: ${API_HOST}/api/peserta/create-from-course?year=${YEAR}"

RESPONSE=$(curl -s -X GET \
    "${API_HOST}/api/peserta/create-from-course?year=${YEAR}" \
    -H "Content-Type: application/json")

# Check if curl was successful
if [ $? -ne 0 ]; then
    print_error "Failed to execute API call"
    exit 1
fi

# Parse response
print_info "API Response:"
FORMATTED_JSON=$(echo "${RESPONSE}" | jq '.' 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "${FORMATTED_JSON}"
    echo "${FORMATTED_JSON}" >> "${LOG_FILE}"
else
    echo "${RESPONSE}"
    echo "${RESPONSE}" >> "${LOG_FILE}"
fi

# Extract summary if jq is available
if command -v jq &> /dev/null; then
    TOTAL=$(echo "${RESPONSE}" | jq -r '.data.totalCourseRecords // 0')
    PROCESSED=$(echo "${RESPONSE}" | jq -r '.data.processedCount // 0')
    CREATED=$(echo "${RESPONSE}" | jq -r '.data.createdCount // 0')
    SKIPPED=$(echo "${RESPONSE}" | jq -r '.data.skippedCount // 0')
    ERRORS=$(echo "${RESPONSE}" | jq -r '.data.errorCount // 0')
    
    echo "════════════════════════════════════════════════════════════════"
    echo "════════════════════════════════════════════════════════════════" >> "${LOG_FILE}"
    print_success "Peserta Creation Summary:"
    echo "  Total Course Records : ${TOTAL}" | tee -a "${LOG_FILE}"
    echo "  Processed            : ${PROCESSED}" | tee -a "${LOG_FILE}"
    echo "  Created              : ${CREATED}" | tee -a "${LOG_FILE}"
    echo "  Skipped (Exists)     : ${SKIPPED}" | tee -a "${LOG_FILE}"
    echo "  Errors               : ${ERRORS}" | tee -a "${LOG_FILE}"
    echo "════════════════════════════════════════════════════════════════"
    echo "════════════════════════════════════════════════════════════════" >> "${LOG_FILE}"
fi

print_success "Peserta creation process completed!"
print_info "Check log file: ${LOG_FILE}"
