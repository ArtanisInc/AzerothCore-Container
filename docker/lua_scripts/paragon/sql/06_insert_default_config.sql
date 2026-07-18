-- ============================================================================
-- Paragon System - Default Configuration Values
-- ============================================================================
-- Inserts default configuration settings for the Paragon system
-- These values are only inserted if they don't already exist (INSERT IGNORE)
-- ============================================================================

INSERT IGNORE INTO `acore_ale`.`paragon_config` (field, value) VALUES
-- System Control
('ENABLE_PARAGON_SYSTEM', '1'),
('MINIMUM_LEVEL_FOR_PARAGON_XP', '80'),
('PARAGON_LEVEL_CAP', '999'),
('LEVEL_LINKED_TO_ACCOUNT', '0'),

-- Progression Settings
('BASE_MAX_EXPERIENCE', '1000'),
('POINTS_PER_LEVEL', '1'),
('PARAGON_STARTING_LEVEL', '1'),
('PARAGON_STARTING_EXPERIENCE', '0'),

-- Experience Rewards (Universal Defaults)
('UNIVERSAL_CREATURE_EXPERIENCE', '50'),
('UNIVERSAL_ACHIEVEVEMENT_EXPERIENCE', '100'),
('UNIVERSAL_SKILL_EXPERIENCE', '25'),
('UNIVERSAL_QUEST_EXPERIENCE', '75'),

-- Experience Multipliers
('EXPERIENCE_MULTIPLIER_LOW_LEVEL', '1.5'),
('EXPERIENCE_MULTIPLIER_HIGH_LEVEL', '0.8'),
('LOW_LEVEL_THRESHOLD', '5'),
('HIGH_LEVEL_THRESHOLD', '100'),

-- Point Customization
('DEFAULT_STAT_LIMIT', '255');
