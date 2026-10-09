local config = {
    name = "Hammer", 
    trigger = "R", 
    triggerEnabled = true,
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
}

local rules = {
    
}