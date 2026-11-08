-- Verdichter und Hochdruckverdichter: Maschine, Item und Herstellungsrezept.
-- Werte (Kollision, Sound usw.) von Vanilla-Maschinen übernommen:
--   Verdichter          = Zentrifuge (Grundspiel, 3×3)
--   Hochdruckverdichter = Kryoanlage (Space Age, 5×5)
-- Grafik aus "CMA Graphics" von trentmkelly (CC0, siehe graphics/LICENSE-cma-graphics.txt):
--   Verdichter          = Industrial Press Mk2 (Hydraulikpresse, Blickrichtung Nord)
--   Hochdruckverdichter = Singularity Press Mk2
-- Beide Maschinen sind nicht drehbar, daher reicht eine Blickrichtung.

local config = require("config")

local GFX = "__quality-compressor__/graphics/"

-- Baut das Grafik-Set aus den CMA-Sprites (32 Bilder, 8 pro Zeile, 64 px/Feld → scale 0.5).
-- s: Grösse und Verschiebung je Ebene (Werte aus lib/sprites/<maschine>.lua von CMA Graphics).
-- Das Werkstück (tint) nimmt die Primärfarbe des Rezepts an (Farbe des Rohstoffs),
-- das Leuchten (emission) die Sekundärfarbe (Farbe der Zielqualität), siehe compression-recipes.lua.
local function make_graphics_set(name, s)
  local dir = GFX .. "entity/" .. name .. "/" .. name .. "-"
  local function sheet(layer, m, extra)
    local l = { filename = dir .. layer .. ".png", width = m.width, height = m.height, shift = m.shift,
                scale = 0.5, frame_count = 32, line_length = 8, animation_speed = 0.5 }
    for key, value in pairs(extra or {}) do l[key] = value end
    return l
  end
  local shadow = { filename = dir .. "shadow.png", width = s.shadow.width, height = s.shadow.height,
                   shift = s.shadow.shift, scale = 0.5, draw_as_shadow = true,
                   frame_count = 1, repeat_count = 32, animation_speed = 0.5 }
  return {
    animation = { layers = { sheet("animation", s.main), shadow } },
    working_visualisations = {
      { apply_recipe_tint = "primary", animation = sheet("tint", s.tint) },
      { fadeout = true, apply_recipe_tint = "secondary",
        animation = sheet("emission", s.main, { draw_as_glow = true, blend_mode = "additive" }) },
    },
    frozen_patch = { filename = dir .. "frozen.png", width = s.frozen.width, height = s.frozen.height,
                     shift = s.frozen.shift, scale = 0.5 },
    reset_animation_when_frozen = true,
  }
end

