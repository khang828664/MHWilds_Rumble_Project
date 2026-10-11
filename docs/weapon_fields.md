# MH Wilds — real weapon field names (from il2cpp_dump.json)

Source: REFramework `il2cpp_dump.json` → extract of `app.cHunterWpNNHandling` + parent classes + referenced types. Analysis: 7 agents (2 weapons each) + 1 vibration agent.

**Verification:** every field/method name in the JSON map was checked against the dump with a script — all exist (including `Hunter._IsWeaponOn` and `_Ammos[i]._LoadedAmmo`). Behaviour/confidence is inferred from name + type, **not** tested in-game.

**Common notes:**
- Method names in the dump carry an id suffix (`get_IsCharging510123`); call them in Lua without the suffix (`wp:call("get_IsCharging")`).
- `app.cValueHolderF` / `cValueHolderI`: read the `._Value` sub-field.
- `via.rds.Mandrake` (Kireaji, gun `_LoadedAmmo`) is an encrypted value — read it through a getter method (e.g. `getCurrentAmmo`), not directly.
- **Guard**: no guard field on weapon handling classes — it is a hunter status. Holding guard: `app.HunterCharacter.checkHunterStatusFlag(app.HunterDef.STATUS_FLAG)` with GUARD=2 / POWER_GUARD=3 / TECHNICAL_GUARD=4 / GUARD_POINT=6. Guard got hit: `get_DamageInfo()._DamageType` GUARD_S/M/L=34-36, GUARD_TECH=37, POWER_GUARD=44. JSON values prefixed `hunter:` are read from `app.HunterCharacter`, not the weapon. Names exist in the dump; untested in-game. See monster_hit_roar.md.
- **Action-based states** (values prefixed `action:`): read the current action with `hunter:get_BaseActionController():get_CurrentActionID()` → `ace.ACTION_ID` (`_Category`, `_Index`) and compare `_Index` with the `app.WpNNAction.ID` constants listed. The `_Category` value used for weapon actions is not in the dump — check it in-game first. Fallback that avoids the category: `get_CurrentAction():get_type_definition():get_full_name()`, then match the class name (e.g. `app.Wp00Action.cCharge`).

## Wp00 Great Sword (`gs`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| chargeLevel | `_ChargeLevel` (or method `get_ChargeLevel`) | app.Wp00Def.CHARGE_LEVEL | level/enum LV0=0..LV3=3 (MAX=4 is sentinel) | high | Name + dedicated enum LV0-LV3; companion `_PrevChargeLevel` confirms it is the live value |
| charging | current action index (`app.Wp00Action.ID`): IdleToCharge=5, CHARGE=6, STORNG_CHARGE=7, Charge_Fly=8, SPIRIT_CHARGE=11, IDLE_TO_PARRY_CHARGE=21, PARRY_CHARGE=22 | ace.ACTION_ID._Index (Int32) | enum/action set | high | Action names CHARGE/STORNG_CHARGE/SPIRIT_CHARGE are the GS charge actions. Alt poll: `_ChargeTimer` > 0. Category not verified |
| guard (flag) | method `app.HunterCharacter.checkHunterStatusFlag` (arg `app.HunterDef.STATUS_FLAG.GUARD=2`) | → bool (return type not checked) | bool flag | medium | Guard is a hunter-level status, not a weapon field. Exists in dump; untested in-game |
| guardHit (extra) | `app.HunterCharacter.get_DamageInfo()._DamageType` | app.HunterDef.DAMAGE_TYPE | enum: GUARD_S=34, GUARD_M=35, GUARD_L=36, GUARD_TECH=37, GUARD_TECH_M=38, GUARD_POINT_S/M/L=41-43, POWER_GUARD=44 | medium | Damage type when an attack is blocked; S/M/L = block strength. Value may persist after the hit → detect change or hook `HunterCharacter.evHit_Damage`. Untested |
| chargeType (extra) | `_ChargeType` (or method `get_ChargeType`) | app.Wp00Def.CHARGE_TYPE | enum NORMAL/STRONG/SPIRIT/FLY/SLIDING/PARRY/BT_RIDE | high | Identifies which charged attack (True Charged = STRONG?, Spirit, etc.); value change = new charge attack started |
| overheat (extra) | `_IsOverheat` (or method `get_IsOverheat`) | Boolean | bool flag | medium | Likely the 'held charge too long' state; exact semantics not provable from name |
| spiritSlashEnhanced (extra) | `_IsSpiritSlashEnhanced` (method `get_IsSpiritSlashEnhanced`) | Boolean | bool flag | medium | Explicit name; enhanced spirit-type slash state |
| chargeContinue (extra) | `_ChargeContinue` | Boolean | bool flag | low | Probably charge carried over into next attack (requestChargeContinue/chargeContinue methods); meaning not certain |
| parryState (extra) | `<ParryState>k__BackingField` (method `get_ParryState`) | app.HunterDef.PARRY_STATE | enum NONE/WAIT/HIT/SUCCESS=3/RECOIL | medium | Base-class parry state; fire on SUCCESS. Whether GS uses it (e.g. guard-tackle/offset) not provable |
| hitEnemy (extra) | `_IsHitAttackToEnemy` | Boolean | bool flag | medium | Attack connected; may be a per-frame pulse |
| hitWeakPoint (extra) | `_IsHitWeakPoint` | Boolean | bool flag | medium | Hit on weak point/wound |
| woundBreak (extra) | `_ScarBreakCount` | Int32 | counter | high | Scar = wound; increments when a wound is destroyed (addScarBreakCount/resetScarBreakCount) |
| justChargeTiming (extra) | method `isJustChargeTiming` | method -> bool | bool flag | medium | Method only; perfect-timing window of charge |
| maxCharge (extra) | method `isMaxCharge` | method -> bool | bool flag | medium | Method only; true at max charge level |
| weaponDrawn (extra) | HunterCharacter `_IsWeaponOn` (method `get_IsWeaponOn`) | Boolean | bool flag | high | Shared hunter field |

> Charging has no direct flag. Suggested derivation: charging = (_ChargeTimer > 0) or (_ChargeLevel > LV0); verify in game. Guard is not in the weapon handling; look for it in the hunter action ID or status. Getters that exist: get_ChargeLevel, get_ChargeType, get_IsOverheat, get_IsSpiritSlashEnhanced, get_ChargeTimeRate (a 0..1 charge rate float, also usable as a gauge but it changes every frame). File: C:/Users/ADMIN/AppData/Local/Temp/claude/c--KHANG-code-MHWilds-Rumble-Project/baa3ada1-6ffa-4aec-8bfb-650d3f64ed8b/scratchpad/digest/wp00.md

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp00Handling**
`<ActionRemoveIgnoreTag>k__BackingField` : System.UInt32
`<ChargeTurnDeg>k__BackingField` : Nullable<Single>
`<IsWeakPointDelayExecuted>k__BackingField` : Boolean
`<LastHitTimer>k__BackingField` : Single
`<OverwriteChargeOverHeatTime>k__BackingField` : Nullable<Single>
`<WeaponPointDelayInfoContinue>k__BackingField` : Boolean
`_ChargeContinue` : Boolean
`_ChargeLevel` : app.Wp00Def.CHARGE_LEVEL
`_ChargeRequestType` : app.Wp00Def.CHARGE_REQUEST_TYPE
`_ChargeTimer` : Single
`_ChargeType` : app.Wp00Def.CHARGE_TYPE
`_ConstInfo` : app.cHunterWp00Handling.AimConstInfo
`_DisableChargeParts` : Boolean
`_EffectChargeLevel` : app.Wp00Def.CHARGE_LEVEL
`_IsBreakWeakPointInFrame` : Boolean
`_IsOverheat` : Boolean
`_IsSpiritSlashEnhanced` : Boolean
`_NeedDelayWeakPointExecute` : Boolean
`_OverwriteGuardDir` : via.vec3
`_PrevChargeLevel` : app.Wp00Def.CHARGE_LEVEL
`_PrevChargeType` : app.Wp00Def.CHARGE_TYPE
`_WeakPointDelayAttackInfos` : List<cDelayAttackInfo>
`_WpGimmickMotChargeLv` : app.Wp00Def.WP_GIMMICK_MOT_CHARGE_LV
`_WpGimmickMotType` : app.Wp00Def.WP_GIMMICK_MOT_TYPE
`_WpGimmickRestart` : Boolean

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : Nullable<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : Boolean
`<IsHitInfoContinue>k__BackingField` : Boolean
`<IsParryInfoContinue>k__BackingField` : Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : Single
`<ReserveShellWeaponAttackPower>k__BackingField` : Single
`<ReserveShellWeaponAttrPower>k__BackingField` : Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : Nullable<UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : Boolean
`_IsFittingMode` : Boolean
`_IsHitAttackToEnemy` : Boolean
`_IsHitWeakPoint` : Boolean
`_IsUseExtraStealthCollider` : Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : Int32
`_ScarBreakIndexList` : List<Int32>
`_Skill218or217Timer` : Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**app.HunterCharacter (via <Hunter>k__BackingField, relevant)**
`_IsWeaponOn` : Boolean
`_HunterWeaponFlag` : ace.cSafeContinueFlagGroup

</details>

## Wp01 Sword & Shield (`sns`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| guard (flag) | method `app.HunterCharacter.checkHunterStatusFlag` (arg `app.HunterDef.STATUS_FLAG.GUARD=2`) | → bool (return type not checked) | bool flag | medium | Guard is a hunter-level status, not a weapon field. Exists in dump; untested in-game |
| guardHit (extra) | `app.HunterCharacter.get_DamageInfo()._DamageType` | app.HunterDef.DAMAGE_TYPE | enum: GUARD_S=34, GUARD_M=35, GUARD_L=36, GUARD_TECH=37, GUARD_TECH_M=38, GUARD_POINT_S/M/L=41-43, POWER_GUARD=44 | medium | Damage type when an attack is blocked; S/M/L = block strength. Value may persist after the hit → detect change or hook `HunterCharacter.evHit_Damage`. Untested |
| perfectRush | `_IsLastJustRushFinshSuccess` | Boolean | bool flag (true after a perfectly timed Rush finisher) | medium | 'JustRush' = Perfect Rush ('Finsh' typo is real spelling); only a setter exists (set_IsLastJustRushFinshSuccess), no getter. 'Last' suggests it stays latched until next rush, so trigger on false->true |
| chargedChop | current action index (`app.Wp01Action.ID`): BACK_STEP_CHARGE=24, CHARGE_SLASH=25 | ace.ACTION_ID._Index (Int32) | enum/action set | medium | CHARGE_SLASH / BACK_STEP_CHARGE = charged slash actions. Category not verified |
| stepSlashCount (extra) | `_StepSlashCount` (method `get_StepSlashCount`) | Int32 | counter | medium | addStepSlashCount/resetStepSlashCount; increment = one more step slash in the chain. Which in-game move it is cannot be told from the name |
| hitFinishAttack (extra) | `_IsHitFinishAttack` (method `get_IsHitFinishAttack`) | Boolean | bool flag | medium | A finisher attack connected (likely tied to createFinishSlashShell) |
| hitTearScar (extra) | `_IsHitTearScar` (method `get_IsHitTearScar`) | Boolean | bool flag | medium | Hit that tears/opens a wound (scar) |
| woundBreak (extra) | `_ScarBreakCount` | Int32 | counter | high | Increments when a wound is destroyed (base class) |
| parryState (extra) | `<ParryState>k__BackingField` (method `get_ParryState`) | app.HunterDef.PARRY_STATE | enum; SUCCESS=3 = parry success | medium | Base-class parry state; SnS has perfect-guard/offset style moves, but the digest cannot prove it is used |
| hitEnemy (extra) | `_IsHitAttackToEnemy` | Boolean | bool flag | medium | Attack connected |
| hitWeakPoint (extra) | `_IsHitWeakPoint` | Boolean | bool flag | medium | Hit on weak point |
| weaponDrawn (extra) | HunterCharacter `_IsWeaponOn` | Boolean | bool flag | high | Shared hunter field |
| perfectRushAction | current action index (`app.Wp01Action.ID`): JUST_RUSH_START=48, JUST_RUSH_COMBO_0=49, JUST_RUSH_COMBO_1=50, JUST_RUSH_COMBO_2=51 | ace.ACTION_ID._Index (Int32) | enum/action set | high | JUST_RUSH_* = Perfect Rush combo actions. Category not verified |

> The SnS handling class is small. There is no charge, gauge or guard state in it. The Charged Chop and guard states probably have to come from the hunter action ID. Keep the misspelling `_IsLastJustRushFinshSuccess` exactly as written. It has only a setter (no getter), so read the field directly. File: C:/Users/ADMIN/AppData/Local/Temp/claude/c--KHANG-code-MHWilds-Rumble-Project/baa3ada1-6ffa-4aec-8bfb-650d3f64ed8b/scratchpad/digest/wp01.md

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp01Handling**
`_ConstInfo` : app.cHunterWp01Handling.AimConstInfo
`_EmStepSlashHeightOffset` : Single
`_EmStepSlashPos` : Nullable<via.vec3>
`_IsBreakWeakPointInFrame` : Boolean
`_IsHitFinishAttack` : Boolean
`_IsHitTearScar` : Boolean
`_IsLastJustRushFinshSuccess` : Boolean
`_StepSlashCount` : Int32
`_WpGimmickMotType` : app.Wp01Def.WP_GIMMICK_MOT_TYPE

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : Nullable<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : Boolean
`<IsHitInfoContinue>k__BackingField` : Boolean
`<IsParryInfoContinue>k__BackingField` : Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : Single
`<ReserveShellWeaponAttackPower>k__BackingField` : Single
`<ReserveShellWeaponAttrPower>k__BackingField` : Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : Nullable<UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : Boolean
`_IsFittingMode` : Boolean
`_IsHitAttackToEnemy` : Boolean
`_IsHitWeakPoint` : Boolean
`_IsUseExtraStealthCollider` : Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : Int32
`_ScarBreakIndexList` : List<Int32>
`_Skill218or217Timer` : Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**app.HunterCharacter (via <Hunter>k__BackingField, relevant)**
`_IsWeaponOn` : Boolean

</details>

## Wp02 Dual Blades (`db`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| demonMode | `_IsKijinOn` | Boolean | bool flag | high | kijin=Demon; ExposeMember; has getter get_IsKijinOn and setKijinOn/startKijinMode/endKijinMode methods |
| demonGauge | `<KijinGauge>k__BackingField` -> `_Value` | app.cValueHolderF (Single) | gauge 0..max (`MaxValue`) | high | KijinGauge = Demon gauge; getter get_KijinGauge, checkKijinGaugeEnough, param _Ranbu*/Chain*GaugeReduce consume it |
| archdemon | `_IsKijinEnhancement` | Boolean | bool flag | high | kyouka/enhancement on kijin = Archdemon; getter get_IsKijinEnhancement, setKijinEnhancement/updateKijinEnhancement |
| perfectEvade (extra) | `<IsMikiriDodgeSuccessed>k__BackingField` | Boolean | bool flag | medium | mikiri dodge successed = perfect-evade success; may stay true for a window, trigger on false->true edge |
| mikiriSuccessPulse (extra) | `_MikiriSuccessFrame` | Boolean | bool flag (likely single-frame pulse) | medium | 'SuccessFrame' implies set on the frame of a mikiri success; may be missed by polling if cleared same frame |
| mikiriCount (extra) | `_MikiriCount` | Int32 | counter | medium | integer count of mikiri successes; trigger on increment (may reset) |
| mikiriBuff (extra) | `<IsMikiriBuff>k__BackingField` | Boolean | bool flag | medium | buff active after a just-dodge (_JustSuccessBuffTime param); getter get_IsMikiriBuff |
| demonComboLv (extra) | `<KijinComboLv>k__BackingField` | app.Wp02Def.KIJIN_COMBO_LV | enum | medium | combo level carried out of demon mode (INVALID/FROM_KIJIN1/FROM_KIJIN2) |
| constSpinHits (extra) | `ConstSpinHitCount` | Int32 | counter | low | name suggests hit count of a spin attack; 'Const' here likely refers to CONST_SPIN attack type (SPECIAL_ATTACK_PARAM_TYPE), not a constant, but unverified |
| hit (extra) | `_IsHit` | Boolean | bool flag | low | generic hit flag; reset timing unknown |
| parry (extra) | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum | medium | base-class parry state; SUCCESS=3 for parry success (DB rarely parries) |

> Getter alternatives exist: method get_IsKijinOn, get_IsKijinEnhancement, get_KijinGauge (returns cValueHolderF; then get_Value or _Value), get_IsMikiriDodgeSuccessed, get_IsMikiriBuff, get_KijinComboLv. Gauge max via KijinGauge.MaxValue (Nullable<Single>) or cValueHolderF method calcValueRate for 0..1. _MikiriSuccessFrame may be a 1-frame pulse; prefer _MikiriCount increment or IsMikiriDodgeSuccessed rising edge for reliable polling.

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp02Handling**
`<ConstEmUniqueIndex>k__BackingField` : System.Nullable<Int32>
`<IsKijinOnFromAimAttack>k__BackingField` : Boolean
`<IsMikiriASkill004>k__BackingField` : Boolean
`<IsMikiriBuff>k__BackingField` : Boolean
`<IsMikiriDodgeSuccessed>k__BackingField` : Boolean
`<KijinComboLv>k__BackingField` : app.Wp02Def.KIJIN_COMBO_LV
`<KijinGauge>k__BackingField` : app.cValueHolderF
`ConstSpinHitCount` : Int32
`IsAirKijinOnOff` : Boolean
`_ActionParam` : app.user_data.Wp02ActionParam
`_AimWeakHitInfo` : app.cHunterWp02Handling.cAimWeakHitInfo
`_AttackPostLock` : ace.cLockObject
`_BuffExtern` : Single
`_IsHit` : Boolean
`_IsKijinEnhancement` : Boolean
`_IsKijinEnhancementEffect` : Boolean
`_IsKijinOn` : Boolean
`_IsKijinOnEffect` : Boolean
`_KijinComboLvContinue` : Boolean
`_KijinEffectType` : app.Wp02Def.KIJIN_EFFECT_TYPE
`_KijinEnhancementEffectEffect` : via.effect.script.CreatedEffectContainer
`_KijinExtern` : Single
`_KijinOnEffect` : via.effect.script.CreatedEffectContainer
`_MikiriBuffEffect` : via.effect.script.CreatedEffectContainer
`_MikiriBuffTimer` : Single
`_MikiriCount` : Int32
`_MikiriSuccessFrame` : Boolean
`_WpGimmickMotType` : app.Wp02Def.WP_GIMMICK_MOT_TYPE

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : Nullable<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : Boolean
`<IsHitInfoContinue>k__BackingField` : Boolean
`<IsParryInfoContinue>k__BackingField` : Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : Single
`<ReserveShellWeaponAttackPower>k__BackingField` : Single
`<ReserveShellWeaponAttrPower>k__BackingField` : Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : Nullable<UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : Boolean
`_IsFittingMode` : Boolean
`_IsHitAttackToEnemy` : Boolean
`_IsHitWeakPoint` : Boolean
`_IsUseExtraStealthCollider` : Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : Int32
`_ScarBreakIndexList` : List<Int32>
`_Skill218or217Timer` : Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**app.cValueHolderF** (sub-fields): `DefaultValue` : Single, `MaxValue` : Nullable<Single>, `MinValue` : Nullable<Single>, `_Value` : Single

</details>

## Wp03 Long Sword (`ls`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| spiritGauge | `<RenkiGauge>k__BackingField` -> `_Value` | app.cValueHolderF (Single) | gauge 0..max (`MaxValue`) | high | renki = Spirit gauge; getter get_RenkiGauge, checkRenkiEnough, requestRenkiAdd, updateRenkiGauge |
| spiritLevel | `<AuraLevel>k__BackingField` | app.Wp03Def.AURA_LEVEL | enum (level) | high | aura colour level NONE=1/WHITE=2/YELLOW=3/RED=4 -> spiritLevel 0..3 = value-1 (INVALID=0 treat as 0); getter get_AuraLevel, addAuraLevel/consumeAuraLevel |
| iaiStance | current action index (`app.Wp03Action.ID`): IAI_WP_OFF=23 | ace.ACTION_ID._Index (Int32) | enum/action set | medium | IAI_WP_OFF = sheathe into Iai stance; stance ends when action changes to IAI_SLASH / IAI_KIJIN_SLASH_* / IAI_END. Category not verified |
| foresightSuccess | `IsMikiriSuccessed` | Boolean | bool flag | high | mikiri = foresight; set on Foresight Slash counter success (doSuccessMikiri) |
| iaiSuccess | `IsIaiKijinMikiriSuccessed` | Boolean | bool flag | high | Iai Spirit Slash (iai+kijin) counter success; doOnIaiKijinMikiriSuccessed |
| foresightHit (extra) | `IsMikiriHitSuccessed` | Boolean | bool flag | medium | foresight follow-up actually hit |
| redForesightHit (extra) | `IsRedMikiriHitSuccessed` | Boolean | bool flag | medium | foresight hit while at red aura |
| iaiSlashHit (extra) | `IsIaiSlashHitted` | Boolean | bool flag | medium | normal Iai Slash connected |
| iaiSpiritSlashHit (extra) | `IsIaiKijinSlashHitted` | Boolean | bool flag | medium | Iai Spirit Slash connected |
| redIaiSpiritHit (extra) | `IsRedIaiKijinHitted` / `_RedIaiKijinHitCount` | Boolean / Int32 | flag / counter | medium | red-level Iai Spirit hits |
| roundslashHit (extra) | `IsRedSlashRoundHitted` / `_RedSlashRoundHitCount` | Boolean / Int32 | flag / counter | medium | Spirit Roundslash at red hit; hit count |
| mikiriSuccessPulse (extra) | `_MikiriSuccessFrame` | Boolean | bool flag (likely 1-frame) | medium | set on the frame of a mikiri success |
| spiritChargeLv (extra) | `_KijinChargeLv` | app.Wp03Def.KIJIN_CHARGE_LV | level 0..3 | medium | Spirit Blade charge level (LV0..LV3); getter get_KijinChargeLv; `<RealKijinChargeLv>k__BackingField` is the alternate 'real' value |
| spiritFullCharge (extra) | `_IsKijinFullCharge` | Boolean | bool flag | medium | full spirit charge reached |
| helmBreakerStart (extra) | `_IsKabutowariStart` | Boolean | bool flag | medium | kabutowari = Spirit Helm Breaker started |
| helmBreakerHits (extra) | `_KabutowariHitNum` | Int32 | counter | medium | number of helm breaker hits |
| levelUp (extra) | `_IsAuraAdded` | Boolean | bool flag | low | probably set when aura level was added; reset timing unknown — prefer watching AuraLevel change |
| spiritConsumed (extra) | `IsRenkiConsumed` | Boolean | bool flag | low | spirit gauge consumed this action; prefer gauge delta |
| parry (extra) | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum | low | base parry state; LS uses mikiri flags instead |
| iaiAttack | current action index (`app.Wp03Action.ID`): IAI_END=24, IAI_SLASH=25, IAI_KIJIN_SLASH_NONE=26, IAI_KIJIN_SLASH_WHITE=27, IAI_KIJIN_SLASH_YELLOW=28, IAI_KIJIN_SLASH_RED=29 | ace.ACTION_ID._Index (Int32) | enum/action set | high | Iai Slash / Iai Spirit Slash actions (colour = Spirit level). Category not verified |

