local RumbleHammer      = require("haptic_pack.rumble.hammer")
local RumbleGreatSword  = require("haptic_pack.rumble.great_sword")
local RumbleLongSword   = require("haptic_pack.rumble.long_sword")

-- Keyed by the weapon keys of Constants.WEAPON_BY_TYPE.
return {
    hammer  = RumbleHammer,
    gs      = RumbleGreatSword,
    ls      = RumbleLongSword,
}
