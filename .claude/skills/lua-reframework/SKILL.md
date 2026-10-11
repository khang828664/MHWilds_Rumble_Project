---
name: lua-reframework
description: Lua coding rules for this REFramework mod (MH Wilds Haptic Pack). Use BEFORE writing, editing or reviewing any .lua file under autorun/ — style, module layout, REFramework/sdk safety, per-frame performance, hooks, and comments (keep them few).
---

# Lua rules — MH Wilds Haptic Pack (REFramework, Lua 5.4)

Sources: hslua Lua style guide, Tarantool Lua style guide, Hisham Muhammad (LuaRocks) "modules in a post-module() world", plus the REFramework patterns already proven in `autorun/MHWilds_Haptic_Pack.lua`.
When a generic guide disagrees with existing project code, **the project wins** (noted below).

## 1. Formatting
- Indent **4 spaces**, no tabs. (Generic guides say 2; the project uses 4.)
- **Double quotes** for strings. (Generic guides say single; the project uses double.)
- Max line ~120 chars. Split long calls one argument group per line.
- Spaces around operators and after commas. `{ a, b }` with inner spaces, `f(a, b)` without.
- No semicolons. One statement per line, except trivial `if x then return end`.
- No trailing whitespace. File ends with one newline.
- Formatter config: `.stylua.toml` at repo root (`stylua autorun/`).

## 2. Naming
| Thing | Style | Example |
|---|---|---|
| local variables, functions, fields | `snake_case` | `read_trigger`, `last_sent` |
| module table | full PascalCase noun | `local ReFramework = {}`, `local Rumble = {}`, `local Constants = require(...)` |
| constants / config tables | `UPPER_SNAKE` | `FREE`, `SIGNATURE_TRIGGER`, `MAXIMUM_POWER` |
| booleans / predicates | `is_` / `has_` / `can_` | `is_dualsense(pad)` |
| unused values | `_` | `for _, value in ipairs(list)` |
| game names (fields, methods, types) | **exact** spelling from the dump | `"_ChargeLevel"`, `"<KijinGauge>k__BackingField"` |

