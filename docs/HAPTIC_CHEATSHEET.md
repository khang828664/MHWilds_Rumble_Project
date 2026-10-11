# Haptic Pack — tri thức nhanh để chỉnh & code

Nguồn: `autorun/MHWilds_Haptic_Pack.lua` (v1.1.0). Số dòng ghi `Lxxx` để nhảy tới.
Tên field thật của game: [weapon_fields.md](weapon_fields.md), [monster_hit_roar.md](monster_hit_roar.md).

---

## 1. Luồng chạy mỗi frame (`frame_body`, L3434)

```
re.on_frame → frame_body
  ├─ get_pad()            ace.PadManager:getPadInfo(0) → ace.cPadInfo (cache 1 frame)
  ├─ process_pulses()     phát các pulse rung đang chờ (re-send mỗi 0.03s)
  ├─ S.lt / S.rt          độ bóp cò 0..1 (get_LTrigger / get_RTrigger)
  ├─ get_chara → get_WeaponHandling → tên type "app.cHunterWpXXHandling" → S.kind (gs, ls, ...)
  ├─ đổi vũ khí → on_weapon_changed (quét field) + init_rules (gán field cho RULES)
  ├─ hàng đợi chung: S.hapticsLeft (haptic lặp), S.rumbleUntil (rung kéo dài)
  └─ CFG[kind].module ? CFG[kind].update(now,c,pad) : update_charge(now,c,pad)
```

Vũ khí → engine:

| Engine | Vũ khí | Hàm |
|---|---|---|
| Charge state machine | gs, hammer, bow | `update_charge` L1927 |
| Event engine (generic) | sns, gl, hh, db, lance, ig | `update_generic` L2668 + `run_event` L2559 |
| Module riêng | sa, cb, ls | `update_sa` L2219, `update_cb` L2298, `update_ls` L2430 |
| Súng | lbg, hbg | `update_gun` L2975 + `GUN_PROFILES` L2811 |

Gán engine: `CFG.xx.update = ...` (L3187+). `module = true` → dùng `update`, không thì dùng `update_charge`.

---

## 2. Hai đầu ra phần cứng

### 2a. Lực cò (adaptive trigger) — tuple 5 số

`send_trigger(side, v)` → `cPadInfo.setAdaptiveTriggerFeedback(f, vib, from, to, snap, AdaptiveTriggerMotor)`

| Vị trí | Tên | Ý nghĩa | Ví dụ |
|---|---|---|---|
| `v[1]` | force | lực cản 0..1 | `1.0` = tường cứng |
| `v[2]` | vib | rung trên cò (0 = không rung) | `0.1` = xung LS, `0.3` = va khiên |
| `v[3]` | from | điểm bắt đầu vùng cản (0..1 hành trình) | `0.2` |
| `v[4]` | to | điểm kết thúc vùng cản | `0.8` |
| `v[5]` | snap | độ "gắt" ở mép vùng (code gọi là snap) | `1.0` cứng, `0.1` mềm — chưa xác minh chính xác |

Mẫu có sẵn:
- `FREE = {0,0,0,1,0}`: thả lỏng.
- `{1,0,0,1,1}`: cứng cả hành trình (giữ charge).
- `{0.8,0,0,0.2,1}`: cản 20% đầu (GS idle).
- `{1,0,0.2,0.8,0.1}`: cản mềm 20–80% (LS Iai).
- `{0.55,0,0.30,0.55,1}`: 1 "click" như phím đàn (HH).

Quy tắc:
- `apply_trigger(side, v)` L1755 **chỉ gửi khi giá trị đổi** (tránh spam). Luôn gọi hàm này, không gọi `send_trigger` trực tiếp.
- Chỉ dùng overload 6 tham số có `AdaptiveTriggerMotor` (L=0, R=1). Bản Left/Right riêng ghi đè lẫn nhau.
- Chế độ `S.out == "rumble"` (Xbox/Vader): tuple được **giả lập bằng motor** (`emu_trigger` L1729) theo vị trí ngón tay.

Hiệu ứng cò ngắn (`S.fx`, đọc bởi `fx_trigger` L2162):
- `trigger_notch(now, side, gap, hit)`: thả lỏng `gap`s rồi đập tường `hit`s, tạo cảm giác "cạch".
- `trigger_impact(now, side, time, freq)`: tường cứng + rung `freq` trong `time`s (va khiên).
- `S.fx = { seq = { {dur, tuple}, ... } }`: chuỗi tuple nối tiếp.

