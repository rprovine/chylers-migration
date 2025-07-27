# Chyler's Hawaiian Beef Chips - Data Migration Plan

## Overview
This document outlines the complete data migration strategy for preserving all existing functionality and data during the Chyler's website rebuild.

## Phase 1: Data Export Strategy

### 1.1 Customer Data Export
```sql
-- Export all customer accounts
SELECT 
    customer_id,
    email,
    password_hash,
    first_name,
    last_name,
    phone,
    created_at,
    last_login,
    email_opt_in,
    sms_opt_in,
    loyalty_points,
    customer_group,
    tags,
    notes
FROM customers
ORDER BY customer_id;

-- Export customer addresses
SELECT 
    address_id,
    customer_id,
    address_type,
    first_name,
    last_name,
    company,
    address_line1,
    address_line2,
    city,
    state,
    zip,
    country,
    phone,
    is_default
FROM customer_addresses
ORDER BY customer_id, address_id;
```

### 1.2 Product Catalog Export
```sql
-- Export all products
SELECT 
    product_id,
    sku,
    name,
    slug,
    description,
    short_description,
    status,
    visibility,
    featured,
    weight,
    dimensions,
    created_at,
    updated_at
FROM products;

-- Export product variants (flavors/sizes)
SELECT 
    variant_id,
    product_id,
    sku,
    name,
    price,
    compare_price,
    cost,
    weight,
    inventory_quantity,
    inventory_policy,
    barcode,
    requires_shipping,
    taxable
FROM product_variants;

-- Export product images
SELECT 
    image_id,
    product_id,
    variant_id,
    image_url,
    alt_text,
    position,
    width,
    height
FROM product_images;

-- Export product categories
SELECT 
    category_id,
    parent_id,
    name,
    slug,
    description,
    image_url,
    position,
    is_active
FROM categories;
```

### 1.3 Order History Export
```sql
-- Export all orders
SELECT 
    order_id,
    order_number,
    customer_id,
    email,
    status,
    financial_status,
    fulfillment_status,
    currency,
    subtotal,
    tax_total,
    shipping_total,
    discount_total,
    total,
    payment_method,
    shipping_method,
    notes,
    created_at,
    updated_at
FROM orders;

-- Export order items
SELECT 
    order_item_id,
    order_id,
    product_id,
    variant_id,
    sku,
    name,
    quantity,
    price,
    discount,
    tax,
    total
FROM order_items;

-- Export order shipping info
SELECT 
    shipping_id,
    order_id,
    tracking_number,
    carrier,
    shipped_at,
    delivered_at,
    shipping_address,
    will_call_pickup
FROM order_shipping;
```

### 1.4 Content and SEO Export
```sql
-- Export page content
SELECT 
    page_id,
    title,
    slug,
    content,
    meta_title,
    meta_description,
    meta_keywords,
    canonical_url,
    status,
    created_at,
    updated_at
FROM pages;

-- Export URL redirects
SELECT 
    old_url,
    new_url,
    redirect_type,
    created_at
FROM url_redirects;
```

## Phase 2: Export Scripts

### Script 1: Customer Data Export
```bash
#!/bin/bash
# scripts/export/export_customers.sh

EXPORT_DIR="../../data/exports/customers"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Starting customer data export..."

# Create export directory
mkdir -p $EXPORT_DIR

# Export customers to CSV
echo "Exporting customer accounts..."
mysql -u $DB_USER -p$DB_PASS $DB_NAME \
  -e "SELECT * FROM customers" \
  --batch --raw > $EXPORT_DIR/customers_$TIMESTAMP.csv

# Export addresses
echo "Exporting customer addresses..."
mysql -u $DB_USER -p$DB_PASS $DB_NAME \
  -e "SELECT * FROM customer_addresses" \
  --batch --raw > $EXPORT_DIR/addresses_$TIMESTAMP.csv

# Create JSON export for easier import
echo "Creating JSON export..."
php export_customers_json.php > $EXPORT_DIR/customers_$TIMESTAMP.json

echo "Customer export complete!"
```

### Script 2: Product Catalog Export
```bash
#!/bin/bash
# scripts/export/export_products.sh

EXPORT_DIR="../../data/exports/products"
IMAGE_DIR="../../data/exports/product_images"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Starting product catalog export..."

# Create directories
mkdir -p $EXPORT_DIR
mkdir -p $IMAGE_DIR

# Export product data
echo "Exporting products..."
mysqldump -u $DB_USER -p$DB_PASS $DB_NAME \
  products product_variants product_categories \
  product_images product_attributes \
  --no-create-info --complete-insert \
  > $EXPORT_DIR/products_$TIMESTAMP.sql

# Download all product images
echo "Downloading product images..."
php download_product_images.php $IMAGE_DIR

# Create product catalog JSON
echo "Creating product catalog JSON..."
php export_products_json.php > $EXPORT_DIR/catalog_$TIMESTAMP.json

echo "Product export complete!"
```

