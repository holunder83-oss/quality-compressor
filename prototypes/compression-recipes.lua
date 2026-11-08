-- Verdichtungsrezepte: je Rohstoff und Zielstufe ein Rezept.
--
-- Knackpunkt 1 (Ausgabe höher als die Zutaten) wird ohne Scripting gelöst:
-- Factorio 2.1 kennt quality_min/quality_max/quality_change auf Zutaten und Produkten.
--  * Zutat: Qualität fest auf die Vorstufe (quality_min = quality_max).
--    Dadurch ist die Rezeptqualität nicht wählbar und immer "normal".
--  * Produkt: quality_change hebt das Ergebnis von "normal" auf die Zielstufe.
--    quality_max begrenzt Würfe von Qualitätsmodulen auf die Grenze der Maschine.
-- Im Spiel getestet (2.1.22): ohne Module 100 % Zielstufe, mit Qualitätsmodulen
-- teils eine Stufe höher, nie über quality_max.
-- Achtung: quality_change wirkt nur, wenn die Fraktion die Zielqualität per Forschung
-- freigeschaltet hat (quality-module / epic-quality / legendary-quality). Sonst kommt
-- "normal" heraus. Die Freischalt-Forschungen müssen daher davon abhängen.

local config = require("config")

-- Qualität -> Position in der Kette (normal = 0, uncommon = 1, ...)
local quality_index = { normal = 0 }
for index, tier in ipairs(config.tiers) do
  quality_index[tier.quality] = index
end

-- Kategorien und Obergrenze für eine Zielstufe im Verdichter/Hochdruckverdichter:
-- alle Maschinen, deren Grenze die Zielstufe erreicht; gedeckelt durch die kleinste Grenze.
local function compressor_categories(tier_index)
  local categories, cap = {}, nil
  for _, machine in pairs(config.machines) do
    local max_index = quality_index[machine.max_quality]
    if max_index >= tier_index then
      categories[#categories + 1] = machine.category
      if not cap or max_index < quality_index[cap] then cap = machine.max_quality end
    end
  end
  table.sort(categories)
  return categories, cap
end

local function item_icons(item)
  if item.icons then return table.deepcopy(item.icons) end
  return { { icon = item.icon, icon_size = item.icon_size } }
end

for item_name, material in pairs(config.materials) do
  if material.enabled then
    local item = data.raw.item[item_name]
    if not item then
      error("quality-compressor: Rohstoff '" .. item_name .. "' aus config.materials existiert nicht als Item.")
    end
    local previous_quality = "normal"

    for index, tier in ipairs(config.tiers) do
      local amount = config.ingredient_amount(tier, material)
      local categories, cap, time, description
      if material.machine == "biochamber" then
        categories = { config.biochamber.category }
        cap = config.biochamber.max_quality
        time = config.tiers[1].time * config.biochamber.time_factor[tier.quality]
        description = { "recipe-description.quality-compression-organic",
          tostring(amount), tostring(time), { "quality-name." .. cap } }
      else
        categories, cap = compressor_categories(index)
        time = tier.time
        -- Echter Strombedarf: Das Maschinen-Tooltip zeigt nur den Grundverbrauch,
        -- der Zuschlag je Zielstufe kommt erst zur Laufzeit (control.lua).
        description = { "recipe-description.quality-compression",
          tostring(tier.power_mw), tostring(amount), tostring(time), { "quality-name." .. cap } }
      end

      local icons = item_icons(item)
      icons[#icons + 1] = { icon = data.raw.quality[tier.quality].icon, scale = 0.25, shift = { -8, 8 } }

      data:extend({
        {
          type = "recipe",
          name = config.recipe_name(item_name, tier.quality),
          localised_name = { "recipe-name.quality-compression", { "item-name." .. item_name }, { "quality-name." .. tier.quality } },
          localised_description = description,
          icons = icons,
          categories = categories,
          subgroup = "quality-compression",
          order = material.planet .. "-" .. item_name .. "-" .. index,
          -- Freischaltung über control.lua (Rohstoff-Forschung UND Zielstufen-Forschung)
          enabled = false,
          energy_required = time,
          ingredients = {
            {
              type = "item", name = item_name,
              amount = amount,
              quality_min = previous_quality, quality_max = previous_quality,
            },
          },
          results = {
            { type = "item", name = item_name, amount = 1, quality_change = index, quality_max = cap },
          },
          main_product = item_name,
          -- Grafik: Werkstück in Rohstofffarbe, Leuchten in Farbe der Zielqualität
          crafting_machine_tint = {
            primary = config.material_colors[item_name] or { r = 0.6, g = 0.6, b = 0.6 },
            secondary = data.raw.quality[tier.quality].color,
          },
          -- Keine Produktivität. allow_productivity = false allein reicht nicht:
          -- Der +50 % Grundbonus der Biokammer wirkt trotzdem (getestet), daher zusätzlich maximum_productivity = 0.
          allow_productivity = false,
          maximum_productivity = 0,
          allow_decomposition = false,
          hide_from_player_crafting = true,
          -- Kein automatisches Recycling-Rezept, sonst wäre Verdichten umkehrbar.
          auto_recycle = false,
        },
      })

      previous_quality = tier.quality
    end
  end
end
