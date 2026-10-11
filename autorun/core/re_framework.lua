-- Every call into the game goes through here. Functions never throw: they return nil/false on failure.
-- Names and signatures come from il2cpp_dump.json (docs/GAME_PAD_API.md).

local Constants = require("core.constants")

local ReFramework = {}

-- True while this module calls a hooked game method itself (hooks use it to skip the mod's own calls).
ReFramework.self_call = false

local type_cache = {}
local method_cache = {}

-- Cached type definition, nil if the type does not exist.
function ReFramework.type(type_name)
    local type_definition = type_cache[type_name]
    if type_definition == nil then
        type_definition = sdk.find_type_definition(type_name) or false
        type_cache[type_name] = type_definition
    end
    return type_definition or nil
end

-- Cached method by name or full signature, nil if not found.
function ReFramework.method(type_name, signature)
    local key = type_name .. "|" .. signature
    local method = method_cache[key]
    if method == nil then
        local type_definition = ReFramework.type(type_name)
        method = type_definition and type_definition:get_method(signature) or false
        method_cache[key] = method
    end
    return method or nil
end

-- Safe call: returns ok, result (never throws).
function ReFramework.try_call(object, type_name, signature, ...)
    if not object then
        return false, "nil object"
    end
    local method = type_name and ReFramework.method(type_name, signature)
    if method then
        return pcall(method.call, method, object, ...)
    end
    return pcall(object.call, object, signature, ...)
end

-- Safe call: returns the result, nil on failure.
function ReFramework.call(object, type_name, signature, ...)
    local ok, result = ReFramework.try_call(object, type_name, signature, ...)
    if ok then
        return result
    end
    return nil
end

-- Safe field read, nil on failure.
function ReFramework.field(object, name)
    if not object then
        return nil
    end
    local ok, value = pcall(object.get_field, object, name)
    if ok then
        return value
    end
    return nil
end

-- Reads nested fields: field_path(object, "_A", "_B") = object._A._B.
function ReFramework.field_path(object, ...)
    local value = object
    for index = 1, select("#", ...) do
        value = ReFramework.field(value, (select(index, ...)))
        if value == nil then
            return nil
        end
    end
    return value
end

-- Number from a number or boolean (true = 1, false = 0).
function ReFramework.to_number(value)
    if type(value) == "boolean" then
        return value and 1 or 0
    end
    return tonumber(value)
end

-- Field read as a number.
function ReFramework.number_field(object, name)
    return ReFramework.to_number(ReFramework.field(object, name))
end

-- Not cached: the game recreates managers between scenes.
function ReFramework.singleton(type_name)
    local ok, singleton = pcall(sdk.get_managed_singleton, type_name)
    if ok then
        return singleton
    end
    return nil
end

-- Full type name of a managed object, "" if unknown.
function ReFramework.type_name(object)
    if not object then
        return ""
    end
    local ok, type_definition = pcall(object.get_type_definition, object)
    if not ok or not type_definition then
        return ""
    end
    local ok_name, name = pcall(type_definition.get_full_name, type_definition)
    return ok_name and name or ""
end

-- Memory address of a managed object: compares objects across frames and hooks.
function ReFramework.address(object)
    if not object then
        return nil
    end
    local ok, address = pcall(object.get_address, object)
    if ok then
        return address
    end
    return nil
end

local uptime_method = nil
local last_uptime = 0.0

-- Application uptime in seconds. A failed call returns the last value so callers never mix in os.clock.
function ReFramework.now()
    if uptime_method == nil then
        uptime_method = ReFramework.method("via.Application", "get_UpTimeSecond") or false
    end
    if not uptime_method then
        return os.clock()
    end
    local ok, time = pcall(uptime_method.call, uptime_method, nil)
    if ok and type(time) == "number" then
        last_uptime = time
    end
    return last_uptime
end

local enum_cache = {}

-- All values of a game enum as { name = value }, cached.
function ReFramework.enum(type_name)
    local values = enum_cache[type_name]
    if values then
        return values
    end
    values = {}
    local type_definition = ReFramework.type(type_name)
    if type_definition then
        for _, field in ipairs(type_definition:get_fields()) do
            if field:is_static() then
                local ok, value = pcall(field.get_data, field, nil)
                if ok and type(value) == "number" then
                    values[field:get_name()] = value
                end
            end
        end
    end
    enum_cache[type_name] = values
    return values
end

-- Enum value from its name.
function ReFramework.enum_value(type_name, name)
    return ReFramework.enum(type_name)[name]
end

-- Enum name from its value.
function ReFramework.enum_name(type_name, value)
    for name, enum_value in pairs(ReFramework.enum(type_name)) do
        if enum_value == value then
            return name
        end
    end
    return nil
end

-- Hooks fire for every character in co-op: filter by the local player inside `before`.
function ReFramework.hook(type_name, signature, before, after)
    local method = ReFramework.method(type_name, signature)
    if not method then
        log.info("[ReFramework] hook failed, method not found: " .. type_name .. "." .. signature)
        return false
    end
    sdk.hook(method, before or function() end, after or function(return_value)
        return return_value
    end)
    return true
end

-- Hook argument as a managed object.
function ReFramework.argument_object(arguments, index)
    return sdk.to_managed_object(arguments[index])
end

-- Hook argument as a 64-bit integer (also object addresses).
function ReFramework.argument_integer(arguments, index)
    return sdk.to_int64(arguments[index])
end

-- Hook argument as a 32-bit unsigned integer (enums, ids, masks).
function ReFramework.argument_unsigned_integer(arguments, index)
    return (sdk.to_int64(arguments[index]) or 0) & 0xFFFFFFFF
end

-- Hook argument as a float, nil on failure.
function ReFramework.argument_float(arguments, index)
    local ok, value = pcall(sdk.to_float, arguments[index])
    return ok and value or nil
end

ReFramework.SKIP_ORIGINAL = sdk.PreHookResult and sdk.PreHookResult.SKIP_ORIGINAL or nil

-- Reads a JSON file from reframework/data, nil if missing or invalid.
function ReFramework.load_json(file)
    local ok, data = pcall(json.load_file, file)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

-- Writes a JSON file to reframework/data, returns ok.
function ReFramework.save_json(file, data)
    return (pcall(json.dump_file, file, data))
end

-- Log line with the mod prefix.
function ReFramework.log(message)
    log.info(Constants.LOG_PREFIX .. " " .. tostring(message))
end

ReFramework.pad = {}

local PAD_TYPE = "ace.cPadInfo"
local SIGNATURE_RUMBLE = "addVibrationRequest(System.Single, ace.cPadInfo.VIBRATION_MOTOR_TYPE)"
-- Always use this overload: the Left/Right-only variants overwrite each other.
local SIGNATURE_TRIGGER = "setAdaptiveTriggerFeedback(System.Single, System.Single, System.Single, System.Single, "
    .. "System.Single, via.hid.AdaptiveTriggerMotor)"

local MOTOR_BY_NAME = {
    low = Constants.MOTOR.LOW,
    high = Constants.MOTOR.HIGH,
    left_trigger = Constants.MOTOR.LTRIGGER,
    right_trigger = Constants.MOTOR.RTRIGGER,
    heavy = Constants.MOTOR.LOW,
    light = Constants.MOTOR.HIGH,
}
local TRIGGER_MOTOR = Constants.TRIGGER_MOTOR

ReFramework.pad.FREE = Constants.TRIGGER.FREE

-- Pad info (ace.cPadInfo) by index, 0 = first pad.
function ReFramework.pad.get(index)
    return ReFramework.call(ReFramework.singleton("ace.PadManager"), "ace.PadManager", "getPadInfo", index or 0)
end

-- Pad the game currently treats as the main one.
function ReFramework.pad.main()
    return ReFramework.call(ReFramework.singleton("ace.PadManager"), "ace.PadManager", "get_MainPad")
end

-- How far LT/RT (L2/R2) is pressed, 0..1.
function ReFramework.pad.trigger(pad, side)
    local value = ReFramework.call(pad, PAD_TYPE, side == "L" and "get_LTrigger" or "get_RTrigger")
    if type(value) ~= "number" then
        return 0.0
    end
    if value > 1.0 then
        return value / 255.0
    end
    return value
end

-- Stick vector of the "L" or "R" stick.
function ReFramework.pad.stick(pad, side)
    return ReFramework.call(pad, PAD_TYPE, side == "L" and "get_LStick" or "get_RStick")
end

-- Button bit mask: held this frame.
function ReFramework.pad.keys_held(pad)
    return ReFramework.call(pad, PAD_TYPE, "get_KeyOn")
end

-- Button bit mask: pressed this frame.
function ReFramework.pad.keys_pressed(pad)
    return ReFramework.call(pad, PAD_TYPE, "get_KeyTrigger")
end

-- Button bit mask: released this frame.
function ReFramework.pad.keys_released(pad)
    return ReFramework.call(pad, PAD_TYPE, "get_KeyRelease")
end

-- True for a DualSense (PS5) pad.
function ReFramework.pad.is_dualsense(pad)
    return ReFramework.call(pad, PAD_TYPE, "get_DualSense") == true
end

-- Controller kind name from via.hid.DeviceKindDetails ("DualSense", "XboxOne"...).
function ReFramework.pad.device_kind(pad)
    local value = ReFramework.call(pad, PAD_TYPE, "get_DeviceKindDetails")
    if value == nil then
        return nil
    end
    return ReFramework.enum_name("via.hid.DeviceKindDetails", value) or tostring(value)
end

-- One short rumble burst on one motor (number or name: low, high, left_trigger...).
function ReFramework.pad.rumble(pad, power, motor)
    if not pad or not power or power <= 0 then
        return false
    end
    local motor_value = type(motor) == "number" and motor or MOTOR_BY_NAME[motor or "low"] or Constants.MOTOR.LOW
    ReFramework.self_call = true
    local ok = ReFramework.try_call(pad, PAD_TYPE, SIGNATURE_RUMBLE, power, motor_value)
    ReFramework.self_call = false
    return ok
end

-- Burst on both grip motors.
function ReFramework.pad.rumble_body(pad, power)
    ReFramework.pad.rumble(pad, power, "low")
    ReFramework.pad.rumble(pad, power, "high")
end

-- Stops all rumble on this pad.
function ReFramework.pad.stop(pad)
    return (ReFramework.try_call(pad, PAD_TYPE, "stopVibration"))
end

-- DualSense trigger resistance: effect = { force, vibration, from, to, snap }.
function ReFramework.pad.set_trigger(pad, side, effect)
    if not pad or not effect then
        return false
    end
    local ok = ReFramework.try_call(
        pad,
        PAD_TYPE,
        SIGNATURE_TRIGGER,
        effect[1],
        effect[2],
        effect[3],
        effect[4],
        effect[5],
        TRIGGER_MOTOR[side] or TRIGGER_MOTOR.R
    )
    return ok
end

-- Both DualSense triggers back to free.
function ReFramework.pad.reset_triggers(pad)
    return (ReFramework.try_call(pad, PAD_TYPE, "resetAdaptiveTriggerFeedback"))
end

ReFramework.vibration = {}

local VIBRATION_MANAGER = "app.AppPadVibrationManager"

-- Game vibration manager (app.AppPadVibrationManager).
function ReFramework.vibration.manager()
    return ReFramework.singleton(VIBRATION_MANAGER)
end

-- True when vibration is enabled in the game options.
function ReFramework.vibration.is_on()
    return ReFramework.call(ReFramework.vibration.manager(), VIBRATION_MANAGER, "get_IsVibrationOn") == true
end

-- UNVERIFIED: guessed from the method name.
function ReFramework.vibration.set_gain_bias(gain)
    return (ReFramework.try_call(ReFramework.vibration.manager(), VIBRATION_MANAGER, "setGainBias", gain))
end

-- Stops every vibration the game is playing.
function ReFramework.vibration.stop_all()
    return (ReFramework.try_call(ReFramework.vibration.manager(), VIBRATION_MANAGER, "stopAllVibration"))
end

-- Pauses game vibration.
function ReFramework.vibration.pause()
    return (ReFramework.try_call(ReFramework.vibration.manager(), VIBRATION_MANAGER, "requestPauseVibration"))
end

-- Resumes game vibration.
function ReFramework.vibration.resume()
    return (ReFramework.try_call(ReFramework.vibration.manager(), VIBRATION_MANAGER, "requestResumeVibration"))
end

-- Call add_ref() on owner/preset before keeping them after the hook returns.
function ReFramework.vibration.on_game_haptic(callback)
    return ReFramework.hook("ace.cAceAdvancedVibrationBase", "triggerVibration", function(arguments)
        if ReFramework.self_call then
            return
        end
        pcall(callback, {
            owner = sdk.to_managed_object(arguments[2]),
            id = ReFramework.argument_unsigned_integer(arguments, 3),
            preset = sdk.to_managed_object(arguments[4]),
            request = sdk.to_valuetype(arguments[5], "ace.PadVibrationDefine.cRequestData"),
            pad = ReFramework.argument_unsigned_integer(arguments, 6),
        })
    end)
end

-- Replays a haptic captured by on_game_haptic.
function ReFramework.vibration.play_game_haptic(haptic)
    if not (haptic and haptic.owner and haptic.preset) then
        return false
    end
    ReFramework.self_call = true
    local ok = ReFramework.try_call(
        haptic.owner,
        "ace.cAceAdvancedVibrationBase",
        "triggerVibration",
        haptic.id,
        haptic.preset,
        haptic.request,
        haptic.pad
    )
    ReFramework.self_call = false
    return ok
end

-- Hook: a sound with a vibration plays; callback(game_object_address, arguments) to filter the local player.
function ReFramework.vibration.on_sound_vibration(callback)
    return ReFramework.hook(
        "app.SoundPostVibrationManager",
        "requestVibration(app.snd_user_data.SoundVibrationTriggerListData.VibrationTrigger, via.GameObject)",
        function(arguments)
            pcall(callback, sdk.to_int64(arguments[4]) or 0, arguments)
        end
    )
end

-- Hook: the game rumbles one motor; callback(power, motor). The mod's own calls are skipped.
function ReFramework.vibration.on_motor_request(callback)
    return ReFramework.hook(PAD_TYPE, SIGNATURE_RUMBLE, function(arguments)
        if ReFramework.self_call then
            return
        end
        pcall(callback, ReFramework.argument_float(arguments, 3), ReFramework.argument_unsigned_integer(arguments, 4))
    end)
end

-- Static method call (no instance): returns the result, nil on failure.
function ReFramework.call_static(type_name, signature, ...)
    local method = ReFramework.method(type_name, signature)
    if not method then
        return nil
    end
    local ok, result = pcall(method.call, method, nil, ...)
    if ok then
        return result
    end
    return nil
end

ReFramework.sound = {}

local REQUEST_INFO = "soundlib.SoundManager.RequestInfo"

-- Hook: every sound request posted by the game, all characters; callback(request_info).
-- May run outside the frame callback: read the ids only and handle them on the next frame.
function ReFramework.sound.on_request(callback)
    return ReFramework.hook(
        "soundlib.SoundManager",
        "postRequestInfo(soundlib.SoundManager.RequestInfo)",
        function(arguments)
            -- Static method: the first parameter is arguments[2].
            pcall(callback, sdk.to_managed_object(arguments[2]))
        end
    )
end

-- Wwise trigger id of the request (the game's sound cue id).
function ReFramework.sound.trigger_id(request_info)
    return ReFramework.call(request_info, REQUEST_INFO, "get_TriggerId")
end

-- Wwise event id actually posted.
function ReFramework.sound.event_id(request_info)
    return ReFramework.call(request_info, REQUEST_INFO, "get_EventId")
end

-- Wwise game object id: the target of ReFramework.sound.rtpc_value.
function ReFramework.sound.game_object_id(request_info)
    return ReFramework.call(request_info, REQUEST_INFO, "get_GameObjId")
end

-- Address of the via.GameObject that plays the sound: compare with player_game_object_address.
function ReFramework.sound.source_address(request_info)
    return ReFramework.address(ReFramework.call(request_info, REQUEST_INFO, "get_SrcGameObj"))
end

function ReFramework.sound.distance(request_info)
    return ReFramework.call(request_info, REQUEST_INFO, "get_DistanceFromListener")
end

-- Wwise RTPC value; meter effects write loudness (dB) into an RTPC. UNVERIFIED: meaning of the Boolean argument.
function ReFramework.sound.rtpc_value(game_object_id, rtpc_id)
    return ReFramework.call_static(
        "via.simplewwise.Driver",
        "getRtpcValue(System.UInt64, System.UInt32, System.Boolean)",
        game_object_id,
        rtpc_id,
        false
    )
end

ReFramework.game = {}

local HUNTER = "app.HunterCharacter"
local CHARACTER = "app.CharacterBase"

local WEAPON_BY_TYPE = Constants.WEAPON_BY_TYPE

-- Local player character (app.HunterCharacter).
function ReFramework.game.player()
    local master_player =
        ReFramework.call(ReFramework.singleton("app.PlayerManager"), "app.PlayerManager", "getMasterPlayer")
    return ReFramework.call(master_player, "app.cPlayerManageInfo", "get_Character")
end

-- Address of the player's GameObject: filters hooks to the local player in co-op.
function ReFramework.game.player_game_object_address(character)
    return ReFramework.address(ReFramework.call(character or ReFramework.game.player(), HUNTER, "get_GameObject"))
end

-- Weapon handling object of the current weapon (holds gauges, charge levels...).
function ReFramework.game.weapon_handling(character)
    return ReFramework.call(character or ReFramework.game.player(), HUNTER, "get_WeaponHandling")
end

-- Weapon key ("gs", "ls"...) from the weapon handling type name.
function ReFramework.game.weapon_kind(weapon_handling)
    local weapon_code = ReFramework.type_name(weapon_handling):match("cHunter(Wp%d%d)Handling")
    return weapon_code and WEAPON_BY_TYPE[weapon_code] or nil
end

-- True while the weapon is drawn.
function ReFramework.game.is_weapon_drawn(character)
    return ReFramework.call(character or ReFramework.game.player(), HUNTER, "get_IsWeaponOn") == true
end

-- UNVERIFIED in game.
function ReFramework.game.has_status_flag(character, flag)
    local flag_value
    if type(flag) == "string" then
        flag_value = ReFramework.enum_value("app.HunterDef.STATUS_FLAG", flag)
    else
        flag_value = flag
    end
    if flag_value == nil then
        return false
    end
    return ReFramework.call(character or ReFramework.game.player(), HUNTER, "checkHunterStatusFlag", flag_value) == true
end

-- Last damage the player took.
function ReFramework.game.damage_info(character)
    return ReFramework.call(character or ReFramework.game.player(), HUNTER, "get_DamageInfo")
end

-- The value stays after the hit: react when it changes.
function ReFramework.game.damage_type(character)
    local value = ReFramework.number_field(ReFramework.game.damage_info(character), "_DamageType")
    if value == nil then
        return nil, nil
    end
    return value, ReFramework.enum_name("app.HunterDef.DAMAGE_TYPE", value)
end

-- Monster id and name of the last attacker.
function ReFramework.game.attacker_monster(character)
    local damage_info = ReFramework.game.damage_info(character)
    local value = ReFramework.to_number(ReFramework.field_path(damage_info, "_AttackerEmInfo", "_EmID"))
    if value == nil then
        return nil, nil
    end
    return value, ReFramework.enum_name("app.EnemyDef.ID", value)
end

-- UNVERIFIED: check which category weapon actions use in game first.
function ReFramework.game.action_id(character)
    local controller = ReFramework.call(character or ReFramework.game.player(), CHARACTER, "get_BaseActionController")
    local action_id = ReFramework.call(controller, "ace.cActionController", "get_CurrentActionID")
    if not action_id then
        return nil, nil
    end
    return ReFramework.number_field(action_id, "_Category"), ReFramework.number_field(action_id, "_Index")
end

-- Type name of the player's current action.
function ReFramework.game.action_name(character)
    local controller = ReFramework.call(character or ReFramework.game.player(), CHARACTER, "get_BaseActionController")
    return ReFramework.type_name(ReFramework.call(controller, "ace.cActionController", "get_CurrentAction"))
end

-- Hook: a weapon attack hits; callback(weapon_handling, hit_info).
function ReFramework.game.on_weapon_hit(callback)
    return ReFramework.hook("app.cHunterWeaponHandlingBase", "evHit_AttackPostProcess", function(arguments)
        pcall(callback, sdk.to_managed_object(arguments[2]), sdk.to_managed_object(arguments[3]))
    end)
end

return ReFramework