> spiritLevel: AURA_LEVEL is offset by one (NONE=1..RED=4); map level = max(value-1, 0). Getters: method get_RenkiGauge, get_AuraLevel, get_KijinChargeLv, get_RealKijinChargeLv, get_IsRenkiAutoRecover. iaiStance has no handling-class field; suggestion (unverified): check hunter's current action ID, or try `_IsIaiRenkiAutoRecoverIai` / method get_IsRenkiAutoRecover which may only be true while in iai stance. Main trap: AuraGauge is the decaying level-duration bar, not the Spirit gauge (that is RenkiGauge). Success booleans (IsMikiriSuccessed etc.) are ExposeMember public flags; trigger on false->true edge since their reset timing is unknown.

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp03Handling**
`<AuraGauge>k__BackingField` : app.cValueHolderF
`<AuraLevel>k__BackingField` : app.Wp03Def.AURA_LEVEL
`<KabutowariAuraLevel>k__BackingField` : app.Wp03Def.AURA_LEVEL
`<KabutowariStartPos>k__BackingField` : Nullable<via.vec3>
`<KijinChargeSpeedType>k__BackingField` : app.Wp03Def.KIJIN_CHARGE_SPEED_TYPE
`<KijinComboLv>k__BackingField` : app.Wp03Def.KIJIN_COMBO_LV
`<RealKijinChargeLv>k__BackingField` : app.Wp03Def.KIJIN_CHARGE_LV
`<RenkiConsumedContinue>k__BackingField` : Boolean
`<RenkiGauge>k__BackingField` : app.cValueHolderF
`<WeaponPointDelayInfoContinue>k__BackingField` : Boolean
`IsIaiKijinMikiriSuccessed` : Boolean
`IsIaiKijinSlashHitted` : Boolean
`IsIaiSlashHitted` : Boolean
`IsMikiriHitSuccessed` : Boolean
`IsMikiriSuccessed` : Boolean
`IsPorterDismountHitted` : Boolean
`IsPorterDismountMikiriSuccessed` : Boolean
`IsRedIaiKijinHitted` : Boolean
`IsRedMikiriHitSuccessed` : Boolean
`IsRedSlashRoundHitted` : Boolean
`IsRenkiConsumed` : Boolean
`WeakSlashDir` : ace.AceUtil.DIR4_FBLR
`_ActionParam` : app.user_data.Wp03ActionParam
`_AttackPostLock` : ace.cLockObject
`_AuraStopTimer` : Single
`_EmRideFinishDelayHitInfo` : cEmRideDelayShellInfo
`_EmRideFinishDelayHitTimer` : Single
`_IaiDelayHitAuraLevel` : app.Wp03Def.AURA_LEVEL
`_IaiDelayHitCreateShellTimer` : Single
`_IaiDelayHitInfo` : List<cDelayShellInfo>
`_IaiRenkiAutoRecoverTimerIai` : Single
`_IsAuraAdded` : Boolean
`_IsAuraStop` : Boolean
`_IsHit` : Boolean
`_IsIaiDelayHitStart` : Boolean
`_IsIaiRenkiAutoRecoverIai` : Boolean
`_IsKabutowariDelayHitSetup` : Boolean
`_IsKabutowariStart` : Boolean
`_IsKijinFullCharge` : Boolean
`_IsRenkiReleaseDelayShellSetup` : Boolean
`_IsRenkiReleaseDelayShellStart` : Boolean
`_IsWeakPointBreakDelayReserve` : Boolean
`_IsWeakPointDelayFirstExecuted` : Boolean
`_KabutowariConsumeAuraTimer` : Single
`_KabutowariCreateShellTimer` : Single
`_KabutowariHitNum` : Int32
`_KabutowariInfo` : List<cDelayShellInfo>
`_KabutowariShellNum` : Int32
`_KijinChargeContinue` : Boolean
`_KijinChargeLv` : app.Wp03Def.KIJIN_CHARGE_LV
`_KijinChargeTimer` : Single
`_KijinComboLvContinue` : Boolean
`_MikiriSuccessFrame` : Boolean
`_NoHitTimer` : Single
`_RedIaiKijinHitCount` : Int32
`_RedSlashRoundHitCount` : Int32
`_RenkiReleaseConsumeAuraTimer` : Single
`_RenkiReleaseDelayEndCreatShellTimer` : Single
`_RenkiReleaseDelayShellNoHitIndex` : List<Int32>
`_RenkiReleaseDelayShellNum` : Int32
`_RenkiReleaseHitInfo` : List<cDelayShellInfo>
`_RenkiReleaseShellInfo` : List<cRenkiReleaseShellInfo>
`_WeakPointBreakDelayTimer` : Single
`_WeakPointDelayAttackInfos` : List<cWeakSlashDelayShellInfo>

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : Nullable<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : Boolean
`<IsHitInfoContinue>k__BackingField` : Boolean
`<IsParryInfoContinue>k__BackingField` : Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : Single
`<ReserveShellWeaponAttackPower>k__BackingField` : Single
`<ReserveShellWeaponAttrPower>k__BackingField` : Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : Nullable<UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : Boolean
`_IsFittingMode` : Boolean
`_IsHitAttackToEnemy` : Boolean
`_IsHitWeakPoint` : Boolean
`_IsUseExtraStealthCollider` : Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : Int32
`_ScarBreakIndexList` : List<Int32>
`_Skill218or217Timer` : Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**app.cValueHolderF** (sub-fields): `DefaultValue` : Single, `MaxValue` : Nullable<Single>, `MinValue` : Nullable<Single>, `_Value` : Single

</details>

## Wp04 Hammer (`hammer`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| chargeLevel | `<ChargeLv>k__BackingField` (or method get_ChargeLv) | app.Wp04Def.CHARGE_LV | enum/level LV0=0..LV3=3 (MAX=4 is a count sentinel) | high | Exact name + enum with levels; get_ChargeLv/onChargeLvUp/levelUpChargeLv confirm it is the live level |
| charging | method get_IsCharging (no backing field in digest) | bool (method) | bool flag | medium | Getter literally named IsCharging exists but there is no _IsCharging field; fallback field-only proxy: `<ChargeLv>k__BackingField` > LV0 or `_IsPreCharging` (pre-charge phase only) |
| powerMode | `<SuperChargeLv>k__BackingField` (+ method get_IsSuperCharging for the on/off flag) | app.Wp04Def.SUPER_CHARGE_LV | enum/level LV0..LV3 (MAX=4) | medium | Wilds Power/Strength charge is the 'super charge' state; SuperChargeLv + IsSuperCharging + onSuperChargeLvUp + requestStopSuperCharge fit; no field literally named Power/Strength mode exists |
| parryAttack (extra) | `_IsParryAttack` | System.Boolean | bool flag | medium | Hammer offset/parry attack flag set by requestParryAttack; ExposeMember; `_ParryAttackRequest` is the request trap |
| parryState (extra) | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum NONE=0, WAIT=1, HIT=2, SUCCESS=3, RECOIL=4 | high | Base-class parry state; trigger haptic on transition to SUCCESS(3) |
| spinCount (extra) | `SpinCount` | System.Int32 | counter | medium | Spinning Bludgeon rotation counter (param _MaxSpinCount/_Attack1SpinCount exist); fire on increment |
| bounceHit (extra) | `<IsBounceAttackHit>k__BackingField` | Nullable<Boolean> | bool flag (nullable: nil/false/true) | low | Name suggests big-bang/bounce attack hit result; nullable so read via get_IsBounceAttackHit and treat nil as false |
| chargeContinue (extra) | `_ChargeContinue` | System.Boolean | bool flag | low | Charge carried through an action (requestChargeContinue); unknown exact semantics |
| hitEnemy (extra) | `_IsHitAttackToEnemy` | System.Boolean | bool flag | medium | Base-class hit flag, generic hit-confirm haptic |
| woundBreak (extra) | `_ScarBreakCount` | System.Int32 | counter | high | Wound (scar) break counter in base class; fire on increment |

> No field named Power/Strength mode exists; best match is the super charge (SUPER_CHARGE_LV + get_IsSuperCharging). Verify in game by watching <SuperChargeLv>k__BackingField while entering Power Charge. Charging has only a getter (get_IsCharging), no backing field. The digest has no 'Other enums in app.Wp04Def' section. Methods carry a numeric suffix in the dump (e.g. get_IsCharging510893).

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp04Handling**
`<ChargeAimIdleTurn>k__BackingField` : System.Boolean
`<ChargeLv>k__BackingField` : app.Wp04Def.CHARGE_LV
`<ChargeLvEffect>k__BackingField` : app.Wp04Def.CHARGE_LV
`<ChargePlace>k__BackingField` : app.Wp04Def.CHARGE_PLACE
`<IsAimHitMotionPhase2>k__BackingField` : System.Boolean
`<IsBounceAttackHit>k__BackingField` : System.Nullable`1<System.Boolean>
`<IsDodgeToStepUpEndAttack>k__BackingField` : System.Boolean
`<MoveBeforeDir>k__BackingField` : via.vec3
`<PrevVSwingMoveAttack>k__BackingField` : ace.ACTION_ID
`<SuperChargeLv>k__BackingField` : app.Wp04Def.SUPER_CHARGE_LV
`IsSkipStartCharge` : System.Boolean
`SpinCount` : System.Int32
`_ActionParam` : app.user_data.Wp04ActionParam
`_ChargeContinue` : System.Boolean
`_ChargeContinueWpGimmickType` : System.Boolean
`_ChargeTimer` : System.Single
`_IsNextScarInfo` : System.Boolean
`_IsParryAttack` : System.Boolean
`_IsPreCharging` : System.Boolean
`_IsRequestStartCharge` : System.Boolean
`_IsStopSuperCharge` : System.Boolean
`_ParryAttackRequest` : System.Boolean
`_StartChargeFrameTimer` : System.Single
`_SuperChargeTimer` : System.Single
`_WeakHitInfoList` : List<app.Wp04Def.cWeakHitInfo>
`_WpGimmickMotType` : app.Wp04Def.WP_GIMMICK_MOT_TYPE

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : Nullable<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : System.Boolean
`<IsHitInfoContinue>k__BackingField` : System.Boolean
`<IsParryInfoContinue>k__BackingField` : System.Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : System.Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : System.Single
`<ReserveShellWeaponAttackPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : Nullable<System.UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : System.Boolean
`_IsFittingMode` : System.Boolean
`_IsHitAttackToEnemy` : System.Boolean
`_IsHitWeakPoint` : System.Boolean
`_IsUseExtraStealthCollider` : System.Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : System.Int32
`_ScarBreakIndexList` : List<System.Int32>
`_Skill218or217Timer` : System.Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**Relevant methods (suffix stripped)**: get_ChargeLv, get_IsCharging, get_IsPreCharging, get_IsRequestStartCharge, get_IsSuperCharging, get_SuperChargeLv, get_ChargeTimeRate, get_ChargePlace, get_IsBounceAttackHit, onChargeLvUp, onSuperChargeLvUp, levelUpChargeLv, startCharge, startFullCharge, resetCharge, resetSuperCharge, requestStopSuperCharge, requestParryAttack, updateCharge, updateSuperCharge

</details>

## Wp05 Hunting Horn (`hh`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| notesStored | `_ToneBuffer` (via method get_ToneBuffer) | ace.cFixedRingBuffer`1<app.Wp05Def.TONE_TYPE> | counter (number of notes in the staff) | medium | Ring buffer of TONE_TYPE notes, reset by resetToneBuff; its count sub-field is NOT in the digest, so use the ring buffer's own count/size accessor (unverified). If you want songs stocked rather than notes, use `_MusicStockBuff` instead |
| performing | current action index (`app.Wp05Action.ID`): FAST_PLAYING=26, M_START_1=27, M_START_1_SP_00=28, M_START_1_SP_01=29, M_START_1_FRONT_ONLY=30, M_START_1_SP_00_FRONT_ONLY=31, M_START_1_SP_01_FRONT_ONLY=32, M_START_2=33, M_START_3=34, M_WAIT=35, M_MOVE=36, M_END=37, ADD_M_START=38, ADD_THREE_M_START=39, ADD_M_WAIT=40, ADD_M_MOVE=41, NEW_ADD_M_START=42, NEW_ADD_M_START_ATTACK_00_01=43 | ace.ACTION_ID._Index (Int32) | enum/action set | medium | "M" actions (M_START/M_WAIT/M_MOVE/M_END, ADD_M = encore) + FAST_PLAYING; "M" probably = music/melody (inferred). Category not verified |
| echoBubbleCount | `_HibikiFloatShellInfo` -> `_Ammo` | System.Byte (max in `_MaxAmmo`) | counter 0.._MaxAmmo | medium | Hibiki=echo, float shell = Echo Bubble; cTimeChargeAmmoBase stock with reload timer; getters get_IsHibikiFloatShellAmmoFull / get_HibikiFloatShellList confirm |
| songStocked (extra) | `_IsStockMusic` | System.Boolean | bool flag | medium | Set when a melody is stocked/ready; also method get_IsAvailableMusic |
| songAdded (extra) | `_AddMusicStock` | System.Boolean | bool flag (short pulse) | low | Name says a melody was added to the stock; good 'melody ready' haptic but may be a 1-frame pulse |
| echoType (extra) | `_HibikiFloatShellInfo` -> `_HibikiShellType` | WP05_HIBIKI_SKILL_TYPE | enum | medium | Which echo bubble type is equipped |
| musicGameSuccessNotes (extra) | `_MusicGame` -> `_SuccessNotesCount` | System.Int32 | counter | medium | Rhythm (great echo / offset) mini-game hits; fire on increment (successNotes/justSuccessNotes methods) |
| musicGameActive (extra) | `_MusicGame` -> `_IsGameStart` | System.Boolean | bool flag | medium | Rhythm mini-game running |
| justMAction (extra) | `_IsJustM_Action` | System.Boolean | bool flag | low | 'Just' timing performance action (requestJustM/unRequestJustM); exact semantics unknown |
| mStartCount (extra) | `<MStartCount>k__BackingField` | app.Wp05Def.MULTI_M_START | enum/level NONE=0..THREE=3 | low | Multi-performance start count; unknown exact trigger |
| parryState (extra) | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum, SUCCESS=3 | high | Base-class parry state (offset melody); trigger on SUCCESS |
| penetrateSoundHit (extra) | `_PenetrateSoundAttackHit` | System.Boolean | bool flag | medium | Special sound attack hit (SP_PENETRATE_SOUND_ATTACK); reset by resetPenetrateSoundAttackHit |
| hitEnemy (extra) | `_IsHitAttackToEnemy` | System.Boolean | bool flag | medium | Generic base-class hit confirm |

