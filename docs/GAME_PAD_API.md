# MH Wilds — Hàm điều khiển tay cầm của game (rung + cò)

Lấy từ `il2cpp_dump.json`. Mọi signature dưới đây đều **có trong dump**.
Mô tả hành vi suy ra từ tên + kiểu; chỗ nào chưa chắc ghi *(chưa xác minh)*.
`Lxxx` = dòng trong `autorun/MHWilds_Haptic_Pack.lua` đang dùng hàm đó.

---

## 0. Các tầng

```
Tầng cao  app.AppPadVibrationManager  (ace.PadVibrationManager<app.cADVibration>)
          └─ chạy PRESET rung của game (theo Guid), có suy giảm theo khoảng cách
              └─ app.cADVibration  (ace.cAceAdvancedVibrationBase)  → haptic DualSense (âm thanh-haptic)
Tầng giữa ace.PadManager → ace.cPadInfo       ← script dùng tầng này
          ├─ addVibrationRequest(power, motor)      rung motor đơn giản
          └─ setAdaptiveTriggerFeedback(...)        lực cò DualSense
Tầng thấp via.hid.GamePadDevice
          └─ setMotorPower(motor, power)            ghi thẳng công suất motor
Phụ       app.SoundPostVibrationManager           rung gắn với âm thanh (game tự gọi)
```

Lấy đối tượng trong Lua:
```lua
local pm  = sdk.get_managed_singleton("ace.PadManager")
local pad = pm:call("getPadInfo", 0)              -- hoặc pm:call("get_MainPad")
local vm  = sdk.get_managed_singleton("app.AppPadVibrationManager")   -- tên singleton suy từ dump (chưa xác minh)
```

---

## 1. `ace.PadManager` — quản lý tay cầm (singleton)

| Hàm | Trả về | Ghi chú |
|---|---|---|
| `getPadInfo(System.Int32)` | `ace.cPadInfo` | tay cầm số i (0 = người chơi 1). **L801** |
| `get_MainPad()` | `ace.cPadInfo` | tay cầm chính |
| `get_MainPadIndex()` | `System.Int32` | |
| `isPadEnabled(System.Int32)` | `System.Boolean` | |
| `onDeviceAssigned(via.hid.GamePlayerIndex, via.hid.GamePadDevice)` | Void | game gọi khi cắm tay cầm (hook được) |

Field: `_MainPad : ace.cPadInfo`, `_MainPadIndex : Int32`, `_OriginalPadInfo : ace.cPadInfo[]`.

---

## 2. `ace.cPadInfo` — 1 tay cầm (đối tượng chính)

### Rung
| Hàm | Ghi chú |
|---|---|
| `addVibrationRequest(System.Single power, ace.cPadInfo.VIBRATION_MOTOR_TYPE motor)` | rung 1 motor. Gọi liên tục để giữ rung. **L981 `out_rumble`** |
| `stopVibration()` | dừng rung |
| `updateVibration(System.Single)` | game gọi mỗi frame; tham số có lẽ là delta time *(chưa xác minh)* |
| `setVibrationWaveIndex(System.UInt32)` / `resetVibrationWaveIndex()` / `get_VibrationWaveIndex()` | chỉ số "sóng" rung *(chưa rõ)* |

Giải thích từng motor: [MOTORS.md](MOTORS.md).

`VIBRATION_MOTOR_TYPE`: `LOW=0` (motor trái, trầm), `HIGH=1` (phải, sắc), `LTRIGGER=2`, `RTRIGGER=3` (motor trong cò: tay Xbox One/Series, Vader), `MAX=4`.

### Lực cò (DualSense)
| Hàm | Ghi chú |
|---|---|
| `setAdaptiveTriggerFeedback(Single, Single, Single, Single, Single, via.hid.AdaptiveTriggerMotor)` | **dùng cái này.** 5 số + chọn cò. **L854 `SIG_G`, L896** |
| `setAdaptiveTriggerFeedback(System.Single[], System.Single, via.hid.AdaptiveTriggerMotor)` | bản mảng *(ý nghĩa tham số chưa rõ)* |
| `setAdaptiveTriggerFeedbackLeftTrigger(Single ×5)` / `...RightTrigger(Single ×5)` | ⚠️ 2 hàm này ghi đè lẫn nhau, chỉ 1 cò giữ được hiệu ứng (theo ghi chú L8) |
| `resetAdaptiveTriggerFeedback()` | trả cò về tự do |

5 số (theo cách script dùng): `{ force, vibration, from, to, snap }`, ví dụ `{1,0,0,1,1}` = cứng cả hành trình, `{0,0,0,1,0}` = tự do. Xem [HAPTIC_CHEATSHEET.md](HAPTIC_CHEATSHEET.md) mục 2a.

