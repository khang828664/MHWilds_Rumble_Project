-- Game values come from il2cpp_dump.json; tuning values are copied from MHWilds_Haptic_Pack.lua.
-- Tables are read-only: use Constants.copy() for a value a menu slider will change. Time is in seconds.

local Constants = {}

local function readonly(source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            source[key] = readonly(value)
        end
    end
    return setmetatable({}, {
        __index = source,
        __newindex = function(_, key)
            error("constants are read-only (key: " .. tostring(key) .. ")", 2)
        end,
        __pairs = function()
            return next, source, nil
        end,
        __len = function()
            return #source
        end,
    })
end

function Constants.copy(source)
    if type(source) ~= "table" then
        return source
    end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = Constants.copy(value)
    end
    return copy
end

-- ace.cPadInfo.VIBRATION_MOTOR_TYPE
Constants.MOTOR = {
    LOW = 0, -- left grip, heavy
    HIGH = 1, -- right grip, light
    LTRIGGER = 2,
    RTRIGGER = 3,
}

Constants.SIDE = { L = "L", R = "R" }

-- via.hid.AdaptiveTriggerMotor
Constants.TRIGGER_MOTOR = { L = 0, R = 1, NULL = 254, ALL = 255 }

-- ace.PadVibrationDefine.PAD_INDEX (bit mask)
Constants.PAD_INDEX = { INVALID = 0, PAD_1 = 1, PAD_2 = 2, PAD_3 = 4, PAD_4 = 8, ALL = 15 }

-- via.hid.DeviceKindDetails
Constants.DEVICE_KIND = {
    DUALSHOCK4 = 5,
    DUALSENSE = 8,
    DUALSENSE_REMOTE_PLAY = 9,
    XBOX_ONE = 11,
    WINDOWS_XINPUT = 13,
    WINDOWS_GAMING_INPUT = 15,
    STEAM_CONTROLLER = 18,
    STEAM_DECK = 19,
    SWITCH_PRO = 21,
}

Constants.WEAPON_BY_TYPE = {
    Wp00 = "gs", Wp01 = "sns", Wp02 = "db", Wp03 = "ls", Wp04 = "hammer", Wp05 = "hh", Wp06 = "lance",
    Wp07 = "gl", Wp08 = "sa", Wp09 = "cb", Wp10 = "ig", Wp11 = "bow", Wp12 = "hbg", Wp13 = "lbg",
}

Constants.WEAPONS = { "gs", "sns", "db", "ls", "hammer", "hh", "lance", "gl", "sa", "cb", "ig", "bow", "hbg", "lbg" }

Constants.WEAPON_LABEL = {
    gs = "Great Sword", sns = "Sword & Shield", db = "Dual Blades", ls = "Long Sword",
    hammer = "Hammer", hh = "Hunting Horn", lance = "Lance", gl = "Gunlance",
    sa = "Switch Axe", cb = "Charge Blade", ig = "Insect Glaive", bow = "Bow",
    hbg = "Heavy Bowgun", lbg = "Light Bowgun",
}

-- app.HunterDef.DAMAGE_TYPE (cHunterDamageInfo._DamageType)
Constants.HUNTER_DAMAGE = {
    SMALL = 0, SLIP = 1, SMASH = 2, SMASH_SMALL = 3, SMASH_MIDDLE = 4, SMASH_HYPER = 5, SMASH_UPPER = 6,
    EAR_S = 10, EAR_L = 11, EAR_FLY = 12, -- roar
    WIND_SS = 13, WIND_S = 14, WIND_L = 15, WIND_DRAGON = 16, WIND_FLY = 17,
    QUAKE_SS = 18, QUAKE_S = 19, QUAKE_L = 20, -- tremor
    STUN = 21, FLASH = 22, PARALYZE = 23, SLEEP = 26, FROZEN = 31,
    GUARD_S = 34, GUARD_M = 35, GUARD_L = 36, -- blocked a hit
    GUARD_TECH = 37, GUARD_TECH_M = 38, -- perfect guard
    GUARD_POINT_S = 41, GUARD_POINT_M = 42, GUARD_POINT_L = 43,
    POWER_GUARD = 44,
    NONE = 4294967295,
}

-- app.HitDef.DAMAGE_TYPE (cAttackParamBase._DamageType)
Constants.HIT_DAMAGE = { NORMAL = 0, QUAKE = 1, EAR = 2, SOUND_REACT = 3, WIND = 4, GESTURE = 5, FLASH = 6 }

-- app.HunterDef.STATUS_FLAG. UNVERIFIED in game.
Constants.STATUS_FLAG = {
    GUARD = 2, POWER_GUARD = 3, TECHNICAL_GUARD = 4, LASER_GUARD = 5, GUARD_POINT = 6,
    IN_GUARD_SAFETY_SPACE = 38, IN_PL_GUARD_SAFETY_SPACE = 39,
    WP_02_KIJIN_DODGE = 58,
    WP_05_DEFENCE_UP_WP05 = 62,
}

-- app.HunterDef.PARRY_STATE
Constants.PARRY_STATE = { NONE = 0, WAIT = 1, HIT = 2, SUCCESS = 3, RECOIL = 4 }

-- app.WpXXAction.ID, compared with ace.ACTION_ID._Index. UNVERIFIED: check _Category in game first.
Constants.ACTION = {
    gs = {
        IdleToCharge = 5, CHARGE = 6, STORNG_CHARGE = 7, Charge_Fly = 8, SPIRIT_CHARGE = 11,
        IDLE_TO_PARRY_CHARGE = 21, PARRY_CHARGE = 22,
    },
    sns = {
        BACK_STEP_CHARGE = 24, CHARGE_SLASH = 25,
        JUST_RUSH_START = 48, JUST_RUSH_COMBO_0 = 49, JUST_RUSH_COMBO_1 = 50, JUST_RUSH_COMBO_2 = 51,
    },
    ls = {
        IAI_WP_OFF = 23, IAI_END = 24, IAI_SLASH = 25,
        IAI_KIJIN_SLASH_NONE = 26, IAI_KIJIN_SLASH_WHITE = 27, IAI_KIJIN_SLASH_YELLOW = 28, IAI_KIJIN_SLASH_RED = 29,
    },
    hh = {
        FAST_PLAYING = 26, M_START_1 = 27, M_START_2 = 33, M_START_3 = 34,
        M_WAIT = 35, M_MOVE = 36, M_END = 37,
        ADD_M_START = 38, ADD_THREE_M_START = 39, ADD_M_WAIT = 40, ADD_M_MOVE = 41, NEW_ADD_M_START = 42,
    },
    sa = {
        SWORD_DISCHARGE_STAB = 34, SWORD_DISCHARGE_STAB_SHORT = 35, SWORD_DISCHARGE_STAB_END = 36,
        SWORD_DISCHARGE_STAB_ATTACK = 37, SWORD_DISCHARGE_STAB_FINISH = 38, SWORD_DISCHARGE_STAB_FINISH_WEAK = 39,
        SWORD_DISCHARGE_STAB_AIM_FINISH = 40, SWORD_DISCHARGE_CONST = 41, SWORD_DISCHARGE_CONST_FINISH = 42,
        SWORD_DISCHARGE_CONST_FINISH_WEAK = 43, SWORD_DISCHARGE_SWITCH_FINISH_START = 44,
        SWORD_DISCHARGE_SWITCH_FINISH = 45, SWORD_DISCHARGE_SWITCH_CHARGE_FINISH = 46,
        SWORD_JUMP_DISCHARGE_STAB = 67, SWORD_JUMP_DISCHARGE_STAB_LAND = 68,
    },
    bow = {
        SPECIAL_CHARGE = 5, CHARGE_RUN = 14, CHARGE_RUN_STOP = 15, RUN_TO_CHARGE = 16,
        KYOKUSHA_AIM_START = 17, KYOKUSHA_AIM_LOOP = 18, JUMP_CHARGE = 23,
        AIM_IDLE = 152, AIM_MOVE = 153, AIM_MOVE_STOP = 154,
    },
}

-- { force, vibration, from, to, snap } -- only for adaptive triggers
Constants.TRIGGER = {
    FREE = { 0.0, 0.0, 0.0, 1.0, 0.0 },
    HARD_WALL = { 1.0, 0.0, 0.0, 1.0, 1.0 },
    PULSE = { 1.0, 0.1, 0.0, 1.0, 1.0 },
    GUARD_START = { 0.8, 0.0, 0.0, 0.2, 1.0 },
    SOFT_ZONE = { 1.0, 0.0, 0.2, 0.8, 0.1 },
    CLICK = { 0.55, 0.0, 0.30, 0.55, 1.0 },
    SHIELD_WALL = { 1.0, 0.0, 0.0, 0.3, 1.0 },
}

Constants.RUMBLE = {
    MAXIMUM_POWER = 2.0, -- power clamp; above 1.0 depends on the controller (UNVERIFIED)
    RESEND_INTERVAL = 0.03, -- a game rumble call is one short burst: re-send held pulses this often
    STREAM_INTERVAL = 0.05, -- continuous rumble (friction, hum) refresh; unused in the new modules yet
    ERM_MINIMUM_PULSE = 0.08, -- ERM motors need ~30-50 ms to spin up
    KICK_TIME = 0.06, -- One short knock under the finger (shot, level up, click); stretched to ERM_MINIMUM_PULSE
    MAXIMUM_QUEUED_PULSES = 32, -- per motor; the oldest pulse is dropped when full
}

Constants.WEAPON_HIT = {
    hammer = { force = 1.7, length = 1.5 }, gs = { force = 1.6, length = 1.5 }, cb = { force = 1.35, length = 1.25 },
    sa = { force = 1.35, length = 1.25 }, gl = { force = 1.35, length = 1.25 }, hh = { force = 1.3, length = 1.2 },
    ls = { force = 1.1, length = 1.0 }, sns = { force = 0.95, length = 0.9 }, hbg = { force = 1.1, length = 1.0 },
    lbg = { force = 0.9, length = 0.9 }, bow = { force = 0.85, length = 0.85 },
    db = { force = 0.85, length = 0.7 }, lance = { force = 1.25, length = 0.9 }, ig = { force = 1.0, length = 0.9 },
}

Constants.INPUT = {
    PRESS_THRESHOLD = 0.25,
    EDGE_THRESHOLD = 0.6,
    RELEASE_FRAMES = 3,
}

Constants.TIME = {
    CHARACTER_REFETCH = 2.0,
    DEVICE_DETECT = 2.0,
    BLUETOOTH_STATUS_READ = 2.0,
    BLUETOOTH_STATUS_STALE = 5.0,
    LEVEL_UP_COOLDOWN = 0.25,
    GUARD_HIT_COOLDOWN = 0.25,
    MORPH_COOLDOWN = 1.0,
    GAME_VIBRATION_MINIMUM_GAP = 0.025,
    LITE_MINIMUM_INTERVAL = 0.12,
}

Constants.FILE = {
    SETTINGS = "MHWilds_Haptic_Pack.json",
    MAIN_SETTINGS = "MHWilds_Haptic_Pack_main.json",
    BLUETOOTH_CONFIG = "MHWHapticBT_config.json",
    BLUETOOTH_STATUS = "MHWHapticBT_status.json",
    PRESET_DUMP = "MHWilds_preset_dump.json",
    HAPTIC_CATALOG = "MHWilds_haptic_catalog.json",
    SOUND_LOG = "MHWilds_sound_log.json",
}

Constants.LOG_PREFIX = "[HapticPack]"

return readonly(Constants)