> notesStored: the digest does not list ace.cFixedRingBuffer sub-fields, so the element-count accessor for _ToneBuffer/_MusicStockBuff must be checked in REFramework's object explorer before you use it. Echo bubble = Hibiki float shell, a cTimeChargeAmmoBase (_Ammo/_MaxAmmo Byte). No performing flag exists; I recommend matching action IDs or hooking playMusic*. Strip numeric suffixes from method names (e.g. get_IsHibikiFloatShellAmmoFull450835).

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp05Handling**
`<MStartCount>k__BackingField` : app.Wp05Def.MULTI_M_START
`_AddMusicStock` : System.Boolean
`_AimShortAttackEnableTimer` : System.Single
`_DestroyCount` : System.Int32
`_EffectOrbFromPos` : via.vec3
`_EffectOrbToPos` : via.vec3
`_FirstPlayMusicStock` : app.Wp05Def.MUSIC_STOCK_TYPE
`_HibikiFloatShellInfo` : app.Wp05Def.cHibikiFloatShellInfo
`_HighFreqSkill` : app.Wp05Def.WP05_MUSIC_SKILL_HIGH_FREQ_TYPE
`_IsFirstPlay3Tone` : System.Boolean
`_IsFreeToneInput` : System.Boolean
`_IsJustM_Action` : System.Boolean
`_IsNextScarInfo` : System.Boolean
`_IsRequestJustTimingEffect` : System.Boolean
`_IsRequestKillAllNotesEffect` : System.Boolean
`_IsRequestKillNotesEffect` : System.Boolean
`_IsRequestMusicEffect` : System.Boolean
`_IsRequestNotesEffect` : System.Boolean
`_IsRequestNotesJustSuccessEffect` : System.Boolean
`_IsRequestNotesSuccessEffect` : System.Boolean
`_IsStockMusic` : System.Boolean
`_LastPlayedMusic` : System.Int32[]
`_MStartTimeRequest` : System.Boolean
`_MStartTimer` : System.Single
`_MultiLevelMusicBuff` : System.Int32[]
`_MusicAttackToDodgeInvalidResetTime` : System.Single
`_MusicDatas` : app.Wp05Def.cMusic[]
`_MusicGame` : app.cWp05MusicGame
`_MusicStockBuff` : ace.cFixedRingBuffer`1<WP05_MUSIC_SKILL_TYPE>
`_MusicStockBuffSortCopy` : ace.cFixedRingBuffer`1<WP05_MUSIC_SKILL_TYPE>
`_MusicStockBuff_MusicDataIdBuff` : ace.cFixedRingBuffer`1<System.UInt32>
`_NotesEffect` : via.effect.script.CreatedEffectContainer
`_NotesEffectEm` : via.effect.script.CreatedEffectContainer
`_NotesEffectList` : List<CreatedEffectContainer>
`_NotesEffectPl` : via.effect.script.CreatedEffectContainer
`_PenetrateSoundAttackHit` : System.Boolean
`_PenetrateSoundShellCreated` : System.Boolean
`_PenetrateSoundShellRequested` : System.Boolean
`_PlayTone` : System.Boolean
`_PlayWMusic` : System.Boolean
`_PlayedStockBuff` : ace.cFixedRingBuffer`1<WP05_MUSIC_SKILL_TYPE>
`_SpMusicStockBuff` : app.Wp05Def.WP05_MUSIC_SKILL_TYPE
`_SpMusicStockBuff_MusicDataIdBuff` : System.UInt32
`_ToneBuffer` : ace.cFixedRingBuffer`1<app.Wp05Def.TONE_TYPE>
`_ToneCol_1` : app.Wp05Def.WP05_TONE_COLOR_TYPE
`_ToneCol_2` : app.Wp05Def.WP05_TONE_COLOR_TYPE
`_ToneCol_3` : app.Wp05Def.WP05_TONE_COLOR_TYPE
`_ToneFreeInput_Attack00` : app.cHunterWp05Handling.cToneFreeInput
`_ToneFreeInput_Attack01` : app.cHunterWp05Handling.cToneFreeInput
`_WeakHitInfo` : app.Wp05Def.cWeakHitInfo
`_WeakHitInfoList` : List<app.Wp05Def.cWeakHitInfo>
`_WpGimmickMotType` : app.Wp05Def.WP_GIMMICK_MOT_TYPE

**app.cHunterWeaponHandlingBase**
(same 31 base fields as hammer: `<AimAttackHitTargetCol>k__BackingField`, `<AimAttackSightPos>k__BackingField`, `<AimAttackTargetCol>k__BackingField`, `<Hunter>k__BackingField`, `<IsDrawOffRequested>k__BackingField`, `<IsHitInfoContinue>k__BackingField`, `<IsParryInfoContinue>k__BackingField`, `<ParryState>k__BackingField` : PARRY_STATE, `<ParryTarget>k__BackingField`, `<RequestRecoil>k__BackingField`, `<ReserveShellOriginalCriticalRate>k__BackingField`, `<ReserveShellWeaponAttackPower>k__BackingField`, `<ReserveShellWeaponAttrPower>k__BackingField`, `<ReserveShellWeaponAttrType>k__BackingField`, `WeakPointRWLock`, `_AimAtkHitTargetOfs`, `_AimRangeSensorRequestSetID`, `_AimTargetOfs`, `_ExFieldWeakHitInfoList`, `_IsAimSearchSuccess`, `_IsFittingMode`, `_IsHitAttackToEnemy` : Boolean, `_IsHitWeakPoint` : Boolean, `_IsUseExtraStealthCollider`, `_Kireaji` : app.cWeaponKireaji, `_MikiriInfo`, `_MikiriLockObject`, `_ScarBreakCount` : Int32, `_ScarBreakIndexList`, `_Skill218or217Timer` : Single, `_WpExGimmickMotPhase` : WP_EX_GIMMICK_MOT_PHASE)

**Sub-fields**
`app.Wp05Def.cHibikiFloatShellInfo`: `_HibikiShellType` : WP05_HIBIKI_SKILL_TYPE, `_Ammo` : Byte, `_MaxAmmo` : Byte, `_MaxReloadTime` : Single, `_MaxReloadTimeRate` : Single, `_ReloadTimer` : Single
`app.cWp05MusicGame`: `NearNotesRate` : Single, `_BPM_Beat_Timer` : Single, `_BPS` : Single, `_Beat_Speed` : Single, `_CreateNotesCount` : Int32, `_DestroyNotesCount` : Int32, `_IsGameStart` : Boolean, `_IsGameStarting` : Boolean, `_IsLastNoersPush` : Boolean, `_NotesList` : Notes[], `_OldBPM` : Single, `_OldBeatNotes` : Int32, `_SuccessNotesCount` : Int32

**Relevant methods (suffix stripped)**: get_ToneBuffer, get_MusicStockBuff, get_IsStockMusic, get_IsAvailableMusic, get_IsAvailableSpMusic, get_HibikiFloatShellInfo, get_HibikiFloatShellList, get_IsHibikiFloatShellAmmoFull, get_HibikiShellType, get_MusicGame, get_MStartCount, get_IsMStartTime, playTone, playMusic, playMusicW, playSpMusic, playAllMusic, playHibiki, successNotes, justSuccessNotes, createHibikiFloatShell, createFullComboShell

</details>

## Wp06 Lance (`lance`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| guarding | method `app.HunterCharacter.checkHunterStatusFlag` (arg `app.HunterDef.STATUS_FLAG.GUARD=2`) | → bool (return type not checked) | bool flag | medium | Guard is a hunter-level status, not a weapon field. Exists in dump; untested in-game |
| powerGuard | method `app.HunterCharacter.checkHunterStatusFlag` (arg `app.HunterDef.STATUS_FLAG.POWER_GUARD=3`) | → bool (return type not checked) | bool flag | medium | Guard is a hunter-level status, not a weapon field. Exists in dump; untested in-game |
| guardHit (extra) | `app.HunterCharacter.get_DamageInfo()._DamageType` | app.HunterDef.DAMAGE_TYPE | enum: GUARD_S=34, GUARD_M=35, GUARD_L=36, GUARD_TECH=37, GUARD_TECH_M=38, GUARD_POINT_S/M/L=41-43, POWER_GUARD=44 | medium | Damage type when an attack is blocked; S/M/L = block strength. Value may persist after the hit → detect change or hook `HunterCharacter.evHit_Damage`. Untested |
| lanceCharge | `_RushLevel` | System.Int32 | level | medium | Rush (突進) is Lance's Charge. Level rises via rushLevelAdd and falls via rushLevelSub. Getter get_RushLevel, max-reached check method get_IsRushLevelMax. Not a pure 'running' bool: the value is probably 0 when not charging. |
| lanceChargeStrong (extra) | `<IsStrongRush>k__BackingField` | System.Boolean | bool flag | medium | 'Strong rush' = upgraded/fast charge phase (getter get_IsStrongRush). Good for a rumble step-up. |
| guardSuccess (extra) | `_IsGuardSuccess` | System.Boolean | bool flag | high | Getter get_IsGuardSuccess, set by reqestGuardSuccess. Rising edge = blocked a hit. |
| parryState (extra) | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum | medium | Base-class parry state (NONE/WAIT/HIT/SUCCESS/RECOIL). Lance's perfect guard / counter probably goes through it; fire on SUCCESS=3. |
| finishChargeLevel (extra) | `_FinishChargeLevel` | System.Int32 | level | medium | Charge level of the finishing thrust/counter (setFinishChargeLevel, get_IsMaxFinishChargeLevel). Pulse once per level increase. |
| finishCounterSuccess (extra) | `IsFinishCounterSuccessed` | System.Boolean | bool flag | medium | Public exposed bool: the finishing counter landed. Rising edge = counter success. |
| guardToFinishStingerLv (extra) | `_GuardToFinishStingerChargeLv` | System.Int32 | level | low | Charge level gained by guarding toward the finish stinger (getter get_GuardToFinishStingerChargeLv). Exact range unknown. |
| stepCount (extra) | `_StepCount` | System.Int32 | counter | medium | Hop/back-step count (onStep, get_StepCount). Each increment = one hop. |
| hitEnemy (extra) | `_IsHitAttackToEnemy` | System.Boolean | bool flag | medium | Base class: an attack hit an enemy. Generic hit-confirm trigger. |

> guarding and powerGuard active-state flags do NOT exist on cHunterWp06Handling. Read them from the action ID / hunter status instead. As a fallback, `_PowerGuardMaxReactCount` (int, increments on power-guard reactions) works as a 'power guard hit' trigger, and `_IsGuardSuccess` as a 'guard hit' trigger. Charge = Rush in the dump (`_RushLevel`, `<IsStrongRush>k__BackingField`, get_IsRushLevelMax). Useful getters: get_IsGuardSuccess, get_RushLevel, get_IsRushLevelMax, get_IsStrongRush, get_IsMaxFinishChargeLevel, get_PowerGuardMaxReactCount, get_IsPowerGurdMaxReactCount (typo is Capcom's). Source digest: C:/Users/ADMIN/AppData/Local/Temp/claude/c--KHANG-code-MHWilds-Rumble-Project/baa3ada1-6ffa-4aec-8bfb-650d3f64ed8b/scratchpad/digest/wp06.md

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp06Handling**
`<IsAimHitEndMotion>k__BackingField` : System.Boolean
`<IsCanRushSliding>k__BackingField` : System.Boolean
`<IsFinishCounterEndMotion>k__BackingField` : System.Boolean
`<IsStrongMotion>k__BackingField` : System.Boolean
`<IsStrongRush>k__BackingField` : System.Boolean
`<PreGuardAxisZ>k__BackingField` : via.vec3
`<PreGuardTurnAxisZ>k__BackingField` : System.Nullable`1<via.vec3>
`IsFinishCounterSuccessed` : System.Boolean
`_CounterInfo` : List<app.cHunterWp06Handling.cCounterInfo>
`_EffectContainer` : via.effect.script.CreatedEffectContainer
`_EmRideFinishInfo` : app.Wp06Def.cEmRideFinishInfo
`_FinishChargeLevel` : System.Int32
`_FinishChargeLevelForAction` : System.Int32
`_FinishChargeTimer` : System.Single
`_FinishCounterShell` : ace.ShellBase
`_GuardToDir4GuardDashTimer` : System.Single
`_GuardToFinishStingerChargeLv` : System.Int32
`_IsBackStep` : System.Boolean
`_IsGuardSuccess` : System.Boolean
`_IsNextScarInfo` : System.Boolean
`_IsRequestFinishLevel` : System.Boolean
`_IsRequestPowerGuardMaxReactCountReset` : System.Boolean
`_IsRushToGuard` : System.Boolean
`_MaxGuardToFinishStingerChargeLvTime` : System.Single
`_PowerGuardMaxReactCount` : System.Int32
`_PowerGuardMaxReactCountEffect` : System.Int32
`_PreFinishChargeLevel` : System.Int32
`_RideAttackTimer` : System.Single
`_RushLevel` : System.Int32
`_RushLevelTimer` : System.Single
`_StepCount` : System.Int32
`_ToFastRushTimer` : System.Single
`_WeakHitInfoList` : List<app.Wp04Def.cWeakHitInfo>
`_WpGimmickMotType` : app.Wp06Def.WP_GIMMICK_MOT_TYPE

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : System.Nullable`1<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : System.Boolean
`<IsHitInfoContinue>k__BackingField` : System.Boolean
`<IsParryInfoContinue>k__BackingField` : System.Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : System.Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : System.Single
`<ReserveShellWeaponAttackPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : System.Nullable`1<System.UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<app.cHunterWeaponHandlingBase.cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : System.Boolean
`_IsFittingMode` : System.Boolean
`_IsHitAttackToEnemy` : System.Boolean
`_IsHitWeakPoint` : System.Boolean
`_IsUseExtraStealthCollider` : System.Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<app.cHunterWeaponHandlingBase.cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : System.Int32
`_ScarBreakIndexList` : List<System.Int32>
`_Skill218or217Timer` : System.Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

</details>

## Wp07 Gunlance (`gl`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| shellsLoaded | method:get_LoadedAmmo (backing data `_Ammo` -> `_LoadedAmmo`) | via.rds.Mandrake (inside app.cAmmo) | counter | high | `_LoadedAmmo` is the loaded shell count, with reloadShell/requestBulletFire changing it. Mandrake is an obfuscated/encrypted value type, so read it through the getter get_LoadedAmmo (or get_IsLoadedAmmo for >0), not the raw field. |
| wyrmstakeLoaded | `_IsPileLoaded` | System.Boolean | bool flag | high | Pile = Wyrmstake. Getter get_IsPileLoaded, set by reloadPile and cleared by shootPileShell. |
| wyvernsFire | `_RyuugekiGauge` -> `_Value` | app.cValueHolderF -> System.Single | gauge 0..max | high | Ryuugeki = Wyvern's Fire. Has requestRyuugekiAdd, resetRyuugekiGauge and setRyuugekiValue. Getter get_RyuugekiGaugeRate gives a normalized rate. For 'ready', use method get_CanRyuugekiShoot. |
| wyvernsFireReady (extra) | method:get_CanRyuugekiShoot | bool (method) | bool flag | medium | Getter name says Wyvern's Fire can be fired. Rising edge = gauge ready. |
| guard (flag) | method `app.HunterCharacter.checkHunterStatusFlag` (arg `app.HunterDef.STATUS_FLAG.GUARD=2`) | → bool (return type not checked) | bool flag | medium | Guard is a hunter-level status, not a weapon field. Exists in dump; untested in-game |
| guardHit (extra) | `app.HunterCharacter.get_DamageInfo()._DamageType` | app.HunterDef.DAMAGE_TYPE | enum: GUARD_S=34, GUARD_M=35, GUARD_L=36, GUARD_TECH=37, GUARD_TECH_M=38, GUARD_POINT_S/M/L=41-43, POWER_GUARD=44 | medium | Damage type when an attack is blocked; S/M/L = block strength. Value may persist after the hit → detect change or hook `HunterCharacter.evHit_Damage`. Untested |
| parryState (extra) | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum | low | Base-class parry state. Unclear whether Gunlance perfect guard uses it; fire on SUCCESS=3 if it does. |
| chargeShotCount (extra) | `_ChargeShotCount` | System.Int32 | counter | medium | Shots fired in the current charged shell (chargeShotProcess). Increments per blast. |
| fullBurstShotCount (extra) | `_FullBurstShotCount` | System.Int32 | counter | medium | Shells fired so far in a Full Burst (updateFullBurst). One pulse per shell. |
| fullBurstTrigger (extra) | `_IsTriggerFullBurst` | System.Boolean | bool flag | medium | Set when a Full Burst is triggered (requestFullBurst/setupFullBurst). Rising edge = burst start. |
| chargeShotTrigger (extra) | `_IsTriggerChargeShot` | System.Boolean | bool flag | medium | Set when a charged shell triggers (requestChargeShot). |
| fullBurstType (extra) | `_FullBurstType` | app.Wp07Def.FULL_BURST_TYPE | enum | low | Which burst variant (V_SLASH/BF/RBF) to pick a rumble pattern. Changing alone is not an event. |
| stepCount (extra) | `_StepCount` | System.Int32 | counter | medium | Hop count (onStep, get_StepCount). |
| hitEnemy (extra) | `_IsHitAttackToEnemy` | System.Boolean | bool flag | medium | Base class: an attack hit an enemy. |

> Loaded shells live in `_Ammo` (app.cAmmo) -> `_LoadedAmmo`, but they are stored as via.rds.Mandrake (encrypted), so poll the getter get_LoadedAmmo (get_IsLoadedAmmo for a bool, get_LimitAmmo for capacity). Wyrmstake = Pile: `_IsPileLoaded` / get_IsPileLoaded. Wyvern's Fire = Ryuugeki: `_RyuugekiGauge` (app.cValueHolderF) -> `_Value`. get_RyuugekiGaugeRate gives a normalized rate and get_CanRyuugekiShoot gives readiness. No guard-state field exists in the Gunlance handling; use the action ID / hunter status. Source digest: C:/Users/ADMIN/AppData/Local/Temp/claude/c--KHANG-code-MHWilds-Rumble-Project/baa3ada1-6ffa-4aec-8bfb-650d3f64ed8b/scratchpad/digest/wp07.md

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp07Handling**
`_AimDrillEndTimer` : System.Single
`_AimDrillShell` : ace.ShellBase
`_AimHitInfo` : app.cHunterWp07Handling.AIM_HIT_INFO
`_Ammo` : app.cAmmo
`_CanRoastCornDispLog` : System.Boolean
`_ChargeShotBeginPos` : via.vec3
`_ChargeShotBulletNum` : System.Int32
`_ChargeShotCount` : System.Int32
`_ChargeShotDir` : via.vec3
`_ChargeShotElapsedTimer` : System.Single
`_FullBurstBulletNum` : System.Int32
`_FullBurstConstOffsetAngle` : via.vec3
`_FullBurstDelayTime` : System.Single
`_FullBurstElapsedTimer` : System.Single
`_FullBurstFirstShootDir` : via.vec3
`_FullBurstOffsetAngle` : via.vec3
`_FullBurstShotCount` : System.Int32
`_FullBurstType` : app.Wp07Def.FULL_BURST_TYPE
`_GuardQuickReloadDir` : app.Wp07Def.COMBO_DIR
`_GuardQuickReloadTimer` : System.Single
`_GuardShortRyuugekiTimer` : System.Single
`_IsKeepAtk01` : System.Boolean
`_IsKeepAtk01FromLastAct` : System.Boolean
`_IsPileLoaded` : System.Boolean
`_IsRequestedEffectWeaponOn` : System.Boolean
`_IsTriggerChargeShot` : System.Boolean
`_IsTriggerFullBurst` : System.Boolean
`_KeepAtk01Timer` : System.Single
`_RideAttackTimer` : System.Single
`_RyuugekiGauge` : app.cValueHolderF  (sub: `DefaultValue` Single, `MaxValue` Nullable<Single>, `MinValue` Nullable<Single>, `_Value` Single)
`_ShellLevel` : System.Int32
`_ShellType` : app.Wp07Def.SHELL_TYPE
`_StepCount` : System.Int32
`_WpGimmickMotType` : app.Wp07Def.WP_GIMMICK_MOT_TYPE

(app.cAmmo sub-fields: `_BackupAmmo`, `_LimitAmmo`, `_LoadedAmmo` : via.rds.Mandrake)

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : System.Nullable`1<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : System.Boolean
`<IsHitInfoContinue>k__BackingField` : System.Boolean
`<IsParryInfoContinue>k__BackingField` : System.Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : System.Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : System.Single
`<ReserveShellWeaponAttackPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : System.Nullable`1<System.UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<app.cHunterWeaponHandlingBase.cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : System.Boolean
`_IsFittingMode` : System.Boolean
`_IsHitAttackToEnemy` : System.Boolean
`_IsHitWeakPoint` : System.Boolean
`_IsUseExtraStealthCollider` : System.Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<app.cHunterWeaponHandlingBase.cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : System.Int32
`_ScarBreakIndexList` : List<System.Int32>
`_Skill218or217Timer` : System.Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

</details>

## Wp08 Switch Axe (`sa`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| mode | `_Mode` | app.Wp08Def.MODE | enum (AXE=0, SWORD=1) | high | Exact Mode enum with AXE/SWORD values; getter get_Mode and changeMode methods back it |
| switchGauge | `_SlashGauge` -> `_Value` | app.cValueHolderF -> System.Single | gauge 0..max (read MaxValue for the cap) | high | ExposeMember gauge with addSlashGauge, subSlashGauge, get_SlashGauge and get_SlashGaugeRate methods. NOT the _SlashGaugeAutoRecoveryTimer trap |
| swordAmp | method `get_IsSwordAwaken` (field fallback: `_SwordAwakeTimer` > 0) | bool (method) / System.Single | bool flag (method); the timer counts while amped | medium | awake=amped; the beginSwordAwaken and endSwordAwaken methods mark it as a state. No bool field exists, so the field fallback is to treat timer>0 as active and only watch for the 0 to >0 edge |
| swordAmp build-up (extra: ampGauge) | `_SwordAwakeGauge` -> `_Value` | app.cValueHolderF -> System.Single | gauge 0..max | high | Amp gauge that fills before awakening (addSwordAwakeGauge, get_SwordAwakeGaugeRate) |
| dischargeActive | current action index (`app.Wp08Action.ID`): SWORD_DISCHARGE_STAB=34, SWORD_DISCHARGE_STAB_SHORT=35, SWORD_DISCHARGE_STAB_END=36, SWORD_DISCHARGE_STAB_ATTACK=37, SWORD_DISCHARGE_STAB_FINISH=38, SWORD_DISCHARGE_STAB_FINISH_WEAK=39, SWORD_DISCHARGE_STAB_AIM_FINISH=40, SWORD_DISCHARGE_CONST=41, SWORD_DISCHARGE_CONST_FINISH=42, SWORD_DISCHARGE_CONST_FINISH_WEAK=43, SWORD_DISCHARGE_SWITCH_FINISH_START=44, SWORD_DISCHARGE_SWITCH_FINISH=45, SWORD_DISCHARGE_SWITCH_CHARGE_FINISH=46, SWORD_JUMP_DISCHARGE_STAB=67, SWORD_JUMP_DISCHARGE_STAB_LAND=68 | ace.ACTION_ID._Index (Int32) | enum/action set | high | SWORD_DISCHARGE_* = Zero Sum / Element Discharge actions. Category not verified |
| axeEnhanced (extra) | method `get_IsAxeEnhanced` (field fallback: `_AxeEnhancedTimer` > 0) | bool (method) / System.Single | bool flag (method) / timer | medium | The beginAxeEnhanced and endAxeEnhanced methods pair with effect PL_WP08_AXE_ENHANCED. The timer fallback needs an edge check |
| parry / counter (extra) | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum (NONE=0, WAIT=1, HIT=2, SUCCESS=3, RECOIL=4) | medium | Base-class parry state; fire on a transition to SUCCESS. SA has counter/parry finishers (SHELL_TYPE SWORD_PARRY_FINISH_CONST) |
| hitEnemy (extra) | `_IsHitAttackToEnemy` | System.Boolean | bool flag | medium | Base-class ExposeMember hit flag; a rising edge means a landed hit |
| woundBreak (extra) | `_ScarBreakCount` | System.Int32 | counter | medium | Increments via addScarBreakCount when a wound is destroyed |
| phialValue (extra) | `_BinValue` | System.Single | unknown | low | ExposeMember float tied to getWp08BinValue/checkBinValueLimit; meaning unclear (possibly a phial power value, possibly static) |