`via.hid.AdaptiveTriggerMotor`: `LAnalogTriggerMotor=0`, `RAnalogTriggerMotor=1`, `Null=254`, `All=255`.
`via.hid.AdaptiveTriggerState`: `Off=0, Intercepted=1, Standby=2, Active=3, Pulling=4, Fired=5` (chưa thấy hàm nào trả về enum này trên `cPadInfo`).

### Đọc input
| Hàm | Trả về | Ghi chú |
|---|---|---|
| `get_LTrigger()` / `get_RTrigger()` | `System.Single` | độ bóp cò. Script chia 255 nếu > 1 (**L842**) |
| `get_LStick()` / `get_RStick()` | `via.vec2` | |
| `get_KeyOn()` / `get_KeyTrigger()` / `get_KeyRelease()` / `get_KeyRepeat()` | `ace.ACE_PAD_KEY.BITS` | giữ / vừa nhấn / vừa thả / lặp |
| `get_Acceleration()`, `get_AngularVelocity()`, `get_Orientation()` | vec3 / Quaternion | gyro (có bản Left/Right) |

### Nhận diện tay cầm
| Hàm | Trả về | Ghi chú |
|---|---|---|
| `get_DualSense()` | `System.Boolean` | **có phải DualSense không** — cách gọn nhất |
| `get_DeviceKindDetails()` | `via.hid.DeviceKindDetails` | `DualShock4=5, DualSense=8, DualSenseRemotePlay=9, XboxOne=11, WindowsXInput=13, SteamController=18, SteamDeck=19, SwitchProController=21`… |
| `get_DeviceType()` | `via.hid.DeviceType` | |
| `get_IsValid()` | `System.Boolean` | tay cầm còn kết nối |

> Script hiện tự dò thiết bị bằng tên getter/enum (`device_from_game` L1855). Có thể thay bằng `get_DualSense()` / `get_DeviceKindDetails()`.

---

## 3. `app.AppPadVibrationManager` — chạy preset rung của game

Kế thừa `ace.PadVibrationManager<app.cADVibration>` → `ace.PadVibrationManagerBase`.

| Hàm | Ghi chú |
|---|---|
| `addVibrationRequest(System.Guid preset, ace.PadVibrationDefine.PAD_INDEX, via.GameObject, via.GameObject, ace.cJointHash, System.Nullable<via.vec3>, System.Boolean)` | phát preset theo Guid |
| `addVibrationRequest(cMotorVibration, cPadVibrationPreset, System.Guid, PAD_INDEX, GameObject, GameObject, cJointHash, Nullable<vec3>, Boolean)` | bản đầy đủ |
| `addVibrationRequest(ace.motion_track.PadVibrationTrackBase, PAD_INDEX, GameObject, GameObject)` | rung gắn với motion |
| `tryADVibration(cPadVibrationPreset, cADVibrationPreset)` → Boolean | thử phát haptic DualSense của preset |
| `stopVibration(System.Guid, PAD_INDEX)` / `stopMotorVibration(Guid, PAD_INDEX)` | dừng 1 preset |
| `stopAllVibration()` / `stopAllMotorVibration()` | dừng tất cả |
| `requestPauseVibration()` / `requestResumeVibration()` | tạm dừng / tiếp tục |
| **`setGainBias(System.Single)`** | **hệ số khuếch đại chung** — ứng viên làm "thanh tổng" cho DualSense *(chưa xác minh)* |
| `get_IsVibrationOn()` | rung đang bật trong option game |
| `IsPadDualSenseCheck(...)` | (trên Base) |

`ace.PadVibrationDefine.PAD_INDEX`: `INVALID=0, PAD_1=1, PAD_2=2, PAD_3=4, PAD_4=8, ALL=15` (bitmask).
Field đáng chú ý: `_ADVibration : app.cADVibration`, `_AllPresetDict : Dictionary<Guid, cPadVibrationPreset>`, `_IsPauseVibration : Boolean` (`_IsPauseVibrationPrev` = bẫy, giá trị frame trước).

---

## 4. `ace.cAceAdvancedVibrationBase` / `app.cADVibration` — haptic DualSense

