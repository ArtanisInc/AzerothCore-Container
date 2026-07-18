-- ============================================================================
-- Paragon System - Paragon Progression Tables
-- ============================================================================
-- Creates tables for storing paragon progression data:
-- - character_paragon: Character-specific progression (when LEVEL_LINKED_TO_ACCOUNT = 0)
-- - account_paragon: Account-wide progression (when LEVEL_LINKED_TO_ACCOUNT = 1)
-- - character_paragon_stats: Character stat point investments
-- ============================================================================

-- Character Paragon Table (Character-Linked)
-- Stores each character's paragon level and experience when LEVEL_LINKED_TO_ACCOUNT = 0
CREATE TABLE IF NOT EXISTS `acore_ale`.`character_paragon` (
    `guid` INT(11) NOT NULL,
    `level` INT(11) NOT NULL DEFAULT 1,
    `experience` INT(11) NOT NULL DEFAULT 0,

    PRIMARY KEY (`guid`)
);

-- Account Paragon Table (Account-Linked)
-- Stores account-wide paragon level and experience when LEVEL_LINKED_TO_ACCOUNT = 1
CREATE TABLE IF NOT EXISTS `acore_ale`.`account_paragon` (
    `account_id` INT(11) NOT NULL,
    `level` INT(11) NOT NULL DEFAULT 1,
    `experience` INT(11) NOT NULL DEFAULT 0,

    PRIMARY KEY (`account_id`)
);

-- Character Paragon Statistics Table
-- Stores stat points invested by each character
CREATE TABLE IF NOT EXISTS `acore_ale`.`character_paragon_stats` (
    `guid` INT(11) NOT NULL,
    `stat_id` INT(11) NOT NULL,
    `stat_value` INT(11) NOT NULL,

    PRIMARY KEY (`guid`, `stat_id`)
);