> SA MODE enum is AXE=0, SWORD=1. CB's MODE is the opposite (SWORD=0, AXE=1). The max for the gauges comes from cValueHolderF.MaxValue (Nullable) or the get_SlashGaugeRate / get_SwordAwakeGaugeRate methods (normalised 0..1). dischargeActive has no field. Suggestion: action ID, or a low-confidence proxy via the _DischargeConstEmUniqueIndex change. Method names have their id suffix stripped.

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp08Handling**
`_AimHitInfo` : app.cHunterWp08Handling.AIM_HIT_INFO
`_AxeEnhancedTimer` : System.Single
`_BinEffectID` : app.Wp08Def.BIN_TYPE_EFFECT_ID
`_BinType` : app.Wp08Def.BIN_TYPE
`_BinValue` : System.Single
`_DischargeConstEmUniqueIndex` : System.Int32
`_DischargeConstPointIndex` : System.Int32
`_DischargeHitEffectCheckTimer` : System.Single
`_DischargeMeshConstResult` : app.cMeshIntersectionResultWrapper
`_Mode` : app.Wp08Def.MODE
`_PrevWpAttr` : app.WeaponDef.ATTR
`_SlashGauge` : app.cValueHolderF
`_SlashGaugeAutoRecoveryTimer` : System.Single
`_SwordAddConstShellNum` : System.Int32
`_SwordAwakeGauge` : app.cValueHolderF
`_SwordAwakeGaugeAutoReduceTimer` : System.Single
`_SwordAwakeTimer` : System.Single
`_WpGimmickMotType` : app.Wp08Def.WP_GIMMICK_MOT_TYPE

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : System.Nullable`1<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : System.Boolean
`<IsHitInfoContinue>k__BackingField` : System.Boolean
`<IsParryInfoContinue>k__BackingField` : System.Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : System.Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : System.Single
`<ReserveShellWeaponAttackPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : System.Nullable`1<System.UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<app.cHunterWeaponHandlingBase.cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : System.Boolean
`_IsFittingMode` : System.Boolean
`_IsHitAttackToEnemy` : System.Boolean
`_IsHitWeakPoint` : System.Boolean
`_IsUseExtraStealthCollider` : System.Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<app.cHunterWeaponHandlingBase.cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : System.Int32
`_ScarBreakIndexList` : List<System.Int32>
`_Skill218or217Timer` : System.Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**app.cValueHolderF (sub-fields)**
`DefaultValue` : System.Single
`MaxValue` : System.Nullable`1<System.Single>
`MinValue` : System.Nullable`1<System.Single>
`_Value` : System.Single

</details>

## Wp09 Charge Blade (`cb`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| phials | `_SwordBinNum` -> `_Value` | app.cValueHolder -> System.Int32 | counter 0..max (MaxValue) | high | bin=phial; ExposeMember with the reloadBin/consumeBin/consumeAllBin methods |
| swordCharged | method `get_IsSwordEnhanced` (field fallback: `_SwordEnhancedTimer` > 0) | bool (method) / System.Single | bool flag (method); timer counting down while active | medium | The enhanceSword and endSwordEnhanced methods mark this as the Sword Boost (charged blade) state, matching effect PL_WP09_SWORD_ENHANCED. No bool field exists |
| shieldCharged | method `get_IsShieldEnhanced` (field fallback: `_ShieldEnhancedTimer` > 0) | bool (method) / System.Single | bool flag (method); timer | medium | The enhanceShield and endShieldEnhanced methods pair with effect PL_WP09_SHIELD_ENHANCED. No bool field exists |
| savageAxe | method `get_IsAxeEnhanced` (field fallback: `_AxeEnhancedTimer` > 0) | bool (method) / System.Single | bool flag (method); timer | medium | The enhanceAxe and endAxeEnhanced methods pair with effect PL_WP09_AXE_ENHANCED / AXE_SAW_ACTIVE; savage axe = power axe mode |
| mode | `_Mode` | app.Wp09Def.MODE | enum (SWORD=0, AXE=1) | high | Exact Mode enum; get_Mode and changeMode back it |
| guard (flag) | method `app.HunterCharacter.checkHunterStatusFlag` (arg `app.HunterDef.STATUS_FLAG.GUARD=2`) | → bool (return type not checked) | bool flag | medium | Guard is a hunter-level status, not a weapon field. Exists in dump; untested in-game |
| guardHit (extra) | `app.HunterCharacter.get_DamageInfo()._DamageType` | app.HunterDef.DAMAGE_TYPE | enum: GUARD_S=34, GUARD_M=35, GUARD_L=36, GUARD_TECH=37, GUARD_TECH_M=38, GUARD_POINT_S/M/L=41-43, POWER_GUARD=44 | medium | Damage type when an attack is blocked; S/M/L = block strength. Value may persist after the hit → detect change or hook `HunterCharacter.evHit_Damage`. Untested |
| guardPoint (extra) | method `app.HunterCharacter.checkHunterStatusFlag` (arg `app.HunterDef.STATUS_FLAG.GUARD_POINT=6`) | → bool (return type not checked) | bool flag | medium | Guard is a hunter-level status, not a weapon field. Exists in dump; untested in-game |
| overchargedPhials (extra) | `_SwordOverChargedBinNum` -> `_Value` | app.cValueHolder -> System.Int32 | counter | high | Overcharged phial count (red phials); isOverChargeReload method |
| swordEnergy (extra) | `_SwordEnergyPoint` -> `_Value` | app.cValueHolderF -> System.Single | gauge 0..max | high | Sword energy (phial-charge build-up) gauge; addSwordEnergyPoint |
| swordEnergyState (extra) | `_SwordEnergyState` | app.Wp09Def.SWORD_ENERGY_STATE | enum (NONE=0, RELOAD_S=1, RELOAD_L=2, OVER_HEAT=3) | high | Sword glow stage (yellow/red/overheat); setSwordEnergyState, get_IsOverHeat. A change to OVER_HEAT is a good bounce-off rumble |
| axeSawHit (extra) | `_AxeSawHitStopState` | app.Wp09Def.AXE_SAW_HIT_STOP_STATE | enum (NONE=0, READY=1, HIT=2, DONE=3) | medium | Saw hit-stop state; a transition to HIT = grinding contact |
| axeSawSpin (extra) | `_AxeSawMotionState` | app.Wp09Def.AXE_SAW_MOTION_STATE | enum (NONE=0, ROTATE=1, END=2) | medium | ROTATE = saw spinning (grind) |
| axeSawHitCount (extra) | `_AxeSawAttackCountInAction` | System.UInt32 | counter (per action) | medium | Increments per saw tick inside one action; resets per action |
| dischargeShell (extra) | `_ShellCreateMode` | app.Wp09Def.SHELL_CREATE_MODE | enum (NONE=0, AXE_ATTRIBUTE=1, AXE_DISCHARGE=2, AXE_DISCHARGE_2=3, SWORD_ENHANCED=4, SHIELD_ATTACK=5) | medium | Set during AED/SAED/discharge moves (setShellCreateMode/resetShellCreateMode); non-NONE = phial explosion move active |
| parryState (extra) | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum (NONE=0, WAIT=1, HIT=2, SUCCESS=3, RECOIL=4) | medium | Base-class parry state; SUCCESS for perfect guard / guard-point counter if CB uses it |
| hitEnemy (extra) | `_IsHitAttackToEnemy` | System.Boolean | bool flag | medium | Base-class hit flag |

> _SwordBinNum and _SwordOverChargedBinNum are app.cValueHolder (Int32 _Value), not cValueHolderF. CB MODE is SWORD=0, AXE=1, the reverse of SA. The other getters also exist: get_IsOverHeat, get_IsAxeSawHitStop, get_SwordBinNum, get_SwordEnergyPoint, get_SwordEnergyState, get_SwordOverChargedBinNum. If 'swordCharged' means the sword glow level rather than Sword Boost mode, use _SwordEnergyState instead. guard is not in the handling class. Suggestion: the hunter action ID or guard status on app.HunterCharacter.

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp09Handling**
`_ActionEnterBinNum` : System.Int32
`_ActionEnterOverChargedBinNum` : System.Int32
`_AimHitInfo` : app.cHunterWp09Handling.AIM_HIT_INFO
`_AxeEnhancedTimer` : System.Single
`_AxeSawAttackCountInAction` : System.UInt32
`_AxeSawHitStopNoHitTimer` : System.Single
`_AxeSawHitStopState` : app.Wp09Def.AXE_SAW_HIT_STOP_STATE
`_AxeSawHitStopTimer` : System.Single
`_AxeSawMotionState` : app.Wp09Def.AXE_SAW_MOTION_STATE
`_BinEffectID` : app.Wp09Def.BIN_TYPE_EFFECT_ID
`_BinType` : app.Wp09Def.BIN_TYPE
`_Mode` : app.Wp09Def.MODE
`_PrevWpAttr` : app.WeaponDef.ATTR
`_ShellCreateMode` : app.Wp09Def.SHELL_CREATE_MODE
`_ShieldEnhancedTimer` : System.Single
`_SwordBinNum` : app.cValueHolder
`_SwordEnergyPoint` : app.cValueHolderF
`_SwordEnergyState` : app.Wp09Def.SWORD_ENERGY_STATE
`_SwordEnhancedTimer` : System.Single
`_SwordOverChargedBinNum` : app.cValueHolder
`_WpGimmickMotType` : app.Wp09Def.WP_GIMMICK_MOT_TYPE

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : System.Nullable`1<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : System.Boolean
`<IsHitInfoContinue>k__BackingField` : System.Boolean
`<IsParryInfoContinue>k__BackingField` : System.Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : System.Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : System.Single
`<ReserveShellWeaponAttackPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : System.Nullable`1<System.UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<app.cHunterWeaponHandlingBase.cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : System.Boolean
`_IsFittingMode` : System.Boolean
`_IsHitAttackToEnemy` : System.Boolean
`_IsHitWeakPoint` : System.Boolean
`_IsUseExtraStealthCollider` : System.Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<app.cHunterWeaponHandlingBase.cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : System.Int32
`_ScarBreakIndexList` : List<System.Int32>
`_Skill218or217Timer` : System.Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**app.cValueHolder (sub-fields)**
`DefaultValue` : System.Int32
`MaxValue` : System.Nullable`1<System.Int32>
`MinValue` : System.Nullable`1<System.Int32>
`_Value` : System.Int32

**app.cValueHolderF (sub-fields)**
`DefaultValue` : System.Single
`MaxValue` : System.Nullable`1<System.Single>
`MinValue` : System.Nullable`1<System.Single>
`_Value` : System.Single

</details>

## Wp10 Insect Glaive (`ig`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| redExtract | `get_IsRed` (method) ; raw alt `ExtractTimer[0]._Value` | bool / Single | bool flag (method); timer counting down (array) | high | Method name literal; app.Wp10Def.EXTRACT_TYPE RED=0 indexes ExtractTimer array (index mapping inferred, verify) |
| whiteExtract | `get_IsWhite` (method) ; raw alt `ExtractTimer[1]._Value` | bool / Single | bool flag / timer | high | get_IsWhite literal; EXTRACT_TYPE WHITE=1 |
| orangeExtract | `get_IsOrange` (method) ; raw alt `ExtractTimer[2]._Value` | bool / Single | bool flag / timer | high | get_IsOrange literal; EXTRACT_TYPE ORANGE=2 |
| tripleUp (extra) | `get_IsTrippleUp` (method) ; raw alt `TrippleUpTimer._Value` | bool / Single | bool flag / timer | high | Triple-extract buff; forceEndTrippleUp method confirms |
| airborne | `<Hunter>k__BackingField` -> `<Landed>k__BackingField` (inverted: airborne = not Landed) | System.Boolean | bool flag | medium | CharacterBase field inherited by HunterCharacter; no IG-specific airborne flag exists |
| chargeLevel | `<ChargeLv>k__BackingField` (or method `get_ChargeLv`) | System.Int32 | level | medium | Has get/set_ChargeLv and updateCharge; ChargeAttackLv is a separate int (possibly level of the released charge attack) |
| airCharge (extra) | `_IsAirCharge` | System.Boolean | bool flag | medium | Aerial charge in progress |
| vaultCount (extra) | `_EmStepCount` | System.Int32 | counter | medium | Enemy-step (midair vault off monster) count; addEnemyStepCount / _EnemyStepCountMax confirm |
| markHit (extra) | `IsAimAttackHitted` | System.Boolean | bool flag | medium | Focus/aim-attack (marking) hit landed |
| insectCharging (extra) | `<InsectChargingThisFrame>k__BackingField` | System.Boolean | bool flag (per frame) | medium | Kinsect charge active this frame |
| directCharge (extra) | `IsDirectChargeAttack` | System.Boolean | bool flag | low | Name only; likely charge attack without kinsect requirement |
| parry (extra) | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum | high | SUCCESS=3 is parry success; base class |
| hitEnemy (extra) | `_IsHitAttackToEnemy` | System.Boolean | bool flag | medium | Base class hit flag, good for hit-feedback haptic |
| scarBreak (extra) | `_ScarBreakCount` | System.Int32 | counter | medium | Increments on wound destroy (addScarBreakCount) |

> ExtractTimer is an app.cValueHolderF[] array; index-to-colour mapping via app.Wp10Def.EXTRACT_TYPE (RED=0, WHITE=1, ORANGE=2) is inferred, so verify in game. The get_IsRed/IsWhite/IsOrange/IsTrippleUp getters are the safest bool sources. No IG airborne flag exists, so use Hunter <Landed>k__BackingField inverted (or method get_IsDrawOff etc. are unrelated). ChargeAttackLv vs <ChargeLv>k__BackingField: both are Int32; <ChargeLv> has get/set accessors tied to updateCharge, so prefer it, but log both in game to confirm.

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp10Handling**
`<AimHitInfo>k__BackingField` : app.cHunterWp10Handling.cAimHitInfo
`<ChargeLv>k__BackingField` : System.Int32
`<DirectChargeAttackEnableLv>k__BackingField` : System.Int32
`<InsectChargingThisFrame>k__BackingField` : System.Boolean
`ChargeAttackLv` : System.Int32
`ExtractTimer` : app.cValueHolderF[]
`InsectChargeTimer` : System.Single
`IsAimAttackHitted` : System.Boolean
`IsChargePreSucess` : System.Boolean
`IsDirectChargeAttack` : System.Boolean
`IsInsectCatchGesture` : System.Boolean
`IsOnceReleaseCharge` : System.Boolean
`TrippleUpTimer` : app.cValueHolderF
`_ActionParam` : app.user_data.Wp10ActionParam
`_ChargeTimer` : System.Single
`_CheckEnableInsectOrder` : System.Boolean
`_EmStepCount` : System.Int32
`_IsAirCharge` : System.Boolean
`_IsPreAirCharge` : System.Boolean
`_IsReplicaCharing` : System.Boolean
`_IsReplicaInsectCharing` : System.Boolean
`_IsReserve` : System.Boolean
`_Mesh` : via.render.Mesh
`_PreChargeTimer` : System.Single
`_WpGimmickMotType` : app.Wp10Def.WP_GIMMICK_MOT_TYPE

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : System.Nullable<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : System.Boolean
`<IsHitInfoContinue>k__BackingField` : System.Boolean
`<IsParryInfoContinue>k__BackingField` : System.Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : System.Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : System.Single
`<ReserveShellWeaponAttackPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : System.Nullable<System.UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : System.Boolean
`_IsFittingMode` : System.Boolean
`_IsHitAttackToEnemy` : System.Boolean
`_IsHitWeakPoint` : System.Boolean
`_IsUseExtraStealthCollider` : System.Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : System.Int32
`_ScarBreakIndexList` : List<System.Int32>
`_Skill218or217Timer` : System.Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**app.cValueHolderF** (sub-fields): `DefaultValue` : Single, `MaxValue` : Nullable<Single>, `MinValue` : Nullable<Single>, `_Value` : Single

**app.CharacterBase via Hunter (relevant)**: `<Landed>k__BackingField` : System.Boolean, `_LandIgnoreTimer` : Single, `_StandState` : cSafeContinueValue<CharacterDef.STAND_STATE>; HunterCharacter `_IsWeaponOn` : Boolean

</details>

## Wp11 Bow (`bow`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| chargeLevel | `<ChargeLv>k__BackingField` (or method `get_ChargeLv`) | app.Wp11Def.CHARGE_LV | enum level (NONE..LV4, HOMING=5) | high | Exact name, enum with LV1-LV4; requestChargeLvUp / setChargeLv confirm |
| drawing | `_IsBowStringConstToHand` (suggestion; alt derive `<ChargeLv>k__BackingField` != NONE) | System.Boolean | bool flag | low | No explicit IsDrawing field; bowstring-constrained-to-hand plausibly true while the string is pulled, but unverified |
| coating | `<BottleType>k__BackingField` (or method `get_BottleType`) | app.Wp11Def.BOTTLE_TYPE | enum | high | Bottle=phial/coating; enum CLOSE/STRONG/PENETRATE/PARALYSE/POISON/SLEEP/BLAST/STAMINA |
| coatingCount (extra) | `<BottleNum>k__BackingField` | System.Int32 | counter | medium | Remaining coating count; drops on shot (removeBottleAfterShot) |
| bottleShotCount (extra) | `<BottleShotCount>k__BackingField` | System.Int32 | counter | medium | Shots fired with current bottle; increments per shot, good shot trigger |
| arrowGauge (extra) | `<ArrowGauge>k__BackingField._Value` | Single (via app.cValueHolderF) | gauge 0..max | medium | Trace-arrow/Tsugiya gauge (_TsugiyaUseGauge, _MikiriAddGauge, _ArrowGaugeAddSpeed) |
| perfectDodge (extra) | `<IsMikiriDodgeSuccessed>k__BackingField` | System.Boolean | bool flag | high | mikiri=perfect evade, 'Successed' explicit |
| perfectDodgeSuper (extra) | `<IsMikiriSuper>k__BackingField` | System.Boolean | bool flag | medium | Super mikiri variant (_SuperMikiriAddGauge) |
| mikiriFrame (extra) | `_MikiriSuccessFrame` | System.Boolean | bool flag (one frame) | medium | Pulses on the frame of perfect dodge; may be missed if polled late |
| tsugiyaSet (extra) | `IsTsugiyaSetting` | System.Boolean | bool flag | medium | Follow-up (Tracer) arrow being set/nocked |
| chargeStepShot (extra) | `IsChargeStepShotted` | System.Boolean | bool flag | low | Name only: shot after charge-step |
| parryState (extra) | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum | high | SUCCESS=3 = parry success (base class) |
| hitEnemy (extra) | `_IsHitAttackToEnemy` | System.Boolean | bool flag | medium | Base class hit flag |
| scarBreakCount (extra) | `_ScarBreakCount` | System.Int32 | counter | medium | Wound destroy counter |
| drawing | current action index (`app.Wp11Action.ID`): SPECIAL_CHARGE=5, CHARGE_RUN=14, CHARGE_RUN_STOP=15, RUN_TO_CHARGE=16, KYOKUSHA_AIM_START=17, KYOKUSHA_AIM_LOOP=18, JUMP_CHARGE=23, AIM_IDLE=152, AIM_MOVE=153, AIM_MOVE_STOP=154 | ace.ACTION_ID._Index (Int32) | enum/action set | low | Bow aim/charge-hold actions; exact set that counts as "drawing" needs in-game check. Pair with `<ChargeLv>k__BackingField`. Category not verified |

> There is no explicit 'drawing' flag. _IsBowStringConstToHand is the closest literal candidate, but it is unverified. Deriving drawing from ChargeLv > NONE (or _ChargeTimer > 0 as a gate only, not as a trigger) is safer. Also consider the methods get_UseBottleType / get_UseBottleNum, which may reflect the effective coating, including skill 218. Shot detection: trigger on increments of <BottleShotCount>k__BackingField, or on changes of <PrevShotChargeLv>k__BackingField.

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp11Handling**
`<ArrowGauge>k__BackingField` : app.cValueHolderF
`<BottleInfos>k__BackingField` : app.EquipDef.BowBottleInfo[]
`<BottleNum>k__BackingField` : System.Int32
`<BottleShotCount>k__BackingField` : System.Int32
`<BottleType>k__BackingField` : app.Wp11Def.BOTTLE_TYPE
`<ChargeLv>k__BackingField` : app.Wp11Def.CHARGE_LV
`<IsMikiriASkill004>k__BackingField` : System.Boolean
`<IsMikiriDodgeSuccessed>k__BackingField` : System.Boolean
`<IsMikiriSuper>k__BackingField` : System.Boolean
`<MaxChargeLv>k__BackingField` : app.Wp11Def.CHARGE_LV
`<PrevShotChargeLv>k__BackingField` : app.Wp11Def.CHARGE_LV
`<Skill218BottleNum>k__BackingField` : System.Int32
`<Skill218BottleType>k__BackingField` : app.Wp11Def.BOTTLE_TYPE
`IsChargeStepShotted` : System.Boolean
`IsJustGoshaPreInput` : System.Boolean
`IsPrevShotTsugiya` : System.Boolean
`IsTsugiyaSetting` : System.Boolean
`JumpSlashBottleType` : app.Wp11Def.BOTTLE_TYPE
`SelectedBottleItem` : app.ItemDef.ID
`TsugiyaSettingEffect` : via.effect.script.CreatedEffectContainer
`_ASkill005GaugeSpeedRate` : System.Single
`_ActionParam` : app.user_data.Wp11ActionParam
`_AimDistance` : System.Single
`_AimRangeType` : app.GunnerTargetRange.TYPE
`_ArrowAccessory` : app.accessory.cAccessoryAccessor
`_BowConstraintUpdater` : app.ConstraintUpdater
`_ChargeTimer` : System.Single
`_DispTsugiyaTutorial` : System.Boolean
`_InitialBottleInfos` : app.EquipDef.BowBottleInfo[]
`_IsBowStringConstToHand` : System.Boolean
`_IsFirstUpdate` : System.Boolean
`_IsScarBreakDelayStart` : System.Boolean
`_IsTsugiyaHoming` : System.Boolean
`_LockOnTsugiyaAttachInfo` : app.mcShellPlWp11ArrowTsugiyaAttach.cAttachInfo
`_MikiriSuccessFrame` : System.Boolean
`_MultiLockonConstLock` : ace.cLockObject
`_MultiLockonHitScarList` : List<cMultiLockonHitScarInfo>
`_MultiLockonInScreenTargetList` : List<cMultiLockonTargetInfo>
`_MultiLockonList` : List<cMultiLockonTargetInfo>
`_MultiLockonTargetAddTimer` : System.Single
`_MultiLockonTargetList` : List<cMultiLockonTargetInfo>
`_OnceChargeTimer` : System.Single
`_RideAimInfo` : app.cHunterWp11Handling.RIDE_AIM_INFO
`_ScarBreakDelayTimer` : System.Single
`_ShellList` : ace.user_data.ShellList
`_TsugiyaTutorialCDTimer` : System.Single
`_TsugiyaTutorialContinueTimer` : System.Single
`_WaitRemoveBottle` : System.Boolean
`_WaitRemoveSkill218Bottle` : System.Boolean
`_WpGimmickMotType` : app.Wp11Def.WP_GIMMICK_MOT_TYPE

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : System.Nullable<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : System.Boolean
`<IsHitInfoContinue>k__BackingField` : System.Boolean
`<IsParryInfoContinue>k__BackingField` : System.Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : System.Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : System.Single
`<ReserveShellWeaponAttackPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : System.Nullable<System.UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List<cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : System.Boolean
`_IsFittingMode` : System.Boolean
`_IsHitAttackToEnemy` : System.Boolean
`_IsHitWeakPoint` : System.Boolean
`_IsUseExtraStealthCollider` : System.Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List<cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : System.Int32
`_ScarBreakIndexList` : List<System.Int32>
`_Skill218or217Timer` : System.Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**app.cValueHolderF** (sub-fields): `DefaultValue` : Single, `MaxValue` : Nullable<Single>, `MinValue` : Nullable<Single>, `_Value` : Single

