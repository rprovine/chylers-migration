<?php
/**
 * Download All Product Images
 * 
 * This script downloads all product images from the current
 * platform and organizes them for migration.
 */

if ($argc < 2) {
    echo "Usage: php download_product_images.php <output_directory>\n";
    exit(1);
}

$outputDir = $argv[1];

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

    // Create output directory structure
    if (!is_dir($outputDir)) {
        mkdir($outputDir, 0755, true);
    }

    // Fetch all product images
    $stmt = $pdo->query("
        SELECT 
            pi.image_id,
            pi.product_id,
            pi.variant_id,
            pi.image_url,
            pi.alt_text,
            p.sku as product_sku,
            pv.sku as variant_sku
        FROM product_images pi
        JOIN products p ON pi.product_id = p.product_id
        LEFT JOIN product_variants pv ON pi.variant_id = pv.variant_id
        ORDER BY pi.product_id, pi.position
    ");

    $downloadedImages = [];
    $errors = [];

    while ($image = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $productDir = $outputDir . '/' . $image['product_sku'];
        if (!is_dir($productDir)) {
            mkdir($productDir, 0755, true);
        }

        // Determine filename
        $urlParts = parse_url($image['image_url']);
        $filename = basename($urlParts['path']);
        
        // Add variant SKU to filename if applicable
        if ($image['variant_sku']) {
            $info = pathinfo($filename);
            $filename = $info['filename'] . '_' . $image['variant_sku'] . '.' . $info['extension'];
        }

        $localPath = $productDir . '/' . $filename;

        // Download image
        $ch = curl_init($image['image_url']);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        
        $imageData = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode == 200 && $imageData) {
            file_put_contents($localPath, $imageData);
            $downloadedImages[] = [
                'image_id' => $image['image_id'],
                'original_url' => $image['image_url'],
                'local_path' => $localPath,
                'product_sku' => $image['product_sku'],
                'variant_sku' => $image['variant_sku'],
                'alt_text' => $image['alt_text']
            ];
            echo "Downloaded: {$image['image_url']} -> $localPath\n";
        } else {
            $errors[] = [
                'image_id' => $image['image_id'],
                'url' => $image['image_url'],
                'error' => "HTTP $httpCode"
            ];
            echo "Error downloading: {$image['image_url']} (HTTP $httpCode)\n";
        }
    }

    // Save manifest
    $manifest = [
        'download_date' => date('Y-m-d H:i:s'),
        'total_images' => count($downloadedImages),
        'errors' => count($errors),
        'images' => $downloadedImages,
        'failed_downloads' => $errors
    ];

    file_put_contents(
        $outputDir . '/image_manifest.json',
        json_encode($manifest, JSON_PRETTY_PRINT)
    );

    echo "\nDownload complete!\n";
    echo "Total images: " . count($downloadedImages) . "\n";
    echo "Errors: " . count($errors) . "\n";

} catch (Exception $e) {
    error_log("Image download error: " . $e->getMessage());
    exit(1);
}