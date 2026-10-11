-- Reads the game's sound requests (soundlib) for the local player: live trigger ids, counts, RTPC levels.
local Constants = require("core.constants")
local ReFramework = require("core.re_framework")
local Language = require("core.language")
local Menu = require("core.menu")

local SoundMonitor = {}

local QUEUE_SIZE = 256
local RECENT_SIZE = 16
local TOP_COUNT = 20

local queue = {}
local recent = {}
for index = 1, QUEUE_SIZE do
    queue[index] = { trigger_id = 0, event_id = 0, game_object_id = 0, source_address = 0, distance = 0.0 }
end
for index = 1, RECENT_SIZE do
    recent[index] = { trigger_id = 0, event_id = 0, time = 0.0, is_mine = false }
end

local state = {
    is_enabled = false,
    has_listeners = false,
    is_installed = false,
    include_others = false,
    queue_head = 0,
    queue_tail = 0,
    dropped = 0,
    others = 0,
    recent_index = 0,
    mine = 0,
    player_address = nil,
    player_game_object_id = nil,
    next_player_fetch = 0.0,
    rtpc_text = "",
    rtpc_value = nil,
}
SoundMonitor.state = state

local counts = {}
local listeners = {}

local function on_request(request_info)
    if not (state.is_enabled or state.has_listeners) then
        return
    end
    local source_address = ReFramework.sound.source_address(request_info) or 0
    if source_address ~= state.player_address and not state.include_others then
        state.others = state.others + 1
        return
    end
    local next_tail = state.queue_tail % QUEUE_SIZE + 1
    if next_tail == state.queue_head then
        state.dropped = state.dropped + 1
        return
    end
    local record = queue[next_tail]
    record.source_address = source_address
    record.trigger_id = ReFramework.sound.trigger_id(request_info) or 0
    record.event_id = ReFramework.sound.event_id(request_info) or 0
    record.game_object_id = ReFramework.sound.game_object_id(request_info) or 0
    record.distance = ReFramework.sound.distance(request_info) or 0.0
    state.queue_tail = next_tail
end

local function install()
    if state.is_installed then
        return
    end
    state.is_installed = true
    ReFramework.sound.on_request(on_request)
end

-- callback(record, now) for each local-player request with this Wwise trigger id; record is reused, copy what you keep.
function SoundMonitor.on_trigger(trigger_id, callback)
    local list = listeners[trigger_id]
    if not list then
        list = {}
        listeners[trigger_id] = list
    end
    list[#list + 1] = callback
    state.has_listeners = true
    install()
end

function SoundMonitor.set_enabled(is_enabled)
    state.is_enabled = is_enabled
    if is_enabled then
        install()
    end
end

local function handle(record, now)
    local is_mine = state.player_address ~= nil and record.source_address == state.player_address
    if is_mine then
        state.mine = state.mine + 1
        state.player_game_object_id = record.game_object_id
    else
        state.others = state.others + 1
    end
    counts[record.trigger_id] = (counts[record.trigger_id] or 0) + 1
    state.recent_index = state.recent_index % RECENT_SIZE + 1
    local entry = recent[state.recent_index]
    entry.trigger_id, entry.event_id, entry.time, entry.is_mine = record.trigger_id, record.event_id, now, is_mine
    local list = is_mine and listeners[record.trigger_id]
    if list then
        for _, callback in ipairs(list) do
            pcall(callback, record, now)
        end
    end
end

function SoundMonitor.update(now, character)
    if not state.is_installed then
        return
    end
    if now >= state.next_player_fetch then
        state.next_player_fetch = now + Constants.TIME.CHARACTER_REFETCH
        state.player_address = ReFramework.game.player_game_object_address(character)
    end
    while state.queue_head ~= state.queue_tail do
        state.queue_head = state.queue_head % QUEUE_SIZE + 1
        handle(queue[state.queue_head], now)
    end
end

-- Current value of an RTPC on the player's Wwise game object, nil if unknown.
function SoundMonitor.player_rtpc(rtpc_id)
    if not state.player_game_object_id then
        return nil
    end
    return ReFramework.sound.rtpc_value(state.player_game_object_id, rtpc_id)
end

local function sorted_counts()
    local list = {}
    for trigger_id, count in pairs(counts) do
        list[#list + 1] = { trigger_id = trigger_id, count = count }
    end
    table.sort(list, function(left, right)
        return left.count > right.count
    end)
    return list
end

function SoundMonitor.save()
    local data = {}
    for _, item in ipairs(sorted_counts()) do
        data[#data + 1] = { trigger_id = item.trigger_id, count = item.count }
    end
    return ReFramework.save_json(Constants.FILE.SOUND_LOG, { triggers = data })
end

function SoundMonitor.clear()
    counts = {}
    state.mine, state.others, state.dropped = 0, 0, 0
    for _, entry in ipairs(recent) do
        entry.trigger_id, entry.time = 0, 0.0
    end
end

function SoundMonitor.draw(now)
    local imgui = Menu.imgui
    local changed, value = imgui.checkbox("Also show sounds of other characters", state.include_others)
    if changed then
        state.include_others = value
    end
    Menu.untranslated.text(Language.format(
        "Sound requests: yours %d | others %d | dropped %d",
        state.mine,
        state.others,
        state.dropped
    ))
    if imgui.tree_node("Latest sounds") then
        for offset = 0, RECENT_SIZE - 1 do
            local entry = recent[(state.recent_index - offset - 1) % RECENT_SIZE + 1]
            if entry.time > 0.0 then
                Menu.untranslated.text(string.format(
                    "%6.2fs  trigger %d  event %d%s",
                    now - entry.time,
                    entry.trigger_id,
                    entry.event_id,
                    entry.is_mine and "" or "  (other)"
                ))
            end
        end
        imgui.tree_pop()
    end
    if imgui.tree_node("Most frequent triggers") then
        local list = sorted_counts()
        for index = 1, math.min(TOP_COUNT, #list) do
            Menu.untranslated.text(string.format("trigger %d  x%d", list[index].trigger_id, list[index].count))
        end
        imgui.tree_pop()
    end
    local rtpc_changed, rtpc_text = Menu.untranslated.input_text(Language.translate("RTPC id"), state.rtpc_text)
    if rtpc_changed then
        state.rtpc_text = rtpc_text
    end
    local rtpc_id = tonumber(state.rtpc_text)
    if rtpc_id then
        state.rtpc_value = SoundMonitor.player_rtpc(rtpc_id)
        Menu.untranslated.text(Language.format("RTPC value: %s", tostring(state.rtpc_value)))
    end
    if imgui.button("Save sound log") then
        SoundMonitor.save()
    end
    imgui.same_line()
    if imgui.button("Clear") then
        SoundMonitor.clear()
    end
end

return SoundMonitor
