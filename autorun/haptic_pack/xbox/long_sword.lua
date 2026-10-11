-- Long Sword rumble for ERM controllers (Xbox / XInput): LOW, HIGH body motors + LT / RT impulse triggers.
-- Design notes and the event table are in docs/LONG_SWORD_RUMBLE.md.
local Constants = require("core.constants")
local ReFramework = require("core.re_framework")
local Rumble = require("haptic_pack.hardwares.rumble")
local RumbleTrigger = require("haptic_pack.hardwares.rumble_trigger")
local XboxPatterns = require("haptic_pack.xbox.patterns")

local XboxLongSword = {}

local LOW = Constants.MOTOR.LOW
local HIGH = Constants.MOTOR.HIGH
local LT = Constants.MOTOR.LTRIGGER
local RT = Constants.MOTOR.RTRIGGER
local HANDLING_TYPE = "app.cHunterWp03Handling"
local IAI_STANCE_ACTION = "cIaiWpOff"

local TUNING = {
    hit_power = 0.40,
    hit_power_per_aura = 0.12,
    hit_time = 0.09,
    hit_cooldown = 0.06,
    charge_hum = 0.10,
    charge_hum_per_level = 0.07,
    charge_hum_interval = 0.07,
    charge_heartbeat = { 0.0, 0.50, 0.40, 0.28 }, -- seconds between beats per charge level, 0 = none
    charge_heartbeat_power = 0.30,
    charge_timeout = 0.1,
    swoosh_enabled = true,
    swoosh_cooldown = 0.15,
    gain = 1.0,
    trigger_gain = 1.0, -- 0 = no trigger rumble (controllers without impulse triggers)
    trigger_hum = 0.08,
    trigger_hum_per_level = 0.06,
    trigger_hit_scale = 0.7,
}

