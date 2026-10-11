# Motor rung — dễ hiểu

## 1. Trong tay cầm có gì

```
        ┌───────── L2 ─────────┐             ┌───────── R2 ─────────┐
        │  LTRIGGER (2)        │             │  RTRIGGER (3)        │   motor nhỏ trong cò
        └──────────────────────┘             └──────────────────────┘   (chỉ Xbox One/Series, Vader...)

   ┌──────────────┐                                     ┌──────────────┐
   │  LOW (0)     │  tay cầm TRÁI                       │  HIGH (1)    │  tay cầm PHẢI
   │  cục nặng    │  → "ùùù", "thịch"                   │  cục nhẹ     │  → "rừ rừ", "tách"
   └──────────────┘                                     └──────────────┘
```

| Motor | Số (`Constants.MOTOR`) | Vị trí | Cảm giác | Dùng cho | Tên role trong mod |
|---|---|---|---|---|---|
| `LOW` | 0 | tay cầm trái | trầm, nặng, "thịch", lan khắp tay | va chạm mạnh, nổ, búa đập, tim đập | `heavy` |
| `HIGH` | 1 | tay cầm phải | sắc, nhẹ, "rừ rừ", "tách" | chém, đạn nhỏ, click, tiếng tách | `light` |
| `LTRIGGER` | 2 | trong cò L2 | rung dưới ngón trỏ trái | ngắm, kéo dây cung | `trigL` |
| `RTRIGGER` | 3 | trong cò R2 | rung dưới ngón trỏ phải | bắn, giật súng, lên level charge | `trigR` |
| *(cả 2 thân)* | 0 + 1 | | rung toàn thân | phần lớn hiệu ứng | `body` |

Đây là motor **ERM**: một cục kim loại lệch tâm quay tròn. Quay càng nhanh thì rung càng mạnh. Motor `LOW` có cục to nên rung trầm, motor `HIGH` có cục nhỏ nên rung sắc.

### Mỗi loại tay cầm có những motor nào

> Bảng đầy đủ mọi tay cầm + đường đi của tín hiệu: [CONTROLLERS.md](CONTROLLERS.md).

| Tay cầm | LOW / HIGH | LTRIGGER / RTRIGGER | Lực cò (adaptive trigger) |
|---|---|---|---|
| Xbox One / Series, Flydigi Vader 5 | ✅ motor thật | ✅ motor thật | ❌ |
| DualShock 4, Switch Pro | ✅ | ❌ (không có, lệnh bị bỏ qua) | ❌ |
| **DualSense (PS5)** | ⚠️ không có ERM: dùng **voice coil** (giống loa), rung LOW/HIGH được giả lập | ❌ | ✅ |

> Rung (`addVibrationRequest`) và **lực cò** (`setAdaptiveTriggerFeedback`) là **2 thứ khác nhau**.
> Lực cò làm cò **cứng/nặng** để cản ngón tay, không phải rung. Xem mục 2a trong [HAPTIC_CHEATSHEET.md](HAPTIC_CHEATSHEET.md).

---

## 2. Một lệnh rung gồm 2 con số

```lua
ReFramework.pad.rumble(pad, power, motor)
--                 ^       ^
--                 |       └─ motor nào: Constants.MOTOR.LOW / HIGH / LTRIGGER / RTRIGGER
--                 └───────── mạnh bao nhiêu: 0.0 (tắt) .. 1.0 (mạnh), mod cho tới 2.0
```

**Không có tham số thời gian.** Mỗi lệnh chỉ rung một nhịp rất ngắn. Muốn rung **kéo dài** thì phải **gửi lại liên tục**, khoảng mỗi `Constants.RUMBLE.RESEND_INTERVAL` = 0.03 s. Ngừng gửi là motor tự tắt.

```
gửi  gửi  gửi  gửi  gửi            (ngừng gửi)
 |    |    |    |    |
 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░                    ← motor quay rồi tắt dần
 0   0.03 0.06 0.09 0.12 s
```

Hàm `pulse(role, power, seconds)` trong script chính làm đúng việc này: tự gửi lại mỗi 0.03 s cho đến hết `seconds`.

---

## 3. Giới hạn vật lý (vì sao có mấy con số "lạ")

