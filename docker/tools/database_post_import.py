#!/usr/bin/env python3
"""Idempotent post-import schema and module-data synchronization."""

from __future__ import annotations

import os
import time
from pathlib import Path

from admin import create_account, set_gm
from common import (
    MODULES_DIR,
    ToolError,
    first_created_table,
    first_existing,
    mysql,
    scalar,
    table_exists,
    world_sql_digest,
)

STATE_FILE = Path(os.getenv("DATABASE_MIGRATION_STATE_FILE", "/azerothcore/env/dist/etc/.database-preflight.sha256"))
DBIMPORT_READY = STATE_FILE.with_name(".db-import.ready")
POST_IMPORT_READY = STATE_FILE.with_name(".database-post-import.ready")
PARAGON_SQL_DIR = Path("/azerothcore/lua-sql/paragon")

# Resource template IDs used by Upload Academy's MIT-licensed Better
# Professions pack. We only port its spawn-density behavior; quests and Lua are
# intentionally excluded. Source:
# https://github.com/Upload-Academy/azerothcore-daisy/tree/master/packs/mcrilly/better-professions
BETTER_PROFESSIONS_RESOURCES = {
    "herbalism": (
        "Adder's Tongue", "Ancient Lichen", "Arthas' Tears", "Black Lotus",
        "Blindweed", "Bloodthistle", "Briarthorn", "Bruiseweed", "Dreamfoil",
        "Dreaming Glory", "Earthroot", "Fadeleaf", "Felweed", "Firebloom",
        "Firethorn", "Flame Cap", "Frost Lotus", "Frozen Herb", "Ghost Mushroom",
        "Golden Sansam", "Goldclover", "Goldthorn", "Grave Moss", "Gromsblood",
        "Icecap", "Icethorn", "Khadgar's Whisker", "Kingsblood", "Lichbloom",
        "Liferoot", "Mageroyal", "Mana Thistle", "Mountain Silversage",
        "Netherbloom", "Netherdust Bush", "Nightmare Vine", "Peacebloom",
        "Plaguebloom", "Purple Lotus", "Ragveil", "Sanguine Hibiscus",
        "Silverleaf", "Stranglekelp", "Sungrass", "Talandra's Rose", "Terocone",
        "Tiger Lily", "Wild Steelbloom", "Wintersbite",
    ),
    "mining": (
        "Adamantite Deposit", "Cobalt Deposit", "Copper Vein", "Dark Iron Deposit",
        "Fel Iron Deposit", "Gold Vein", "Hakkari Thorium Vein",
        "Incendicite Mineral Vein", "Iron Deposit", "Khorium Vein",
        "Lesser Bloodstone Deposit", "Mithril Deposit", "Nethercite Deposit",
        "Ooze Covered Gold Vein", "Ooze Covered Mithril Deposit",
        "Ooze Covered Rich Thorium Vein", "Ooze Covered Thorium Vein",
        "Ooze Covered Truesilver Deposit", "Rich Adamantite Deposit",
        "Rich Cobalt Deposit", "Rich Saronite Deposit", "Rich Thorium Vein",
        "Saronite Deposit", "Silver Vein", "Small Thorium Vein", "Tin Vein",
        "Titanium Vein", "Truesilver Deposit",
    ),
}


def import_sql(database: str, path: Path, label: str) -> None:
    print(f"[INFO] {label}: importing {path.name}")
    mysql(database=database, input_file=path, capture=False)


def ensure_schema(database: str, path: Path | None, label: str) -> None:
    if not path:
        print(f"[WARN] {label}: SQL file not found")
        return
    sentinel = first_created_table(path)
    if not sentinel:
        raise ToolError(f"{label}: no CREATE TABLE found in {path}")
    if table_exists(database, sentinel):
        print(f"[OK] {label}: {database}.{sentinel} already exists")
        return
    import_sql(database, path, label)
    if not table_exists(database, sentinel):
        raise ToolError(f"{label}: sentinel table {database}.{sentinel} is still missing")


def ensure_world_data(path: Path | None, label: str, probe: str, minimum: int = 1) -> None:
    if not path:
        print(f"[WARN] {label}: SQL file not found")
        return
    count = int(scalar(probe, "acore_world", "0"))
    if count >= minimum:
        print(f"[OK] {label}: world data already present ({count})")
        return
    import_sql("acore_world", path, label)
    count = int(scalar(probe, "acore_world", "0"))
    if count < minimum:
        raise ToolError(f"{label}: import completed but probe returned {count}")


