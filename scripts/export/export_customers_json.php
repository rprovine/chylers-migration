<?php
/**
 * Export Customers to JSON Format
 * 
 * This script exports all customer data including addresses, 
 * order history references, and preferences to a JSON file
 * for easy import into the new platform.
 */

// Database configuration
$config = [
    'host' => getenv('DB_HOST') ?: 'localhost',
    'user' => getenv('DB_USER') ?: 'root',
    'pass' => getenv('DB_PASS') ?: '',
    'name' => getenv('DB_NAME') ?: 'chylers_db'
];

try {
    // Connect to database
    $pdo = new PDO(
        "mysql:host={$config['host']};dbname={$config['name']};charset=utf8mb4",
        $config['user'],
        $config['pass'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    // Fetch all customers
    $customersStmt = $pdo->query("
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
            notes,
            is_active
        FROM customers
        WHERE is_active = 1
        ORDER BY customer_id
    ");

    $customers = [];

    while ($customer = $customersStmt->fetch(PDO::FETCH_ASSOC)) {
        // Fetch addresses for this customer
        $addressStmt = $pdo->prepare("
            SELECT 
                address_id,
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
            WHERE customer_id = ?
            ORDER BY is_default DESC, address_id
        ");
        $addressStmt->execute([$customer['customer_id']]);
        $customer['addresses'] = $addressStmt->fetchAll(PDO::FETCH_ASSOC);

        // Fetch order summary for this customer
        $orderStmt = $pdo->prepare("
            SELECT 
                COUNT(*) as total_orders,
                SUM(total) as lifetime_value,
                MAX(created_at) as last_order_date,
                AVG(total) as average_order_value
            FROM orders
            WHERE customer_id = ?
            AND status NOT IN ('cancelled', 'failed')
        ");
        $orderStmt->execute([$customer['customer_id']]);
        $customer['order_summary'] = $orderStmt->fetch(PDO::FETCH_ASSOC);

        // Fetch saved payment methods (tokenized)
        $paymentStmt = $pdo->prepare("
            SELECT 
                payment_method_id,
                type,
                last_four,
                card_brand,
                exp_month,
                exp_year,
                is_default,
                created_at
            FROM customer_payment_methods
            WHERE customer_id = ?
            AND is_active = 1
        ");
        $paymentStmt->execute([$customer['customer_id']]);
        $customer['payment_methods'] = $paymentStmt->fetchAll(PDO::FETCH_ASSOC);

        // Add to customers array
        $customers[] = $customer;
    }

    // Create export structure
    $export = [
        'export_date' => date('Y-m-d H:i:s'),
        'export_type' => 'customers',
        'total_records' => count($customers),
        'platform' => 'chylers_legacy',
        'data' => $customers
    ];

    // Output as JSON
    echo json_encode($export, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);

} catch (Exception $e) {
    error_log("Customer export error: " . $e->getMessage());
    exit(1);
}