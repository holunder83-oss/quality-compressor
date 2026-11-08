-- Zentrale Konfiguration: Alle Zahlenwerte des Mods stehen hier.
-- Es sind Startwerte zum Testen, sie dürfen frei angepasst werden.

local config = {}

-- Zielstufen der Verdichtung.
-- ratio:    Wie viele Items der Vorstufe ergeben ein Item dieser Stufe.
-- power_mw: Grundstromverbrauch in MW (Maschine normaler Qualität).
-- time:     Dauer eines Vorgangs in Sekunden (bei Arbeitsgeschwindigkeit 1).
config.tiers = {
  { quality = "uncommon",  ratio = 8,  power_mw = 5,   time = 10  },
  { quality = "rare",      ratio = 8,  power_mw = 20,  time = 30  },
  { quality = "epic",      ratio = 10, power_mw = 80,  time = 60  },
  { quality = "legendary", ratio = 12, power_mw = 300, time = 120 },
}

-- Einstellung "Stromverbrauch" (Startup, 1 bis 100 %, Standard 100): Anteil auf alle Stufen. Wirkt ueberall
-- gleich (Maschine, Tooltips, Zuschlag in control.lua), weil alle power_mw von hier lesen.
-- settings gibt es in der Daten- und der Kontrollphase, in der Einstellungsphase nicht.
do
  local s = settings and settings.startup and settings.startup["quality-compressor-power-percent"]
  local factor = s and s.value / 100 or 1
  if factor ~= 1 then
    for _, tier in pairs(config.tiers) do
      tier.power_mw = math.floor(tier.power_mw * factor * 1000 + 0.5) / 1000
    end
  end
end

-- Einstellung "Verhältnis" je Zielstufe (Startup): ersetzt tier.ratio.
do
  for _, tier in pairs(config.tiers) do
    local s = settings and settings.startup and settings.startup["quality-compressor-ratio-" .. tier.quality]
    if s then tier.ratio = s.value end
  end
end

-- Stromfaktor nach Qualität der Maschine (1.0 = 100 %).
config.machine_power_factor = {
  normal    = 1.00,
  uncommon  = 0.85,
  rare      = 0.70,
  epic      = 0.50,
  legendary = 0.30,
}

-- Geschwindigkeitsfaktor nach Qualität der Maschine (1.0 = 100 %).
-- Etwas schwächer als Vanilla (bis 2.5×): Qualität soll vor allem Strom sparen.
config.machine_speed_factor = {
  normal    = 1.0,
  uncommon  = 1.2,
  rare      = 1.4,
  epic      = 1.6,
  legendary = 2.0,
}

-- Verdichter-Maschinen.
-- max_quality:  Höchste erreichbare Zielstufe (auch mit Qualitätsmodulen).
-- category:     Eigene Rezeptkategorie der Maschine.
-- module_slots: Anzahl Modulplätze.
-- Ein Rezept, das mehrere Maschinen können, ist durch die kleinste Grenze gedeckelt
-- (z. B. "Ungewöhnlich" im Hochdruckverdichter: Modulwürfe höchstens bis "Selten").
config.machines = {
  ["quality-compressor"]               = { max_quality = "rare",      category = "quality-compression",               module_slots = 2 },
  ["high-pressure-quality-compressor"] = { max_quality = "legendary", category = "quality-compression-high-pressure", module_slots = 4 },
}

