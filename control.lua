-- Laufzeit: Knackpunkt 2 – Strom abhängig von der Zielstufe.
--
-- Maschinen haben einen festen Grundverbrauch (= erste Zielstufe). Je nach eingestelltem
-- Rezept bekommt jeder Verdichter einen zusätzlichen Verbrauchs-Effekt (local_effect),
-- z. B. +59 (= +5900 %) für Legendär: 5 MW × 60 = 300 MW.
-- Die Qualität der Maschine wirkt danach weiterhin als Faktor (energy_usage_quality_multiplier).
--
-- Es gibt kein Ereignis "Rezept geändert". Deshalb:
--  * sofort aktualisieren beim Bauen, beim Schliessen des Maschinenfensters und beim Einfügen von Einstellungen
--  * zusätzlich alle CHECK_INTERVAL Ticks eine Kontrolle nur über die registrierten Verdichter
--    (fängt Rezeptwechsel per Schaltung ab; die Verdichter sind wenige, die Kosten gering)

local config = require("config")

local CHECK_INTERVAL = 60

-- Rezeptname -> zusätzlicher Verbrauchs-Effekt
local consumption_by_recipe = {}
do
  local base_mw = config.tiers[1].power_mw
  for item_name in pairs(config.materials) do
    for _, tier in ipairs(config.tiers) do
      consumption_by_recipe[config.recipe_name(item_name, tier.quality)] = tier.power_mw / base_mw - 1
    end
  end
end

-- Namen der Verdichter-Maschinen, die es in diesem Spiel tatsächlich gibt
local function machine_names()
  local names = {}
  for name in pairs(config.machines) do
    if prototypes.entity[name] then names[#names + 1] = name end
  end
  return names
end

local function is_compressor(entity)
  return entity and entity.valid and config.machines[entity.name] ~= nil
end

-- Verbrauchs-Effekt passend zum aktuellen Rezept setzen
local function update(entity)
  local recipe = entity.get_recipe()
  local recipe_name = recipe and recipe.name or ""
  local data = storage.compressors[entity.unit_number]
  if data and data.recipe == recipe_name then return end

  local consumption = consumption_by_recipe[recipe_name] or 0
  if consumption ~= 0 then
    entity.local_effect = { consumption = consumption }
  else
    entity.local_effect = nil
  end
  storage.compressors[entity.unit_number] = { entity = entity, recipe = recipe_name }
end

local function register(entity)
  if is_compressor(entity) then update(entity) end
end

-- Noch nicht erfasste Verdichter auf einer Oberfläche registrieren
local function scan_surface(surface)
  local names = machine_names()
  if #names == 0 then return end
  for _, entity in pairs(surface.find_entities_filtered({ name = names })) do
    if not storage.compressors[entity.unit_number] then update(entity) end
  end
end

-- Alle vorhandenen Verdichter (neu) erfassen, z. B. nach Mod-Update oder Konfigurationsänderung
local function rescan()
  storage.compressors = {}
  for _, surface in pairs(game.surfaces) do
    scan_surface(surface)
  end
end

---------------------------------------------------------------------------
-- Freischaltung der Verdichtungsrezepte: Rohstoff-Forschung UND Zielstufen-Forschung.
-- Läuft nur bei Forschungs-Ereignissen, nicht pro Tick.

-- { Rezept, Rohstoff-Forschung, Zielstufen-Forschung }
local unlocks = {}
for item_name, material in pairs(config.materials) do
  if material.enabled then
    for _, tier in ipairs(config.tiers) do
      unlocks[#unlocks + 1] = {
        recipe = config.recipe_name(item_name, tier.quality),
        material_tech = config.material_technology(item_name),
        tier_tech = config.tier_technology[tier.quality],
      }
    end
  end
end

local function researched(force, tech_name)
  local tech = force.technologies[tech_name]
  return tech ~= nil and tech.researched
end

local function sync_recipes(force)
  for _, unlock in pairs(unlocks) do
    local recipe = force.recipes[unlock.recipe]
    if recipe then
      recipe.enabled = researched(force, unlock.material_tech) and researched(force, unlock.tier_tech)
    end
  end
end

local function sync_all_forces()
  for _, force in pairs(game.forces) do
    sync_recipes(force)
  end
end

local function on_research_changed(event)
  sync_recipes(event.research.force)
end
script.on_event(defines.events.on_research_finished, on_research_changed)
script.on_event(defines.events.on_research_reversed, on_research_changed)

-- Ereignisse, nach denen die Rezepte einer Fraktion neu gesetzt werden müssen
local function on_force_event(event)
  sync_recipes(event.force or event.destination)
end
script.on_event(defines.events.on_technology_effects_reset, on_force_event)
script.on_event(defines.events.on_force_reset, on_force_event)
script.on_event(defines.events.on_force_created, on_force_event)
script.on_event(defines.events.on_forces_merged, on_force_event)

script.on_init(function()
  rescan()
  sync_all_forces()
end)

script.on_configuration_changed(function()
  rescan()
  sync_all_forces()
end)

-- Bauen (Spieler, Roboter, Raumplattform, andere Mods)
local function on_built(event)
  register(event.entity or event.destination)
end

local built_events = {
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  defines.events.on_entity_cloned,
}
for _, event_id in pairs(built_events) do
  script.on_event(event_id, on_built)
end

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  register(event.destination)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  register(event.entity)
end)

-- Andere Mods bauen teils ohne Ereignis (z. B. Nomad: Startschiff per ghost.revive()).
-- Wenn ein Spieler eine Oberfläche betritt, dort nach noch nicht erfassten Verdichtern suchen.
script.on_event(defines.events.on_player_changed_surface, function(event)
  local player = game.get_player(event.player_index)
  if player and player.valid and player.surface then
    scan_surface(player.surface)
  end
end)

-- Regelmässige Kontrolle, nur über die Verdichter
script.on_nth_tick(CHECK_INTERVAL, function()
  for unit_number, data in pairs(storage.compressors) do
    if data.entity.valid then
      update(data.entity)
    else
      storage.compressors[unit_number] = nil
    end
  end
end)