-- { power, seconds, motor, delay }. RT carries the blade (Spirit Blade, charge, Iai use RT); LT joins on clashes.
local PATTERN = {
    swoosh = {
        { 0.12, 0.08, HIGH, 0.00 }, { 0.26, 0.08, HIGH, 0.05 }, { 0.12, 0.08, HIGH, 0.11 },
        { 0.30, 0.06, RT, 0.00 },
    },
    charge_level_up = { { 0.60, 0.08, HIGH, 0.00 }, { 0.30, 0.08, LOW, 0.00 }, { 0.80, 0.06, RT, 0.00 } },
    charge_full = {
        { 0.70, 0.08, HIGH, 0.00 }, { 0.40, 0.08, LOW, 0.00 }, { 0.80, 0.06, RT, 0.00 },
        { 0.95, 0.10, HIGH, 0.12 }, { 0.65, 0.12, LOW, 0.12 }, { 1.00, 0.08, RT, 0.12 }, { 0.60, 0.08, LT, 0.12 },
    },
    aura_up = {
        { { 0.45, 0.10, LOW, 0.00 }, { 0.30, 0.10, HIGH, 0.00 }, { 0.40, 0.06, RT, 0.00 } },
        {
            { 0.45, 0.09, LOW, 0.00 }, { 0.40, 0.06, RT, 0.00 },
            { 0.65, 0.12, LOW, 0.13 }, { 0.40, 0.12, HIGH, 0.13 }, { 0.60, 0.08, RT, 0.13 },
        },
        {
            { 0.45, 0.09, LOW, 0.00 }, { 0.40, 0.06, RT, 0.00 },
            { 0.70, 0.09, LOW, 0.12 }, { 0.60, 0.06, RT, 0.12 },
            { 1.10, 0.20, LOW, 0.24 }, { 0.80, 0.16, HIGH, 0.24 }, { 1.00, 0.12, RT, 0.24 }, { 0.80, 0.12, LT, 0.24 },
            { 0.35, 0.20, LOW, 0.44 },
        },
    },
    aura_down = { { 0.30, 0.10, LOW, 0.00 }, { 0.15, 0.12, LOW, 0.10 } },
    iai_stance = { { 0.35, 0.08, HIGH, 0.00 }, { 0.18, 0.08, LOW, 0.03 }, { 0.45, 0.06, RT, 0.00 } },
    counter_success = {
        { 1.00, 0.08, HIGH, 0.00 }, { 0.70, 0.14, LOW, 0.04 }, { 1.00, 0.06, RT, 0.00 }, { 0.80, 0.06, LT, 0.00 },
    },
    iai_spirit_counter = {
        { 1.00, 0.08, HIGH, 0.00 }, { 1.20, 0.20, LOW, 0.04 }, { 0.40, 0.18, LOW, 0.24 },
        { 1.00, 0.08, RT, 0.00 }, { 0.90, 0.08, LT, 0.00 }, { 0.50, 0.12, RT, 0.24 },
    },
    counter_hit = { { 0.85, 0.12, LOW, 0.00 }, { 0.70, 0.10, HIGH, 0.00 }, { 0.70, 0.08, RT, 0.00 } },
    red_counter_hit = {
        { 1.20, 0.16, LOW, 0.00 }, { 0.90, 0.12, HIGH, 0.00 }, { 0.45, 0.18, LOW, 0.16 },
        { 1.00, 0.10, RT, 0.00 }, { 0.70, 0.10, LT, 0.00 },
    },
    iai_slash_hit = { { 0.90, 0.08, HIGH, 0.00 }, { 0.80, 0.12, LOW, 0.02 }, { 0.90, 0.08, RT, 0.00 } },
    iai_spirit_hit = {
        { 1.00, 0.10, HIGH, 0.00 }, { 1.10, 0.18, LOW, 0.02 }, { 0.40, 0.16, LOW, 0.20 },
        { 1.00, 0.10, RT, 0.00 }, { 0.60, 0.08, LT, 0.02 },
    },
    red_iai_spirit_hit = {
        { 1.00, 0.10, HIGH, 0.00 }, { 1.40, 0.22, LOW, 0.02 },
        { 0.70, 0.16, LOW, 0.24 }, { 0.30, 0.20, LOW, 0.40 },
        { 1.00, 0.12, RT, 0.00 }, { 0.80, 0.12, LT, 0.02 }, { 0.50, 0.14, RT, 0.24 },
    },
    helm_breaker_start = { { 0.25, 0.15, LOW, 0.00 }, { 0.15, 0.10, HIGH, 0.00 }, { 0.30, 0.12, RT, 0.00 } },
    red_roundslash_hit = {
        { 1.10, 0.16, LOW, 0.00 }, { 0.80, 0.10, HIGH, 0.00 }, { 0.35, 0.16, LOW, 0.16 },
        { 1.00, 0.10, RT, 0.00 }, { 0.70, 0.10, LT, 0.00 },
    },
}

local state = XboxPatterns.new_state({
    last_hit = -10.0,
    last_charge_update = -10.0,
    is_charging = false,
    next_hum = 0.0,
    next_heartbeat = 0.0,
    is_iai_stance = false,
    trigger_was_down = false,
    last_swoosh = -10.0,
})

local is_charge_hook_installed = false

local function install_charge_hook()
    if is_charge_hook_installed then
        return
    end
    is_charge_hook_installed = true
    ReFramework.hook(HANDLING_TYPE, "updateKijinCharge()", function(arguments)
        if state.handling_address and ReFramework.argument_integer(arguments, 2) == state.handling_address then
            state.last_charge_update = ReFramework.now()
        end
    end)
end

