-- ============================================================================
-- Paragon System - Experience Reward Configuration Tables
-- ============================================================================
-- Creates tables to store experience rewards for specific sources:
-- - paragon_config_experience_creature: Creature kill rewards
-- - paragon_config_experience_achievement: Achievement rewards
-- - paragon_config_experience_skill: Skill increase rewards
-- - paragon_config_experience_quest: Quest completion rewards
-- ============================================================================

-- Creature Experience Rewards
-- Stores experience rewards for specific creature kills
CREATE TABLE IF NOT EXISTS `acore_ale`.`paragon_config_experience_creature` (
    `id` INT(11) NOT NULL,
    `experience` INT(11) NOT NULL DEFAULT 50,

    PRIMARY KEY (`id`)
);

-- Achievement Experience Rewards
-- Stores experience rewards for specific achievements
CREATE TABLE IF NOT EXISTS `acore_ale`.`paragon_config_experience_achievement` (
    `id` INT(11) NOT NULL,
    `experience` INT(11) NOT NULL DEFAULT 100,

    PRIMARY KEY (`id`)
);

-- Skill Experience Rewards
-- Stores experience rewards for skill increases
CREATE TABLE IF NOT EXISTS `acore_ale`.`paragon_config_experience_skill` (
    `id` INT(11) NOT NULL,
    `experience` INT(11) NOT NULL DEFAULT 25,

    PRIMARY KEY (`id`)
);

-- Quest Experience Rewards
-- Stores experience rewards for quest completions
CREATE TABLE IF NOT EXISTS `acore_ale`.`paragon_config_experience_quest` (
    `id` INT(11) NOT NULL,
    `experience` INT(11) NOT NULL DEFAULT 75,

    PRIMARY KEY (`id`)
);
