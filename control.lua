-- require("mod-gui")
local PriorityQueue = require("priority_queue")
local pumpable_resource_categories = require("pumpable")

function string:starts_with(prefix)
  return string.find(self, prefix) == 1
end

-- returns a string representation of a position
local function key(position)
    return math.floor(position.x) .. "," .. math.floor(position.y)
end

function table.clone(org)
  local copy = {}
  for k, v in pairs(org) do
      copy[k] = v
  end
  return copy
end

local pump_neighbors = {
  {x = 1, y = -2, direction = defines.direction.north},
  {x = 2, y = -1, direction = defines.direction.east},
  {x = -1, y = 2, direction = defines.direction.south},
  {x = -2, y = 1, direction = defines.direction.west},  
}

local function makeNodesFromPatch(patch)
  local nodes = {}
  for i, n in ipairs(pump_neighbors) do
    local node = {
      patch = patch,
      position = {
        x = patch.position.x + n.x,
        y = patch.position.y + n.y,
      },
      direction = n.direction,
    }
    node.key = key(node.position)
    nodes[i] = node
  end

  return nodes
end

local function dist_squared(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  return dx * dx + dy * dy
end

local function heuristic_score_crow(goals, node)
  local score = math.huge
  for _, goal in ipairs(goals) do
    score = math.min(score, dist_squared(goal, node))
  end
  return math.sqrt(score)
end

local function heuristic_score_taxicab(goals, node)
  local score = math.huge
  for _, goal in ipairs(goals) do
    score = math.min(score, math.abs(goal.position.x - node.position.x) + math.abs(goal.position.y - node.position.y))
  end
  return score
end

local pipe_neighbors = {
  {x = 0, y = -1},
  {x = 1, y = 0},
  {x = 0, y = 1},
  {x = -1, y = 0},  
}

local function make_neighbors(parent)
  local nodes = {}
  for i, n in ipairs(pipe_neighbors) do
    local node = {
      parent = parent,
      position = {
        x = parent.position.x + n.x,
        y = parent.position.y + n.y,
      },
      g_score = parent.g_score + 1,
    }
    node.key = key(node.position)
    nodes[i] = node
  end
  return nodes
end

local function point_in_box(box, point)
  return point.x >= box.left_top.x and point.x <= box.right_bottom.x and point.y >= box.left_top.y and point.y <= box.right_bottom.y
end

local function a_star(start_nodes, goal_nodes, blockers_map, work_zone, heuristic_score)
  local search_queue = PriorityQueue:new()
  local count = 0

  local all_nodes_map = start_nodes

  for _, node in ipairs(start_nodes) do
    if not blockers_map[node.key] then
      node.g_score = 0
      node.f_score = 0 + heuristic_score(goal_nodes, node)
      all_nodes_map[node.key] = node
      search_queue:put(node, node.f_score * 1000 + count)
      count = count + 1
    end
  end

  while not search_queue:empty() do
    local best = search_queue:pop()

    for _, node in ipairs(make_neighbors(best)) do
      if point_in_box(work_zone, node.position) then
        if not blockers_map[node.key] then
          local o = all_nodes_map[node.key]
          if o == nil or node.g_score < o.g_score then
            local h = heuristic_score(goal_nodes, node)
            if h == 0 then
              for _, g in ipairs(goal_nodes) do
                if g.key == node.key then
                  g.parent = node.parent
                  return g
                end
              end 
              return node
            end
            node.f_score = node.g_score + h
            all_nodes_map[node.key] = node
            search_queue:put(node, node.f_score * 1000 + count)
            count = count + 1
          end
        end
      end
    end
  end
  -- no path found
  return nil
end

local function min_pos(a, b)
  return {
    x = math.min(a.x, b.x),
    y = math.min(a.y, b.y)
  }
end

local function max_pos(a, b)
  return {
    x = math.max(a.x, b.x),
    y = math.max(a.y, b.y)
  }
end

local function log_object(o)
  log("\r" .. serpent.block(o))
end

local function add_point(work_zone, point)
  if work_zone.left_top == nil then
    work_zone.left_top = table.clone(point)
  else
    work_zone.left_top = min_pos(point, work_zone.left_top)
  end
  if work_zone.right_bottom == nil then
    work_zone.right_bottom = table.clone(point)
  else
    work_zone.right_bottom = max_pos(point, work_zone.right_bottom)
  end
end

local function expand_box(box, amount) 
  box.left_top.x = box.left_top.x - amount
  box.left_top.y = box.left_top.y - amount
  box.right_bottom.x = box.right_bottom.x + amount
  box.right_bottom.y = box.right_bottom.y + amount
end

local function place_ghost(state, prototype_name, position, direction, modules)
  local args = {}
  args.name = "entity-ghost"
  args.inner_name = prototype_name
  args.position = position
  args.direction = direction
  args.force = state.force
  args.player = state.player
  local ghost = state.surface.create_entity(args)
  if modules then
    ghost.item_requests = modules
  end
end

local function distance_error(position_groups, position)
  local error = 0

  for _, pg in ipairs(position_groups) do
    for _, p in ipairs(pg) do
      error = error + dist_squared(p, position)
    end
  end
  return error
end

local function distance_error2(position_groups, position1, position2)
  local error1 = 0
  local error2 = 0

  for _, pg in pairs(position_groups) do
    for _, p in pairs(pg) do
      error1 = error1 + dist_squared(p, position1)
      error2 = error2 + dist_squared(p, position2)
    end
  end
  return error1, error2
end

-- find the min distance squared between two groups
local function error_between_groups(g1, g2)
  local error = math.huge
  local l1 = #g1
  local l2 = #g2
  for i = 1, l1 do
    p1 = g1[i]
    for j = 1, l2 do
      p2 = g2[j]
      local e = dist_squared(p1, p2)
      if e < error then
        error = e
      end
    end
  end
  return error
end

-- find the 2 closest poles in the 2 groups
local function find_closest_poles(g1, g2)
  local error = math.huge
  local l1 = #g1
  local l2 = #g2
  local out1, out2
  for i = 1, l1 do
    p1 = g1[i]
    for j = 1, l2 do
      p2 = g2[j]
      local e = dist_squared(p1, p2)
      if e < error then
        error = e
        out1 = p1
        out2 = p2
      end
    end
  end
  return out1, out2
end

-- fast merge 2 tables
local function fast_merge(t1, t2)
  local len1 = #t1
  local len2 = #t2
  for i = 1, len2 do
    t1[i + len1] = t2[i]
  end
end

local function not_blocked(blockers_map, position, pole_width, pole_height) 
  local width_adjust = (pole_width - 1) / 2
  local height_adjust = (pole_height - 1) / 2

  local x1 = position.x - width_adjust
  local y1 = position.y - height_adjust

  for x = 0, pole_width - 1 do
    local x2 = x1 + x
    for y = 0, pole_height - 1 do
      local y2 = y1 + y
      if blockers_map[key({x = x2, y = y2})] then 
        return false
      end
    end
  end
  return true
end

local function connect_2_pole_groups(g1, g2, blockers_map, wire_range_squared, pole_width, pole_height)
  local p1, p2 = find_closest_poles(g1, g2)


  -- log("connect_2_pole_groups 1")
  -- loop until we can merge the two groups or we fail to find a pole between them
  while true do
    local box = {}
    add_point(box, p1)
    add_point(box, p2)
    expand_box(box, 10)
    
    local best_score = 0
    local best_error = math.huge
    local best_pos
    for x = box.left_top.x, box.right_bottom.x do
      for y = box.left_top.y, box.right_bottom.y do
        local score = 0
        local pos = {x = x, y = y}
        if not_blocked(blockers_map, pos, pole_width, pole_height) then
          local ds1 = dist_squared(pos, p1)
          if ds1 > 0 and ds1 <= wire_range_squared then
            score = score + 1
          end

          local ds2 = dist_squared(pos, p2)
          if ds2 > 0 and ds2 <= wire_range_squared then
            score = score + 2
          end

          if score > best_score then
            best_score = score
            best_pos = pos
            best_error = math.huge
          elseif score == best_score then
            error = ds1 + ds2
            if error < best_error then
              best_error = error
              best_pos = pos
            end
          end
        end
      end
    end

    if best_score == 0 then
      -- failed to connect the groups
      return {g1, g2}
    elseif best_score == 1 then
      -- found a pole that fits in group 1
      local g3 = {best_pos}
      fast_merge(g3, g1)
      g1 = g3
      p1 = best_pos
    elseif best_score == 2 then
      -- found a pole that fits in group 2
      local g3 = {best_pos}
      fast_merge(g3, g2)
      g2 = g3
      p2 = best_pos
    elseif best_score == 3 then
      -- found a pole that joins both groups
      -- return a single merged group
      local g3 = {best_pos}
      fast_merge(g3, g1)    
      fast_merge(g3, g2)
      return {g3}    
    end
  end
end

-- pole_groups = connect_pole_groups(pole_groups, blockers_map)
local function connect_pole_groups(pole_groups, blockers_map, wire_range_squared, pole_width, pole_height)
  while true do
    if #pole_groups < 2 then
      return pole_groups
    elseif #pole_groups == 2 then
      return connect_2_pole_groups(pole_groups[1], pole_groups[2], blockers_map, wire_range_squared, pole_width, pole_height)
    end

    local error = math.huge
    local j = 0
    local pg1
    for i, pg in ipairs(pole_groups) do
      if i == 1 then
        pg1 = pg
      else
        local e = error_between_groups(pg1, pg)
        if e < error then
          error = e
          j = i
        end
      end
    end

    if j == 0 then
      -- this shouldn't happen
      return pole_groups
    end

    -- g2 will hold everything except pole_groups[1] and pole_groups[j]
    local g2 = {}
    local count = 0
    for i = 2, #pole_groups do
      if i ~= j then
        count = count + 1
        g2[count] = pole_groups[i]
      end
    end
    local new_groups = connect_2_pole_groups(pole_groups[1], pole_groups[j], blockers_map, wire_range_squared, pole_width, pole_height)
    fast_merge(g2, new_groups)
    pole_groups = g2
  end
end

-- TODO NEED TO ADD POLES TO BLOCKERS AS WE ADD THEM SO WE DONT PLACE 2 POLES ON TOP OF EACH OTHER

-- blockers_map map of blocked squares
-- consumers - items that need power {position, size}
-- pole_prototype - the prototype of the electric pole to use
local function place_electric_poles(blockers_map, consumers, pole_prototype, work_zone, state)
  pole_groups = {}

  local pole_width = math.ceil(pole_prototype.selection_box.right_bottom.x - pole_prototype.selection_box.left_top.x)
  local width_adjust = (pole_width - 1) / 2
  local pole_height = math.ceil(pole_prototype.selection_box.right_bottom.y - pole_prototype.selection_box.left_top.y)
  local height_adjust = (pole_height - 1) / 2

  local wire_range = pole_prototype.max_wire_distance
  local wire_range_squared = wire_range * wire_range

  log("finding pole_positions")
  state.profiler:reset()

  -- make a list of valid pole positions
  -- TODO: optimize for 2x2 poles
  local pole_positions = {}
  local pole_positions_count = 0
  for x = work_zone.left_top.x - width_adjust, work_zone.right_bottom.x + width_adjust do
    for y = work_zone.left_top.y - height_adjust, work_zone.right_bottom.y + height_adjust do
      local pos = {x = x, y = y}
      if not_blocked(blockers_map, pos, pole_width, pole_height) then
        pole_positions_count = pole_positions_count + 1
        pole_positions[pole_positions_count] = pos
      end
    end
  end

  log(state.profiler)
  log("pole_positions_count = "..pole_positions_count)
  log("placing electric poles")
  state.profiler:reset()

  while #consumers > 0 do
    log("#consumers = " .. #consumers)

    local consumer_count = #consumers
 
    -- find the pole location that powers the most consumers
    local best_score = 0
    for i = 1, pole_positions_count do
      local pos = pole_positions[i]
      local score = 0

      for j = 1, consumer_count do
        local c = consumers[j]
        local range = c.size + pole_prototype.supply_area_distance - 0.5
        if math.abs(c.position.x - pos.x) < range then
          if math.abs(c.position.y - pos.y) < range then
            score = score + 1
          end
        end
      end
      
      if score > best_score then
        best_score = score
        best_pos = pos
      -- else
      --   if score == best_score then
      --     e1, e2 = distance_error2(pole_groups, pos, best_pos)
      --     if e1 < e2 then
      --       best_pos = pos
      --     end
      --   end
      end
    end

    if best_score == 0 then
      break
    end
    
    local new_group = {best_pos}
    local new_groups = {new_group}
    
    for _, pg in pairs(pole_groups) do
      local found = false
      for _, p in pairs(pg) do
        if dist_squared(p, best_pos) <= wire_range_squared then
          found = true
          break
        end
      end
      if found then
        local j = #new_group
        for i, p in ipairs(pg) do
          new_group[i + j] = p
        end
      else
        table.insert(new_groups, pg)
      end
    end
    pole_groups = new_groups
    
    local new_consumers = {}
    for _, c in pairs(consumers) do
      local found = false
      local range = c.size + pole_prototype.supply_area_distance - 0.5
      if math.abs(c.position.x - best_pos.x) < range then
        if math.abs(c.position.y - best_pos.y) < range then
          found = true
        end
      end
      if not found then
        table.insert(new_consumers, c)
      end
    end

    consumers = new_consumers
  end

  log(state.profiler)
  log("done powering consumers")
  state.profiler:reset()
  
  pole_groups = connect_pole_groups(pole_groups, blockers_map, wire_range_squared, pole_width, pole_height)
  
  log(state.profiler)
  log("done connect groups of poles")
  state.profiler:reset()

  -- place poles
  for _, pg in ipairs(pole_groups) do
    for _, p in ipairs(pg) do
      place_ghost(state, pole_prototype.name, p)
    end
  end
  
end

-- returns a map of names of module ptorotypes
local function get_module_prototypes()
  out = {}
  for name, item in pairs(game.item_prototypes) do
    log(name)
    log(item.type)
    if item.type == "module" then
      log("match")
      out[name] = item
    end
  end
  return out
end

-- returns a map of items that place entities of type
local function get_items_of_entity_type(type)
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

local function get_pumpjack_prototypes()
  local items = get_items_of_entity_type("mining-drill")
  local out = {}
  for name, item in pairs(items) do
    local entity = item.place_result
    for category in pairs(entity.resource_categories) do
      if pumpable_resource_categories[category] then
        out[name] = item
      end
    end
  end
  return out
end

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

local function get_pumpjack()
  local prototypes = get_pumpjack_prototypes()
  local config_name = "well_planner_pumpjack_type"
  return get_prototype_from_config(prototypes, config_name)
end

local function get_pipe()
  local prototypes = get_items_of_entity_type("pipe")
  local config_name = "well_planner_pipe_type"
  return get_prototype_from_config(prototypes, config_name)
end

local function get_pipe_to_ground()
  local prototypes = get_items_of_entity_type("pipe-to-ground")
  local config_name = "well_planner_pipe_to_ground_type"
  return get_prototype_from_config(prototypes, config_name)
end

local function get_electric_pole()
  local prototypes = get_items_of_entity_type("electric-pole")
  local config_name = "well_planner_electric_pole_type"
  return get_prototype_from_config(prototypes, config_name)
end

local function get_module()
  local prototypes = get_module_prototypes()
  local config_name = "well_planner_module_type"
  return get_prototype_from_config(prototypes, config_name)
end

local function init()
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

local function profile_checkpoint(tag)
  log(tag)
end  

local function on_selected_area(event, deconstruct_friendly)
  init()

  local total_profiler = game.create_profiler()
  local profiler = game.create_profiler()
  profile_checkpoint("find patches")

  local pumpjack = get_pumpjack().place_result

  local player = game.players[event.player_index]
  local surface = player.surface
  local force = player.force
--	local conf = get_config(player)

  local state = {
    player = player,
    force = force,
    surface = surface,
  }

  -- find liquid resource patches...
  local patches_by_resource = {}
  local bad_resource_type
  for _, entity in pairs(event.entities) do
    -- ghost entities are not "valid"
    if entity.valid then
      p = entity.prototype
      if pumpjack.resource_categories[p.resource_category] then

        local fluid_patches = patches_by_resource[p.name]
        if not fluid_patches then
          fluid_patches = {}
          patches_by_resource[p.name] = fluid_patches
        end
        
        table.insert(fluid_patches, {position = entity.position})
      else
        bad_resource_type = p.localised_name
      end	
    end	
  end

  -- find the resource with the most patches
  local fluid_patches = {}
  for k, v in pairs(patches_by_resource) do
    if #v > #fluid_patches then
      fluid_patches = v
    end
  end
  
  if #fluid_patches == 0 then
    if bad_resource_type then
      player.print({"well-planner.bad_resoure", pumpjack.localised_name, bad_resource_type})
    else
      player.print({"well-planner.no_resoures"})
    end
    return
  end

  -- define a work zone around the fluid patches
  work_zone = {}
  for _, v in pairs(fluid_patches) do
    add_point(work_zone, v.position)
  end
  expand_box(work_zone, 3)

  -- Deconstruct anything in the area
  local da = {
    area = work_zone,
    force = force,
    player = player,
    skip_fog_of_war = true,
  }
  surface.deconstruct_area(da)

  -- if #fluid_patches == 1 then
    -- local patch = fluid_patches[1]
    -- todo place modules if pumpjack.module_inventory_size and pumpjack.module_inventory_size > 0
    -- local modules = {["speed-module-3"] = 1}
    -- place_ghost(state, pumpjack.name, patch.position, defines.direction.north, modules)
  --   place_ghost(state, pumpjack.name, patch.position, defines.direction.north)
  --   return
  -- end

  -- build the blockers map
  -- map of all tile locations where we cant build
  local blockers_map = {}
  local min, max

  for i, patch in ipairs(fluid_patches) do
    if i == 1 then
      min = patch.position
      max = patch.position
    else
      min = min_pos(min, patch.position)
      max = max_pos(max, patch.position)
    end
    for x = -1, 1 do
      for y = -1, 1 do
        local position = {
          x = patch.position.x + x,
          y = patch.position.y + y,
        }
        blockers_map[key(position)] = true
      end
    end
  end
  -- find the center of the patches
  local center = {
    x = (min.x + max.x) / 2,
    y = (min.y + max.y) / 2,
  }

  -- dont build on water tiles
  local tiles = surface.find_tiles_filtered{
    -- TODO dont hard-code
    area = work_zone,
    name = {     
      "water",
      "deepwater",
      "water-green",
      "deepwater-green",
      "water-shallow",
      "water-mud"
    }
  }
  for _, t in ipairs(tiles) do
    blockers_map[key(t.position)] = true
  end

  log(profiler)
  profile_checkpoint("route pipes")
  profiler:reset()

  -- add the patches to a queue
  -- patches closest to the center go first
  local patch_queue = PriorityQueue:new()
  for i, patch in ipairs(fluid_patches) do
    patch_queue:put(patch, dist_squared(center, patch.position))
  end


  -- pathfind for pipes
  local goals
  local starts
    
  local i = 0

  local pipes_to_place = {}
  local got_pipes = false
  while not patch_queue:empty() do
    i = i + 1
    local patch = patch_queue:pop()

    if i == 1 then
      goals = makeNodesFromPatch(patch)
    else
      starts = makeNodesFromPatch(patch)
      local node = a_star(starts, goals, blockers_map, work_zone, heuristic_score_taxicab)

      -- if node == nil then
      --   log("astar failed")
      -- else
      --   log("astar succeded")
      -- end

      if i == 2 and node ~= nil then
        goals = {}
      end

      while node do
        pipes_to_place[key(node.position)] = node
        got_pipes = true
        
        if node.patch then
          node.patch.direction = node.direction

          node.patch = nil

          if node.direction == defines.direction.north or node.direction == defines.direction.south then 
            node.vertical_connection = true
          else
            node.horizontal_connection = true
          end

        end

        table.insert(goals, node)

        node = node.parent
      end      
    end
  end

  -- place ghosts for pumps
  local unconnected_pumps = 0
  for _, patch in pairs(fluid_patches) do
    if not patch.direction then
      unconnected_pumps = unconnected_pumps + 1
    end

    -- place modules in pumpjack
    local modules = {}
    if global.config.well_planner_use_modules then
      if pumpjack.module_inventory_size and pumpjack.module_inventory_size > 0 then
        modules[get_module().name] = pumpjack.module_inventory_size
      end
    end
    place_ghost(state, pumpjack.name, patch.position, patch.direction, modules)

  end
  if #fluid_patches > 1 and unconnected_pumps > 0 then
    player.print({"well-planner.cant_connect", ""..unconnected_pumps, pumpjack.localised_name})
  end

  log(profiler)
  profile_checkpoint("route underground pipes")
  profiler:reset()

  -- convert to underground pipes
  if global.config.well_planner_use_pipe_to_ground == true and got_pipes then
    local pipe_to_ground = get_pipe_to_ground().place_result
    local fb = pipe_to_ground.fluidbox_prototypes[1]
    local mud = 10
    for k, v in pairs(fb.pipe_connections) do
      if v.max_underground_distance then
        mud = v.max_underground_distance
      end
    end

    local pipe_zone = {}
    for k, node in pairs(pipes_to_place) do
      add_point(pipe_zone, node.position)
    end

    local left = math.floor(pipe_zone.left_top.x)
    local top = math.floor(pipe_zone.left_top.y)
    local right = math.floor(pipe_zone.right_bottom.x)
    local bottom = math.floor(pipe_zone.right_bottom.y)

    local count = 0

    local pipes_to_delete = {}
    local pipes_to_ground = {}

    local min_pipe_run = 2

    -- replace east-west runs of pipe with pipe-to-ground
    for row = top, bottom do
      for col = left, right + 1 do
        local good = false
        local pipe = pipes_to_place[col .. "," .. row]
        if pipe then
          if not pipe.vertical_connection then
            if not (pipes_to_place[col .. "," .. (row - 1)] or pipes_to_place[col .. "," .. (row + 1)]) then
              good = true
            end
          end
        end

        if good then
          count = count + 1
        else
          if count >= min_pipe_run then
            for i = 1, count do
              table.insert(pipes_to_delete, (col - i) .. "," .. row)
            end
            local segments = math.floor((count + mud) / (mud + 1))
            for segment = 0, segments - 1 do
              local segment_start = math.floor(count * segment / segments)
              local segment_end = math.floor(count * (segment + 1) / segments) - 1

              local pos1 = {x = col - segment_start - 0.5, y = row + 0.5}
              place_ghost(state, pipe_to_ground.name, pos1, defines.direction.east)
              table.insert(pipes_to_ground, key(pos1))

              local pos2 = {x = col - segment_end - 0.5, y = row + 0.5}
              place_ghost(state, pipe_to_ground.name, pos2, defines.direction.west)
              table.insert(pipes_to_ground, key(pos2))
            end
          end
          count = 0
        end
      end
    end

    -- replace north-south runs of pipe with pipe-to-ground
    for col = left, right do
      for row = top, bottom + 1 do
      local good = false
        local pipe = pipes_to_place[col .. "," .. row]
        if pipe then
          if not pipe.horizontal_connection then
            if not (pipes_to_place[(col - 1) .. "," .. row] or pipes_to_place[(col + 1) .. "," .. row]) then
              good = true
            end
          end
        end

        if good then
          count = count + 1
        else
          if count >= min_pipe_run then
            for i = 1, count do
              table.insert(pipes_to_delete, col .. "," .. (row - i))
            end
            local segments = math.floor((count + mud) / (mud + 1))
            for segment = 0, segments - 1 do
              local segment_start = math.floor(count * segment / segments)
              local segment_end = math.floor(count * (segment + 1) / segments) - 1

              local pos1 = {x = col + 0.5, y = row - segment_start - 0.5}
              place_ghost(state, pipe_to_ground.name, pos1, defines.direction.south)
              table.insert(pipes_to_ground, key(pos1))
              
              local pos2 = {x = col + 0.5, y = row - segment_end - 0.5}
              place_ghost(state, pipe_to_ground.name, pos2, defines.direction.north)
              table.insert(pipes_to_ground, key(pos2))
            end
          end
          count = 0
        end
      end
    end

    -- remove the pipes
    for _, v in ipairs(pipes_to_delete) do
      pipes_to_place[v] = nil
    end

    for _, key in ipairs(pipes_to_ground) do
      blockers_map[key] = true
    end
  end

  -- connect with pipes
  local pipe_proto = get_pipe()
  for k, node in pairs(pipes_to_place) do
    place_ghost(state, pipe_proto.name, node.position)
    blockers_map[node.key] = true
  end

  log(profiler)
  profile_checkpoint("place elecctric poles")
  profiler:reset()
  state.profiler = profiler

  if global.config.well_planner_place_electric_poles then
    -- log("place electric poles")
    local consumers = {}
    for i, p in ipairs(fluid_patches) do
      table.insert(consumers, {position = p.position, size = 1.5})
    end
    local electric_pole_proptotype = get_electric_pole().place_result
    place_electric_poles(blockers_map, consumers, electric_pole_proptotype, work_zone, state)
  end
  log(profiler)
  profile_checkpoint("done")
  profiler = nil
  log("total_time")
  log(total_profiler)
  total_profiler = nil
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
  init()

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

local function on_mod_item_opened(event)
  local player = game.players[event.player_index]
  gui_open_close_frame(player)
end

script.on_event(
  defines.events.on_gui_click,
  function(event)
    local name = event.element.name
    if name == "well_planner_close_button" then
      local player = game.players[event.player_index]
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

script.on_event(
  defines.events.on_mod_item_opened,
  function(event)
    if event.item.name == "well-planner" then
      on_mod_item_opened(event)
    end
  end
)

script.on_event(
  defines.events.on_player_selected_area,
  function(event)
    if event.item == "well-planner" then
      on_selected_area(event)
    end
  end
)

script.on_event(
  defines.events.on_player_alt_selected_area,
  function(event)
    if event.item == "well-planner" then
      on_selected_area(event, true)
    end
  end
)

