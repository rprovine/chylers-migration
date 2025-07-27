#!/bin/bash
# Pre-Migration Data Validation Script
# 
# This script performs comprehensive validation of all data
# before migration begins to ensure data integrity.

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DB_HOST=${DB_HOST:-localhost}
DB_USER=${DB_USER:-root}
DB_PASS=${DB_PASS:-}
DB_NAME=${DB_NAME:-chylers_db}

# MySQL command
MYSQL="mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME -N"

echo "======================================"
echo "Pre-Migration Data Validation"
echo "Database: $DB_NAME"
echo "Date: $(date)"
echo "======================================"
echo

# Function to run query and display result
check_count() {
    local table=$1
    local count=$($MYSQL -e "SELECT COUNT(*) FROM $table" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $table: $count records"
    else
        echo -e "${RED}✗${NC} $table: ERROR"
    fi
}

# Function to check for issues
check_issue() {
    local description=$1
    local query=$2
    local count=$($MYSQL -e "$query" 2>/dev/null)
    if [ $? -eq 0 ]; then
        if [ "$count" -gt 0 ]; then
            echo -e "${RED}⚠${NC}  $description: $count issues found"
        else
            echo -e "${GREEN}✓${NC} $description: OK"
        fi
    else
        echo -e "${RED}✗${NC} $description: ERROR"
    fi
}

echo "1. Database Record Counts"
echo "------------------------"
check_count "customers"
check_count "customer_addresses"
check_count "products"
check_count "product_variants"
check_count "product_images"
check_count "categories"
check_count "orders"
check_count "order_items"
echo

echo "2. Data Integrity Checks"
echo "------------------------"
check_issue "Duplicate customer emails" \
    "SELECT COUNT(*) FROM (SELECT email FROM customers GROUP BY email HAVING COUNT(*) > 1) AS dupes"

check_issue "Orders without customers" \
    "SELECT COUNT(*) FROM orders WHERE customer_id NOT IN (SELECT customer_id FROM customers)"

check_issue "Order items without products" \
    "SELECT COUNT(*) FROM order_items WHERE product_id NOT IN (SELECT product_id FROM products)"

check_issue "Products without SKUs" \
    "SELECT COUNT(*) FROM products WHERE sku IS NULL OR sku = ''"

check_issue "Products without prices" \
    "SELECT COUNT(*) FROM product_variants WHERE price IS NULL OR price <= 0"

check_issue "Invalid email addresses" \
    "SELECT COUNT(*) FROM customers WHERE email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'"

check_issue "Orphaned product images" \
    "SELECT COUNT(*) FROM product_images WHERE product_id NOT IN (SELECT product_id FROM products)"

check_issue "Empty customer names" \
    "SELECT COUNT(*) FROM customers WHERE (first_name IS NULL OR first_name = '') AND (last_name IS NULL OR last_name = '')"
echo

echo "3. Critical Business Data"
echo "------------------------"
# Active products
ACTIVE_PRODUCTS=$($MYSQL -e "SELECT COUNT(*) FROM products WHERE status = 'active'" 2>/dev/null)
echo "Active products: $ACTIVE_PRODUCTS"

# Products with inventory
IN_STOCK=$($MYSQL -e "SELECT COUNT(*) FROM product_variants WHERE inventory_quantity > 0" 2>/dev/null)
echo "Products in stock: $IN_STOCK"

# Recent orders
RECENT_ORDERS=$($MYSQL -e "SELECT COUNT(*) FROM orders WHERE created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)" 2>/dev/null)
echo "Orders (last 30 days): $RECENT_ORDERS"

# Active customers
ACTIVE_CUSTOMERS=$($MYSQL -e "SELECT COUNT(*) FROM customers WHERE last_login > DATE_SUB(NOW(), INTERVAL 90 DAY)" 2>/dev/null)
echo "Active customers (90 days): $ACTIVE_CUSTOMERS"
echo

echo "4. Data Size Analysis"
echo "--------------------"
# Table sizes
$MYSQL -e "
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.TABLES 
WHERE table_schema = '$DB_NAME'
ORDER BY (data_length + index_length) DESC
LIMIT 10" | column -t
echo

echo "5. Generating Checksums"
echo "-----------------------"
# Generate checksums for critical tables
for table in customers products orders order_items; do
    checksum=$($MYSQL -e "CHECKSUM TABLE $table" | awk '{print $2}')
    echo "$table checksum: $checksum"
done
echo

echo "6. Export Readiness"
echo "------------------"
# Check for required fields
echo -n "Checking customer email field... "
$MYSQL -e "DESCRIBE customers email" >/dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${RED}MISSING${NC}"

echo -n "Checking product SKU field... "
$MYSQL -e "DESCRIBE products sku" >/dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${RED}MISSING${NC}"

echo -n "Checking order number field... "
$MYSQL -e "DESCRIBE orders order_number" >/dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${RED}MISSING${NC}"
echo

echo "7. Creating Validation Report"
echo "----------------------------"
REPORT_FILE="../../data/validation_report_$(date +%Y%m%d_%H%M%S).txt"
{
    echo "Pre-Migration Validation Report"
    echo "Generated: $(date)"
    echo "Database: $DB_NAME"
    echo
    echo "Summary:"
    echo "- Total Customers: $($MYSQL -e 'SELECT COUNT(*) FROM customers')"
    echo "- Total Products: $($MYSQL -e 'SELECT COUNT(*) FROM products')"
    echo "- Total Orders: $($MYSQL -e 'SELECT COUNT(*) FROM orders')"
    echo "- Database Size: $($MYSQL -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE table_schema = '$DB_NAME'")"
} > "$REPORT_FILE"

echo -e "${GREEN}✓${NC} Validation report saved to: $REPORT_FILE"
echo

echo "======================================"
echo "Validation Complete"
echo "======================================"

# Exit with error if critical issues found
if [ "$ACTIVE_PRODUCTS" -eq 0 ]; then
    echo -e "${RED}ERROR: No active products found!${NC}"
    exit 1
fi

echo -e "${GREEN}Ready for migration${NC}"