#!/bin/bash
# Post-Migration Verification Script
#
# This script verifies that all data has been successfully
# migrated to the new platform without loss.

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration for OLD database
OLD_DB_HOST=${OLD_DB_HOST:-localhost}
OLD_DB_USER=${OLD_DB_USER:-root}
OLD_DB_PASS=${OLD_DB_PASS:-}
OLD_DB_NAME=${OLD_DB_NAME:-chylers_db}

# Configuration for NEW database
NEW_DB_HOST=${NEW_DB_HOST:-localhost}
NEW_DB_USER=${NEW_DB_USER:-root}
NEW_DB_PASS=${NEW_DB_PASS:-}
NEW_DB_NAME=${NEW_DB_NAME:-chylers_new}

# MySQL commands
OLD_MYSQL="mysql -h $OLD_DB_HOST -u $OLD_DB_USER -p$OLD_DB_PASS $OLD_DB_NAME -N"
NEW_MYSQL="mysql -h $NEW_DB_HOST -u $NEW_DB_USER -p$NEW_DB_PASS $NEW_DB_NAME -N"

echo "======================================"
echo "Post-Migration Verification"
echo "Old Database: $OLD_DB_NAME"
echo "New Database: $NEW_DB_NAME"
echo "Date: $(date)"
echo "======================================"
echo

# Function to compare counts
compare_counts() {
    local table=$1
    local old_count=$($OLD_MYSQL -e "SELECT COUNT(*) FROM $table" 2>/dev/null)
    local new_count=$($NEW_MYSQL -e "SELECT COUNT(*) FROM $table" 2>/dev/null)
    
    if [ "$old_count" -eq "$new_count" ]; then
        echo -e "${GREEN}✓${NC} $table: $old_count → $new_count (Match)"
    else
        echo -e "${RED}✗${NC} $table: $old_count → $new_count (Mismatch!)"
        ERRORS=$((ERRORS + 1))
    fi
}

# Function to compare checksums
compare_checksums() {
    local table=$1
    local old_checksum=$($OLD_MYSQL -e "CHECKSUM TABLE $table" | awk '{print $2}')
    local new_checksum=$($NEW_MYSQL -e "CHECKSUM TABLE $table" | awk '{print $2}')
    
    if [ "$old_checksum" = "$new_checksum" ]; then
        echo -e "${GREEN}✓${NC} $table checksum: Match"
    else
        echo -e "${YELLOW}⚠${NC}  $table checksum: Different (may be OK if structure changed)"
    fi
}

# Initialize error counter
ERRORS=0

echo "1. Record Count Comparison"
echo "--------------------------"
compare_counts "customers"
compare_counts "customer_addresses"
compare_counts "products"
compare_counts "product_variants"
compare_counts "product_images"
compare_counts "categories"
compare_counts "orders"
compare_counts "order_items"
echo