def ensure_transmog_characters_schema() -> None:
    path = MODULES_DIR / "mod-transmog/data/sql/db-characters/trasmorg.sql"
    if not path.is_file():
        print("[WARN] mod-transmog characters SQL not found")
        return
    required = ("custom_transmogrification", "custom_unlocked_appearances")
    if all(table_exists("acore_characters", table) for table in required):
        print("[OK] mod-transmog characters schema already present")
        return
    import_sql("acore_characters", path, "mod-transmog characters")
    missing = [table for table in required if not table_exists("acore_characters", table)]
    if missing:
        raise ToolError(f"mod-transmog characters tables missing: {', '.join(missing)}")


def ensure_battlepass_npc() -> None:
    """Create the NPC template expected by the Lua module (not shipped upstream)."""
    if scalar("SELECT COUNT(*) FROM creature_template WHERE entry=90100", "acore_world", "0") != "0":
        print("[OK] lua-battlepass NPC template already present")
        return
    source = scalar(
        "SELECT entry FROM creature_template WHERE (npcflag & 1)=1 ORDER BY entry LIMIT 1",
        "acore_world",
    )
    if not source:
        raise ToolError("lua-battlepass NPC: no gossip NPC template is available to clone")
    raw_columns = mysql(
        "SELECT COLUMN_NAME FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA='acore_world' AND TABLE_NAME='creature_template' "
        "AND COLUMN_NAME<>'entry' ORDER BY ORDINAL_POSITION",
        "acore_world",
    )
    columns = [column for column in raw_columns.splitlines() if column]
    if not columns:
        raise ToolError("lua-battlepass NPC: creature_template columns not found")
    quoted = ",".join(f"`{column.replace('`', '``')}`" for column in columns)
    mysql(
        f"INSERT INTO creature_template (`entry`,{quoted}) "
        f"SELECT 90100,{quoted} FROM creature_template WHERE entry={int(source)} LIMIT 1; "
        "UPDATE creature_template SET name='Battle Pass Master', "
        "subname='Season Rewards', npcflag=1, AIName='', ScriptName='' WHERE entry=90100",
        "acore_world",
    )
    print(f"[OK] lua-battlepass NPC template created from safe gossip template {source}")


def density_multiplier(name: str) -> int:
    raw = os.getenv(name, "3").strip()
    try:
        value = int(raw)
    except ValueError as error:
        raise ToolError(f"{name} must be an integer between 1 and 10") from error
    if not 1 <= value <= 10:
        raise ToolError(f"{name} must be between 1 and 10 (received {value})")
    return value


def ensure_better_professions_density() -> None:
    """Apply deterministic resource density from an immutable baseline.

    The first run snapshots each affected pool's imported AzerothCore value.
    Later runs always calculate from that baseline, so multipliers never stack.
    Setting a multiplier back to 1 restores the original density.
    """
    mysql(
        "CREATE TABLE IF NOT EXISTS custom_better_professions_pool_baseline ("
        "pool_entry int unsigned NOT NULL PRIMARY KEY, "
        "base_max_limit int unsigned NOT NULL, "
        "captured_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        "acore_world",
    )

    seen: dict[int, str] = {}
    for resource, names in BETTER_PROFESSIONS_RESOURCES.items():
        multiplier = density_multiplier(f"BETTER_PROFESSIONS_{resource.upper()}_MULTIPLIER")
        name_list = ",".join("'" + name.replace("'", "''") + "'" for name in names)
        pool_query = (
            "SELECT DISTINCT pt.entry FROM pool_template pt "
            "JOIN pool_gameobject pgo ON pgo.pool_entry=pt.entry "
            "JOIN gameobject g ON g.guid=pgo.guid "
            "JOIN gameobject_template got ON got.entry=g.id "
            f"WHERE got.type=3 AND got.name IN ({name_list})"
        )
        pools = [int(value) for value in mysql(pool_query, "acore_world").splitlines() if value]
        if not pools:
            raise ToolError(f"Better Professions: no {resource} pools matched the current world database")
        overlap = sorted(pool for pool in pools if pool in seen)
        if overlap:
            raise ToolError(
                f"Better Professions: pools classified as both {seen[overlap[0]]} and {resource}: "
                + ",".join(str(pool) for pool in overlap)
            )
        seen.update((pool, resource) for pool in pools)
        pool_list = ",".join(str(pool) for pool in pools)
        mysql(
            "INSERT IGNORE INTO custom_better_professions_pool_baseline (pool_entry,base_max_limit) "
            f"SELECT entry,max_limit FROM pool_template WHERE entry IN ({pool_list}); "
            "UPDATE pool_template pt "
            "JOIN custom_better_professions_pool_baseline bp ON bp.pool_entry=pt.entry "
            f"SET pt.max_limit=LEAST(65535,GREATEST(1,ROUND(bp.base_max_limit*{multiplier}))) "
            f"WHERE pt.entry IN ({pool_list})",
            "acore_world",
        )
        print(f"[OK] Better Professions: {len(pools)} {resource} pools set to x{multiplier}")