local function update_charge(weapon_handling, now)
    local is_charging = now - state.last_charge_update < TUNING.charge_timeout
    -- app.Wp03Def.KIJIN_CHARGE_LV: LV0..LV3, MAX=4
    local charge_level = math.min(XboxPatterns.read_number(weapon_handling, "_KijinChargeLv") or 0, 3)
    local is_full = XboxPatterns.read_number(weapon_handling, "_IsKijinFullCharge")

    if is_charging and not state.is_charging then
        state.next_hum, state.next_heartbeat = now, now + 0.3
    end
    state.is_charging = is_charging

    local became_full = XboxPatterns.has_increased(state, "full_charge", is_full)
    local leveled_up = XboxPatterns.has_increased(state, "charge_level", charge_level)
    if became_full then
        XboxPatterns.play(PATTERN.charge_full, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    elseif leveled_up and is_charging and charge_level > 0 then
        XboxPatterns.play(PATTERN.charge_level_up, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
        state.next_heartbeat = now + 0.2
    end
    if not is_charging then
        return
    end

    if now >= state.next_hum then
        state.next_hum = now + TUNING.charge_hum_interval
        local power = TUNING.charge_hum + TUNING.charge_hum_per_level * charge_level
        Rumble.vibrate(power * TUNING.gain, TUNING.charge_hum_interval + 0.03, HIGH)
        local trigger_power = TUNING.trigger_hum + TUNING.trigger_hum_per_level * charge_level
        RumbleTrigger.right(trigger_power * TUNING.gain * TUNING.trigger_gain, TUNING.charge_hum_interval + 0.03)
    end
    local beat_interval = TUNING.charge_heartbeat[charge_level + 1] or 0
    if beat_interval > 0 and now >= state.next_heartbeat then
        state.next_heartbeat = now + beat_interval
        Rumble.vibrate(TUNING.charge_heartbeat_power * TUNING.gain, 0.08, LOW)
    end
end

local function update_aura(weapon_handling)
    -- app.Wp03Def.AURA_LEVEL: INVALID=0, NONE=1, WHITE=2, YELLOW=3, RED=4
    local aura_value = XboxPatterns.read_number(weapon_handling, "<AuraLevel>k__BackingField")
    local aura = aura_value and math.min(math.max(aura_value - 1, 0), #PATTERN.aura_up)
    local aura_change = XboxPatterns.value_change(state, "aura", aura)
    if aura_change > 0 then
        XboxPatterns.play(PATTERN.aura_up[aura], TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    elseif aura_change < 0 then
        XboxPatterns.play(PATTERN.aura_down, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    end
    return aura or state.previous.aura or 0
end

local function update_counters(weapon_handling)
    local iai_spirit_counter = XboxPatterns.has_increased(
        state,
        "iai_spirit_counter",
        XboxPatterns.read_number(weapon_handling, "IsIaiKijinMikiriSuccessed")
    )
    local counter = XboxPatterns.has_increased(
        state,
        "counter",
        XboxPatterns.read_number(weapon_handling, "IsMikiriSuccessed")
    )
    local red_counter_hit = XboxPatterns.has_increased(
        state,
        "red_counter_hit",
        XboxPatterns.read_number(weapon_handling, "IsRedMikiriHitSuccessed")
    )
    local counter_hit = XboxPatterns.has_increased(
        state,
        "counter_hit",
        XboxPatterns.read_number(weapon_handling, "IsMikiriHitSuccessed")
    )
    if iai_spirit_counter then
        XboxPatterns.play(PATTERN.iai_spirit_counter, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    elseif counter then
        XboxPatterns.play(PATTERN.counter_success, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    end
    if red_counter_hit then
        XboxPatterns.play(PATTERN.red_counter_hit, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    elseif counter_hit then
        XboxPatterns.play(PATTERN.counter_hit, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    end
end

local function update_special_hits(weapon_handling)
    local red_iai_spirit_hit = XboxPatterns.has_increased(
        state,
        "red_iai_spirit_hit",
        XboxPatterns.read_number(weapon_handling, "_RedIaiKijinHitCount")
    )
    local iai_spirit_hit = XboxPatterns.has_increased(
        state,
        "iai_spirit_hit",
        XboxPatterns.read_number(weapon_handling, "IsIaiKijinSlashHitted")
    )
    if red_iai_spirit_hit then
        XboxPatterns.play(PATTERN.red_iai_spirit_hit, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    elseif iai_spirit_hit then
        XboxPatterns.play(PATTERN.iai_spirit_hit, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    end
    if XboxPatterns.has_increased(
        state,
        "iai_slash_hit",
        XboxPatterns.read_number(weapon_handling, "IsIaiSlashHitted")
    ) then
        XboxPatterns.play(PATTERN.iai_slash_hit, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    end
    if XboxPatterns.has_increased(
        state,
        "red_roundslash_hit",
        XboxPatterns.read_number(weapon_handling, "_RedSlashRoundHitCount")
    ) then
        XboxPatterns.play(PATTERN.red_roundslash_hit, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    end
    if XboxPatterns.has_increased(
        state,
        "helm_breaker_start",
        XboxPatterns.read_number(weapon_handling, "_IsKabutowariStart")
    ) then
        XboxPatterns.play(PATTERN.helm_breaker_start, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    end
    local helm_breaker_hits = XboxPatterns.read_number(weapon_handling, "_KabutowariHitNum")
    if XboxPatterns.has_increased(state, "helm_breaker_hits", helm_breaker_hits) then
        local power = math.min(0.5 + 0.1 * helm_breaker_hits, 1.2)
        Rumble.vibrate(power * TUNING.gain, 0.10, LOW)
        Rumble.vibrate(power * 0.7 * TUNING.gain, 0.08, HIGH)
        RumbleTrigger.right(power * 0.8 * TUNING.gain * TUNING.trigger_gain, 0.08)
    end
end

local function update_iai_stance(character)
    local is_iai_stance = ReFramework.game.action_name(character):find(IAI_STANCE_ACTION, 1, true) ~= nil
    if XboxPatterns.has_increased(state, "iai_stance", is_iai_stance and 1 or 0) then
        XboxPatterns.play(PATTERN.iai_stance, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
    end
    state.is_iai_stance = is_iai_stance
end

local function update_hits(aura, now)
    if state.pending_hits == 0 then
        return
    end
    state.pending_hits = 0
    if now - state.last_hit < TUNING.hit_cooldown then
        return
    end
    state.last_hit = now
    local power = (TUNING.hit_power + TUNING.hit_power_per_aura * aura) * TUNING.gain
    Rumble.vibrate(power, TUNING.hit_time, LOW)
    Rumble.vibrate(power * 0.8, TUNING.hit_time * 0.7, HIGH)
    RumbleTrigger.kick("R", power * TUNING.trigger_hit_scale * TUNING.trigger_gain)
end

local function update_swoosh(pad, character, now)
    local is_down = ReFramework.pad.trigger(pad, "R") > Constants.INPUT.EDGE_THRESHOLD
    local pressed = is_down and not state.trigger_was_down
    state.trigger_was_down = is_down
    if not (TUNING.swoosh_enabled and pressed) or state.is_charging or state.is_iai_stance then
        return
    end
    if now - state.last_swoosh < TUNING.swoosh_cooldown or not ReFramework.game.is_weapon_drawn(character) then
        return
    end
    state.last_swoosh = now
    XboxPatterns.play(PATTERN.swoosh, TUNING.gain, TUNING.gain * TUNING.trigger_gain)
end

function XboxLongSword.update(context)
    local now, was_reset = XboxPatterns.update(state, context)
    if not now then
        return
    end
    if was_reset then
        state.is_charging = false
    end
    install_charge_hook()
    local weapon_handling = context.weapon_handling
    update_charge(weapon_handling, now)
    local aura = update_aura(weapon_handling)
    update_counters(weapon_handling)
    update_special_hits(weapon_handling)
    update_iai_stance(context.character)
    update_hits(aura, now)
    update_swoosh(context.pad, context.character, now)
end

XboxLongSword.TUNING = TUNING
XboxLongSword.PATTERN = PATTERN

return XboxLongSword
