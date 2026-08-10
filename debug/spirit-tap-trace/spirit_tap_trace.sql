-- Spirit Tap trace binding for an isolated/debug world database only.
-- This temporarily assigns all Spirit Tap ranks to spell_priest_spirit_tap_trace.
-- Do NOT apply this to the primary server database unless you intend to trace there.

CREATE TABLE IF NOT EXISTS `debug_spirit_tap_script_backup` (
    `entry` MEDIUMINT UNSIGNED NOT NULL,
    `script_name` VARCHAR(64) NOT NULL DEFAULT '',
    PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `debug_spirit_tap_script_backup` (`entry`, `script_name`)
SELECT `entry`, `script_name`
FROM `spell_template`
WHERE `entry` IN (15270, 15335, 15336, 15337, 15338);

UPDATE `spell_template`
SET `script_name` = 'spell_priest_spirit_tap_trace'
WHERE `entry` IN (15270, 15335, 15336, 15337, 15338);

SELECT `entry`, `script_name`, `procFlags`
FROM `spell_template`
WHERE `entry` IN (15270, 15335, 15336, 15337, 15338)
ORDER BY `entry`;
