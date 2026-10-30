-- GENERIERT von Tools/rules-js/seed-rules.js aus RookRaid/Engine/rookraid-rules.json – Regel-Version 3
insert into public.rules_config (version, config, active)
values (3, '{"version":3,"maxMana":10,"manaPerTurn":1,"goodMoveBonus":1,"ultimateCost":8,"cardCooldown":2,"drainGain":2,"focusGain":4,"sacrificeGain":3,"cardCosts":{"focus":0,"sacrifice":0,"drain":0,"reinforce":1,"retreat":1,"bulwark":2,"shield":2,"lightning":2,"advance":3,"knighting":3,"bishopize":3,"sprint":3,"freeze":4,"swap":4,"revive":6},"cardCooldowns":{"lightning":3},"ultimateCosts":{"fortress":6}}'::jsonb, true)
on conflict (version) do update set config = excluded.config, active = true;
update public.rules_config set active = false where version <> 3;
