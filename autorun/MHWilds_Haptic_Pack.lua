-- =============================================
-- MHWilds Haptic Pack  —  DualSense adaptive triggers + haptics / rumble-controller feedback
-- for all 14 weapons of Monster Hunter Wilds.
-- Requires REFramework. Install: <game folder>/reframework/autorun/MHWilds_Haptic_Pack.lua
-- Settings are saved to <game folder>/reframework/data/MHWilds_Haptic_Pack.json
--
-- Design rules:
--  * Trigger force is sent with setAdaptiveTriggerFeedback(..., AdaptiveTriggerMotor)
--    (the Left/Right-only variants overwrite each other, so only one trigger would keep its effect).
--  * No trigger resistance at rest. Resistance only appears in meaningful states
--    (charging, drawing the bow, guarding with a shield...).
--  * Attacks landing / releasing a charge => BODY rumble (haptics + motors), not trigger rumble.
--  * Controllers without adaptive triggers (Xbox / XInput / Flydigi Vader...) get the same design
--    through motors: trigger effects are emulated with trigger/grip motors.
--
-- No weapon class is hooked directly: every frame the script reads the character's WeaponHandling,
-- identifies the weapon by its type name (app.cHunterWpXXHandling) and auto-detects the fields it needs.
-- =============================================
local VERSION = "1.1.0"
log.info("[HapticPack] Loading v" .. VERSION)

local Language = require("core.language")
local Menu = require("core.menu")
local imgui = Menu.imgui

local CFG = {
    RELEASE_FRAMES  = 3,     -- consecutive frames without a charge => counts as released
    PRESS_THRESHOLD = 0.25,  -- trigger pulled past this amount counts as held

    -- GREAT SWORD: charged with face buttons (Triangle/Circle), not the trigger
    gs = {
        name = "Great Sword", trigger = "R", triggerEnabled = true,
        sustainByTrigger = false,          -- charged without the trigger => do not use the trigger to keep the charge state
        contField = "_ChargeContinue",     -- the game's charge flag
        chargeTrigger = false,             -- keep the R2 guard force while charging, unchanged
        idleTrigger = { 0.8, 0.0, 0.0, 0.2, 1.0 },   -- R2 guard: resistance in the first 20% of the pull
        holdTrigger = { 1.0, 0.0, 0.0, 1.0, 1.0 },
        holdHaptic = false, holdHapticEvery = 0.0,
        levelPulse = false, pulseFreq = 0.1, pulseTime = 0.055,
        notchStyle = "pulse", notchGap = 0.0, notchHaptics = 1, notchRumble = 0.0, notchRumbleTime = 0.0,
        levelSource = "auto",
        -- swing (charge release): 5 haptic pulses + motor 1.5 over 0.4s
        rumbleBase = 1.5, rumbleStep = 0.0, rumbleTime = 0.4,
        hapticBase = 5, hapticStep = 0.0, hapticGap = 0.04,
        minCharge = 0.0, minLevel = 1,     -- only counts as a swing after at least a level 1 charge
        fallbackLevelTime = 0.8, maxLevel = 3,
    },

    -- LONG SWORD (values kept from the original LS adaptive-trigger script)
    ls = {
        name = "Long Sword", module = true, trigger = "R",
        iaiTrigger   = { 1.0, 0.0, 0.2, 0.8, 0.1 },   -- Iai (sheathing): smooth resistance 20%..80%
        kijinTrigger = { 1.0, 0.0, 0.0, 1.0, 1.0 },   -- spirit charge hold
        pulseTrigger = { 1.0, 0.1, 0.0, 1.0, 1.0 },   -- spirit level-up: trigger hit
        pulseTime = 0.055, lvCooldown = 0.5, kijinTimeout = 0.1,
        holdFromStart = false,     -- false = like the original LS script: the trigger only stiffens after the first level-up
        holdHaptic = true, holdHapticEvery = 0.04,
        -- true = like the original LS script: vibrate inside the game's spirit charge update (every game tick, smoothest)
        --        and always use the game's latest vibration pattern while charging
        hapticInHook = true,
        -- SPIRIT BLADE (R2): every slash has a sword-swing feel
        --  * R2: short impact (stiff trigger + vibration) right on the press => feels like the blade cutting in
        --  * body: rumble follows a "swoosh" curve (up then down) instead of one lump, haptic pulse at the peak of the slash
        --  * combo I -> II -> III -> Roundslash gets stronger; Roundslash adds a click + a heavy hit
        --  * the higher the Spirit gauge (white/yellow/red), the stronger (if the Spirit level field is found)
        spiritEnabled = true,
        spiritBase = 0.55, spiritStep = 0.15,      -- strength of slash 1, extra per combo hit
        spiritSwingTime = 0.22,                    -- length of one "swoosh"
        spiritImpact = 0.06, spiritImpactFreq = 0.2,
        spiritHaptics = 1, spiritComboWindow = 1.3,
        roundslashRumble = 1.3, roundslashHaptics = 4,
        spiritLevelBonus = 0.12,                   -- bonus per Spirit level
    },

    hammer = {
        name = "Hammer", trigger = "R", triggerEnabled = true,
        -- CHARGE HOLD = exactly like the Long Sword spirit charge on R2:
        --   trigger: one fixed resistance command when the charge starts (no ramp, not re-sent)
        --   body: replay the game's haptic preset EVERY FRAME while holding
        holdTrigger = { 1.0, 0.0, 0.0, 1.0, 1.0 },   -- LS KIJIN_CHARGE
        holdHaptic = true, holdHapticEvery = 0.0,     -- every frame (the tuned feel)
        -- trigger pulse on level-up (LS spirit-charge style)
        levelPulse = true, pulseFreq = 0.1, pulseTime = 0.055,
        -- LEVEL CLICK: the trigger lets go a little then hits a wall (a latch feel), plus a clear body rumble
        notchStyle = "detent",     -- "pulse" = like LS | "detent" = release then hit | "both"
        notchGap = 0.045,          -- how long the trigger stays loose before hitting again
        notchHaptics = 2,          -- haptic pulses on level-up
        notchRumble = 0.45, notchRumbleTime = 0.08,    -- reduced (was 0.7)
        levelSource = "auto",      -- "auto" | "field" | "sound" (game level-up vibration event, like LS) | "time"
        -- hammer slam: body rumble by charge level
        rumbleBase = 0.4, rumbleStep = 0.25, rumbleTime = 0.3,     -- reduced (was 0.6 / 0.4 / 0.35)
        hapticBase = 1, hapticStep = 1, hapticGap = 0.05,          -- reduced (was 2 / 2)
        minCharge = 0.25,          -- shorter charge => not a charged attack
        fallbackLevelTime = 0.6,   -- no charge level field: every 0.6s held = 1 level
        maxLevel = 3,
    },
    bow = {
        name = "Bow", trigger = "R", triggerEnabled = true,
        holdTrigger = { 1.0, 0.0, 0.0, 1.0, 1.0 },
        holdHaptic = true, holdHapticEvery = 0.0,     -- every frame (the tuned feel)
        levelPulse = true, pulseFreq = 0.1, pulseTime = 0.055,
        notchStyle = "pulse", notchGap = 0.0, notchHaptics = 1,
        notchRumble = 0.0, notchRumbleTime = 0.0,
        levelSource = "auto",
        -- arrow release: short rumble, lighter than the hammer
        rumbleBase = 0.25, rumbleStep = 0.15, rumbleTime = 0.12,
        hapticBase = 1, hapticStep = 0.5, hapticGap = 0.05,
        minCharge = 0.10,
        fallbackLevelTime = 0.45,
        maxLevel = 4,
    },

    -- SWITCH AXE: R2 = morph. No charging, the feel is event based.
    sa = {
        name = "Switch Axe", module = true, trigger = "R",
        morphNotch = true,          -- R2 trigger click + body "clack" on morph
        morphFromTrigger = true,    -- detect morph from R2 presses (fallback when there is no mode field)
        morphRumble = 0.8, morphHaptics = 2,
        dischargeRumbleMin = 0.2, dischargeRumbleMax = 0.9, dischargeRamp = 2.5, dischargeBeat = 0.15,
        finisherRumble = 1.3, finisherTime = 0.4, finisherHaptics = 6,
        reloadHaptics = 3,          -- switch gauge reload (gauge jumps up)
        morphOn = true, reloadOn = true, dischargeOn = true,   -- toggle each effect
        morphStable = 0.3,          -- the new mode must hold for >= 0.3s to count as a morph (filters noise while attacking)
        dischargeHold = 0.35,       -- Discharge must last >= 0.35s before it starts rumbling
    },

    -- CHARGE BLADE: guard trigger (R2 by default, some guides say L2 - change it in the menu).
    cb = {
        name = "Charge Blade", module = true, trigger = "R",
        guardTrigger = true, guardHold = 0.12,          -- trigger must be held over 0.12s to count as guarding (avoids R2+O morphs)
        guardResist = { 0.75, 0.0, 0.0, 1.0, 0.8 },
        guardHitRumble = 1.0, guardHitHaptics = 2,       -- guard hit / Guard Point: trigger click + rumble
        guardRaise = { 0.9, 0.4, 0.13 }, guardBrace = 0.1,
        phialTick = 0.35, phialGap = 0.07,               -- each phial loaded: one pulse
        dischargeBase = 0.5, dischargePerPhial = 0.25,   -- phial discharge (AED/SAED): stronger with more phials used
        swordChargedHaptics = 2,                         -- sword enters the red charged state
        shieldRumble = 0.9, shieldHaptics = 3,           -- shield charged
        savageBuzz = 0.18,                               -- Savage Axe spinning: continuous grinding buzz (0 = off)
    },

    -- ===== Weapons that use the shared "event" engine =====
    -- events: { key = tracked field, on = "up"/"down"/"enter"/"leave"/"active", rumble, perUnit, haptics, hapticsPerUnit, time, notch, beat, exitRumble, exitHaptics }
    sns = {
        name = "Sword & Shield", module = true, generic = true, trigger = "R",
        -- SHIELD: the wall sits at the START of the trigger pull (push past it to raise the shield),
        -- no waiting for a held trigger before adding force (by then the trigger is already fully pressed and feels light)
        -- no wall at rest; hold R2 (guard) for over 0.12s to get a little force
        guardTrigger = true, guardHold = 0.12,
        guardResist = { 0.6, 0.0, 0.0, 1.0, 0.6 },
        guardHitRumble = 0.8, guardHitHaptics = 2, impactTime = 0.06, impactFreq = 0.18,
        guardRaise = { 0.75, 0.5, 0.10 }, guardBrace = 0.08,   -- small shield: crisp "thud" when raised
        events = {
            { key = "charge", label = "Charge (Charged Chop)", on = "active", rumble = 0.1, beat = 0.06,
              exitRumble = 1.0, exitHaptics = 3, exitTime = 0.25 },
        },
    },
    gl = {
        name = "Gunlance", module = true, generic = true, trigger = "R",
        -- big shield: thicker, deeper wall, heavier and longer impact than SnS
        guardTrigger = true, guardHold = 0.05, shieldWall = { 1.0, 0.0, 0.0, 0.3, 1.0 },
        guardResist = { 1.0, 0.0, 0.0, 0.3, 1.0 },
        guardHitRumble = 1.5, guardHitHaptics = 4, impactTime = 0.12, impactFreq = 0.3,
        guardRaise = { 1.0, 0.35, 0.16 }, guardBrace = 0.14,   -- big shield: heavy "boom" when raised
        events = {
            { key = "shell",  label = "Shelling (Full Burst = several shells)", on = "down", rumble = 0.7, perUnit = 0.25,
              haptics = 2, hapticsPerUnit = 1, time = 0.12, timePerUnit = 0.04 },
            { key = "shell",  label = "Reload", on = "up", rumble = 0.3, haptics = 2, time = 0.08, notch = true },
            { key = "stake",  label = "Wyrmstake", on = "down", rumble = 1.2, haptics = 4, time = 0.3 },
            { key = "wyvern", label = "Wyvern's Fire", on = "down", rumble = 1.8, haptics = 8, time = 0.8, notch = true },
        },
    },
    -- ===== BOWGUNS (L2 aim - untouched, R2 fire) =====
    -- Every ammo type has its own "trigger" and "recoil" (see GUN_PROFILES below).
    lbg = {
        name = "Light Bowgun", module = true, gunModule = true, trigger = "R",
        triggerOff = true,        -- bowguns: vibration only, R2 untouched (untick in the menu for a pistol click)
        triggerKick = false,      -- false = NO trigger kick / lock / click when firing (less finger fatigue), only the pistol click
        heavy = false, shotGap = 0.05,
        rapidScaleForce = 0.6,    -- Rapid Fire: light & short trigger for fast pulls
        rapidScaleKick = 0.75,    -- Rapid Fire: lighter recoil per shot (bursts still feel dense)
        slackEnabled = false,
        specialRumble = 0.5, specialDelay = 1.1, specialBlast = 1.2,    -- Wyvernblast / Adhesive: place -> delayed blast
        focusRumble = 1.3, focusHaptics = 4,                            -- Eagle Strike
    },
    hbg = {
        name = "Heavy Bowgun", module = true, gunModule = true, trigger = "R",
        triggerOff = true, triggerKick = false,
        heavy = true, shotGap = 0.08,
        slackEnabled = false,
        -- Ignition: each HBG model has its own style, pick it in the menu
        --  heart   = Wyvernheart: hold R2 for automatic fire, barrel spins up (trigger vibration and body rumble build up)
        --  counter = Wyverncounter: hold R2 to charge (trigger tightens) -> release = big blast
        --  piercer = continuous piercing beam: steady trigger vibration + steady body rumble
        ignitionStyle = "heart", ignitionSpinUp = 1.5,
        specialRumble = 1.5, specialDelay = 0.0, specialBlast = 0.0,    -- Wyvernsnipe: one very heavy piercing shot
        focusRumble = 1.7, focusHaptics = 5,                            -- Focus Blast: Wyvern Howl
    },

    hh = {
        name = "Hunting Horn", module = true, generic = true, trigger = "R",
        guardTrigger = false, guardHold = 0.12, guardResist = { 0.0, 0.0, 0.0, 1.0, 0.0 },
        guardHitRumble = 0.0, guardHitHaptics = 0,
        -- R2 = Perform, R2 + X = Echo Bubble.
        -- Trigger like a piano key: a single click zone at 30%..55% of the pull, then it lets go => a "tick", not heavy for the whole pull
        idleTrigger = { 0.55, 0.0, 0.30, 0.55, 1.0 },
        -- performing: R2 pulses lightly on each beat
        beatTrigger = { 0.5, 0.12, 0.0, 1.0, 0.5 }, beatTriggerTime = 0.06,
        events = {
            { key = "note",    label = "Each note", on = "up", rumble = 0.25, haptics = 1, time = 0.05 },
            { key = "perform", label = "Performing", on = "active", rumble = 0.15, beat = 0.25, beatTrigger = true,
              exitRumble = 0.6, exitHaptics = 2, exitTime = 0.15 },
            { key = "bubble",  label = "Echo Bubble placed", on = "up", rumble = 0.7, haptics = 2, time = 0.15, notch = true },
        },
    },

    -- ===== DUAL BLADES: R2 = toggle Demon Mode =====
    -- R2 at rest: free. Each Demon Mode toggle: the trigger "ticks" like a switch.
    -- In Demon Mode: light "lub-dub" heartbeat (stamina is draining).
    -- Archdemon: one "boom" on entering, one tick when it ends.
    db = {
        name = "Dual Blades", module = true, generic = true, trigger = "R",
        guardTrigger = false, guardHold = 0.12, guardResist = { 0.0, 0.0, 0.0, 1.0, 0.0 },
        guardHitRumble = 0.0, guardHitHaptics = 0,
        events = {
            { key = "demon", label = "Demon Mode", on = "active", rumble = 0, beat = 0.85, heart = 0.3,
              enterRumble = 0.8, enterHaptics = 2, enterTime = 0.18, notchEnter = true,
              exitRumble = 0.35, exitHaptics = 0, exitTime = 0.1, notchExit = true,
              edgeFallback = true, cool = 0.3 },
            { key = "arch", label = "Archdemon", on = "active", unless = "demon", rumble = 0,
              enterRumble = 0.55, enterHaptics = 2, enterTime = 0.14,
              exitRumble = 0.25, exitTime = 0.08, cool = 0.5 },
        },
    },

    -- ===== LANCE: the biggest shield in the game, hold R2 = guard =====
    -- Guard: same as the Gunlance: a wall at the start of R2, heavy guard-hit impact.
    -- Power Guard: the shield "locks" (trigger tick + straining body rumble), guard hits are heavier.
    -- Lance Charge: charging run => alternating left/right footsteps, ends with a heavy hit.
    lance = {
        name = "Lance", module = true, generic = true, trigger = "R",
        guardTrigger = true, guardHold = 0.05, shieldWall = { 1.0, 0.0, 0.0, 0.3, 1.0 },
        guardResist = { 1.0, 0.0, 0.0, 0.3, 1.0 },
        guardHitRumble = 1.5, guardHitHaptics = 4, impactTime = 0.12, impactFreq = 0.3,
        guardRaise = { 1.0, 0.35, 0.16 },
        guardBrace = 0, guardLower = 0, quietGuard = true,   -- rumble controllers: only the shield RAISE is felt, nothing while holding
        soundGuardHit = true,                          -- rumble controllers (Vader): detect guard hits from sound events
        powerGuardKey = "powerGuard", powerGuardHitMul = 1.3,
        events = {
            { key = "powerGuard", label = "Power Guard", on = "active", rumble = 0,
              enterRumble = 1.0, enterHaptics = 3, enterTime = 0.16, notchEnter = true,
              exitRumble = 0.4, exitTime = 0.1, cool = 0.3 },
            { key = "charge", label = "Lance Charge (charging run)", on = "active", rumble = 0.1, beat = 0.28, step = 0.35,
              exitRumble = 0.9, exitHaptics = 3, exitTime = 0.2, cool = 0.3 },
        },
    },

    -- ===== INSECT GLAIVE: R2 is a modifier (Kinsect, vault) => trigger always free =====
    -- Each extract has its own "signature": red = sharp tick (light motor), white = soft flick, orange = heavy thud (heavy motor).
    -- All 3 extracts (Triple Up): trigger click + one big boom. Red extract expired: one light tick (red moveset lost).
    -- Vault: one launch hit, one tick on landing. Charge (red extract): rumble ramps up, release = one heavy hit.
    ig = {
        name = "Insect Glaive", module = true, generic = true, trigger = "R",
        guardTrigger = false, guardHold = 0.12, guardResist = { 0.0, 0.0, 0.0, 1.0, 0.0 },
        guardHitRumble = 0.0, guardHitHaptics = 0,
        events = {
            { key = "red",    label = "Red extract gained",   on = "up", big = true, rumble = 0.6,  haptics = 1, time = 0.1,  role = "light", cool = 0.4 },
            { key = "white",  label = "White extract gained", on = "up", big = true, rumble = 0.35, haptics = 0, time = 0.06, role = "light", cool = 0.4 },
            { key = "orange", label = "Orange extract gained",  on = "up", big = true, rumble = 0.6,  haptics = 0, time = 0.14, role = "heavy", cool = 0.4 },
            { key = "red", allOf = { "red", "white", "orange" }, label = "TRIPLE UP (all 3 extracts)", on = "enter",
              rumble = 1.1, haptics = 4, time = 0.3, notch = true },
            { key = "red",    label = "Red extract expired",   on = "leave", rumble = 0.3, haptics = 0, time = 0.08, role = "heavy" },
            { key = "air",    label = "Vault / airborne", on = "active", rumble = 0,
              enterRumble = 0.6, enterHaptics = 1, enterTime = 0.12,
              exitRumble = 0.35, exitHaptics = 0, exitTime = 0.08, cool = 0.4 },
            { key = "charge", label = "Charge (red extract)", on = "active", rumble = 0, ramp = { 0.08, 0.45, 1.2 },
              exitRumble = 1.0, exitHaptics = 3, exitTime = 0.25, cool = 0.3 },
        },
    },
}

-- Tracked fields per weapon: auto-detected by name, can be changed in the menu
-- type: flag = on/off (value > 0), counter = counts up/down, change = value changes
local RULES = {
    sa = {
        { key = "mode",      label = "Sword/Axe mode",     type = "change",  pats = { { "sword", "mode" }, { "axe", "mode" }, { "weapon", "mode" }, { "mode" }, { "style" } } },
        { key = "gauge",     label = "Switch gauge",      type = "counter",
          exclude = { "timer", "time", "recover", "auto", "interval", "wait", "speed", "rate", "cool" }, pats = { { "switch", "gauge" }, { "bin", "gauge" }, { "bottle", "gauge" }, { "gauge" } } },
        { key = "discharge", label = "Element/Zero Sum Discharge", type = "flag", pats = { { "discharge", "active" }, { "discharge", "timer" }, { "burst", "active" } } },
    },
    cb = {
        { key = "phial",  label = "Phials",            type = "counter", pats = { { "bottle", "num" }, { "bottle", "count" }, { "phial" }, { "bottle" } } },
        { key = "sword",  label = "Sword charged (red)",    type = "flag",    pats = { { "sword", "charge" }, { "sword", "energy" }, { "sword", "boost" }, { "sword", "enhance" } } },
        { key = "shield", label = "Shield charged",  type = "flag",    pats = { { "shield", "timer" }, { "shield", "enhance" }, { "shield", "charge" }, { "shield" } } },
        { key = "axe",    label = "Savage Axe",       type = "flag",    pats = { { "axe", "enhance" }, { "axe", "timer" }, { "axe", "boost" }, { "saw" } } },
    },
    ls = {
        { key = "spiritLv", label = "Spirit level (white/yellow/red)", type = "change",
          pats = { { "kijin", "lv" }, { "kijin", "level" }, { "renki", "lv" }, { "spirit", "lv" }, { "spirit", "level" } } },
    },
    sns = {
        { key = "charge",  label = "Charge",             type = "flag",    pats = { { "charge", "timer" }, { "charge", "time" }, { "charge" } } },
    },
    gl = {
        { key = "shell",   label = "Shells",           type = "counter", pats = { { "bullet", "num" }, { "shell", "num" }, { "bullet" }, { "shell" } } },
        { key = "stake",   label = "Wyrmstake",        type = "counter", pats = { { "stake" }, { "pile" }, { "kui" } } },
        { key = "wyvern",  label = "Wyvern's Fire gauge", type = "counter", pats = { { "ryugeki" }, { "dragon", "fire" }, { "wyvern" }, { "fire", "gauge" } } },
    },
    lbg = {
        { key = "ammo",     label = "Ammo in magazine",    type = "counter", pats = { { "loaded" }, { "ammo", "num" }, { "bullet", "num" }, { "magazine" }, { "bullet", "count" } } },
        { key = "ammoType", label = "Selected ammo type", type = "change", allowType = true,
          pats = { { "bullet", "type" }, { "ammo", "type" }, { "shell", "type" }, { "bullet", "kind" }, { "ammo", "kind" }, { "select", "bullet" }, { "current", "bullet" }, { "bullet", "id" } } },
        { key = "mode",     label = "Rapid Fire mode",  type = "flag",    allowType = true, pats = { { "rapid" }, { "rendan" }, { "fullauto" }, { "burst", "mode" } } },
        { key = "special",  label = "Special ammo (Wyvernblast/Adhesive)", type = "counter", pats = { { "special", "num" }, { "special", "gauge" }, { "wyvernblast" }, { "special" } } },
        { key = "focus",    label = "Focus Blast (Eagle Strike)", type = "counter", pats = { { "eagle" }, { "focus", "num" }, { "focus", "blast" } } },
    },
    hbg = {
        { key = "ammo",     label = "Ammo in magazine",    type = "counter", pats = { { "loaded" }, { "ammo", "num" }, { "bullet", "num" }, { "magazine" }, { "bullet", "count" } } },
        { key = "ammoType", label = "Selected ammo type", type = "change", allowType = true,
          pats = { { "bullet", "type" }, { "ammo", "type" }, { "shell", "type" }, { "bullet", "kind" }, { "ammo", "kind" }, { "select", "bullet" }, { "current", "bullet" }, { "bullet", "id" } } },
        { key = "mode",     label = "Ignition mode",    type = "flag",    allowType = true, pats = { { "ignition" }, { "wyvernheart" }, { "gatling" }, { "ex", "mode" } } },
        { key = "special",  label = "Special ammo (Wyvernsnipe)", type = "counter", pats = { { "snipe" }, { "special", "num" }, { "special", "gauge" }, { "special" } } },
        { key = "focus",    label = "Focus Blast (Wyvern Howl)", type = "counter", pats = { { "howl" }, { "focus", "num" }, { "focus", "blast" } } },
    },
    hh = {
        { key = "note",    label = "Notes",         type = "counter", pats = { { "note", "num" }, { "note", "count" }, { "onpu" }, { "note" }, { "melody", "stock" } } },
        { key = "perform", label = "Performance",         type = "flag",    pats = { { "perform" }, { "ensou" }, { "recital" }, { "play", "timer" } } },
        { key = "bubble",  label = "Echo Bubble",      type = "counter", pats = { { "bubble" }, { "echo" }, { "hibiki" } } },
    },
    -- Dual Blades: "Kijin" = Demon Mode, "Kyouka" = Archdemon (internal Japanese names)
    db = {
        { key = "demon", label = "Demon Mode", type = "flag",
          exclude = { "gauge", "kyouka", "kyoka", "arch", "count", "rate", "point" },
          pats = { { "is", "kijin" }, { "kijin", "mode" }, { "demon", "mode" }, { "kijin", "flag" }, { "demon" }, { "kijin" } } },
        { key = "arch",  label = "Archdemon / Demon gauge", type = "flag",
          pats = { { "kyouka" }, { "kyoka" }, { "arch" }, { "kijin", "gauge" }, { "demon", "gauge" }, { "gauge" } } },
    },
    lance = {
        { key = "powerGuard", label = "Power Guard", type = "flag",
          pats = { { "power", "guard" }, { "strong", "guard" }, { "guard", "power" } } },
        { key = "charge", label = "Lance Charge", type = "flag", exclude = { "counter" },
          pats = { { "charge", "run" }, { "rush" }, { "dash", "attack" }, { "charge", "timer" }, { "charge" } } },
    },
    ig = {
        { key = "red",    label = "Red extract",   type = "flag", pats = { { "red", "extract" }, { "red", "essence" }, { "red", "time" }, { "_red" } } },
        { key = "white",  label = "White extract", type = "flag", pats = { { "white", "extract" }, { "white", "essence" }, { "white", "time" }, { "_white" } } },
        { key = "orange", label = "Orange extract",  type = "flag", pats = { { "orange", "extract" }, { "orange", "essence" }, { "orange", "time" }, { "_orange" }, { "yellow", "extract" } } },
        { key = "air",    label = "Airborne", type = "flag", exclude = { "count", "num" },
          pats = { { "is", "air" }, { "aerial" }, { "vault" }, { "_air" } } },
        { key = "charge", label = "Charge",      type = "flag", pats = { { "charge", "timer" }, { "charge", "time" }, { "charge" } } },
    },
}