-- Rohstoffe, die verdichtet werden können.
-- planet:           Heimatplanet, bestimmt die Freischaltung.
-- machine:          "compressor" (Verdichter/Hochdruckverdichter) oder "biochamber".
-- science_pack:     Wissenschaftspaket des Planeten: Voraussetzung und Kosten der Rohstoff-Forschung.
--                   nil = nur Nauvis-Wissenschaft.
-- prerequisites:    Zusätzliche Voraussetzungen der Rohstoff-Forschung (optional).
-- ratio_multiplier: Faktor auf das Verhältnis der Zielstufe (Standard 1).
-- enabled:          Schalter, um einen Rohstoff auszunehmen (false = keine Rezepte).
config.materials = {
  -- Nauvis
  ["iron-ore"]    = { planet = "nauvis", machine = "compressor", science_pack = nil, enabled = true },
  ["copper-ore"]  = { planet = "nauvis", machine = "compressor", science_pack = nil, enabled = true },
  ["stone"]       = { planet = "nauvis", machine = "compressor", science_pack = nil, enabled = true },
  ["coal"]        = { planet = "nauvis", machine = "compressor", science_pack = nil, enabled = true },
  ["uranium-ore"] = { planet = "nauvis", machine = "compressor", science_pack = nil, prerequisites = { "uranium-mining" }, enabled = true },
  -- Vulcanus
  ["tungsten-ore"] = { planet = "vulcanus", machine = "compressor", science_pack = "metallurgic-science-pack", enabled = true },
  ["calcite"]      = { planet = "vulcanus", machine = "compressor", science_pack = "metallurgic-science-pack", enabled = true },
  ["sulfur"]       = { planet = "vulcanus", machine = "compressor", science_pack = "metallurgic-science-pack", enabled = true },
  -- Fulgora (Schrott teurer, weil Recyceln sonst alles in hoher Qualität liefert)
  -- Ausnahme von "nur Rohstoffe": Holmiumplatte statt Holmiumerz, denn das Erz wird nur zu
  -- Holmiumlösung (Flüssigkeit, ohne Qualität) verarbeitet – verdichtetes Erz wäre nutzlos.
  ["holmium-plate"] = { planet = "fulgora", machine = "compressor", science_pack = "electromagnetic-science-pack", enabled = true },
  ["scrap"]       = { planet = "fulgora", machine = "compressor", science_pack = "electromagnetic-science-pack", ratio_multiplier = 2, enabled = true },
  -- Gleba (Plastik nur in der Biokammer)
  ["plastic-bar"] = { planet = "gleba", machine = "biochamber", science_pack = "agricultural-science-pack", enabled = true },
  -- Aquilo
  ["ice"] = { planet = "aquilo", machine = "compressor", science_pack = "cryogenic-science-pack", enabled = true },
}

-- Reihenfolge der Planeten in den Mod-Einstellungen
config.planet_order = { nauvis = "a", vulcanus = "b", fulgora = "c", gleba = "d", aquilo = "e" }

-- Einstellung "Verhältnis-Faktor" je Rohstoff (Startup): ersetzt ratio_multiplier.
-- Der Wert oben (z. B. Schrott 2) ist der Standardwert der Einstellung (settings.lua).
do
  for item_name, material in pairs(config.materials) do
    local s = settings and settings.startup and settings.startup["quality-compressor-ratio-factor-" .. item_name]
    if s then material.ratio_multiplier = s.value end
  end
end

-- Menge der Zutat eines Verdichtungsrezepts: Verhältnis der Stufe × Faktor des Rohstoffs,
-- aufgerundet, mindestens 2 (sonst wäre es keine Verdichtung), höchstens 65535 (Grenze der Rezeptmenge).
function config.ingredient_amount(tier, material)
  local amount = math.ceil(tier.ratio * (material.ratio_multiplier or 1) - 1e-9)
  return math.min(math.max(amount, 2), 65535)
end