echo "2. Data Integrity Verification"
echo "------------------------------"
# Check for missing customers
echo -n "Checking for missing customers... "
MISSING_CUSTOMERS=$($OLD_MYSQL -e "SELECT COUNT(*) FROM customers WHERE customer_id NOT IN (SELECT customer_id FROM $NEW_DB_NAME.customers)" 2>/dev/null)
if [ "$MISSING_CUSTOMERS" -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}$MISSING_CUSTOMERS missing!${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check for missing orders
echo -n "Checking for missing orders... "
MISSING_ORDERS=$($OLD_MYSQL -e "SELECT COUNT(*) FROM orders WHERE order_id NOT IN (SELECT order_id FROM $NEW_DB_NAME.orders)" 2>/dev/null)
if [ "$MISSING_ORDERS" -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}$MISSING_ORDERS missing!${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check for missing products
echo -n "Checking for missing products... "
MISSING_PRODUCTS=$($OLD_MYSQL -e "SELECT COUNT(*) FROM products WHERE product_id NOT IN (SELECT product_id FROM $NEW_DB_NAME.products)" 2>/dev/null)
if [ "$MISSING_PRODUCTS" -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}$MISSING_PRODUCTS missing!${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo

echo "3. Critical Data Verification"
echo "-----------------------------"
# Verify order totals match
echo -n "Verifying order totals... "
OLD_TOTAL=$($OLD_MYSQL -e "SELECT SUM(total) FROM orders" 2>/dev/null)
NEW_TOTAL=$($NEW_MYSQL -e "SELECT SUM(total) FROM orders" 2>/dev/null)
if [ "$OLD_TOTAL" = "$NEW_TOTAL" ]; then
    echo -e "${GREEN}OK (\$$OLD_TOTAL)${NC}"
else
    echo -e "${RED}Mismatch! Old: \$$OLD_TOTAL, New: \$$NEW_TOTAL${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Verify customer emails
echo -n "Verifying customer emails... "
OLD_EMAILS=$($OLD_MYSQL -e "SELECT COUNT(DISTINCT email) FROM customers" 2>/dev/null)
NEW_EMAILS=$($NEW_MYSQL -e "SELECT COUNT(DISTINCT email) FROM customers" 2>/dev/null)
if [ "$OLD_EMAILS" = "$NEW_EMAILS" ]; then
    echo -e "${GREEN}OK ($OLD_EMAILS unique)${NC}"
else
    echo -e "${RED}Mismatch! Old: $OLD_EMAILS, New: $NEW_EMAILS${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Verify product SKUs
echo -n "Verifying product SKUs... "
OLD_SKUS=$($OLD_MYSQL -e "SELECT COUNT(DISTINCT sku) FROM products WHERE sku IS NOT NULL" 2>/dev/null)
NEW_SKUS=$($NEW_MYSQL -e "SELECT COUNT(DISTINCT sku) FROM products WHERE sku IS NOT NULL" 2>/dev/null)
if [ "$OLD_SKUS" = "$NEW_SKUS" ]; then
    echo -e "${GREEN}OK ($OLD_SKUS unique)${NC}"
else
    echo -e "${RED}Mismatch! Old: $OLD_SKUS, New: $NEW_SKUS${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo

echo "4. Sample Data Comparison"
echo "-------------------------"
# Compare a few random customers
echo "Sampling customer data..."
$OLD_MYSQL -e "SELECT customer_id, email FROM customers ORDER BY RAND() LIMIT 5" | while read id email; do
    NEW_EMAIL=$($NEW_MYSQL -e "SELECT email FROM customers WHERE customer_id = $id" 2>/dev/null)
    if [ "$email" = "$NEW_EMAIL" ]; then
        echo -e "  Customer $id: ${GREEN}✓${NC}"
    else
        echo -e "  Customer $id: ${RED}✗${NC} (email mismatch)"
        ERRORS=$((ERRORS + 1))
    fi
done

# Compare a few random orders
echo "Sampling order data..."
$OLD_MYSQL -e "SELECT order_id, order_number, total FROM orders ORDER BY RAND() LIMIT 5" | while read id number total; do
    NEW_TOTAL=$($NEW_MYSQL -e "SELECT total FROM orders WHERE order_id = $id" 2>/dev/null)
    if [ "$total" = "$NEW_TOTAL" ]; then
        echo -e "  Order $number: ${GREEN}✓${NC}"
    else
        echo -e "  Order $number: ${RED}✗${NC} (total mismatch)"
        ERRORS=$((ERRORS + 1))
    fi
done
echo

echo "5. Functional Testing"
echo "--------------------"
# Test URLs file exists
if [ -f "../../data/url_mapping.csv" ]; then
    echo -e "${GREEN}✓${NC} URL mapping file exists"
else
    echo -e "${YELLOW}⚠${NC}  URL mapping file not found"
fi

# Check for test results
if [ -f "../../data/functional_tests.log" ]; then
    echo -e "${GREEN}✓${NC} Functional tests completed"
    FAILED_TESTS=$(grep -c "FAILED" ../../data/functional_tests.log)
    if [ "$FAILED_TESTS" -gt 0 ]; then
        echo -e "${RED}  $FAILED_TESTS tests failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠${NC}  Functional tests not run"
fi
echo

echo "6. Performance Metrics"
echo "---------------------"
# Check database sizes
OLD_SIZE=$($OLD_MYSQL -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE table_schema = '$OLD_DB_NAME'" 2>/dev/null)
NEW_SIZE=$($NEW_MYSQL -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE table_schema = '$NEW_DB_NAME'" 2>/dev/null)
echo "Old database size: ${OLD_SIZE}MB"
echo "New database size: ${NEW_SIZE}MB"

# Size difference warning
SIZE_DIFF=$(echo "$NEW_SIZE - $OLD_SIZE" | bc)
if (( $(echo "$SIZE_DIFF > 100" | bc -l) )); then
    echo -e "${YELLOW}⚠${NC}  Size increased by more than 100MB"
elif (( $(echo "$SIZE_DIFF < -100" | bc -l) )); then
    echo -e "${YELLOW}⚠${NC}  Size decreased by more than 100MB"
else
    echo -e "${GREEN}✓${NC} Size difference within acceptable range"
fi
echo

echo "7. Generating Verification Report"
echo "---------------------------------"
REPORT_FILE="../../data/verification_report_$(date +%Y%m%d_%H%M%S).txt"
{
    echo "Post-Migration Verification Report"
    echo "Generated: $(date)"
    echo "Old Database: $OLD_DB_NAME"
    echo "New Database: $NEW_DB_NAME"
    echo
    echo "Summary:"
    echo "- Errors Found: $ERRORS"
    echo "- Old DB Size: ${OLD_SIZE}MB"
    echo "- New DB Size: ${NEW_SIZE}MB"
    echo
    echo "Record Counts:"
    echo "- Customers: $($OLD_MYSQL -e 'SELECT COUNT(*) FROM customers') → $($NEW_MYSQL -e 'SELECT COUNT(*) FROM customers')"
    echo "- Products: $($OLD_MYSQL -e 'SELECT COUNT(*) FROM products') → $($NEW_MYSQL -e 'SELECT COUNT(*) FROM products')"
    echo "- Orders: $($OLD_MYSQL -e 'SELECT COUNT(*) FROM orders') → $($NEW_MYSQL -e 'SELECT COUNT(*) FROM orders')"
} > "$REPORT_FILE"

echo -e "${GREEN}✓${NC} Verification report saved to: $REPORT_FILE"
echo

echo "======================================"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}Verification Complete - All Checks Passed!${NC}"
    exit 0
else
    echo -e "${RED}Verification Complete - $ERRORS Errors Found!${NC}"
    exit 1
fi