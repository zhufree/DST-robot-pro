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
icon_atlas = "images/modicon.xml"
icon = "modicon.tex"
-- dst兼容
dst_compatible = true
-- 是否是客户端mod
client_only_mod = false
-- 是否是所有客户端都需要安装
all_clients_require_mod = true
-- 饥荒api版本，固定填10
api_version = 10

-- mod的配置项（以下为新机器人的全局默认值，可通过机器人控制器对每个机器人单独设置）
configuration_options = {
    {
        name = "freshness_rate",
        label = "默认保鲜程度",
        hover = "新机器人背包中食物的默认保鲜速率倍数（可通过控制器对每个机器人单独调整）",
        options = {
            {description = "永不腐烂", data = 0},
            {description = "非常慢 (0.1x)", data = 0.1},
            {description = "较慢 (0.25x)", data = 0.25},
            {description = "慢 (0.5x)", data = 0.5},
            {description = "正常 (1x)", data = 1},
        },
        default = 0.5,
    },
}