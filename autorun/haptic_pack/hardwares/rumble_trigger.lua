-- Rumble Trigger (impulse triggers): small ERM motors inside LT / RT.
-- Popular controllers using it: Xbox One / Series, Flydigi Vader 5. Others ignore these motors.
local Constants = require("core.constants")
local Rumble = require("haptic_pack.hardwares.rumble")

local RumbleTrigger = {}

local MOTOR_BY_SIDE = {
    L = Constants.MOTOR.LTRIGGER,
    R = Constants.MOTOR.RTRIGGER,
}

-- Queued in Rumble: Rumble.update(pad, now) sends it, strongest pulse per motor wins.
function RumbleTrigger.vibrate(side, power, seconds, delay)
    return Rumble.vibrate(power, seconds, MOTOR_BY_SIDE[side] or MOTOR_BY_SIDE.R, delay)
end

function RumbleTrigger.left(power, seconds, delay)
    return RumbleTrigger.vibrate("L", power, seconds, delay)
end

function RumbleTrigger.right(power, seconds, delay)
    return RumbleTrigger.vibrate("R", power, seconds, delay)
end

function RumbleTrigger.both(power, seconds, delay)
    RumbleTrigger.vibrate("L", power, seconds, delay)
    RumbleTrigger.vibrate("R", power, seconds, delay)
end

-- One short knock under the finger (shot, level up, click).
function RumbleTrigger.kick(side, power, delay)
    return RumbleTrigger.vibrate(side, power, Constants.RUMBLE.KICK_TIME, delay)
end

return RumbleTrigger
