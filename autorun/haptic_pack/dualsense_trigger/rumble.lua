-- The game's rumble call has no duration (one short burst per call), so pulses are queued and re-sent.
-- this for basic rumble functionality
-- Each motor (LOW, HIGH, LTRIGGER, RTRIGGER) has its own channel: queue and re-send timer never shared.
local Constants = require("core.constants")
local ReFramework = require("core.re_framework")

local Rumble = {}

local gain = 1.0
local channels = {}
for _, motor in pairs(Constants.MOTOR) do
    channels[motor] = { pulses = {}, last_send = -1.0 }
end

-- @param power The intensity of the rumble (0.0 to 1.0)
-- @param seconds The duration of the rumble in seconds
-- @param motor The motor to activate (low, high, left_trigger, right_trigger)
-- @param delay The delay before the rumble starts, in seconds
function Rumble.vibrate(power, seconds, motor, delay)
    power = (power or 0) * gain
    if power <= 0 or not seconds or seconds <= 0 then
        return false
    end
    local channel = channels[motor or Constants.MOTOR.LOW]
    if not channel then
        return false
    end
    local pulses = channel.pulses
    if #pulses >= Constants.RUMBLE.MAXIMUM_QUEUED_PULSES then
        table.remove(pulses, 1)
    end
    local start = ReFramework.now() + (delay or 0)
    pulses[#pulses + 1] = {
        power = math.min(power, Constants.RUMBLE.MAXIMUM_POWER),
        start = start,
        stop = start + math.max(seconds, Constants.RUMBLE.ERM_MINIMUM_PULSE),
    }
    return true
end

-- Strength multiplier from the menu, applied to every pulse.
function Rumble.set_gain(value)
    gain = value or 1.0
end

function Rumble.left(power, seconds, delay)
    return Rumble.vibrate(power, seconds, Constants.MOTOR.LOW, delay)
end

function Rumble.right(power, seconds, delay)
    return Rumble.vibrate(power, seconds, Constants.MOTOR.HIGH, delay)
end

function Rumble.body(power, seconds, delay)
    Rumble.vibrate(power, seconds, Constants.MOTOR.LOW, delay)
    Rumble.vibrate(power, seconds, Constants.MOTOR.HIGH, delay)
end

function Rumble.stop(pad)
    for _, channel in pairs(channels) do
        local pulses = channel.pulses
        for index = #pulses, 1, -1 do
            pulses[index] = nil
        end
    end
    ReFramework.pad.stop(pad or ReFramework.pad.get(0))
end

function Rumble.is_active(motor)
    if motor then
        local channel = channels[motor]
        return channel ~= nil and #channel.pulses > 0
    end
    for _, channel in pairs(channels) do
        if #channel.pulses > 0 then
            return true
        end
    end
    return false
end

-- Overlapping pulses on one motor: only the strongest is sent.
local function strongest_power(pulses, now)
    local strongest = 0
    for index = #pulses, 1, -1 do
        local pulse = pulses[index]
        if now >= pulse.stop then
            table.remove(pulses, index)
        elseif now >= pulse.start and pulse.power > strongest then
            strongest = pulse.power
        end
    end
    return strongest
end

function Rumble.update(pad, now)
    now = now or ReFramework.now()
    for motor, channel in pairs(channels) do
        if #channel.pulses > 0 and now - channel.last_send >= Constants.RUMBLE.RESEND_INTERVAL then
            channel.last_send = now
            local power = strongest_power(channel.pulses, now)
            if power > 0 then
                pad = pad or ReFramework.pad.get(0)
                ReFramework.pad.rumble(pad, power, motor)
            end
        end
    end
end

return Rumble