local function make_compressor(spec)
  local name = spec.name
  local machine = config.machines[name]
  local base = data.raw["assembling-machine"][spec.base]
  local base_item = data.raw.item[spec.base]

  local entity = table.deepcopy(base)
  entity.name = name
  -- Grundverbrauch und Höchstverbrauch aus der Konfiguration (das Tooltip zeigt sonst nur den Grundverbrauch)
  local top_mw = 0
  for _, tier in ipairs(config.tiers) do
    if tier.quality == machine.max_quality then top_mw = tier.power_mw end
  end
  entity.localised_description = { "entity-description." .. name,
    tostring(config.tiers[1].power_mw), tostring(top_mw) }
  entity.icon = GFX .. "icons/" .. name .. ".png"
  entity.icon_size = 64
  entity.icons = nil
  entity.minable = { mining_time = 0.2, result = name }
  entity.fast_replaceable_group = nil
  entity.next_upgrade = nil
  entity.crafting_categories = { machine.category }
  entity.crafting_speed = 1
  entity.effect_receiver = nil
  -- Keine Schranke für Oberflächen, damit die Maschine auch auf Raumplattformen baubar ist.
  entity.surface_conditions = nil
  -- Keine Rohranschlüsse (die Kryoanlage hat welche, die Verdichtung braucht keine Flüssigkeit).
  -- Ohne Flüssigkeitsboxen ist die Maschine auch nicht drehbar, passend zur Grafik.
  entity.fluid_boxes = nil
  entity.fluid_boxes_off_when_no_fluid_recipe = nil
  entity.graphics_set = make_graphics_set(name, spec.sprites)
  entity.graphics_set_flipped = nil  -- Die Sprites ragen oben über das Feld hinaus
  entity.drawing_box_vertical_extension = 1

  -- Strom: Grundverbrauch der ersten Zielstufe; der Zuschlag je Zielstufe kommt aus control.lua.
  entity.energy_usage = config.tiers[1].power_mw .. "MW"
  -- Höhere Qualität der Maschine senkt den Verbrauch und macht sie etwas schneller.
  entity.quality_affects_energy_usage = true
  entity.energy_usage_quality_multiplier = config.machine_power_factor
  entity.crafting_speed_quality_multiplier = config.machine_speed_factor

  -- Module: Qualität ja, Produktivität nein (sonst gäbe es Gratis-Material).
  entity.module_slots = machine.module_slots
  entity.allowed_effects = { "consumption", "speed", "pollution", "quality" }

  local item = {
    type = "item",
    name = name,
    icon = entity.icon,
    icon_size = 64,
    localised_description = entity.localised_description,
    subgroup = "production-machine",
    order = "z[quality-compression]-" .. name,
    inventory_move_sound = base_item.inventory_move_sound,
    pick_sound = base_item.pick_sound,
    drop_sound = base_item.drop_sound,
    place_result = name,
    stack_size = 20,
    -- Raketengewicht bewusst fest gesetzt (Nomad: Maschinen werden hochgeschossen).
    weight = spec.weight,
  }

  -- Freigeschaltet über die Forschung (prototypes/technologies.lua).
  local recipe = {
    type = "recipe",
    name = name,
    enabled = false,
    energy_required = 10,
    ingredients = spec.ingredients,
    results = { { type = "item", name = name, amount = 1 } },
  }

  data:extend({ entity, item, recipe })
end

-- Verdichter: aus Grundmaterialien, früh verfügbar.
make_compressor({
  name = "quality-compressor",
  base = "centrifuge",
  sprites = {   -- Industrial Press Mk2, Nord
    main   = { width = 190, height = 218, shift = { 0.0, -0.171875 } },
    shadow = { width = 292, height = 174, shift = { 0.796875, 0.765625 } },
    tint   = { width = 108, height = 120, shift = { 0.5625, 0.265625 } },
    frozen = { width = 190, height = 218, shift = { 0.0, -0.15625 } },
  },
  weight = 50 * kg,
  ingredients = {
    { type = "item", name = "steel-plate",        amount = 10 },
    { type = "item", name = "iron-gear-wheel",    amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 5  },
  },
})

-- Hochdruckverdichter: braucht Material von Aquilo (Lithiumplatten).
make_compressor({
  name = "high-pressure-quality-compressor",
  base = "cryogenic-plant",
  -- Grundfläche 5×5 wie die Kryoanlage (Wunsch des Users). Die Bodenplatte der CMA-Grafik ist
  -- nur 5×4 Felder (gemessen: 313 × 253 px bei 64 px/Feld). Deshalb sind alle Bilder (jedes
  -- Einzelbild) senkrecht um 364/288 ≈ 1,264 gestreckt (System.Drawing, bikubisch), Platte jetzt
  -- 313 × 320 px = 5×5, mittig. Verschiebungen y im gleichen Verhältnis (vorher −0,203/0,4375/−0,828).
  -- Originale: Desktop\Quality mod\original-hp-compressor-graphics (nicht Teil des Mods).
  sprites = {   -- Singularity Press Mk2, senkrecht gestreckt
    main   = { width = 318, height = 364, shift = { 0.0, -0.2567 } },
    shadow = { width = 384, height = 313, shift = { 0.53125, 0.5530 } },
    tint   = { width = 144, height = 159, shift = { 0.0, -1.0467 } },
    frozen = { width = 318, height = 361, shift = { 0.0, -0.2567 } },
  },
  weight = 100 * kg,
  ingredients = {
    { type = "item", name = "quality-compressor", amount = 1  },
    { type = "item", name = "lithium-plate",      amount = 20 },
    { type = "item", name = "tungsten-carbide",   amount = 20 },
    { type = "item", name = "processing-unit",    amount = 10 },
  },
})
