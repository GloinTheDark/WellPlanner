local pumpable_resource_categories = require("pumpable")




local function get_first_key_in_map(map)
  for k,v in pairs(map) do
    return k
  end
end

local function get_prototype_from_config(prototypes, config_name)
  local proto_name = global.config[config_name]
  if proto_name == nil then
    proto_name = get_first_key_in_map(prototypes)
    global.config[config_name] = proto_name
  end
  local proto = prototypes[proto_name]
  if proto == nil then
    proto_name = get_first_key_in_map(prototypes)
    global.config[config_name] = proto_name
    proto = prototypes[proto_name]
  end
  return proto
end

-- returns a map of items that place entities of type
function get_items_of_entity_type(type)
  out = {}
  for name, item in pairs(game.item_prototypes) do
    local entity = item.place_result
    if entity and entity.type == type then
      if item.name == item.place_result.name then
        if entity.has_flag("player-creation") then
          out[name] = item
        end
      end
    end  
  end
  return out
end



function get_pumpjack_prototypes()
  local items = get_items_of_entity_type("mining-drill")
  local out = {}
  for name, item in pairs(items) do
    local entity = item.place_result
    for cat, _ in pairs(pumpable_resource_categories) do
      if entity.resource_categories[cat] then
        out[name] = item
      end
    end
  end
  return out
end



function get_pumpjack()
  local prototypes = get_pumpjack_prototypes()
  local config_name = "well_planner_pumpjack_type"
  return get_prototype_from_config(prototypes, config_name)
end

function get_pipe()
  local prototypes = get_items_of_entity_type("pipe")
  local config_name = "well_planner_pipe_type"
  return get_prototype_from_config(prototypes, config_name)
end

function get_pipe_to_ground()
  local prototypes = get_items_of_entity_type("pipe-to-ground")
  local config_name = "well_planner_pipe_to_ground_type"
  return get_prototype_from_config(prototypes, config_name)
end

function get_electric_pole()
  local prototypes = get_items_of_entity_type("electric-pole")
  local config_name = "well_planner_electric_pole_type"
  return get_prototype_from_config(prototypes, config_name)
end

-- returns a map of names of module ptorotypes
function get_module_prototypes()
  out = {}
  for name, item in pairs(game.item_prototypes) do
    if item.type == "module" then
      out[name] = item
    end
  end
  return out
end


function get_module()
  local prototypes = get_module_prototypes()
  local config_name = "well_planner_module_type"
  return get_prototype_from_config(prototypes, config_name)
end



function init_config()
  if not global.config then
    global.config = {
    well_planner_use_pipe_to_ground = true,
    well_planner_place_electric_poles = true,      
    well_planner_use_modules = false,      
    }
  end
  get_pumpjack()
  get_pipe()
  get_pipe_to_ground()
  get_electric_pole()
  get_module()
end
  