| Hàm | Ghi chú |
|---|---|
| `triggerVibration(System.UInt32, ace.user_data.ADVibrationPresetList.cADVibrationPreset, ace.PadVibrationDefine.cRequestData, System.UInt32)` | **mỗi haptic của game đi qua đây.** Script hook để bắt preset rồi phát lại (**L1052, L1442**, `play_haptic` L1056) |
| `IsExistDualSense()` → Boolean | có DualSense đang cắm |
| `stopADVibration(System.UInt32)`, `stopAllVibration()`, `stopAllNormalADVibration()`, `stopAllPostVibration()` | dừng haptic |
| `pauseAllVibration()` / `resumeAllVibration()` | |
| `isVibrationOn()`, `isPlayingAt(Int32)`, `isEnabledAt(Int32)` | trạng thái |
| `getVolume(cADVibrationPreset)` → Single | âm lượng haptic của preset |
| `onPostVibrationEvent(System.UInt32, System.Single, System.Single)` | sự kiện rung sau âm thanh *(chưa rõ)* |

`ace.PadVibrationDefine.cRequestData`: `get_Power()`, `get_Motor()`, `get_PresetGuid()`, `get_IsFinished()`, `get_SendPadMask()`; field `_CurrentPower`, `_ElapsedTime`.

---

## 5. `app.SoundPostVibrationManager` — rung theo âm thanh

| Hàm | Ghi chú |
|---|---|
| `requestVibration(app.snd_user_data.SoundVibrationTriggerListData.VibrationTrigger, via.GameObject)` | game gọi khi một âm thanh có rung đi kèm (chém, lên level charge LS…). `args[4]` = GameObject → lọc nhân vật của mình. Script hook ở **L1627** |

---

## 6. `via.hid.GamePadDevice` — tầng thấp (chưa dùng)

| Hàm | Ghi chú |
|---|---|
| `setMotorPower(via.hid.GamePadMotor, System.Single)` | ghi thẳng công suất motor, bỏ qua hệ thống rung của game *(chưa test, có thể bị game ghi đè mỗi frame)* |
| `getMotorPower(via.hid.GamePadMotor)` → Single | đọc công suất hiện tại |
| `resetMotors()` | |
| `get_ForceFeedbackEnable()` / `set_ForceFeedbackEnable(Boolean)` | |
| `get_AnalogL()` / `get_AnalogR()` | cò thô |

`via.hid.GamePadMotor`: `Motor0..3=0..3, Max=4, Null=5, All=6, LowFrequencyMotor=128, HighFrequencyMotor=129, LAnalogTriggerMotor=130, RAnalogTriggerMotor=131, HmdMotor=132`.
Lấy device: `ace.cPadInfo` có field `_Device : via.hid.GamePadDevice`.

---

## 7. Mẫu Lua tối thiểu

```lua
local pm = sdk.get_managed_singleton("ace.PadManager")
local pad = pm and pm:call("getPadInfo", 0)
if pad then
    pad:call("addVibrationRequest", 0.8, 0)    -- rung motor LOW (gọi mỗi frame để giữ rung)
    -- lực cò phải (DualSense): cứng cả hành trình
    pad:call("setAdaptiveTriggerFeedback(System.Single, System.Single, System.Single, System.Single, System.Single, via.hid.AdaptiveTriggerMotor)",
             1.0, 0.0, 0.0, 1.0, 1.0, 1)
    -- trả cò về tự do
    pad:call("resetAdaptiveTriggerFeedback")
end
```

Lưu ý:
- **Hàm có overload** (`setAdaptiveTriggerFeedback`, `addVibrationRequest` của manager) → gọi bằng **signature đầy đủ** như trên, không thì REFramework có thể chọn nhầm.
- **Gọi mỗi frame → cache method:** `sdk.find_type_definition("ace.cPadInfo"):get_method(sig)` rồi `m:call(pad, ...)`. Tra tên mỗi lần rất tốn (xem `pad_method` L792).
- **Chỉ gửi lực cò khi giá trị đổi** (`apply_trigger` L1755). Gửi lại liên tục làm cò giật.
- Giá trị rung > 1.0: script dùng tới ~2.0, ý nghĩa phần vượt 1 chưa rõ. `+8.0` (L1008) là quy ước riêng của mod với plugin Bluetooth, không phải của game.
- Hook trong co-op: `triggerVibration` / `requestVibration` được gọi cho **mọi** nhân vật → luôn lọc theo GameObject của mình.

---

## 8. Đọc trạng thái game (để quyết định khi nào rung)

Không thuộc tay cầm, xem file riêng:
- Field vũ khí: [weapon_fields.md](weapon_fields.md) / [weapon_fields.json](weapon_fields.json)
- Đánh trúng, tiếng gầm, guard, action ID: [monster_hit_roar.md](monster_hit_roar.md)
- Cách script dùng tất cả: [HAPTIC_CHEATSHEET.md](HAPTIC_CHEATSHEET.md)
