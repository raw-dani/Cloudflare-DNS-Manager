-- Cloudflare DNS Manager Module - Database Installation
-- Run this SQL script to create the required database table

CREATE TABLE IF NOT EXISTS `mod_cfdnsmanager_records` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `serviceid` int(11) NOT NULL,
    `cloudflare_record_id` varchar(255) DEFAULT NULL,
    `type` varchar(10) NOT NULL,
    `name` varchar(255) NOT NULL,
    `content` text NOT NULL,
    `ttl` int(11) NOT NULL DEFAULT 1,
    `priority` int(11) NOT NULL DEFAULT 0,
    `sync_status` enum('pending','synced','failed','scanned') NOT NULL DEFAULT 'pending',
    `sync_error` text,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `synced_at` timestamp NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `serviceid_sync_status` (`serviceid`,`sync_status`),
    KEY `cloudflare_record_id` (`cloudflare_record_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Optional: Add some sample data for testing (remove in production)
-- INSERT INTO `mod_cfdnsmanager_records` (`serviceid`, `type`, `name`, `content`, `ttl`, `sync_status`) VALUES
-- (1, 'A', 'test.example.com', '192.168.1.1', 1, 'pending');