-- Farbe des Werkstücks in der Maschine (Rezept-Primärfarbe), je Rohstoff.
-- Das Leuchten der Maschine nimmt die Farbe der Zielqualität an.
-- Fehlt ein Eintrag, bleibt das Werkstück grau.
config.material_colors = {
  ["iron-ore"]      = { r = 0.45, g = 0.55, b = 0.65 },
  ["copper-ore"]    = { r = 0.85, g = 0.45, b = 0.25 },
  ["stone"]         = { r = 0.70, g = 0.62, b = 0.48 },
  ["coal"]          = { r = 0.20, g = 0.20, b = 0.20 },
  ["uranium-ore"]   = { r = 0.40, g = 0.90, b = 0.25 },
  ["tungsten-ore"]  = { r = 0.35, g = 0.30, b = 0.45 },
  ["calcite"]       = { r = 0.95, g = 0.92, b = 0.85 },
  ["sulfur"]        = { r = 0.95, g = 0.90, b = 0.20 },
  ["holmium-plate"] = { r = 0.90, g = 0.45, b = 0.65 },
  ["scrap"]         = { r = 0.55, g = 0.45, b = 0.35 },
  ["plastic-bar"]   = { r = 0.95, g = 0.95, b = 0.95 },
  ["ice"]           = { r = 0.70, g = 0.90, b = 1.00 },
}

-- Forschungen.
-- Ein Verdichtungsrezept ist freigeschaltet, wenn die Forschung des Rohstoffs UND die
-- Forschung der Zielstufe erforscht sind (control.lua schaltet die Rezepte frei).
-- Die Zielstufen hängen von den Vanilla-Forschungen ab, die die Qualität freischalten,
-- sonst käme beim Verdichten nur "normal" heraus.
local nauvis_packs = { "automation-science-pack", "logistic-science-pack", "chemical-science-pack" }
config.technologies = {
  -- Grundtechnologie: Verdichter, Zielstufe Ungewöhnlich, Eisenerz
  base = {
    name = "quality-compression",
    prerequisites = { "quality-module", "chemical-science-pack" },
    count = 300, time = 30,
    packs = nauvis_packs,
  },
  -- Zielstufen (uncommon = Grundtechnologie, epic = Hochdruckverdichter)
  rare = {
    name = "quality-compression-tier-rare",
    prerequisites = { "quality-compression", "production-science-pack" },
    count = 500, time = 30,
    packs = { "automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack" },
  },
  high_pressure = {
    name = "high-pressure-quality-compressor",
    prerequisites = { "quality-compression-tier-rare", "epic-quality", "tungsten-carbide", "cryogenic-science-pack" },
    count = 1000, time = 60,
    packs = { "automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack",
              "utility-science-pack", "space-science-pack", "cryogenic-science-pack" },
  },
  legendary = {
    name = "quality-compression-tier-legendary",
    prerequisites = { "high-pressure-quality-compressor", "legendary-quality" },
    count = 2000, time = 60,
    packs = { "automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack",
              "utility-science-pack", "space-science-pack", "cryogenic-science-pack" },
  },
  -- Forschung pro Rohstoff: Kosten der Grundtechnologie + Wissenschaftspaket des Planeten
  material = { count = 200, time = 30 },
}

-- Welche Forschung schaltet welche Zielstufe frei
config.tier_technology = {
  uncommon  = "quality-compression",
  rare      = "quality-compression-tier-rare",
  epic      = "high-pressure-quality-compressor",
  legendary = "quality-compression-tier-legendary",
}

-- Name der Forschung eines Rohstoffs (Eisenerz kommt mit der Grundtechnologie)
function config.material_technology(item_name)
  if item_name == "iron-ore" then return config.technologies.base.name end
  return "quality-compression-material-" .. item_name
end

-- Name eines Verdichtungsrezepts
function config.recipe_name(item_name, quality)
  return "quality-compression-" .. item_name .. "-" .. quality
end

-- Biokammer: läuft mit Nährstoffen statt Strom. Die Kosten steigen über die
-- Rezeptzeit (längere Zeit = mehr verbrauchte Nährstoffe).
-- Rezeptzeit = Zeit der ersten Zielstufe × Faktor der Zielstufe.
config.biochamber = {
  category    = "quality-compression-organic",
  max_quality = "legendary",
  time_factor = {
    uncommon  = 1,
    rare      = 4,
    epic      = 16,
    legendary = 60,
  },
}

return config
