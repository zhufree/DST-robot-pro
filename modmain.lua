-- 瓦器人 storage_robot
-- 薇机人 winona_storage_robot
-- 饥荒游戏代码参考：E:\Steam\steamapps\common\Don't Starve Together\data\databundles\lib_scripts

local Ingredient = GLOBAL.Ingredient
local TECH = GLOBAL.TECH

---------------------------------------------------------------------------------------------------
-- 注册prefab和配方
---------------------------------------------------------------------------------------------------
PrefabFiles = { "robot_controller" }

-- 给原版wobot添加配方（原版没配方，现在有了）
AddRecipe2("storage_robot",
    {
        Ingredient("gears", 4),
        Ingredient("transistor", 4),
    },
    TECH.SCIENCE_ONE,
    nil, {"TOOLS", "MODS"}
)

-- 机器人控制器配方：一级科技，电子元件+废料
AddRecipe2("robot_controller",
    {
        Ingredient("transistor", 1),
        Ingredient("gears", 1),
    },
    TECH.SCIENCE_ONE,
    nil, {"TOOLS", "MODS"}
)

---------------------------------------------------------------------------------------------------
-- 自定义Action：提取全部物品（从机器人container转移到玩家inventory）
---------------------------------------------------------------------------------------------------
AddAction("ROBOT_EXTRACT", "提取全部", function(act)
    local doer = act.doer
    local target = act.target
    if doer == nil or target == nil then return false end
    if doer.components.inventory == nil then return false end
    if target.components.container == nil then return false end

    local container = target.components.container

    -- 关键修复：先关闭容器，防止GiveItem把物品塞回已打开的机器人container
    container:Close()

    target._extracting = true
    local transferred = 0
    for slot = 1, container.numslots do
        local item = container.slots[slot]
        if item ~= nil then
            if not item:IsValid() or item.components.inventoryitem == nil then
                container.slots[slot] = nil
            else
                local removed = container:RemoveItemBySlot(slot)
                if removed ~= nil then
                    -- GiveItem可能因背包满而失败，此时掉落到地上
                    if not doer.components.inventory:GiveItem(removed) then
                        doer.components.inventory:DropItem(removed, true, false)
                    end
                    transferred = transferred + 1
                end
            end
        end
    end
    target._extracting = nil
    return true
end)

---------------------------------------------------------------------------------------------------
-- 模块导入
---------------------------------------------------------------------------------------------------
-- 容器UI定义（需要在Action注册之后，因为containers.lua中引用了ROBOT_EXTRACT）
modimport("scripts/containers.lua")
-- 物品存储功能（container、STORE hook、保鲜、replica修复、per-robot设置持久化）
modimport("scripts/robot_storage.lua")
-- 机器人控制器功能（Action、RPC、设置UI交互）
modimport("scripts/robot_configure.lua")
-- 自动采集功能
modimport("scripts/robot_harvest.lua")
