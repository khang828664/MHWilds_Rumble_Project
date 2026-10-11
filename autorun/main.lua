local Constants = require("core.constants")
local ReFramework = require("core.re_framework")
local Rumble = require("haptic_pack.hardwares.rumble")
local AdaptiveTrigger = require("haptic_pack.hardwares.adaptive_trigger")
local SettingsMenu = require("haptic_pack.settings_menu")
local SoundMonitor = require("haptic_pack.sound_monitor")

local XboxWeapons = require("haptic_pack.xbox.weapons")
local DualSenseWeapons = require("haptic_pack.dualsense.weapons")
local SwitchWeapons = require("haptic_pack.switch.weapons")
local SteamControllerWeapons = require("haptic_pack.steam_controller.weapons")

local VERSION = "0.1"

local WEAPONS_BY_CONTROLLER = {
    xbox = XboxWeapons,
    dualsense = DualSenseWeapons,
    switch = SwitchWeapons,
    steam_controller = SteamControllerWeapons,
}

-- via.hid.DeviceKindDetails names; anything else (Xbox, XInput, DualShock 4...) uses the xbox rumble set.
local CONTROLLER_BY_DEVICE_KIND = {
    DualSense = "dualsense",
    DualSenseRemotePlay = "dualsense",
    SwitchProController = "switch",
    SwitchJoyCon = "switch",
    SteamController = "steam_controller",
    SteamDeck = "steam_controller",
}

local state = {
    controller = "xbox",
    next_detect = 0.0,
    weapon_kind = nil,
    weapon_haptics = nil,
    was_enabled = true,
    -- Frame errors stay in memory and show in the menu: no log file write per frame.
    error_count = 0,
    last_error = "",
}

local settings = SettingsMenu.settings

-- Reused every frame by weapon modules that expose update(context).
local context = { pad = nil, character = nil, weapon_handling = nil, now = 0.0 }

local function detect_controller(pad, now)
    if now < state.next_detect then
        return state.controller
    end
    state.next_detect = now + Constants.TIME.DEVICE_DETECT
    local device_kind = ReFramework.pad.device_kind(pad)
    if device_kind then
        state.controller = CONTROLLER_BY_DEVICE_KIND[device_kind] or "xbox"
    end
    return state.controller
end

local function select_weapon_haptics(pad, weapon_handling, now)
    local weapons = WEAPONS_BY_CONTROLLER[detect_controller(pad, now)]
    local weapon_kind = ReFramework.game.weapon_kind(weapon_handling)
    state.weapon_kind = weapon_kind
    if not weapons or not weapon_kind then
        return nil
    end
    return weapons[weapon_kind]
end

local function on_frame()
    local now = ReFramework.now()
    SettingsMenu.save_if_changed(now)
    local pad = ReFramework.pad.get(0)
    if not pad then
        return
    end
    if not settings.enabled then
        if state.was_enabled then
            Rumble.stop(pad)
            AdaptiveTrigger.release(pad)
        end
        state.was_enabled = false
        return
    end
    state.was_enabled = true
    local character = ReFramework.game.player()
    local weapon_handling = ReFramework.game.weapon_handling(character)
    SoundMonitor.set_enabled(settings.sound_monitor)
    SoundMonitor.update(now, character)
    state.weapon_haptics = select_weapon_haptics(pad, weapon_handling, now)
    local weapon_haptics = state.weapon_haptics
    if weapon_haptics and weapon_haptics.update and weapon_handling then
        context.pad, context.character, context.weapon_handling, context.now = pad, character, weapon_handling, now
        weapon_haptics.update(context)
    end
    Rumble.update(pad, now)
    AdaptiveTrigger.update(pad)
end

local function record_error(ok, message)
    if not ok then
        state.error_count = state.error_count + 1
        state.last_error = tostring(message)
    end
end

SettingsMenu.load(WEAPONS_BY_CONTROLLER)

re.on_frame(function()
    record_error(pcall(on_frame))
end)

re.on_draw_ui(function()
    record_error(pcall(SettingsMenu.draw, state))
end)

ReFramework.log("loading v" .. VERSION)
