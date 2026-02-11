local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"
local Image = require "widgets/image"
local TEMPLATES = require "widgets/redux/templates"

local SettingsDef = require "robot_settings_def"

local FONT = CHATFONT
local FONT_SIZE = 28
local TITLE_SIZE = 36
local PANEL_W = 480
local PANEL_H = 420

local RobotSettingsScreen = Class(Screen, function(self, robot, initial_settings, callback_fn)
    Screen._ctor(self, "RobotSettingsScreen")

    self.robot = robot
    self.callback_fn = callback_fn

    -- 使用服务端回传的设置作为初始值
    self.settings = {}
    if initial_settings then
        for k, v in pairs(initial_settings) do
            self.settings[k] = v
        end
    else
        self.settings.freshness_rate = SettingsDef.DEFAULT_FRESHNESS
        for _, cat in ipairs(SettingsDef.HARVEST_CATEGORIES) do
            self.settings["harvest_" .. cat.id] = cat.default
        end
    end

    -- 黑色半透明背景
    self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVAnchor(ANCHOR_MIDDLE)
    self.black:SetHAnchor(ANCHOR_MIDDLE)
    self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
    self.black:SetTint(0, 0, 0, 0.6)
    self.black.OnMouseButton = function() self:Close() return true end

    -- 主面板
    self.root = self:AddChild(Widget("root"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    -- 面板背景
    self.panel = self.root:AddChild(TEMPLATES.RectangleWindow(PANEL_W, PANEL_H))

    -- 标题
    self.title = self.root:AddChild(Text(FONT, TITLE_SIZE, "机器人设置"))
    self.title:SetPosition(0, PANEL_H / 2 - 20)
    self.title:SetColour(1, 1, 1, 1)

    local y = PANEL_H / 2 - 70

    -- 保鲜程度
    local freshness_title = self.root:AddChild(Text(FONT, FONT_SIZE, "保鲜程度:"))
    freshness_title:SetPosition(-100, y)
    freshness_title:SetColour(0.9, 0.8, 0.5, 1)

    self.freshness_idx = 1
    for i, opt in ipairs(SettingsDef.FRESHNESS_OPTIONS) do
        if opt.value == self.settings.freshness_rate then
            self.freshness_idx = i
            break
        end
    end

    self.freshness_label = self.root:AddChild(Text(FONT, FONT_SIZE,
        SettingsDef.FRESHNESS_OPTIONS[self.freshness_idx].label))
    self.freshness_label:SetPosition(100, y)
    self.freshness_label:SetColour(1, 1, 1, 1)

    -- 保鲜左右箭头
    local arrow_left = self.root:AddChild(ImageButton(
        "images/global_redux.xml", "arrow2_left.tex",
        "arrow2_left_over.tex", nil, nil, nil, {0.4, 0.4}))
    arrow_left:SetPosition(20, y)
    arrow_left:SetOnClick(function() self:ChangeFreshness(-1) end)

    local arrow_right = self.root:AddChild(ImageButton(
        "images/global_redux.xml", "arrow2_right.tex",
        "arrow2_right_over.tex", nil, nil, nil, {0.4, 0.4}))
    arrow_right:SetPosition(180, y)
    arrow_right:SetOnClick(function() self:ChangeFreshness(1) end)

    y = y - 60

    -- 分隔线文字
    local harvest_title = self.root:AddChild(Text(FONT, FONT_SIZE, "自动采集类别:"))
    harvest_title:SetPosition(0, y)
    harvest_title:SetColour(0.9, 0.8, 0.5, 1)

    y = y - 50

    -- 采集类别开关
    self.category_buttons = {}
    for _, cat in ipairs(SettingsDef.HARVEST_CATEGORIES) do
        local key = "harvest_" .. cat.id
        local enabled = self.settings[key]
        if enabled == nil then enabled = cat.default end

        -- 类别名称
        local cat_label = self.root:AddChild(Text(FONT, FONT_SIZE, cat.name))
        cat_label:SetPosition(-120, y)
        cat_label:SetColour(1, 1, 1, 1)

        -- 描述
        local cat_desc = self.root:AddChild(Text(FONT, 20, cat.desc))
        cat_desc:SetPosition(40, y)
        cat_desc:SetColour(0.7, 0.7, 0.7, 1)

        y = y - 30

        -- 开关按钮
        local btn = self.root:AddChild(ImageButton(
            "images/global_redux.xml", "button_carny_long_normal.tex",
            "button_carny_long_hover.tex", "button_carny_long_disabled.tex",
            "button_carny_long_down.tex"))
        btn:SetPosition(-120, y)
        btn:SetScale(0.4, 0.5)
        btn:SetText(enabled and "开启" or "关闭")
        btn:SetFont(FONT)
        btn:SetTextSize(40)

        local cat_id = cat.id
        btn:SetOnClick(function()
            self.settings[key] = not self.settings[key]
            btn:SetText(self.settings[key] and "开启" or "关闭")
        end)

        self.category_buttons[key] = btn

        y = y - 50
    end

    -- 确认按钮
    local confirm_btn = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:Confirm() end, "确认", {120, 40}))
    confirm_btn:SetPosition(-90, -PANEL_H / 2 + 40)

    -- 取消按钮
    local cancel_btn = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:Close() end, "取消", {120, 40}))
    cancel_btn:SetPosition(90, -PANEL_H / 2 + 40)
end)

function RobotSettingsScreen:ChangeFreshness(delta)
    self.freshness_idx = self.freshness_idx + delta
    if self.freshness_idx < 1 then
        self.freshness_idx = #SettingsDef.FRESHNESS_OPTIONS
    elseif self.freshness_idx > #SettingsDef.FRESHNESS_OPTIONS then
        self.freshness_idx = 1
    end
    local opt = SettingsDef.FRESHNESS_OPTIONS[self.freshness_idx]
    self.settings.freshness_rate = opt.value
    self.freshness_label:SetString(opt.label)
end

function RobotSettingsScreen:Confirm()
    print("[RobotSettingsScreen] Confirm clicked, settings:")
    for k, v in pairs(self.settings) do
        print("  " .. tostring(k) .. " = " .. tostring(v))
    end
    if self.callback_fn then
        self.callback_fn(self.settings)
    end
    TheFrontEnd:PopScreen(self)
end

function RobotSettingsScreen:Close()
    TheFrontEnd:PopScreen(self)
end

function RobotSettingsScreen:OnControl(control, down)
    if RobotSettingsScreen._base.OnControl(self, control, down) then
        return true
    end
    if not down and control == CONTROL_CANCEL then
        self:Close()
        return true
    end
end

function RobotSettingsScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    return TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK
end

return RobotSettingsScreen
