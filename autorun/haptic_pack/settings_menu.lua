-- REFramework menu of the main script: on/off, strength, language, per-weapon TUNING. Saved to JSON.
local Constants = require("core.constants")
local ReFramework = require("core.re_framework")
local Language = require("core.language")
local Menu = require("core.menu")
local Rumble = require("haptic_pack.hardwares.rumble")
local SoundMonitor = require("haptic_pack.sound_monitor")

local SettingsMenu = {}

-- Sliders change every frame while dragged: write the file once they stop.
local SAVE_DELAY = 0.5
local LANGUAGES = { "en", "vi" }
local LANGUAGE_LABELS = { "English", "Tiếng Việt" }

local settings = { enabled = true, gain = 1.0, language = "en", sound_monitor = false, tuning = {} }
SettingsMenu.settings = settings

local weapon_sets = {}
local defaults = {}
local sorted_names = {}
local is_dirty = false
local last_change = 0.0

local function tuning_key(controller, weapon_kind)
    return controller .. "." .. weapon_kind
end

local function scalar_copy(tuning)
    local copy = {}
    for name, value in pairs(tuning) do
        if type(value) == "number" or type(value) == "boolean" then
            copy[name] = value
        end
    end
    return copy
end

local function apply_tuning(tuning, values)
    for name, value in pairs(values) do
        if type(tuning[name]) == type(value) and type(value) ~= "table" then
            tuning[name] = value
        end
    end
end

local function mark_changed()
    is_dirty = true
    last_change = ReFramework.now()
end

function SettingsMenu.load(weapons_by_controller)
    weapon_sets = weapons_by_controller
    local saved = ReFramework.load_json(Constants.FILE.MAIN_SETTINGS) or {}
    if type(saved.enabled) == "boolean" then
        settings.enabled = saved.enabled
    end
    if type(saved.gain) == "number" then
        settings.gain = saved.gain
    end
    if type(saved.language) == "string" then
        settings.language = saved.language
    end
    if type(saved.sound_monitor) == "boolean" then
        settings.sound_monitor = saved.sound_monitor
    end
    if type(saved.tuning) == "table" then
        settings.tuning = saved.tuning
    end
    for controller, weapons in pairs(weapon_sets) do
        for weapon_kind, weapon in pairs(weapons) do
            if type(weapon) == "table" and type(weapon.TUNING) == "table" then
                local key = tuning_key(controller, weapon_kind)
                defaults[key] = scalar_copy(weapon.TUNING)
                local names = {}
                for name in pairs(defaults[key]) do
                    names[#names + 1] = name
                end
                table.sort(names)
                sorted_names[key] = names
                apply_tuning(weapon.TUNING, settings.tuning[key] or {})
            end
        end
    end
    Language.set(settings.language)
    Rumble.set_gain(settings.gain)
end

function SettingsMenu.save_if_changed(now)
    if not is_dirty or now - last_change < SAVE_DELAY then
        return
    end
    is_dirty = false
    ReFramework.save_json(Constants.FILE.MAIN_SETTINGS, settings)
end

local function draw_tuning(controller, weapon_kind, tuning)
    local key = tuning_key(controller, weapon_kind)
    if not Menu.imgui.tree_node(weapon_kind .. "##" .. key) then
        return
    end
    local is_changed = false
    local default_values = defaults[key]
    for _, name in ipairs(sorted_names[key]) do
        local label = name .. "##" .. key
        local value = tuning[name]
        if type(value) == "number" then
            local maximum = math.max(1.0, default_values[name] * 3.0)
            is_changed = Menu.slider(label, tuning, name, 0.0, maximum) or is_changed
        else
            local changed, new_value = Menu.imgui.checkbox(label, value)
            if changed then
                tuning[name] = new_value
                is_changed = true
            end
        end
    end
    if Menu.imgui.button("Reset to defaults##" .. key) then
        apply_tuning(tuning, default_values)
        is_changed = true
    end
    if is_changed then
        settings.tuning[key] = scalar_copy(tuning)
        mark_changed()
    end
    Menu.imgui.tree_pop()
end

-- status: { controller, weapon_kind, error_count, last_error } from main.lua.
function SettingsMenu.draw(status)
    if not Menu.imgui.tree_node("MHWilds Haptic Pack") then
        return
    end
    local changed, value = Menu.imgui.checkbox("Enabled", settings.enabled)
    if changed then
        settings.enabled = value
        mark_changed()
    end
    if Menu.slider("Rumble strength", settings, "gain", 0.0, Constants.RUMBLE.MAXIMUM_POWER) then
        Rumble.set_gain(settings.gain)
        mark_changed()
    end
    local language_changed, language = Menu.combo_value("Language", settings.language, LANGUAGES, LANGUAGE_LABELS)
    if language_changed then
        settings.language = language
        Language.set(language)
        mark_changed()
    end
    if Menu.imgui.button("Test rumble") then
        Rumble.body(0.8, 0.3)
    end

    Menu.untranslated.text(Language.format("Controller: %s", status.controller or "?"))
    Menu.untranslated.text(Language.format("Weapon: %s", status.weapon_kind or "-"))
    if status.error_count > 0 then
        Menu.untranslated.text(Language.format("Errors: %d, last: %s", status.error_count, status.last_error))
    end

    local weapons = weapon_sets[status.controller]
    if weapons and Menu.imgui.tree_node("Weapon tuning") then
        for weapon_kind, weapon in pairs(weapons) do
            if type(weapon) == "table" and type(weapon.TUNING) == "table" then
                draw_tuning(status.controller, weapon_kind, weapon.TUNING)
            end
        end
        Menu.imgui.tree_pop()
    end
    if Menu.imgui.tree_node("Sound monitor (read game sounds)") then
        local sound_changed, sound_enabled = Menu.imgui.checkbox("Enabled##sound", settings.sound_monitor)
        if sound_changed then
            settings.sound_monitor = sound_enabled
            mark_changed()
        end
        if settings.sound_monitor then
            SoundMonitor.draw(ReFramework.now())
        end
        Menu.imgui.tree_pop()
    end
    Menu.imgui.tree_pop()
end

return SettingsMenu
