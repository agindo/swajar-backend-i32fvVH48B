#!/bin/bash

##############################################
# Script untuk Create Users from Certificates
# File ini akan memanggil API endpoint untuk
# create user dari certificate berdasarkan
# instansi dan number yang ditentukan
##############################################

# Configuration
API_URL="http://localhost:8071/api/certificates/create-users"
LOG_FILE="./logs/create-users-from-certificates.log"

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create logs directory if not exists
mkdir -p "./logs"

# Function to log messages (append to single log file)
log_to_file() {
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

# Function to log info
log_info() {
    echo -e "${BLUE}[INFO]${NC} $@"
    log_to_file "[INFO] $@"
}

# Function to log success
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $@"
    log_to_file "[SUCCESS] $@"
}

# Function to log warning
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $@"
    log_to_file "[WARNING] $@"
}

# Function to log error
log_error() {
    echo -e "${RED}[ERROR]${NC} $@"
    log_to_file "[ERROR] $@"
}

# Print header
echo "========================================" | tee -a "$LOG_FILE"
echo "Create Users from Certificates Script" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
log_info "Log file: $LOG_FILE"
echo ""

# Get parameters from arguments or use defaults
if [ $# -eq 3 ]; then
    INSTANSI=$1
    NUMBER=$2
    DETERMINE=$3
else
    # Use defaults
    INSTANSI="Lembaga Administrasi Negara"
    NUMBER="2022"
    DETERMINE=0
    
    log_warning "No instansi/number/determine provided, using defaults: '$INSTANSI' / $NUMBER / $DETERMINE"
    echo ""
fi

# Validate number (should be 4-digit string)
if ! [[ "$NUMBER" =~ ^[0-9]{4}$ ]]; then
    log_error "Invalid number: $NUMBER (must be a 4-digit string from NIP)"
    exit 1
fi

# Validate determine (should be 0 or 1)
if [ "$DETERMINE" -ne 0 ] && [ "$DETERMINE" -ne 1 ]; then
    log_error "Invalid determine: $DETERMINE (must be 0 or 1)"
    exit 1
fi

# Prepare request body
REQUEST_BODY=$(cat <<EOF
{
  "instansi": "$INSTANSI",
  "number": "$NUMBER",
  "determine": $DETERMINE
}
EOF
)

log_info "API URL: $API_URL"
log_info "Request Parameters:"
log_info "  - Instansi: $INSTANSI"
log_info "  - Number: $NUMBER"
log_info "  - Determine: $DETERMINE"
echo ""

# Call the API
log_info "Calling API endpoint..."
log_info "Starting user creation process at $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Execute curl and capture response
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY")

# Split response body and status code
HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n 1)

# Log raw response for debugging
log_info "HTTP Status Code: $HTTP_STATUS"
echo ""

# Check HTTP status
if [ "$HTTP_STATUS" -eq 200 ]; then
    log_success "API call successful!"
    
    # Parse and display results
    echo ""
    log_info "API Response:"
    echo "----------------------------------------" | tee -a "$LOG_FILE"
    echo "$HTTP_BODY" | tee -a "$LOG_FILE"
    echo "----------------------------------------" | tee -a "$LOG_FILE"
    echo ""
    
    # Extract statistics using grep and sed (works without jq)
    SUCCESS_COUNT=$(echo "$HTTP_BODY" | grep -o '"successCount":[0-9]*' | grep -o '[0-9]*')
    FAILED_COUNT=$(echo "$HTTP_BODY" | grep -o '"failedCount":[0-9]*' | grep -o '[0-9]*')
    ALREADY_EXIST_COUNT=$(echo "$HTTP_BODY" | grep -o '"alreadyExistCount":[0-9]*' | grep -o '[0-9]*')
    TOTAL=$(echo "$HTTP_BODY" | grep -o '"totalProcessed":[0-9]*' | grep -o '[0-9]*')
    
    log_info "Summary:"
    log_success "  ✓ Successfully created: $SUCCESS_COUNT users"
    log_error "    ✗ Failed: $FAILED_COUNT"
    log_warning "    ⊗ Already exist: $ALREADY_EXIST_COUNT"
    log_info "  Total processed: $TOTAL certificates"
    
    echo ""
    log_success "User creation process completed successfully!"
    
elif [ "$HTTP_STATUS" -eq 400 ]; then
    log_error "Bad Request - Check parameters"
    echo ""
    echo "$HTTP_BODY" | tee -a "$LOG_FILE"
    exit 1
    
elif [ "$HTTP_STATUS" -eq 500 ]; then
    log_error "Internal Server Error"
    echo ""
    echo "$HTTP_BODY" | tee -a "$LOG_FILE"
    exit 1
    
else
    log_error "Unexpected HTTP status: $HTTP_STATUS"
    echo ""
    echo "$HTTP_BODY" | tee -a "$LOG_FILE"
    exit 1
fi

echo ""
log_info "Process finished at $(date '+%Y-%m-%d %H:%M:%S')"
log_info "Full log saved to: $LOG_FILE"
echo ""

exit 0
