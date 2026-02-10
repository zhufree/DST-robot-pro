local ACTIONS = GLOBAL.ACTIONS
local StorageRobotCommon = GLOBAL.require("prefabs/storage_robot_common")

local freshness_rate = GetModConfigData("freshness_rate") or 0.5

---------------------------------------------------------------------------------------------------
-- Hook FindContainerWithItem：优先返回机器人自身作为存储目标
---------------------------------------------------------------------------------------------------
local _original_FindContainerWithItem = StorageRobotCommon.FindContainerWithItem
StorageRobotCommon.FindContainerWithItem = function(robot, item, count)
    if robot._extracting then
        return _original_FindContainerWithItem(robot, item, count)
    end
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
    if doer == target and doer:HasTag("storagerobot")
        and doer.components.inventory ~= nil
        and doer.components.container ~= nil then
        local item = act.invobject
        if item ~= nil then
            doer.components.inventory:RemoveItem(item, true)
            if not doer.components.container:GiveItem(item) then
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
-- 通用的机器人存储增强PostInit
---------------------------------------------------------------------------------------------------
local function RobotStoragePostInit(inst)
    if not GLOBAL.TheWorld.ismastersim then
        return
    end

    -- 防止原始FindContainerWithItem搜索附近容器时把机器人自身也搜到
    inst:AddTag("portablestorage")

    -- 添加container组件（3x3 = 9格暂存背包）
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("robot_inventory")
    inst.components.container.canbeopened = true

    -- 修复container中物品被消耗/销毁后slot引用残留导致的崩溃：
    -- 当物品被吃掉、使用等操作后变成LIMBO/invalid状态，但container的slot引用
    -- 没有被清理，后续的Close/Swap/Remove等操作访问到无效物品时会崩溃。
    -- 方案：监听itemget/itemlose事件，对每个放入container的物品注册onremove回调，
    -- 物品被销毁时自动清理对应的slot引用。
    local function CleanInvalidSlots(container)
        for k, v in GLOBAL.pairs(container.slots) do
            if v ~= nil and (not v:IsValid() or v.replica.inventoryitem == nil) then
                container.slots[k] = nil
            end
        end
    end

    local item_remove_listeners = {}

    local function TrackItemRemoval(container, slot, item)
        if item == nil then return end
        -- 移除旧的监听（如果有）
        if item_remove_listeners[item] then
            inst:RemoveEventCallback("onremove", item_remove_listeners[item], item)
            item_remove_listeners[item] = nil
        end
        -- 注册新的onremove监听
        local fn = function()
            if container.slots[slot] == item then
                container.slots[slot] = nil
            end
            item_remove_listeners[item] = nil
        end
        item_remove_listeners[item] = fn
        inst:ListenForEvent("onremove", fn, item)
    end

    local function UntrackItem(item)
        if item == nil then return end
        if item_remove_listeners[item] then
            inst:RemoveEventCallback("onremove", item_remove_listeners[item], item)
            item_remove_listeners[item] = nil
        end
    end

    inst:ListenForEvent("itemget", function(inst, data)
        if data and data.item and inst.components.container
            and inst.components.container.slots[data.slot] == data.item then
            TrackItemRemoval(inst.components.container, data.slot, data.item)
        end
    end)

    inst:ListenForEvent("itemlose", function(inst, data)
        if data and data.prev_item then
            UntrackItem(data.prev_item)
        end
    end)

    -- 额外保护：Close前也清理一遍无效slot（兜底）
    local _orig_Close = inst.components.container.Close
    inst.components.container.Close = function(self, doer)
        CleanInvalidSlots(self)
        return _orig_Close(self, doer)
    end

    -- 修复inventory和container在同一entity上的事件冲突：
    -- container_replica监听了entity上所有的itemget/itemlose事件，
    -- 当inventory组件触发itemget(slot=1)时，container_replica会误将
    -- inventory的物品同步到container的slot 1，导致第一格显示异常。
    if inst.replica.container ~= nil then
        local replica = inst.replica.container
        local _orig_onitemget = replica._onitemget
        local _orig_onitemlose = replica._onitemlose

        if _orig_onitemget ~= nil then
            inst:RemoveEventCallback("itemget", _orig_onitemget)
            replica._onitemget = function(inst, data)
                if inst.components.container
                    and inst.components.container.slots[data.slot] == data.item then
                    _orig_onitemget(inst, data)
                end
            end
            inst:ListenForEvent("itemget", replica._onitemget)
        end

        if _orig_onitemlose ~= nil then
            inst:RemoveEventCallback("itemlose", _orig_onitemlose)
            replica._onitemlose = function(inst, data)
                if inst.components.container
                    and data.slot <= inst.components.container.numslots
                    and inst.components.container.slots[data.slot] == nil then
                    _orig_onitemlose(inst, data)
                end
            end
            inst:ListenForEvent("itemlose", replica._onitemlose)
        end
    end

    -- 保鲜功能
    if freshness_rate ~= nil then
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

        inst:ListenForEvent("itemlose", function(inst, data)
            if data.prev_item then
                ResetItemFreshness(data.prev_item)
            end
        end)

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
AddPrefabPostInit("storage_robot", RobotStoragePostInit)
AddPrefabPostInit("winona_storage_robot", RobotStoragePostInit)
