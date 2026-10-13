-- VCM - Voice Coil Motor (Voice Coil Actuator)
-- Popular controllers using it: Dualsense (PS5 Controller), Steam Controller
-- this calls haptic feedback
local VCM = {} 

function VCM.vibrate(intensity, duration)
    -- intensity: 0.0 to 1.0
    -- duration: in milliseconds
    -- Implement the hardware-specific vibration logic here
end

return VCM