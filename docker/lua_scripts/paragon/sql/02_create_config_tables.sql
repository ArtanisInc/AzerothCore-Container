-- ============================================================================
-- Paragon System - Configuration Tables
-- ============================================================================
-- Creates all configuration tables for the Paragon system:
-- - paragon_config_category: Category definitions
-- - paragon_config_statistic: Stat configs with properties
-- - paragon_config: General key-value settings
-- ============================================================================

-- Category Configuration Table
-- Stores paragon statistic categories (e.g., Combat, Stats, etc.)
CREATE TABLE IF NOT EXISTS `acore_ale`.`paragon_config_category` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(50) NOT NULL,

    PRIMARY KEY (`id`)
);

-- Statistic Configuration Table
-- Defines available paragon statistics with their properties
-- type: AURA, COMBAT_RATING, or UNIT_MODS
-- factor: Multiplier for each point invested
-- limit: Maximum points that can be invested
-- application: How the stat bonus is applied
CREATE TABLE IF NOT EXISTS `acore_ale`.`paragon_config_statistic` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `category` INT NOT NULL DEFAULT 1,
    `type` ENUM('AURA','COMBAT_RATING','UNIT_MODS') NOT NULL DEFAULT 'AURA',
    `type_value` INT NOT NULL DEFAULT 0,
    `icon` VARCHAR(50) NOT NULL DEFAULT '0',
    `factor` INT NOT NULL DEFAULT 1,
    `limit` INT(3) NOT NULL DEFAULT 255,
    `application` INT NOT NULL DEFAULT 0,

    PRIMARY KEY (`id`),
    CONSTRAINT `fk_category`
        FOREIGN KEY (`category`)
        REFERENCES `acore_ale`.`paragon_config_category`(`id`)
            ON UPDATE CASCADE
            ON DELETE NO ACTION
);

-- General Configuration Table
-- Stores key-value pairs for general paragon settings
-- Uses field as primary key for efficient lookups and prevents duplicate keys
CREATE TABLE IF NOT EXISTS `acore_ale`.`paragon_config` (
    `field` VARCHAR(255) NOT NULL,
    `value` VARCHAR(255) NOT NULL,

    PRIMARY KEY (`field`)
);
