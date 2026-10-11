# MH Wilds — sound data (from il2cpp_dump.json)

Source: `python -I tools/extract_dump_types.py il2cpp_dump.json "sound|wwise|snd_|audio" sound_types.json` → 1684 types
(`app.*` 1067, `via.*` 383 incl. `via.simplewwise` / `via.wwiselib` / `via.audiorender`, `soundlib.*` 226).
Names checked against the dump; **not tested in-game** unless stated.

## What can be read from Lua

| Level | Readable? | How |
|---|---|---|
| Sound events (which cue plays, who plays it) | yes | hook `soundlib.SoundManager.postRequestInfo` |
| Loudness / level (dB) | partly | Wwise RTPC via `via.simplewwise.Driver.getRtpcValue` — only RTPCs the game's Wwise project drives (meter effects) |
| Raw PCM samples / waveform | **no** | Wwise mixes in native code; not exposed to the managed API. Needs a native plugin (e.g. WASAPI loopback) |

## Event hook — `soundlib.SoundManager`

`postRequestInfo(soundlib.SoundManager.RequestInfo) -> System.UInt32` — **static**, so in a REFramework hook the
request is `arguments[2]`. Every sound the game posts (all characters, environment, UI) goes through it.

Other entry points (not used): `soundlib.SoundContainer.trigger(...)` (6 overloads), `soundlib.SoundManager.postEvent(...)`,
field `OnPostEvent : System.Action<RequestInfo>`.

## `soundlib.SoundManager.RequestInfo` getters

| Getter | Type | Use |
|---|---|---|
| `get_TriggerId` | UInt32 | game sound cue id — the key to map sounds to haptics |
| `get_EventId` | UInt32 | Wwise event actually posted |
| `get_SrcGameObj` | via.GameObject | who plays it; compare its address with the player's GameObject |
| `get_TargetGameObj` | via.GameObject | target object |
| `get_GameObjId` | UInt64 | Wwise game object id (for RTPC reads) |
| `get_DistanceFromListener` | Single | distance to the camera listener |
| `get_Position` | via.vec3 | world position |
| `get_Playing` / `get_PlayEnded` | Boolean | play state |
| `get_Container` | soundlib.SoundContainer | owning container |

## Level (RTPC / meter)

- `via.simplewwise.Driver.getRtpcValue(System.UInt64, System.UInt32, System.Boolean) -> System.Single` — static, native.
  Meaning of the Boolean is UNVERIFIED (called with `false`).
- `app.SoundMeterStatus` — `get_Value() -> Single`, `get_Available()`, fields `_RtpcId`, `MIN_VOLUME_DB`, `<GameObjectId>k__BackingField`.
  The game's own meter (used by `app.SoundDialogueTriggerManager.DialogueMeterManager.get_MeterStatusList()` for dialogue).
  Reading `_RtpcId` from a live `SoundMeterStatus` gives a meter RTPC id to try with `getRtpcValue`.
- `via.wwiselib.MeteringFlags`: `NoMetering, Peak, TruePeak, RMS, KPower, Meter3D`.

## Sound-driven vibration already in the game

- `app.SoundPostVibrationManager.requestVibration(app.snd_user_data.SoundVibrationTriggerListData.VibrationTrigger, via.GameObject)`
  — already hooked by `ReFramework.vibration.on_sound_vibration`.
- `VibrationTrigger` fields: `_TriggerId : UInt32`, `_PresetGuid : Guid`, `_StopOnEndOfEvent`, `_AlwaysEnabled`.
  Same trigger ids as `RequestInfo.get_TriggerId`.
- `app.SoundVibrationContainer.onPostRequestInfo(RequestInfo)` / `onEndOfEvent(RequestInfo)` — the game's own link
  from sound requests to vibration.

## In the mod

- `ReFramework.sound.*` (`autorun/core/re_framework.lua`): `on_request`, `trigger_id`, `event_id`, `game_object_id`,
  `source_address`, `distance`, `rtpc_value`.
- `autorun/haptic_pack/sound_monitor.lua`: menu **Sound monitor** shows the player's latest trigger ids, the most frequent
  ones, an RTPC probe, and saves counts to `reframework/data/MHWilds_sound_log.json`.
  Map a sound to a haptic with `SoundMonitor.on_trigger(trigger_id, function(record, now) ... end)`.

Workflow: enable the monitor → do one action (e.g. a perfect guard) → note the trigger id that appears → bind it with
`on_trigger`.
