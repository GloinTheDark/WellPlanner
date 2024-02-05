local mod_gui = require("mod-gui")

require("wp_config")
require("wp_engine")

local GUI_BUTTON = "wp_button"


function string:starts_with(prefix)
  return string.find(self, prefix) == 1
end


local function item_selector_flow_2(frame, config_name, prototypes, player)
  local flow = frame.add(
    {
      type = "flow",
      name = config_name,
      direction = "horizontal",
      enabled = true,
    }
  )
  
  local stored_item_type = global.config[config_name]
  
  local inv = player.get_main_inventory()

  for item_name, item_prototype in pairs(prototypes) do
    local button_name = config_name .. "_" .. item_name
    local style = "compact_slot"
    if stored_item_type == item_name then
      style = "compact_slot_sized_button"
    end
    flow.add (
      {
        name = button_name,
        type = "sprite-button",
        sprite = "item/" .. item_name,
        style = style,
        tooltip = item_prototype.localised_name,
        number = inv.get_item_count(item_name),
      }
    )  
  end
    
  return flow
end

local function item_selector_flow(frame, config_name, type, player)
  local prototypes = get_items_of_entity_type(type)
  return item_selector_flow_2(frame, config_name, prototypes, player)
end

function gui_open_close_frame(player)
  init_config()

  local flow = player.gui.center

  local frame = flow.well_planner_config_frame

  -- if the frame exists destroy it and return
  if frame then
    frame.destroy()
    return
  end

  -- Now we can build the GUI.
  frame = flow.add{
    type = "frame",
    name = "well_planner_config_frame",
    caption = {"well-planner.config-frame-title"},
    direction = "vertical"
  }
  
  -- add a tabbed pane
  local tabs = frame.add{
    type = "tabbed-pane",
    direction = "horizontal"
  }

  -- add tab1
  tab1 = tabs.add {
    type = "tab",
    caption = {"well-planner.well_planner_tab1"},
  }

  local tab1contents = tabs.add{
    type = "flow",
    name = "tab1contents",
    direction = "vertical",
    enabled = true,
  }

  -- add tab2
  local tab2 = tabs.add {
    type = "tab",
    caption = {"well-planner.well_planner_tab2"},
  }

  local tab2contents = tabs.add{
    type = "flow",
    name = "tab2contents",
    direction = "vertical",
    enabled = true,
  }

  tab2contents.add(
    {
      type = "checkbox",
      name = "well_planner_use_modules",
      caption = {"well-planner.use_modules"},
      state = global.config.well_planner_use_modules == true,
      tooltip = {"well-planner.use_modules_tooltip"},
    }
  )

  item_selector_flow_2(tab2contents, "well_planner_module_type", get_module_prototypes(), player)

  tabs.add_tab(tab1, tab1contents)
  tabs.add_tab(tab2, tab2contents)

  tab1contents.add(
    {
      type = "label",
      caption = {"well-planner.pumpjacks"},
    }
  )

  item_selector_flow_2(tab1contents, "well_planner_pumpjack_type", get_pumpjack_prototypes(), player)

  tab1contents.add(
    {
      type = "label",
      caption = {"well-planner.pipes"},
    }
  )
  item_selector_flow(tab1contents, "well_planner_pipe_type", "pipe", player)

  tab1contents.add(
    {
      type = "checkbox",
      name = "well_planner_use_pipe_to_ground",
      caption = {"well-planner.use_pipe_to_ground"},
      state = global.config.well_planner_use_pipe_to_ground == true,
      tooltip = {"well-planner.use_pipe_to_ground_tooltip"},
    }
  )

  item_selector_flow(tab1contents, "well_planner_pipe_to_ground_type", "pipe-to-ground", player)

  tab1contents.add(
    {
      type = "checkbox",
      name = "well_planner_place_electric_poles",
      caption = {"well-planner.place_electric_poles"},
      state = global.config.well_planner_place_electric_poles == true,
      tooltip = {"well-planner.place_electric_poles_tooltip"},
    }
  )

  item_selector_flow(tab1contents, "well_planner_electric_pole_type", "electric-pole", player)

  frame.add(
    {
      type = "button",
      name = "well_planner_close_button",
      caption = {"well-planner.close_button"},
    }
  )

end

-- local function on_mod_item_opened(event)
--   local player = game.players[event.player_index]
--   gui_open_close_frame(player)
-- end

script.on_event(
  defines.events.on_gui_click,
  function(event)
    local name = event.element.name
    -- log("Well Planner on_gui_click")
    -- log(name)
    local player = game.players[event.player_index]
    
    if event.element.name == GUI_BUTTON then
      gui_open_close_frame(player)
    elseif name == "well_planner_close_button" then
      gui_open_close_frame(player)    
    elseif name:starts_with("well_planner_") and event.element.parent.type == "flow" then
      local config_key = event.element.parent.name
      if config_key and config_key:starts_with("well_planner_") then
        for _, sibling in pairs(event.element.parent.children) do
          sibling.style = "compact_slot"
        end
        event.element.style = "compact_slot_sized_button"
        local stored_item_type = name:sub(string.len(config_key) + 2)
        global.config[config_key] = stored_item_type
      end
    end
  end
)

script.on_event(
  defines.events.on_gui_checked_state_changed,
  function(event)
    if event.element.name:starts_with("well_planner_") then
      global.config[event.element.name] = event.element.state
    end
  end
)

-- script.on_event(
--   defines.events.on_mod_item_opened,
--   function(event)
--     if event.item.name == "well-planner" then
--       on_mod_item_opened(event)
--     end
--   end
-- )

local function local_on_selected_area(event)
  if event.item == "well-planner" then
    on_selected_area(event)
  end
end


script.on_event(
  defines.events.on_player_selected_area,
  local_on_selected_area
)

script.on_event(
  defines.events.on_player_alt_selected_area,
  local_on_selected_area
)

function get_wp_flow(player)
  local button_flow = mod_gui.get_button_flow(player)
  local flow = button_flow.wp_flow
  if not flow then
      flow = button_flow.add {
          type = "flow",
          name = "wp_flow",
          direction = "horizontal"
      }
  end
  return flow
end

function add_top_button(player)
  -- log("Well Planner add_top_button")

  if player.gui.top.wp_flow then player.gui.top.wp_flow.destroy() end -- remove the old flow

  local flow = get_wp_flow(player)

  if flow[GUI_BUTTON] then flow[GUI_BUTTON].destroy() end
  flow.add {
    type = "sprite-button",
    name = GUI_BUTTON,
    style = mod_gui.button_style,
    tooltip = {"well-planner.config-frame-title"},
    sprite = "well-planner",
  }
end

script.on_init(
  function()
    -- log("Well Planner on_init")
    for _, player in pairs(game.players) do
        add_top_button(player)
    end
  end
)

script.on_event(defines.events.on_player_created, function(event)
  -- log("Well Planner on_player_created")
  local player = game.players[event.player_index]
  add_top_button(player)
end)


script.on_configuration_changed(function(data)
  -- log("Well Planner on_configuration_changed")
  if not data or not data.mod_changes then
      return
  end
  for _, player in pairs(game.players) do
      add_top_button(player)
  end
end)
