# Các loại tay cầm & đường đi của tín hiệu rung

Liên quan:
- [MOTORS.md](MOTORS.md): từng motor rung ra sao
- [GAME_PAD_API.md](GAME_PAD_API.md): hàm của game
- [HAPTIC_CHEATSHEET.md](HAPTIC_CHEATSHEET.md): cách mod dùng

Chú thích: ✅ có / ❌ không / ⚠️ có nhưng bị giới hạn / ❓ chưa xác minh trên máy thật.

---

## 1. Tín hiệu đi đường nào? (mod → game → tay cầm)

Mod **không nói chuyện trực tiếp với tay cầm**. Mod gọi hàm rung **của game**, rồi game và Windows chuyển xuống tay cầm.

```
 ┌──────────────┐   pad:call("addVibrationRequest", 0.8, LOW)
 │  Mod (Lua)   │   pad:call("setAdaptiveTriggerFeedback", ...)
 └──────┬───────┘
        ▼  REFramework cho Lua gọi hàm trong game
 ┌──────────────┐
 │ Game (C#)    │   ace.cPadInfo  — hàm rung / lực cò CÓ SẴN của game
 └──────┬───────┘
        ▼
 ┌──────────────┐
 │ RE Engine    │   via.hid  — engine biết đang cắm tay cầm loại gì (DeviceKindDetails)
 └──────┬───────┘
        ▼  chọn API theo loại tay cầm
 ┌────────────────────────────────────────────────────────────────────┐
 │ XInput / Windows.Gaming.Input / thư viện Sony / Steam Input        │
 └──────┬─────────────────────────────────────────────────────────────┘
        ▼  driver Windows → USB / Bluetooth
 ┌──────────────┐
 │  Tay cầm     │
 └──────────────┘
```

Hệ quả:
- Tay cầm nào **game hỗ trợ** thì mod rung được, và chỉ được tới mức game hỗ trợ.
- Tắt rung trong Options của game có thể chặn luôn rung của mod *(❓ chưa test)*.
- Mod không cần driver riêng cho từng hãng.

### Ngoại lệ: DualSense qua Bluetooth (plugin `MHWHapticBT.dll`)

Qua Bluetooth, game chỉ gửi được rung kiểu cũ (giả lập motor), mất haptic và mất lực cò. Plugin xử lý bằng cách **đi tắt**:

```
 Mod (Lua) ──► hàm của game (addVibrationRequest / setAdaptiveTriggerFeedback)
                     │
                     ▼  plugin HOOK (chặn lại tại đây)
              MHWHapticBT.dll ── tự TẠO SÓNG haptic (3000 Hz) + lệnh lực cò
                     │
                     ▼  gửi THẲNG gói HID qua Bluetooth (bỏ qua game/Windows)
                 DualSense
```

- Mod ↔ plugin trao đổi qua file trong `reframework/data/`: `MHWHapticBT_status.json` (plugin báo trạng thái), `MHWHapticBT_config.json` (mod gửi cài đặt).
- Bridge chỉ bật khi plugin báo `bluetooth=true` và `open=true` (`update_bt` trong script chính).
- Lệnh của mod được cộng `+8.0` vào lực rung để plugin phân biệt với rung gốc của game. Đây là quy ước riêng của mod.

---

## 2. Bảng tổng hợp

| Tay cầm | Kết nối | Rung thân | Motor trong cò | Lực cò (adaptive) | Haptic chi tiết | Chế độ mod | Game nhận là (`DeviceKindDetails`) |
|---|---|---|---|---|---|---|---|
| **DualSense** (PS5) | USB | ✅ voice coil | ❌ | ✅ | ✅ | `dualsense` | `DualSense` (8) |
| **DualSense** | Bluetooth | ⚠️ chỉ rung giả lập | ❌ | ❌ (game) / ✅ (plugin) | ❌ (game) / ✅ (plugin) | `dualsense` + BT bridge | `DualSense` (8) |
| **DualSense Edge** | USB / BT | như DualSense ❓ | ❌ | ✅ ❓ | ✅ ❓ | `dualsense` | ❓ |
| **DualShock 4** (PS4) | USB / BT | ✅ 2 ERM | ❌ | ❌ | ❌ | `rumble` | `Dualshock4` (5) |
| **Xbox 360** / tay XInput thường | USB / RF | ✅ 2 ERM | ❌ | ❌ | ❌ | `rumble` | `WindowsXInput` (13) |
| **Xbox One / Series / Elite** | USB / BT / dongle | ✅ 2 ERM | ⚠️ có 4 motor, nhưng XInput chỉ điều khiển 2 motor thân ❓ | ❌ | ❌ | `rumble` | `XboxOne` (11) / `WindowsXInput` (13) / `WindowsGamingInput` (15) |
| **Flydigi Vader 5 Pro** | USB / dongle | ✅ 2 motor | ✅ (đã test: game gửi `LTRIGGER`/`RTRIGGER` được) | ❌ | ❌ | `rumble` (mặc định đã tinh chỉnh) | `WindowsXInput` (13) ❓ |
| **Flydigi Apex** (có cò force-feedback) | USB / dongle | ✅ | ❓ | ⚠️ cò do app Flydigi điều khiển, game không điều khiển được ❓ | ❌ | `rumble` | ❓ |
| **Switch Pro / Joy-Con** | BT (thường qua Steam Input) | ⚠️ có HD Rumble (LRA) nhưng trên PC chỉ ra rung 2 kênh đơn giản | ❌ | ❌ | ❌ | `rumble` | `SwitchProController` (21) / `SwitchJoyCon` (20) |
| **Steam Controller** (2015) | USB / dongle (Steam Input) | ⚠️ không có motor, rung được giả lập bằng haptic dưới trackpad | ❌ | ❌ | ❌ | `rumble` | `SteamController` (18) |
| **Steam Deck** | tích hợp (Steam Input) | ⚠️ rung 2 kênh qua Steam Input ❓ | ❌ | ❌ | ❌ | `rumble` | `SteamDeck` (19) |
| **8BitDo / tay generic** | XInput hoặc DirectInput | ✅ thường 2 motor | ❌ | ❌ | ❌ | `rumble` | `WindowsXInput` (13) / `WindowsJoypad` (16) |

