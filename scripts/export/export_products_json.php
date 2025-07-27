<?php
/**
 * Export Products to JSON Format
 * 
 * This script exports the complete product catalog including
 * variants, images, categories, and attributes.
 */

// Database configuration
$config = [
    'host' => getenv('DB_HOST') ?: 'localhost',
    'user' => getenv('DB_USER') ?: 'root',
    'pass' => getenv('DB_PASS') ?: '',
    'name' => getenv('DB_NAME') ?: 'chylers_db'
];

try {
    $pdo = new PDO(
        "mysql:host={$config['host']};dbname={$config['name']};charset=utf8mb4",
        $config['user'],
        $config['pass'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    // Fetch all active products
    $productsStmt = $pdo->query("
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
            weight_unit,
            created_at,
            updated_at,
            meta_title,
            meta_description,
            made_in_hawaii,
            ingredients,
            nutrition_facts,
            allergen_info,
            shelf_life
        FROM products
        WHERE status = 'active'
        ORDER BY product_id
    ");

    $products = [];

    while ($product = $productsStmt->fetch(PDO::FETCH_ASSOC)) {
        // Fetch variants (flavors and sizes)
        $variantStmt = $pdo->prepare("
            SELECT 
                variant_id,
                sku,
                name,
                flavor,
                size,
                price,
                compare_price,
                cost,
                weight,
                barcode,
                inventory_quantity,
                inventory_policy,
                requires_shipping,
                taxable,
                is_default
            FROM product_variants
            WHERE product_id = ?
            ORDER BY is_default DESC, position
        ");
        $variantStmt->execute([$product['product_id']]);
        $product['variants'] = $variantStmt->fetchAll(PDO::FETCH_ASSOC);

        // Fetch product images
        $imageStmt = $pdo->prepare("
            SELECT 
                image_id,
                variant_id,
                image_url,
                alt_text,
                position,
                width,
                height,
                is_primary
            FROM product_images
            WHERE product_id = ?
            ORDER BY is_primary DESC, position
        ");
        $imageStmt->execute([$product['product_id']]);
        $product['images'] = $imageStmt->fetchAll(PDO::FETCH_ASSOC);

        // Fetch categories
        $categoryStmt = $pdo->prepare("
            SELECT 
                c.category_id,
                c.name,
                c.slug,
                c.parent_id
            FROM categories c
            JOIN product_categories pc ON c.category_id = pc.category_id
            WHERE pc.product_id = ?
        ");
        $categoryStmt->execute([$product['product_id']]);
        $product['categories'] = $categoryStmt->fetchAll(PDO::FETCH_ASSOC);

        // Fetch custom attributes
        $attrStmt = $pdo->prepare("
            SELECT 
                attribute_name,
                attribute_value
            FROM product_attributes
            WHERE product_id = ?
        ");
        $attrStmt->execute([$product['product_id']]);
        $attributes = [];
        while ($attr = $attrStmt->fetch(PDO::FETCH_ASSOC)) {
            $attributes[$attr['attribute_name']] = $attr['attribute_value'];
        }
        $product['attributes'] = $attributes;

        // Fetch related products
        $relatedStmt = $pdo->prepare("
            SELECT 
                related_product_id,
                relationship_type
            FROM product_relationships
            WHERE product_id = ?
        ");
        $relatedStmt->execute([$product['product_id']]);
        $product['related_products'] = $relatedStmt->fetchAll(PDO::FETCH_ASSOC);

        $products[] = $product;
    }

    // Fetch all categories for hierarchy
    $categoriesStmt = $pdo->query("
        SELECT 
            category_id,
            parent_id,
            name,
            slug,
            description,
            image_url,
            position,
            is_active
        FROM categories
        ORDER BY parent_id, position
    ");
    $categories = $categoriesStmt->fetchAll(PDO::FETCH_ASSOC);

    // Create export structure
    $export = [
        'export_date' => date('Y-m-d H:i:s'),
        'export_type' => 'product_catalog',
        'total_products' => count($products),
        'total_categories' => count($categories),
        'platform' => 'chylers_legacy',
        'data' => [
            'products' => $products,
            'categories' => $categories
        ]
    ];

    echo json_encode($export, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);

} catch (Exception $e) {
    error_log("Product export error: " . $e->getMessage());
    exit(1);
}