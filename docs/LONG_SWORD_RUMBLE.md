# Long Sword — rumble pattern (Xbox / ERM)

Module: `autorun/haptic_pack/xbox/long_sword.lua`. Motor: `LOW` = trái, nặng (thân, "trọng lượng"); `HIGH` = phải, nhẹ (độ sắc, "kim loại");
`RT` / `LT` = motor trong cò (impulse trigger, Xbox One / Series, Vader 5), rung ngay dưới ngón trỏ.

## Triết lý

| Nguyên tắc | Áp dụng |
|---|---|
| Kiếm sắc, không phải búa | Hit thường ngắn (0.09 s), HIGH đi kèm LOW để có cảm giác "cắt", không "đập" |
| Spirit gauge = sức mạnh tích luỹ | Mọi hit mạnh dần theo aura (trắng → vàng → đỏ), `hit_power_per_aura` |
| Im lặng trước nhát chém | Iai stance chỉ có 1 tiếng "tách" khi tra kiếm, sau đó im để nhát Iai nổi bật |
| Counter phải "kêu" | Foresight / Iai Spirit thành công: HIGH 1.0 sắc trước, LOW sâu theo sau 40 ms |
| Phân tầng rõ | nền (hum) < hit thường < level-up < counter < đòn đỏ / finisher |

## Rung cò (impulse trigger)

| Nguyên tắc | Áp dụng |
|---|---|
| RT = lưỡi kiếm | Spirit Blade, Spirit Charge, Iai, Foresight đều bấm RT, nên năng lượng và vết cắt đi qua ngón trỏ phải |
| LT chỉ khi va chạm lớn | counter thành công, charge đầy, aura đỏ, đòn đỏ: LT + RT cùng đập, cả tay cầm "rung lên" |
| Charge = năng lượng dồn vào ngón tay | RT hum 0.08 + 0.06/level; nhịp tim vẫn ở thân (LOW) để tách 2 lớp |
| Aura giảm không rung cò | mất sức mạnh chỉ cảm nhận ở thân, cò im |

| Sự kiện | RT | LT |
|---|---|---|
| Spirit Blade (vút) | kick 0.30 | — |
| Giữ Spirit Charge | hum 0.08 → 0.26 theo level | — |
| Charge lên level / đầy | kick 0.80 / kick 0.80 rồi 1.00 | — / 0.60 ở nhịp 2 |
| Aura trắng / vàng / đỏ | 1 / 2 / 3 kick tăng dần | — / — / 0.80 ở nhịp cuối |
| Hit thường | kick = hit × 0.7 | — |
| Vào Iai stance | kick 0.45 (chốt vỏ kiếm) | — |
| Foresight / Iai Spirit counter | 1.00 (+ đuôi 0.50 cho Iai Spirit) | 0.80 / 0.90 |
| Foresight trúng / trúng đỏ | 0.70 / 1.00 | — / 0.70 |
| Iai Slash / Iai Spirit / Iai Spirit đỏ | 0.90 / 1.00 / 1.00 + đuôi | — / 0.60 / 0.80 |
| Helm Breaker | đà 0.30, mỗi hit = hit × 0.8 | — |
| Spirit Roundslash đỏ | 1.00 | 0.70 |

`TUNING.trigger_gain` nhân riêng phần rung cò (0 = tắt, cho tay không có motor cò: DS4, Switch Pro).

## Bảng sự kiện

| Sự kiện | Nguồn game | Pattern |
|---|---|---|
| Spirit charge (giữ RT) | hook `updateKijinCharge()` | HIGH hum 0.10 + 0.07/level, nhịp tim LOW mỗi 0.50 / 0.40 / 0.28 s theo level |
| Charge lên level | `_KijinChargeLv` tăng | tick: HIGH 0.6 + LOW 0.3, 80 ms |
| Charge đầy | `_IsKijinFullCharge` | tick đôi, nhịp 2 mạnh hơn |
| Aura lên trắng / vàng / đỏ | `<AuraLevel>k__BackingField` tăng | 1 / 2 / 3 nhịp tăng dần; đỏ có đuôi dài 0.2 s |
| Aura giảm (tiêu / hết giờ) | `<AuraLevel>` giảm | 2 nhịp LOW nhẹ tắt dần |
| Hit thường | hook `evHit_AttackPostProcess` | LOW (0.40 + 0.12×aura) + HIGH 80%, cooldown 60 ms |
| Spirit Blade (nhấn RT) | cò phải vượt 0.6 | "vút" HIGH 0.12 → 0.26 → 0.12 |
| Vào Iai stance | action `cIaiWpOff` | tách: HIGH 0.35 + LOW 0.18 |
| Foresight thành công | `IsMikiriSuccessed` | clang: HIGH 1.0 → LOW 0.7 |
| Iai Spirit counter | `IsIaiKijinMikiriSuccessed` | clang + LOW 1.2 0.2 s + đuôi |
| Foresight trúng / trúng đỏ | `IsMikiriHitSuccessed` / `IsRedMikiriHitSuccessed` | hit nặng / hit nặng + đuôi |
| Iai Slash trúng | `IsIaiSlashHitted` | HIGH 0.9 + LOW 0.8 |
| Iai Spirit Slash trúng / đỏ | `IsIaiKijinSlashHitted` / `_RedIaiKijinHitCount` | LOW 1.1 + đuôi / LOW 1.4 + đuôi 2 tầng |
| Helm Breaker | `_IsKabutowariStart`, `_KabutowariHitNum` | đà nhảy nhẹ, mỗi hit mạnh dần (0.5 + 0.1×n, tối đa 1.2) |
| Spirit Roundslash đỏ trúng | `_RedSlashRoundHitCount` | LOW 1.1 + HIGH 0.8 + đuôi |

## Chỉnh

`XboxLongSword.TUNING` (cường độ, nhịp, `trigger_*` cho cò) và `XboxLongSword.PATTERN` (mỗi bước `{ power, seconds, motor, delay }`).
`TUNING.gain` nhân toàn bộ. Mỗi xung ERM tối thiểu 0.08 s (`Constants.RUMBLE.ERM_MINIMUM_PULSE`).

## Chưa kiểm chứng trong game

- Thời điểm reset của các cờ `Is*Hitted` / `IsMikiri*`: module chỉ phản ứng ở cạnh false → true; nếu cờ giữ true suốt combo thì chỉ rung lần đầu.
- Tên action Iai stance `cIaiWpOff` lấy từ type `app.Wp03Action.cIaiWpOff` (legacy hook dùng được).
- `MHWilds_Haptic_Pack.lua` (bản cũ) cũng nằm ở `autorun/`: nếu cả hai cùng chạy, rung bị chồng.