Số trong ngoặc là giá trị enum `via.hid.DeviceKindDetails` lấy từ dump. Đọc trong Lua bằng `ReFramework.pad.device_kind(pad)`.

---

## 3. Từng loại

### DualSense (PS5)
> Chi tiết VCM và cách MH Wilds phát haptic: [DUALSENSE_VCM.md](DUALSENSE_VCM.md).

- **Phần cứng:**
  - 2 **voice coil** ở 2 tay cầm, rung bằng sóng âm thanh nên tinh hơn motor quay.
  - 2 **motor cò** tạo lực cản (adaptive trigger).
  - Loa, gyro, touchpad.
- **USB:** đủ mọi thứ. Game phát haptic dạng âm thanh, và mod "bắt" lại để phát lại (`play_haptic`, hook `triggerVibration`).
- **Bluetooth:** Windows không truyền được haptic âm thanh qua BT, nên game chỉ gửi rung giả lập. Muốn có haptic và lực cò thì phải dùng **plugin `MHWHapticBT.dll`**.
- **Mod:** chế độ `dualsense`, đầy đủ hiệu ứng nhất.

### DualShock 4 (PS4)
- **Phần cứng:** 2 motor ERM (trái nặng / phải nhẹ). Không có motor cò, không có lực cò.
- **Mod:** chế độ `rumble`. Hiệu ứng cò được chuyển thành rung thân, trái → `LOW`, phải → `HIGH` (xem [MOTORS.md](MOTORS.md) mục 5).

### Xbox 360 / tay XInput thông thường
- **Phần cứng:** 2 motor ERM.
- **Mod:** chế độ `rumble`, giống DS4.

### Xbox One / Series / Elite
- **Phần cứng:** 4 motor = 2 ERM thân + 2 **impulse trigger** (motor trong cò).
- ⚠️ **XInput chỉ điều khiển được 2 motor thân.** Muốn dùng motor cò thì game phải dùng API Windows.Gaming.Input / GameInput. Enum của game có `WindowsGamingInput` (15), nên có thể game có hỗ trợ ❓ chưa test với tay Xbox thật.
- **Mod:** chế độ `rumble`. Nếu motor cò không phản hồi thì tắt "Trigger motors respond" trong menu, khi đó rung cò được chuyển sang motor thân.

### Flydigi Vader 5 Pro
- **Phần cứng:** 2 motor thân + 2 motor cò.
- **Đã kiểm chứng:** game gửi `LTRIGGER`/`RTRIGGER` tới được motor cò (ghi chú trong code: *"Vader 5 Pro: the game's LTRIGGER/RTRIGGER motors do respond"*).
- **Mod:** mặc định của chế độ `rumble` được tinh chỉnh trên tay này (`FLYDIGI_DEFAULTS`). Menu có nút "Restore Flydigi Vader 5 Pro defaults".

### Flydigi Apex (dòng có cò force-feedback)
- Cò cứng/mềm do **app Flydigi** (Space Station) điều khiển, game và mod không điều khiển được ❓.
- **Mod:** dùng như tay rung thường.

### Switch Pro / Joy-Con
- **Phần cứng:** **HD Rumble** (motor tuyến tính LRA, chỉnh được tần số).
- Trên PC thường đi qua **Steam Input**, chỉ còn rung 2 kênh đơn giản, mất cái hay của HD Rumble.
- **Mod:** chế độ `rumble`.

### Steam Controller / Steam Deck
- Hầu như luôn đi qua **Steam Input**: game thấy một tay cầm "giả lập", và Steam tự chuyển rung sang phần cứng.
- Steam Controller không có motor quay, rung được giả lập bằng haptic dưới trackpad.
- **Mod:** chế độ `rumble`. Kết quả phụ thuộc vào Steam ❓.

