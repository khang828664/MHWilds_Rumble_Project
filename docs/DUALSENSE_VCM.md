# DualSense VCM — phần cứng & cách MH Wilds dùng

Ký hiệu độ tin cậy:
- **[dump]** = tên/kiểu có trong `il2cpp_dump.json`
- **[catalog]** = dữ liệu thật mod đã ghi lại (`reframework/data/MHWilds_haptic_catalog.json`, 40 preset, chơi GS + LS)
- **[web]** = nguồn bên ngoài (ở cuối file)
- **[suy luận]** = suy ra từ tên, chưa kiểm chứng

Liên quan: [MOTORS.md](MOTORS.md), [CONTROLLERS.md](CONTROLLERS.md), [GAME_PAD_API.md](GAME_PAD_API.md).

---

## 1. Phần cứng: VCM khác motor rung thế nào

| | Motor ERM (Xbox, DS4) | VCM — voice coil (DualSense) |
|---|---|---|
| Cấu tạo | cục kim loại lệch tâm **quay tròn** | nam châm + cuộn dây **dao động thẳng** trên lò xo/màng, giống loa **[web]** |
| Điều khiển bằng | 1 con số "mạnh bao nhiêu" | **một dạng sóng** như tín hiệu âm thanh **[web]** |
| Khởi động | chậm, cần ~30–50 ms để quay | gần như tức thì |
| Tả được | to/nhỏ | to/nhỏ + **tần số** + **hình dạng**: gõ, sột soạt, mưa, dây cung căng… |
| Mạch điều khiển | driver motor | chip âm thanh **Realtek** → khuếch đại **Nuvoton** → 2 VCM **[web]** |

DualSense có **2 VCM**, ở tay cầm trái và tay cầm phải. Lực cò (adaptive trigger) là **motor + bánh răng riêng**, không phải VCM.

> Chưa tìm được số đo dải tần (Hz) chính thức của VCM DualSense.

---

## 2. PC gửi sóng tới VCM bằng cách nào

| Kết nối | Haptic VCM | Ghi chú |
|---|---|---|
| **USB** | ✅ qua **thiết bị âm thanh** | Windows/Linux thấy DualSense là card âm thanh nhiều kênh. Theo báo cáo cộng đồng: 4 kênh, cặp kênh sau điều khiển 2 VCM **[web]** |
| **Bluetooth** | ⚠️ cần gói HID đặc biệt | report `0x31`: header có tag/sequence + **CRC32**. USB dùng report `0x02` không có CRC **[web]**. Game trên PC thường không gửi → chỉ còn **rung giả lập** ("compatible vibration") |

Rung kiểu cũ ("classic rumble") vẫn có để tương thích ngược: DualSense **giả lập motor bằng VCM** **[web]**.
→ Đó là lý do mod cần plugin **`MHWHapticBT.dll`** khi dùng Bluetooth: plugin tự tạo sóng và đóng gói HID gửi thẳng (xem [CONTROLLERS.md](CONTROLLERS.md) mục 1).

---

## 3. Bên trong MH Wilds: mỗi "rung" là một preset có 3 bản

Mỗi rung trong game là một **preset**. Preset chứa sẵn dữ liệu cho cả 3 kiểu tay cầm; game chọn bản phù hợp lúc chạy.

```
                          ┌─ (1) .vsrc  — sóng âm thanh cho VCM DualSense
 Preset rung (1 sự kiện) ─┼─ (2) .bnvib — sóng HD Rumble (2 dải tần)        [suy luận: Nintendo Switch]
                          └─ (3) motor  — danh sách {motor, lực, thời gian} cho tay ERM
```

| Bản | Class / field **[dump]** | Nội dung |
|---|---|---|
| (1) VCM | `ace.user_data.ADVibrationPresetList.cADVibrationPreset` | `_VibAudioSource : via.audiorender.VibrationSourceResourceHolder` (file `.vsrc`), `_Volume : Single` (**dB**), `_DurationAD : Single`, `_VibrationOutputNode : Int32`, `_VibrationTrigger : UInt32` (id) |
| (2) HD Rumble | cùng preset: `_BnvibResource : via.hid.BnvibResourceHolder` | tham số phát `via.hid.BnvibOutputParam { gainLow, gainHigh, pitchLow, pitchHigh, playPosition }`: 2 dải tần thấp/cao kiểu HD Rumble **[suy luận]** |
| (3) Motor | `ace.user_data.PadVibrationPresetList.cPadVibrationPreset` → `_MotorVibration : cMotorVibration[]` | mỗi phần tử: `_MotorType` (LOW/HIGH/LTRIGGER/RTRIGGER), `_Power`, `_Time`, `_IsTimeAttenuation`, `_TimeAttenuationType : via.curve.EaseType` (đường cong tắt dần); thêm suy giảm theo khoảng cách (`_IsDistanceAttenuation`, `_AttenuationDistance`) |

