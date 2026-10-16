-- Adaptive Trigger
-- Popular controllers using it: Dualsense (PS5 controllers), Flydigi 6,
-- The game keeps an effect until the next one: timed effects are built by the caller from context.now.
local Constants = require("core.constants")
local ReFramework = require("core.re_framework")

local AdaptiveTrigger = {}

local FREE = Constants.TRIGGER.FREE

local function new_state()
    return { effect = FREE, sent = { nil, nil, nil, nil, nil } }
end

local states = { L = new_state(), R = new_state() }
local is_dirty = false

local function state_for(side)
    return states[side] or states.R
end

local function is_sent(sent, effect)
    return sent[1] == effect[1]
        and sent[2] == effect[2]
        and sent[3] == effect[3]
        and sent[4] == effect[4]
        and sent[5] == effect[5]
end

local function send(pad, side, state)
    local effect = state.effect
    if is_sent(state.sent, effect) then
        return true
    end
    if not ReFramework.pad.set_trigger(pad, side, effect) then
        return false
    end
    local sent = state.sent
    sent[1], sent[2], sent[3], sent[4], sent[5] = effect[1], effect[2], effect[3], effect[4], effect[5]
    return true
end

function AdaptiveTrigger.set(side, effect)
    local state = state_for(side)
    effect = effect or FREE
    if state.effect ~= effect then
        state.effect = effect
        is_dirty = true
    end
end

function AdaptiveTrigger.update(pad)
    if not is_dirty or not pad then
        return
    end
    is_dirty = false
    for side, state in pairs(states) do
        if not send(pad, side, state) then
            is_dirty = true
        end
    end
end

function AdaptiveTrigger.release(pad)
    for _, state in pairs(states) do
        state.effect = FREE
    end
    is_dirty = true
    AdaptiveTrigger.update(pad)
end

-- The game can reset the triggers on its own; forget what was sent so the next update re-sends.
function AdaptiveTrigger.invalidate()
    for _, state in pairs(states) do
        local sent = state.sent
        sent[1], sent[2], sent[3], sent[4], sent[5] = nil, nil, nil, nil, nil
    end
    is_dirty = true
end

return AdaptiveTrigger
