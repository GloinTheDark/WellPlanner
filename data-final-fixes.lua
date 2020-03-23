local pumpable_resource_categories = require("pumpable")

local resource_names = {}
for name,resource in pairs(data.raw["resource"]) do
    if pumpable_resource_categories[resource.category] then
        table.insert(resource_names, name)
        -- log(name)
    end
end

local well_planner = data.raw["selection-tool"]["well-planner"]

well_planner.entity_filters = resource_names
well_planner.alt_entity_filters = resource_names
