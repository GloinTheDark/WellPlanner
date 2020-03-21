--data.lua

data:extend(
    {
        {
            type = "selection-tool",
            name = "well-planner",
            icon = "__WellPlanner__/graphics/well-planner.png",
            icon_size = 64,
            selection_color = {r = 1.0, g = 0.55, b = 0.0, a = 0.2},
            alt_selection_color = {r = 1.0, g = 0.2, b = 0.0, a = 0.2},
            selection_mode = {"any-entity"},
            alt_selection_mode = {"any-entity"},
            selection_cursor_box_type = "not-allowed",
            alt_selection_cursor_box_type = "not-allowed",
            subgroup = "tool",
            order = "c[automated-construction]-d[well-planner]",
            stack_size = 1,
            show_in_library = true,
            entity_filters = {"crude-oil"},
            alt_entity_filters = {"crude-oil"},
            can_be_mod_opened = true,
            stackable = false,
            flags = {"not-stackable", "mod-openable"},
        },
        {
            type = "recipe",
            name = "well-planner",
            enabled = true,
            energy_required = 0.1,
            category = "crafting",
            ingredients = {},
            result = "well-planner"
        },
    }
)
      