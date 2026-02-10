local containers = GLOBAL.require("containers")
local params = containers.params

-- 3x3 机器人背包容器定义
local robot_container_params = {
    widget = {
        slotpos = {},
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = GLOBAL.Vector3(0, 200, 0),
        side_align_tip = 160,
        buttoninfo = {
            text = "设置",
            position = GLOBAL.Vector3(0, -165, 0),
            fn = function(inst, doer)
                if doer and doer.HUD then
                    -- 设置按钮回调，暂留空
                end
            end,
        },
    },
    type = "chest",
}

-- 生成3x3格子布局
for y = 2, 0, -1 do
    for x = 0, 2 do
        table.insert(robot_container_params.widget.slotpos,
            GLOBAL.Vector3(80 * x - 80, 80 * y - 80, 0))
    end
end

-- 需要同时用自定义名称和prefab名称注册，
-- 因为客户端container_replica通过prefab名称查找widget配置
params.robot_inventory = robot_container_params
params.storage_robot = robot_container_params
params.winona_storage_robot = robot_container_params
