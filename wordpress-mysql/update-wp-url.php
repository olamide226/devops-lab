<?php
// WordPress database settings from wp-config.php
require_once('/var/www/html/wp-config.php');

// Connect to the database
$connection = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);

if ($connection->connect_error) {
    die("Connection failed: " . $connection->connect_error);
}

// Get the external IP address
$external_ip = '192.168.107.202';

// Update the WordPress site URL and home URL
$connection->query("UPDATE {$table_prefix}options SET option_value = 'http://{$external_ip}:8080' WHERE option_name = 'siteurl'");
$connection->query("UPDATE {$table_prefix}options SET option_value = 'http://{$external_ip}:8080' WHERE option_name = 'home'");

echo "WordPress URLs updated to http://{$external_ip}:8080\n";

$connection->close();
?>