</details>

## Wp12 Heavy Bowgun (`hbg`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| ammoInMag | `_Ammos[_ShellType]._LoadedAmmo` (or method `getCurrentAmmo`) | app.cWeaponGunAmmo[] -> via.rds.Mandrake | counter (loaded rounds) | medium | `_LoadedAmmo` vs `_LimitAmmo`/`_BackupAmmo` clearly means loaded mag; but it is an encrypted Mandrake (decode sub-fields not in digest) and array index = `_ShellType` is inferred. `getCurrentAmmo` (cHunterWpGunHandling method) is the safer read |
| ammoType | `_ShellType` (method `get_ShellType`) | System.Int32 | enum/index of selected shell | medium | Base gun-handling field for the current shell; Int32 not typed as SHELL_TYPE, so likely an index into `_Ammos`/`<EquipShellInfo>k__BackingField`. Alt: `_SelectedShellItem` (app.ItemDef.ID) changes with ammo selection too |
| specialMode | `_IsEnergyMode` (method `get_IsEnergyMode`) | System.Boolean | bool flag | high | Wilds HBG Ignition = energy mode; set by `beginEnergyMode`/`endEnergyMode` methods |
| specialGauge | `_EnergyBulletInfo._CurrentEnergy` | System.Single | gauge 0..max (max not in digest) | medium-high | Current energy of the Ignition gauge; `addEnergy`/`subUsingEnergy` methods modify it |
| energyPartsState | `_EnergyPartsState` | app.Wp12Def.ENERGY_PARTS_STATE | enum OFF/IDLE/USING/USE_END/USE_END_EMPTY/NOT_USE_END | medium | Ignition parts state: USING -> firing Ignition, USE_END_EMPTY -> ran out (good for 'empty' thump) |
| energyChargeLevel | `_EnergyBulletInfo._CharageLevel` (sic, Capcom typo) | app.Wp12Def.ENERGY_BULLET_CHARGE_LV | level LV0..LV3 | medium | Charge level of the energy shot (`setChargeLevel` method); step changes are good haptic ticks |
| parryState | `<ParryState>k__BackingField` (method `get_ParryState`) | app.HunterDef.PARRY_STATE | enum NONE/WAIT/HIT/SUCCESS/RECOIL | high | Base parry state; HBG has energy parry (SHELL_TYPE ENERGY_PARRY) + `onParrySuccess` override |
| parryHitChargeLevel | `_ParryHitChargeLevel` | System.Int32 | level | low | Set on parry hit; meaning of the value unknown |
| gatlingHitCount | `_GatlingHitCount` | System.Int32 | counter | medium | Wyvernheart/energy gatling hit counter; reset by `resetGatlingHitCount`. Increments per hit -> rumble per hit |
| snipeAmmo | `_SnipeAmmo._CurrentAmmo` | System.Int32 | counter (vs `_MaxAmmo`) | medium | Ammo for the weak-point snipe (`subSnipeAmmo`) |
| shotgunNearHits | `_ShotGunNearHitCount` | System.Int32 | counter | low | Near-range spread hit count; reset semantics unknown |
| hitWeakPoint | `_IsHitWeakPoint` | System.Boolean | bool flag | medium | Base flag; may be per-hit and short-lived |

> Mandrake (`_LoadedAmmo`) is an encrypted int and its sub-fields are not in the digest, so in Lua call the `getCurrentAmmo` method (or `checkCurrentAmmoToShoot`) instead of reading the field raw. Methods have their dump id suffix removed. The max for `_CurrentEnergy` is not in the digest, so diff on changes instead of normalising. `_CharageLevel` is spelled that way in the dump.

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp12Handling**
`_EnergyBulletCustomLv` : app.Wp12Def.BULLET_CUSTOM_LV
`_EnergyBulletInfo` : app.Wp12Def.cEnergyBulletInfo
`_EnergyEfficiencyCustomType` : app.EnergyEfficiencyType.TYPE
`_EnergyEfficiencyRate` : System.Single
`_EnergyPartsAccessory` : app.accessory.cAccessoryAccessor
`_EnergyPartsState` : app.Wp12Def.ENERGY_PARTS_STATE
`_GatlingHitCount` : System.Int32
`_GatlingLockObj` : ace.cLockObject
`_IsDispPowerBarrel` : System.Boolean
`_IsEnergyMode` : System.Boolean
`_NormalBulletCustomLv` : app.Wp12Def.BULLET_CUSTOM_LV
`_OnParryEvent` : ace.cSafeEvent`3<app.HunterDef.PARRY_STATE,System.Int32,via.vec3>
`_ParryHitChargeLevel` : System.Int32
`_ParryHitEmID` : System.Int32
`_ParryHitPos` : via.vec3
`_PrevEnergyPartsState` : app.Wp12Def.ENERGY_PARTS_STATE
`_PrevShootSquatShellType` : app.WeaponGunDef.SHELL_TYPE
`_RequestLackOfEnergyAction` : System.Boolean
`_SnipeAmmo` : app.Wp12Def.cSnipeAmmo

**app.cHunterWpGunHandling**
`<EquipShellInfo>k__BackingField` : app.EquipDef.BowgunShellInfo[]
`<ShellList>k__BackingField` : ace.user_data.ShellList
`<Skill218AdditionalShellMaxNum>k__BackingField` : System.Int16
`<Skill218AdditionalShellNum>k__BackingField` : System.Int16
`<WpGunParam>k__BackingField` : app.user_data.WpGunActionParamBase
`_ActionShellType` : System.Int32
`_ActionShellTypeLayer` : app.AppActionDef.LAYER
`_AimDistance` : System.Single
`_AimRangeType` : app.GunnerTargetRange.TYPE
`_AimUIType` : app.GunnerAim.TYPE
`_Ammos` : app.cWeaponGunAmmo[]
`_CustomizeID` : app.CustomizeItemID.ID[]
`_DodgeReloadPoint` : System.Single
`_IsContinueReload` : System.Boolean
`_IsRequestedNoAmmoReload` : System.Boolean
`_IsShootedSkill218` : System.Boolean
`_MortarInfo` : app.WeaponGunDef.cMortarInfo
`_ReloadShellType` : System.Int32
`_ReloadShellTypeLayer` : app.AppActionDef.LAYER
`_RideAimInfo` : app.cHunterWpGunHandling.RIDE_AIM_INFO
`_SelectedShellItem` : app.ItemDef.ID
`_ShellType` : System.Int32
`_ShootAmmoReloadType` : app.cWeaponGunAmmo.AMMO_RELOADED_TYPE
`_ShotGunNearHitCount` : System.Int32
`_UseUIShellType` : System.Boolean

**app.cHunterWeaponHandlingBase**
`<AimAttackHitTargetCol>k__BackingField` : via.physics.Collidable
`<AimAttackSightPos>k__BackingField` : System.Nullable`1<via.vec3>
`<AimAttackTargetCol>k__BackingField` : via.physics.Collidable
`<Hunter>k__BackingField` : app.HunterCharacter
`<IsDrawOffRequested>k__BackingField` : System.Boolean
`<IsHitInfoContinue>k__BackingField` : System.Boolean
`<IsParryInfoContinue>k__BackingField` : System.Boolean
`<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE
`<ParryTarget>k__BackingField` : via.GameObject
`<RequestRecoil>k__BackingField` : System.Boolean
`<ReserveShellOriginalCriticalRate>k__BackingField` : System.Single
`<ReserveShellWeaponAttackPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrPower>k__BackingField` : System.Single
`<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR
`WeakPointRWLock` : via.threading.SimpleReaderWriterLock
`_AimAtkHitTargetOfs` : via.mat4
`_AimRangeSensorRequestSetID` : System.Nullable`1<System.UInt32>
`_AimTargetOfs` : via.mat4
`_ExFieldWeakHitInfoList` : List`1<app.cHunterWeaponHandlingBase.cExFieldWeakHitInfo>
`_IsAimSearchSuccess` : System.Boolean
`_IsFittingMode` : System.Boolean
`_IsHitAttackToEnemy` : System.Boolean
`_IsHitWeakPoint` : System.Boolean
`_IsUseExtraStealthCollider` : System.Boolean
`_Kireaji` : app.cWeaponKireaji
`_MikiriInfo` : List`1<app.cHunterWeaponHandlingBase.cMikiriInfo>
`_MikiriLockObject` : ace.cLockObject
`_ScarBreakCount` : System.Int32
`_ScarBreakIndexList` : List`1<System.Int32>
`_Skill218or217Timer` : System.Single
`_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**Composite sub-fields**
app.Wp12Def.cEnergyBulletInfo: `_CharageLevel` : ENERGY_BULLET_CHARGE_LV, `_CurrentEnergy` : Single, `_LatestUsingEnergy` : Single, `_PowerEnergyShellType`, `_StandardEnergyShellType`, `_UsingEnergy` : Single, `_WeakEnergyShellType`
app.Wp12Def.cSnipeAmmo: `_ChargeTime` : Single, `_ChargeTimer` : Single, `_CurrentAmmo` : Int32, `_MaxAmmo` : Int32
app.cWeaponGunAmmo: `_AmmoType` : AMMO_TYPE, `_BackupAmmo` / `_LimitAmmo` / `_LoadedAmmo` : via.rds.Mandrake (from app.cAmmo)
app.EquipDef.BowgunShellInfo: `<CanRapid>k__BackingField`, `<ItemId>k__BackingField`, `<Num>k__BackingField` : Int32, `<OverloadNum>k__BackingField` : Int32, `_ShellLv`

</details>

## Wp13 Light Bowgun (`lbg`)

| State | Field | Type | Behaviour | Confidence | Reason |
|---|---|---|---|---|---|
| ammoInMag | `_Ammos[_ShellType]._LoadedAmmo` (or method `getCurrentAmmo`; Wp13 also overrides `getAmmo`) | cWeaponGunAmmo[] -> via.rds.Mandrake | counter | medium | Same base mechanism as HBG; Mandrake is encrypted, so the method is safer. During Rapid Fire the loaded count may come from `_VariableAmmo` instead (unverified) |
| ammoType | `_ShellType` (method `get_ShellType`) | System.Int32 | enum/index of selected shell | medium | Base selected-shell field; `_SelectedShellItem` is an alternative ItemDef.ID |
| specialMode | `_IsRapidShotBoost` (method `get_IsRapidShotBoost`) | System.Boolean | bool flag | high | Rapid Fire = 'RapidShotBoost'; toggled by `beginRapidShotBoost`/`endRapidShotBoost` |
| specialGauge | method `get_RapidBoostGaugeRate`; field fallback `_RapidShotBoostInfo._ModeTime` | Single | gauge (rate, likely 0..1) | medium | The getter name fits the Rapid Fire gauge. `_ModeTime` vs `_MaxModeTime` is the field backing it, but it behaves like a timer while the mode is active (low confidence as a field) |
| canRapidShotBoost | method `get_IsCanRapidShotBoost` | bool | bool flag | medium | True when the gauge allows entering Rapid Fire; good 'ready' pulse |
| rapidShootCount | `<RpidShootCount>k__BackingField` (sic, 'Rpid') | System.Int32 | counter | medium | Shots fired in the rapid burst; `set_RpidShootCount` exists |
| specialAmmoType | `_SpecialAmmoType` | app.Wp13Def.SPECIAL_AMMO_TYPE | enum SET_BOMB/CHATCH | high | Equipped special ammo kind (static per loadout) |
| setBombAmmo | `_SetBombInfo._Ammo` | System.Byte | counter (vs `_MaxAmmo`) | medium-high | Set-bomb special ammo charges; recharges over time |
| catchAmmo | `_CatchAmmoInfo._Ammo` (methods `get_CatchAmmoCurrent`, `get_IsCatchAmmoFull`) | System.Byte | counter | medium-high | Catch special ammo charges |
| specialAmmoGauge | method `get_SpecialAmmoGaugeRate` | Single | gauge rate | medium | Recharge gauge of the special ammo |
| weakAmmo | `_WeakAmmoInfo._Ammo` | System.Byte | counter | medium | Weak-point ammo count (`get_IsWeakAmmo`) |
| weakAmmoLevel | `_WeakAmmoInfo._CurrentLevel` | app.Wp13Def.WEAK_AMMO_CHARGE_TYPE | level LV_0..LV_3 | medium | Charge level of the weak-point ammo; step change = haptic tick |
| energyPartsState | `_EnergyPartsState` | app.Wp13Def.ENERGY_PARTS_STATE | enum | low | Parts state; mapping to gameplay not clear for LBG |
| parryState | `<ParryState>k__BackingField` | app.HunterDef.PARRY_STATE | enum | medium | Base parry state; LBG has no well-known parry, so it may stay NONE |
| hitWeakPoint | `_IsHitWeakPoint` | System.Boolean | bool flag | medium | Base flag |

> Wp13 has its own `updatePadVibration` method. Hooking it with sdk.hook could be a cleaner trigger than polling, because the game already fires pad rumble at that point. In Rapid Fire the ammo may be tracked in `_VariableAmmo` (app.cWeaponGunAmmo) with `_VariableShellType`, which is unverified, so log both. `<RpidShootCount>k__BackingField` and `CHATCH` are misspelled that way in the dump. Method names have their id suffix removed.

<details><summary>All instance fields (including inherited)</summary>

**app.cHunterWp13Handling**
`<RpidShootCount>k__BackingField` : System.Int32
`IsInterceptRemove` : System.Boolean
`_AddRapidAmmo` : System.Int32
`_CatchAmmoInfo` : app.Wp13Def.cCatchAmmoInfo
`_EmRideFinishInfo` : app.Wp13Def.cEmRideFinishInfo
`_EnergyPartsAccessory` : app.accessory.cAccessoryAccessor
`_EnergyPartsState` : app.Wp13Def.ENERGY_PARTS_STATE
`_IsDispLongBarrel` : System.Boolean
`_IsDispSuppressor` : System.Boolean
`_IsPreRapidShotBoost` : System.Boolean
`_IsRapidShotBoost` : System.Boolean
`_RapidBoostHealRate` : System.Single
`_RapidShotBoostInfo` : app.Wp13Def.cRapidShotBoostInfo
`_SetBombInfo` : app.Wp13Def.cSetBombInfo
`_ShotGunAddEnergyList` : List`1<System.Int32>
`_SpecialAmmoHealRate` : System.Single
`_SpecialAmmoType` : app.Wp13Def.SPECIAL_AMMO_TYPE
`_VariableAmmo` : app.cWeaponGunAmmo
`_VariableNoAimRecoilDeg` : System.Single
`_VariableShellType` : System.Int32
`_WeakAmmoInfo` : app.Wp13Def.cWeakAmmoInfo
`_WpGimmickMotType` : app.Wp13Def.WP_GIMMICK_MOT_TYPE

**app.cHunterWpGunHandling** (same as HBG)
`<EquipShellInfo>k__BackingField` : app.EquipDef.BowgunShellInfo[]
`<ShellList>k__BackingField` : ace.user_data.ShellList
`<Skill218AdditionalShellMaxNum>k__BackingField` : System.Int16
`<Skill218AdditionalShellNum>k__BackingField` : System.Int16
`<WpGunParam>k__BackingField` : app.user_data.WpGunActionParamBase
`_ActionShellType` : System.Int32
`_ActionShellTypeLayer` : app.AppActionDef.LAYER
`_AimDistance` : System.Single
`_AimRangeType` : app.GunnerTargetRange.TYPE
`_AimUIType` : app.GunnerAim.TYPE
`_Ammos` : app.cWeaponGunAmmo[]
`_CustomizeID` : app.CustomizeItemID.ID[]
`_DodgeReloadPoint` : System.Single
`_IsContinueReload` : System.Boolean
`_IsRequestedNoAmmoReload` : System.Boolean
`_IsShootedSkill218` : System.Boolean
`_MortarInfo` : app.WeaponGunDef.cMortarInfo
`_ReloadShellType` : System.Int32
`_ReloadShellTypeLayer` : app.AppActionDef.LAYER
`_RideAimInfo` : app.cHunterWpGunHandling.RIDE_AIM_INFO
`_SelectedShellItem` : app.ItemDef.ID
`_ShellType` : System.Int32
`_ShootAmmoReloadType` : app.cWeaponGunAmmo.AMMO_RELOADED_TYPE
`_ShotGunNearHitCount` : System.Int32
`_UseUIShellType` : System.Boolean

**app.cHunterWeaponHandlingBase** (same as HBG)
`<AimAttackHitTargetCol>k__BackingField`, `<AimAttackSightPos>k__BackingField`, `<AimAttackTargetCol>k__BackingField`, `<Hunter>k__BackingField` : app.HunterCharacter, `<IsDrawOffRequested>k__BackingField` : Boolean, `<IsHitInfoContinue>k__BackingField` : Boolean, `<IsParryInfoContinue>k__BackingField` : Boolean, `<ParryState>k__BackingField` : app.HunterDef.PARRY_STATE, `<ParryTarget>k__BackingField` : via.GameObject, `<RequestRecoil>k__BackingField` : Boolean, `<ReserveShellOriginalCriticalRate>k__BackingField` : Single, `<ReserveShellWeaponAttackPower>k__BackingField` : Single, `<ReserveShellWeaponAttrPower>k__BackingField` : Single, `<ReserveShellWeaponAttrType>k__BackingField` : app.WeaponDef.ATTR, `WeakPointRWLock`, `_AimAtkHitTargetOfs` : via.mat4, `_AimRangeSensorRequestSetID`, `_AimTargetOfs` : via.mat4, `_ExFieldWeakHitInfoList`, `_IsAimSearchSuccess` : Boolean, `_IsFittingMode` : Boolean, `_IsHitAttackToEnemy` : Boolean, `_IsHitWeakPoint` : Boolean, `_IsUseExtraStealthCollider` : Boolean, `_Kireaji` : app.cWeaponKireaji, `_MikiriInfo`, `_MikiriLockObject`, `_ScarBreakCount` : Int32, `_ScarBreakIndexList`, `_Skill218or217Timer` : Single, `_WpExGimmickMotPhase` : app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE

**Composite sub-fields**
app.Wp13Def.cRapidShotBoostInfo: `_AddRate` : Single, `_MaxModeTime` : Single, `_ModeTime` : Single
app.Wp13Def.cTimeChargeAmmoBase (base of cCatchAmmoInfo/cSetBombInfo): `_Ammo` : Byte, `_MaxAmmo` : Byte, `_MaxReloadTime` : Single, `_MaxReloadTimeRate` : Single, `_ReloadTimer` : Single; cCatchAmmoInfo adds `_Reloading` : Boolean
app.Wp13Def.cWeakAmmoInfo: `<IsReloding>k__BackingField` : Boolean, `_Ammo` : Byte, `_ChargeTimeRate` : Single, `_CurrentChargeTime` : Single, `_CurrentLevel` : WEAK_AMMO_CHARGE_TYPE, `_CurrentReloadTime` : Single, `_IsCharge` : Boolean, `_IsRequestRemove` : Boolean, `_MaxAmmo` : Byte, `_PreCurrentLevel` : WEAK_AMMO_CHARGE_TYPE
app.Wp13Def.cEmRideFinishInfo: `EmTargetAccessKey`, `RidingPartsIndex` : Int32, `_DelayTime` : Single, `_IsCreated` : Boolean
app.cWeaponGunAmmo: `_AmmoType`, `_BackupAmmo` / `_LimitAmmo` / `_LoadedAmmo` : via.rds.Mandrake

</details>

# Traps

