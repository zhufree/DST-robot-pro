-- 瓦器人 storage_robot
-- 薇机人 winona_storage_robot

local Ingredient = GLOBAL.Ingredient
local TECH = GLOBAL.TECH

-- 给原版wobot添加配方（原版没配方，现在有了）
AddRecipe2("storage_robot",
    {
        Ingredient("gears", 4),
        Ingredient("scrap", 8),
    },
    TECH.NONE,
    nil, {"TOOLS", "MODS"}
)

-- 容器UI定义
modimport("scripts/containers.lua")
-- 物品存储功能（container、STORE hook、保鲜、replica修复）
modimport("scripts/robot_storage.lua")
-- 自动采集功能
modimport("scripts/robot_harvest.lua")