### 2b. Rung thân (rumble / haptic)

> Motor nào rung ra sao, vì sao có các con số 0.03 / 0.08…: xem [MOTORS.md](MOTORS.md).

`out_rumble(strength, role)` L981 → `cPadInfo.addVibrationRequest(strength, VIBRATION_MOTOR_TYPE)`
- Motor type: `LOW=0, HIGH=1, LTRIGGER=2, RTRIGGER=3`.
- Role: `"heavy"` (motor trái, trầm), `"light"` (phải, sắc), `"trigL"`, `"trigR"`, `"body"` (= heavy + light).
- Strength: trong code bị clamp ~`2.0`. Ở rumble mode được nhân thêm `S.rumbleGain`.

Hàm dùng hằng ngày:

| Hàm | Dùng khi | Ghi chú |
|---|---|---|
| `pulse(role, s, dur, delay)` L1020 | 1 xung rung ngắn | tối đa 32 xung chờ, re-send mỗi 0.03s |
| `motor_rumble(s)` | rung body 1 lần | = `out_rumble(s,"body")` |
| `start_rumble(now, s, dur)` L1586 | rung body kéo dài `dur` | qua `S.rumbleUntil` |
| `start_haptics(now, n, gap)` L1593 | lặp haptic `n` lần cách `gap` | |
| `play_haptic()` L1056 | 1 nhịp haptic | DualSense: phát lại preset game đã "bắt" được (hook `triggerVibration` L1442). Rumble: pulse light+heavy |
| `thunk(now, rumble, haptics, time)` L2187 | combo rung + haptic | dùng nhiều nhất trong event |
| `hit_wave(s, d)` L1398 | sóng va chạm kiểu DualSense cho motor ERM | kick 60ms → body → đuôi tắt dần, nhân `WEAPON_HIT[kind]` |

---

## 3. Núm chỉnh toàn cục (`S.*`, lưu vào `reframework/data/MHWilds_Haptic_Pack.json`)

| Biến | Mặc định | Tác dụng |
|---|---|---|
| `S.out` / `S.outMode` | auto | `"dualsense"` (cò thật + haptic) / `"rumble"` (giả lập bằng motor) |
| `S.rumbleGain` | 2.5 | nhân **mọi** rung ở rumble mode |
| `S.trigEmuGain` | 1.6 | độ mạnh giả lập cò bằng motor |
| `S.hapticRumble` | 1.5 | haptic → rung (rumble mode) |
| `S.gameVibOn` / `S.gameVibGain` | true / 4.0 | khuếch đại rung của chính game (đánh trúng, bị đánh) |
| `S.sideBleed` | 0.814 | rung cò lan sang motor bên kia (0 = tách hẳn trái/phải) |
| `S.trigTension` | true | rung nhẹ khi giữ ngón trong vùng cản |
| `S.trigMotorsWork` | true | tay cầm có motor cò thật (Vader 5) |
| `S.lite` | false | giảm tần suất gửi (co-op / máy yếu) |
| `S.btBridge`, `S.btHitGain`, `S.btHapticPulse` | — | DualSense Bluetooth qua plugin `MHWHapticBT.dll` |
| `WEAPON_HIT[kind] = {k, dk}` L1091 | — | lực / độ dài va chạm theo vũ khí |
| `CFG.RELEASE_FRAMES` | 3 | số frame không charge → coi là nhả |
| `CFG.PRESS_THRESHOLD` | 0.25 | bóp cò quá mức này = đang giữ |

---

## 4. `CFG[kind]` — tham số từng vũ khí (L412)

### Chung
`trigger = "R"|"L"`, `triggerEnabled`, `idleTrigger` (tuple lúc rảnh), `module`, `generic`.

