local XboxHammer = require("haptic_pack.xbox.hammer")
local XboxGreatSword = require("haptic_pack.xbox.great_sword")
local XboxLongSword = require("haptic_pack.xbox.long_sword")

-- Keyed by the weapon keys of Constants.WEAPON_BY_TYPE.
return {
    hammer = XboxHammer,
    gs = XboxGreatSword,
    ls = XboxLongSword,
}