| Weapon | Field | Type | Why trap |
|---|---|---|---|
| gs | `_ChargeTimer` | Single | Timer rising every frame while charging; changes every frame, not a level |
| gs | `_PrevChargeLevel` | CHARGE_LEVEL | Previous-frame copy; lags real value |
| gs | `_PrevChargeType` | CHARGE_TYPE | Previous-frame copy |
| gs | `_EffectChargeLevel` | CHARGE_LEVEL | Level used for VFX; may differ/lag from gameplay level |
| gs | `_ChargeRequestType` | CHARGE_REQUEST_TYPE | Request mode (BASIC/NO_UPDATE/NONE), not charge state |
| gs | `_DisableChargeParts` | Boolean | Disable flag for charge parts/visuals |
| gs | `<OverwriteChargeOverHeatTime>k__BackingField` | Nullable<Single> | Overwrite time constant for overheat, not a state |
| gs | `<LastHitTimer>k__BackingField` | Single | Timer since last hit |
| gs | `<ChargeTurnDeg>k__BackingField` | Nullable<Single> | Turn angle during charge, not charge state |
| gs | `_WpGimmickMotChargeLv` | WP_GIMMICK_MOT_CHARGE_LV | Weapon-gimmick motion variant (NONE/LV3/LV2), visual only, reversed ordering |
| gs | `_WpGimmickMotType` / `_WpGimmickRestart` | enum/Boolean | Weapon model gimmick animation control |
| gs | `_IsBreakWeakPointInFrame` | Boolean | Single-frame pulse; use `_ScarBreakCount` instead |
| gs | `<RequestRecoil>k__BackingField` | Boolean | Request flag, consumed quickly |
| gs | `<IsDrawOffRequested>k__BackingField` | Boolean | Request flag for sheathing |
| gs | `_Skill218or217Timer` | Single | Skill timer |
| gs | `_OverwriteGuardDir` | via.vec3 | Direction vector override, not a guard flag |
| gs | `_Kireaji._CurrentValue` etc. | via.rds.Mandrake | Encrypted/obfuscated value type; cannot be read as plain number |
| sns | `_EmStepSlashPos` | Nullable<via.vec3> | Target position for step slash, not a state |
| sns | `_EmStepSlashHeightOffset` | Single | Positional offset constant, not a state |
| sns | `_IsBreakWeakPointInFrame` | Boolean | Single-frame pulse; prefer `_ScarBreakCount` |
| sns | `_WpGimmickMotType` | WP_GIMMICK_MOT_TYPE | Weapon-model gimmick animation variant, visual only |
| sns | `<RequestRecoil>k__BackingField` | Boolean | Request flag, consumed quickly |
| sns | `<IsDrawOffRequested>k__BackingField` | Boolean | Sheathe request flag |
| sns | `<IsParryInfoContinue>k__BackingField` | Boolean | Info-continue bookkeeping, not the parry result; use ParryState |
| sns | `_Skill218or217Timer` | Single | Skill timer |
| sns | `_Kireaji._CurrentValue` etc. | via.rds.Mandrake | Encrypted value type, not plain number |
| sns | `_IsLastJustRushFinshSuccess` | Boolean | Caution: 'Last' = latched result of the last rush, may stay true; only edge-trigger on false->true |
| db | `_IsKijinOnEffect` | Boolean | visual effect state flag, not the mode itself; may lag/differ from _IsKijinOn |
| db | `_IsKijinEnhancementEffect` | Boolean | effect flag for Archdemon VFX, not the state |
| db | `_KijinOnEffect` / `_KijinEnhancementEffectEffect` / `_MikiriBuffEffect` | CreatedEffectContainer | effect handles, not numeric states |
| db | `_KijinEffectType` | KIJIN_EFFECT_TYPE | effect variant (NORMAL/FROM_CHAIN), not a mode flag |
| db | `_MikiriBuffTimer` | Single | countdown timer for the buff; changes every frame |
| db | `_KijinExtern` / `_BuffExtern` | Single | unknown external modifiers (probably rates); not the gauge |
| db | `IsAirKijinOnOff` | Boolean | permission/enable flag for toggling demon mode in air (updateEnableAirKijinOnOff), not the mode |
| db | `<IsKijinOnFromAimAttack>k__BackingField` | Boolean | origin flag for how demon mode was entered, not demon mode |
| db | `_KijinComboLvContinue` | Boolean | continue/request flag for combo level carry-over |
| db | `<ConstEmUniqueIndex>k__BackingField` | Nullable<Int32> | enemy index for const-spin target, not a counter |
| db | `<IsMikiriASkill004>k__BackingField` | Boolean | skill-specific mikiri variant flag; not the general success |
| db | `_Skill218or217Timer` | Single | skill timer |
| db | `<IsDrawOffRequested>k__BackingField` / `<RequestRecoil>k__BackingField` | Boolean | request flags, consumed quickly |
| db | `_WpGimmickMotType` | WP_GIMMICK_MOT_TYPE | motion variant for weapon gimmick animation |
| db | `<KijinGauge>k__BackingField.MaxValue` / `DefaultValue` | Single | constants of the holder, not the current value |
| db | `_ActionParam._KijinEnhancemenetReduceTime` etc. | Single | user_data constants (per-action gauge reduce amounts/times) |
| ls | `<AuraGauge>k__BackingField` | app.cValueHolderF | NOT the spirit gauge: it is the aura (spirit level) duration that decays (reduceAuraGauge/updateAuraGauge); drains every frame |
| ls | `_AuraStopTimer` / `_IsAuraStop` | Single / Boolean | aura-decay pause timer/flag, not level |
| ls | `_IaiRenkiAutoRecoverTimerIai` | Single | auto-recovery timer, ticks every frame |
| ls | `_KijinChargeTimer` | Single | charge timer, continuous |
| ls | `_NoHitTimer` | Single | timer |
| ls | `_KabutowariConsumeAuraTimer` / `_KabutowariCreateShellTimer` / `_RenkiReleaseConsumeAuraTimer` / `_RenkiReleaseDelayEndCreatShellTimer` / `_IaiDelayHitCreateShellTimer` / `_EmRideFinishDelayHitTimer` / `_WeakPointBreakDelayTimer` | Single | per-attack delay/shell timers |
| ls | `<KabutowariAuraLevel>k__BackingField` / `_IaiDelayHitAuraLevel` | AURA_LEVEL | snapshot of level at attack start, not current level |
| ls | `<RealKijinChargeLv>k__BackingField` vs `_KijinChargeLv` | KIJIN_CHARGE_LV | two charge levels; one may be speed-adjusted internal value |
| ls | `<KijinChargeSpeedType>k__BackingField` | KIJIN_CHARGE_SPEED_TYPE | charge speed modifier, not level |
| ls | `<KijinComboLv>k__BackingField` / `_KijinComboLvContinue` / `_KijinChargeContinue` / `<RenkiConsumedContinue>k__BackingField` / `<WeaponPointDelayInfoContinue>k__BackingField` | various | continue/request flags for action transitions |
| ls | `_IsIaiDelayHitStart` / `_IsRenkiReleaseDelayShellSetup` / `_IsRenkiReleaseDelayShellStart` / `_IsKabutowariDelayHitSetup` | Boolean | delayed-shell setup flags; fire after the actual event |
| ls | `_KabutowariShellNum` / `_RenkiReleaseDelayShellNum` | Int32 | shell counts for setup, not hits |
| ls | `WeakSlashDir` | DIR4_FBLR | direction enum for focus strike |
| ls | `_Skill218or217Timer` | Single | skill timer |
| ls | `<RenkiGauge>k__BackingField.MaxValue` / `DefaultValue` | Single | holder constants |
| hammer | `<ChargeLvEffect>k__BackingField` | CHARGE_LV | Same enum as ChargeLv but drives the VFX; may lag/differ from the real level |
| hammer | `_ChargeTimer` | Single | Continuous timer, changes every frame while charging |
| hammer | `_SuperChargeTimer` | Single | Timer for power charge, changes every frame |
| hammer | `_StartChargeFrameTimer` | Single | Per-frame startup timer |
| hammer | `_IsRequestStartCharge` | Boolean | Request flag (1-frame/pending), not the charging state |
| hammer | `_ParryAttackRequest` | Boolean | Request flag; real result is `_IsParryAttack` / ParryState |
| hammer | `_IsStopSuperCharge` | Boolean | Stop request for power charge, not the mode itself |
| hammer | `IsSkipStartCharge` | Boolean | Skip-startup option flag, not charging |
| hammer | `<PrevVSwingMoveAttack>k__BackingField` | ace.ACTION_ID | Previous action ID (Prev), history |
| hammer | `_WpGimmickMotType` | WP_GIMMICK_MOT_TYPE | Weapon model gimmick animation type, cosmetic |
| hammer | `<ChargePlace>k__BackingField` | CHARGE_PLACE | Where charge happens (ground/slope/air), not level |
| hammer | `_ActionParam` fields (_ChargeTimeLv2, _SuperChargeTimeLv3, _MaxSpinCount...) | user_data | Constant tuning parameters, never change at runtime |
| hammer | `_Skill218or217Timer` | Single | Skill timer |
| hammer | `<RequestRecoil>k__BackingField` | Boolean | Request flag |
| hh | `_HibikiFloatShellInfo._ReloadTimer` | Single | Bubble recharge timer, changes every frame |
| hh | `_HibikiFloatShellInfo._MaxAmmo` / `_MaxReloadTime` / `_MaxReloadTimeRate` | Byte/Single | Max/constant values |
| hh | `_MStartTimer` | Single | Timer |
| hh | `_AimShortAttackEnableTimer` | Single | Timer |
| hh | `_MusicAttackToDodgeInvalidResetTime` | Single | Timer |
| hh | `_MusicGame._BPM_Beat_Timer` / `_BPS` / `_Beat_Speed` / `NearNotesRate` | Single | Beat timers and per-frame rates |
| hh | `_MusicGame._OldBPM` / `_OldBeatNotes` | Single/Int32 | Old/previous values |
| hh | `_MusicGame._CreateNotesCount` / `_DestroyNotesCount` | Int32 | Count rhythm notes spawned/destroyed, not hits; noisy |
| hh | `_IsRequestMusicEffect`, `_IsRequestNotesEffect`, `_IsRequestNotesSuccessEffect`, `_IsRequestNotesJustSuccessEffect`, `_IsRequestJustTimingEffect`, `_IsRequestKillNotesEffect`, `_IsRequestKillAllNotesEffect` | Boolean | Effect request flags (1-frame, VFX-driven) |
| hh | `_NotesEffect`, `_NotesEffectEm`, `_NotesEffectPl`, `_NotesEffectList` | CreatedEffectContainer | Effect objects, not note count |
| hh | `_MStartTimeRequest`, `_PenetrateSoundShellRequested` | Boolean | Request flags |
| hh | `_MusicStockBuffSortCopy`, `_MusicStockBuff_MusicDataIdBuff`, `_PlayedStockBuff` | ring buffers | Sorted copy / ID mirror / history of played songs, not the live stock |
| hh | `_LastPlayedMusic` | Int32[] | History of last played music |
| hh | `_ToneCol_1/2/3` | WP05_TONE_COLOR_TYPE | Weapon note colours, constant per weapon |
| hh | `_MusicDatas` | cMusic[] | Song table data, constant |
| hh | `_DestroyCount` | Int32 | Unknown destroy counter, probably effect/shell cleanup |
| hh | `_ToneFreeInput_Attack00/01` | cToneFreeInput | Input-lag buffers (LagTimer), not note state |
| hh | `_WpGimmickMotType` | WP_GIMMICK_MOT_TYPE | Cosmetic weapon gimmick animation |
| lance | `_RushLevelTimer` | System.Single | Timer driving rush level changes (updateRushLevelTimer). Ticks every frame, so it is not the level. |
| lance | `_ToFastRushTimer` | System.Single | Countdown before the fast rush phase. Changes per frame. |
| lance | `_FinishChargeTimer` | System.Single | Charge-up timer behind `_FinishChargeLevel`. Changes per frame. |
| lance | `_PreFinishChargeLevel` | System.Int32 | 'Pre': previous-frame copy of the level, so it lags by one. |
| lance | `_FinishChargeLevelForAction` | System.Int32 | A snapshot copy used by action logic, not the live charge level. |
| lance | `_IsRequestFinishLevel` | System.Boolean | Request flag, only set for a frame or so. |
| lance | `_IsRequestPowerGuardMaxReactCountReset` | System.Boolean | Request for a counter reset, not a power-guard state. |
| lance | `_PowerGuardMaxReactCountEffect` | System.Int32 | Effect bookkeeping copy of the react count, used for VFX. |
| lance | `_GuardToDir4GuardDashTimer` | System.Single | Timer/window for the guard dash input, not a guard state. |
| lance | `_MaxGuardToFinishStingerChargeLvTime` | System.Single | Max/const-like time threshold. |
| lance | `<PreGuardAxisZ>k__BackingField` / `<PreGuardTurnAxisZ>k__BackingField` | via.vec3 | Direction vectors saved before a guard. They are not a guard flag and can change while the hunter turns. |
| lance | `_IsRushToGuard` | System.Boolean | Transition flag (rush into guard), brief and set via requestRushToGuard. Not 'guarding'. |
| lance | `_RideAttackTimer` | System.Single | Mount-attack timer. |
| lance | `_Skill218or217Timer` | System.Single | Skill timer from the base class. |
| lance | `<RequestRecoil>k__BackingField` / `<IsDrawOffRequested>k__BackingField` | System.Boolean | Request flags, transient. |
| lance | `_WpGimmickMotType` | app.Wp06Def.WP_GIMMICK_MOT_TYPE | Weapon model gimmick animation type, cosmetic. |
| gl | `_Ammo` -> `_LoadedAmmo` (raw) | via.rds.Mandrake | Obfuscated/encrypted value. Reading the raw struct gives scrambled numbers, so use get_LoadedAmmo instead. |
| gl | `_Ammo` -> `_LimitAmmo` | via.rds.Mandrake | Max capacity (constant per weapon), not the loaded count. |
| gl | `_Ammo` -> `_BackupAmmo` | via.rds.Mandrake | Backup copy, not the live loaded count. |
| gl | `_RyuugekiGauge` -> `MaxValue` / `MinValue` / `DefaultValue` | Nullable<Single> / Single | Gauge bounds/defaults, constant. Only `_Value` moves. |
| gl | `_GuardShortRyuugekiTimer` | System.Single | Timer window for the guard short Wyvern's Fire follow-up. Ticks per frame and is not the gauge. |
| gl | `_GuardQuickReloadTimer` | System.Single | Timer window for the guard quick reload. Despite 'Guard' in the name, it is not a guard flag. |
| gl | `_GuardQuickReloadDir` | app.Wp07Def.COMBO_DIR | Input-direction bookkeeping for quick reload, not a guard state. |
| gl | `_ShellLevel` | System.Int32 | Weapon's shelling level stat, constant during a hunt. It is not a shell count. |
| gl | `_ShellType` | app.Wp07Def.SHELL_TYPE | Shelling type (NORMAL/WIDE/LONG), a weapon property that never changes. |
| gl | `_ChargeShotBulletNum` / `_FullBurstBulletNum` | System.Int32 | Number of shells set up for the action (setup values), not a live counter. |
| gl | `_ChargeShotElapsedTimer` / `_FullBurstElapsedTimer` / `_FullBurstDelayTime` | System.Single | Per-frame timers/delay constants. |
| gl | `_AimDrillEndTimer` / `_KeepAtk01Timer` / `_RideAttackTimer` | System.Single | Timers. |
| gl | `_IsRequestedEffectWeaponOn` | System.Boolean | Effect request flag. |
| gl | `_CanRoastCornDispLog` | System.Boolean | Easter-egg UI log flag (roasting corn). Irrelevant. |
| gl | `_IsKeepAtk01` / `_IsKeepAtk01FromLastAct` | System.Boolean | Combo-continuation bookkeeping, not an event. |
| gl | `_ChargeShotDir` / `_FullBurstOffsetAngle` / etc. | via.vec3 | Direction vectors that change continuously. |
| sa | `_SlashGaugeAutoRecoveryTimer` | System.Single | Looping auto-recovery timer, not the gauge (known past mistake) |
| sa | `_SwordAwakeGaugeAutoReduceTimer` | System.Single | Auto-reduce tick timer for the amp gauge; changes constantly |
| sa | `_SwordAwakeTimer` | System.Single | Countdown that changes every frame while amped; use only the 0 to >0 edge, or use get_IsSwordAwaken |
| sa | `_AxeEnhancedTimer` | System.Single | Countdown timer, changes every frame |
| sa | `_DischargeHitEffectCheckTimer` | System.Single | Internal effect-check interval timer |
| sa | `_BinEffectID` | app.Wp08Def.BIN_TYPE_EFFECT_ID | Struct of effect IDs (setup data), not state |
| sa | `_BinType` | app.Wp08Def.BIN_TYPE | Phial type of the equipped weapon; static per weapon |
| sa | `_PrevWpAttr` | app.WeaponDef.ATTR | Prev value cache |
| sa | `_DischargeConstPointIndex` / `_DischargeConstEmUniqueIndex` | System.Int32 | Attach-point indices; reset value unknown, may not reset between discharges |
| sa | `_DischargeMeshConstResult` | app.cMeshIntersectionResultWrapper | Mesh raycast result, not a gameplay flag |
| sa | `_SwordAddConstShellNum` | System.Int32 | Count of sticky additional-hit shells (internal shell bookkeeping, cleared by clearSwordAddConstShellCount) |
| sa | `_WpGimmickMotType` | app.Wp08Def.WP_GIMMICK_MOT_TYPE | Model gimmick motion variant (DEFAULT/TYPE_01), static |
| sa | `_SlashGauge.MaxValue` / `DefaultValue` | Nullable<Single> / Single | Max/Default constants, not the live value |
| sa | `<RequestRecoil>k__BackingField` | System.Boolean | Request flag consumed within a frame |
| sa | `<IsDrawOffRequested>k__BackingField` | System.Boolean | Request flag for sheathing |
| sa | `_Skill218or217Timer` | System.Single | Skill timer |
| sa | `_IsFittingMode` | System.Boolean | Equipment fitting/preview mode |
| cb | `_ActionEnterBinNum` | System.Int32 | Snapshot of the phial count at action enter (Prev-like), not live |
| cb | `_ActionEnterOverChargedBinNum` | System.Int32 | Snapshot at action enter, not live |
| cb | `_SwordEnhancedTimer` | System.Single | Countdown timer, changes every frame; edge-check only, or use get_IsSwordEnhanced |
| cb | `_ShieldEnhancedTimer` | System.Single | Countdown timer, changes every frame |
| cb | `_AxeEnhancedTimer` | System.Single | Countdown timer, changes every frame |
| cb | `_AxeSawHitStopTimer` | System.Single | Hit-stop duration timer |
| cb | `_AxeSawHitStopNoHitTimer` | System.Single | Interval timer between saw hits |
| cb | `_BinEffectID` | app.Wp09Def.BIN_TYPE_EFFECT_ID | Effect ID struct (setup data) |
| cb | `_BinType` | app.Wp09Def.BIN_TYPE | Impact/Element phial type; static per weapon |
| cb | `_PrevWpAttr` | app.WeaponDef.ATTR | Prev value cache |
| cb | `_WpGimmickMotType` | app.Wp09Def.WP_GIMMICK_MOT_TYPE | Model gimmick variant, static |
| cb | `_SwordBinNum.MaxValue` / `DefaultValue` | Nullable<Int32> / Int32 | Max/default constants, not the live count |
| cb | `<RequestRecoil>k__BackingField` | System.Boolean | Single-frame request flag |
| cb | `<IsDrawOffRequested>k__BackingField` | System.Boolean | Sheathe request flag |
| cb | `_Skill218or217Timer` | System.Single | Skill timer |
| ig | `InsectChargeTimer` | System.Single | Kinsect charge timer, continuously changes every frame |
| ig | `_ChargeTimer` | System.Single | Hold-time accumulator for charge; changes every frame, not the level |
| ig | `_PreChargeTimer` | System.Single | Pre-charge timer, per-frame |
| ig | `_IsPreAirCharge` | System.Boolean | Pre/previous state of air charge, not the current one |
| ig | `IsChargePreSucess` | System.Boolean | Pre-success (input window) flag, not actual charge level |
| ig | `<DirectChargeAttackEnableLv>k__BackingField` | System.Int32 | Threshold/config level that enables direct charge attack, not current level |
| ig | `_IsReplicaCharing` / `_IsReplicaInsectCharing` | System.Boolean | Network replica (other players) state, not local |
| ig | `ExtractTimer[i]._Value` | Single | Decreases every frame; trigger on >0 transitions only, or use get_IsRed/White/Orange |
| ig | `TrippleUpTimer._Value` | Single | Countdown timer; per-frame change |
| ig | `_Skill218or217Timer` | System.Single | Skill timer in base class |
| ig | `<RequestRecoil>k__BackingField` / `<IsDrawOffRequested>k__BackingField` | Boolean | Request flags, transient one-frame requests |
| ig | `_LandIgnoreTimer` (Hunter) | System.Single | Landing ignore timer, not airborne state |
| ig | `_ActionParam._ExtractTimerRed/White/Orange` | Single | Constant user_data durations (max), never change in play |
| bow | `_ChargeTimer` | System.Single | Hold-time accumulator, per-frame change; level is <ChargeLv> |
| bow | `_OnceChargeTimer` | System.Single | Timer, per-frame |
| bow | `<MaxChargeLv>k__BackingField` | CHARGE_LV | Max reachable level (config/skill), not current level |
| bow | `<PrevShotChargeLv>k__BackingField` | CHARGE_LV | Previous shot's level; changes only after shooting |
| bow | `IsPrevShotTsugiya` | Boolean | Prev state, not current |
| bow | `SelectedBottleItem` | app.ItemDef.ID | Item ID of selected bottle, not the coating type in use |
| bow | `JumpSlashBottleType` | BOTTLE_TYPE | Coating for a specific jump-slash attack, not the loaded coating |
| bow | `<Skill218BottleType>k__BackingField` / `<Skill218BottleNum>k__BackingField` | BOTTLE_TYPE / Int32 | Skill-218 extra bottle, separate from main coating |
| bow | `_WaitRemoveBottle` / `_WaitRemoveSkill218Bottle` | Boolean | Pending removal flags, transient |
| bow | `_ASkill005GaugeSpeedRate` | Single | Per-frame rate multiplier |
| bow | `_MultiLockonTargetAddTimer` / `_ScarBreakDelayTimer` / `_TsugiyaTutorialCDTimer` / `_TsugiyaTutorialContinueTimer` | Single | Timers/cooldowns |
| bow | `TsugiyaSettingEffect` | CreatedEffectContainer | Effect object handle, not state |
| bow | `_DispTsugiyaTutorial` | Boolean | UI tutorial display flag |
| bow | `IsJustGoshaPreInput` | Boolean | Pre-input buffer flag, not an executed action |
| bow | `_IsFirstUpdate` | Boolean | Init flag |
| bow | `<RequestRecoil>k__BackingField` / `<IsDrawOffRequested>k__BackingField` | Boolean | Request flags |
| bow | `_ActionParam._ChargeTimeLv2/3/4` | Single | Constant thresholds |
| hbg | `_PrevEnergyPartsState` | ENERGY_PARTS_STATE | Prev-frame copy; lags the real `_EnergyPartsState` |
| hbg | `_PrevShootSquatShellType` | SHELL_TYPE | Prev value of last squat-shot shell, not current ammo |
| hbg | `_RequestLackOfEnergyAction` | Boolean | Request flag, consumed quickly; may never be seen true by a poll |
| hbg | `_EnergyEfficiencyRate` | Single | Rate/multiplier from customization, not the gauge |
| hbg | `_EnergyEfficiencyCustomType` / `_EnergyBulletCustomLv` / `_NormalBulletCustomLv` | enums | Static artian/customization config, change only on equip |
| hbg | `_EnergyBulletInfo._UsingEnergy` / `_LatestUsingEnergy` | Single | Per-shot energy cost, not remaining gauge |
| hbg | `_SnipeAmmo._ChargeTimer` / `_ChargeTime` | Single | Charge timer / constant duration, loops per frame |
| hbg | `_Skill218or217Timer` | Single | Skill timer |
| hbg | `_DodgeReloadPoint` | Single | Accumulator for dodge-reload skill, not ammo |
| hbg | `_ActionShellType` / `_ReloadShellType` | Int32 | Transient shell type saved for the current shoot/reload action, not the selected ammo |
| hbg | `_Ammos[i]._LimitAmmo` / `_BackupAmmo` | Mandrake | Mag capacity (Max) / reserve pouch, not loaded rounds |
| hbg | `_Ammos[i]._AmmoType` | cWeaponGunAmmo.AMMO_TYPE | NORMAL/RAPID_BOOST category of the ammo slot, not the selected ammo |
| hbg | `_ShootAmmoReloadType` | AMMO_RELOADED_TYPE | Reload result category (FULL/EMPTY_3...), not a count |
| hbg | `_IsRequestedNoAmmoReload` | Boolean | Request flag |
| hbg | `_ParryHitEmID` / `_ParryHitPos` | Int32 / vec3 | Enemy ID / position of parry, not a state |
| hbg | `_IsDispPowerBarrel` | Boolean | Model display toggle only |
| hbg | `<RequestRecoil>k__BackingField` | Boolean | Request flag (one-frame) |
| lbg | `_IsPreRapidShotBoost` | Boolean | Pre-state flag (wind-up before boost), not the active mode |
| lbg | `_RapidShotBoostInfo._MaxModeTime` | Single | Max constant |
| lbg | `_RapidShotBoostInfo._AddRate` | Single | Per-frame/per-hit fill rate, not the gauge |
| lbg | `_RapidBoostHealRate` / `_SpecialAmmoHealRate` | Single | Recovery rates (auto-recovery), not values |
| lbg | `_SetBombInfo._ReloadTimer` / `_CatchAmmoInfo._ReloadTimer` | Single | Auto-recharge timer, loops continuously |
| lbg | `_MaxReloadTime` / `_MaxReloadTimeRate` / `_MaxAmmo` | Single/Byte | Max/const values |
| lbg | `_WeakAmmoInfo._CurrentChargeTime` / `_CurrentReloadTime` / `_ChargeTimeRate` | Single | Timers/rates, change every frame |
| lbg | `_WeakAmmoInfo._PreCurrentLevel` | WEAK_AMMO_CHARGE_TYPE | Previous-level copy |
| lbg | `_WeakAmmoInfo._IsRequestRemove` / `IsInterceptRemove` | Boolean | Request/remove flags |
| lbg | `_EmRideFinishInfo._DelayTime` | Single | Delay timer for the ride-finish shell |
| lbg | `_VariableNoAimRecoilDeg` | Single | Recoil angle parameter |
| lbg | `_AddRapidAmmo` | Int32 | Amount added to rapid ammo, not the current count (unknown semantics) |
| lbg | `_ShotGunAddEnergyList` | List<Int32> | Per-hit energy additions list |
| lbg | `_IsDispLongBarrel` / `_IsDispSuppressor` / `_WpGimmickMotType` | Boolean/enum | Model display / gimmick motion only |
| lbg | `SPECIAL_AMMO_TYPE_Fixed` | enum | Hashed 'Fixed' enum variant, values are not 0/1 |
| lbg | `_Ammos[i]._LimitAmmo` / `_BackupAmmo` | Mandrake | Capacity / reserve, not loaded |
| lbg | `_ActionShellType` / `_ReloadShellType` / `_Skill218or217Timer` / `_DodgeReloadPoint` | Int32/Single | Transient action shell types / timers / accumulators |

