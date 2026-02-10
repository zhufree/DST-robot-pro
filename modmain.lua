-- 瓦器人 storage_robot
-- 薇机人 winona_storage_robot

local Recipe = GLOBAL.Recipe
local Ingredient = GLOBAL.Ingredient
local RECIPETABS = GLOBAL.RECIPETABS
local TECH = GLOBAL.TECH
local ACTIONS = GLOBAL.ACTIONS
local Vector3 = GLOBAL.Vector3

-- 给原版wobot添加配方（原版没配方，现在有了）
AddRecipe2("storage_robot",  -- 已有prefab名
    {
        Ingredient("gears", 4),
        Ingredient("scrap", 8),
    },
    TECH.NONE,  -- 科技（或SCIENCE_TWO）
    nil,{"TOOLS", "MODS"}
)

---------------------------------------------------------------------------------------------------
-- 注册容器UI
---------------------------------------------------------------------------------------------------
modimport("scripts/containers.lua")

---------------------------------------------------------------------------------------------------
-- 获取保鲜配置
---------------------------------------------------------------------------------------------------
local freshness_rate = GetModConfigData("freshness_rate") or 0.5

---------------------------------------------------------------------------------------------------
-- 全局引用
---------------------------------------------------------------------------------------------------
local StorageRobotCommon = GLOBAL.require("prefabs/storage_robot_common")
local EQUIPSLOTS = GLOBAL.EQUIPSLOTS

---------------------------------------------------------------------------------------------------
-- Hook FindContainerWithItem：优先返回机器人自身作为存储目标
---------------------------------------------------------------------------------------------------
local _original_FindContainerWithItem = StorageRobotCommon.FindContainerWithItem
StorageRobotCommon.FindContainerWithItem = function(robot, item, count)
    if robot.components.container ~= nil then
        count = count or 0
        local stack_maxsize = item.components.stackable ~= nil and item.components.stackable.maxsize or 1
        if robot.components.container:CanAcceptCount(item, stack_maxsize) > count then
            return robot
        end
    end
    return _original_FindContainerWithItem(robot, item, count)
end

---------------------------------------------------------------------------------------------------
-- Hook STORE动作：当机器人对自身执行STORE时，直接转移物品到container
-- 避免原始STORE的OpenChestContainer/CloseChestContainer导致显示冲突
---------------------------------------------------------------------------------------------------
local _original_store_fn = ACTIONS.STORE.fn
ACTIONS.STORE.fn = function(act)
    local doer = act.doer
    local target = act.target
    -- 只拦截机器人对自身执行STORE的情况
    if doer == target and doer:HasTag("storagerobot")
        and doer.components.inventory ~= nil
        and doer.components.container ~= nil then
        local item = act.invobject
        if item ~= nil then
            -- 从inventory中移除物品
            doer.components.inventory:RemoveItem(item, true)
            -- 直接放入自身container
            if not doer.components.container:GiveItem(item) then
                -- container满了，放回inventory
                doer.components.inventory:GiveItem(item)
            end
        end
        return true
    end
    return _original_store_fn(act)
end

---------------------------------------------------------------------------------------------------
-- 保鲜辅助函数
---------------------------------------------------------------------------------------------------
local function SetItemFreshness(item)
    if item and item.components.perishable then
        if freshness_rate == 0 then
            item.components.perishable:SetLocalMultiplier(0)
        else
            item.components.perishable:SetLocalMultiplier(freshness_rate)
        end
    end
end

local function ResetItemFreshness(item)
    if item and item:IsValid() and item.components.perishable then
        item.components.perishable:SetLocalMultiplier(1)
    end
end

local function ApplyFreshnessToAllSlots(inst)
    if inst.components.container and inst.components.container.slots then
        for k, v in pairs(inst.components.container.slots) do
            SetItemFreshness(v)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- 通用的机器人增强PostInit
---------------------------------------------------------------------------------------------------
local function RobotPostInit(inst)
    if not GLOBAL.TheWorld.ismastersim then
        return
    end

    -- 防止原始FindContainerWithItem搜索附近容器时把机器人自身也搜到
    -- portablestorage在原始CONTAINER_CANT_TAGS中，会被排除
    inst:AddTag("portablestorage")

    -- 添加container组件（3x3 = 9格暂存背包）
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("robot_inventory")
    inst.components.container.canbeopened = true

    -- 保鲜功能
    if freshness_rate ~= nil then
        -- 物品进入container时应用保鲜
        inst:ListenForEvent("itemget", function(inst, data)
            if data.item and inst.components.container then
                for k, v in pairs(inst.components.container.slots) do
                    if v == data.item then
                        SetItemFreshness(data.item)
                        return
                    end
                end
            end
        end)

        -- 物品离开container时恢复正常腐烂速率
        inst:ListenForEvent("itemlose", function(inst, data)
            if data.prev_item then
                ResetItemFreshness(data.prev_item)
            end
        end)

        -- 对已有物品应用保鲜（加载存档时）
        local _OnLoad = inst.OnLoad
        inst.OnLoad = function(inst, data, newents)
            if _OnLoad then
                _OnLoad(inst, data, newents)
            end
            inst:DoTaskInTime(0, function()
                ApplyFreshnessToAllSlots(inst)
            end)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- 右键动作：打开机器人背包
---------------------------------------------------------------------------------------------------
AddComponentAction("SCENE", "container", function(inst, doer, actions, right)
    if right and inst:HasTag("storagerobot") and inst.components.container ~= nil then
        table.insert(actions, ACTIONS.RUMMAGE)
    end
end)

---------------------------------------------------------------------------------------------------
-- 对两种机器人应用PostInit
---------------------------------------------------------------------------------------------------
AddPrefabPostInit("storage_robot", function(inst)
    RobotPostInit(inst)
end)

AddPrefabPostInit("winona_storage_robot", function(inst)
    RobotPostInit(inst)
end)