**[catalog]** trên PC: mọi preset ghi lại đều có `.vsrc` nhưng `bnvib = nil` → bản HD Rumble không có trên PC.

### Phát lên tay trái / phải / cả hai

`_VibrationOutputNode` → enum `via.hid.VibrationOutputNode` **[dump]**:

| Giá trị | Tên | Nghĩa |
|---|---|---|
| 0 | `Dual` | cả 2 VCM |
| 1 | `LeftOnly` | chỉ VCM trái |
| 2 | `RightOnly` | chỉ VCM phải |
| 3 | `LeftAndRightSeparately` | 2 kênh riêng (stereo) |

**[catalog]**: toàn bộ 40 preset ghi lại đều là `node=0` (Dual).

---

## 4. Đường đi trong game (sự kiện → VCM)

```
 Âm thanh trong game phát (chém, đánh trúng, charge, quái gầm...)
        │
        ▼
 app.SoundVibrationContainer              (component gắn theo object có âm thanh)
   _VibTriggerList : SoundVibrationTriggerListData
        │   tra TriggerId của âm thanh → VibrationTrigger { _TriggerId, _PresetGuid, _AlwaysEnabled, _StopOnEndOfEvent }
        ▼
 app.SoundPostVibrationManager.requestVibration(VibrationTrigger, GameObject)   ← mod hook ở đây (LS level-up)
        │
        ▼
 app.AppPadVibrationManager  (ace.PadVibrationManager<app.cADVibration>)
   addVibrationRequest(Guid, PAD_INDEX, ...)  →  tryADVibration(cPadVibrationPreset, cADVibrationPreset)
        │
        ├── DualSense có mặt? (IsExistDualSense)
        │      ▼ CÓ
        │   app.cADVibration.triggerVibration(id, cADVibrationPreset, cRequestData, padBits)   ← mod hook ở đây
        │      → phát file .vsrc lên "bus" âm thanh haptic (cBusInfo: BusId / BusAssignId)
        │      → USB audio → Realtek → Nuvoton → 2 VCM
        │
        └── KHÔNG → chạy cMotorVibration[] → ace.cPadInfo.addVibrationRequest(power, motor) → ERM
```

Mọi tên trong sơ đồ đều có trong **[dump]**. Thứ tự rẽ nhánh là **[suy luận]** từ tên hàm.

Chi tiết thêm **[dump]**:
- `cAceAdvancedVibrationBase._SineWavResource_L` / `_SineWavResource_R` (`.vsrc`) và `_LegacyVibrating : UInt32` → **[suy luận]** khi có lệnh rung motor kiểu cũ, game phát **sóng sin** lên VCM trái/phải để giả lập motor.
- Suy giảm theo khoảng cách: `getDistanceAttenuationVolume(cRequestData)`, `UPDATE_ATTEANUATION_INFO`. Rung của vật ở xa sẽ nhẹ hơn.
- Dừng / tạm dừng: `stopADVibration(UInt32)`, `stopAllADVibrationIfDualSenseMissing()`, `pauseAllVibration()`.
- Component cấp engine: `via.hid.HDVibrationSource` (`Volume`, `Loop`, `LoopStartRate`/`LoopEndRate`, `Binaural`, `Vibration2D`, `PriorityLayer`; `TargetNode`: `Dual=0, Left=1, Right=2`).
- `via.hid.DualSenseDevice` (kế thừa `PSGamePadDevice`): `setAdaptiveTriggerFeedback`, `resetAdaptiveTriggerFeedback`, `VibrationWaveIndex`, `set_LightBarColor(via.Color)` (**đèn LED** cũng điều khiển được).

---

## 5. Dữ liệu thật: game phát những sóng gì **[catalog]**

Tất cả nằm ở `Sound/ADVibration/Wav/<tên>.vsrc`. Quy ước đặt tên:

| Tiền tố | Nghĩa **[suy luận]** | Ví dụ (số lần phát) |
|---|---|---|
| `wp00_two_` | Great Sword | `wp00_two_cmn_hit` (x57), `wp00_two_iron_ground_imp` (x49), `wp00_two_fo_sword_whoosh` (x52), `wp00_two_cmn_penetrate_hit` |
| `wp_swo_` | Long Sword | `wp_swo_iron_sword_whoosh_velocity` (x74), `wp_swo_efx_mikiri_success`, `wp_swo_efx_renki_use` |
| `wp_cmn_` | chung mọi vũ khí | `wp_cmn_efx_charge_lv1/2/3`, `wp_cmn_hit_slash_small/large`, `wp_cmn_hit_bullet_small` |
| `hm_` | hunter | `hm_buff_dmg_big/mid` (bị đánh), `hm_prop_slinger_rope_prop_catch_gm`, `hm_gm_collect_mid` |
| `em0154_vo_` | **tiếng quái** (monster EM0154) | `em0154_vo_bind`, `em0154_vo_bind_short`, `em0154_vo_bind_angry` (**tiếng gầm**) |
| `sys_gui_` | menu | `sys_gui_select_cmn`, `sys_gui_decide_cmn`, `sys_gui_start_quest` |
| `pt00_` | Seikret (thú cưỡi) | `pt00_cmn_vo_automove_change` |
| `silence` | sóng câm | `silence` (x154, nhiều nhất) |

