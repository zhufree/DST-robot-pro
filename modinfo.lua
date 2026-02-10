-- 名称
name = "瓦器人增强"
-- 描述
description = "机器人增强"
-- 作者
author = "zhufree"
-- 版本
version = "0.1"
-- klei官方论坛地址，为空则默认是工坊的地址
forumthread = ""
-- modicon 下一篇再介绍怎么创建的
-- icon_atlas = "images/modicon.xml"
-- icon = "modicon.tex"
-- dst兼容
dst_compatible = true
-- 是否是客户端mod
client_only_mod = false
-- 是否是所有客户端都需要安装
all_clients_require_mod = true
-- 饥荒api版本，固定填10
api_version = 10

-- 辅助函数：生成开关配置项
local function BoolOption(name, label, hover, default_val)
    return {
        name = name,
        label = label,
        hover = hover,
        options = {
            {description = "关闭", data = false},
            {description = "开启", data = true},
        },
        default = default_val,
    }
end

-- mod的配置项
configuration_options = {
    {
        name = "freshness_rate",
        label = "保鲜程度",
        hover = "机器人背包中食物的保鲜速率倍数，越小保鲜效果越好，0为永不腐烂",
        options = {
            {description = "永不腐烂", data = 0},
            {description = "非常慢 (0.1x)", data = 0.1},
            {description = "较慢 (0.25x)", data = 0.25},
            {description = "慢 (0.5x)", data = 0.5},
            {description = "正常 (1x)", data = 1},
        },
        default = 0.5,
    },

    BoolOption("auto_harvest",          "自动采集",     "是否启用机器人自动采集功能",   true),
    BoolOption("harvest_grass",         "采集草",       "自动采集草丛",                 true),
    BoolOption("harvest_sapling",       "采集树枝",     "自动采集树苗",                 true),
    BoolOption("harvest_berries",       "采集浆果",     "自动采集浆果丛",               false),
    BoolOption("harvest_berries_juicy", "采集多汁浆果", "自动采集多汁浆果丛",           false),
    BoolOption("harvest_mushroom",      "采集蘑菇",     "自动采集地表蘑菇",             false),
    BoolOption("harvest_reeds",         "采集芦苇",     "自动采集芦苇",                 false),
    BoolOption("harvest_carrot",        "采集胡萝卜",   "自动采集野外胡萝卜",           false),
    BoolOption("harvest_cave_banana",   "采集洞穴香蕉", "自动采集洞穴香蕉树",           false),
    BoolOption("harvest_lichen",        "采集地衣",     "自动采集洞穴地衣",             false),
    BoolOption("harvest_rock_avocado",  "采集石果",     "自动采集月球岛石果灌木",       false),
    BoolOption("harvest_monkeytail",    "采集猴尾草",   "自动采集猴尾草",               false),
}