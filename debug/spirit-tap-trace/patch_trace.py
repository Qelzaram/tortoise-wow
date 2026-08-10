from pathlib import Path

path = Path("src/scripts/spells/spell_priest.cpp")
text = path.read_text(encoding="utf-8")

trace_struct = r'''struct spell_priest_spirit_tap_trace : public AuraScript
{
    std::optional<SpellProcEventTriggerCheck> OnCheckProc(Unit const* /*owner*/, Unit* victim, SpellAuraHolder* holder,
        SpellEntry const* procSpell, uint32 procFlag, uint32 procExtra, WeaponAttackType attType, bool isVictim) override
    {
        SpellEntry const* auraSpell = holder ? holder->GetSpellProto() : nullptr;

        sLog.outError(
            "[SPIRIT_TAP_TRACE] aura=%u dbcProcFlags=0x%08X procSpell=%u incomingProcFlag=0x%08X procExtra=0x%08X "
            "victimAlive=%u victimHP=%u/%u attType=%u isVictim=%u",
            auraSpell ? auraSpell->Id : 0,
            auraSpell ? auraSpell->procFlags : 0,
            procSpell ? procSpell->Id : 0,
            procFlag,
            procExtra,
            victim ? uint32(victim->IsAlive()) : 0,
            victim ? victim->GetHealth() : 0,
            victim ? victim->GetMaxHealth() : 0,
            uint32(attType),
            uint32(isVictim));

        // Trace only: do not change the normal proc decision.
        return std::nullopt;
    }
};

'''

struct_marker = "struct spell_priest_vampiric_embrace : public AuraScript\n"
if "struct spell_priest_spirit_tap_trace" not in text:
    if struct_marker not in text:
        raise SystemExit("Could not find insertion point for Spirit Tap trace AuraScript")
    text = text.replace(struct_marker, trace_struct + struct_marker, 1)

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

if "[TOW_TRACE]" not in text:
    if old_tow not in text:
        raise SystemExit("Could not find Touch of Weakness CastSpell line")
    text = text.replace(old_tow, new_tow, 1)

register_marker = '    RegisterAuraScript("spell_priest_inspiration", &GetAuraScript<spell_priest_inspiration>);\n'
register_trace = '    RegisterAuraScript("spell_priest_spirit_tap_trace", &GetAuraScript<spell_priest_spirit_tap_trace>);\n'
if register_trace not in text:
    if register_marker not in text:
        raise SystemExit("Could not find priest script registration insertion point")
    text = text.replace(register_marker, register_marker + register_trace, 1)

path.write_text(text, encoding="utf-8", newline="\n")
print("Applied Spirit Tap / Touch of Weakness trace instrumentation.")
