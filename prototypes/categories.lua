-- Rezeptkategorien und Untergruppe für die Verdichtungsrezepte.

local config = require("config")

-- Je Verdichter-Maschine eine eigene Kategorie
for _, machine in pairs(config.machines) do
  data:extend({ { type = "recipe-category", name = machine.category } })
end

-- Kategorie für Plastik in der Biokammer
data:extend({
  { type = "recipe-category", name = config.biochamber.category },
  {
    type = "item-subgroup",
    name = "quality-compression",
    group = "intermediate-products",
    order = "z[quality-compression]",
  },
})

-- Vorgesehene Ausnahme von "Vanilla nicht ändern" (siehe CLAUDE.md):
-- Die Biokammer bekommt zusätzlich die Plastik-Verdichtung, sonst bleibt sie unverändert.
local biochamber = data.raw["assembling-machine"]["biochamber"]
table.insert(biochamber.crafting_categories, config.biochamber.category)