local KIND_BY_TYPE = {
    { pat = "Wp00", kind = "gs" },
    { pat = "Wp01", kind = "sns" },
    { pat = "Wp05", kind = "hh" },
    { pat = "Wp07", kind = "gl" },
    { pat = "Wp12", kind = "hbg" },
    { pat = "Wp13", kind = "lbg" },
    { pat = "Wp03", kind = "ls" },
    { pat = "Wp04", kind = "hammer" },
    { pat = "Wp11", kind = "bow" },
    { pat = "Wp08", kind = "sa" },
    { pat = "Wp09", kind = "cb" },
    { pat = "Wp02", kind = "db" },
    { pat = "Wp06", kind = "lance" },
    { pat = "Wp10", kind = "ig" },
}
local KIND_LABEL = { lbg = "Light Bowgun", hbg = "Heavy Bowgun", sns = "Sword & Shield", hh = "Hunting Horn", gl = "Gunlance", gs = "Great Sword", ls = "Long Sword", hammer = "Hammer", bow = "Bow", sa = "Switch Axe", cb = "Charge Blade",
    db = "Dual Blades", lance = "Lance", ig = "Insect Glaive" }

-- =============================================
-- STATE
-- =============================================
local S = {
    chara = nil, lastCharaFetch = -10.0,
    wh = nil, typeName = "", kind = nil, kindOverride = "auto",
    fields = {}, levelIdx = 1, timerIdx = 1, fieldNames = { "(not used)" },

    charging = false, chargeStart = 0.0, level = 0, maxLevel = 0,
    lastLevel = 0, lastTimer = 0.0, still = 0, lastLevelUpAt = 0.0,

    pulseUntil = 0.0, ramp = 0.0, lastHoldRumble = 0.0, lastBeat = 0.0,
    notchStart = -10.0, notchEnd = -10.0,
    soundSeen = {}, soundEvents = 0, levelSrcUsed = "",
    rumbleUntil = 0.0, rumbleStr = 0.0, lastRumbleSend = 0.0,
    hapticsLeft = 0, nextHapticAt = 0.0,

    sentKey = nil, sentSide = nil,
    ev = "", releases = 0,
    lt = 0.0, rt = 0.0,
}

-- =============================================
-- ACCESS
-- =============================================
local uptime = sdk.find_type_definition("via.Application"):get_method("get_UpTimeSecond")
local function now_s() return uptime:call(nil) end

local padManager = nil
local padCache, padCacheFrame, frameNo = nil, -1, 0
-- Cache method definitions: obj:call("name") looks the name up every time (very costly every frame / tick)
local GETPAD_M = nil
local PAD_TD = nil
local PADM = {}            -- [signature] = method definition | false
local function pad_method(sig)
    local m = PADM[sig]
    if m == nil then
        PAD_TD = PAD_TD or sdk.find_type_definition("ace.cPadInfo")
        m = PAD_TD and PAD_TD:get_method(sig) or false
        PADM[sig] = m
    end
    return m
end
local function get_pad()
    if padCacheFrame == frameNo then return padCache end
    if not padManager then padManager = sdk.get_managed_singleton("ace.PadManager") end
    if padManager then
        if GETPAD_M == nil then
            local td = sdk.find_type_definition("ace.PadManager")
            GETPAD_M = td and td:get_method("getPadInfo") or false
        end
        if GETPAD_M then
            local ok, r = pcall(GETPAD_M.call, GETPAD_M, padManager, 0)
            padCache = ok and r or nil
        else
            padCache = padManager:call("getPadInfo", 0)
        end
    else
        padCache = nil
    end
    padCacheFrame = frameNo
    return padCache
end

local function get_chara(now)
    if S.chara and now - S.lastCharaFetch < 2.0 then return S.chara end
    S.lastCharaFetch = now
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    local mp = pm and pm:call("getMasterPlayer")
    S.chara = mp and mp:call("get_Character") or nil
    S.myGoAddr = nil
    S.charaAddr = nil
    if S.chara then
        local okc, ca = pcall(S.chara.get_address, S.chara)
        if okc then S.charaAddr = ca end
        local ok, go = pcall(S.chara.call, S.chara, "get_GameObject")
        if ok and go then
            local ok2, addr = pcall(go.get_address, go)
            if ok2 then S.myGoAddr = addr end
        end
    end
    return S.chara
end

local function read_trigger(pad, getter)
    local m = pad_method(getter)
    local ok, v
    if m then ok, v = pcall(m.call, m, pad) else ok, v = pcall(pad.call, pad, getter) end
    if not ok or type(v) ~= "number" then return 0.0 end
    if v > 1.0 then v = v / 255.0 end
    return v
end

-- =============================================
-- TRIGGERS & RUMBLE (same approach that worked in the GS version)
-- =============================================
local SIG_G   = "setAdaptiveTriggerFeedback(System.Single, System.Single, System.Single, System.Single, System.Single, via.hid.AdaptiveTriggerMotor)"
local SIG_VIB = "addVibrationRequest(System.Single, ace.cPadInfo.VIBRATION_MOTOR_TYPE)"

local call_status = {}
local sigKey = {}
local function pad_call(pad, sig, ...)
    local m = pad_method(sig)
    local ok, err
    if m then ok, err = pcall(m.call, m, pad, ...) else ok, err = pcall(pad.call, pad, sig, ...) end
    local key = sigKey[sig]
    if not key then key = sig:match("^[%w_]+") or sig; sigKey[sig] = key end
    if ok then
        if call_status[key] ~= "OK" then call_status[key] = "OK" end
    else
        call_status[key] = Language.translate("ERROR: ") .. tostring(err)
    end
end

local function read_enum(type_name)
    local out = {}
    local td = sdk.find_type_definition(type_name)
    if not td then return out end
    for _, f in ipairs(td:get_fields()) do
        if f:is_static() then
            local ok, v = pcall(f.get_data, f, nil)
            if ok and type(v) == "number" then out[f:get_name()] = v end
        end
    end
    return out
end

local TRIGGER_MOTOR = nil
local function motor_for(side)
    TRIGGER_MOTOR = TRIGGER_MOTOR or read_enum("via.hid.AdaptiveTriggerMotor")
    for name, v in pairs(TRIGGER_MOTOR) do
        local n = name:lower()
        if side == "L" and n:find("left") then return v end
        if side == "R" and n:find("right") then return v end
    end
    return side == "L" and 0 or 1
end

local function send_trigger(side, v)
    local pad = get_pad()
    if pad then pad_call(pad, SIG_G, v[1], v[2], v[3], v[4], v[5], motor_for(side)) end
end

local FREE = { 0.0, 0.0, 0.0, 1.0, 0.0 }

-- =============================================
-- RUMBLE LAYER (supports both DualSense and rumble controllers such as the Flydigi Vader 5 / Xbox)
--  Motor roles: heavy = heavy motor (low frequency), light = light motor (high frequency),
--                 trigL / trigR = trigger motors (the Vader 5 has them), off = disabled
-- =============================================
S.out = "dualsense"          -- "dualsense" | "rumble"
S.motorRoles = {}            -- [motor name] = role (picked by the player, saved)
-- Defaults = the values tuned on a Flydigi Vader 5 Pro
local FLYDIGI_DEFAULTS = {
    rumbleGain = 2.5, trigEmuGain = 1.6, hapticRumble = 1.5, keepPreset = false,
    trigMotorsWork = true, sideBleed = 0.814, trigTension = true,
    gameVibOn = true, gameVibGain = 4.0, soundAll = true,
}
S.trigEmuGain = FLYDIGI_DEFAULTS.trigEmuGain    -- emulated trigger rumble strength (rumble mode)
S.hapticRumble = FLYDIGI_DEFAULTS.hapticRumble  -- haptic -> rumble: strength
S.rumbleGain = FLYDIGI_DEFAULTS.rumbleGain      -- rumble mode: multiplier for ALL rumble
S.keepPreset = false         -- rumble mode: also play the game's haptic preset
S.trigMotorsWork = FLYDIGI_DEFAULTS.trigMotorsWork   -- Vader 5 Pro: the game's LTRIGGER/RTRIGGER motors do respond
S.sideBleed = FLYDIGI_DEFAULTS.sideBleed            -- trigger rumble: how much bleeds into the other motor for a fuller feel (0 = fully separate left/right)
S.trigTension = true         -- light "tension" rumble while pressing inside a resistance zone

local ROLES = { "heavy", "light", "trigL", "trigR", "off" }
local ROLE_LABEL = { heavy = "Heavy (left grip)", light = "Light (right grip)", trigL = "Left trigger (L2/LT)", trigR = "Right trigger (R2/RT)", off = "Off" }

local function guess_role(u)
    if u:find("TRIG") then
        if u:find("LEFT") or u:find("^L") or u:find("_L") or u:find("LT") then return "trigL" end
        if u:find("RIGHT") or u:find("^R") or u:find("_R") or u:find("RT") then return "trigR" end
        return nil
    end
    if u:find("LEFT") or u:find("LOW") or u:find("LARGE") or u:find("STRONG") or u:find("HEAVY") then return "heavy" end
    if u:find("RIGHT") or u:find("HIGH") or u:find("SMALL") or u:find("WEAK") or u:find("LIGHT") then return "light" end
    return nil
end

local VIB_MOTORS = nil
local function load_vib_motors()
    if VIB_MOTORS then return VIB_MOTORS end
    VIB_MOTORS = {}
    for n, v in pairs(read_enum("ace.cPadInfo.VIBRATION_MOTOR_TYPE")) do
        local u = n:upper()
        if not (u:find("MAX") or u:find("NUM") or u:find("INVALID") or u:find("NONE")) then
            VIB_MOTORS[#VIB_MOTORS + 1] = { name = n, value = v, guess = guess_role(u), isTrig = u:find("TRIG") ~= nil }
        end
    end
    table.sort(VIB_MOTORS, function(a, b) return a.value < b.value end)
    -- body motors not guessed: alternate heavy / light; trigger motors not guessed: alternate left / right
    local nb, nt = 0, 0
    for _, m in ipairs(VIB_MOTORS) do
        if not m.guess then
            if m.isTrig then nt = nt + 1; m.guess = (nt % 2 == 1) and "trigL" or "trigR"
            else nb = nb + 1; m.guess = (nb % 2 == 1) and "heavy" or "light" end
        end
    end
    for _, m in ipairs(VIB_MOTORS) do
        m.role = S.motorRoles[m.name] or m.guess
        m.enabled = m.role ~= "off"
    end
    return VIB_MOTORS
end

local roleCount = {}
local function count_roles()
    for k in pairs(roleCount) do roleCount[k] = 0 end
    for _, m in ipairs(load_vib_motors()) do
        if m.role ~= "off" then roleCount[m.role] = (roleCount[m.role] or 0) + 1 end
    end
end

-- Body effects go through the motor path (addVibrationRequest) in rumble mode, and also for a DualSense on
-- Bluetooth when the MHWHapticBT plugin is active: the plugin turns those requests into real haptics.
S.btBridge = false
S.btHitGain = 0.55        -- Bluetooth DualSense: hit-wave strength (Vader uses gameVibGain x4)
S.btHapticPulse = 0.3     -- Bluetooth DualSense: strength of a replayed "haptic" beat (Vader uses 1.5)
S.btGameHaptics = false   -- Bluetooth DualSense: also turn every game haptic preset into a hit (off: too busy)
local function body_via_motors() return S.out == "rumble" or S.btBridge == true end

-- Send rumble to motors by role. "body" = heavy + light.
local function out_rumble(strength, role)
    if strength <= 0 then return end
    local pad = get_pad()
    if not pad then return end
    local motors = load_vib_motors()
    if roleCount.heavy == nil then count_roles() end
    -- Trigger motors do not respond to the game (XInput only has 2 body rumble channels):
    --   left trigger -> left grip motor (heavy, reduced), right trigger -> right grip motor (light)
    --   => left/right is still distinguishable on the controller
    if role == "trigL" or role == "trigR" then
        if not S.trigMotorsWork or (roleCount[role] or 0) == 0 then
            -- right trigger: light (right) motor main + heavy motor padding; left trigger: the opposite
            local main, other = "light", "heavy"
            local mainK, otherK = 1.0, S.sideBleed
            if role == "trigL" then main, other, mainK = "heavy", "light", 0.8 end
            out_rumble(math.min(2.0, strength * mainK), main)
            if otherK > 0 then out_rumble(math.min(2.0, strength * otherK), other) end
            return
        end
    end
    if (role == "heavy" or role == "light") and (roleCount[role] or 0) == 0 then role = "body" end
    if S.out == "rumble" then strength = math.min(2.0, strength * S.rumbleGain) end
    S.selfMotor = true
    for _, m in ipairs(motors) do
        local r = m.role
        if r ~= "off" and (r == role or (role == "body" and (r == "heavy" or r == "light"))) then
            -- Bluetooth bridge: +8 marks the request as the mod's own (the plugin drops the game's legacy rumble)
            pad_call(pad, SIG_VIB, (S.btBridge and S.out ~= "rumble") and (strength + 8.0) or strength, m.value)
        end
    end
    S.selfMotor = false
end

local function motor_rumble(strength)
    out_rumble(strength, "body")
end