# Enums

- `app.Wp00Def.CHARGE_LEVEL`: LV0=0, LV1=1, LV2=2, LV3=3, MAX=4
- `app.Wp00Def.CHARGE_TYPE`: NORMAL=0, STRONG=1, SPIRIT=2, FLY=3, SLIDING=4, PARRY=5, BT_RIDE=6, MAX=7
- `app.Wp00Def.CHARGE_REQUEST_TYPE`: BASIC=0, NO_UPDATE=1, NONE=4294967295
- `app.HunterDef.PARRY_STATE`: NONE=0, WAIT=1, HIT=2, SUCCESS=3, RECOIL=4
- `app.Wp00Def.WP_GIMMICK_MOT_CHARGE_LV` (trap): NONE=0, LV3=1, LV2=2
- `app.Wp01Def.WP_GIMMICK_MOT_TYPE` (trap): DEFAULT=0, TYPE_01=1, TYPE_02=2, TYPE_03=3
- `app.Wp02Def.KIJIN_COMBO_LV`: INVALID=0, FROM_KIJIN1=1, FROM_KIJIN2=2
- `app.Wp02Def.KIJIN_EFFECT_TYPE`: NORMAL=0, FROM_CHAIN=1
- `app.Wp02Def.WP_GIMMICK_MOT_TYPE`: DEFAULT=0, TYPE_01=1, TYPE_02=2, TYPE_03=3
- `app.Wp02Def.KIJIN_USE_GAUGE_ACTION_TYPE`: RANBU_1=0, RANBU_2=1, RANBU_3=2, CHAIN_1=3, CHAIN_2=4, ZERO=99, MAX=100
- `app.Wp02Def.SPECIAL_ATTACK_PARAM_TYPE`: NONE=0, ENABLE_CONST_SPIN=1, CONST_SPIN=2, AIM_ATTACK=3, AIM_CONST_SPIN=4
- `app.Wp03Def.AURA_LEVEL`: INVALID=0, NONE=1, WHITE=2, YELLOW=3, RED=4
- `app.Wp03Def.KIJIN_CHARGE_LV`: LV0=0, LV1=1, LV2=2, LV3=3, MAX=4
- `app.Wp03Def.KIJIN_CHARGE_SPEED_TYPE`: NORMAL=0, FROM_KIJIN1=1, FROM_KIJIN2=2, FROM_KIJIN3=3
- `app.Wp03Def.KIJIN_COMBO_LV`: INVALID=0, FROM_KIJIN1=1, FROM_KIJIN2=2, FROM_KIJIN3=3
- `ace.AceUtil.DIR4_FBLR`: F=0, B=1, L=2, R=3, MAX=4, NONE=4294967295
- `app.Wp03Def.KIJIN_ACTION_TYPE`: KIJIN_SLASH_1=0, KIJIN_SLASH_2=1, KIJIN_SLASH_3=2, KIJIN_SLASH_ROUND=3, KIJIN_SLASH_FRONT=4, KIJIN_JUMP_SLASH_1=5, KIJIN_JUMP_SLASH_2=6, KIJIN_JUMP_SLASH_3=7, SLIDING_KIJIN_SLASH=8, KIJIN_STUB=9, ZERO=10, MAX=11
- `app.Wp03Def.SPECIAL_ATTACK_PARAM_TYPE`: NONE=0, KIJIN_SLASH_ROUND=1, KIJIN_STUB=2, MIKIRI_SLASH=3, KABUTOWARI_SLASH=4, IAI_SLASH=5, IAI_KIJIN_SLASH=6, WEAK_HIT_START=7, WEAK_HIT_KAMAE=8, RENKI_RELEASE_SLASH=10, PORTER_DISMOUNT_ATTACK=11, EM_RIDE_FINISH=12, IAI_KIJIN_SLASH_SHELL=13, WEAK_HIT_SLASH_1=14, WEAK_HIT_SLASH_2=15
- app.Wp04Def.CHARGE_LV: LV0=0, LV1=1, LV2=2, LV3=3, MAX=4
- app.Wp04Def.SUPER_CHARGE_LV: LV0=0, LV1=1, LV2=2, LV3=3, MAX=4
- app.Wp04Def.CHARGE_PLACE: GRAUND=0, SLOPE=1, AIR=2
- app.Wp04Def.WP_GIMMICK_MOT_TYPE: DEFAULT=0, TYPE_01=1, TYPE_02=2, TYPE_03=3, TYPE_04=4, TYPE_05=5
- app.HunterDef.PARRY_STATE: NONE=0, WAIT=1, HIT=2, SUCCESS=3, RECOIL=4
- app.Wp05Def.TONE_TYPE: NONE=0, TONE_1=1, TONE_2=2, TONE_3=3, MAX=4
- app.Wp05Def.WP05_HIBIKI_SKILL_TYPE: NONE=0, HIBIKI_DODGE_NO_HIT_MOVE_SPD=1, HIBIKI_REGENE=2, HIBIKI_STAMINA=3, HIBIKI_ATK_UP_CRT_UP=4, HIBIKI_DEF_UP_ATTR_DEF_UP=5, HIBIKI_DISABLE_BAD_COND_ATTR_DMG=6, MAX=7
- app.Wp05Def.MULTI_M_START: NONE=0, ONE=1, TWO=2, THREE=3
- app.Wp05Def.MUSIC_STOCK_TYPE: TOP=0, MID=1, BOT=2
- app.Wp05Def.MUSIC_GAME_RESULT: JUST_SUCCESS=0, SUCCESS=1, INVALID=2
- app.Wp05Def.WP05_MUSIC_SKILL_TYPE: INVALID=0, SELF_BUFF=1, HEAL_S=2 ... SP_PARRY_SOUND_ATTACK=49, SP_PENETRATE_SOUND_ATTACK=50, SP_HEAL=51, MAX=52 (full list in wp05.md)
- app.Wp06Def.WP_GIMMICK_MOT_TYPE: DEFAULT=0, TYPE_01=1, TYPE_02=2, TYPE_03=3
- app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE: NONE=0, START=1, LOOP=2, END=3
- app.Wp07Def.SHELL_TYPE: NORMAL=0, WIDE=1, LONG=2, MAX=3
- app.Wp07Def.FULL_BURST_TYPE: V_SLASH=0, BF=1, RBF=2
- app.Wp07Def.COMBO_DIR: NONE=0, FRONT=1, FRONT_UP=2, UP=3, UP_FRONT_SHOT=4
- app.Wp07Def.WP_GIMMICK_MOT_TYPE: DEFAULT=0, TYPE_01=1, TYPE_02=2
- app.Wp07Def.SHELL_PARAM_TYPE (not a field type): NONE=0, SHOT=1, CHARGE_SHOT=2, CHARGE_SHOT_CHILD=3, FULL_BURST=4, RYUUGEKI=5, PILE=6, PILE_CONST=7, PILE_BLAST=8, RBF_PILE_CONST=9, RBF_PILE_BLAST=10, DRILL=11, MAX=12
- `app.Wp08Def.MODE`: AXE=0, SWORD=1
- `app.Wp08Def.BIN_TYPE`: POWER=0, ELEMENT=1, DRAGON=2, STAMINA=3, PARALYSE=4, POISON=5, MAX=6
- `app.Wp08Def.SHELL_TYPE` (not on a field): DISCHARGE=0, SWORD_ADDITIONAL_HIT_CONST=1, SWORD_ADDITIONAL_HIT=2, SWORD_DISCHARGE_SWITCH_FINISH_CONST=3, SWORD_DISCHARGE_SWITCH_CHARGE_FINISH_CONST_1=4, SWORD_DISCHARGE_SWITCH_CHARGE_FINISH_CONST_2=5, SWORD_DISCHARGE_SWITCH_BLAST=6, SWORD_PARRY_FINISH_CONST=7
- `app.Wp08Def.WP_GIMMICK_MOT_TYPE`: DEFAULT=0, TYPE_01=1
- `app.Wp09Def.MODE`: SWORD=0, AXE=1
- `app.Wp09Def.SWORD_ENERGY_STATE`: NONE=0, RELOAD_S=1, RELOAD_L=2, OVER_HEAT=3
- `app.Wp09Def.AXE_SAW_HIT_STOP_STATE`: NONE=0, READY=1, HIT=2, DONE=3
- `app.Wp09Def.AXE_SAW_MOTION_STATE`: NONE=0, ROTATE=1, END=2
- `app.Wp09Def.SHELL_CREATE_MODE`: NONE=0, AXE_ATTRIBUTE=1, AXE_DISCHARGE=2, AXE_DISCHARGE_2=3, SWORD_ENHANCED=4, SHIELD_ATTACK=5
- `app.Wp09Def.BIN_TYPE`: GRENADE=0, ELEMENT=1, MAX=2
- `app.Wp10Def.EXTRACT_TYPE`: RED=0, WHITE=1, ORANGE=2, BUFF_MAX=3, GREEN=3, MAX=4, NONE=4294967295
- `app.Wp10Def.WP_GIMMICK_MOT_TYPE`: DEFAULT=0, TYPE_01=1, TYPE_02=2, TYPE_03=3
- `app.WeaponDef.WP_EX_GIMMICK_MOT_PHASE`: NONE=0, START=1, LOOP=2, END=3
- `app.Wp11Def.CHARGE_LV`: NONE=0, LV1=1, LV2=2, LV3=3, LV4=4, HOMING=5
- `app.Wp11Def.BOTTLE_TYPE`: NONE=0, CLOSE=1, STRONG=2, PENETRATE=3, PARALYSE=4, POISON=5, SLEEP=6, BLAST=7, STAMINA=8, MAX=9
- `app.Wp11Def.ARROW_TYPE`: NORMAL=0, QUICK_SHOT=1, GOSHA=2, KYOKUSHA=3, KYOKUSHA_CHILD=4, SPECIAL=5, GOSHA_RAPID=6, TSUGIYA_ATTACH=7, TSUGIYA_BLAST=8, JUMP=9, TSUGIYA=10, MULTI_LOCKON=11, MULTI_LOCKON_SCAR_HIT=12, MULTI_LOCKON_DERIVATION=13, TWIN=15, SPECIAL_SHORT=17, TSUGIYA_ATTACH_MINI=18, TSUGIYA_MINI=19, MULTI_LOCKON_SCAR_ATTACH=20, EM_RIDE_TSUGIYA_ATTACH=21, EM_RIDE_FINISH=22, EM_RIDE_TSUGIYA=23, DASH_CLIMB=24, STEALTH=25, NORMAL_ASKILL005=50, HOMING_BODY_HIT=99
- `app.cHunterWp11Handling.MULTI_LOCKON_PHASE`: PRE_LOCK_ON=0, LOCK_ON_LV_1=1, LOCK_ON_LV_2=2, LOCK_ON_LV_MAX=3
- app.Wp12Def.ENERGY_PARTS_STATE: OFF=0, IDLE=1, USING=2, USE_END=3, USE_END_EMPTY=4, NOT_USE_END=5
- app.Wp12Def.ENERGY_BULLET_CHARGE_LV: LV0=0, LV1=1, LV2=2, LV3=3, MAX=4
- app.cWeaponGunAmmo.AMMO_TYPE: NORMAL=0, RAPID_BOOST=1
- app.WeaponGunDef.SHELL_TYPE: NORMAL=0, PENETRATE=1, SHOT_GUN=2, GRENADE=3, MORTAR=4, SLASH=5, RYUUGEKI=6, FIRE=7, WATER=8, ELEC=9, ICE=10, DRAGON=11, POISON=12, PARALYSE=13, SLEEP=14, KIJIN=15, KOUKA=16, HEAL=17, STAMINA=18, CAPTURE=19, MAX=20, ENERGY_GATLING=21, ENERGY_LASER=22, ENERGY_PARRY=23, ENERGY_GRENADE=24, ENERGY_WEAK_POINT_SNIPE=25, WEAK_POINT=26, SET_BOMB=27, CATCH=28, EM_RIDE_FINISH=29
- app.Wp12Def.BULLET_CUSTOM_LV: LV0=0, LV1=1, LV2=2, MAX=3
- app.Wp12Def.ENERGY_BULLET_TYPE (unreferenced): STANDARD=0, POWER=1, WEAK_POINT=2, MAX=3
- app.Wp13Def.SPECIAL_AMMO_TYPE: SET_BOMB=0, CHATCH=1, MAX=2
- app.Wp13Def.WEAK_AMMO_CHARGE_TYPE: LV_0=0, LV_1=1, LV_2=2, LV_3=3, MAX=4
- app.Wp13Def.ENERGY_PARTS_STATE: OFF=0, USE_OFF=1, IDLE=2, USING=3, USE_END=4, USE_END_EMPTY=5, NOT_USE_END=6, BEGIN_ATTACH=7
- app.Wp13Def.WP_GIMMICK_MOT_TYPE: DEFAULT=0, TYPE_01=1, TYPE_02=2, TYPE_03=3
- app.Wp13Def.CATCH_AMMO_LEVEL (unreferenced): LV_1=0, LV_2=1, LV_3=2
- app.Wp13Def.SET_BOMB_LEVEL (unreferenced): LV_1=0, LV_2=1, LV_3=2, LV_4=3, MAX=4

# Vibration / Adaptive Trigger API

**Supplement (pulled directly from the dump):** `ace.cPadInfo.VIBRATION_MOTOR_TYPE`: LOW=0, HIGH=1, LTRIGGER=2, RTRIGGER=3, MAX=4 · `ace.cPadInfo.VibrationJob._Infos` : `List<System.Single>[]`



I removed the numeric id suffix from each method name. The original names are kept in parentheses.

## 1. ace.cPadInfo: vibration and adaptive trigger methods

Parent class: `System.Object`. Both methods asked about were found.

| Method | Params | Returns | Notes |
|---|---|---|---|
| `addVibrationRequest` (addVibrationRequest296627) | `System.Single`, `ace.cPadInfo.VIBRATION_MOTOR_TYPE` | `System.Void` | **Found.** The values of the `VIBRATION_MOTOR_TYPE` enum are not in the digest. |
| `setAdaptiveTriggerFeedback` (setAdaptiveTriggerFeedback296612) | `System.Single[]`, `System.Single`, `via.hid.AdaptiveTriggerMotor` | `System.Void` | **Found.** Takes an array. |
| `setAdaptiveTriggerFeedback` (setAdaptiveTriggerFeedback296613) | `System.Single` x5, `via.hid.AdaptiveTriggerMotor` | `System.Void` | **Found.** Takes 5 scalars. |
| `setAdaptiveTriggerFeedbackLeftTrigger` (…296614) | `System.Single` x5 | `System.Void` | Left trigger only |
| `setAdaptiveTriggerFeedbackRightTrigger` (…296615) | `System.Single` x5 | `System.Void` | Right trigger only |
| `resetAdaptiveTriggerFeedback` (…296616) | none | `System.Void` | |
| `stopVibration` (stopVibration296628) | none | `System.Void` | |
| `updateVibration` (updateVibration296626) | `System.Single` | `System.Void` | The game probably calls this every frame. The parameter is likely delta time (my guess). |
| `setVibrationWaveIndex` (…296610) | `System.UInt32` | `System.Void` | |
| `resetVibrationWaveIndex` (…296611) | none | `System.Void` | |
| `get_VibrationWaveIndex` (…296604) | none | `System.UInt32` | |
| `get_LTrigger` (…296580) | none | `System.Single` | Reads the trigger value. It does not give feedback. |
| `get_RTrigger` (…296581) | none | `System.Single` | Reads the trigger value. It does not give feedback. |
| `get_KeyTrigger` (…296573) | none | `ace.ACE_PAD_KEY.BITS` | Button-press bits. Not related to adaptive triggers. |
| `clearTrigger` (…296621) | none | `System.Void` | Probably clears input trigger state, not adaptive feedback (low confidence). |

ace.cPadInfo fields related to vibration:

| Field | Type |
|---|---|
| `_Vibration` | `ace.cPadInfo.VibrationJob` (its sub-fields are not in the digest) |
| `_Device` | `via.hid.GamePadDevice` |
| `_GamePlayerIndex` | `via.hid.GamePlayerIndex` |
| `_LTrigger` / `_RTrigger` | `System.Single` |

Points to watch:
- The digest does not name the 5 float parameters of `setAdaptiveTriggerFeedback`. Work out their meaning by testing, not by guessing.
- The digest does not expand `ace.cPadInfo.VIBRATION_MOTOR_TYPE` or `ace.cPadInfo.VibrationJob`.

Other vibration request API: `ace.PadVibrationManager`1<app.cADVibration>`

| Method | Params | Returns |
|---|---|---|
| `addVibrationRequest` (1120837) | `ace.user_data.PadVibrationPresetList.cMotorVibration`, `ace.user_data.PadVibrationPresetList.cPadVibrationPreset`, `System.Guid`, `ace.PadVibrationDefine.PAD_INDEX`, `via.GameObject`, `via.GameObject`, `ace.cJointHash`, `System.Nullable`1<via.vec3>`, `System.Boolean` | `System.Void` |
| `addVibrationRequest` (1120838) | `System.Guid`, `ace.PadVibrationDefine.PAD_INDEX`, `via.GameObject`, `via.GameObject`, `ace.cJointHash`, `System.Nullable`1<via.vec3>`, `System.Boolean` | `System.Void` |
| `addVibrationRequest` (1120839) | `ace.motion_track.PadVibrationTrackBase`, `ace.PadVibrationDefine.PAD_INDEX`, `via.GameObject`, `via.GameObject` | `System.Void` |
| `tryADVibration` (1120852) | `ace.user_data.PadVibrationPresetList.cPadVibrationPreset`, `ace.user_data.ADVibrationPresetList.cADVibrationPreset` | `System.Boolean` |
| `addADVibrationPreset` / `removeADVibrationPreset` | `ace.user_data.ADVibrationPresetList` | `System.Void` |
| `addVibrationPreset` / `removeVibrationPreset` | `ace.user_data.PadVibrationPresetList` | `System.Void` |
| `stopVibration` / `stopMotorVibration` | `System.Guid`, `ace.PadVibrationDefine.PAD_INDEX` | `System.Void` |
| `stopAllVibration` / `stopAllMotorVibration` | none | `System.Void` |
| `requestPauseVibration` / `requestResumeVibration` | none | `System.Void` |

Fields of `ace.PadVibrationManager`1<app.cADVibration>`:

| Field | Type |
|---|---|
| `_ADVibration` | `app.cADVibration` |
| `_AllADPresetDict` | `Dictionary<System.UInt32, ace.user_data.ADVibrationPresetList.cADVibrationPreset>` |
| `_AllPresetDict` | `Dictionary<System.Guid, ace.user_data.PadVibrationPresetList.cPadVibrationPreset>` |
| `_DefaultADPreset` | `ace.user_data.ADVibrationPresetList` |
| `_DefaultPreset` | `ace.user_data.PadVibrationPresetList` |
| `_IsPauseVibration` | `System.Boolean` |
| `_IsPauseVibrationPrev` | `System.Boolean` (trap: holds the previous frame's value) |
| `_Requests` | `List<ace.PadVibrationDefine.cRequestData>` |
| `_VibrationRequestUpdator` | `ace.cVibrationRequestUpdator` |
| `_NSWVibrationManager` | `ace.cNSWVibrationManager` |
| `_AllADRWLock`, `_AllPresetListRWLock` | `via.threading.SimpleReaderWriterLock` |
| `_PauseVibrationLockObj`, `_RequestsLockObj` | `ace.cLockObject` |

## 2. AdaptiveTrigger enums

### via.hid.AdaptiveTriggerMotor

| Name | Value |
|---|---|
| LAnalogTriggerMotor | 0 |
| RAnalogTriggerMotor | 1 |
| Null | 254 |
| All | 255 |

### via.hid.AdaptiveTriggerState

| Name | Value |
|---|---|
| Off | 0 |
| Intercepted | 1 |
| Standby | 2 |
| Active | 3 |
| Pulling | 4 |
| Fired | 5 |

There are no other AdaptiveTrigger enums in the file.

## 3. app.cADVibration and ace.user_data.ADVibrationPresetList

### app.cADVibration

Parent class: `ace.cAceAdvancedVibrationBase`. Every field below is inherited from it, and the digest lists no methods.

| Field | Type |
|---|---|
| `_ActivePadBits` | `System.UInt32` |
| `_AttenuationInfoList` | `Dictionary<System.UInt32, ace.cAceAdvancedVibrationBase.UPDATE_ATTEANUATION_INFO>` |
| `_AttenuationInfoListLockObj` | `via.threading.SimpleReaderWriterLock` |
| `_BusInfoTbl` | `ace.cAceAdvancedVibrationBase.cBusInfo[]` |
| `_IsCalledDeviceUnassigned` | `System.Boolean` |
| `_LegacyVibrating` | `System.UInt32` |
| `_PlayingIdTbl` | `Dictionary<System.UInt32, List<System.UInt32>>` |
| `_PlayingIdTblLockObj` | `via.threading.SimpleReaderWriterLock` |
| `_ReqIdDict` | `Dictionary<System.UInt32, System.UInt32>` |
| `_RequestIdTable` | `System.UInt32[,]` |
| `_SineWavResource_L` | `via.audiorender.VibrationSourceResourceHolder` |
| `_SineWavResource_R` | `via.audiorender.VibrationSourceResourceHolder` |
| `_StopExecuter` | `ace.cAceAdvancedVibrationBase.cStopExecuter` |
| `_VibrationWaveIndexLockObj` | `ace.cLockObject` |

The digest does not expand the sub-fields of `UPDATE_ATTEANUATION_INFO`, `cBusInfo` or `cStopExecuter`.

### ace.user_data.ADVibrationPresetList

Parent class: `via.sound.SoundUserData`.

| Field | Type |
|---|---|
| `_List` | `ace.user_data.ADVibrationPresetList.cADVibrationPreset[]` |
| `_RefCnt` | `System.Int32` |

### ace.user_data.ADVibrationPresetList.cADVibrationPreset

Parent class: `System.Object`.

| Field | Type |
|---|---|
| `_BnvibResource` | `via.hid.BnvibResourceHolder` |
| `_DurationAD` | `System.Single` |
| `_VibAudioSource` | `via.audiorender.VibrationSourceResourceHolder` |
| `_VibrationOutputNode` | `System.Int32` |
| `_VibrationTrigger` | `System.UInt32` |
| `_Volume` | `System.Single` |

Methods: `get_VibrationOutputNode()` returns `via.hid.VibrationOutputNode`, and `get_VibrationTrigger()` returns `System.UInt32`.

- `_VibrationTrigger` is a UInt32 id. It is also the key of `_AllADPresetDict` (Dictionary<UInt32, cADVibrationPreset>), which I'm inferring from the dictionary type. Despite the name, it is not an adaptive trigger setting.
- The digest does not list the values of the `via.hid.VibrationOutputNode` enum.

Not present in the file: the `via.hid.GamePadDevice` members, the `PAD_INDEX` values and the `VIBRATION_MOTOR_TYPE` values.

# JSON map

```json
{
  "gs": {
    "chargeLevel": "_ChargeLevel",
    "charging": "action:app.Wp00Action.ID in {IdleToCharge=5,CHARGE=6,STORNG_CHARGE=7,Charge_Fly=8,SPIRIT_CHARGE=11,IDLE_TO_PARRY_CHARGE=21,PARRY_CHARGE=22}",
    "guard": "hunter:checkHunterStatusFlag(STATUS_FLAG.GUARD=2)",
    "guardHit": "hunter:get_DamageInfo()._DamageType in {GUARD_S=34,GUARD_M=35,GUARD_L=36,GUARD_TECH=37,GUARD_TECH_M=38,GUARD_POINT_S/M/L=41-43,POWER_GUARD=44}",
    "chargeType": "_ChargeType",
    "overheat": "_IsOverheat",
    "spiritSlashEnhanced": "_IsSpiritSlashEnhanced",
    "chargeContinue": "_ChargeContinue",
    "parryState": "<ParryState>k__BackingField",
    "hitEnemy": "_IsHitAttackToEnemy",
    "hitWeakPoint": "_IsHitWeakPoint",
    "woundBreakCount": "_ScarBreakCount",
    "justChargeTiming": "method:isJustChargeTiming",
    "maxCharge": "method:isMaxCharge",
    "weaponDrawn": "Hunter:_IsWeaponOn"
  },
  "sns": {
    "guard": "hunter:checkHunterStatusFlag(STATUS_FLAG.GUARD=2)",
    "guardHit": "hunter:get_DamageInfo()._DamageType in {GUARD_S=34,GUARD_M=35,GUARD_L=36,GUARD_TECH=37,GUARD_TECH_M=38,GUARD_POINT_S/M/L=41-43,POWER_GUARD=44}",
    "perfectRush": "_IsLastJustRushFinshSuccess",
    "chargedChop": "action:app.Wp01Action.ID in {BACK_STEP_CHARGE=24,CHARGE_SLASH=25}",
    "stepSlashCount": "_StepSlashCount",
    "hitFinishAttack": "_IsHitFinishAttack",
    "hitTearScar": "_IsHitTearScar",
    "woundBreakCount": "_ScarBreakCount",
    "parryState": "<ParryState>k__BackingField",
    "hitEnemy": "_IsHitAttackToEnemy",
    "hitWeakPoint": "_IsHitWeakPoint",
    "weaponDrawn": "Hunter:_IsWeaponOn",
    "perfectRushAction": "action:app.Wp01Action.ID in {JUST_RUSH_START=48,JUST_RUSH_COMBO_0=49,JUST_RUSH_COMBO_1=50,JUST_RUSH_COMBO_2=51}"
  },
  "db": {
    "demonMode": "_IsKijinOn",
    "demonGauge": "<KijinGauge>k__BackingField._Value",
    "archdemon": "_IsKijinEnhancement",
    "perfectEvade": "<IsMikiriDodgeSuccessed>k__BackingField",
    "mikiriSuccessPulse": "_MikiriSuccessFrame",
    "mikiriCount": "_MikiriCount",
    "mikiriBuff": "<IsMikiriBuff>k__BackingField",
    "demonComboLv": "<KijinComboLv>k__BackingField",
    "constSpinHits": "ConstSpinHitCount",
    "parryState": "<ParryState>k__BackingField"
  },
  "ls": {
    "spiritGauge": "<RenkiGauge>k__BackingField._Value",
    "spiritLevel": "<AuraLevel>k__BackingField",
    "iaiStance": "action:app.Wp03Action.ID in {IAI_WP_OFF=23}",
    "foresightSuccess": "IsMikiriSuccessed",
    "iaiSuccess": "IsIaiKijinMikiriSuccessed",
    "foresightHit": "IsMikiriHitSuccessed",
    "redForesightHit": "IsRedMikiriHitSuccessed",
    "iaiSlashHit": "IsIaiSlashHitted",
    "iaiSpiritSlashHit": "IsIaiKijinSlashHitted",
    "redIaiSpiritHitCount": "_RedIaiKijinHitCount",
    "redRoundslashHitCount": "_RedSlashRoundHitCount",
    "mikiriSuccessPulse": "_MikiriSuccessFrame",
    "spiritChargeLv": "_KijinChargeLv",
    "spiritFullCharge": "_IsKijinFullCharge",
    "helmBreakerStart": "_IsKabutowariStart",
    "helmBreakerHits": "_KabutowariHitNum",
    "parryState": "<ParryState>k__BackingField",
    "iaiAttack": "action:app.Wp03Action.ID in {IAI_END=24,IAI_SLASH=25,IAI_KIJIN_SLASH_NONE=26,IAI_KIJIN_SLASH_WHITE=27,IAI_KIJIN_SLASH_YELLOW=28,IAI_KIJIN_SLASH_RED=29}"
  },
  "hammer": {
    "chargeLevel": "<ChargeLv>k__BackingField",
    "charging": "method:get_IsCharging",
    "powerMode": "<SuperChargeLv>k__BackingField",
    "powerModeActive": "method:get_IsSuperCharging",
    "preCharging": "_IsPreCharging",
    "parryAttack": "_IsParryAttack",
    "parryState": "<ParryState>k__BackingField",
    "spinCount": "SpinCount",
    "bounceAttackHit": "<IsBounceAttackHit>k__BackingField",
    "hitEnemy": "_IsHitAttackToEnemy",
    "woundBreakCount": "_ScarBreakCount"
  },
  "hh": {
    "notesStored": "_ToneBuffer",
    "performing": "action:app.Wp05Action.ID in {FAST_PLAYING=26,M_START_1=27,M_START_1_SP_00=28,M_START_1_SP_01=29,M_START_1_FRONT_ONLY=30,M_START_1_SP_00_FRONT_ONLY=31,M_START_1_SP_01_FRONT_ONLY=32,M_START_2=33,M_START_3=34,M_WAIT=35,M_MOVE=36,M_END=37,ADD_M_START=38,ADD_THREE_M_START=39,ADD_M_WAIT=40,ADD_M_MOVE=41,NEW_ADD_M_START=42,NEW_ADD_M_START_ATTACK_00_01=43}",
    "echoBubbleCount": "_HibikiFloatShellInfo._Ammo",
    "echoBubbleFull": "method:get_IsHibikiFloatShellAmmoFull",
    "echoType": "_HibikiFloatShellInfo._HibikiShellType",
    "songsStocked": "_MusicStockBuff",
    "songStocked": "_IsStockMusic",
    "songAdded": "_AddMusicStock",
    "songAvailable": "method:get_IsAvailableMusic",
    "musicGameSuccessNotes": "_MusicGame._SuccessNotesCount",
    "musicGameActive": "_MusicGame._IsGameStart",
    "justMAction": "_IsJustM_Action",
    "parryState": "<ParryState>k__BackingField",
    "penetrateSoundHit": "_PenetrateSoundAttackHit",
    "hitEnemy": "_IsHitAttackToEnemy"
  },
  "lance": {
    "guarding": "hunter:checkHunterStatusFlag(STATUS_FLAG.GUARD=2)",
    "powerGuard": "hunter:checkHunterStatusFlag(STATUS_FLAG.POWER_GUARD=3)",
    "guardHit": "hunter:get_DamageInfo()._DamageType in {GUARD_S=34,GUARD_M=35,GUARD_L=36,GUARD_TECH=37,GUARD_TECH_M=38,GUARD_POINT_S/M/L=41-43,POWER_GUARD=44}",
    "lanceCharge": "_RushLevel",
    "lanceChargeStrong": "<IsStrongRush>k__BackingField",
    "guardSuccess": "_IsGuardSuccess",
    "parryState": "<ParryState>k__BackingField",
    "finishChargeLevel": "_FinishChargeLevel",
    "finishCounterSuccess": "IsFinishCounterSuccessed",
    "guardToFinishStingerLv": "_GuardToFinishStingerChargeLv",
    "powerGuardReactCount": "_PowerGuardMaxReactCount",
    "stepCount": "_StepCount",
    "hitEnemy": "_IsHitAttackToEnemy"
  },
  "gl": {
    "shellsLoaded": "method:get_LoadedAmmo",
    "wyrmstakeLoaded": "_IsPileLoaded",
    "wyvernsFire": "_RyuugekiGauge._Value",
    "wyvernsFireReady": "method:get_CanRyuugekiShoot",
    "wyvernsFireRate": "method:get_RyuugekiGaugeRate",
    "guard": "hunter:checkHunterStatusFlag(STATUS_FLAG.GUARD=2)",
    "guardHit": "hunter:get_DamageInfo()._DamageType in {GUARD_S=34,GUARD_M=35,GUARD_L=36,GUARD_TECH=37,GUARD_TECH_M=38,GUARD_POINT_S/M/L=41-43,POWER_GUARD=44}",
    "parryState": "<ParryState>k__BackingField",
    "chargeShotCount": "_ChargeShotCount",
    "fullBurstShotCount": "_FullBurstShotCount",
    "fullBurstTrigger": "_IsTriggerFullBurst",
    "chargeShotTrigger": "_IsTriggerChargeShot",
    "stepCount": "_StepCount",
    "hitEnemy": "_IsHitAttackToEnemy"
  },
  "sa": {
    "mode": "_Mode",
    "switchGauge": "_SlashGauge._Value",
    "swordAmp": "method:get_IsSwordAwaken",
    "swordAmpTimerFallback": "_SwordAwakeTimer",
    "ampGauge": "_SwordAwakeGauge._Value",
    "dischargeActive": "action:app.Wp08Action.ID in {SWORD_DISCHARGE_STAB=34,SWORD_DISCHARGE_STAB_SHORT=35,SWORD_DISCHARGE_STAB_END=36,SWORD_DISCHARGE_STAB_ATTACK=37,SWORD_DISCHARGE_STAB_FINISH=38,SWORD_DISCHARGE_STAB_FINISH_WEAK=39,SWORD_DISCHARGE_STAB_AIM_FINISH=40,SWORD_DISCHARGE_CONST=41,SWORD_DISCHARGE_CONST_FINISH=42,SWORD_DISCHARGE_CONST_FINISH_WEAK=43,SWORD_DISCHARGE_SWITCH_FINISH_START=44,SWORD_DISCHARGE_SWITCH_FINISH=45,SWORD_DISCHARGE_SWITCH_CHARGE_FINISH=46,SWORD_JUMP_DISCHARGE_STAB=67,SWORD_JUMP_DISCHARGE_STAB_LAND=68}",
    "axeEnhanced": "method:get_IsAxeEnhanced",
    "axeEnhancedTimerFallback": "_AxeEnhancedTimer",
    "parryState": "<ParryState>k__BackingField",
    "hitEnemy": "_IsHitAttackToEnemy",
    "woundBreakCount": "_ScarBreakCount"
  },
  "cb": {
    "phials": "_SwordBinNum._Value",
    "swordCharged": "method:get_IsSwordEnhanced",
    "swordChargedTimerFallback": "_SwordEnhancedTimer",
    "shieldCharged": "method:get_IsShieldEnhanced",
    "shieldChargedTimerFallback": "_ShieldEnhancedTimer",
    "savageAxe": "method:get_IsAxeEnhanced",
    "savageAxeTimerFallback": "_AxeEnhancedTimer",
    "mode": "_Mode",
    "guard": "hunter:checkHunterStatusFlag(STATUS_FLAG.GUARD=2)",
    "guardHit": "hunter:get_DamageInfo()._DamageType in {GUARD_S=34,GUARD_M=35,GUARD_L=36,GUARD_TECH=37,GUARD_TECH_M=38,GUARD_POINT_S/M/L=41-43,POWER_GUARD=44}",
    "guardPoint": "hunter:checkHunterStatusFlag(STATUS_FLAG.GUARD_POINT=6)",
    "overchargedPhials": "_SwordOverChargedBinNum._Value",
    "swordEnergy": "_SwordEnergyPoint._Value",
    "swordEnergyState": "_SwordEnergyState",
    "axeSawHitStopState": "_AxeSawHitStopState",
    "axeSawMotionState": "_AxeSawMotionState",
    "axeSawHitCount": "_AxeSawAttackCountInAction",
    "shellCreateMode": "_ShellCreateMode",
    "parryState": "<ParryState>k__BackingField",
    "hitEnemy": "_IsHitAttackToEnemy"
  },
  "ig": {
    "redExtract": "method:get_IsRed (alt raw: ExtractTimer[0]._Value)",
    "whiteExtract": "method:get_IsWhite (alt raw: ExtractTimer[1]._Value)",
    "orangeExtract": "method:get_IsOrange (alt raw: ExtractTimer[2]._Value)",
    "airborne": "<Hunter>k__BackingField.<Landed>k__BackingField (inverted)",
    "chargeLevel": "<ChargeLv>k__BackingField",
    "tripleUp": "method:get_IsTrippleUp (alt raw: TrippleUpTimer._Value)",
    "airCharge": "_IsAirCharge",
    "vaultCount": "_EmStepCount",
    "markHit": "IsAimAttackHitted",
    "insectCharging": "<InsectChargingThisFrame>k__BackingField",
    "parryState": "<ParryState>k__BackingField",
    "hitEnemy": "_IsHitAttackToEnemy",
    "scarBreakCount": "_ScarBreakCount"
  },
  "bow": {
    "chargeLevel": "<ChargeLv>k__BackingField",
    "drawing": "action:app.Wp11Action.ID in {SPECIAL_CHARGE=5,CHARGE_RUN=14,CHARGE_RUN_STOP=15,RUN_TO_CHARGE=16,KYOKUSHA_AIM_START=17,KYOKUSHA_AIM_LOOP=18,JUMP_CHARGE=23,AIM_IDLE=152,AIM_MOVE=153,AIM_MOVE_STOP=154}",
    "coating": "<BottleType>k__BackingField",
    "coatingCount": "<BottleNum>k__BackingField",
    "bottleShotCount": "<BottleShotCount>k__BackingField",
    "arrowGauge": "<ArrowGauge>k__BackingField._Value",
    "perfectDodge": "<IsMikiriDodgeSuccessed>k__BackingField",
    "perfectDodgeSuper": "<IsMikiriSuper>k__BackingField",
    "mikiriFrame": "_MikiriSuccessFrame",
    "tsugiyaSet": "IsTsugiyaSetting",
    "parryState": "<ParryState>k__BackingField",
    "hitEnemy": "_IsHitAttackToEnemy",
    "scarBreakCount": "_ScarBreakCount"
  },
  "hbg": {
    "ammoInMag": "_Ammos[_ShellType]._LoadedAmmo (via.rds.Mandrake; prefer method:getCurrentAmmo)",
    "ammoType": "_ShellType",
    "specialMode": "_IsEnergyMode",
    "specialGauge": "_EnergyBulletInfo._CurrentEnergy",
    "energyPartsState": "_EnergyPartsState",
    "energyChargeLevel": "_EnergyBulletInfo._CharageLevel",
    "parryState": "<ParryState>k__BackingField",
    "gatlingHitCount": "_GatlingHitCount",
    "snipeAmmo": "_SnipeAmmo._CurrentAmmo",
    "parryHitChargeLevel": "_ParryHitChargeLevel",
    "selectedShellItem": "_SelectedShellItem"
  },
  "lbg": {
    "ammoInMag": "_Ammos[_ShellType]._LoadedAmmo (via.rds.Mandrake; prefer method:getCurrentAmmo)",
    "ammoType": "_ShellType",
    "specialMode": "_IsRapidShotBoost",
    "specialGauge": "method:get_RapidBoostGaugeRate (field fallback: _RapidShotBoostInfo._ModeTime)",
    "canRapidShotBoost": "method:get_IsCanRapidShotBoost",
    "rapidShootCount": "<RpidShootCount>k__BackingField",
    "specialAmmoType": "_SpecialAmmoType",
    "setBombAmmo": "_SetBombInfo._Ammo",
    "catchAmmo": "_CatchAmmoInfo._Ammo",
    "specialAmmoGauge": "method:get_SpecialAmmoGaugeRate",
    "weakAmmo": "_WeakAmmoInfo._Ammo",
    "weakAmmoLevel": "_WeakAmmoInfo._CurrentLevel",
    "parryState": "<ParryState>k__BackingField",
    "selectedShellItem": "_SelectedShellItem"
  }
}
```