| Hằng số | Giá trị | Vì sao |
|---|---|---|
| `Constants.RUMBLE.ERM_MINIMUM_PULSE` | 0.08 s | motor ERM cần khoảng 30–50 ms mới quay đủ nhanh. Xung ngắn hơn ~80 ms gần như không cảm nhận được |
| `Constants.RUMBLE.KICK_TIME` | 0.06 s | cú "đá" đầu mỗi va chạm: cả 2 motor chạy hết công suất cho motor kịp quay |
| `Constants.RUMBLE.RESEND_INTERVAL` | 0.03 s | chu kỳ gửi lại để rung không bị đứt quãng |
| `Constants.RUMBLE.STREAM_INTERVAL` | 0.05 s | hiệu ứng kéo dài (giữ charge, rè rè) gửi thưa hơn để đỡ tốn CPU |
| `Constants.RUMBLE.MAXIMUM_POWER` | 2.0 | trần lực. Trên 1.0 có tác dụng hay không tuỳ tay cầm *(chưa xác minh)* |

---

## 4. Ghép motor thành cảm giác (công thức mod đang dùng)

| Cảm giác | Công thức | Ở đâu trong code |
|---|---|---|
| **Va chạm** (đánh trúng) | 0–60 ms: LOW + HIGH full → 60 ms–55%: LOW mạnh, HIGH 60% → đuôi: LOW nhỏ dần | `hit_wave` |
| **Tim đập** (Demon Mode) | LOW 0.07 s → nghỉ 0.16 s → LOW 65% lực 0.06 s, lặp mỗi 0.85 s | `run_event` (`heart`) |
| **Bước chân** (Lance Charge) | luân phiên LOW / HIGH mỗi 0.28 s | `run_event` (`step`) |
| **Click / tách** | HIGH ngắn ~0.06–0.1 s | `pulse("light", ...)` |
| **Thịch** (giơ khiên) | LOW mạnh + HIGH nhẹ ~0.1–0.16 s | `guard_feel` |
| **Rè rè liên tục** (Savage Axe) | body lực nhỏ, gửi đều mỗi 0.05 s | `update_cb` |

Mẹo:
- Muốn **nặng** thì dùng LOW nhiều hơn. Muốn **sắc / nhanh** thì dùng HIGH.
- Muốn **trái/phải** khác nhau thì tách LOW (trái) và HIGH (phải).
- Đừng làm xung ngắn hơn 0.08 s trên tay cầm có ERM.

---

## 5. Tay cầm không có motor cò

Nếu tay cầm không có `LTRIGGER`/`RTRIGGER` (DS4, Switch Pro), hoặc tắt "Trigger motors respond" trong menu, thì mod chuyển rung cò sang motor thân (`out_rumble`):
- rung cò **trái** → motor **LOW** (tay trái), 80% lực
- rung cò **phải** → motor **HIGH** (tay phải), 100% lực
- `S.sideBleed` (mặc định 0.814): bao nhiêu phần lực lan sang motor bên kia cho đầy tay. 0 = tách hẳn trái/phải.

---

## 6. Module `Rumble` (`autorun/haptic_pack/hardwares/rumble.lua`)

```lua
local Rumble = require("haptic_pack.hardwares.rumble")

Rumble.vibrate(power, seconds, motor, delay)   -- motor mặc định Constants.MOTOR.LOW, delay mặc định 0
Rumble.left(0.9, 0.12)                         -- "thịch" nặng bên trái
Rumble.right(0.5, 0.08)                        -- "tách" sắc bên phải
Rumble.body(1.0, 0.3)                          -- cả 2 motor
Rumble.left(0.8, 0.07); Rumble.left(0.5, 0.06, 0.16)   -- tim đập: lub … dub
Rumble.stop()                                  -- xoá hàng đợi, tắt motor
Rumble.is_active()

-- BẮT BUỘC: gọi 1 lần mỗi frame trong re.on_frame, không có thì không rung
Rumble.update(pad)
```

- Lực bị kẹp trong `0..Constants.RUMBLE.MAXIMUM_POWER`.
- Thời gian tối thiểu là `ERM_MINIMUM_PULSE`.
- Nhiều xung chồng lên cùng một motor thì chỉ gửi xung mạnh nhất.
