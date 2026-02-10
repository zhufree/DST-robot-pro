local ACTIONS = GLOBAL.ACTIONS
local StorageRobotCommon = GLOBAL.require("prefabs/storage_robot_common")
local BufferedAction = GLOBAL.BufferedAction
local TUNING = GLOBAL.TUNING

---------------------------------------------------------------------------------------------------
-- 调试日志：让机器人说话
---------------------------------------------------------------------------------------------------
local function RobotSay(inst, msg)
    if inst.components.talker then
        inst.components.talker:Say(msg)
    else
        print("[RobotHarvest] " .. tostring(inst) .. ": " .. msg)
    end
end

---------------------------------------------------------------------------------------------------
-- 读取采集配置，构建可采集prefab集合
---------------------------------------------------------------------------------------------------
local auto_harvest = GetModConfigData("auto_harvest")
if auto_harvest == nil then auto_harvest = true end

local HARVESTABLE_PREFABS = {}

local HARVEST_CONFIG = {
    { config = "harvest_grass",         prefabs = {"grass"} },
    { config = "harvest_sapling",       prefabs = {"sapling"} },
    { config = "harvest_berries",       prefabs = {"berrybush", "berrybush2"} },
    { config = "harvest_berries_juicy", prefabs = {"berrybush_juicy"} },
    { config = "harvest_mushroom",      prefabs = {"red_mushroom", "green_mushroom", "blue_mushroom"} },
    { config = "harvest_reeds",         prefabs = {"reeds", "reeds_water"} },
    { config = "harvest_carrot",        prefabs = {"carrot_planted"} },
    { config = "harvest_cave_banana",   prefabs = {"cave_banana_tree"} },
    { config = "harvest_lichen",        prefabs = {"lichen"} },
    { config = "harvest_rock_avocado",  prefabs = {"rock_avocado_bush"} },
    { config = "harvest_monkeytail",    prefabs = {"monkeytail"} },
}

if auto_harvest then
    for _, entry in ipairs(HARVEST_CONFIG) do
        local enabled = GetModConfigData(entry.config)
        if enabled then
            for _, prefab in ipairs(entry.prefabs) do
                HARVESTABLE_PREFABS[prefab] = true
            end
        end
    end
end

if not auto_harvest or GLOBAL.next(HARVESTABLE_PREFABS) == nil then
    print("[RobotHarvest] auto_harvest disabled or no prefabs configured, skipping.")
    return
end

print("[RobotHarvest] Enabled. Harvestable prefabs:")
for k, _ in GLOBAL.pairs(HARVESTABLE_PREFABS) do
    print("  - " .. k)
end

---------------------------------------------------------------------------------------------------
-- 辅助函数
---------------------------------------------------------------------------------------------------
local HARVEST_MUST_TAGS = { "pickable" }
local HARVEST_CANT_TAGS = { "NOCLICK", "event_trigger", "fire", "smolder", "INLIMBO" }

local function FindHarvestTarget(inst)
    local spawnpt = StorageRobotCommon.GetSpawnPoint(inst)
    if spawnpt == nil then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local sx, sy, sz = spawnpt:Get()
    local radius = TUNING.STORAGE_ROBOT_WORK_RADIUS

    local ents = GLOBAL.TheSim:FindEntities(x, y, z, radius, HARVEST_MUST_TAGS, HARVEST_CANT_TAGS)
    local platform = inst:GetCurrentPlatform()

    for _, ent in ipairs(ents) do
        if HARVESTABLE_PREFABS[ent.prefab]
            and ent.components.pickable ~= nil
            and ent.components.pickable:CanBePicked()
            and ent:IsOnPassablePoint()
            and ent:GetCurrentPlatform() == platform
            and ent:GetDistanceSqToPoint(sx, sy, sz) <= radius * radius then
            return ent
        end
    end
end

local function HasContainerSpace(inst)
    if inst.components.container == nil then
        return false
    end
    for i = 1, inst.components.container.numslots do
        if inst.components.container.slots[i] == nil then
            return true
        end
    end
    return false
end

-- 采集并直接放入container
local function HarvestAndStore(inst, target)
    if target == nil or target.components.pickable == nil then
        return false
    end
    if not target.components.pickable:CanBePicked() then
        return false
    end
    if inst.components.container == nil then
        return false
    end

    -- 执行采集（pickable:Pick会将物品放入picker的inventory）
    target.components.pickable:Pick(inst)

    -- 将inventory中的所有物品转移到container
    if inst.components.inventory then
        local item = inst.components.inventory:GetFirstItemInAnySlot()
        while item ~= nil do
            local removed = inst.components.inventory:RemoveItem(item, true)
            if removed then
                if not inst.components.container:GiveItem(removed) then
                    -- container满了，放回inventory
                    inst.components.inventory:GiveItem(removed)
                    break
                end
            else
                break
            end
            item = inst.components.inventory:GetFirstItemInAnySlot()
        end
    end

    return true
