from pathlib import Path

# ---------------------------------------------------------------------------
# Touch of Weakness: log the target state immediately before its triggered
# damage spell is cast. This does not change the cast or its parameters.
# ---------------------------------------------------------------------------
priest_path = Path("src/scripts/spells/spell_priest.cpp")
priest = priest_path.read_text(encoding="utf-8")

old_tow = "        spell->m_caster->CastSpell(spell->GetUnitTarget(), spellId, true, nullptr);"
new_tow = r'''        Unit* target = spell->GetUnitTarget();
        sLog.outError(
            "[TOW_TRACE] aura=%u damageSpell=%u targetAlive=%u targetHP=%u/%u",
            spell->m_triggeredByAuraSpell->Id,
            spellId,
            target ? uint32(target->IsAlive()) : 0,
            target ? target->GetHealth() : 0,
            target ? target->GetMaxHealth() : 0);

        spell->m_caster->CastSpell(target, spellId, true, nullptr);'''

if "[TOW_TRACE]" not in priest:
    if old_tow not in priest:
        raise SystemExit("Could not find Touch of Weakness CastSpell line")
    priest = priest.replace(old_tow, new_tow, 1)

priest_path.write_text(priest, encoding="utf-8", newline="\n")

# ---------------------------------------------------------------------------
# Spirit Tap: instrument the central proc decision directly. No spell_template
# script_name changes and no SQL are required. Every log is gated to the five
# Spirit Tap ranks and the original return paths remain unchanged.
# ---------------------------------------------------------------------------
proc_path = Path("src/game/UnitAuraProcHandler.cpp")
proc = proc_path.read_text(encoding="utf-8")

entry_marker = "    SpellEntry const* spellProto = holder->GetSpellProto();\n"
entry_trace = r'''    SpellEntry const* spellProto = holder->GetSpellProto();

    bool const traceSpiritTap = spellProto &&
        (spellProto->Id == 15270 || spellProto->Id == 15335 || spellProto->Id == 15336 ||
         spellProto->Id == 15337 || spellProto->Id == 15338);

    if (traceSpiritTap)
    {
        sLog.outError(
            "[SPIRIT_TAP_TRACE] ENTER aura=%u procSpell=%u incomingProcFlag=0x%08X procExtra=0x%08X "
            "victimAlive=%u victimHP=%u/%u isVictim=%u triggeredByAuraOrItem=%u",
            spellProto->Id,
            procSpell ? procSpell->Id : 0,
            procFlag,
            procExtra,
            pVictim ? uint32(pVictim->IsAlive()) : 0,
            pVictim ? pVictim->GetHealth() : 0,
            pVictim ? pVictim->GetMaxHealth() : 0,
            uint32(isVictim),
            uint32(isSpellTriggeredByAuraOrItem));
    }
'''

if "[SPIRIT_TAP_TRACE] ENTER" not in proc:
    if entry_marker not in proc:
        raise SystemExit("Could not find IsTriggeredAtSpellProcEvent entry marker")
    proc = proc.replace(entry_marker, entry_trace, 1)

flags_marker = """    if (spellProcEvent && spellProcEvent->procFlags) // if exist get custom spellProcEvent->procFlags\n        EventProcFlag = spellProcEvent->procFlags;\n    else\n        EventProcFlag = spellProto->procFlags;       // else get from spell proto\n"""
flags_trace = flags_marker + r'''    if (traceSpiritTap)
    {
        sLog.outError(
            "[SPIRIT_TAP_TRACE] FLAGS aura=%u dbcProcFlags=0x%08X dbProcFlags=0x%08X "
            "eventProcFlag=0x%08X incomingProcFlag=0x%08X overlap=0x%08X dbProcEx=0x%08X",
            spellProto->Id,
            spellProto->procFlags,
            spellProcEvent ? spellProcEvent->procFlags : 0,
            EventProcFlag,
            procFlag,
            EventProcFlag & procFlag,
            spellProcEvent ? spellProcEvent->procEx : 0);
    }
'''

if "[SPIRIT_TAP_TRACE] FLAGS" not in proc:
    if flags_marker not in proc:
        raise SystemExit("Could not find EventProcFlag calculation marker")
    proc = proc.replace(flags_marker, flags_trace, 1)

match_marker = """    if (!SpellMgr::IsSpellProcEventCanTriggeredBy(spellProcEvent, EventProcFlag, procSpell, procFlag, procExtra))\n        return SPELL_PROC_TRIGGER_FAILED;\n"""
match_trace = r'''    if (!SpellMgr::IsSpellProcEventCanTriggeredBy(spellProcEvent, EventProcFlag, procSpell, procFlag, procExtra))
    {
        if (traceSpiritTap)
            sLog.outError("[SPIRIT_TAP_TRACE] MATCH aura=%u result=0", spellProto->Id);
        return SPELL_PROC_TRIGGER_FAILED;
    }

    if (traceSpiritTap)
        sLog.outError("[SPIRIT_TAP_TRACE] MATCH aura=%u result=1", spellProto->Id);
'''

if "[SPIRIT_TAP_TRACE] MATCH" not in proc:
    if match_marker not in proc:
        raise SystemExit("Could not find proc-event match marker")
    proc = proc.replace(match_marker, match_trace, 1)

proc_path.write_text(proc, encoding="utf-8", newline="\n")
print("Applied Spirit Tap / Touch of Weakness trace instrumentation (no DB changes).")