def ensure_soap_account() -> None:
    """Keep the database account used by SOAP aligned with Compose secrets."""
    username = os.environ.get("SOAP_USER", "").strip()
    password = os.environ.get("SOAP_PASSWORD", "")
    if not username or not password:
        raise ToolError("SOAP_USER and SOAP_PASSWORD are required")
    create_account(username, password)
    set_gm(username, 3, -1)


def ensure_paragon_schema() -> None:
    """Apply the upstream Paragon migrations in their required order."""
    migrations = tuple(PARAGON_SQL_DIR.glob("0[2-6]_*.sql"))
    migrations = tuple(sorted(migrations))
    if len(migrations) != 5:
        raise ToolError(f"Paragon: expected 5 migrations in {PARAGON_SQL_DIR}, found {len(migrations)}")
    for migration in migrations:
        import_sql("acore_ale", migration, "Paragon")
    mysql(
        "UPDATE paragon_config SET value='80' "
        "WHERE field='MINIMUM_LEVEL_FOR_PARAGON_XP' AND value='0'",
        "acore_ale",
    )
    required = (
        "paragon_config",
        "paragon_config_category",
        "paragon_config_statistic",
        "paragon_config_experience_creature",
        "paragon_config_experience_achievement",
        "paragon_config_experience_skill",
        "paragon_config_experience_quest",
        "character_paragon",
        "account_paragon",
        "character_paragon_stats",
    )
    missing = [table for table in required if not table_exists("acore_ale", table)]
    if missing:
        raise ToolError(f"Paragon tables missing: {', '.join(missing)}")
    print("[OK] Paragon schema present; progression starts at level 80")


def main() -> int:
    POST_IMPORT_READY.unlink(missing_ok=True)
    for elapsed in range(1800):
        if DBIMPORT_READY.is_file():
            break
        if elapsed % 30 == 0:
            print("[INFO] Waiting for database import...")
        time.sleep(2)
    else:
        raise ToolError("timed out waiting for database import marker")

    reagent = MODULES_DIR / "mod-reagent-bank-account/data/sql"
    reagent_char = first_existing(
        reagent / "db-characters",
        (
            "base/create_table.sql",
            "create_table.sql",
            "base/mod_reagent_bank_account_create_table.sql",
            "mod_reagent_bank_account_create_table.sql",
            "base/reagent_bank_account_characters.sql",
            "reagent_bank_account_characters.sql",
        ),
    )
    reagent_world = first_existing(
        reagent / "db-world",
        (
            "base/reagent_bank_NPC.sql",
            "reagent_bank_NPC.sql",
            "base/mod_reagent_bank_account_NPC.sql",
            "mod_reagent_bank_account_NPC.sql",
            "base/reagent_bank_account_world.sql",
            "reagent_bank_account_world.sql",
        ),
    )
    transmog_world = first_existing(
        MODULES_DIR / "mod-transmog/data/sql/db-world",
        ("trasm_world_NPC.sql", "transmog_npc.sql", "transmog.sql", "mod_transmog_world.sql", "world.sql"),
    )
    battlepass = MODULES_DIR / "lua-battlepass/sql"

    ensure_transmog_characters_schema()
    ensure_schema("acore_characters", reagent_char, "mod-reagent-bank-account characters")
    ensure_world_data(
        reagent_world,
        "mod-reagent-bank-account world",
        "SELECT COUNT(*) FROM creature_template WHERE ScriptName LIKE '%reagent%' OR name LIKE '%Reagent%'",
    )
    ensure_world_data(
        transmog_world,
        "mod-transmog NPC",
        "SELECT COUNT(*) FROM creature_template WHERE ScriptName='npc_transmogrifier'",
    )
    ensure_schema("acore_world", first_existing(battlepass, ("battlepass_world.sql",)), "lua-battlepass world")
    ensure_schema(
        "acore_characters",
        first_existing(battlepass, ("battlepass_characters.sql",)),
        "lua-battlepass characters",
    )
    ensure_battlepass_npc()
    ensure_better_professions_density()
    ensure_paragon_schema()
    ensure_soap_account()

    try:
        mysql(
            "INSERT INTO module_string (module,id,string) VALUES "
            "('mod-aoe-loot',1,'Aoe Loot') ON DUPLICATE KEY UPDATE string=VALUES(string)",
            "acore_world",
        )
        print("[OK] mod-aoe-loot module string present")
    except ToolError as error:
        print(f"[WARN] mod-aoe-loot module string synchronization skipped: {error}")

    STATE_FILE.write_text(world_sql_digest() + "\n")
    POST_IMPORT_READY.touch()
    print("[OK] Database post-import initialization completed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ToolError as error:
        print(f"[ERROR] {error}")
        raise SystemExit(1)