-- Short rumble pulse (keeps rumbling for a while, re-sent every 0.03s)
local pulses = {}
local function pulse(role, strength, dur, delay)
    if strength <= 0 or dur <= 0 then return end
    if #pulses >= 32 then table.remove(pulses, 1) end
    local b = os.clock() + (delay or 0)
    pulses[#pulses + 1] = { role = role, s = strength, b = b, u = b + dur, l = -1 }
end
local function process_pulses()
    local t = os.clock()
    local tm = S.testMotor
    if tm then
        if t >= tm.u then S.testMotor = nil
        else
            local pad = get_pad()
            if pad then S.selfMotor = true; pad_call(pad, SIG_VIB, (S.btBridge and S.out ~= "rumble") and 8.9 or 0.9, tm.v); S.selfMotor = false end
        end
    end
    if #pulses == 0 then return end
    for i = #pulses, 1, -1 do
        local p = pulses[i]
        if t >= p.u then
            table.remove(pulses, i)
        elseif t >= (p.b or 0) and t - p.l >= 0.03 then
            p.l = t
            out_rumble(p.s, p.role)
        end
    end
end

-- Haptic preset: capture the game's vibration pattern, preferring the one played while charging
local saved_inst, saved_preset = nil, {}
local captured, capturedCharging, self_vib = false, false, false

local TRIG_M = sdk.find_type_definition("ace.cAceAdvancedVibrationBase"):get_method("triggerVibration")
local savedInstAddr, savedPresetAddr, capClock = nil, nil, -10.0
local clock = os and os.clock or function() return 0 end

local function play_haptic()
    if body_via_motors() then
        -- rumble controllers: haptic -> one short rumble beat (light motor leads, heavy pads)
        local hr = S.btBridge and S.btHapticPulse or S.hapticRumble
        pulse("light", hr, 0.09)
        pulse("heavy", hr * 0.6, 0.08)
        if not S.keepPreset then return end
    end
    if not (saved_inst and #saved_preset > 0) then
        -- the game's pattern is not captured yet => use the motors instead so there is still feedback
        motor_rumble(0.45)
        return
    end
    self_vib = true
    local ok = pcall(TRIG_M.call, TRIG_M, saved_inst, saved_preset[1], saved_preset[2], saved_preset[3], saved_preset[4])
    self_vib = false
    if not ok then
        saved_inst, saved_preset, captured, capturedCharging = nil, {}, false, false
        savedInstAddr, savedPresetAddr = nil, nil
    end
end

-- =============================================
-- GAME VIBRATION -> MOTORS (rumble mode / Vader 5)
-- On DualSense, every vibration request from the game (hits, getting hit, explosions...) is a crisp haptic wave.
-- Over XInput the game only gives a weak rumble, so we add our own "wave" that imitates DualSense:
--   0-40ms   : both motors at full power   (sharp hit - the "transient")
--   40ms-50% : heavy motor 70%, light 40% (body)
--   50%-end  : heavy motor 35%            (fading tail)
-- Strength / length come from the game's own vibration preset (if readable), otherwise defaults.
-- =============================================
S.gameVibOn = FLYDIGI_DEFAULTS.gameVibOn
S.gameVibGain = FLYDIGI_DEFAULTS.gameVibGain
S.soundAll = FLYDIGI_DEFAULTS.soundAll
-- The heavier the weapon, the harder and longer the impact (k = force, dk = length)
local WEAPON_HIT = {
    hammer = { k = 1.7, dk = 1.5 }, gs = { k = 1.6, dk = 1.5 }, cb = { k = 1.35, dk = 1.25 },
    sa = { k = 1.35, dk = 1.25 }, gl = { k = 1.35, dk = 1.25 }, hh = { k = 1.3, dk = 1.2 },
    ls = { k = 1.1, dk = 1.0 }, sns = { k = 0.95, dk = 0.9 }, hbg = { k = 1.1, dk = 1.0 },
    lbg = { k = 0.9, dk = 0.9 }, bow = { k = 0.85, dk = 0.85 },
    db = { k = 0.85, dk = 0.7 },      -- many fast hits: short, sharp, never blending together
    lance = { k = 1.25, dk = 0.9 },   -- thrusts: strong but short
    ig = { k = 1.0, dk = 0.9 },
}
S.lastGameVib = -10.0
S.lastPresetInfo = nil
local presetInfo = {}          -- [preset address] = { s, d, dump }
local hit_wave                 -- forward declaration, defined below
S.vibSrc = { adv = 0, motor = 0, sound = 0, soundOther = 0 }   -- count game vibration sources (diagnostics)
S.gameReq = 0.0

local function analyze_preset(obj)
    local info = { s = nil, d = nil, dump = {} }
    local ok, td = pcall(obj.get_type_definition, obj)
    local depth = 0
    while ok and td and depth < 4 do
        local okf, fields = pcall(td.get_fields, td)
        if okf and fields then
            for _, f in ipairs(fields) do
                if not f:is_static() then
                    local okv, v = pcall(f.get_data, f, obj)
                    if okv and type(v) == "number" then
                        local n = f:get_name():lower()
                        if #info.dump < 14 then info.dump[#info.dump + 1] = Language.format("%s=%.3f", f:get_name(), v) end
                        if (n:find("time") or n:find("duration") or n:find("length") or n:find("sec")) and v > 0 and v < 10 then
                            info.d = math.max(info.d or 0, v)
                        elseif n:find("frame") and v > 0 and v < 600 then
                            info.d = math.max(info.d or 0, v / 60.0)
                        elseif (n:find("power") or n:find("strength") or n:find("intensity") or n:find("amplitude")
                                or n:find("gain") or n:find("scale") or n:find("level") or n:find("volume")) and v > 0 then
                            local x = v
                            if x > 1.5 and x <= 100 then x = x / 100 end
                            if x <= 2 then info.s = math.max(info.s or 0, x) end
                        end
                    end
                end
            end
        end
        td = td:get_parent_type()
        depth = depth + 1
    end
    info.s = math.max(0.25, math.min(1.5, info.s or 0.85))
    info.d = math.max(0.06, math.min(0.6, info.d or 0.14))
    return info
end

-- Dump the structure of the last game haptic preset to reframework/data/MHWilds_preset_dump.json
-- (research: does the preset carry the raw haptic waveform we could replay over Bluetooth?)
local function dump_value(out, prefix, v, depth, seen)
    if #out > 600 then return end
    local tv = type(v)
    if tv ~= "userdata" then out[#out + 1] = prefix .. " = " .. tostring(v); return end
    local okt, td = pcall(v.get_type_definition, v)
    local tname = (okt and td) and td:get_full_name() or "?"
    local okA, addr = pcall(v.get_address, v)
    local key = okA and tostring(addr) or tostring(v)
    if seen[key] then out[#out + 1] = prefix .. " : " .. tname .. " (already shown)"; return end
    seen[key] = true
    -- arrays / lists: size + first elements
    local okS, size = pcall(v.get_size, v)
    if okS and type(size) == "number" then
        out[#out + 1] = Language.format("%s : %s  [array, %d elements]", prefix, tname, size)
        local parts = {}
        for i = 0, math.min(size, 32) - 1 do
            local oke, e = pcall(v.get_element, v, i)
            if oke then
                if type(e) == "userdata" then
                    if i < 4 and depth < 3 then dump_value(out, prefix .. "[" .. i .. "]", e, depth + 1, seen) end
                else parts[#parts + 1] = tostring(e) end
            end
        end
        if #parts > 0 then out[#out + 1] = prefix .. " values: " .. table.concat(parts, ", ") end
        return
    end
    out[#out + 1] = prefix .. " : " .. tname
    if depth >= 3 or not okt or not td then return end
    local t, guard = td, 0
    while t and guard < 4 do
        local okf, fields = pcall(t.get_fields, t)
        if okf and fields then
            for _, f in ipairs(fields) do
                if not f:is_static() then
                    local okv, fv = pcall(f.get_data, f, v)
                    local ft = f:get_type() and f:get_type():get_full_name() or "?"
                    if okv then
                        if type(fv) == "userdata" then dump_value(out, prefix .. "." .. f:get_name(), fv, depth + 1, seen)
                        else out[#out + 1] = Language.format("%s.%s (%s) = %s", prefix, f:get_name(), ft, tostring(fv)) end
                    else
                        out[#out + 1] = Language.format("%s.%s (%s) = <unreadable>", prefix, f:get_name(), ft)
                    end
                end
            end
        end
        t = t:get_parent_type(); guard = guard + 1
    end
end

local function dump_last_preset()
    local out = {}
    out[#out + 1] = "captured: " .. tostring(captured) .. "  (hit something in game first, then press Dump)"
    out[#out + 1] = "arg3 (id/flags) = " .. tostring(saved_preset[1]) .. "   arg6 = " .. tostring(saved_preset[4])
    if saved_inst then dump_value(out, "instance", saved_inst, 2, {}) end
    if saved_preset[2] then dump_value(out, "preset", saved_preset[2], 0, {}) end
    if saved_preset[3] then dump_value(out, "requestData", saved_preset[3], 1, {}) end
    local ok, err = pcall(json.dump_file, "MHWilds_preset_dump.json", out)
    log.info("[HapticPack] preset dump: " .. #out .. " lines -> reframework/data/MHWilds_preset_dump.json " .. (ok and "" or tostring(err)))
    S.ev = Language.format("Preset dump: %d lines", #out)
end

-- =============================================
-- HAPTIC CATALOG (research): which audio-haptic resource does each game vibration play?
-- Goal: replay the game's real haptic waveforms over Bluetooth. Step 1 = learn resource paths + the API
-- of via.audiorender.VibrationSourceResourceHolder. Writes reframework/data/MHWilds_haptic_catalog.json
-- =============================================
local CATALOG, catalogN, catalogDirty, catalogProbe = {}, 0, false, nil
S.catalogOn = false   -- research tool (haptic catalog), off in release builds

local function list_methods(td, maxN)
    local names, t, guard = {}, td, 0
    while t and guard < 5 do
        local okm, ms = pcall(t.get_methods, t)
        if okm and ms then
            for _, m in ipairs(ms) do
                local okn, n = pcall(m.get_name, m)
                local okp, np = pcall(m.get_num_params, m)
                local okr, rt = pcall(m.get_return_type, m)
                if okn then names[#names + 1] = Language.format("%s::%s(%s) -> %s", t:get_full_name(), n, okp and tostring(np) or "?",
                                                      (okr and rt) and rt:get_full_name() or "?") end
                if #names >= (maxN or 120) then return names end
            end
        end
        t = t:get_parent_type(); guard = guard + 1
    end
    return names
end

-- calls only zero-parameter get_* methods (read-only getters) and records what they return
local function probe_getters(obj, out, prefix, depth)
    local okt, td = pcall(obj.get_type_definition, obj)
    if not (okt and td) then return end
    local t, guard = td, 0
    while t and guard < 5 do
        local okm, ms = pcall(t.get_methods, t)
        if okm and ms then
            for _, m in ipairs(ms) do
                local n = m:get_name()
                local okp, np = pcall(m.get_num_params, m)
                if okp and np == 0 and n:sub(1, 4) == "get_" and not n:find("Type") then
                    local okc, r = pcall(m.call, m, obj)
                    if okc then
                        if type(r) == "userdata" then
                            local okrt, rtd = pcall(r.get_type_definition, r)
                            local rn = (okrt and rtd) and rtd:get_full_name() or "?"
                            local okstr, str = pcall(r.call, r, "ToString")
                            out[#out + 1] = Language.format("%s.%s() = <%s> %s", prefix, n, rn, okstr and tostring(str) or "")
                            if depth < 1 then probe_getters(r, out, prefix .. "." .. n .. "()", depth + 1) end
                        else
                            out[#out + 1] = Language.format("%s.%s() = %s", prefix, n, tostring(r))
                        end
                    else
                        out[#out + 1] = Language.format("%s.%s() = <error>", prefix, n)
                    end
                end
            end
        end
        t = t:get_parent_type(); guard = guard + 1
    end
end

local function holder_path(h)
    if not h then return nil end
    for _, mn in ipairs({ "get_ResourcePath", "get_Path", "ToString" }) do
        local ok, r = pcall(h.call, h, mn)
        if ok and type(r) == "string" and r ~= "" then return r end
    end
    return nil
end

local function catalog_record(args)
    local addr = sdk.to_int64(args[4]) or 0
    if addr == 0 then return end
    local e = CATALOG[addr]
    if e then e.n = e.n + 1; e.last = S.kind or "?"; catalogDirty = true; return end
    local p = sdk.to_managed_object(args[4])
    if not p then return end
    local function fld(n) local ok, v = pcall(p.get_field, p, n); return ok and v or nil end
    local h = fld("_VibAudioSource")
    e = { n = 1, id = fld("_VibrationTrigger"), vol = fld("_Volume"), dur = fld("_DurationAD"), node = fld("_VibrationOutputNode"),
          path = holder_path(h), bnvib = holder_path(fld("_BnvibResource")), first = S.kind or "?", last = S.kind or "?" }
    CATALOG[addr] = e; catalogN = catalogN + 1; catalogDirty = true
    if not catalogProbe and h then                    -- first time: learn the holder API once
        catalogProbe = { "VibrationSourceResourceHolder methods:" }
        local okt, td = pcall(h.get_type_definition, h)
        if okt and td then for _, l in ipairs(list_methods(td, 150)) do catalogProbe[#catalogProbe + 1] = "  " .. l end end
        catalogProbe[#catalogProbe + 1] = "getter results:"
        probe_getters(h, catalogProbe, "holder", 0)
    end
end

local function save_catalog(quiet)
    local list = {}
    for _, e in pairs(CATALOG) do list[#list + 1] = e end
    table.sort(list, function(a, b) return a.n > b.n end)
    local out = { version = VERSION, presets = #list, entries = {}, probe = catalogProbe or { "(no preset with an audio source seen yet)" } }
    for i, e in ipairs(list) do
        out.entries[i] = Language.format("x%-4d id=%s vol=%s dur=%s node=%s weapon=%s/%s path=%s bnvib=%s", e.n, tostring(e.id),
            tostring(e.vol), tostring(e.dur), tostring(e.node), e.first, e.last, tostring(e.path), tostring(e.bnvib))
    end
    local ok, err = pcall(json.dump_file, "MHWilds_haptic_catalog.json", out)
    catalogDirty = false
    if not quiet then S.ev = Language.format("Haptic catalog: %d presets saved", #list) end
    log.info("[HapticPack] haptic catalog: " .. #list .. " presets -> reframework/data/MHWilds_haptic_catalog.json " .. (ok and "" or tostring(err)))
end

-- =============================================
-- BLUETOOTH: play the game's haptics by PRESET NAME (paths learned from the haptic catalog)
--  Wired, these are audio haptics; tiny ones (sword grab, stance, menu cursor) are barely felt.
--  Over Bluetooth the game's legacy rumble turned every one of them into a full pulse, so the plugin
--  now ignores that rumble and the mod decides here, by name, what deserves a vibration.
-- =============================================
local PRESET_RULES = {   -- first match wins; k = base strength, kind = "hit" (impact wave) or "tap" (short pulse)
    { "silence", nil }, { "sys_gui", nil }, { "whoosh", nil }, { "grab", nil }, { "hand_accent", nil },
    { "carry_on", nil }, { "mvmt", nil }, { "pull_loop", nil }, { "rope", nil }, { "gimmick", nil },
    { "hit_bullet_small", "hit", 0.35 }, { "hit_bullet_middle", "hit", 0.55 }, { "hit_bullet", "hit", 0.5 },
    { "hit_slash_small", "hit", 0.5 }, { "hit_slash_middle", "hit", 0.75 }, { "hit_slash_large", "hit", 1.0 },
    { "hit_burst", "hit", 0.9 }, { "hit_blast", "hit", 0.9 }, { "_hit", "hit", 0.7 },
    { "ground_imp", "hit", 0.8 }, { "final_blow", "hit", 1.1 }, { "_imp", "hit", 0.6 },
    { "charge_lv1", "tap", 0.35 }, { "charge_lv2", "tap", 0.5 }, { "charge_lv3", "tap", 0.7 },
    { "charge_max", "tap", 0.8 }, { "charge_1st", "tap", 0.35 }, { "charge_2nd", "tap", 0.5 },
    { "just_guard", "hit", 0.9 }, { "just_dodge", "tap", 0.5 }, { "mikiri", "hit", 0.9 }, { "parry", "hit", 0.8 },
    { "guard", "hit", 0.7 }, { "kijin", "tap", 0.6 }, { "lv_up", "tap", 0.6 }, { "success", "tap", 0.6 },
    { "shot", "tap", 0.55 }, { "launch", "tap", 0.5 }, { "burst", "hit", 0.8 }, { "blast", "hit", 0.8 },
    { "pile", "hit", 0.8 }, { "ryuugeki", "hit", 1.0 }, { "reload", "tap", 0.35 }, { "dmg", "hit", 0.8 },
    { "efx", "tap", 0.45 },
}
S.btPresetMode = 1   -- 0: off, 1: by preset name (default), 2: legacy (the game's own rumble)
local presetClass = {}   -- [preset addr] = { kind, k } or false

local function classify_preset(args)
    local addr = sdk.to_int64(args[4]) or 0
    if addr == 0 then return nil end
    local c = presetClass[addr]
    if c ~= nil then return c end
    c = false
    local p = sdk.to_managed_object(args[4])
    if p then
        local okh, h = pcall(p.get_field, p, "_VibAudioSource")
        local path = okh and h and holder_path(h) or nil
        local okv, vol = pcall(p.get_field, p, "_Volume")
        if path then
            local n = path:lower():match("([^/]+)%.vsrc$") or path:lower()
            for _, r in ipairs(PRESET_RULES) do
                if n:find(r[1], 1, true) then
                    if r[2] then
                        -- the game's own authored volume (dB) scales the strength: -10 dB -> x0.6, +6 dB -> x1.3
                        local db = (okv and type(vol) == "number") and vol or 0
                        local g = math.max(0.5, math.min(1.4, 10 ^ (db / 40)))
                        c = { kind = r[2], k = r[3] * g, name = n }
                    else
                        c = { kind = "none", name = n }
                    end
                    break
                end
            end
            if not c then c = { kind = "tap", k = 0.3, name = n } end   -- unknown: a soft tap
        end
    end
    presetClass[addr] = c
    return c
end

local function bt_preset_fx(args)
    local c = classify_preset(args)
    if not c or c.kind == "none" then return end
    S.lastBtPreset = c.name
    S.btPresetLogs = (S.btPresetLogs or 0) + 1
    if S.btPresetLogs <= 5 then log.info(string.format("[HapticPack][BT] game haptic '%s' -> %s %.2f", c.name, c.kind, c.k or 0)) end
    if c.kind == "hit" then
        hit_wave(c.k, 0.14)
    else
        local k = c.k * S.btHapticPulse * 2.2
        pulse("heavy", k, 0.06); pulse("light", k * 0.8, 0.06)
    end
end

local function game_vib_to_rumble(args)
    local t = os.clock()
    if t - S.lastGameVib < 0.025 then return end
    S.lastGameVib = t
    local addr = sdk.to_int64(args[4]) or 0
    local info = presetInfo[addr]
    if not info then
        local obj = (addr ~= 0) and sdk.to_managed_object(args[4]) or nil
        info = obj and analyze_preset(obj) or { s = 0.85, d = 0.14, dump = {} }
        presetInfo[addr] = info
    end
    S.lastPresetInfo = info
    S.vibSrc.adv = S.vibSrc.adv + 1
    hit_wave(info.s, info.d)
end

-- Play one DualSense-style impact wave (used for every game vibration source)
hit_wave = function(s0, d0)
    local w = WEAPON_HIT[S.kind or ""] or { k = 1.0, dk = 1.0 }
    local k = s0 * (S.btBridge and S.btHitGain or S.gameVibGain) * w.k
    local d = math.max(0.16, d0 * w.dk)
    S.lastHitK, S.lastHitD = k, d
    -- 1) kick: both motors full for 60ms (ERM motors need ~40ms to reach full force)
    pulse("heavy", k * 1.2, 0.06); pulse("light", k, 0.06)
    -- 2) body: heavy motor near full, light motor as padding
    pulse("heavy", k, d * 0.55 - 0.06, 0.06); pulse("light", k * 0.6, d * 0.4, 0.06)
    -- 3) rumbling tail: heavy motor fading out
    pulse("heavy", k * 0.6, d * 0.25, d * 0.55)
    pulse("heavy", k * 0.3, d * 0.2, d * 0.8)
end

-- On Xbox/Vader (XInput) the game may rumble through cPadInfo.addVibrationRequest instead of haptics.
-- Capture those requests (not the script's own) to: play an impact wave on start + boost both body motors.
S.motorHook = false
S.motorHookOn = false   -- measured on a Vader 5: the game does not rumble through this path (count = 0) => off to save work
local function ensure_motor_hook()
    if S.motorHook then return end
    S.motorHook = true
    local m = pad_method(SIG_VIB)
    if not m then log.info("[HapticPack] Could not hook addVibrationRequest"); return end
    sdk.hook(m, function(args)
        if S.selfMotor or S.out ~= "rumble" or not S.gameVibOn then return end
        local ok, v = pcall(sdk.to_float, args[3])
        if ok and type(v) == "number" and v > S.gameReq then S.gameReq = v end
    end, function(retval) return retval end)
    log.info("[HapticPack] Hooked addVibrationRequest (the game's XInput rumble)")
end

local function process_game_motor()
    local v = S.gameReq
    S.gameReq = 0.0
    if v <= 0.02 then S.gameReqOn = false; return end
    S.vibSrc.motor = S.vibSrc.motor + 1
    if not S.gameReqOn then
        S.gameReqOn = true
        hit_wave(math.min(1.5, 0.5 + v), 0.14)            -- hit when the game starts rumbling
    end
    local w = WEAPON_HIT[S.kind or ""] or { k = 1.0, dk = 1.0 }
    out_rumble(math.min(2.0, v * S.gameVibGain * w.k * 0.6), "body")   -- boost the game's own rumble on both motors
end

sdk.hook(TRIG_M, function(args)
    if self_vib then return end
    if S.catalogOn then pcall(catalog_record, args) end
    if S.btBridge and S.btPresetMode == 1 then pcall(bt_preset_fx, args) end
    if S.gameVibOn and (S.out == "rumble" or (S.btBridge and S.btGameHaptics)) then game_vib_to_rumble(args) end
    if S.cbGuarding then S.cbGuardHit = true end   -- game vibrates while guarding = blocked hit / Guard Point
    if S.gunFiring then S.gunShotPending = true end  -- game vibrates while the gun trigger is held = one shot
    -- Outside of charges: capture once. While charging: take the latest pattern, at most ~7 times per second
    -- (co-op vibrates a lot; recapturing every time is costly), lite mode: only once per charge.
    if captured then
        if not S.charging then return end
        if S.lite and S.capturedThisCharge then return end
        local t = clock()
        if t - capClock < 0.15 then return end
        capClock = t
    end
    local instAddr = sdk.to_int64(args[2])
    if not instAddr or instAddr == 0 then return end
    local presetAddr = sdk.to_int64(args[4])
    if S.charging then S.capturedThisCharge = true end
    if instAddr ~= savedInstAddr then
        local inst = sdk.to_managed_object(args[2])
        if not inst then return end
        if saved_inst then pcall(saved_inst.release, saved_inst) end
        pcall(inst.add_ref, inst)
        saved_inst, savedInstAddr = inst, instAddr
    end
    local preset = saved_preset[2]
    if presetAddr ~= savedPresetAddr then
        local np = (presetAddr and presetAddr ~= 0) and sdk.to_managed_object(args[4]) or nil
        if preset then pcall(preset.release, preset) end
        if np then pcall(np.add_ref, np) end
        preset, savedPresetAddr = np, presetAddr
    end
    -- reuse the old table, do not create a new one each time
    saved_preset[1] = sdk.to_int64(args[3]) & 0xFFFFFFFF
    saved_preset[2] = preset
    saved_preset[3] = sdk.to_valuetype(args[5], "ace.PadVibrationDefine.cRequestData")
    saved_preset[4] = sdk.to_int64(args[6]) & 0xFFFFFFFF
    captured = true
    if S.charging then capturedCharging = true end
end, function(retval) return retval end)

-- =============================================
-- WEAPON FIELD DETECTION
-- =============================================
local NUM_TYPES = {
    ["System.Int32"] = "int", ["System.UInt32"] = "int", ["System.Int16"] = "int", ["System.UInt16"] = "int",
    ["System.Byte"] = "int", ["System.SByte"] = "int", ["System.Int64"] = "int",
    ["System.Single"] = "float", ["System.Double"] = "float", ["System.Boolean"] = "bool",
}

local function field_kind(ftd)
    local name = ftd:get_full_name()
    if NUM_TYPES[name] then return NUM_TYPES[name] end
    local ok, isEnum = pcall(ftd.is_a, ftd, "System.Enum")
    if ok and isEnum then return "enum" end
    return nil
end

local function discover_fields(td)
    local list, seen = {}, {}
    local t = td
    while t do
        local ok, fields = pcall(t.get_fields, t)
        if ok and fields then
            for _, f in ipairs(fields) do
                if not f:is_static() then
                    local n = f:get_name()
                    if not seen[n] then
                        seen[n] = true
                        local k = field_kind(f:get_type())
                        if k then list[#list + 1] = { name = n, kind = k, owner = t:get_full_name(), tname = f:get_type():get_full_name(), fd = f, last = nil, changedAt = -10.0 } end
                    end
                end
            end
        end
        t = t:get_parent_type()
    end
    return list
end

local BAD = { "prev", "effect", "max", "overwrite", "request", "disable", "gimmick", "overheat", "sound", "camera", "motion", "ui" }
local function is_bad(lname)
    for _, b in ipairs(BAD) do if lname:find(b, 1, true) then return true end end
    return false
end

local function auto_pick(list, want)
    local best, bestScore = nil, 0
    for i, f in ipairs(list) do
        local n = f.name:lower()
        local score = 0
        if want == "level" and (f.kind == "int" or f.kind == "enum") and n:find("charge") and (n:find("level") or n:find("lv")) then
            score = 10
            if n == "_chargelevel" or n == "_chargelv" then score = 20 end
        elseif want == "timer" and f.kind == "float" and n:find("charge") and (n:find("timer") or n:find("time")) then
            score = 10
            if n == "_chargetimer" or n == "_chargetime" then score = 20 end
        end
        if score > 0 and is_bad(n) then score = score - 8 end
        if score > bestScore then best, bestScore = i, score end
    end
    return best
end

local function on_weapon_changed(td)
    S.fields = td and discover_fields(td) or {}
    S.fieldNames = { "(not used)" }
    for _, f in ipairs(S.fields) do S.fieldNames[#S.fieldNames + 1] = f.name .. " [" .. f.kind .. "]" end
    local li, ti = auto_pick(S.fields, "level"), auto_pick(S.fields, "timer")
    S.levelIdx = li and (li + 1) or 1
    S.timerIdx = ti and (ti + 1) or 1
    log.info(string.format("[HapticPack] %s: %d field, level=%s, timer=%s", S.typeName, #S.fields,
        S.fieldNames[S.levelIdx], S.fieldNames[S.timerIdx]))
    S.flog = {}   -- per-field state of the field-change log
    if S.fieldLogOn and td then
        log.info(string.format("[HapticPack][rec] ===== WEAPON %s (%d fields) =====", S.typeName, #S.fields))
        local line = {}
        for i, f in ipairs(S.fields) do
            line[#line + 1] = f.name .. "[" .. f.kind .. "]"
            if #line == 8 or i == #S.fields then log.info("[HapticPack][rec] fields: " .. table.concat(line, "  ")); line = {} end
        end
    end
end

local function read_field(idx)
    if idx <= 1 or not S.wh then return nil end
    local f = S.fields[idx - 1]
    if not f then return nil end
    local ok, v
    if f.fd and not f.fdBad then
        ok, v = pcall(f.fd.get_data, f.fd, S.wh)
        if not ok then f.fdBad = true end
    end
    if not ok then ok, v = pcall(S.wh.get_field, S.wh, f.name) end
    if not ok then return nil end
    if type(v) == "boolean" then return v and 1 or 0 end
    return tonumber(v)
end

-- =============================================
-- EFFECTS
-- =============================================
local function start_rumble(now, strength, duration)
    S.rumbleStr = strength
    S.rumbleUntil = now + duration
    S.lastRumbleSend = now
    motor_rumble(strength)
end

local function start_haptics(now, count, gap)
    count = math.max(0, math.floor(count + 0.5))
    if count == 0 then return end
    play_haptic()
    S.hapticsLeft = count - 1
    S.hapticGap = gap
    S.nextHapticAt = now + gap
end

local function on_level_up(now, c, lvl)
    if now - S.lastLevelUpAt < 0.25 then return end
    S.lastLevelUpAt = now
    if c.levelPulse then
        local gap = (c.notchStyle ~= "pulse") and c.notchGap or 0.0
        S.notchStart = now
        S.notchEnd = now + gap + c.pulseTime
    end
    start_haptics(now, c.notchHaptics, 0.035)
    if c.notchRumble > 0 then start_rumble(now, c.notchRumble, c.notchRumbleTime) end
    S.ev = Language.format("LEVEL UP %d (%s) @%.2f", lvl, S.levelSrcUsed, now)
end

local function on_release(now, c, lvl, dur)
    start_rumble(now, c.rumbleBase + c.rumbleStep * lvl, c.rumbleTime)
    start_haptics(now, c.hapticBase + c.hapticStep * lvl, c.hapticGap)
    S.releases = S.releases + 1
    S.ev = Language.format("RELEASE level %d (charged %.2fs) @%.2f", lvl, dur, now)
end

-- Sound-driven vibration events from the game (LS uses this hook to know when the spirit charge levels up).
-- The game calls this for EVERY character (co-op = very often) => only install it when really needed
-- (weapons that use the "sound" source), filtered right away by your own player's GameObject.
S.soundHookInstalled = false
S.myGoAddr = nil
local function ensure_sound_hook()
    if S.soundHookInstalled then return end
    S.soundHookInstalled = true
    local spv = sdk.find_type_definition("app.SoundPostVibrationManager")
    local m = spv and spv:get_method("requestVibration(app.snd_user_data.SoundVibrationTriggerListData.VibrationTrigger, via.GameObject)")
    if not m then
        log.info("[HapticPack] SoundPostVibrationManager.requestVibration not found")
        return
    end
    sdk.hook(m, function(args)
        if body_via_motors() and S.gameVibOn then
            local mine = (not S.myGoAddr) or S.goFilterOff or (sdk.to_int64(args[4]) or 0) == S.myGoAddr
            -- rumble controllers: the game sends no haptics, so guard hits are unknown => use your own sound events
            if mine and S.cbGuarding then
                local cg = S.kind and CFG[S.kind]
                if cg and cg.soundGuardHit then S.cbGuardHit = true end
            end
            if mine or (S.soundAll and not S.btBridge) then
                S.vibSrc.sound = S.vibSrc.sound + 1
                local t = os.clock()
                if t - (S.lastSoundHit or -10) > 0.05 then
                    S.lastSoundHit = t
                    hit_wave(0.9, 0.16)
                end
            else
                S.vibSrc.soundOther = S.vibSrc.soundOther + 1
            end
        end
        if not S.charging then return end
        -- only accept your own events (ignore other hunters / monsters in co-op)
        if S.myGoAddr and not S.goFilterOff and (sdk.to_int64(args[4]) or 0) ~= S.myGoAddr then
            -- safety: if the GameObject passed by the game is not the character's (e.g. the weapon's),
            -- the filter would block everything => if nothing arrives after a few charges, disable the filter
            S.goFiltered = (S.goFiltered or 0) + 1
            if S.goFiltered >= 8 and S.soundEvents == 0 then
                S.goFilterOff = true
                log.info("[HapticPack] Disabled the GameObject filter for the sound hook")
            end
            return
        end
        if S.kind == "ls" then
            if not S.lsIai then S.lsLvUp = true end
            S.soundEvents = S.soundEvents + 1
            return
        end
        local c = S.kind and CFG[S.kind]
        if not c then return end
        S.soundEvents = S.soundEvents + 1
        S.soundSeen[S.kind] = true
        if S.levelSrcUsed == "sound" then
            local now = now_s()
            if now - S.chargeStart < 0.1 then return end
            S.maxLevel = S.maxLevel + 1
            on_level_up(now, c, S.maxLevel)
        end
    end, function(retval) return retval end)
    log.info("[HapticPack] Sound vibration hook installed")
end

-- Desired trigger effect for the current frame
local function desired_trigger(now, c)
    local testing = now < (S.testHoldUntil or -10.0)
    if not c.triggerEnabled then return FREE end
    if not (S.charging or testing) or c.chargeTrigger == false then return c.idleTrigger or FREE end
    if now < S.notchEnd then
        local t = now - S.notchStart
        if c.notchStyle ~= "pulse" and t < c.notchGap then
            return FREE                                   -- trigger lets go (drops into the click)
        end
        if c.notchStyle == "detent" then
            return { 1.0, 0.0, 0.0, 1.0, 1.0 }            -- hit a hard wall
        end
        return { 1.0, c.pulseFreq, 0.0, 1.0, 1.0 }        -- LS KIJIN_PULSE
    end
    return c.holdTrigger
end

local lastSent = { 0, 0, 0, 0, 0 }

-- Rumble mode (Vader 5 / Xbox): no trigger resistance => trigger effects become trigger-motor rumble:
--  * vibrating trigger (vibration param > 0: beats, impacts, kicks...) => trigger motor follows
--  * trigger goes loose <-> stiff (clicks, levels, entering/leaving a charge) => one short "tick"
-- Adaptive-trigger emulation with motors, based on the finger POSITION on the trigger (feels closer to the real thing):
--  * finger reaches the resistance zone     -> "thud" (wall hit)
--  * pressing through the whole zone       -> light "tick" (click break)
--  * sliding inside the resistance zone    -> fine rumble by press speed (friction)
--  * holding still inside the zone      -> light tension rumble (finger pressure)
--  * resistance appears while the finger presses -> strong "push" (e.g. entering a spirit charge, Hammer charge start)
--  * resistance disappears while pressing   -> light "release"
--  * vibrating trigger (beats, impacts, kicks) -> continuous rumble by vibration amount
-- ERM motors need ~30-50ms to spin up, so every "hit" lasts >= 80ms.
local emu = { L = { last = -1 }, R = { last = -1 } }
local function emu_kick(side, s, dur)
    pulse((side == "L") and "trigL" or "trigR", math.min(2.0, s * S.trigEmuGain), math.max(0.10, dur * 1.25))
end
local function emu_stream(e, side, s)
    local t = os.clock()
    if t - e.last >= (S.lite and 0.08 or 0.04) then
        e.last = t
        out_rumble(math.min(2.0, s * S.trigEmuGain), (side == "L") and "trigL" or "trigR")
    end
end
local function emu_trigger(side, v)
    local e = emu[side] or emu.R
    local f, freq, st, en = v[1] or 0, v[2] or 0, v[3] or 0, v[4] or 1
    local pos = (side == "L") and S.lt or S.rt
    if e.f ~= nil then
        local df = f - e.f
        if df >= 0.3 and pos > st + 0.05 then emu_kick(side, 0.55 + 0.45 * f, 0.10) end      -- force appears under the finger
        if df <= -0.3 and pos > 0.1 then emu_kick(side, 0.3 + 0.3 * e.f, 0.08) end          -- force lost while pressing
    end
    if f >= 0.15 and e.pos ~= nil then
        local inZone = pos >= st and pos <= en
        if e.pos < st and pos >= st then emu_kick(side, 0.5 + 0.5 * f, 0.09) end            -- wall hit
        if en < 0.97 and e.pos <= en and pos > en then emu_kick(side, 0.35 + 0.3 * f, 0.08) end  -- click break
        if inZone and not S.emuQuiet then
            local dp = math.abs(pos - e.pos)
            if dp > 0.01 then
                emu_stream(e, side, 0.3 * f + math.min(0.8, dp * 8.0))                          -- friction while sliding
            elseif S.trigTension and pos > 0.05 then
                emu_stream(e, side, 0.2 * f)                                                    -- tension while holding still
            end
        end
    end
    if freq > 0 then emu_stream(e, side, f * (0.5 + freq * 2.5)) end                            -- vibrating trigger
    e.pos, e.f = pos, f
end

local function apply_trigger(side, v)
    if S.out == "rumble" then
        emu_trigger(side, v)
        S.sentSide = side
        lastSent[1], lastSent[2], lastSent[3], lastSent[4], lastSent[5] = v[1], v[2], v[3], v[4], v[5]
        return
    end
    if S.sentKey and S.sentSide == side and lastSent[1] == v[1] and lastSent[2] == v[2]
       and lastSent[3] == v[3] and lastSent[4] == v[4] and lastSent[5] == v[5] then
        return
    end
    send_trigger(side, v)
    lastSent[1], lastSent[2], lastSent[3], lastSent[4], lastSent[5] = v[1], v[2], v[3], v[4], v[5]
    S.sentKey, S.sentSide = true, side
end

local function release_trigger_control()
    if S.sentSide and S.out ~= "rumble" then
        send_trigger(S.sentSide, FREE)
    end
    emu.L.f, emu.R.f, emu.L.pos, emu.R.pos = nil, nil, nil, nil
    S.sentKey, S.sentSide = nil, nil
end

-- =============================================
-- CONTROLLER AUTO-DETECT
--  DualSense                                   -> "dualsense" (adaptive triggers + haptics)
--  anything else (Xbox / XInput / Flydigi Vader / DS4 / Switch Pro / Steam Input)
--                                              -> "rumble" (trigger effects emulated with motors)
--  Sources (whichever answers first):
--   1) via.hid.GamePad (engine) -> last used device -> DeviceKindDetails enum name
--   2) ace.cPadInfo (game) -> any getter that looks like a device/pad type
--  Unknown result => keep the current mode (never flips on a guess).
-- =============================================
S.outMode = "auto"                      -- "auto" | "dualsense" | "rumble"
S.detected, S.detectedName, S.lastDetect = nil, "?", -10.0
local DET = { gpT = false, enumNames = {}, padGetters = nil }

local function enum_value_name(tname, v)
    local m = DET.enumNames[tname]
    if not m then
        m = {}
        for name, val in pairs(read_enum(tname)) do m[val] = name end
        DET.enumNames[tname] = m
    end
    return m[v]
end

-- call a 0-arg getter and turn the result into a readable name (enum -> member name)
local function getter_name(obj, m)
    local ok, v = pcall(m.call, m, obj)
    if not ok or v == nil then return nil end
    if type(v) == "boolean" then return v and "true" or "false" end
    if type(v) == "number" then
        local okr, rt = pcall(m.get_return_type, m)
        local tn = okr and rt and rt:get_full_name() or nil
        return (tn and enum_value_name(tn, v)) or tostring(v)
    end
    return tostring(v)
end

local function classify_device(name)
    if not name then return nil end
    local n = name:lower()
    if n:find("dualsense", 1, true) or n:find("ps5", 1, true) or n:find("prospero", 1, true) then return "dualsense" end
    if n:find("merged", 1, true) or n:find("unknown", 1, true) or n:find("null", 1, true) or n == "none" then return nil end
    for _, w in ipairs({ "xinput", "xbox", "dualshock", "ps4", "switch", "joycon", "joypad", "gaminginput", "steam" }) do
        if n:find(w, 1, true) then return "rumble" end
    end
    return nil
end

local function device_from_engine()
    if DET.gpT == false then DET.gpT = sdk.find_type_definition("via.hid.GamePad") end
    local gp = DET.gpT and sdk.get_native_singleton("via.hid.GamePad")
    if not gp then return nil end
    local names = {}
    for i = 1, 2 do
        local ok, dev
        if i == 1 then ok, dev = pcall(sdk.call_native_func, gp, DET.gpT, "get_LastInputDevice")
        else ok, dev = pcall(sdk.call_native_func, gp, DET.gpT, "getMergedDevice", 0) end
        if ok and dev then
            local okt, td = pcall(dev.get_type_definition, dev)
            if okt and td then
                for _, g in ipairs({ "get_DeviceKindDetails", "get_KindDetails", "get_DeviceKind" }) do
                    local m = td:get_method(g)
                    local nm = m and getter_name(dev, m)
                    if nm then
                        names[#names + 1] = nm
                        local mode = classify_device(nm)
                        if mode then return mode, nm end
                    end
                end
            end
        end
    end
    return nil, (#names > 0) and table.concat(names, "/") or nil
end

local DET_WORDS = { "devicekind", "devicetype", "padtype", "padkind", "controllertype", "dualsense", "isps5" }
local function device_from_game(pad)
    if not pad then return nil end
    if not DET.padGetters then
        DET.padGetters = {}
        local okt, td = pcall(pad.get_type_definition, pad)
        local depth = 0
        while okt and td and depth < 4 do
            local okm, methods = pcall(td.get_methods, td)
            if okm and methods then
                for _, m in ipairs(methods) do
                    local okn, mn = pcall(m.get_name, m)
                    local okp, np = pcall(m.get_num_params, m)
                    if okn and mn and okp and np == 0 then
                        local l = mn:lower()
                        for _, w in ipairs(DET_WORDS) do
                            if l:find(w, 1, true) then DET.padGetters[#DET.padGetters + 1] = { m = m, name = mn }; break end
                        end
                    end
                end
            end
            td = td:get_parent_type()
            depth = depth + 1
        end
    end
    local seen = nil
    for _, g in ipairs(DET.padGetters) do
        local nm = getter_name(pad, g.m)
        if nm then
            -- a bool getter like isDualSense(): true -> DualSense, false -> something else
            if nm == "true" or nm == "false" then
                if g.name:lower():find("dualsense", 1, true) or g.name:lower():find("ps5", 1, true) then
                    return (nm == "true") and "dualsense" or "rumble", g.name .. "=" .. nm
                end
            else
                local mode = classify_device(nm)
                if mode then return mode, nm end
                seen = nm
            end
        end
    end
    return nil, seen
end

local function set_out(mode)
    if mode == S.out then return end
    if S.out ~= "rumble" then release_trigger_control() end   -- leave the DualSense triggers free before switching
    S.out = mode
    S.sentKey = nil
    emu.L.f, emu.R.f, emu.L.pos, emu.R.pos = nil, nil, nil, nil
end

local function update_detect(now, pad, force)
    if not force and now - S.lastDetect < 2.0 then return end
    S.lastDetect = now
    local mode, name = device_from_engine()
    if not mode then
        local m2, n2 = device_from_game(pad)
        mode = m2
        name = n2 or name
    end
    S.detected, S.detectedName = mode, name or "?"
    if S.outMode == "auto" and mode then set_out(mode) end
end

local function reset_charge()
    S.charging, S.level, S.maxLevel, S.still = false, 0, 0, 0
    S.lastLevel, S.lastTimer, S.pulseUntil = 0, 0.0, 0.0
end

-- =============================================
-- CHARGE STATE MACHINE (shared by GS, Hammer & Bow)
-- =============================================
local function update_charge(now, c, pad)
    local side = c.trigger
    local pressed = c.sustainByTrigger ~= false
        and read_trigger(pad, side == "L" and "get_LTrigger" or "get_RTrigger") > CFG.PRESS_THRESHOLD
    local cont = false
    if c.contField and S.wh then
        if S.contIdxFor ~= S.typeName then
            S.contIdxFor, S.contIdx = S.typeName, nil
            for i, f in ipairs(S.fields) do if f.name == c.contField then S.contIdx = i + 1 end end
        end
        local v = S.contIdx and read_field(S.contIdx) or nil
        cont = v ~= nil and v ~= 0
    end
    local lvlF = read_field(S.levelIdx)
    local tmr  = read_field(S.timerIdx)

    local timerRising = tmr ~= nil and tmr > S.lastTimer + 1e-4
    local timerReset  = tmr ~= nil and tmr + 1e-4 < S.lastTimer
    local levelUp     = lvlF ~= nil and lvlF > S.lastLevel

    -- Charge start: timer running or charge level rising; with no field at all, fall back to the trigger
    local start
    if tmr ~= nil then start = timerRising
    elseif lvlF ~= nil then start = levelUp and pressed
    else start = pressed end
    -- Keep the charge state: timer still running, or trigger still held (at max level the timer may stop)
    local sustain = start or cont or (S.charging and pressed)

    if sustain then
        if not S.charging then
            S.charging, S.chargeStart, S.maxLevel = true, now, 0
            S.capturedThisCharge = false
        end
        S.still = 0
    elseif S.charging then
        S.still = S.still + 1
    end

    -- Charge level: from a field, or estimated from hold time
    local lvl
    if lvlF ~= nil then lvl = lvlF
    elseif S.charging then lvl = math.min(c.maxLevel, math.floor((now - S.chargeStart) / c.fallbackLevelTime))
    else lvl = 0 end
    S.level = S.charging and lvl or 0

    local src = c.levelSource
    if src == "auto" then
        if lvlF ~= nil then src = "field"
        elseif S.soundSeen[S.kind] then src = "sound"
        else src = "time" end
    end
    S.levelSrcUsed = src
    if (src == "sound" or (c.levelSource == "auto" and lvlF == nil)) and not S.soundHookInstalled then
        ensure_sound_hook()
    end
    if src == "field" or src == "time" then
        if S.charging and lvl > S.maxLevel then
            S.maxLevel = lvl
            if lvl >= 1 then on_level_up(now, c, lvl) end
        end
    else
        S.level = S.maxLevel   -- "sound" source: levels are counted by the game vibration event hook
    end

    local levelDropped = lvlF ~= nil and S.lastLevel >= 1 and lvlF < S.lastLevel
    if S.charging and (levelDropped or timerReset or S.still >= CFG.RELEASE_FRAMES) then
        local dur = now - S.chargeStart
        local finalLvl = math.max(S.maxLevel, S.lastLevel)
        reset_charge()
        if dur >= c.minCharge and finalLvl >= (c.minLevel or 0) then on_release(now, c, finalLvl, dur) end
    end

    S.lastLevel = lvlF or 0
    S.lastTimer = tmr or 0.0

    -- Body rumble while holding: like the LS script calling kijin_charge_vibrate() on every update
    if S.charging and c.holdHaptic and now > S.notchEnd + 0.06 and S.hapticsLeft == 0
       and now - S.lastBeat >= (S.lite and math.max(0.12, c.holdHapticEvery) or c.holdHapticEvery) then
        S.lastBeat = now
        play_haptic()
    end

    apply_trigger(side, desired_trigger(now, c))
end

-- =============================================
-- EVENT MODULES (Switch Axe / Charge Blade)
-- =============================================
S.rules = {}          -- [key] = { idx, last, auto }
S.fx = nil            -- short trigger effect: { side, start, gap, hit }
S.lastBuzz, S.lastAmpBeat, S.lastDisBeat, S.lastDisRumble, S.lastAmpRumble = 0.0, 0.0, 0.0, 0.0, 0.0
S.disStart, S.lastMorph, S.rtPrev, S.guardSince = nil, -10.0, 0.0, nil
S.cbGuarding, S.cbGuardHit = false, false
S.ampManual = {}   -- "full" level locked by the player, kept across weapon changes
S.vibWhy = {}      -- why it is rumbling continuously (shown in the menu)

-- =============================================
-- SAVED SETTINGS (reframework/data/MHWilds_Haptic_Pack.json)
-- =============================================
local SAVE_FILE = "MHWilds_Haptic_Pack.json"
local SAVE = { fields = {}, ampManual = {}, gunMap = {}, ignitionStyle = nil }
do
    local ok, data = pcall(json.load_file, SAVE_FILE)
    if ok and type(data) == "table" then
        SAVE.fields = type(data.fields) == "table" and data.fields or {}
        SAVE.ampManual = type(data.ampManual) == "table" and data.ampManual or {}
        S.lite = data.lite == true
        SAVE.gunMap = type(data.gunMap) == "table" and data.gunMap or {}
        if data.out == "rumble" or data.out == "dualsense" then S.out = data.out end
        Language.set(data.lang)
        if data.outMode == "auto" or data.outMode == "dualsense" or data.outMode == "rumble" then S.outMode = data.outMode end
        if S.outMode ~= "auto" then S.out = S.outMode end
        if type(data.motorRoles) == "table" then S.motorRoles = data.motorRoles end
        if data.outVer == 2 then
            if type(data.trigEmuGain) == "number" then S.trigEmuGain = data.trigEmuGain end
            if type(data.hapticRumble) == "number" then S.hapticRumble = data.hapticRumble end
            if type(data.rumbleGain) == "number" then S.rumbleGain = data.rumbleGain end
        end
        if type(data.trigMotorsWork) == "boolean" then S.trigMotorsWork = data.trigMotorsWork end
        if type(data.soundAll) == "boolean" then S.soundAll = data.soundAll end
        if data.gameVibOn == false then S.gameVibOn = false end
        if data.vibVer == 2 and type(data.gameVibGain) == "number" then S.gameVibGain = data.gameVibGain end
        if data.outVer == 2 and type(data.sideBleed) == "number" then S.sideBleed = data.sideBleed end
        if data.trigTension == false then S.trigTension = false end
        S.keepPreset = data.keepPreset == true
        SAVE.ignitionStyle = data.ignitionStyle
        if SAVE.ignitionStyle then CFG.hbg.ignitionStyle = SAVE.ignitionStyle end
        -- keep every other saved setting, so saving one option never wipes the others
        for k, v in pairs(data) do if SAVE[k] == nil then SAVE[k] = v end end
    end
end

local function save_rule(key)
    local kind = S.kind
    if not kind then return end
    local st = S.rules[key]
    SAVE.fields[kind] = SAVE.fields[kind] or {}
    if st and st.idx > 1 and S.fields[st.idx - 1] then
        SAVE.fields[kind][key] = S.fields[st.idx - 1].name
    else
        SAVE.fields[kind][key] = nil
    end
    SAVE.ampManual[kind] = SAVE.ampManual[kind] or {}
    SAVE.ampManual[kind][key] = S.ampManual[key]
    local ok, err = pcall(json.dump_file, SAVE_FILE, SAVE)
    if not ok then log.info("[HapticPack] Could not save: " .. tostring(err)) end
end

local function pick_rule_field(pats, allowType, exclude)
    for _, alt in ipairs(pats) do
        for i, f in ipairs(S.fields) do
            local n = f.name:lower()
            local ok = true
            for _, w in ipairs(alt) do if not n:find(w, 1, true) then ok = false; break end end
            if ok and exclude then
                for _, w in ipairs(exclude) do if n:find(w, 1, true) then ok = false; break end end
            end
            if ok and not (n:find("prev", 1, true) or n:find("request", 1, true) or n:find("disable", 1, true)
                       or n:find("effect", 1, true) or n:find("max", 1, true) or n:find("index", 1, true)
                       or (not allowType and n:find("type", 1, true)) or n:find("const", 1, true) or n:find("unique", 1, true)
                       or (n:find("hit", 1, true) and not n:find("white", 1, true)) or n:find("check", 1, true)) then
                return i + 1
            end
        end
    end
    return 1
end

-- Find the matching max field (e.g. _AwakeGauge -> _AwakeGaugeMax / _MaxAwakeGauge)
local function find_max_field(idx)
    if idx <= 1 then return 1 end
    local base = S.fields[idx - 1].name:lower():gsub("^_", ""):gsub("k__backingfield", ""):gsub("[<>]", "")
    local core = base:gsub("gauge", ""):gsub("value", ""):gsub("current", ""):gsub("now", ""):gsub("_", "")
    if #core < 3 then core = base end
    for i, f in ipairs(S.fields) do
        local n = f.name:lower()
        if i ~= idx - 1 and n:find("max", 1, true) and n:gsub("_", ""):find(core, 1, true)
           and (f.kind == "float" or f.kind == "int") then
            return i + 1
        end
    end
    return 1
end

local function field_index_by_name(name)
    if not name then return nil end
    for i, f in ipairs(S.fields) do if f.name == name then return i + 1 end end
    return nil
end

local function init_rules(kind)
    S.rules = {}
    local saved = (SAVE.fields or {})[kind or ""] or {}
    for _, r in ipairs(RULES[kind] or {}) do
        local idx = field_index_by_name(saved[r.key])
        if not idx and r.exact then
            for _, nm in ipairs(r.exact) do idx = idx or field_index_by_name(nm) end
        end
        idx = idx or pick_rule_field(r.pats, r.allowType, r.exclude)
        S.rules[r.key] = { idx = idx, last = nil, auto = idx > 1 }
        if r.type == "full" then S.rules[r.key].maxIdx = find_max_field(idx) end
        local savedFull = ((SAVE.ampManual or {})[kind or ""] or {})[r.key]
        if savedFull then S.ampManual[r.key] = savedFull end
    end
end

-- Returns: current value, previous value (nil if none yet)
local function rule_value(key)
    local r = S.rules[key]
    if not r then return nil, nil end
    local v = read_field(r.idx)
    local prev = r.last
    r.last = v
    if v ~= nil and prev ~= nil and math.abs(v - prev) > 1e-4 then r.changed = true end
    return v, prev
end

-- A field that never changed since the weapon was equipped => not a real gauge/state
local function live(key)
    local r = S.rules[key]
    return r ~= nil and r.changed == true
end

local function is_on(v) return v ~= nil and v > 0.001 end

-- Trigger click: release then hit the wall (like a Hammer level-up)
local function trigger_notch(now, side, gap, hit)
    S.fx = { side = side, start = now, gap = gap or 0.045, hit = hit or 0.07 }
end

-- Shield impact: the trigger becomes a hard wall and VIBRATES strongly for a moment (pushes back on the finger)
local function trigger_impact(now, side, time, freq)
    S.fx = { side = side, start = now, impact = true, time = time or 0.09, freq = freq or 0.25 }
end

local function fx_trigger(now)
    local fx = S.fx
    if not fx then return nil end
    local t = now - fx.start
    if fx.seq then
        -- sequence of steps { duration, trigger effect } played back to back
        local acc = 0.0
        for _, step in ipairs(fx.seq) do
            acc = acc + step[1]
            if t < acc then return step[2] end
        end
        S.fx = nil
        return nil
    end
    if fx.impact then
        if t < fx.time then return { 1.0, fx.freq, 0.0, 1.0, 1.0 } end
        S.fx = nil
        return nil
    end
    if t < fx.gap then return FREE end
    if t < fx.gap + fx.hit then return { 1.0, 0.0, 0.0, 1.0, 1.0 } end
    S.fx = nil
    return nil
end

local function thunk(now, rumble, haptics, time)
    if rumble and rumble > 0 then start_rumble(now, rumble, time or 0.1) end
    if haptics and haptics > 0 then start_haptics(now, haptics, 0.04) end
end

-- ---------- SWITCH AXE ----------
local function clear_why() local t = S.vibWhy; for i = #t, 1, -1 do t[i] = nil end end

-- Shield raise (rumble controllers / Vader 5): no trigger resistance, so motors are used:
--  * raising the shield: a "thud" into the body (heavy motor = shield weight) + right trigger push
--  * holding the shield: a very light "strain" on the heavy motor, like carrying its weight
local function guard_feel(now, c, guarding)
    if S.out ~= "rumble" or not c.guardRaise then S.wasGuarding = guarding; return end
    if guarding and not S.wasGuarding then
        local r = c.guardRaise
        pulse("heavy", r[1], r[3]); pulse("light", r[2], r[3] * 0.6)
        pulse((c.trigger == "L") and "trigL" or "trigR", 0.9, r[3])
        S.ev = Language.format("SHIELD UP @%.2f", now)
    elseif not guarding and S.wasGuarding then
        local lo = c.guardLower or 0.35
        if lo > 0 then pulse("light", lo, 0.06) end                       -- lowering the shield: light tick
    end
    if guarding and (c.guardBrace or 0) > 0 then
        S.vibWhy[#S.vibWhy + 1] = "Holding shield"
        if now - (S.lastBrace or 0) >= (S.lite and 0.1 or 0.05) then
            S.lastBrace = now
            out_rumble(c.guardBrace, "heavy")
        end
    end
    S.wasGuarding = guarding
end

local function update_sa(now, c, pad)
    clear_why()
    local rt = S.rt

    -- ---- Morph ----
    -- Old bug: the "_Mode" field changes constantly during attacks, and every R2 press also counted
    -- counted as a morph => click + rumble every 0.5s while attacking. Now:
    --  * valid mode field: only counts when the NEW value holds for >= morphStable seconds and differs from the last stable mode
    --  * no field: only then use R2 presses as a fallback
    local mode = rule_value("mode")
    local modeOK = S.rules["mode"] and S.rules["mode"].idx > 1 and live("mode")
    local morph = false
    if modeOK and mode ~= nil then
        if mode ~= S.saModeCand then S.saModeCand, S.saModeSince = mode, now end
        if S.saModeStable == nil then S.saModeStable = mode end
        if S.saModeCand ~= S.saModeStable and now - S.saModeSince >= c.morphStable then
            S.saModeStable = S.saModeCand
            morph = true
        end
    elseif c.morphFromTrigger and rt > 0.6 and S.rtPrev <= 0.6 then
        morph = true
    end
    S.rtPrev = rt
    if c.morphOn and morph and now - S.lastMorph > 1.0 then
        S.lastMorph = now
        if c.morphNotch then trigger_notch(now, c.trigger) end
        thunk(now, c.morphRumble, c.morphHaptics, 0.1)
        S.ev = Language.format("MORPH @%.2f", now)
    end

    -- ---- Switch gauge reload: jump >= 30% of the highest value, at least 1.5s apart ----
    local g, gPrev = rule_value("gauge")
    if g then S.saGaugeMax = math.max(S.saGaugeMax or 0, g) end
    -- A real gauge sits still most of the time; a timer (e.g. _SlashGaugeAutoRecoveryTimer) changes
    -- every frame and loops. If the field changes on most frames, it is a timer: never treat it as a reload.
    if g and gPrev then
        local changed = (math.abs(g - gPrev) > 1e-4) and 1 or 0
        S.saGChg = (S.saGChg or 0) * 0.95 + changed * 0.05
        S.saGFrames = (S.saGFrames or 0) + 1
    end
    -- also wait ~0.5 s after equipping so the first reading isn't taken as a reload
    local gaugeIsTimer = (S.saGChg or 0) > 0.6 or (S.saGFrames or 0) < 30
    if c.reloadOn and not gaugeIsTimer and g and gPrev and S.saGaugeMax and S.saGaugeMax > 0
       and g - gPrev >= 0.3 * S.saGaugeMax and now - (S.saLastReload or -10) > 1.5 then
        S.saLastReload = now
        start_haptics(now, c.reloadHaptics, 0.06)
        S.ev = Language.format("GAUGE RELOAD @%.2f", now)
    end

    -- ---- Discharge: must last >= dischargeHold before it rumbles ----
    local dis = rule_value("discharge")
    local disOn = c.dischargeOn and is_on(dis) and live("discharge")
    if disOn then
        S.disSeen = S.disSeen or now
    else
        S.disSeen = nil
    end
    if disOn and now - S.disSeen >= c.dischargeHold then
        S.vibWhy[#S.vibWhy + 1] = "Discharge"
        if not S.disStart then S.disStart = now; S.ev = Language.format("DISCHARGE @%.2f", now) end
        local p = math.min(1.0, (now - S.disStart) / math.max(0.1, c.dischargeRamp))
        if now - S.lastDisRumble >= (S.lite and 0.08 or 0.04) then
            S.lastDisRumble = now
            motor_rumble(c.dischargeRumbleMin + (c.dischargeRumbleMax - c.dischargeRumbleMin) * p)
        end
        if now - S.lastDisBeat >= c.dischargeBeat * (1.0 - 0.5 * p) then
            S.lastDisBeat = now
            play_haptic()
        end
    elseif S.disStart and not disOn then
        S.disStart = nil
        thunk(now, c.finisherRumble, c.finisherHaptics, c.finisherTime)
        S.ev = Language.format("FINISHER BURST @%.2f", now)
    end

    apply_trigger(c.trigger, fx_trigger(now) or FREE)
end

-- ---------- CHARGE BLADE ----------
local function update_cb(now, c, pad)
    clear_why()
    local held = read_trigger(pad, c.trigger == "L" and "get_LTrigger" or "get_RTrigger") > CFG.PRESS_THRESHOLD
    if held then S.guardSince = S.guardSince or now else S.guardSince = nil end
    S.cbGuarding = c.guardTrigger and S.guardSince ~= nil and now - S.guardSince >= c.guardHold
    guard_feel(now, c, S.cbGuarding)

    -- Guard hit / Guard Point
    if S.cbGuardHit then
        S.cbGuardHit = false
        if S.cbGuarding and now - (S.lastGuardHit or -10) > 0.25 then
            S.lastGuardHit = now
            trigger_notch(now, c.trigger, 0.04, 0.09)
            thunk(now, c.guardHitRumble, c.guardHitHaptics, 0.12)
            S.ev = Language.format("GUARD HIT @%.2f", now)
        end
    end

    -- Phials: up = load (one pulse per phial), down = discharge (stronger with more phials)
    local ph, phPrev = rule_value("phial")
    if ph and phPrev then
        local d = math.floor(ph - phPrev + 0.5)
        if d > 0 and d <= 10 then
            start_haptics(now, d, c.phialGap)
            start_rumble(now, c.phialTick, 0.05 + 0.04 * d)
            S.ev = Language.format("LOADED %d PHIALS @%.2f", d, now)
        elseif d < 0 and d >= -10 then
            local n = -d
            thunk(now, math.min(2.0, c.dischargeBase + c.dischargePerPhial * n), 2 + n, 0.2 + 0.05 * n)
            S.ev = Language.format("DISCHARGE %d PHIALS @%.2f", n, now)
        end
    end

    local sw, swPrev = rule_value("sword")
    if is_on(sw) and not is_on(swPrev) and swPrev ~= nil then
        start_haptics(now, c.swordChargedHaptics, 0.08)
        S.ev = Language.format("SWORD CHARGED (RED) @%.2f", now)
    end

    local sh, shPrev = rule_value("shield")
    if is_on(sh) and not is_on(shPrev) and shPrev ~= nil then
        trigger_notch(now, c.trigger)
        thunk(now, c.shieldRumble, c.shieldHaptics, 0.2)
        S.ev = Language.format("SHIELD CHARGED @%.2f", now)
    end

    local ax = rule_value("axe")
    if c.savageBuzz > 0 and is_on(ax) and live("axe") then S.vibWhy[#S.vibWhy + 1] = "Savage Axe" end
    if c.savageBuzz > 0 and is_on(ax) and live("axe") and now - S.lastBuzz >= 0.05 then
        S.lastBuzz = now
        motor_rumble(c.savageBuzz)
    end

    local v = fx_trigger(now)
    if not v then v = S.cbGuarding and c.guardResist or FREE end
    apply_trigger(c.trigger, v)
end

-- ---------- LONG SWORD ----------
-- Hooks are only installed when holding the LS. All 3 are filtered to your character/weapon (co-op).
S.lsHooks, S.lsIai, S.lsKijin, S.lsKijinLast = false, false, false, 0.0
S.lsLvUp, S.lsLastPulse, S.lsPulseUntil, S.lsArmed = false, -10.0, 0.0, false

local function ensure_ls_hooks()
    if S.lsHooks then return end
    S.lsHooks = true
    local iai = sdk.find_type_definition("app.Wp03Action.cIaiWpOff")
    local m = iai and iai:get_method("doEnter")
    if m then
        sdk.hook(m, function(args)
            if S.kind ~= "ls" or not S.charaAddr then return end
            local act = sdk.to_managed_object(args[2])
            if not act then return end
            local ok, ch = pcall(act.call, act, "get_Chara")
            if ok and ch then
                local ok2, addr = pcall(ch.get_address, ch)
                if ok2 and addr == S.charaAddr then S.lsIai = true end
            end
        end, function(retval) return retval end)
    end
    local wp = sdk.find_type_definition("app.cHunterWp03Handling")
    if wp then
        local m2 = wp:get_method("updateKijinCharge()")
        if m2 then
            sdk.hook(m2, function(args)
                if S.kind ~= "ls" or sdk.to_int64(args[2]) ~= S.whPtr then return end
                local now = now_s()
                if not S.lsKijin then
                    S.lsKijin, S.lsArmed, S.lsLvUp = true, false, false
                    S.capturedThisCharge = false
                end
                S.charging = true
                S.lsKijinLast = now
                local c = CFG.ls
                if c.holdHaptic and c.hapticInHook and (not S.lite or now - S.lastBeat >= 0.12) then
                    S.lastBeat = now
                    play_haptic()
                end
            end, function(retval) return retval end)
        end
        local m3 = wp:get_method("doBaseActionEnter")
        if m3 then
            sdk.hook(m3, function(args)
                if S.lsIai and S.kind == "ls" and sdk.to_int64(args[2]) == S.whPtr then S.lsIai = false end
            end, function(retval) return retval end)
        end
    end
    log.info("[HapticPack] Long Sword hooks installed")
end

local function ls_spirit_slash(now, c)
    if now - (S.lsLastSlash or -10) > c.spiritComboWindow then S.lsCombo = 0 end
    S.lsCombo = (S.lsCombo or 0) + 1
    S.lsLastSlash = now
    local spLv = S.lsSpLv
    local lvBonus = (spLv and spLv > 0) and math.min(3, spLv) * c.spiritLevelBonus or 0
    local n = math.min(S.lsCombo, 4)
    local peak = c.spiritBase + c.spiritStep * (n - 1) + lvBonus
    local haptics = c.spiritHaptics + (n >= 3 and 1 or 0)
    local impT, impF = c.spiritImpact, c.spiritImpactFreq + 0.03 * (n - 1)
    if n >= 4 then
        -- Roundslash: combo finisher => heaviest hit, longer trigger impact and stronger rumble
        peak = math.max(peak, c.roundslashRumble + lvBonus)
        haptics = c.roundslashHaptics
        impT, impF = c.spiritImpact * 1.8, math.min(0.5, impF + 0.08)
        S.lsCombo = 0
    end
    S.lsSwing = { start = now, T = c.spiritSwingTime + 0.03 * (n - 1), peak = peak, hit = false, haptics = haptics }
    if impT > 0 then trigger_impact(now, c.trigger, impT, impF) end
    S.ev = Language.format("SPIRIT BLADE %d (strength %.2f) @%.2f", n, peak, now)
end

local function update_ls(now, c, pad)
    ensure_ls_hooks()
    ensure_sound_hook()

    if S.lsKijin and now - S.lsKijinLast > c.kijinTimeout then
        S.lsKijin, S.lsArmed, S.lsLvUp = false, false, false
        S.ev = Language.format("SPIRIT CHARGE ENDED @%.2f", now)
    end
    S.charging = S.lsKijin   -- so the hook captures the vibration pattern used while charging

    local active = S.lsKijin and not S.lsIai
    if active and S.lsLvUp and now - S.lsLastPulse > c.lvCooldown then
        S.lsLastPulse, S.lsPulseUntil, S.lsLvUp, S.lsArmed = now, now + c.pulseTime, false, true
        S.ev = Language.format("SPIRIT CHARGE LEVEL UP @%.2f", now)
    end

    if active and c.holdHaptic and not c.hapticInHook then
        local every = S.lite and math.max(0.12, c.holdHapticEvery) or c.holdHapticEvery
        if now - S.lastBeat >= every then
            S.lastBeat = now
            play_haptic()
        end
    end

    -- ---- Spirit Blade ----
    local spLv = rule_value("spiritLv")
    S.lsSpLv = spLv
    if c.spiritEnabled and not S.lsKijin then
        local rt = S.rt
        if rt > 0.6 and (S.lsRtPrev or 0) <= 0.6 and now - (S.lsLastSlash or -10) > 0.15 then
            ls_spirit_slash(now, c)
        end
        S.lsRtPrev = rt
    else
        S.lsRtPrev = S.rt
    end

    local sw = S.lsSwing
    if sw then
        local t = now - sw.start
        if t >= sw.T then
            S.lsSwing = nil
        else
            -- "swoosh" curve: 0 -> peak at 45% -> fade
            local x = t / sw.T
            local amp = (x < 0.45) and (x / 0.45) or (1.0 - (x - 0.45) / 0.55)
            if now - (S.lsLastSwingSend or 0) >= (S.lite and 0.06 or 0.03) then
                S.lsLastSwingSend = now
                motor_rumble(math.max(0.05, sw.peak * amp))
            end
            if not sw.hit and x >= 0.4 then
                sw.hit = true
                start_haptics(now, sw.haptics, 0.035)
            end
        end
    end

    local v = fx_trigger(now)
    if v then
        -- Spirit Blade impact / click effect is running
    elseif S.lsIai then v = c.iaiTrigger
    elseif S.lsKijin then
        if now < S.lsPulseUntil then v = c.pulseTrigger
        elseif S.lsArmed or c.holdFromStart then v = c.kijinTrigger
        else v = FREE end
    else v = FREE end
    apply_trigger(c.trigger, v)
end

-- ---------- SHARED EVENT ENGINE (SnS / DB / Lance / Gunlance / Hunting Horn / IG) ----------
local evState = {}   -- per-event state (active, beat timing...)
local frameVals = {}

local function do_guard(now, c, pad)
    if not c.guardTrigger then S.cbGuarding = false; S.wasGuarding = false; S.emuQuiet = false; return end
    local held = read_trigger(pad, c.trigger == "L" and "get_LTrigger" or "get_RTrigger") > CFG.PRESS_THRESHOLD
    if held then S.guardSince = S.guardSince or now else S.guardSince = nil end
    S.cbGuarding = S.guardSince ~= nil and now - S.guardSince >= c.guardHold
    S.emuQuiet = c.quietGuard or false     -- no friction/tension buzz on the shield trigger (press or release)
    guard_feel(now, c, S.cbGuarding)
    if S.cbGuardHit then
        S.cbGuardHit = false
        if S.cbGuarding and now - (S.lastGuardHit or -10) > 0.25 then
            S.lastGuardHit = now
            -- Power Guard (Lance): guard hits are heavier
            local mul = 1.0
            if c.powerGuardKey and is_on(frameVals[c.powerGuardKey]) and live(c.powerGuardKey) then mul = c.powerGuardHitMul or 1.0 end
            if c.impactTime then
                trigger_impact(now, c.trigger, c.impactTime * mul, c.impactFreq)
                thunk(now, math.min(2.5, c.guardHitRumble * mul), c.guardHitHaptics * mul, c.impactTime * mul + 0.08)
            else
                trigger_notch(now, c.trigger, 0.04, 0.09)
                thunk(now, c.guardHitRumble, c.guardHitHaptics, 0.12)
            end
            S.ev = Language.format(mul > 1.0 and "GUARD HIT (POWER GUARD) @%.2f" or "GUARD HIT @%.2f", now)
        end
    end
end

local function fire_event(now, c, ev, units)
    units = units or 1
    local r = math.min(2.0, (ev.rumble or 0) + (ev.perUnit or 0) * (units - 1))
    local h = (ev.haptics or 0) + (ev.hapticsPerUnit or 0) * (units - 1)
    local t = (ev.time or 0.1) + (ev.timePerUnit or 0) * (units - 1)
    if ev.notch then trigger_notch(now, c.trigger)
    elseif ev.impact then trigger_impact(now, c.trigger, ev.impact, ev.impactFreq or 0.2) end
    if ev.role then
        -- single-motor rumble: "light" = right motor, sharp / "heavy" = left motor, thuddy
        pulse(ev.role, r, t)
        thunk(now, 0, h, t)
    else
        thunk(now, r, h, t)
    end
    S.ev = Language.format("%s x%d @%.2f", ev.label, units, now)
end

-- Effects when ENTERING / LEAVING a state ("active" events), de-flickered with ev.cool
local function ev_edge(now, c, ev, st, enter)
    if now - (st.lastEdge or -10) < (ev.cool or 0) then return end
    st.lastEdge = now
    if enter then
        if ev.notchEnter then trigger_notch(now, c.trigger) end
        thunk(now, ev.enterRumble or 0, ev.enterHaptics or 0, ev.enterTime or 0.15)
    else
        if ev.notchExit then trigger_notch(now, c.trigger) end
        thunk(now, ev.exitRumble or 0, ev.exitHaptics or 0, ev.exitTime or 0.2)
    end
end

local function run_event(now, c, i, ev)
    local st = evState[i]
    if not st then st = { active = false, lastBeat = 0.0, lastRumble = 0.0, since = 0.0 }; evState[i] = st end
    if ev.off then st.active = false; return end
    if not ev.pk then ev.pk = ev.key .. "#p" end

    -- current / previous frame value (allOf = all fields on at once, e.g. IG Triple Up)
    local v, prev
    if ev.allOf then
        local allNow, allPrev, ok = true, true, true
        for _, k in ipairs(ev.allOf) do
            local a, b = frameVals[k], frameVals[k .. "#p"]
            if a == nil or b == nil or not live(k) then ok = false; break end
            if not is_on(a) then allNow = false end
            if not is_on(b) then allPrev = false end
        end
        if ok then v, prev = (allNow and 1 or 0), (allPrev and 1 or 0) end
    else
        v, prev = frameVals[ev.key], frameVals[ev.pk]
    end
    -- unless: this state is "covered" by another (e.g. Archdemon does not count during Demon Mode)
    local blocked = ev.unless ~= nil and is_on(frameVals[ev.unless]) and live(ev.unless)

    if v ~= nil and prev ~= nil and not blocked and now - (st.lastFire or -10) >= (ev.cool or 0) then
        local d = v - prev
        local fired = false
        if ev.on == "down" and d <= -0.5 and d >= -50 then
            if not ev.shot or now - (S.lastShot or -10) > (c.shotGap or 0.06) then
                if ev.shot then S.lastShot = now end
                fire_event(now, c, ev, math.floor(-d + 0.5)); fired = true
            end
        elseif ev.on == "up" and d >= 0.5 and (d <= 50 or ev.big) then
            -- big: the field is a timer (e.g. IG extracts) => fire on gain and on refresh, only for big jumps
            if not ev.big or d >= math.max(0.5, 0.25 * math.abs(prev)) then
                fire_event(now, c, ev, ev.big and 1 or math.floor(d + 0.5)); fired = true
            end
        elseif ev.on == "enter" and is_on(v) and not is_on(prev) then
            fire_event(now, c, ev, 1); fired = true
        elseif ev.on == "leave" and not is_on(v) and is_on(prev) then
            fire_event(now, c, ev, 1); fired = true
        end
        if fired then st.lastFire = now end
    end
    if ev.shot then
        -- Detect shots from 3 sources (first one wins, de-duplicated by shotGap):
        --  1) ammo field goes down (handled in the "down" branch above)
        --  2) the game vibrates while the trigger is held  => also catches automatic fire
        --  3) trigger pulled past the break point (when there is no valid ammo field yet)
        local st2 = S.rules[ev.key]
        local fieldOK = st2 and st2.idx > 1 and live(ev.key)
        local edge = S.rt > 0.6 and (S.rtPrevGun or 0) <= 0.6
        if (S.gunShotPending or (edge and not fieldOK)) and now - (S.lastShot or -10) > (c.shotGap or 0.06) then
            S.lastShot = now
            fire_event(now, c, ev, 1)
        end
    end
    if ev.on ~= "active" then return end

    -- no valid field yet: guess from R2 (each press = one "toggle" hit, no state kept so it cannot drift)
    if ev.edgeFallback then
        local rs = S.rules[ev.key]
        if not (rs and rs.idx > 1 and live(ev.key)) and S.rt > 0.6 and (S.rtPrevGun or 0) <= 0.6 then
            ev_edge(now, c, ev, st, true)
            S.ev = Language.format("%s (guessed from R2) @%.2f", ev.label, now)
        end
    end

    local on = is_on(v) and live(ev.key) and not blocked
    if on then
        S.vibWhy[#S.vibWhy + 1] = ev.label
        if not st.active then
            st.active, st.since = true, now
            if ev.heart or ev.step then st.lastBeat = now end      -- the first beat comes after the "enter" hit
            ev_edge(now, c, ev, st, true)
            S.ev = Language.format("%s @%.2f", ev.label, now)
        end
        local rr = ev.rumble or 0
        if ev.ramp then
            -- rumble ramps up with hold time (charging)
            local rp = ev.ramp
            rr = rp[1] + (rp[2] - rp[1]) * math.min(1.0, (now - st.since) / rp[3])
        end
        if rr > 0 and now - st.lastRumble >= (S.lite and 0.1 or 0.05) then
            st.lastRumble = now
            motor_rumble(rr)
        end
        local beat = ev.beat or 0
        if beat > 0 and S.lite then beat = math.max(beat, 0.12) end
        if beat > 0 and now - st.lastBeat >= beat then
            st.lastBeat = now
            if ev.heart then
                -- heartbeat: "lub" (strong) then "dub" (lighter) 0.16s later, heavy motor
                pulse("heavy", ev.heart, 0.07)
                pulse("heavy", ev.heart * 0.65, 0.06, 0.16)
            elseif ev.step then
                -- footsteps: alternate left (heavy motor) / right (light motor)
                st.foot = not st.foot
                pulse(st.foot and "heavy" or "light", ev.step, 0.06)
            else
                play_haptic()
                if ev.beatTrigger and c.beatTrigger then S.beatTrigUntil = now + (c.beatTriggerTime or 0.06) end
            end
        end
    elseif st.active then
        st.active = false
        ev_edge(now, c, ev, st, false)
    end
end

local function update_generic(now, c, pad)
    clear_why()

    -- read every field exactly once per frame
    for k in pairs(frameVals) do frameVals[k] = nil end
    for _, r in ipairs(RULES[S.kind] or {}) do
        local v, prev = rule_value(r.key)
        if not r.pk then r.pk = r.key .. "#p" end
        frameVals[r.key] = v
        frameVals[r.pk] = prev
    end
    do_guard(now, c, pad)

    for i, ev in ipairs(c.events) do run_event(now, c, i, ev) end

    S.rtPrevGun = S.rt
    S.gunShotPending = false
    S.gunFiring = c.gun and S.rt > 0.5 or false
    local v = fx_trigger(now)
    if not v and c.beatTrigger and now < (S.beatTrigUntil or 0) then v = c.beatTrigger end
    -- out of ammo: dead trigger (fully loose)
    if not v and c.slackWhenEmpty and c.slackEnabled then
        local st3 = S.rules[c.slackWhenEmpty]
        if st3 and st3.idx > 1 and live(c.slackWhenEmpty) and frameVals[c.slackWhenEmpty] == 0 then v = FREE end
    end
    if not v then
        if c.shieldWall and c.guardTrigger then v = c.shieldWall
        elseif S.cbGuarding then v = c.guardResist
        elseif c.idleTrigger and c.idleOn ~= false then v = c.idleTrigger
        else v = FREE end
    end
    apply_trigger(c.trigger, v)
end

local function generic_menu(c)
    local ch
    if c.guardTrigger or c.guardHitRumble > 0 then
        ch, c.guardTrigger = imgui.checkbox("Shield trigger (wall at the start of the pull)", c.guardTrigger)
        if not c.shieldWall then
            local a2
            a2, c.guardResist[1] = imgui.slider_float("Trigger force while guarding", c.guardResist[1], 0.0, 1.0)
            if a2 then S.sentKey = nil end
        end
        if c.shieldWall then
            local a, b, d
            a, c.shieldWall[1] = imgui.slider_float("Shield: wall stiffness", c.shieldWall[1], 0.0, 1.0)
            b, c.shieldWall[4] = imgui.slider_float("Shield: wall depth (travel)", c.shieldWall[4], 0.05, 1.0)
            d, c.shieldWall[5] = imgui.slider_float("Shield: snap", c.shieldWall[5], 0.0, 1.0)
            if a or b or d then S.sentKey = nil end
        end
        local e
        if c.guardRaise then
            e, c.guardBrace = imgui.slider_float("Holding shield: strain rumble (rumble controllers, 0 = off)", c.guardBrace or 0, 0.0, 0.5)
        end
        e, c.guardHitRumble = imgui.slider_float("Guard hit: body rumble", c.guardHitRumble, 0.0, 2.5)
        e, c.guardHitHaptics = imgui.slider_float("Guard hit: haptic pulses", c.guardHitHaptics, 0.0, 8.0)
        if c.impactTime then
            e, c.impactFreq = imgui.slider_float("Guard hit: trigger vibration", c.impactFreq, 0.0, 0.5)
            e, c.impactTime = imgui.slider_float("Guard hit: impact time", c.impactTime, 0.03, 0.3)
        end
        if imgui.button("Test guard hit (hold R2 to feel it)") then
            local t = now_s()
            if c.impactTime then trigger_impact(t, c.trigger, c.impactTime, c.impactFreq)
            else trigger_notch(t, c.trigger, 0.04, 0.09) end
            thunk(t, c.guardHitRumble, c.guardHitHaptics, (c.impactTime or 0.04) + 0.08)
        end
    end
    if c.idleTrigger then
        local a, b, d, e
        a, c.idleOn = imgui.checkbox("R2 has one click point (piano key / trigger break)", c.idleOn ~= false)
        b, c.idleTrigger[1] = imgui.slider_float("Click: force", c.idleTrigger[1], 0.0, 1.0)
        d, c.idleTrigger[3] = imgui.slider_float("Click: start", c.idleTrigger[3], 0.0, 0.9)
        e, c.idleTrigger[4] = imgui.slider_float("Click: end", c.idleTrigger[4], 0.1, 1.0)
        if a or b or d or e then S.sentKey = nil end
    end
    if c.beatTrigger then
        local a
        a, c.beatTrigger[2] = imgui.slider_float("Performance: trigger pulse on each beat", c.beatTrigger[2], 0.0, 0.5)
    end
    if c.slackWhenEmpty then
        local a
        a, c.slackEnabled = imgui.checkbox("Empty magazine = loose trigger (needs the correct ammo field first)", c.slackEnabled)
        if a then S.sentKey = nil end
    end
    if c.guardTrigger and c.soundGuardHit ~= nil then
        local a
        a, c.soundGuardHit = imgui.checkbox("Rumble controllers: detect guard hits from sound events", c.soundGuardHit)
    end
    for i, ev in ipairs(c.events) do
        local a, en = imgui.checkbox(Language.translate(ev.label) .. "  (" .. ev.on .. ")##en" .. i, not ev.off)
        if a then ev.off = not en end
        if ev.on == "active" then
            if ev.enterRumble ~= nil then
                a, ev.enterRumble = imgui.slider_float(Language.translate("Rumble on enter##ev") .. i, ev.enterRumble, 0.0, 2.0)
            end
            if ev.ramp then
                a, ev.ramp[1] = imgui.slider_float(Language.translate("Charge rumble: start##ev") .. i, ev.ramp[1], 0.0, 1.0)
                a, ev.ramp[2] = imgui.slider_float(Language.translate("Charge rumble: max##ev") .. i, ev.ramp[2], 0.0, 1.5)
                a, ev.ramp[3] = imgui.slider_float(Language.translate("Charge rumble: ramp time (s)##ev") .. i, ev.ramp[3], 0.2, 3.0)
            else
                a, ev.rumble = imgui.slider_float(Language.translate("Background rumble##ev") .. i, ev.rumble or 0, 0.0, 1.0)
            end
            if ev.heart then
                a, ev.heart = imgui.slider_float(Language.translate("Heartbeat: strength##ev") .. i, ev.heart, 0.0, 1.0)
                a, ev.beat = imgui.slider_float(Language.translate("Heartbeat: interval (s)##ev") .. i, ev.beat or 0.85, 0.4, 1.5)
            elseif ev.step then
                a, ev.step = imgui.slider_float(Language.translate("Footsteps: strength##ev") .. i, ev.step, 0.0, 1.0)
                a, ev.beat = imgui.slider_float(Language.translate("Footsteps: interval (s)##ev") .. i, ev.beat or 0.28, 0.15, 0.6)
            elseif ev.beat ~= nil then
                a, ev.beat = imgui.slider_float(Language.translate("Haptic beat (s, 0 = off)##ev") .. i, ev.beat or 0, 0.0, 1.0)
            end
            a, ev.exitRumble = imgui.slider_float(Language.translate("Rumble on exit##ev") .. i, ev.exitRumble or 0, 0.0, 2.0)
            if ev.enterRumble ~= nil and imgui.button(Language.translate("Test enter##ev") .. i) then
                local t = now_s()
                if ev.notchEnter then trigger_notch(t, c.trigger) end
                thunk(t, ev.enterRumble, ev.enterHaptics or 0, ev.enterTime or 0.15)
            end
            if ev.heart then
                imgui.same_line()
                if imgui.button(Language.translate("Test heartbeat##ev") .. i) then
                    pulse("heavy", ev.heart, 0.07); pulse("heavy", ev.heart * 0.65, 0.06, 0.16)
                end
            end
        else
            a, ev.rumble = imgui.slider_float(Language.translate("Body rumble##ev") .. i, ev.rumble or 0, 0.0, 2.0)
            a, ev.haptics = imgui.slider_float(Language.translate("Haptic pulses##ev") .. i, ev.haptics or 0, 0.0, 8.0)
            if ev.impact then
                a, ev.impactFreq = imgui.slider_float(Language.translate("Trigger kick: vibration##ev") .. i, ev.impactFreq, 0.0, 0.6)
                a, ev.impact = imgui.slider_float(Language.translate("Trigger kick: time##ev") .. i, ev.impact, 0.02, 0.2)
            end
            if imgui.button("Test##ev" .. i) then fire_event(now_s(), c, ev, 1) end
        end
    end
end

-- =============================================
-- BOWGUNS (Light / Heavy Bowgun)
-- =============================================
-- Profile per ammo type:
--   trig   = R2 force while ready to fire {force, vib, from, to, snap}: the trigger pull of each ammo type
--   impact/freq = trigger kicks back when the gun fires; rumble/rtime/haptics = body recoil
--   tail   = small trailing beats (pierce ammo going through layers of flesh)
--   delay  = delayed blast after the shot (Sticky / Cluster / Slicing)
local GUN_PROFILES = {
    normal  = { label = "Normal",  trig = { 0.50, 0.0, 0.15, 0.27, 1.0 }, impact = 0.05, freq = 0.30,
                rumble = 0.45, rtime = 0.06, haptics = 1 },                                   -- crisp "pak", quick kick
    pierce  = { label = "Pierce",   trig = { 0.55, 0.0, 0.18, 0.32, 1.0 }, impact = 0.10, freq = 0.18,
                rumble = 0.55, rtime = 0.14, haptics = 1, tail = { n = 3, gap = 0.05, r = 0.3 } },  -- long rifle-like pull, long recoil + 3 piercing beats
    -- SHOTGUN: heavy short pull -> BOOM (trigger kicks back hard) -> trigger slips loose (reset)
    --          -> trigger locked while racking -> "clack-clack" pump -> trigger returns
    --          body: big blast that fades fast + pellet patter on the target + 2 pump clacks
    spread  = { label = "Spread",     trig = { 0.65, 0.0, 0.12, 0.24, 1.0 }, impact = 0.10, freq = 0.5,
                rumble = 1.3, rtime = 0.10, haptics = 2,
                shotgun = { boom = 1.3, pellets = 4, pelletGap = 0.03, slip = 0.06, lock = 0.22,
                            pump = true, pumpGap = 0.10, pumpRumble = 0.35 } },
    sticky  = { label = "Sticky", trig = { 0.55, 0.0, 0.15, 0.28, 1.0 }, impact = 0.05, freq = 0.25,
                rumble = 0.4, rtime = 0.06, haptics = 1, delay = { t = 1.0, r = 1.0, time = 0.15, h = 2 } },
    cluster = { label = "Cluster",   trig = { 0.60, 0.0, 0.15, 0.28, 1.0 }, impact = 0.10, freq = 0.40,
                rumble = 1.0, rtime = 0.12, haptics = 2, delay = { t = 0.35, r = 0.5, time = 0.06, burst = 4, gap = 0.07 } },
    slicing = { label = "Slicing",    trig = { 0.50, 0.0, 0.15, 0.27, 1.0 }, impact = 0.05, freq = 0.25,
                rumble = 0.4, rtime = 0.06, haptics = 1, delay = { t = 0.6, r = 0.3, time = 0.04, burst = 5, gap = 0.04 } },
    wyvern  = { label = "Wyvern", trig = { 0.70, 0.0, 0.15, 0.30, 1.0 }, impact = 0.15, freq = 0.50,
                rumble = 1.6, rtime = 0.35, haptics = 4 },
    element = { label = "Element", trig = { 0.45, 0.0, 0.15, 0.25, 1.0 }, impact = 0.04, freq = 0.25,
                rumble = 0.3, rtime = 0.05, haptics = 1 },                                    -- fast, light, crisp shots
    status  = { label = "Status", trig = { 0.40, 0.0, 0.15, 0.25, 1.0 }, impact = 0.04, freq = 0.12,
                rumble = 0.25, rtime = 0.05, haptics = 1 },                                   -- soft "thup"
    support = { label = "Support (Recover/Buff/Tranq)", trig = { 0.35, 0.0, 0.15, 0.24, 1.0 }, impact = 0.03, freq = 0.08,
                rumble = 0.15, rtime = 0.04, haptics = 0 },
}
local GUN_ORDER = { "normal", "pierce", "spread", "sticky", "cluster", "slicing", "wyvern", "element", "status", "support" }
local GUN_LABELS = {}
for i, k in ipairs(GUN_ORDER) do GUN_LABELS[i] = GUN_PROFILES[k].label end

-- Guess the ammo type from the game's enum name (English or romaji)
local AMMO_KEYWORDS = {
    { "wyvern", { "wyvern", "ryugeki", "dragonstrike" } },
    { "spread", { "spread", "sandan", "diffus", "sanran" } },
    { "pierce", { "pierce", "penetrat", "kantsu", "kantu" } },
    { "sticky", { "sticky", "tekko", "adhes" } },
    { "cluster", { "cluster", "kakusan" } },
    { "slicing", { "slic", "zanretsu", "zanretu", "slash" } },
    { "element", { "fire", "flam", "water", "thunder", "ice", "freez", "dragon", "element", "zokusei" } },
    { "status", { "poison", "para", "sleep", "exhaust", "stun", "doku", "mahi", "nemuri" } },
    { "support", { "recover", "heal", "kaifuku", "demon", "armor", "kijin", "kouka", "tranq", "capture", "masui" } },
    { "normal", { "normal", "tsujo", "tuujou", "tujo" } },
}
local function classify_ammo_name(name)
    if not name then return nil end
    local n = name:lower()
    for _, e in ipairs(AMMO_KEYWORDS) do
        for _, w in ipairs(e[2]) do if n:find(w, 1, true) then return e[1] end end
    end
    return nil
end

local enumNameCache = {}
local function enum_name(tname, value)
    if not tname or value == nil then return nil end
    local t = enumNameCache[tname]
    if not t then
        t = {}
        for n, v in pairs(read_enum(tname)) do t[v] = n end
        enumNameCache[tname] = t
    end
    return t[value]
end

local function save_gun()
    local ok, err = pcall(json.dump_file, SAVE_FILE, SAVE)
    if not ok then log.info("[HapticPack] Could not save: " .. tostring(err)) end
end

S.gunOverride = 1          -- 1 = auto, otherwise = index in GUN_ORDER + 1
S.gunDelayed = {}

-- Current ammo type -> profile key
local function current_ammo(c)
    if S.gunOverride > 1 then return GUN_ORDER[S.gunOverride - 1], "forced" end
    local st = S.rules["ammoType"]
    local v = nil
    if st then v = (rule_value("ammoType")) end
    S.gunTypeVal = v
    S.gunTypeName = nil
    if v == nil then return "normal", "default" end
    local map = (SAVE.gunMap[S.kind] or {})[tostring(math.floor(v))]
    if map and GUN_PROFILES[map] then return map, "your mapping" end
    local f = S.fields[st.idx - 1]
    local nm = f and f.kind == "enum" and enum_name(f.tname, math.floor(v)) or nil
    S.gunTypeName = nm
    local k = classify_ammo_name(nm)
    if k then return k, "enum name" end
    return "normal", "unknown (defaulting to Normal)"
end

local function scaled(c, prof, key, base)
    if c.heavy then
        if key == "force" then return math.min(1.0, base + 0.1) end
        if key == "rumble" then return math.min(2.0, base * 1.3) end
        if key == "impact" then return base * 1.3 end
    end
    return base
end

local SG_WALL = { 1.0, 0.0, 0.0, 1.0, 1.0 }
local function fire_shotgun(now, c, prof, kick)
    local sg = prof.shotgun
    local heavyK = c.heavy and 1.3 or 1.0
    local boom = math.min(2.0, sg.boom * heavyK * kick)
    -- ---- trigger ----
    local seq = {
        { scaled(c, prof, "impact", prof.impact) * kick, { 1.0, math.min(0.6, prof.freq * heavyK), 0.0, 1.0, 1.0 } }, -- BOOM: trigger kicks back
        { sg.slip, FREE },                                                                         -- trigger slips loose (reset)
        { sg.lock, SG_WALL },                                                                      -- trigger locked while racking
    }
    if sg.pump then
        seq[#seq + 1] = { 0.04, FREE }; seq[#seq + 1] = { 0.06, SG_WALL }                         -- "clack"
        seq[#seq + 1] = { sg.pumpGap - 0.04, FREE }; seq[#seq + 1] = { 0.06, SG_WALL }            -- "clack"
    end
    S.fx = { side = c.trigger, start = now, seq = seq }
    -- ---- body: big blast then a quick fade (decaying curve) ----
    start_haptics(now, prof.haptics, 0.02)
    local env = { { 0.0, 1.0 }, { 0.035, 0.7 }, { 0.07, 0.45 }, { 0.11, 0.25 }, { 0.15, 0.1 } }
    for _, e in ipairs(env) do
        S.gunDelayed[#S.gunDelayed + 1] = { at = now + e[1], n = 1, gap = 0.05, r = boom * e[2], time = 0.05, h = 0 }
    end
    -- ---- pellets hitting the target: small patter ----
    if sg.pellets > 0 then
        S.gunDelayed[#S.gunDelayed + 1] = { at = now + 0.05, n = math.floor(sg.pellets + 0.5), gap = sg.pelletGap, r = 0.0, time = 0.0, h = 1 }
    end
    -- ---- pump: 2 clacks ----
    if sg.pump then
        local t1 = prof.impact + sg.slip + sg.lock
        S.gunDelayed[#S.gunDelayed + 1] = { at = now + t1 + 0.04, n = 2, gap = sg.pumpGap, r = sg.pumpRumble, time = 0.04, h = 1 }
    end
    S.gunShots = (S.gunShots or 0) + 1
    S.ev = Language.format("SHOT %s @%.2f", prof.label, now)
end

local function fire_shot(now, c, prof)
    local kick = (c.heavy and 1.0) or ((S.gunRapid and c.rapidScaleKick) or 1.0)
    if prof.shotgun then return fire_shotgun(now, c, prof, kick) end
    trigger_impact(now, c.trigger, scaled(c, prof, "impact", prof.impact) * kick, prof.freq)
    thunk(now, scaled(c, prof, "rumble", prof.rumble) * kick, prof.haptics, prof.rtime)
    if prof.tail then
        S.gunDelayed[#S.gunDelayed + 1] = { at = now + prof.tail.gap, n = prof.tail.n, gap = prof.tail.gap, r = prof.tail.r * kick, time = 0.04, h = 1 }
    end
    if prof.delay then
        local d = prof.delay
        S.gunDelayed[#S.gunDelayed + 1] = { at = now + d.t, n = d.burst or 1, gap = d.gap or 0.05,
                                            r = d.r, time = d.time, h = d.h or 1 }
    end
    S.gunShots = (S.gunShots or 0) + 1
    S.ev = Language.format("SHOT %s @%.2f", prof.label, now)
end

-- dropped noticeably (counter down >= 1, or gauge down >= 25% of the highest value seen)
local function dropped(key)
    local st = S.rules[key]
    if not st or st.idx <= 1 then return false end
    local v, prev = rule_value(key)
    if v == nil or prev == nil then return false end
    st.gmax = math.max(st.gmax or 0, v)
    local d = prev - v
    return d >= 0.5 or (st.gmax > 0 and d >= 0.25 * st.gmax and d > 0.01)
end

local function update_gun(now, c, pad)
    clear_why()
    local ammoKey, src = current_ammo(c)
    local prof = GUN_PROFILES[ammoKey]
    S.gunAmmo, S.gunAmmoSrc = ammoKey, src

    local modeV = rule_value("mode")
    local modeOn = is_on(modeV) and live("mode")
    S.gunRapid = (not c.heavy) and modeOn
    local ignition = c.heavy and modeOn

    -- ammo count: down = one shot, up = reload
    local ammoV, ammoPrev = rule_value("ammo")
    local fieldOK = S.rules["ammo"] and S.rules["ammo"].idx > 1 and live("ammo")
    if ammoV and ammoPrev then
        local d = ammoV - ammoPrev
        if d >= 0.5 and d <= 50 then
            trigger_notch(now, c.trigger)
            thunk(now, c.heavy and 0.5 or 0.3, c.heavy and 3 or 2, c.heavy and 0.12 or 0.08)
            S.ev = Language.format("RELOAD @%.2f", now)
        end
    end

    -- ===== Ignition (HBG) =====
    local rtHeld = S.rt > 0.5
    local ignTrig = nil
    if ignition then
        S.vibWhy[#S.vibWhy + 1] = "Ignition"
        if rtHeld then
            S.ignStart = S.ignStart or now
            local p = math.min(1.0, (now - S.ignStart) / math.max(0.2, c.ignitionSpinUp))
            local style = c.ignitionStyle
            local every = S.lite and 0.1 or 0.04
            if style == "heart" then
                ignTrig = { 0.8, 0.12 + 0.25 * p, 0.0, 1.0, 0.8 }
                if now - (S.ignLastR or 0) >= every then S.ignLastR = now; motor_rumble(0.35 + 0.65 * p) end
                if now - (S.ignLastH or 0) >= (S.lite and 0.12 or 0.06) then S.ignLastH = now; play_haptic() end
            elseif style == "counter" then
                ignTrig = { 0.3 + 0.7 * p, 0.0, 0.0, 1.0, 1.0 }       -- charge: trigger tightens
                if p >= 1.0 and not S.ignFull then S.ignFull = true; start_haptics(now, 2, 0.05) end
            else -- piercer
                ignTrig = { 0.7, 0.2, 0.0, 1.0, 0.6 }
                if now - (S.ignLastR or 0) >= every then S.ignLastR = now; motor_rumble(0.7) end
                if now - (S.ignLastH or 0) >= (S.lite and 0.15 or 0.08) then S.ignLastH = now; play_haptic() end
            end
        elseif S.ignStart then
            local held = now - S.ignStart
            if c.ignitionStyle == "counter" and held > 0.25 then
                local p = math.min(1.0, held / math.max(0.2, c.ignitionSpinUp))
                trigger_impact(now, c.trigger, 0.15, 0.5)
                thunk(now, 1.0 + 0.8 * p, 5, 0.4)
                S.ev = Language.format("WYVERNCOUNTER (%.0f%%) @%.2f", p * 100, now)
            elseif held > 0.25 then
                thunk(now, 0.6, 2, 0.15)    -- tail when firing stops
            end
            S.ignStart, S.ignFull = nil, false
        end
    else
        S.ignStart, S.ignFull = nil, false
    end

    -- ===== Normal shot =====
    if not ignition then
        local edge = S.rt > 0.6 and (S.rtPrevGun or 0) <= 0.6
        local byField = ammoV and ammoPrev and (ammoPrev - ammoV) >= 0.5 and (ammoPrev - ammoV) <= 50
        -- Spread fires slowly (has a reload beat): stop extra game vibration from counting as a 2nd shot
        local gap = prof.shotgun and math.max(c.shotGap, 0.4) or c.shotGap
        if (byField or S.gunShotPending or (edge and not fieldOK)) and now - (S.lastShot or -10) > gap then
            S.lastShot = now
            fire_shot(now, c, prof)
        end
    end

    -- ===== Special ammo =====
    if dropped("special") then
        if c.specialDelay > 0 then
            -- LBG: place mine / stick -> delayed blast
            thunk(now, c.specialRumble, 2, 0.08)
            S.gunDelayed[#S.gunDelayed + 1] = { at = now + c.specialDelay, n = 1, gap = 0.05, r = c.specialBlast, time = 0.25, h = 3 }
        else
            -- HBG Wyvernsnipe: one very heavy piercing shot, long tail
            trigger_impact(now, c.trigger, 0.18, 0.45)
            thunk(now, c.specialRumble, 4, 0.35)
            S.gunDelayed[#S.gunDelayed + 1] = { at = now + 0.12, n = 4, gap = 0.06, r = 0.6, time = 0.05, h = 1 }
        end
        S.ev = Language.format("SPECIAL AMMO @%.2f", now)
    end

    -- ===== Focus Blast =====
    if dropped("focus") then
        trigger_impact(now, c.trigger, 0.14, 0.45)
        thunk(now, c.focusRumble, c.focusHaptics, 0.3)
        S.ev = Language.format("FOCUS BLAST @%.2f", now)
    end

    -- ===== Delayed blast / tail beats =====
    for i = #S.gunDelayed, 1, -1 do
        local d = S.gunDelayed[i]
        if now >= d.at then
            if d.r > 0 then start_rumble(now, d.r, d.time) end
            if d.h > 0 then start_haptics(now, d.h, 0.035) end
            d.n = d.n - 1
            if d.n <= 0 then table.remove(S.gunDelayed, i) else d.at = now + d.gap end
        end
    end

    -- ===== Trigger force =====
    S.rtPrevGun = S.rt
    S.gunShotPending = false
    S.gunFiring = S.rt > 0.5
    if c.triggerOff then
        -- haptics only: trigger always loose, all trigger effects removed (pull weight, kick, reload click, shotgun lock...)
        S.fx = nil
        apply_trigger(c.trigger, FREE)
        return
    end
    if not c.triggerKick then S.fx = nil; ignTrig = nil end   -- keep only the pistol click, no trigger kick/lock
    local v = fx_trigger(now) or ignTrig
    if not v and c.slackEnabled and fieldOK and ammoV == 0 then v = FREE end
    if not v then
        local t = prof.trig
        local force = scaled(c, prof, "force", t[1])
        local tEnd = t[4]
        if S.gunRapid then force = force * c.rapidScaleForce; tEnd = math.min(tEnd, 0.3) end
        S.gunTrig = S.gunTrig or { 0, 0, 0, 0, 0 }
        local g = S.gunTrig
        -- reuse one table so no garbage is created every frame
        g[1], g[2], g[3], g[4], g[5] = force, t[2], t[3], tEnd, t[5]
        v = g
    end
    apply_trigger(c.trigger, v)
end


local function gun_menu(c)
    local ch
    imgui.text(Language.format("Ammo: %s  (source: %s)", GUN_PROFILES[S.gunAmmo or "normal"].label, S.gunAmmoSrc or "?"))
    imgui.text(Language.format("  field value: %s   enum name: %s", tostring(S.gunTypeVal), tostring(S.gunTypeName)))
    imgui.text(Language.format("  %s mode: %s   Shots detected: %d", c.heavy and "Ignition" or "Rapid Fire",
        tostring(is_on(S.rules["mode"] and S.rules["mode"].last) and live("mode")), S.gunShots or 0))

    -- Assign an ammo type to the current value (saved)
    if S.gunTypeVal ~= nil then
        local key = tostring(math.floor(S.gunTypeVal))
        SAVE.gunMap[S.kind] = SAVE.gunMap[S.kind] or {}
        local cur = SAVE.gunMap[S.kind][key]
        local idx = 1
        for i, k in ipairs(GUN_ORDER) do if k == cur then idx = i + 1 end end
        local items = { "(auto guess)" }
        for i, l in ipairs(GUN_LABELS) do items[i + 1] = l end
        local cm, ni = imgui.combo(Language.format("Loaded ammo (value %s) is", tostring(key)), idx, items)
        if cm then
            SAVE.gunMap[S.kind][key] = (ni > 1) and GUN_ORDER[ni - 1] or nil
            save_gun()
        end
    end
    do
        local items = { "Auto" }
        for i, l in ipairs(GUN_LABELS) do items[i + 1] = l end
        local cm, ni = imgui.combo("Force ammo type (when the field is not found)", S.gunOverride, items)
        if cm then S.gunOverride = ni end
    end
    if c.heavy then
        local changed, style = Menu.combo_value("Ignition type (heart = Wyvernheart, counter = Wyverncounter)", c.ignitionStyle, { "heart", "counter", "piercer" })
        if changed then c.ignitionStyle = style; SAVE.ignitionStyle = style; save_gun() end
        Menu.slider("Ignition: spin-up / full charge time", c, "ignitionSpinUp", 0.3, 4.0)
    else
        Menu.slider("Rapid Fire: trigger force (scale)", c, "rapidScaleForce", 0.2, 1.0)
        Menu.slider("Rapid Fire: recoil per shot (scale)", c, "rapidScaleKick", 0.2, 1.0)
    end
    local tc
    tc, c.triggerOff = imgui.checkbox("Vibration only, leave the R2 trigger alone", c.triggerOff)
    if tc then S.sentKey = nil end
    local tk
    tk, c.triggerKick = imgui.checkbox("Trigger kick / lock / click when firing (heavier on the finger)", c.triggerKick)
    if tk then S.sentKey = nil end
    ch, c.slackEnabled = imgui.checkbox("Empty magazine = loose trigger (needs the correct ammo field)", c.slackEnabled)

    -- Tune the profile of the ammo in use
    local prof = GUN_PROFILES[S.gunAmmo or "normal"]
    imgui.text(Language.format("Tune %s:", prof.label))
    local a, b, d, e, f, g
    a, prof.trig[1] = imgui.slider_float("Trigger: click stiffness##gp", prof.trig[1], 0.0, 1.0)
    b, prof.trig[4] = imgui.slider_float("Trigger: click ends at (travel)##gp", prof.trig[4], 0.1, 1.0)
    d, prof.trig[5] = imgui.slider_float("Trigger: snap##gp", prof.trig[5], 0.0, 1.0)
    if a or b or d then S.sentKey = nil end
    e, prof.freq = imgui.slider_float("Trigger kick: vibration##gp", prof.freq, 0.0, 0.6)
    f, prof.impact = imgui.slider_float("Trigger kick: time##gp", prof.impact, 0.0, 0.25)
    g, prof.rumble = imgui.slider_float("Body recoil: strength##gp", prof.rumble, 0.0, 2.0)
    if prof.shotgun then
        local sg = prof.shotgun
        local h1, h2, h3, h4, h5
        h1, sg.boom = imgui.slider_float("Shotgun: blast##sg", sg.boom, 0.3, 2.0)
        h2, sg.pellets = imgui.slider_float("Shotgun: pellet hits##sg", sg.pellets, 0.0, 8.0)
        h3, sg.lock = imgui.slider_float("Shotgun: trigger lock while racking (s)##sg", sg.lock, 0.0, 0.5)
        h4, sg.pump = imgui.checkbox("Shotgun: pump-action clack##sg", sg.pump)
        h5, sg.pumpRumble = imgui.slider_float("Shotgun: pump strength##sg", sg.pumpRumble, 0.0, 1.0)
    end
    if imgui.button("Test one shot (hold R2 to feel it)") then fire_shot(now_s(), c, prof) end
    imgui.same_line()
    if imgui.button("Test Focus Blast") then
        local t = now_s(); trigger_impact(t, c.trigger, 0.14, 0.45); thunk(t, c.focusRumble, c.focusHaptics, 0.3)
    end
end

CFG.sa.update = update_sa
CFG.lbg.update = update_gun
CFG.hbg.update = update_gun
CFG.sns.update = update_generic
CFG.gl.update = update_generic
CFG.hh.update = update_generic
CFG.db.update = update_generic
CFG.lance.update = update_generic
CFG.ig.update = update_generic
CFG.ls.update = update_ls
CFG.cb.update = update_cb

-- =============================================
-- 2-STEP FIELD FINDER: snapshot every field in the ON/FULL state and in the OFF/EMPTY state,
-- fields that differ between the 2 snapshots are candidates. Assign one directly to a tracked item.
-- =============================================
local SNAP = { A = nil, B = nil, list = nil }

local function snapshot()
    local t = {}
    if not S.wh then return t end
    for i, f in ipairs(S.fields) do
        local ok, v = pcall(S.wh.get_field, S.wh, f.name)
        if ok then
            if type(v) == "boolean" then v = v and 1 or 0 end
            v = tonumber(v)
            if v then t[i] = v end
        end
    end
    return t
end

local function build_candidates()
    SNAP.list = {}
    if not (SNAP.A and SNAP.B) then return end
    for i, a in pairs(SNAP.A) do
        local b = SNAP.B[i]
        if b and math.abs(a - b) > 1e-3 then
            local n = S.fields[i].name:lower()
            local score = math.abs(a - b) / math.max(math.abs(a), math.abs(b), 1e-3)
            if n:find("timer", 1, true) or n:find("time", 1, true) or n:find("frame", 1, true) then score = score * 0.3 end
            SNAP.list[#SNAP.list + 1] = { i = i, a = a, b = b, score = score }
        end
    end
    table.sort(SNAP.list, function(x, y) return x.score > y.score end)
end

local function wizard_menu(rules)
    if not imgui.tree_node("2-step Field finder (when auto-detected fields are wrong)") then return end
    imgui.text("1) Get into the ON state (e.g. gauge full), then press Snapshot A")
    imgui.text("2) Wait for the OFF state (e.g. gauge empty), then press Snapshot B")
    imgui.text("3) Assign the right field to the item to track (the value at A is used as \"full\")")
    if imgui.button("Snapshot A (ON / FULL)") then SNAP.A = snapshot(); build_candidates() end
    imgui.same_line()
    if imgui.button("Snapshot B (OFF / EMPTY)") then SNAP.B = snapshot(); build_candidates() end
    imgui.same_line()
    if imgui.button("Clear") then SNAP.A, SNAP.B, SNAP.list = nil, nil, nil end
    imgui.text(Language.format("A: %s   B: %s", SNAP.A and "taken" or "not yet", SNAP.B and "taken" or "not yet"))

    if SNAP.list then
        imgui.text(Language.format("%d fields differ between A and B (sorted by amount of change):", #SNAP.list))
        for k, cand in ipairs(SNAP.list) do
            if k > 25 then break end
            local f = S.fields[cand.i]
            imgui.text(Language.format("%s [%s]: %.3f -> %.3f", f.name, f.kind, cand.a, cand.b))
            for _, r in ipairs(rules) do
                imgui.same_line()
                if imgui.button(r.label .. "##w" .. cand.i .. r.key) then
                    local st = S.rules[r.key]
                    if st then
                        st.idx = cand.i + 1
                        st.last, st.changed, st.maxSeen, st.learnedFull, st.lastPeak, st.wasFull = nil, true, 0, nil, nil, nil
                        if r.type == "full" then
                            st.maxIdx = 1
                            S.ampManual[r.key] = math.max(cand.a, cand.b)
                        end
                        S.ev = Language.format("Assigned %s to %s", f.name, r.label)
                        save_rule(r.key)
                    end
                end
            end
        end
    end
    imgui.tree_pop()
end


local function module_menu(c)
    local ch
    local changed, side = Menu.combo_value("Weapon trigger", c.trigger, { "R", "L" })
    if changed then release_trigger_control(); c.trigger = side end
    if S.kind == "ls" then
        local a, b, d
        a, c.iaiTrigger[1] = imgui.slider_float("Iai: trigger force", c.iaiTrigger[1], 0.0, 1.0)
        b, c.kijinTrigger[1] = imgui.slider_float("Spirit charge: trigger force", c.kijinTrigger[1], 0.0, 1.0)
        d, c.pulseTrigger[2] = imgui.slider_float("Spirit level-up: trigger vibration", c.pulseTrigger[2], 0.0, 1.0)
        if a or b or d then S.sentKey = nil end
        ch, c.holdFromStart = imgui.checkbox("Trigger stiff from the start of the charge (original LS: after the first level-up)", c.holdFromStart)
        ch, c.holdHaptic = imgui.checkbox("Body rumble during spirit charge", c.holdHaptic)
        ch, c.hapticInHook = imgui.checkbox("Follow the game rhythm like the original LS mod (smoothest)", c.hapticInHook)
        Menu.slider("Body rumble interval (s)", c, "holdHapticEvery", 0.0, 0.3)
        imgui.text("Spirit Blade (R2):")
        ch, c.spiritEnabled = imgui.checkbox("Sword-swing feel on Spirit Blade slashes", c.spiritEnabled)
        Menu.slider("Slash 1: strength", c, "spiritBase", 0.0, 1.5)
        Menu.slider("Extra per combo hit", c, "spiritStep", 0.0, 0.5)
        Menu.slider("Swing length (s)", c, "spiritSwingTime", 0.1, 0.5)
        Menu.slider("Trigger: vibration on slash", c, "spiritImpactFreq", 0.0, 0.5)
        Menu.slider("Trigger: impact time", c, "spiritImpact", 0.0, 0.15)
        Menu.slider("Roundslash: strength", c, "roundslashRumble", 0.0, 2.5)
        Menu.slider("Spirit level: bonus per level", c, "spiritLevelBonus", 0.0, 0.4)
        imgui.text(Language.format("Current combo: %d", S.lsCombo or 0))
        if imgui.button("Test one slash (press repeatedly = combo)") then
            local t = now_s()
            if t - (S.lsLastSlash or -10) > 0.15 then ls_spirit_slash(t, c) end
        end
        imgui.text(Language.format("Iai: %s   Spirit charge: %s   stiff trigger: %s", tostring(S.lsIai), tostring(S.lsKijin), tostring(S.lsArmed)))
    elseif c.gunModule then
        gun_menu(c)
    elseif c.generic then
        generic_menu(c)
    elseif S.kind == "sa" then
        ch, c.morphOn = imgui.checkbox("On: rumble on morph", c.morphOn)
        ch, c.reloadOn = imgui.checkbox("On: rumble when the switch gauge reloads", c.reloadOn)
        ch, c.dischargeOn = imgui.checkbox("On: rumble on Discharge", c.dischargeOn)
        ch, c.morphNotch = imgui.checkbox("Trigger click on morph", c.morphNotch)
        ch, c.morphFromTrigger = imgui.checkbox("Detect morph from trigger pulls (only when there is no mode field)", c.morphFromTrigger)
        Menu.slider("New mode must hold (s) to count as a morph", c, "morphStable", 0.05, 1.0)
        Menu.slider("Discharge must last (s) before it rumbles", c, "dischargeHold", 0.0, 1.0)
        Menu.slider("Morph: body rumble", c, "morphRumble", 0.0, 1.5)
        Menu.slider("Discharge: start rumble", c, "dischargeRumbleMin", 0.0, 1.0)
        Menu.slider("Discharge: end rumble", c, "dischargeRumbleMax", 0.0, 2.0)
        Menu.slider("Discharge: ramp time", c, "dischargeRamp", 0.3, 5.0)
        Menu.slider("Finisher burst: rumble", c, "finisherRumble", 0.0, 2.5)
        if imgui.button("Test morph") then S.lastMorph = -10; trigger_notch(now_s(), c.trigger); thunk(now_s(), c.morphRumble, c.morphHaptics, 0.1) end
        imgui.same_line()
        if imgui.button("Test finisher burst") then thunk(now_s(), c.finisherRumble, c.finisherHaptics, c.finisherTime) end
    else
        ch, c.guardTrigger = imgui.checkbox("Trigger force when guarding", c.guardTrigger)
        local a
        a, c.guardResist[1] = imgui.slider_float("Guard trigger force", c.guardResist[1], 0.0, 1.0)
        a, c.guardResist[5] = imgui.slider_float("Guard snap", c.guardResist[5], 0.0, 1.0)
        Menu.slider("Guard hit: body rumble", c, "guardHitRumble", 0.0, 2.0)
        Menu.slider("Phial load: rumble per phial", c, "phialTick", 0.0, 1.0)
        Menu.slider("Phial discharge: base rumble", c, "dischargeBase", 0.0, 1.5)
        Menu.slider("Phial discharge: extra per phial", c, "dischargePerPhial", 0.0, 0.6)
        Menu.slider("Shield charged: rumble", c, "shieldRumble", 0.0, 2.0)
        Menu.slider("Savage Axe: grinding buzz (0 = off)", c, "savageBuzz", 0.0, 0.6)
        if imgui.button("Test guard hit") then trigger_notch(now_s(), c.trigger, 0.04, 0.09); thunk(now_s(), c.guardHitRumble, c.guardHitHaptics, 0.12) end
        imgui.same_line()
        if imgui.button("Test 5-phial discharge") then thunk(now_s(), math.min(2.0, c.dischargeBase + c.dischargePerPhial * 5), 7, 0.45) end
    end

    wizard_menu(RULES[S.kind] or {})
    imgui.text("Tracked fields (auto-detected; if wrong, use the Field finder above):")
    for _, r in ipairs(RULES[S.kind] or {}) do
        local st = S.rules[r.key]
        if st then
            local c2, ni2 = imgui.combo(r.label, st.idx, S.fieldNames)
            if c2 then
                st.idx = ni2; st.last = nil; st.maxSeen = 0; st.learnedFull = nil; st.lastPeak = nil
                if r.type == "full" then st.maxIdx = find_max_field(ni2) end
                save_rule(r.key)
            end
            imgui.same_line()
            imgui.text(st.last ~= nil and Language.format("= %.2f", st.last) or "")
        end
    end
end

-- =============================================
-- MAIN LOOP
-- =============================================
-- =============================================
-- DUALSENSE BLUETOOTH BRIDGE (optional plugin reframework/plugins/MHWHapticBT.dll)
-- The plugin writes reframework/data/MHWHapticBT_status.json every second; we read it every 2 s.
-- When it reports a DualSense on Bluetooth, body effects are sent as motor requests, which the plugin
-- turns into real haptics. Settings for the plugin go to MHWHapticBT_config.json.
-- =============================================
S.bt, S.btLive, S.btLastTick, S.btTickSeenAt, S.btLastRead = nil, false, nil, -10.0, -10.0
S.btMode = "auto"                 -- "auto" | "off"
local BT_DEFAULTS = { enabled = true, triggers = true, gain = 0.6, heavyHz = 55, lightHz = 150, holdMs = 70,
                      swap = false, unsignedPcm = false, testPulse = 0, trigGain = 1.3,
                      hitGain = 0.55, pulseGain = 0.3, gameHaptics = false,
                      flags11 = 0xFE, trigRefreshMs = 500, waveMode = 2, testTrigger = 0,
                      keepAliveMs = 20000, prerollReports = 3, curveK = 1.8, releaseMs = 45, leftTrig = 0, presetMode = 1, gameRumble = 0 }
local BTCFG = {}
for k, v in pairs(BT_DEFAULTS) do BTCFG[k] = v end
if type(SAVE.bt) == "table" then
    for k, v in pairs(SAVE.bt) do if BT_DEFAULTS[k] ~= nil and type(v) == type(BT_DEFAULTS[k]) then BTCFG[k] = v end end
    -- settings that were only exposed in test builds always come back to their tuned defaults
    for _, k in ipairs({ "flags11", "waveMode", "keepAliveMs", "prerollReports", "trigRefreshMs", "holdMs", "unsignedPcm", "gameHaptics" }) do
        BTCFG[k] = BT_DEFAULTS[k]
    end
end
if SAVE.btMode == "off" or SAVE.btMode == "auto" then S.btMode = SAVE.btMode end
if not SAVE.btHitFix then
    if BTCFG.hitGain and BTCFG.hitGain < 0.5 then BTCFG.hitGain = BT_DEFAULTS.hitGain end
    SAVE.btHitFix = true
    SAVE.bt = BTCFG
    pcall(json.dump_file, SAVE_FILE, SAVE)
end
S.btHitGain = BTCFG.hitGain
S.btPresetMode = BTCFG.presetMode or 1
BTCFG.gameRumble = (S.btPresetMode == 2) and 1 or 0
S.fieldLogOn = false   -- research tool (field-change log), off in release builds
S.btHitGain, S.btHapticPulse, S.btGameHaptics = BTCFG.hitGain, BTCFG.pulseGain, BTCFG.gameHaptics

local function save_bt()
    BTCFG.enabled = S.btMode ~= "off"
    SAVE.bt, SAVE.btMode = BTCFG, S.btMode
    pcall(json.dump_file, SAVE_FILE, SAVE)
    local ok, err = pcall(json.dump_file, "MHWHapticBT_config.json", BTCFG)
    if not ok then log.info("[HapticPack][BT] could not write MHWHapticBT_config.json: " .. tostring(err)) end
end
save_bt()   -- make sure the plugin sees the current settings on start

local function update_bt(now)
    if now - S.btLastRead < 2.0 then return end
    S.btLastRead = now
    local ok, st = pcall(json.load_file, "MHWHapticBT_status.json")
    if not ok or type(st) ~= "table" then
        if S.bt ~= nil then log.info("[HapticPack][BT] status file gone -> bridge off") end
        S.bt, S.btLive = nil, false
    else
        S.bt = st
        if st.tick ~= S.btLastTick then S.btLastTick, S.btTickSeenAt = st.tick, now end
        -- the status file stays on disk after the game closes: only trust it while it keeps updating
        S.btLive = now - S.btTickSeenAt < 5.0
    end
    local want = S.btMode ~= "off" and S.btLive and S.bt ~= nil and S.bt.bluetooth == true and S.bt.open == true
                 and S.out == "dualsense"
    if want ~= S.btBridge then
        S.btBridge = want
        log.info(string.format("[HapticPack][BT] bridge %s (plugin live=%s bluetooth=%s open=%s out=%s mode=%s)",
            want and "ON: body effects -> motor requests -> plugin haptics" or "OFF",
            tostring(S.btLive), tostring(S.bt and S.bt.bluetooth), tostring(S.bt and S.bt.open), S.out, S.btMode))
    end
end

local perf = { last = 0.0, avg = 0.0, peak = 0.0, peakAt = 0.0 }

local function frame_body()
    local now = now_s()
    local pad = get_pad()
    update_detect(now, pad)
    update_bt(now)
    process_pulses()
    if body_via_motors() and S.gameVibOn then
        if S.motorHookOn and not S.motorHook then ensure_motor_hook() end
        if not S.soundHookInstalled then ensure_sound_hook() end
        process_game_motor()
    end
    if pad then
        S.lt = read_trigger(pad, "get_LTrigger")
        S.rt = read_trigger(pad, "get_RTrigger")
    end

    -- Weapon detection
    local chara = get_chara(now)
    local wh = nil
    if chara then
        if S.whMFor ~= chara then
            S.whMFor = chara
            local td = chara:get_type_definition()
            S.whM = td and td:get_method("get_WeaponHandling") or false
        end
        local ok, r
        if S.whM then ok, r = pcall(S.whM.call, S.whM, chara) else ok, r = pcall(chara.call, chara, "get_WeaponHandling") end
        if ok then wh = r else S.chara = nil end
    end
    S.wh = wh
    local typeName = ""
    local td = nil
    if wh then
        -- only re-query the type when the WeaponHandling object changes (saves work every frame)
        local okp, ptr = pcall(wh.get_address, wh)
        if not okp then ptr = tostring(wh) end
        if ptr ~= S.whPtr then
            S.whPtr = ptr
            S.whTd = wh:get_type_definition()
            S.whTypeName = S.whTd and S.whTd:get_full_name() or ""
        end
        td, typeName = S.whTd, S.whTypeName
    else
        S.whPtr = nil
    end
    if typeName ~= S.typeName then
        S.typeName = typeName
        on_weapon_changed(td)
        reset_charge()
    end

    local kind = nil
    if S.kindOverride ~= "auto" then
        kind = (S.kindOverride ~= "off") and S.kindOverride or nil
    else
        if S.kindForType ~= typeName then
            S.kindForType, S.kindAuto = typeName, nil
            for _, m in ipairs(KIND_BY_TYPE) do
                if typeName:find(m.pat, 1, true) then S.kindAuto = m.kind; break end
            end
        end
        kind = S.kindAuto
    end
    if kind ~= S.kind or S.rulesFor ~= typeName .. tostring(kind) then
        if kind ~= S.kind then release_trigger_control(); reset_charge() end
        S.kind = kind
        S.rulesFor = typeName .. tostring(kind)
        init_rules(kind)
        S.fx, S.disStart, S.guardSince, S.cbGuarding = nil, nil, nil, false
        S.emuQuiet = false
        S.lsIai, S.lsKijin, S.lsArmed, S.lsLvUp = false, false, false, false
        for k in pairs(evState) do evState[k] = nil end
        S.gunDelayed, S.ignStart, S.gunShots = {}, nil, 0
        S.saModeCand, S.saModeStable, S.saGaugeMax, S.disSeen, S.saGChg = nil, nil, nil, nil, nil
        S.saGFrames = 0
        S.vibWhy = {}
    end

    -- Vibration queues (run for every weapon in the pack)
    if S.hapticsLeft > 0 and now >= S.nextHapticAt then
        S.hapticsLeft = S.hapticsLeft - 1
        S.nextHapticAt = now + (S.hapticGap or 0.05)
        play_haptic()
    end
    if now < S.rumbleUntil and now - S.lastRumbleSend >= (S.lite and 0.1 or 0.05) then
        S.lastRumbleSend = now
        motor_rumble(S.rumbleStr)
    end

    local c = kind and CFG[kind]
    if c and pad and wh then
        if c.module then c.update(now, c, pad) else update_charge(now, c, pad) end
    end

    -- Field-change LOG (research): every change of every weapon field goes to re2_framework_log.txt,
    -- together with the effects the mod fires, so real field names can replace the guessed patterns.
    -- Fields that change many times per second (timers) are muted after 3 lines and reported once.
    if S.fieldLogOn and wh then
        S.flog = S.flog or {}
        S.flogT0 = S.flogT0 or now
        local t = now - S.flogT0
        for _, f in ipairs(S.fields) do
            local ok, v = pcall(wh.get_field, wh, f.name)
            if ok then
                if type(v) == "boolean" then v = v and 1 or 0 end
                v = tonumber(v)
                if v ~= nil then
                    local st = S.flog[f.name]
                    if not st then S.flog[f.name] = { last = v, sec = math.floor(t), n = 0, muted = false, quietSince = t }
                    elseif math.abs(v - st.last) > 1e-4 then
                        local sec = math.floor(t)
                        if sec ~= st.sec then st.sec, st.n = sec, 0 end
                        st.n = st.n + 1
                        if st.muted then
                            st.quietSince = t
                        elseif st.n > 3 then
                            st.muted, st.quietSince = true, t
                            log.info(string.format("[HapticPack][rec] %8.2f %s changes every frame (timer-like) -> muted", t, f.name))
                        else
                            local fv = f.kind == "float" and string.format("%.3f -> %.3f", st.last, v) or string.format("%d -> %d", math.floor(st.last), math.floor(v))
                            log.info(string.format("[HapticPack][rec] %8.2f %-36s %s", t, f.name, fv))
                        end
                        st.last = v
                    elseif st.muted and t - st.quietSince > 3 then
                        st.muted = false
                        log.info(string.format("[HapticPack][rec] %8.2f %s stopped changing = %s", t, f.name, tostring(v)))
                    end
                end
            end
        end
        if S.ev ~= S.flogEv then
            S.flogEv = S.ev
            if S.ev and S.ev ~= "" then log.info(string.format("[HapticPack][rec] %8.2f   >>> MOD EFFECT: %s", t, tostring(S.ev))) end
        end
        if pad then
            local r2 = (S.rt or 0) > 0.5
            if r2 ~= S.flogR2 then S.flogR2 = r2; log.info(string.format("[HapticPack][rec] %8.2f   [R2 %s]", t, r2 and "pressed" or "released")) end
            local l2 = (S.lt or 0) > 0.5
            if l2 ~= S.flogL2 then S.flogL2 = l2; log.info(string.format("[HapticPack][rec] %8.2f   [L2 %s]", t, l2 and "pressed" or "released")) end
        end
    end

    -- Field recorder: logs every change of every weapon field while recording (to find the REAL field names)
    if S.rec and wh then
        local r = S.rec
        if not r.t0 then r.t0 = now; r.stopAt = now + (r.dur or 60) end
        if now > r.stopAt then
            S.rec = nil
            local out = { version = VERSION, weapon = r.kind, handling = r.tname, seconds = Language.format("%.1f", now - r.t0),
                          note = "Fields sorted by number of changes. Each event = time(s):value", fields = {} }
            local list = {}
            for _, f in pairs(r.f) do list[#list + 1] = f end
            table.sort(list, function(a, b) return a.n > b.n end)
            for _, f in ipairs(list) do
                if f.n > 0 then
                    out.fields[#out.fields + 1] = Language.format("%-40s [%s] changes=%d min=%s max=%s start=%s | %s", f.name, f.kind, f.n,
                        tostring(f.min), tostring(f.max), tostring(f.v0), table.concat(f.ev, " "))
                end
            end
            out.unchanged = {}
            for _, f in ipairs(list) do if f.n == 0 then out.unchanged[#out.unchanged + 1] = Language.format("%s [%s] = %s", f.name, f.kind, tostring(f.v0)) end end
            local fname = "MHWilds_field_record_" .. tostring(r.kind) .. ".json"
            local ok = pcall(json.dump_file, fname, out)
            S.ev = Language.format("Field record saved: %s (%d fields changed)", fname, #out.fields)
            log.info("[HapticPack] field record -> reframework/data/" .. fname .. (ok and "" or " FAILED"))
        else
            for _, f in ipairs(S.fields) do
                local ok, v = pcall(wh.get_field, wh, f.name)
                if ok then
                    if type(v) == "boolean" then v = v and 1 or 0 end
                    v = tonumber(v)
                    if v ~= nil then
                        local e = r.f[f.name]
                        if not e then e = { name = f.name, kind = f.kind, n = 0, v0 = v, last = v, min = v, max = v, ev = {} }; r.f[f.name] = e
                        elseif math.abs(v - e.last) > 1e-4 then
                            -- floats that drift every frame (timers) are capped so the file stays readable
                            e.n = e.n + 1; e.last = v
                            if v < e.min then e.min = v end; if v > e.max then e.max = v end
                            if #e.ev < 40 then e.ev[#e.ev + 1] = Language.format("%.2f:%s", now - r.t0, f.kind == "float" and Language.format("%.2f", v) or tostring(math.floor(v))) end
                        end
                    end
                end
            end
        end
    end

    -- Update the field viewer (only while the menu is open, so it costs nothing in play)
    if wh and now - (S.viewerOpenAt or -10.0) < 0.5 then
        for _, f in ipairs(S.fields) do
            local ok, v = pcall(wh.get_field, wh, f.name)
            if ok then
                if type(v) == "boolean" then v = v and 1 or 0 end
                v = tonumber(v)
                if v ~= nil then
                    if f.last ~= nil and math.abs(v - f.last) > 1e-4 then f.changedAt = now end
                    f.last = v
                end
            end
        end
    end
end

S.enabled = true
re.on_frame(function()
    if catalogDirty and S.catalogOn then
        local t = os.clock()
        if t - (S.catalogSaved or 0) > 30 then S.catalogSaved = t; pcall(save_catalog, true) end
    end
    frameNo = frameNo + 1
    if not S.enabled then return end
    local t0 = clock()
    local ok, err = pcall(frame_body)
    if not ok then log.info("[HapticPack] frame error: " .. tostring(err)) end
    local ms = (clock() - t0) * 1000.0
    perf.last = ms
    perf.avg = perf.avg * 0.95 + ms * 0.05
    if ms > perf.peak or now_s() - perf.peakAt > 5.0 then perf.peak, perf.peakAt = ms, now_s() end
end)

-- =============================================
-- MENU (REFramework -> Script Generated UI)
-- =============================================
local viewerFilter = true
local VIEW_KEYS = { "charge", "lv", "level", "timer", "bottle", "phial", "gauge", "energy", "mode", "morph",
    "arrow", "shot", "coating", "guard", "axe", "sword", "heat", "amp", "awake", "power", "spin", "bin",
    "kijin", "demon", "kyouka", "arch", "extract", "essence", "red", "white", "orange", "air", "aerial", "vault", "rush", "run" }


local function weapon_menu(c)
    local ch
    if c.idleTrigger then
        local it = c.idleTrigger
        local a, b, d
        a, it[1] = imgui.slider_float("R2 guard: force", it[1], 0.0, 1.0)
        b, it[4] = imgui.slider_float("R2 guard: resistance up to (travel)", it[4], 0.05, 1.0)
        d, it[5] = imgui.slider_float("R2 guard: snap", it[5], 0.0, 1.0)
        if a or b or d then S.sentKey = nil end
    end
    ch, c.triggerEnabled = imgui.checkbox(Language.format("Trigger force while charging (%s2)", c.trigger), c.triggerEnabled)
    do
        local changed, side = Menu.combo_value("Trigger used for charging", c.trigger, { "R", "L" })
        if changed then release_trigger_control(); c.trigger = side end
    end
    do
        local ht = c.holdTrigger
        local a, b, d, e
        a, ht[1] = imgui.slider_float("Trigger force while holding", ht[1], 0.0, 1.0)
        b, ht[3] = imgui.slider_float("Resistance start position", ht[3], 0.0, 1.0)
        d, ht[5] = imgui.slider_float("Hold snap", ht[5], 0.0, 1.0)
        if a or b or d then S.sentKey = nil end
    end
    ch, c.holdHaptic = imgui.checkbox("Continuous haptics while holding", c.holdHaptic)
    Menu.slider("Hold haptic interval (0 = every frame, like LS)", c, "holdHapticEvery", 0.0, 0.3)
    Menu.slider("Snap (high = abrupt)", c, "resistSnap", 0.0, 1.0)
    ch, c.levelPulse = imgui.checkbox("Trigger click on level-up", c.levelPulse)
    do
        local changed, value = Menu.combo_value("Click style (detent = release then hit, pulse = like LS)", c.notchStyle, { "detent", "pulse", "both" })
        if changed then c.notchStyle = value end
        changed, value = Menu.combo_value("Level-up source", c.levelSource, { "auto", "field", "sound", "time" })
        if changed then c.levelSource = value end
        imgui.text(Language.format("  using: %s   game vibration events while charging: %d", tostring(S.levelSrcUsed), S.soundEvents or 0))
    end
    Menu.slider("Click: release time", c, "notchGap", 0.0, 0.15)
    Menu.slider("Click: hit time", c, "pulseTime", 0.02, 0.2)
    Menu.slider("Click: body rumble", c, "notchRumble", 0.0, 1.5)
    Menu.slider("Click: haptic pulses", c, "notchHaptics", 0.0, 5.0)
    Menu.slider("Release body rumble: base", c, "rumbleBase", 0.0, 2.0)
    Menu.slider("Release body rumble: extra per level", c, "rumbleStep", 0.0, 1.0)
    Menu.slider("Rumble time (s)", c, "rumbleTime", 0.05, 1.0)
    Menu.slider("Haptic pulses: base", c, "hapticBase", 0.0, 6.0)
    Menu.slider("Haptic pulses: extra per level", c, "hapticStep", 0.0, 3.0)
    Menu.slider("Minimum charge (s)", c, "minCharge", 0.0, 1.0)
    if imgui.button("Test level-up (hold R2 to feel it)") then
        local t = now_s()
        S.lastLevelUpAt = -10.0
        S.testHoldUntil = t + 0.6
        on_level_up(t + 0.15, c, 1)   -- hold the force for 0.15s before the click
        S.notchStart, S.notchEnd = t + 0.15, t + 0.15 + ((c.notchStyle ~= "pulse") and c.notchGap or 0) + c.pulseTime
    end
    imgui.same_line()
    if imgui.button("Test max-level release") then reset_charge(); on_release(now_s(), c, c.maxLevel, 1.0) end
end

local function save_out()
    SAVE.out, SAVE.outMode, SAVE.motorRoles, SAVE.trigEmuGain = S.out, S.outMode, S.motorRoles, S.trigEmuGain
    SAVE.hapticRumble, SAVE.keepPreset = S.hapticRumble, S.keepPreset
    SAVE.trigMotorsWork = S.trigMotorsWork
    SAVE.sideBleed, SAVE.trigTension = S.sideBleed, S.trigTension
    SAVE.rumbleGain, SAVE.outVer = S.rumbleGain, 2
    SAVE.gameVibOn, SAVE.gameVibGain, SAVE.vibVer = S.gameVibOn, S.gameVibGain, 2
    SAVE.soundAll = S.soundAll
    pcall(json.dump_file, SAVE_FILE, SAVE)
end

local OUT_MODES = { "auto", "dualsense", "rumble" }
local KIND_OPTS = { "auto", "gs", "ls", "sns", "db", "hammer", "hh", "lance", "gl", "sa", "cb", "ig", "bow", "lbg", "hbg", "off" }
local KIND_OPT_LABELS = nil

re.on_draw_ui(function()
    if not imgui.tree_node("MHWilds Haptic Pack v" .. VERSION) then return end

    local ce
    ce, S.enabled = imgui.checkbox("Enable Haptic Pack", S.enabled)
    if ce and not S.enabled then release_trigger_control() end
    do
        local changed, code = Menu.combo_value("Language / Ngôn ngữ", Language.current(), { "en", "vi" }, { "English", "Tiếng Việt" })
        if changed then Language.set(code); SAVE.lang = code; pcall(json.dump_file, SAVE_FILE, SAVE) end
    end

    -- ---- controller ----
    local det = (S.detected == "dualsense") and "DualSense" or ((S.detected == "rumble") and "rumble controller" or "not recognized")
    local outLabels = { Language.format(Language.translate("Auto (detected: %s)"), Language.translate(det)),
        "DualSense (adaptive triggers + haptics)", "Rumble controller: Xbox / XInput / Flydigi Vader 5 (trigger motors + body)" }
    local outChanged, outMode = Menu.combo_value("Controller type", S.outMode, OUT_MODES, outLabels)
    if outChanged then
        S.outMode = outMode
        if S.outMode == "auto" then update_detect(now_s(), get_pad(), true) else set_out(S.outMode) end
        save_out()
    end
    imgui.text(Language.format(Language.translate("  Running: %s   (device reports: %s)"),
        Language.translate(S.out == "rumble" and "rumble mode" or "DualSense mode"), S.detectedName))

    local cl
    cl, S.lite = imgui.checkbox("Lite mode (co-op) — NOTE: makes charge-hold vibration sparser and weaker", S.lite)

    if cl then SAVE.lite = S.lite; pcall(json.dump_file, SAVE_FILE, SAVE) end

    -- ---- weapon ----
    imgui.text(Language.translate("Weapon: ") .. Language.translate(S.kind and KIND_LABEL[S.kind] or "not supported"))
    do
        if not KIND_OPT_LABELS then
            KIND_OPT_LABELS = {}
            for i, k in ipairs(KIND_OPTS) do
                KIND_OPT_LABELS[i] = (k == "auto") and "Auto-detect" or ((k == "off") and "Off" or KIND_LABEL[k])
            end
        end
        local ch, kind = Menu.combo_value("Force weapon type (if detected wrong)", S.kindOverride, KIND_OPTS, KIND_OPT_LABELS)
        if ch then S.kindOverride = kind end
    end

    if S.kind and CFG[S.kind] then
        if imgui.tree_node(Language.translate("Tune ") .. Language.translate(CFG[S.kind].name)) then
            if CFG[S.kind].module then module_menu(CFG[S.kind]) else weapon_menu(CFG[S.kind]) end
            imgui.tree_pop()
        end
    end

    if imgui.tree_node("Controller & rumble motors") then
        if S.out == "rumble" then
            imgui.text("This controller has no trigger resistance: trigger effects are turned into trigger-motor rumble.")
            if imgui.button("Restore Flydigi Vader 5 Pro defaults") then
                for k, v in pairs(FLYDIGI_DEFAULTS) do S[k] = v end
                save_out()
            end
            local a, b, d
            local rg
            rg, S.rumbleGain = imgui.slider_float("OVERALL rumble strength (all effects)", S.rumbleGain, 0.5, 2.5)
            if rg then save_out() end
            a, S.trigEmuGain = imgui.slider_float("Trigger rumble strength", S.trigEmuGain, 0.0, 3.0)
            b, S.hapticRumble = imgui.slider_float("Haptic -> rumble: strength", S.hapticRumble, 0.0, 1.5)
            d, S.keepPreset = imgui.checkbox("Also play the game's original haptics", S.keepPreset)
            local e
            e, S.trigMotorsWork = imgui.checkbox("Trigger motors respond (tick only if the trigger tests vibrate)", S.trigMotorsWork)
            if not S.trigMotorsWork then
                imgui.text("  -> left trigger rumble runs on the LEFT grip motor, right trigger rumble on the RIGHT grip motor")
            end
            local g, h
            g, S.sideBleed = imgui.slider_float("Trigger rumble: bleed into the other motor (fuller feel)", S.sideBleed, 0.0, 1.0)
            h, S.trigTension = imgui.checkbox("Light tension rumble while pressing inside a resistance zone", S.trigTension)
            if a or b or d or e or g or h then save_out() end
            local gv, gg
            gv, S.gameVibOn = imgui.checkbox("DualSense-style impact rumble (hits, getting hit, explosions...)", S.gameVibOn)
            gg, S.gameVibGain = imgui.slider_float("Impact rumble strength", S.gameVibGain, 0.0, 4.0)
            if gv or gg then save_out() end
            local li = S.lastPresetInfo
            if li then
                imgui.text(Language.format("  Last impact: preset strength %.2f length %.2fs -> played %.2f for %.2fs",
                    li.s, li.d, S.lastHitK or 0, S.lastHitD or 0))
                if #li.dump > 0 then imgui.text("  preset: " .. table.concat(li.dump, "  ")) end
            end
            imgui.text(Language.format("  Game vibration sources received: haptic %d | motor %d | your sound events %d (others %d)",
                S.vibSrc.adv, S.vibSrc.motor, S.vibSrc.sound, S.vibSrc.soundOther))
            imgui.text("  (hit a few times: the counter that goes up is the active source; if all stay 0, please report it)")
            local sa
            sa, S.soundAll = imgui.checkbox("Also accept sound events not tied to your character (if 'yours' always stays 0)", S.soundAll)
            if sa then save_out() end
            if imgui.button("Test impact") then
                game_vib_to_rumble({ nil, nil, nil, 0 })
            end
            imgui.same_line()
            if imgui.button("Test R2 wall hit") then emu_kick("R", 1.0, 0.09) end
            imgui.same_line()
            if imgui.button("Test R2 pulse") then
                for i = 0, 2 do pulse("trigR", 0.9 * S.trigEmuGain, 0.09, i * 0.18) end
            end
        end
        imgui.text("Motor roles (press Test to find where each motor is on your controller):")
        for i, m in ipairs(load_vib_motors()) do
            local labels = {}
            for k, r in ipairs(ROLES) do labels[k] = ROLE_LABEL[r] end
            local cr, role = Menu.combo_value(m.name .. " (" .. tostring(m.value) .. ")##mr" .. i, m.role, ROLES, labels, 5)
            if cr then
                m.role = role; m.enabled = m.role ~= "off"
                S.motorRoles[m.name] = m.role
                count_roles(); save_out()
            end
            imgui.same_line()
            if imgui.button("Test##mt" .. i) then
                S.testMotor = { v = m.value, u = os.clock() + 0.35 }   -- rumble only this motor for 0.35s
            end
        end
        if imgui.button("Test left trigger rumble") then pulse("trigL", 0.9, 0.3) end
        imgui.same_line()
        if imgui.button("Test right trigger rumble") then pulse("trigR", 0.9, 0.3) end
        imgui.same_line()
        if imgui.button("Test haptic") then play_haptic() end
        imgui.tree_pop()
    end

    if imgui.tree_node("DualSense over Bluetooth (MHWHapticBT plugin)") then
        local st = S.bt
        if not st then
            imgui.text("Plugin not detected. Put MHWHapticBT.dll in reframework/plugins and restart the game.")
        else
            imgui.text(Language.format("Plugin %s  |  bridge: %s  |  DualSense found: %s  Bluetooth: %s", tostring(st.version),
                S.btBridge and "ON" or "OFF", tostring(st.found), tostring(st.bluetooth)))
            if st.found and not st.bluetooth then imgui.text("  USB cable: the game plays its own haptics, the plugin stays idle.") end
        end
        local modes = { "auto", "off" }
        local mi = (S.btMode == "off") and 2 or 1
        local cm, nm = imgui.combo("Bluetooth bridge", mi, { "Auto (when the plugin finds a Bluetooth DualSense)", "Off" })
        if cm then S.btMode = modes[nm]; save_bt() end
        local ch = {}
        local function mark(c) ch[#ch + 1] = c end
        local c, v
        c, BTCFG.gain = imgui.slider_float("BT haptics: strength", BTCFG.gain, 0.1, 2.0); mark(c)
        c, BTCFG.hitGain = imgui.slider_float("BT: hit strength", BTCFG.hitGain, 0.1, 1.5); mark(c)
        c, BTCFG.pulseGain = imgui.slider_float("BT: haptic beat strength", BTCFG.pulseGain, 0.1, 1.5); mark(c)
        c, BTCFG.curveK = imgui.slider_float("BT: strength curve (higher = weak and strong closer)", BTCFG.curveK, 0.3, 2.5); mark(c)
        c, BTCFG.releaseMs = imgui.slider_float("BT: fade-out between hits (ms)", BTCFG.releaseMs, 5, 150); mark(c)
        c, BTCFG.heavyHz = imgui.slider_float("BT haptics: heavy tone (Hz)", BTCFG.heavyHz, 20, 120); mark(c)
        c, BTCFG.lightHz = imgui.slider_float("BT haptics: light tone (Hz)", BTCFG.lightHz, 80, 320); mark(c)
        c, v = imgui.combo("BT: game haptics", (BTCFG.presetMode or 1) + 1,
            { "Off (only the mod's weapon effects)", "By name: hits, charges, guards (recommended)", "Legacy: game's own rumble (everything vibrates)" })
        if c then BTCFG.presetMode = v - 1 end; mark(c)
        BTCFG.gameRumble = (BTCFG.presetMode == 2) and 1 or 0
        S.btPresetMode = BTCFG.presetMode
        c, BTCFG.triggers = imgui.checkbox("BT: send adaptive triggers too", BTCFG.triggers); mark(c)
        c, BTCFG.trigGain = imgui.slider_float("BT: trigger force multiplier", BTCFG.trigGain, 0.5, 2.0); mark(c)
        c, v = imgui.combo("BT: L2 trigger", (BTCFG.leftTrig or 0) + 1,
            { "Free (Focus Mode stays light)", "Game effects, light", "Game effects, full force" })
        if c then BTCFG.leftTrig = v - 1 end; mark(c)
        c, BTCFG.swap = imgui.checkbox("BT: swap left/right actuators", BTCFG.swap); mark(c)
        S.btHitGain, S.btHapticPulse, S.btGameHaptics = BTCFG.hitGain, BTCFG.pulseGain, BTCFG.gameHaptics
        for _, x in ipairs(ch) do if x then save_bt(); break end end
        if not BTCFG.triggers then imgui.text_colored(Language.translate("  ! 'BT: send adaptive triggers too' is OFF - game triggers are not sent over Bluetooth"), 0xFF40A0FF) end
        if imgui.button("Test: vibration") then
            BTCFG.testPulse = (BTCFG.testPulse or 0) + 1; save_bt()
        end
        imgui.same_line()
        if imgui.button("Test: trigger wall 3 s (hold R2/L2)") then
            BTCFG.testTrigger = (BTCFG.testTrigger or 0) + 1; save_bt()
        end
        imgui.same_line()
        if imgui.button("Reset Bluetooth settings to defaults") then
            local tp, tt = BTCFG.testPulse, BTCFG.testTrigger
            for k, dv in pairs(BT_DEFAULTS) do BTCFG[k] = dv end
            BTCFG.testPulse, BTCFG.testTrigger = tp, tt
            S.btHitGain, S.btHapticPulse, S.btGameHaptics = BTCFG.hitGain, BTCFG.pulseGain, BTCFG.gameHaptics
            S.btPresetMode = BTCFG.presetMode
            save_bt()
        end
        imgui.text("Log for bug reports: reframework/data/MHWHapticBT.log")
        imgui.tree_pop()
    end

    if imgui.tree_node("Diagnostics (troubleshooting / bug reports)") then
        imgui.text(Language.format("Script cost: %.3f ms/frame (avg %.3f, 5s peak %.3f)", perf.last, perf.avg, perf.peak))
        imgui.text(Language.translate("Weapon handling type: ") .. (S.typeName ~= "" and S.typeName or Language.translate("(none)")))
        imgui.text(Language.format("Trigger effect sent (%s2): force %.2f  vib %.2f  from %.2f  to %.2f  snap %.2f",
            S.sentSide or "-", lastSent[1], lastSent[2], lastSent[3], lastSent[4], lastSent[5]))
        imgui.text(Language.format("Triggers: L2=%.2f  R2=%.2f   Charging: %s  Level: %d   Releases: %d",
            S.lt, S.rt, tostring(S.charging), S.level, S.releases))
        imgui.text(Language.translate("Last event: ") .. S.ev)
        local why = Language.translate("none")
        if #S.vibWhy > 0 then
            why = ""
            for i, w in ipairs(S.vibWhy) do why = why .. (i > 1 and ", " or "") .. Language.translate(w) end
        end
        imgui.text(Language.translate("Continuous rumble because of: ") .. why)
        imgui.text(Language.translate("Haptic captured: ") .. tostring(captured) .. Language.translate(" (while charging: ") .. tostring(capturedCharging) .. ")")
        imgui.text(Language.translate("Sound hook: ") .. Language.translate(not S.soundHookInstalled and "not installed (not needed)"
            or (S.goFilterOff and "installed (cannot filter by player)" or "installed (only your events)")))
        for k, v in pairs(call_status) do imgui.text("  " .. k .. " -> " .. v) end
        if imgui.button("Re-detect controller") then update_detect(now_s(), get_pad(), true) end
        local ch, ni
        ch, ni = imgui.combo("Charge level field", S.levelIdx, S.fieldNames)
        if ch then S.levelIdx = ni end
        ch, ni = imgui.combo("Charge timer field", S.timerIdx, S.fieldNames)
        if ch then S.timerIdx = ni end
        imgui.tree_pop()
    end

    if imgui.tree_node("Field viewer (yellow = changed in the last second)") then
        local c
        c, viewerFilter = imgui.checkbox("Only show relevant fields", viewerFilter)
        local now = now_s()
        S.viewerOpenAt = now
        local shown = 0
        for _, f in ipairs(S.fields) do
            local ln = f.name:lower()
            local show = not viewerFilter
            if viewerFilter then
                for _, k in ipairs(VIEW_KEYS) do if ln:find(k, 1, true) then show = true; break end end
            end
            if show then
                shown = shown + 1
                local val = f.last ~= nil and (f.kind == "float" and Language.format("%.3f", f.last) or tostring(math.floor(f.last))) or "?"
                local line = Language.format("%s [%s] = %s", f.name, f.kind, val)
                if now - f.changedAt < 1.0 then
                    imgui.text_colored(line, 0xFF00FFFF)
                else
                    imgui.text(line)
                end
            end
        end
        imgui.text(Language.format("(%d / %d field)", shown, #S.fields))
        if imgui.button("Write all fields to the log") then
            for _, f in ipairs(S.fields) do
                log.info(string.format("[HapticPack][field] %s :: %s [%s] = %s", f.owner, f.name, f.kind, tostring(f.last)))
            end
        end
        imgui.tree_pop()
    end

    imgui.tree_pop()
end)

log.info("[HapticPack] Loaded")