#### Haptic trackpad: game có hỗ trợ không? (đã dò dump, 2026-10-11)

**Kết luận: không.** Game không có hàm nào điều khiển riêng haptic trackpad. Game chỉ gửi rung 2 kênh `LOW`/`HIGH`, Steam tự chuyển sang 2 trackpad (trái ← `LOW`, phải ← `HIGH` ❓ chưa test máy thật).

Bằng chứng (file trong thư mục game):

| Tìm thấy | Ý nghĩa |
|---|---|
| `via.hid.DeviceType.ISteamInputGamePad = 10`, `get_UseISteamInput` | game dùng Steam Input API |
| `via.hid.DeviceKindDetails.SteamController = 18`, `SteamDeck = 19` | nhận diện được tay |
| `via.hid.ISteamInputGamePadDevice` (cha: `via.hid.GamePadDevice`) chỉ có `setAdaptiveTriggerFeedback` ×2, `resetAdaptiveTriggerFeedback`, `get/set_LightBarColor` | hàm cho DualSense qua Steam Input, **không có** hàm trackpad |
| `via.hid.detail.HapticsLocationIndex`: `LeftHandle, RightHandle, LeftTrigger, RightTrigger` | không có vị trí trackpad |
| Không có `TriggerHapticPulse`, `SimpleHapticEvent`, `Trackpad` trong dump | — |

Cách dò lại (Git Bash, ~5 s cho dump 2 GB):
```bash
cd "C:/Program Files (x86)/Steam/steamapps/common/MonsterHunterWilds"
grep -n -i "steam\|haptic\|trackpad" Enums_Internal.hpp
LC_ALL=C grep -a -o -i -E '"[A-Za-z0-9_.]*(HapticPulse|SteamInput|SimpleHaptic|Haptic)[A-Za-z0-9_.]*"' il2cpp_dump.json | sort | uniq -c
# xem method của 1 type: lấy offset rồi cắt đoạn JSON phía sau
LC_ALL=C grep -a -b -o '"via.hid.ISteamInputGamePadDevice": {' il2cpp_dump.json
```

Giải pháp thay thế:
1. **Dùng `Rumble` có sẵn** (`LOW`/`HIGH`): Steam lo phần trackpad. Haptic trackpad là actuator nhanh, nên dùng xung ngắn, sắc (~20-40 ms); mức chặn `ERM_MINIMUM_PULSE` 0.08 s không hợp.
2. **Plugin C++ gọi thẳng Steamworks**: game đã nạp `steam_api64.dll`; plugin gọi `ISteamInput::Legacy_TriggerHapticPulse(handle, pad trái/phải, micro giây)` hoặc `TriggerSimpleHapticEvent` qua flat API (`GetProcAddress`), làm theo mẫu `MHWHapticBT.dll`. Chưa xác minh, có thể đụng rung của game.
3. **Cấu hình Steam** cho game: chỉ chỉnh được bật/tắt và cường độ rung.

Cả 3 chỉ áp dụng khi Steam Input bật (`device_kind` = `SteamController` / `SteamDeck`).

---

## 4. Steam Input — lưu ý quan trọng

Khi **Steam Input bật** cho tay cầm (Steam → game Properties → Controller):
- Game có thể **thấy tay cầm sai loại**, ví dụ DualSense bị nhận thành tay Xbox. Khi đó mất lực cò và mất haptic.
- Rung đi qua Steam nên có thể bị đổi lực hoặc gộp kênh.

→ **DualSense:** nên **tắt Steam Input** cho Monster Hunter Wilds để game nhận đúng DualSense.
→ Nếu mod nhận sai tay cầm thì vào menu → "Controller type" và chọn tay.

---

## 5. Mod chọn chế độ thế nào

| Chế độ | Khi nào | Cò | Thân |
|---|---|---|---|
| `dualsense` | phát hiện DualSense | lực cò thật (`setAdaptiveTriggerFeedback`) | haptic của game phát lại + rung |
| `rumble` | mọi tay khác | **giả lập** lực cò bằng motor cò / motor thân (`emu_trigger`) | rung motor (`out_rumble`), khuếch đại bằng `rumbleGain` |
| `dualsense` + BT bridge | DualSense qua Bluetooth + plugin đang chạy | plugin gửi lực cò thẳng | plugin tạo sóng haptic |

Cách dò:
- Mỗi 2 giây hỏi engine `via.hid.GamePad` → `DeviceKindDetails`, rồi hỏi tới game `ace.cPadInfo` (`update_detect` trong script chính).
- Không chắc thì **giữ nguyên chế độ cũ**, không đổi theo phỏng đoán.
- Có thể ép tay trong menu "Controller type".
- API gọn hơn có trong dump nhưng script chưa dùng: `cPadInfo.get_DualSense()` và `get_DeviceKindDetails()` (`ReFramework.pad.is_dualsense` / `ReFramework.pad.device_kind`).
