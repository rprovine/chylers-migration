#!/bin/bash
# Master Export Script for Chyler's Data Migration
#
# This script coordinates the complete data export process
# including all customer data, products, orders, and content.

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
EXPORT_BASE_DIR="../../data/exports"
BACKUP_DIR="../../data/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$EXPORT_BASE_DIR/export_log_$TIMESTAMP.txt"

# Database configuration
export DB_HOST=${DB_HOST:-localhost}
export DB_USER=${DB_USER:-root}
export DB_PASS=${DB_PASS:-}
export DB_NAME=${DB_NAME:-chylers_db}

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        log "✓ $1 completed successfully"
    else
        log "✗ $1 failed!"
        exit 1
    fi
}

# Create directory structure
echo -e "${YELLOW}Creating export directories...${NC}"
mkdir -p "$EXPORT_BASE_DIR"/{customers,products,orders,content,config}
mkdir -p "$BACKUP_DIR"
mkdir -p "$EXPORT_BASE_DIR/product_images"

# Initialize log file
echo "Chyler's Data Export Log" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "========================" >> "$LOG_FILE"

echo -e "${GREEN}=== Starting Complete Data Export ===${NC}"
log "Export process initiated"

# 1. Create full database backup first
echo -e "\n${YELLOW}Step 1: Creating full database backup${NC}"
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --complete-insert \
    --skip-lock-tables \
    | gzip > "$BACKUP_DIR/chylers_full_backup_$TIMESTAMP.sql.gz"
check_success "Full database backup"

# 2. Export customers
echo -e "\n${YELLOW}Step 2: Exporting customer data${NC}"
log "Starting customer export..."

# Export to SQL
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME \
    customers customer_addresses customer_payment_methods \
    --complete-insert --skip-lock-tables \
    > "$EXPORT_BASE_DIR/customers/customers_$TIMESTAMP.sql"
check_success "Customer SQL export"

# Export to JSON
php export_customers_json.php > "$EXPORT_BASE_DIR/customers/customers_$TIMESTAMP.json"
check_success "Customer JSON export"

# Export to CSV for Excel
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME -e \
    "SELECT 'customer_id','email','first_name','last_name','phone','created_at','last_login','email_opt_in','loyalty_points'
     UNION ALL
     SELECT customer_id,email,first_name,last_name,phone,created_at,last_login,email_opt_in,loyalty_points 
     FROM customers 
     INTO OUTFILE '/tmp/customers_$TIMESTAMP.csv' 
     FIELDS TERMINATED BY ',' 
     ENCLOSED BY '\"' 
     LINES TERMINATED BY '\n'"
mv "/tmp/customers_$TIMESTAMP.csv" "$EXPORT_BASE_DIR/customers/" 2>/dev/null || true

# 3. Export products
echo -e "\n${YELLOW}Step 3: Exporting product catalog${NC}"
log "Starting product export..."

# Export to SQL
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME \
    products product_variants product_images product_categories \
    categories product_attributes product_relationships \
    --complete-insert --skip-lock-tables \
    > "$EXPORT_BASE_DIR/products/products_$TIMESTAMP.sql"
check_success "Product SQL export"

# Export to JSON
php export_products_json.php > "$EXPORT_BASE_DIR/products/catalog_$TIMESTAMP.json"
check_success "Product JSON export"

# Download product images
echo -e "\n${YELLOW}Step 4: Downloading product images${NC}"
log "Starting image download..."
php download_product_images.php "$EXPORT_BASE_DIR/product_images"
check_success "Product image download"

# 4. Export orders
echo -e "\n${YELLOW}Step 5: Exporting order history${NC}"
log "Starting order export..."

# Export to SQL
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME \
    orders order_items order_shipping order_payments \
    order_discounts order_taxes order_notes \
    --complete-insert --skip-lock-tables \
    > "$EXPORT_BASE_DIR/orders/orders_$TIMESTAMP.sql"
check_success "Order SQL export"

