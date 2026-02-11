-- 机器人设置的共享定义（服务端和客户端都会用到）
-- 采集类别分组和保鲜选项

local HARVEST_CATEGORIES = {
    {
        id = "materials",
        name = "素材",
        desc = "草、树枝、芦苇、猴尾草",
        prefabs = {
            "grass", "sapling", "reeds", "reeds_water", "monkeytail",
        },
        default = true,
    },
    {
        id = "foods",
        name = "食物",
        desc = "浆果、蘑菇、香蕉、地衣、石果、胡萝卜",
        prefabs = {
            "berrybush", "berrybush2", "berrybush_juicy",
            "red_mushroom", "green_mushroom", "blue_mushroom",
            "cave_banana_tree", "lichen", "rock_avocado_bush",
            "carrot_planted",
        },
        default = false,
    },
}

local FRESHNESS_OPTIONS = {
    { value = 0,    label = "永不腐烂" },
    { value = 0.1,  label = "非常慢 (0.1x)" },
    { value = 0.25, label = "较慢 (0.25x)" },
    { value = 0.5,  label = "慢 (0.5x)" },
    { value = 1,    label = "正常 (1x)" },
}

local DEFAULT_FRESHNESS = 0.5

return {
    HARVEST_CATEGORIES = HARVEST_CATEGORIES,
    FRESHNESS_OPTIONS = FRESHNESS_OPTIONS,
    DEFAULT_FRESHNESS = DEFAULT_FRESHNESS,
}
