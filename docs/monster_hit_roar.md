# MH Wilds — monster hit & roar hooks (from il2cpp_dump.json)

All names below were confirmed to exist in the dump. Method names drop the dump's numeric id suffix.
Behaviour is inferred from name + type, **not** tested in-game.

## 1. Hunter hits a monster

| Source | Name | Type / signature | Notes |
|---|---|---|---|
| Poll (weapon) | `_IsHitAttackToEnemy` | Boolean on `app.cHunterWeaponHandlingBase` | Every weapon inherits it. May be a short pulse. |
| Poll (weapon) | `_IsHitWeakPoint` | Boolean | Hit on a weak point. |
| Poll (weapon) | `_ScarBreakCount` | Int32 | Increments when a wound breaks. |
| Hook (weapon) | `app.cHunterWeaponHandlingBase.evHit_AttackPostProcess` | `(app.HitInfo, Boolean) -> Void` | Fires once per hit. Best haptic trigger. |
| Hook (weapon) | `doOnHitWeakPoint` | `(app.HitInfo, app.cDamageParamEm) -> Void` | Weak-point hit. |
| Hook (hunter) | `app.HunterCharacter.evHit_AttackPostProcess` | `(app.HitInfo) -> Void` | Covers all hunter attacks, including slinger and shells. |
| Hook (enemy) | `app.EnemyCharacter.evDamage_Health` | `(Single, Single) -> Void` | Monster loses HP. Params are probably damage/HP (unverified). |
| Hook (enemy) | `app.EnemyCharacter.evDamage_WeakPoint` / `evDamage_Parts` | `(Int32, Single) -> Void` | Part index + value. |

`app.HitInfo` useful getters: `<AttackOwner>k__BackingField` / `<DamageOwner>k__BackingField` (GameObject), `<Position>k__BackingField` (vec3), `<MultiHitCount>k__BackingField` (Int32), `<DamageData>k__BackingField` (cDamageParamBase), `<AttackData>k__BackingField` (cAttackParamBase).

Filter tip: in the enemy hooks, check that the attacker is the local hunter. Otherwise teammates' hits will also rumble.

## 2. Monster roar

There is **no shared roar base class**. Each monster has its own action classes, e.g. `app.Em0001_00Action.cRoarDiscover` and `cRoarShort`. They inherit generic bases (`app.EmCommonAction.cGroupSingleBase`, etc.).
Practical ways to detect a roar:

| Method | Name | Notes |
|---|---|---|
| Hunter is hit by roar (recommended) | `app.HunterCharacter.get_DamageInfo()` → `app.cHunterDamageInfo._DamageType` | `app.HunterDef.DAMAGE_TYPE`: `EAR_S=10`, `EAR_L=11`, `EAR_FLY=12`. Fires only when the hunter is actually affected. With Earplugs it probably won't trigger. |
| Which monster | `app.cHunterDamageInfo._AttackerEmInfo._EmID` | `app.EnemyDef.ID` (212 values, e.g. `EM0001_00_0=0` … `EM0166_00_0=34`). |
| Hook | `app.cHunterStockDamage.getEarDamageType(app.cAttackParamEm, Boolean) -> app.HunterDef.DAMAGE_TYPE` | Called when the hunter takes an ear hit. Read the return value in post-hook. |
| Attack data | `app.cAttackParamBase._DamageType` | `app.HitDef.DAMAGE_TYPE`: `EAR=2`, `SOUND_REACT=3`, `QUAKE=1`, `WIND=4`, `FLASH=6`. Read from `HitInfo.<DamageAttackData>k__BackingField` in `HunterCharacter.evHit_Damage(app.HitInfo)`. |
| Monster ID | `app.EnemyCharacter._Context._Em` → `app.cEnemyContext.get_EmID()` | Which monster this is. |
| Monster action (catches roar even with Earplugs) | Read the current action type name of the monster and match `Roar` / `Howl` | No ready-made field; needs the action controller. Unverified. |

Trap: `app.EnemyDef.SP_ATK_TYPE.ROAR_MAJOR / ROAR_MINIOR` is only used by the GUI monster report. It is not a runtime state.

## 3. Guard

Two different signals:

| Want | Name | Notes |
|---|---|---|
| **Holding guard (state)** | `app.HunterCharacter.checkHunterStatusFlag(app.HunterDef.STATUS_FLAG)` (also on `app.cHunterStatus`) | `STATUS_FLAG`: `GUARD=2`, `POWER_GUARD=3`, `TECHNICAL_GUARD=4`, `LASER_GUARD=5`, `GUARD_POINT=6`. Likely returns bool (return type not checked). Untested. |
| **Guard got hit (event)** | `app.cHunterDamageInfo._DamageType` | `GUARD_S=34`, `GUARD_M=35`, `GUARD_L=36`, `GUARD_TECH=37`, `POWER_GUARD=44`. The value can stay after the hit, so detect the change (or hook `HunterCharacter.evHit_Damage`). |
| Related | `app.HunterDef.CONTINUE_FLAG` | `GUARD_BLOCK=285`, `GUARD_BLOCK_FINISH=153`. |

Bonus from the same enum (`app.HunterDef.DAMAGE_TYPE`), useful for haptics:
- `QUAKE_SS/S/L` (18–20): tremor
- `WIND_*` (13–17): wind pressure
- `FLASH=22`
- `STUN=21`
- `GUARD_S/M/L` (34–36): guard hit, small/medium/large. This is a usable guard signal for GS/SnS/Lance/GL/CB, which have no guard flag.
- `POWER_GUARD=44`
- `GUARD_TECH`: perfect guard
- `SMASH_*`: getting knocked flying
