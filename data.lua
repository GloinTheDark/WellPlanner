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
            selection_cursor_box_type = "entity",
            alt_selection_cursor_box_type = "entity",


            subgroup = "tool",
            order = "c[automated-construction]-d[well-planner]",
            stack_size = 1,

            entity_type_filters = {"resource"},
            alt_entity_type_filters = {"resource"},
            entity_filter_mode = "whitelist",

            entity_filters = {
                "basic-fluid",
                "water",
                "oil",
                "crude-oil",
                "mineral-water"
            },

            alt_entity_filters = {
                "basic-fluid",
                "water",
                "oil",
                "crude-oil",
                "mineral-water"
            },
            -- can_be_mod_opened = false,
            -- stackable = false,
            flags = {"not-stackable", "only-in-cursor", "spawnable"},

            -- subgroup = "tool",
        },
    
        {
            type = "shortcut",
            name = "well-planner",
            localised_name = {"item-name.well-planner"},
            tooltip = {"item-description.well-planner"},
            order = "b[blueprint]-i[well-planner]",
            associated_control_input = "well-planner",
            action = "spawn-item",
            item_to_spawn = "well-planner",
            style = "blue",
            icon =
            {
                filename = "__WellPlanner__/graphics/wp-shortcut-x32.png",
                priority = "extra-high-no-scale",
                size = 32,
                scale = 1,
                flags = {"gui-icon"}
            },
            small_icon =
            {
                filename = "__WellPlanner__/graphics/wp-shortcut-x24.png",
                priority = "extra-high-no-scale",
                size = 24,
                scale = 1,
                flags = {"gui-icon"}
            },
        },
        {
            type = "custom-input",
            name = "well-planner",
            localised_name = {"item-name.well-planner"},
            action = "spawn-item",
            item_to_spawn = "well-planner",
            key_sequence = "",
        },
        {
            type = "sprite",
            name = "well-planner",
            filename = "__WellPlanner__/graphics/settings.png",
            width = 64,
            height = 64
        },
    
    }
)
      