local ACTIONS = GLOBAL.ACTIONS
local SettingsDef = GLOBAL.require("robot_settings_def")

---------------------------------------------------------------------------------------------------
-- 自定义Action：使用控制器配置机器人（客户端打开UI，服务端接收设置）
---------------------------------------------------------------------------------------------------
local ROBOT_CONFIGURE = AddAction("ROBOT_CONFIGURE", "配置机器人", function(act)
    print("[RobotConfigure] Action fn executed on server, doer="..tostring(act.doer).." target="..tostring(act.target))
    return true
end)
ROBOT_CONFIGURE.distance = 3
ROBOT_CONFIGURE.rmb = true
ROBOT_CONFIGURE.priority = 10

---------------------------------------------------------------------------------------------------
-- ModRPC：客户端↔服务端通信
---------------------------------------------------------------------------------------------------
local RPC_NAMESPACE = "DST_ROBOT_PRO"

-- 客户端缓存：等待服务端回传设置时记住目标机器人
local _pending_robot = nil

-- 保鲜值→索引 的映射（用于RPC传输，因为RPC只能传整数）
local FRESHNESS_TO_IDX = {}
local IDX_TO_FRESHNESS = {}
for i, opt in ipairs(SettingsDef.FRESHNESS_OPTIONS) do
    FRESHNESS_TO_IDX[opt.value] = i
    IDX_TO_FRESHNESS[i] = opt.value
end

-- 服务端RPC：应用设置
AddModRPCHandler(RPC_NAMESPACE, "ApplySettings", function(player, robot, freshness_idx, harvest_materials, harvest_foods)
    if robot == nil or not robot:HasTag("storagerobot") then return end
    if player:GetDistanceSqToInst(robot) > 25 then return end

    local freshness_rate = IDX_TO_FRESHNESS[freshness_idx] or SettingsDef.DEFAULT_FRESHNESS

    if robot._robot_settings == nil then
        robot._robot_settings = {}
    end
    robot._robot_settings.freshness_rate = freshness_rate
    robot._robot_settings.harvest_materials = harvest_materials == 1
    robot._robot_settings.harvest_foods = harvest_foods == 1

    if robot._ApplyFreshnessToAllSlots then
        robot._ApplyFreshnessToAllSlots(robot)
    end

    print("[RobotSettings] Applied to " .. tostring(robot) ..
        ": freshness=" .. tostring(freshness_rate) ..
        " materials=" .. tostring(robot._robot_settings.harvest_materials) ..
        " foods=" .. tostring(robot._robot_settings.harvest_foods))
end)

-- 服务端RPC：客户端请求当前设置，服务端回传
AddModRPCHandler(RPC_NAMESPACE, "RequestSettings", function(player, robot)
    print("[RobotConfigure] Server received RequestSettings from "..tostring(player).." for "..tostring(robot))
    if robot == nil or not robot:HasTag("storagerobot") then
        print("[RobotConfigure] RequestSettings rejected: invalid robot")
        return
    end
    if player:GetDistanceSqToInst(robot) > 25 then
        print("[RobotConfigure] RequestSettings rejected: too far")
        return
    end

    local settings = robot._robot_settings or {}
    local freshness_idx = FRESHNESS_TO_IDX[settings.freshness_rate] or FRESHNESS_TO_IDX[SettingsDef.DEFAULT_FRESHNESS] or 4
    local mat = settings.harvest_materials and 1 or 0
    local food = settings.harvest_foods and 1 or 0

    SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "ReceiveSettings"),
        player.userid, freshness_idx, mat, food)
end)

-- 客户端RPC：接收服务端回传的设置并打开UI
-- 注意：Client RPC handler 没有 player 参数，直接接收数据参数
AddClientModRPCHandler(RPC_NAMESPACE, "ReceiveSettings", function(freshness_idx, harvest_materials, harvest_foods)
    print("[RobotConfigure] Client received ReceiveSettings: freshness="..tostring(freshness_idx).." mat="..tostring(harvest_materials).." food="..tostring(harvest_foods))
    local robot = _pending_robot
    _pending_robot = nil
    if robot == nil or not robot:IsValid() then
        print("[RobotConfigure] ERROR: no pending robot or robot invalid")
        return
    end

    local settings = {
        freshness_rate = IDX_TO_FRESHNESS[freshness_idx] or SettingsDef.DEFAULT_FRESHNESS,
        harvest_materials = harvest_materials == 1,
        harvest_foods = harvest_foods == 1,
    }

    local RobotSettingsScreen = GLOBAL.require("screens/robotsettingsscreen")
    local screen = RobotSettingsScreen(robot, settings, function(new_settings)
        local new_fidx = FRESHNESS_TO_IDX[new_settings.freshness_rate] or 4
        print("[RobotConfigure] Sending ApplySettings RPC: robot="..tostring(robot).." fidx="..tostring(new_fidx).." mat="..tostring(new_settings.harvest_materials and 1 or 0).." food="..tostring(new_settings.harvest_foods and 1 or 0))
        SendModRPCToServer(
            GetModRPC(RPC_NAMESPACE, "ApplySettings"),
            robot,
            new_fidx,
            new_settings.harvest_materials and 1 or 0,
            new_settings.harvest_foods and 1 or 0
        )
    end)
    GLOBAL.TheFrontEnd:PushScreen(screen)
end)

---------------------------------------------------------------------------------------------------
-- 右键地上的机器人→配置（需要装备控制器）
---------------------------------------------------------------------------------------------------
AddComponentAction("SCENE", "container", function(inst, doer, actions, right)
    if right and inst:HasTag("storagerobot") then
        local equipitem = doer.replica.inventory ~= nil
            and doer.replica.inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.HANDS) or nil
        if equipitem ~= nil and equipitem:HasTag("robot_controller") then
            table.insert(actions, ACTIONS.ROBOT_CONFIGURE)
        end
    end
end)

---------------------------------------------------------------------------------------------------
-- 客户端：执行配置Action时发送请求到服务端
---------------------------------------------------------------------------------------------------
if not GLOBAL.TheNet:IsDedicated() then
    AddComponentPostInit("playercontroller", function(self)
        print("[RobotConfigure] playercontroller PostInit, hooking DoAction")
        local _DoAction = self.DoAction
        if _DoAction then
            self.DoAction = function(self_inner, ba, ...)
                if ba then
                    print("[RobotConfigure] DoAction called, action="..tostring(ba.action).." target="..tostring(ba.target))
                end
                if ba and ba.action == ACTIONS.ROBOT_CONFIGURE and ba.target then
                    print("[RobotConfigure] Intercepted! Sending RequestSettings RPC for target="..tostring(ba.target))
                    _pending_robot = ba.target
                    SendModRPCToServer(
                        GetModRPC(RPC_NAMESPACE, "RequestSettings"),
                        ba.target
                    )
                    return
                end
                return _DoAction(self_inner, ba, ...)
            end
        else
            print("[RobotConfigure] WARNING: DoAction is nil!")
        end
    end)
end

-- 为ROBOT_CONFIGURE添加stategraph handler（使用短动作动画）
AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(ACTIONS.ROBOT_CONFIGURE, "doshortaction"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(ACTIONS.ROBOT_CONFIGURE, "doshortaction"))