### Charge engine (gs / hammer / bow)
| Khóa | Ý nghĩa |
|---|---|
| `holdTrigger` | tuple khi đang charge |
| `holdHaptic`, `holdHapticEvery` | haptic lặp khi giữ (0 = mỗi frame) |
| `levelPulse`, `pulseFreq`, `pulseTime` | xung cò khi lên level |
| `notchStyle` | `"pulse"` / `"detent"` (thả rồi đập) / `"both"`; `notchGap` |
| `notchHaptics`, `notchRumble`, `notchRumbleTime` | rung thân khi lên level |
| `rumbleBase + rumbleStep*lvl`, `rumbleTime` | rung khi **nhả** đòn |
| `hapticBase + hapticStep*lvl`, `hapticGap` | haptic khi nhả |
| `levelSource` | `"auto"/"field"/"sound"/"time"` — nguồn tính level |
| `minCharge`, `minLevel`, `maxLevel`, `fallbackLevelTime` | ngưỡng / ước lượng level theo thời gian |
| `contField`, `sustainByTrigger`, `chargeTrigger` | (GS) giữ trạng thái charge bằng field thay vì cò |

### Khiên (sns / gl / lance / cb)
`guardTrigger`, `guardHold` (giữ cò bao lâu mới tính guard), `guardResist` / `shieldWall` (tuple),
`guardHitRumble`, `guardHitHaptics`, `impactTime`, `impactFreq` (khi đỡ đòn),
`guardRaise = {heavy, light, time}`, `guardBrace`, `guardLower`, `quietGuard` (rumble mode),
`soundGuardHit`, `powerGuardKey`, `powerGuardHitMul` (lance).
> Hiện tại guard được **đoán từ việc giữ cò** (`do_guard` L2503). Guard hit được đoán từ "game rung trong lúc guard" (L1447).

### Event engine — mỗi phần tử trong `events = { ... }`
| Khóa | Ý nghĩa |
|---|---|
| `key` | tên rule trong `RULES[kind]` (field theo dõi) |
| `on` | `"up"` tăng / `"down"` giảm / `"enter"` bật / `"leave"` tắt / `"active"` trong lúc bật |
| `rumble`, `perUnit`, `haptics`, `hapticsPerUnit`, `time`, `timePerUnit` | lực theo số đơn vị thay đổi (vd. bắn 3 viên) |
| `role` | `"light"`/`"heavy"`: rung 1 motor |
| `notch`, `impact`, `impactFreq` | hiệu ứng cò kèm theo |
| `enterRumble/Haptics/Time`, `exitRumble/Haptics/Time`, `notchEnter`, `notchExit` | khi vào/ra trạng thái `active` |
| `beat` | nhịp lặp trong `active` (giây); `heart` = tim lub-dub; `step` = bước chân trái/phải; `beatTrigger` |
| `ramp = {from, to, sec}` | rung tăng dần theo thời gian giữ |
| `cool` | chống nháy (giây) |
| `unless` | bỏ qua khi rule khác đang bật |
| `allOf` | chỉ bật khi tất cả rule cùng bật (IG Triple Up) |
| `big` | field là timer → chỉ tính bước nhảy lớn |
| `edgeFallback` | chưa có field → đoán từ R2 |
| `shot` | sự kiện bắn (súng) |

### Súng — `GUN_PROFILES[ammo]` L2811
`trig` (tuple cò từng loại đạn), `impact`/`freq` (giật cò), `rumble`/`rtime`/`haptics` (giật thân),
`tail` (nhịp xuyên), `delay` (nổ chậm), `shotgun` (boom → pump). Toàn cục súng: `triggerOff`, `triggerKick`, `shotGap`, `rapidScale*`, `ignitionStyle`.

---

## 5. `RULES[kind]` — nối field game vào engine (L669)

```lua
{ key = "gauge", label = "Switch gauge", type = "counter",
  exact   = { "_SlashGauge" },                -- ƯU TIÊN: tên field thật (thêm khóa này)
  pats    = { { "switch", "gauge" }, { "gauge" } },   -- dự phòng: đoán theo từ khóa
  exclude = { "timer", "auto", "recover" } }
```

Thứ tự chọn field (`init_rules` L2117):
1. Field người chơi chọn trong menu (đã lưu ở `SAVE.fields`).
2. `exact`.
3. `pats` / `exclude`.

`type`: `flag` (>0 là bật), `counter` (đếm lên/xuống), `change` (đổi giá trị), `full` (kèm field Max).

Đọc giá trị: `frameVals[key]` (frame này) / `frameVals[key.."#p"]` (frame trước). `live(key)` = field đã từng đổi giá trị (lọc field chết).