end

---------------------------------------------------------------------------------------------------
-- Hook ACTIONS.PICK：当机器人执行PICK时，采集后直接放入container
---------------------------------------------------------------------------------------------------
local _original_pick_fn = ACTIONS.PICK.fn
ACTIONS.PICK.fn = function(act)
    if act.doer ~= nil and act.doer:HasTag("storagerobot")
        and act.doer.components.container ~= nil then
        return HarvestAndStore(act.doer, act.target)
    end
    return _original_pick_fn(act)
end

-- 为stategraph添加PICK动作handler（复用pickup动画）
AddStategraphActionHandler("storage_robot", GLOBAL.ActionHandler(ACTIONS.PICK, "pickup"))

---------------------------------------------------------------------------------------------------
-- Brain PostInit：在行为树中插入采集行为节点
-- modpostinitfns在Brain:Start()中OnStart()之后调用，此时bt已经创建好了
---------------------------------------------------------------------------------------------------
AddBrainPostInit("storage_robotbrain", function(self)
    print("[RobotHarvest] BrainPostInit called for " .. tostring(self.inst))

    if self.bt == nil then
        print("[RobotHarvest] ERROR: bt is nil!")
        return
    end

    -- 行为树实际结构（从日志dump确认）:
    -- root (Priority)
    --   children[1] = Parallel
    --     children[1] = ConditionNode "NO BRAIN WHEN BUSY OR BROKEN"
    --     children[2] = Priority {PickUp, StoreItem, GoHome, StandStill}
    local root = self.bt.root
    local parallelnode = root and root.children and root.children[1]
    local prioritynode = parallelnode and parallelnode.children and parallelnode.children[2]

    if prioritynode == nil or prioritynode.children == nil then
        print("[RobotHarvest] ERROR: could not find PriorityNode in behavior tree!")
        return
    end

    print("[RobotHarvest] BrainPostInit: found PriorityNode with " .. #prioritynode.children .. " children")

    local harvest_node = GLOBAL.DoAction(self.inst, function(inst)
        -- 低电量时不采集
        if inst.LOW_BATTERY_GOHOME and
            inst.components.fueled:GetPercent() < TUNING.WINONA_STORAGE_ROBOT_LOW_FUEL_PCT and
            StorageRobotCommon.GetSpawnPoint(inst) then
            return
        end

        -- inventory有物品时不采集（先存储）
        if inst.components.inventory:GetFirstItemInAnySlot() ~= nil then
            return
        end

        -- container满了不采集
        if not HasContainerSpace(inst) then
            return
        end

        local target = FindHarvestTarget(inst)
        if target == nil then
            return
        end

        RobotSay(inst, "发现 " .. (target.prefab or "?") .. "!")
        return BufferedAction(inst, target, ACTIONS.PICK)
    end, "Harvest Plant", true)

    -- 插入到第3个位置（PickUp=1, StoreItem=2, Harvest=3, GoHome=4...）
    GLOBAL.table.insert(prioritynode.children, 3, harvest_node)
    print("[RobotHarvest] Harvest node inserted at position 3, total children = " .. #prioritynode.children)
end)

---------------------------------------------------------------------------------------------------
-- 离屏采集支持
---------------------------------------------------------------------------------------------------
local function DoOffscreenHarvest(inst)
    if not inst:IsAsleep() then
        return false
    end
    if not HasContainerSpace(inst) then
        return false
    end

    local target = FindHarvestTarget(inst)
    if target == nil then
        return false
    end

    return HarvestAndStore(inst, target)
end

local function HookOffscreenHarvest(inst)
    if not GLOBAL.TheWorld.ismastersim then return end

    local _OnEntitySleep = inst.OnEntitySleep
    inst.OnEntitySleep = function(inst, ...)
        if _OnEntitySleep then
            _OnEntitySleep(inst, ...)
        end
        if inst._harvest_sleep_task == nil then
            inst._harvest_sleep_task = inst:DoPeriodicTask(5, function()
                if inst:IsAsleep() and not inst.components.fueled:IsEmpty() then
                    DoOffscreenHarvest(inst)
                end
            end)
        end
    end

    local _OnEntityWake = inst.OnEntityWake
    inst.OnEntityWake = function(inst, ...)
        if _OnEntityWake then
            _OnEntityWake(inst, ...)
        end
        if inst._harvest_sleep_task ~= nil then
            inst._harvest_sleep_task:Cancel()
            inst._harvest_sleep_task = nil
        end
    end
end

AddPrefabPostInit("storage_robot", HookOffscreenHarvest)
AddPrefabPostInit("winona_storage_robot", HookOffscreenHarvest)