**No abbreviations (the user's explicit rule).** Write every name in full words:
- `type_definition` not `td`, `method` not `m`, `value` not `v`, `result` not `r`, `index` not `i`,
  `key` not `k`, `field` not `f`, `object` not `obj`, `signature` not `sig`, `message` not `msg`,
  `character` not `chara`, `arguments` not `args`, `return_value` not `retval`, `pulse` not `p`.
- Module locals: `ReFramework`, `Constants` — never `RE`, `C`.
- Constants: `MAXIMUM` / `MINIMUM` not `MAX` / `MIN`, `BLUETOOTH` not `BT`, `VIBRATION` not `VIB`, `SIGNATURE` not `SIG`.
- Kept as-is (data, not names we choose): weapon keys `"gs"`, `"ls"`… (saved-settings JSON keys), game names from
  the dump (`EAR_S`, `cPadInfo`, `LTRIGGER`), trigger side values `"L"` / `"R"`, well-known acronyms (`ERM`, `VCM`, `JSON`, `HID`).
- `ok` (pcall status) is a word, not an abbreviation.
- Never name a parameter `arg` (shadows Lua's vararg table).
- Existing camelCase keys in `CFG` / `S` stay as they are (saved JSON depends on them). New code uses snake_case.

## 3. Modules
- One module per file. File name = module name. Never write globals.
  ```lua
  local Rumble = {}
  function Rumble.pulse(pad, power, seconds) ... end
  return Rumble
  ```
- `require` with **dots, no extension**: `require("core.re_framework")`.
  Never `require("haptic_pack/xbox/hammer.lua")` (Lua appends `.lua` itself → file not found).
- Bind a required module to a local named after its last component: `local ReFramework = require("core.re_framework")`, `local Constants = require("core.constants")`. No cryptic aliases (`RE`, `C`).
- Only `autorun/*.lua` at the root is auto-run by REFramework. Library modules go in `autorun/haptic_pack/...` and must **not** register `re.on_frame` / hooks at load time unless that is their purpose — expose an `init()` / `install()` instead.
- Shared modules in `autorun/core/`: `re_framework` (game access), `constants`, `language` (EN/VI translate, format),
  `menu` (translated `imgui`, `Menu.slider`, `Menu.combo_value`). Script UI code uses these instead of local copies.
- Release = one file per entry, built with the existing tool `luabundler` (npm, dev dependency): `npm run build`
  (targets in package.json `scripts`) writes `dist/`. Only literal `require("a.b")` strings are bundled.
- A module that is required must `return` its table (a file with no `return` makes `require` return `true`).

## 4. Locals & scope
- Everything `local`. Declare at the top of its scope or just before first use.
- Prefer early return over nested `if`.
- Prefer defaults (`x = x or 0`) over `else` branches.
- Remember: only `nil` and `false` are falsy (`0` and `""` are true).
- Use `tostring` / `tonumber`, never `.. ""` or `+ 0` tricks.

## 5. REFramework / game calls (the important part)
All game access goes through `autorun/core/re_framework.lua` (`ReFramework`). Do not call `sdk.*`, `object:call`, `object:get_field` directly in feature code.
- **Never let an error escape `re.on_frame` / a hook.** Wrap game calls in `pcall`; the frame callback itself is wrapped once (`pcall(frame_body)`).
- **Cache lookups.** `sdk.find_type_definition`, `type_definition:get_method`, enum reads are slow → cache them (ReFramework does). Never look a method up by name every frame on a hot path.
- **Overloaded methods → full signature string**, e.g.
  `"setAdaptiveTriggerFeedback(System.Single, System.Single, System.Single, System.Single, System.Single, via.hid.AdaptiveTriggerMotor)"`.
- **Use only names that exist in `il2cpp_dump.json`** (see `docs/weapon_fields.md`, `docs/GAME_PAD_API.md`). If guessed, mark it `-- UNVERIFIED` in a comment.
- Booleans from `get_field` come back as Lua booleans: convert with `ReFramework.to_number` when comparing numerically.
- `app.cValueHolderF` gauges: read `._Value` (`ReFramework.field_path(weapon_handling, "_Gauge", "_Value")`), not the holder.
- `via.rds.Mandrake` values are encrypted: read them through a getter method, never as a field.
- Singletons can be recreated between scenes: re-fetch them, cache only for a short time (≤ 2 s) or per frame.

## 6. Hooks
- Install through `ReFramework.hook(type_name, signature, before, after)`; `after` must return `return_value` (ReFramework provides a default).
- `arguments[2]` = `this`, parameters start at `arguments[3]`. Decode with `ReFramework.argument_*` / `sdk.to_*`.
- Hooks fire for **every character in co-op** → filter by the local player (`ReFramework.game.player_game_object_address()`, weapon handling address).
- Install lazily (only when the feature is in use) and only once (guard with a flag).
- Calls your own code makes to a hooked method re-enter the hook: set a `self_call` flag around them.
- A managed object kept after the hook returns needs `object:add_ref()` (and `release()` when replaced).

## 7. Per-frame performance
- Target < 0.3 ms per frame for the whole mod (`perf.avg` in the menu).
- No table/closure/string allocation in the per-frame path when avoidable: reuse tables (`t[1], t[2] = a, b`).
- Send hardware commands **only on change** (adaptive trigger) or at a fixed rate (rumble re-send every ~0.03–0.05 s), never unconditionally every frame.
- Read each game field once per frame and pass the value around.
- Throttle debug logs; never `log.info` every frame.

## 8. Haptic design rules (project specific)
- Trigger tuple is always `{ force, vibration, from, to, snap }`; `FREE = { 0, 0, 0, 1, 0 }`.
- No trigger resistance at rest; resistance only in meaningful states (charge, draw, guard).
- Hits / releases → body rumble, not trigger rumble.
- Rumble values: 0..1 normal, up to ~2.0 allowed; durations in **seconds** (not ms).

## 9. Comments (the user's explicit rule: few comments)
The code must read on its own; a file full of comments is hard to read.
- Comment ONLY what the code cannot say:
  - game facts: which game type/enum a value comes from, what an enum value means (`EAR_S = 10, -- roar`), units;
  - `UNVERIFIED` markers for dump names not tested in game;
  - the *why* of a non-obvious choice (`-- Not cached: the game recreates managers between scenes.`).
- One short line. No paragraphs, no ASCII art in code.
- No comment that repeats the name or the code (`-- drop the oldest pulse` above `table.remove(queue, 1)`).
- No usage examples or tutorials in file headers: those go in `docs/`. A file header is at most 2 lines.
- No `-- ====` section banners in new code. No LuaCATS `---@param` / `---@return` blocks.
- Do not delete existing comments in code you were not asked to change.

## 10. Before finishing a Lua change
1. No new globals (lua-language-server: only `sdk re imgui log json draw fs d2d` are allowed globals, see `.luarc.json`).
2. Every `require`d module returns a table; require paths use dots.
3. Every game call is safe (`pcall` / `ReFramework.*`), every hook filters co-op.
4. Nothing allocates or sends hardware commands unconditionally per frame.
5. Run `stylua --check autorun/` if StyLua is installed.