### Script 3: Order History Export
```bash
#!/bin/bash
# scripts/export/export_orders.sh

EXPORT_DIR="../../data/exports/orders"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Starting order history export..."

mkdir -p $EXPORT_DIR

# Export orders with related data
echo "Exporting orders..."
mysqldump -u $DB_USER -p$DB_PASS $DB_NAME \
  orders order_items order_shipping order_payments \
  order_discounts order_taxes order_notes \
  --no-create-info --complete-insert \
  > $EXPORT_DIR/orders_$TIMESTAMP.sql

# Create order summary report
echo "Creating order summary..."
mysql -u $DB_USER -p$DB_PASS $DB_NAME \
  -e "SELECT COUNT(*) as total_orders, 
      SUM(total) as lifetime_value,
      AVG(total) as avg_order_value
      FROM orders" \
  > $EXPORT_DIR/order_summary_$TIMESTAMP.txt

echo "Order export complete!"
```

## Phase 3: Data Validation Checklists

### Pre-Migration Validation
```bash
#!/bin/bash
# scripts/validation/pre_migration_check.sh

echo "=== Pre-Migration Data Validation ==="

# Count records in source
echo "Source Database Counts:"
echo "Customers: $(mysql -N -e 'SELECT COUNT(*) FROM customers')"
echo "Products: $(mysql -N -e 'SELECT COUNT(*) FROM products')"
echo "Orders: $(mysql -N -e 'SELECT COUNT(*) FROM orders')"
echo "Addresses: $(mysql -N -e 'SELECT COUNT(*) FROM customer_addresses')"

# Check for data integrity
echo -e "\nData Integrity Checks:"
echo "Orders without customers: $(mysql -N -e 'SELECT COUNT(*) FROM orders WHERE customer_id NOT IN (SELECT customer_id FROM customers)')"
echo "Products without SKUs: $(mysql -N -e 'SELECT COUNT(*) FROM products WHERE sku IS NULL OR sku = ""')"

# Generate checksums
echo -e "\nGenerating data checksums..."
mysql -e "CHECKSUM TABLE customers, products, orders, customer_addresses"
```

### Post-Migration Validation
```bash
#!/bin/bash
# scripts/validation/post_migration_check.sh

echo "=== Post-Migration Data Validation ==="

# Compare record counts
echo "Comparing record counts..."
./compare_record_counts.sh

# Verify critical data
echo -e "\nVerifying critical data..."
# Check customer login capability
./test_customer_logins.sh

# Verify product catalog
./verify_product_catalog.sh

# Test order history access
./verify_order_history.sh

# Check URL redirects
./test_url_redirects.sh
```

## Phase 4: Critical Data Preservation

### 4.1 Customer Authentication
- Password hashes must be preserved exactly
- Salt values must be maintained
- Password reset tokens should be invalidated
- Remember me tokens should be cleared

### 4.2 Order Integrity
- Order numbers must remain unchanged
- Order status history must be preserved
- Payment records must be maintained
- Refund/return records must be included

### 4.3 Product Relationships
- Product-category associations
- Product variants and options
- Related products/cross-sells
- Product reviews and ratings

### 4.4 SEO Preservation
- URL structure must be maintained or redirected
- Meta data must be preserved
- Sitemap must be regenerated
- Search engine rankings must be protected

## Phase 5: Migration Execution Plan

### Step 1: Full Backup (T-7 days)
1. Complete database backup
2. File system backup (images, documents)
3. Configuration backup
4. Verify backup integrity

### Step 2: Test Migration (T-5 days)
1. Set up staging environment
2. Run migration scripts
3. Validate all data
4. Test all functionality
5. Performance testing

### Step 3: Final Data Sync (T-1 day)
1. Freeze current site (maintenance mode)
2. Export final data changes
3. Sync to new platform
4. Final validation

### Step 4: DNS Cutover (T-0)
1. Update DNS records
2. Monitor traffic flow
3. Test all critical paths
4. Monitor error logs

### Step 5: Post-Migration (T+1)
1. Remove maintenance mode
2. Monitor site performance
3. Check analytics tracking
4. Verify order processing
5. Customer communication

## Data Security During Migration

### Encryption Requirements
- All exports must be encrypted at rest
- Use secure transfer protocols (SFTP/SCP)
- Limit access to migration team only
- Audit all data access

### PII Protection
- Mask sensitive data in dev/staging
- Use tokenization for payment data
- Comply with PCI DSS requirements
- Document data handling procedures

### Backup Retention
- Keep source backups for 90 days
- Daily backups during migration
- Test restore procedures
- Document backup locations

## Rollback Plan

### Immediate Rollback (0-4 hours)
1. Revert DNS changes
2. Restore original site
3. Communicate with customers
4. Investigate issues

### Delayed Rollback (4-24 hours)
1. Sync new data back to old platform
2. Merge customer changes
3. Process pending orders
4. Plan corrective migration

## Success Criteria

### Technical Metrics
- [ ] 100% of customers can log in
- [ ] All products display correctly
- [ ] Order history is complete
- [ ] Payment processing works
- [ ] Shipping calculations accurate
- [ ] No 404 errors from old URLs

### Business Metrics
- [ ] No decrease in conversion rate
- [ ] Page load time ≤ 3 seconds
- [ ] Mobile score ≥ 90
- [ ] Zero data loss
- [ ] No security vulnerabilities