local Language = require("core.language")

local Menu = {}

local untranslated = imgui
Menu.untranslated = untranslated

-- Same API as the global imgui, with labels and combo options translated.
Menu.imgui = setmetatable({
    text = function(label)
        return untranslated.text(Language.translate_label(label))
    end,
    button = function(label, ...)
        return untranslated.button(Language.translate_label(label), ...)
    end,
    checkbox = function(label, ...)
        return untranslated.checkbox(Language.translate_label(label), ...)
    end,
    slider_float = function(label, ...)
        return untranslated.slider_float(Language.translate_label(label), ...)
    end,
    combo = function(label, selected_index, options)
        return untranslated.combo(Language.translate_label(label), selected_index, Language.translate_list(options))
    end,
    tree_node = function(label)
        return untranslated.tree_node(Language.translate_label(label))
    end,
}, { __index = untranslated })

function Menu.slider(label, owner, key, minimum, maximum)
    local changed, value = Menu.imgui.slider_float(label, owner[key], minimum, maximum)
    if changed then
        owner[key] = value
    end
    return changed
end

-- Combo over a list of values; returns changed, selected value.
function Menu.combo_value(label, current_value, values, labels, fallback_index)
    local selected_index = fallback_index or 1
    for index, value in ipairs(values) do
        if value == current_value then
            selected_index = index
        end
    end
    local changed, new_index = Menu.imgui.combo(label, selected_index, labels or values)
    return changed, values[new_index]
end

return Menu