**Giới hạn hiện tại:** `discover_fields` (L1502) chỉ nhận field kiểu số/bool/enum **nằm trực tiếp trên WeaponHandling**. Các nguồn dưới đây **chưa** cắm vào RULES được, phải viết reader riêng:

| Loại trong weapon_fields.json | Ví dụ | Cách đọc trong Lua |
|---|---|---|
| field thường | `_Mode`, `_IsKijinOn` | thêm vào `exact` ✅ |
| `cValueHolderF` | `_SlashGauge._Value` | `S.wh:get_field("_SlashGauge"):get_field("_Value")` |
| `method:` | `get_IsSwordAwaken` | `S.wh:call("get_IsSwordAwaken")` (nhớ cache method như `pad_method`) |
| `hunter:` | `checkHunterStatusFlag(2)` | `S.chara:call("checkHunterStatusFlag", 2)` |
| `action:` | `CHARGE=6` | `S.chara:call("get_BaseActionController"):call("get_CurrentActionID")` → `_Index` (kiểm tra `_Category` trước) |

---

## 6. Chỉnh nặng/nhẹ: menu hay code?

- **Menu → "Tune <vũ khí>"**: chỉnh trực tiếp `CFG[kind]` trong lúc chơi, nhưng **KHÔNG được lưu**. Khởi động lại game là mất. Dùng để thử, xong chép số vào `CFG` trong code.
- **Menu → "Controller & rumble motors"**: có lưu (`save_out` L3729). Chỉ hiện khi `S.out == "rumble"` (Xbox/Vader): `rumbleGain`, `trigEmuGain`, `hapticRumble`, `gameVibGain`, `sideBleed`.
- **DualSense không có thanh tổng.** `S.rumbleGain` chỉ nhân ở rumble mode (L1002), và `play_haptic` phát lại preset của game với cường độ gốc. Muốn nhẹ hơn thì giảm số `haptics` / `rumble` từng hiệu ứng.

## 7. Công thức chỉnh nhanh

**Rung mạnh / yếu hơn cho 1 vũ khí:** sửa `rumble`/`haptics` trong `events`, hoặc `rumbleBase`/`rumbleStep` (charge), hoặc `WEAPON_HIT[kind].k` (va chạm).

**Đổi cảm giác cò:** sửa tuple. Đẩy `from`/`to` để dời vùng cản. Hạ `force` để nhẹ hơn. Tăng `vib` để cò rung.

**Thêm 1 hiệu ứng mới cho vũ khí dùng event engine** (ví dụ DB perfect evade):
```lua
-- RULES.db
{ key = "mikiri", label = "Perfect evade", type = "flag", exact = { "<IsMikiriDodgeSuccessed>k__BackingField" }, pats = {} },
-- CFG.db.events
{ key = "mikiri", label = "Perfect evade", on = "enter", rumble = 0.6, haptics = 2, time = 0.12, notch = true, cool = 0.3 },
```

**Thay field đoán sai bằng field thật:** thêm `exact = { "<tên trong weapon_fields.json>" }` vào rule tương ứng. Ví dụ SA: `mode → _Mode`; DB: `demon → _IsKijinOn`, `arch → _IsKijinEnhancement`.

**Thêm 1 vũ khí/engine mới:** tạo `CFG.xx = { module = true, ... }`, viết `update_xx(now, c, pad)`, rồi gán `CFG.xx.update = update_xx`. Cuối hàm luôn gọi `apply_trigger(c.trigger, tuple)`.

---

## 8. Công cụ debug có sẵn (menu REFramework → Script Generated UI)

- **Field viewer:** xem field nào đang đổi giá trị (chỉ cập nhật khi menu mở).
- **Field log** (`S.fieldLogOn`): ghi mọi thay đổi field + hiệu ứng mod + R2/L2 vào `re2_framework_log.txt`. Field đổi mỗi frame (timer) bị tắt tiếng sau 3 dòng → dễ thấy **bẫy timer**.
- **Field recorder** (`S.rec`): ghi 60s → `reframework/data/MHWilds_field_record_<kind>.json`, sắp theo số lần đổi.
- **Haptic catalog** (`S.catalogOn`): ghi preset rung của game.
- `S.ev`: dòng sự kiện cuối cùng mod bắn (hiện trên menu). `S.vibWhy`: lý do đang rung.
- Perf: `perf.avg`, `perf.peak` (ms/frame).
