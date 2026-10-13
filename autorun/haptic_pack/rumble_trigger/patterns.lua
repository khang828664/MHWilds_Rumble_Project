local Constants = require("core.constants")
local ReFramework = require("core.re_framework")
local Rumble = require("haptic_pack.hardwares.rumble")

local XboxPatterns = {}

-- Seconds without update (menu, scene change) before a weapon state is cleared.
local RESET_GAP = 0.5

local active_state = nil
local is_hit_hook_installed = false

-- Fields every weapon state needs; `fields` adds the weapon's own.
function XboxPatterns.new_state(fields)
    local state = { handling_address = nil, pending_hits = 0, last_update = -10.0, previous = {} }
    for key, value in pairs(fields or {}) do
        state[key] = value
    end
    return state
end

local function is_trigger_motor(motor)
    return motor == Constants.MOTOR.LTRIGGER or motor == Constants.MOTOR.RTRIGGER
end

-- Steps are { power, seconds, motor, delay }. trigger_scale applies to LTRIGGER / RTRIGGER steps (default: scale).
function XboxPatterns.play(pattern, scale, trigger_scale)
    if not pattern then
        return
    end
    scale = scale or 1.0
    trigger_scale = trigger_scale or scale
    for _, step in ipairs(pattern) do
        local step_scale = is_trigger_motor(step[3]) and trigger_scale or scale
        Rumble.vibrate(step[1] * step_scale, step[2], step[3], step[4])
    end
end

XboxPatterns.read_number = ReFramework.number_field

-- Stores `value` under `name` and compares it with the previous frame: 1 = up, -1 = down, 0 = same / first read / nil.
-- Each name keeps one previous value: call only one of these functions per name per frame.
function XboxPatterns.value_change(state, name, value)
    if value == nil then
        return 0
    end
    local previous = state.previous[name]
    state.previous[name] = value
    if previous == nil or value == previous then
        return 0
    end
    return value > previous and 1 or -1
end

-- Flag turned on (false -> true), or counter / level went up since the previous frame.
function XboxPatterns.has_increased(state, name, value)
    return XboxPatterns.value_change(state, name, value) > 0
end

-- Flag turned off, or counter / level went down since the previous frame.
function XboxPatterns.has_decreased(state, name, value)
    return XboxPatterns.value_change(state, name, value) < 0
end

function XboxPatterns.reset(state, handling_address)
    state.handling_address = handling_address
    state.pending_hits = 0
    for name in pairs(state.previous) do
        state.previous[name] = nil
    end
end

-- One hit hook shared by every weapon: only the active weapon of the local player counts.
function XboxPatterns.init()
    if is_hit_hook_installed then
        return
    end
    is_hit_hook_installed = true
    ReFramework.game.on_weapon_hit(function(weapon_handling)
        local state = active_state
        if state and state.handling_address and ReFramework.address(weapon_handling) == state.handling_address then
            state.pending_hits = state.pending_hits + 1
        end
    end)
end

-- Call first in a weapon's update. Returns now and whether the state was just reset, or nil without a weapon.
function XboxPatterns.update(state, context)
    local handling_address = ReFramework.address(context.weapon_handling)
    if not handling_address then
        return nil
    end
    XboxPatterns.init()
    active_state = state
    local now = context.now
    local was_reset = handling_address ~= state.handling_address or now - state.last_update > RESET_GAP
    if was_reset then
        XboxPatterns.reset(state, handling_address)
    end
    state.last_update = now
    return now, was_reset
end

-- Charge with levels: Hammer, Great Sword
function XboxPatterns.charge_level_up(weapon_kind)
end

-- Charge without levels: Switch Axe Zero Sum Discharge, Gunlance Wyvern's Fire
function XboxPatterns.charge_ultimate(weapon_kind)
end

function XboxPatterns.charge_shelling(weapon_kind)
end

function XboxPatterns.on_hit(weapon_kind)
end

function XboxPatterns.on_ultimate_hit(weapon_kind)
end

return XboxPatterns
