local VERSION = "0.1"
local LANGUAGE = "en"

-- Weapons Catalog
local KIND_BY_TYPE = {
    { pattern = "Wp00", kind = "gs" },
    { pattern = "Wp01", kind = "sns" },
    { pattern = "Wp02", kind = "db" },
    { pattern = "Wp03", kind = "ls" },
    { pattern = "Wp04", kind = "hammer" },
    { pattern = "Wp05", kind = "hh" },
    { pattern = "Wp06", kind = "lance" },
    { pattern = "Wp07", kind = "gl" },
    { pattern = "Wp08", kind = "sa" },
    { pattern = "Wp09", kind = "cb" },
    { pattern = "Wp10", kind = "ig" },
    { pattern = "Wp11", kind = "bow" },
    { pattern = "Wp12", kind = "hbg" },
    { pattern = "Wp13", kind = "lbg" }, 
}
local KIND_LABEL = { 
    gs = "Great Sword", 
    sns = "Sword & Shield", 
    db = "Dual Blades", 
    ls = "Long Sword", 
    hammer = "Hammer", 
    hh = "Hunting Horn", 
    lance = "Lance", 
    gl = "Gunlance", 
    sa = "Switch Axe", 
    cb = "Charge Blade",
    ig = "Insect Glaive",
    bow = "Bow", 
    hbg = "Heavy Bowgun", 
    lbg = "Light Bowgun", 
}

log.info("[Haptic Pack] loading v" .. VERSION)