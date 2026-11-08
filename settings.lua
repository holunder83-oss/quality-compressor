-- Einstellungen des Mods.
-- config.lua liest in der Einstellungsphase noch keine settings, liefert hier also die Standardwerte.
local config = require("config")

local settings_list = {
  {
    -- Stromverbrauch beider Verdichter in Prozent (config.lua). 100 % = 5 / 20 / 80 / 300 MW.
    -- Nur nach unten: je kleiner der Wert, desto weniger Strom.
    type = "int-setting",
    name = "quality-compressor-power-percent",
    setting_type = "startup",
    default_value = 100,
    minimum_value = 1,
    maximum_value = 100,
    order = "a",
  },
}

-- Verhältnis je Zielstufe (z. B. 12 = 12 Items der Vorstufe ergeben 1 Item)
for index, tier in ipairs(config.tiers) do
  settings_list[#settings_list + 1] = {
    type = "int-setting",
    name = "quality-compressor-ratio-" .. tier.quality,
    localised_name = { "mod-setting-name.quality-compressor-ratio", { "quality-name." .. tier.quality } },
    localised_description = { "mod-setting-description.quality-compressor-ratio", tostring(tier.ratio) },
    setting_type = "startup",
    default_value = tier.ratio,
    minimum_value = 2,
    maximum_value = 1000,
    order = "b-" .. index,
  }
end

-- Faktor auf das Verhältnis je Rohstoff (Schrott Standard 2)
for item_name, material in pairs(config.materials) do
  local default = material.ratio_multiplier or 1
  settings_list[#settings_list + 1] = {
    type = "double-setting",
    name = "quality-compressor-ratio-factor-" .. item_name,
    localised_name = { "mod-setting-name.quality-compressor-ratio-factor", { "item-name." .. item_name } },
    localised_description = { "mod-setting-description.quality-compressor-ratio-factor", tostring(default) },
    setting_type = "startup",
    default_value = default,
    minimum_value = 0.1,
    maximum_value = 100,
    order = "c-" .. (config.planet_order[material.planet] or "z") .. "-" .. item_name,
  }
end

data:extend(settings_list)