# Export order summary
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME -e \
    "SELECT 
        DATE_FORMAT(created_at, '%Y-%m') as month,
        COUNT(*) as order_count,
        SUM(total) as revenue,
        AVG(total) as avg_order_value
     FROM orders 
     WHERE status NOT IN ('cancelled', 'failed')
     GROUP BY DATE_FORMAT(created_at, '%Y-%m')
     ORDER BY month DESC" \
    > "$EXPORT_BASE_DIR/orders/order_summary_$TIMESTAMP.txt"

# 5. Export content and SEO data
echo -e "\n${YELLOW}Step 6: Exporting content and SEO data${NC}"
log "Starting content export..."

# Export pages and SEO
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME \
    pages url_redirects meta_tags \
    --complete-insert --skip-lock-tables \
    > "$EXPORT_BASE_DIR/content/content_$TIMESTAMP.sql"
check_success "Content export"

# 6. Export configuration
echo -e "\n${YELLOW}Step 7: Exporting configuration${NC}"
log "Starting configuration export..."

# Export settings
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME \
    settings shipping_zones shipping_rates tax_rates \
    payment_gateways email_templates \
    --complete-insert --skip-lock-tables \
    > "$EXPORT_BASE_DIR/config/configuration_$TIMESTAMP.sql"
check_success "Configuration export"

# 7. Generate checksums
echo -e "\n${YELLOW}Step 8: Generating checksums${NC}"
log "Generating checksums for verification..."

{
    echo "Table Checksums for Migration Verification"
    echo "Generated: $(date)"
    echo "==========================================
"
    for table in customers products orders order_items; do
        checksum=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME -N -e "CHECKSUM TABLE $table" | awk '{print $2}')
        echo "$table: $checksum"
    done
} > "$EXPORT_BASE_DIR/checksums_$TIMESTAMP.txt"

# 8. Create manifest
echo -e "\n${YELLOW}Step 9: Creating export manifest${NC}"
log "Creating export manifest..."

{
    echo "Chyler's Data Export Manifest"
    echo "Export Date: $(date)"
    echo "Export ID: $TIMESTAMP"
    echo
    echo "Database Information:"
    echo "- Host: $DB_HOST"
    echo "- Database: $DB_NAME"
    echo
    echo "Exported Files:"
    find "$EXPORT_BASE_DIR" -type f -name "*$TIMESTAMP*" -exec ls -lh {} \; | awk '{print "- " $9 " (" $5 ")"}'
    echo
    echo "Record Counts:"
    echo "- Customers: $(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME -N -e 'SELECT COUNT(*) FROM customers')"
    echo "- Products: $(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME -N -e 'SELECT COUNT(*) FROM products')"
    echo "- Orders: $(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME -N -e 'SELECT COUNT(*) FROM orders')"
    echo "- Categories: $(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME -N -e 'SELECT COUNT(*) FROM categories')"
} > "$EXPORT_BASE_DIR/manifest_$TIMESTAMP.txt"

# 9. Compress exports
echo -e "\n${YELLOW}Step 10: Compressing exports${NC}"
log "Compressing export files..."

cd "$EXPORT_BASE_DIR"
tar -czf "chylers_export_$TIMESTAMP.tar.gz" \
    customers/*$TIMESTAMP* \
    products/*$TIMESTAMP* \
    orders/*$TIMESTAMP* \
    content/*$TIMESTAMP* \
    config/*$TIMESTAMP* \
    checksums_$TIMESTAMP.txt \
    manifest_$TIMESTAMP.txt
check_success "Export compression"

# Final summary
echo -e "\n${GREEN}=== Export Complete ===${NC}"
echo -e "Export ID: ${YELLOW}$TIMESTAMP${NC}"
echo -e "Files location: ${YELLOW}$EXPORT_BASE_DIR${NC}"
echo -e "Compressed archive: ${YELLOW}chylers_export_$TIMESTAMP.tar.gz${NC}"
echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"

# Display summary statistics
echo -e "\n${GREEN}Export Summary:${NC}"
tail -n 20 "$EXPORT_BASE_DIR/manifest_$TIMESTAMP.txt"

log "Export process completed successfully"