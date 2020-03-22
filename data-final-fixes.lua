




local resource_names = {}
for name,resource in pairs(data.raw["resource"]) do
    if resource.catagory ~= "basic-solid" then
        table.insert(resource_names, name)
    end
end

local well_planner = data.raw["selection-tool"]["well-planner"]

well_planner.entity_filters = resource_names
well_planner.alt_entity_filters = resource_names
