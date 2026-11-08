-- Forschungen: Grundtechnologie, Zielstufen, Hochdruckverdichter und je eine pro Rohstoff.
--
-- Die Verdichtungsrezepte brauchen zwei Forschungen (Rohstoff UND Zielstufe). Factorio kann
-- ein Rezept nur über eine Forschung freischalten, darum macht das control.lua. Hier stehen
-- dafür "nothing"-Effekte, damit der Forschungsbaum trotzdem anzeigt, was freigeschaltet wird.

local config = require("config")

local function unit(spec, packs)
  local ingredients = {}
  for _, pack in ipairs(packs) do
    ingredients[#ingredients + 1] = { pack, 1 }
  end
  return { count = spec.count, time = spec.time, ingredients = ingredients }
end

local function item_icons(item)
  if item.icons then return table.deepcopy(item.icons) end
  return { { icon = item.icon, icon_size = item.icon_size or 64 } }
end

local function tier_effect(quality)
  return {
    type = "nothing",
    icons = { { icon = data.raw.quality[quality].icon, icon_size = data.raw.quality[quality].icon_size or 64 } },
    effect_description = { "quality-compression-effect.tier", { "quality-name." .. quality } },
  }
end

local function material_effect(item_name)
  return {
    type = "nothing",
    icons = item_icons(data.raw.item[item_name]),
    effect_description = { "quality-compression-effect.material", { "item-name." .. item_name } },
  }
end

local techs = config.technologies
-- Grosse Maschinen-Icons (512 px) aus CMA Graphics für den Forschungsbaum
local compressor_icons = { { icon = "__quality-compressor__/graphics/icons/quality-compressor-big.png", icon_size = 512 } }
local high_pressure_icons = { { icon = "__quality-compressor__/graphics/icons/high-pressure-quality-compressor-big.png", icon_size = 512 } }

local prototypes = {
  {
    type = "technology",
    name = techs.base.name,
    icons = compressor_icons,
    effects = {
      { type = "unlock-recipe", recipe = "quality-compressor" },
      tier_effect("uncommon"),
      material_effect("iron-ore"),
    },
    prerequisites = techs.base.prerequisites,
    unit = unit(techs.base, techs.base.packs),
    order = "z[quality-compression]-a",
  },
  {
    type = "technology",
    name = techs.rare.name,
    icons = { { icon = data.raw.quality["rare"].icon, icon_size = data.raw.quality["rare"].icon_size or 64 } },
    effects = { tier_effect("rare") },
    prerequisites = techs.rare.prerequisites,
    unit = unit(techs.rare, techs.rare.packs),
    order = "z[quality-compression]-b",
  },
  {
    type = "technology",
    name = techs.high_pressure.name,
    icons = high_pressure_icons,
    effects = {
      { type = "unlock-recipe", recipe = "high-pressure-quality-compressor" },
      tier_effect("epic"),
    },
    prerequisites = techs.high_pressure.prerequisites,
    unit = unit(techs.high_pressure, techs.high_pressure.packs),
    order = "z[quality-compression]-c",
  },
  {
    type = "technology",
    name = techs.legendary.name,
    icons = { { icon = data.raw.quality["legendary"].icon, icon_size = data.raw.quality["legendary"].icon_size or 64 } },
    effects = { tier_effect("legendary") },
    prerequisites = techs.legendary.prerequisites,
    unit = unit(techs.legendary, techs.legendary.packs),
    order = "z[quality-compression]-d",
  },
}

-- Je eine Forschung pro Rohstoff (ausser Eisenerz, das kommt mit der Grundtechnologie)
for item_name, material in pairs(config.materials) do
  local tech_name = config.material_technology(item_name)
  if material.enabled and tech_name ~= techs.base.name then
    local packs = table.deepcopy(techs.base.packs)
    local prerequisites = { techs.base.name }
    if material.science_pack then
      packs[#packs + 1] = material.science_pack
      prerequisites[#prerequisites + 1] = material.science_pack
    end
    for _, extra in pairs(material.prerequisites or {}) do
      prerequisites[#prerequisites + 1] = extra
    end

    prototypes[#prototypes + 1] = {
      type = "technology",
      name = tech_name,
      localised_name = { "technology-name.quality-compression-material", { "item-name." .. item_name } },
      localised_description = { "technology-description.quality-compression-material", { "item-name." .. item_name } },
      icons = item_icons(data.raw.item[item_name]),
      effects = { material_effect(item_name) },
      prerequisites = prerequisites,
      unit = unit(techs.material, packs),
      order = "z[quality-compression]-m-" .. material.planet .. "-" .. item_name,
    }
  end
end

data:extend(prototypes)