Quan sát:
- **Mỗi đòn có sóng riêng**: vung kiếm (`whoosh`), chém trúng nhỏ/lớn, đập đất (`ground_imp`), charge từng level. Đây là thứ VCM làm được còn ERM không làm được.
- **Tiếng gầm của quái có sóng haptic riêng** (`em0154_vo_bind*`). Đây là cách thứ 2 để nhận biết quái gầm, bên cạnh `cHunterDamageInfo._DamageType = EAR_*` ([monster_hit_roar.md](monster_hit_roar.md)). Cách này còn **biết được con nào** qua mã `emXXXX`.
- `_Volume` tính bằng **dB**, từ −20 (charge lv1, rất nhẹ) tới +6 (chém lớn, đâm xuyên).
- `_DurationAD` = 0 trên mọi preset ghi được → độ dài do chính file sóng quyết định **[suy luận]**.

---

## 6. Mod đang tận dụng VCM thế nào (`MHWilds_Haptic_Pack.lua`)

| Kỹ thuật | Ở đâu | Làm gì |
|---|---|---|
| Bắt & phát lại preset | hook `triggerVibration` (L1442), `play_haptic` (L1056) | chép preset đang phát, nhất là lúc **đang charge**, rồi phát lại theo nhịp của mod (giữ charge Hammer/Bow/LS) |
| Phân loại theo tên `.vsrc` | `PRESET_RULES` (L1316), `classify_preset` | Bluetooth: đọc tên file → quyết định "hit" hay "tap" và lực. Lực được nhân theo `_Volume` (dB → `10^(dB/40)`) |
| Đọc lực/độ dài preset | `analyze_preset` (L1107) | tay rung thường: đổi preset thành `hit_wave` cho motor ERM |
| Ghi catalog | `catalog_record` / `save_catalog` (L1274) | công cụ nghiên cứu, tạo ra file catalog dùng ở mục 5 |

---

## 7. Hướng nghiên cứu tiếp

| Ý tưởng | Dựa trên | Trạng thái |
|---|---|---|
| Phát **một sóng cụ thể theo tên** (ví dụ `wp_cmn_efx_charge_lv3`) bất cứ lúc nào | giữ lại `cADVibrationPreset` theo tên từ hook, rồi gọi `triggerVibration` | khả thi, mod đã làm với preset gần nhất |
| Nhận diện **quái gầm + con nào** qua tên `em*_vo_*` | hook `triggerVibration` + `_VibAudioSource.get_ResourcePath()` | cần thử nhiều quái |
| Chỉnh âm lượng haptic của game (thanh tổng cho DualSense) | `cADVibrationPreset._Volume`, `PadVibrationManager.setGainBias` | **[suy luận]**, chưa test |
| Phát stereo trái/phải riêng | `_VibrationOutputNode = 3` / `HDVibrationSource.TargetNode` | chưa test |
| Đổi màu đèn LED theo trạng thái (Demon Mode, Spirit level) | `PSGamePadDevice.set_LightBarColor(via.Color)` | API có trong dump, chưa test |
| Catalog đầy đủ 14 vũ khí + nhiều quái | bật `S.catalogOn` rồi chơi lần lượt | hiện mới có GS + LS |

---

## Nguồn

- [Actronika — What's under the hood of the DualSense?](https://actronika.com/post/whats-under-the-hood-of-the-dualsense)
- [Actronika — DualSense towards realistic haptics](https://actronika.com/post/dualsense-towards-realistic-haptics-sony-playstation-5-controller-review-actronika)
- [Linux kernel hid-playstation.c](https://gbmc.googlesource.com/linux/+/refs/heads/dev-5.15/drivers/hid/hid-playstation.c) và [patch thảo luận haptics](https://patchwork.kernel.org/comment/23879469)
- [PipeWire issue #2486 — DualSense haptics là thiết bị âm thanh](https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/2486)
- [Báo cáo cộng đồng: audio & haptics DualSense (4 kênh)](https://gitlab.com/TYcommand/Gamepads/-/issues/11)
- [MP1st — Deep dive haptic feedback Astro's Playroom](https://mp1st.com/features/deep-dive-look-at-haptic-feedback-of-astros-playroom)
- [Microsoft GameInput & DualSense](https://tbreak.com/microsoft-gameinput-dualsense-controls/)
