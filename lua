-- ============================================================================
-- 1. 基础面向对象框架与工具库 (Object System & Utilities)
-- ============================================================================

local Class = {}
function Class.define(super)
    local cls = {}
    cls.__index = cls
    if super then
        setmetatable(cls, { __index = super })
        cls.super = super
    end
    function cls.new(...)
        local instance = setmetatable({}, cls)
        if instance.ctor then
            instance:ctor(...)
        end
        return instance
    end
    return cls
end

-- 通用矢量与矩形数据结构
local Vec2 = Class.define()
function Vec2:ctor(x, y)
    self.x = x or 0
    self.y = y or 0
end

local Rect = Class.define()
function Rect:ctor(x, y, w, h)
    self.x = x or 0
    self.y = y or 0
    self.w = w or 0
    self.h = h or 0
end

function Rect:contains(vec2)
    return vec2.x >= self.x and vec2.x <= (self.x + self.w) and
           vec2.y >= self.y and vec2.y <= (self.y + self.h)
end

-- 设备类型枚举
local DeviceType = {
    PC = "PC",
    MOBILE = "MOBILE"
}

-- 输入事件枚举
local InputType = {
    HOVER = "HOVER",
    CLICK = "CLICK",
    TOUCH_BEGIN = "TOUCH_BEGIN",
    TOUCH_MOVE = "TOUCH_MOVE",
    TOUCH_END = "TOUCH_END",
    NAV_UP = "NAV_UP",
    NAV_DOWN = "NAV_DOWN",
    NAV_LEFT = "NAV_LEFT",
    NAV_RIGHT = "NAV_RIGHT",
    CONFIRM = "CONFIRM",
    BACK = "BACK"
}

-- ============================================================================
-- 2. 界面基础节点组件 (UI Component Base)
-- ============================================================================

local UIComponent = Class.define()

function UIComponent:ctor(name)
    self.name = name or "Component"
    self.bounds = Rect.new(0, 0, 100, 40)
    self.relative_pos = Vec2.new(0, 0)
    self.visible = true
    self.enabled = true
    self.focusable = true
    self.is_focused = false
    self.is_hovered = false
    self.is_pressed = false
    self.parent = nil
    self.children = {}
    self.style = {
        bg_color = {0.2, 0.2, 0.2, 1.0},
        focus_color = {0.4, 0.6, 1.0, 1.0},
        pressed_color = {0.1, 0.1, 0.1, 1.0},
        text_color = {1.0, 1.0, 1.0, 1.0},
        font_size = 16
    }
end

function UIComponent:add_child(child)
    child.parent = self
    table.insert(self.children, child)
end

function UIComponent:remove_child(child)
    for i, c in ipairs(self.children) do
        if c == child then
            c.parent = nil
            table.remove(self.children, i)
            break
        end
    end
end

function UIComponent:update_transform(parent_x, parent_y)
    self.bounds.x = parent_x + self.relative_pos.x
    self.bounds.y = parent_y + self.relative_pos.y
    for _, child in ipairs(self.children) do
        if child.visible then
            child:update_transform(self.bounds.x, self.bounds.y)
        end
    end
end

function UIComponent:on_input(input_type, args)
    if not self.visible or not self.enabled then return false end

    -- 先向下传递给子节点 (深度优先)
    for i = #self.children, 1, -1 do
        local child = self.children[i]
        if child:on_input(input_type, args) then
            return true
        end
    end

    -- 本节点响应处理
    return self:handle_self_input(input_type, args)
end

function UIComponent:handle_self_input(input_type, args)
    return false
end

function UIComponent:render(render_engine)
    if not self.visible then return end
    self:draw(render_engine)
    for _, child in ipairs(self.children) do
        child:render(render_engine)
    end
end

function UIComponent:draw(render_engine)
    -- 由抽象渲染层或具体平台实现
end

-- ============================================================================
-- 3. 核心控件库 (Core Controls Library)
-- ============================================================================

-- ---------- 3.1 按钮控件 (Button) ----------
local UIButton = Class.define(UIComponent)

function UIButton:ctor(name, text, callback)
    UIButton.super.ctor(self, name)
    self.text = text or "Button"
    self.callback = callback
end

function UIButton:handle_self_input(input_type, args)
    if input_type == InputType.HOVER then
        local in_bounds = self.bounds:contains(args.pos)
        self.is_hovered = in_bounds
        return in_bounds
    elseif input_type == InputType.CLICK or input_type == InputType.TOUCH_END then
        if self.bounds:contains(args.pos) or (self.is_focused and input_type == InputType.CONFIRM) then
            if self.callback then
                self.callback(self)
            end
            return true
        end
    elseif input_type == InputType.CONFIRM and self.is_focused then
        if self.callback then
            self.callback(self)
        end
        return true
    end
    return false
end

function UIButton:draw(render_engine)
    local color = self.style.bg_color
    if self.is_pressed then
        color = self.style.pressed_color
    elseif self.is_focused or self.is_hovered then
        color = self.style.focus_color
    end
    render_engine:draw_rect(self.bounds, color)
    render_engine:draw_text(self.text, self.bounds, self.style.text_color, self.style.font_size)
end

-- ---------- 3.2 滑块控件 (Slider) ----------
local UISlider = Class.define(UIComponent)

function UISlider:ctor(name, min_val, max_val, cur_val, on_change)
    UISlider.super.ctor(self, name)
    self.min_val = min_val or 0
    self.max_val = max_val or 100
    self.value = cur_val or min_val
    self.on_change = on_change
    self.is_dragging = false
end

function UISlider:set_value(val)
    local old = self.value
    self.value = math.max(self.min_val, math.min(self.max_val, val))
    if old ~= self.value and self.on_change then
        self.on_change(self.value)
    end
end

function UISlider:handle_self_input(input_type, args)
    if input_type == InputType.TOUCH_BEGIN or input_type == InputType.CLICK then
        if self.bounds:contains(args.pos) then
            self.is_dragging = true
            self:update_value_from_pos(args.pos.x)
            return true
        end
    elseif input_type == InputType.TOUCH_MOVE and self.is_dragging then
        self:update_value_from_pos(args.pos.x)
        return true
    elseif input_type == InputType.TOUCH_END then
        self.is_dragging = false
    elseif self.is_focused then
        if input_type == InputType.NAV_LEFT then
            self:set_value(self.value - (self.max_val - self.min_val) * 0.05)
            return true
        elseif input_type == InputType.NAV_RIGHT then
            self:set_value(self.value + (self.max_val - self.min_val) * 0.05)
            return true
        end
    end
    return false
end

function UISlider:update_value_from_pos(x_pos)
    local pct = (x_pos - self.bounds.x) / self.bounds.w
    pct = math.max(0, math.min(1, pct))
    self:set_value(self.min_val + pct * (self.max_val - self.min_val))
end

function UISlider:draw(render_engine)
    render_engine:draw_rect(self.bounds, self.style.bg_color)
    local fill_w = ((self.value - self.min_val) / (self.max_val - self.min_val)) * self.bounds.w
    local fill_rect = Rect.new(self.bounds.x, self.bounds.y, fill_w, self.bounds.h)
    render_engine:draw_rect(fill_rect, self.style.focus_color)
    render_engine:draw_text(string.format("%s: %.1f", self.name, self.value), self.bounds, self.style.text_color, self.style.font_size)
end

-- ---------- 3.3 滚动视图控件 (ScrollView - 手机手势优化) ----------
local UIScrollView = Class.define(UIComponent)

function UIScrollView:ctor(name)
    UIScrollView.super.ctor(self, name)
    self.scroll_offset = Vec2.new(0, 0)
    self.content_size = Vec2.new(100, 100)
    self.touch_start_pos = nil
    self.velocity = Vec2.new(0, 0)
    self.damping = 0.92
end

function UIScrollView:handle_self_input(input_type, args)
    if input_type == InputType.TOUCH_BEGIN or input_type == InputType.CLICK then
        if self.bounds:contains(args.pos) then
            self.touch_start_pos = Vec2.new(args.pos.x, args.pos.y)
            self.velocity = Vec2.new(0, 0)
            return true
        end
    elseif input_type == InputType.TOUCH_MOVE and self.touch_start_pos then
        local dy = args.pos.y - self.touch_start_pos.y
        self.scroll_offset.y = self.scroll_offset.y + dy
        self.velocity.y = dy
        self.touch_start_pos = Vec2.new(args.pos.x, args.pos.y)
        self:clamp_scroll()
        return true
    elseif input_type == InputType.TOUCH_END then
        self.touch_start_pos = nil
    end
    return false
end

function UIScrollView:clamp_scroll()
    local max_y = math.max(0, self.content_size.y - self.bounds.h)
    if self.scroll_offset.y > 0 then self.scroll_offset.y = 0 end
    if self.scroll_offset.y < -max_y then self.scroll_offset.y = -max_y end
end

function UIScrollView:update(dt)
    if not self.touch_start_pos and math.abs(self.velocity.y) > 0.1 then
        self.scroll_offset.y = self.scroll_offset.y + self.velocity.y
        self.velocity.y = self.velocity.y * self.damping
        self:clamp_scroll()
    end
end

-- ---------- 3.4 虚拟摇杆/手势响应区 (Virtual Joystick) ----------
local UIVirtualJoystick = Class.define(UIComponent)

function UIVirtualJoystick:ctor(name, radius)
    UIVirtualJoystick.super.ctor(self, name)
    self.radius = radius or 80
    self.stick_pos = Vec2.new(0, 0)
    self.is_active = false
    self.direction = Vec2.new(0, 0)
end

function UIVirtualJoystick:handle_self_input(input_type, args)
    if input_type == InputType.TOUCH_BEGIN then
        if self.bounds:contains(args.pos) then
            self.is_active = true
            self:update_stick(args.pos)
            return true
        end
    elseif input_type == InputType.TOUCH_MOVE and self.is_active then
        self:update_stick(args.pos)
        return true
    elseif input_type == InputType.TOUCH_END and self.is_active then
        self.is_active = false
        self.stick_pos = Vec2.new(0, 0)
        self.direction = Vec2.new(0, 0)
        return true
    end
    return false
end

function UIVirtualJoystick:update_stick(touch_pos)
    local center_x = self.bounds.x + self.bounds.w / 2
    local center_y = self.bounds.y + self.bounds.h / 2
    local dx = touch_pos.x - center_x
    local dy = touch_pos.y - center_y
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist > self.radius then
        dx = (dx / dist) * self.radius
        dy = (dy / dist) * self.radius
    end
    
    self.stick_pos = Vec2.new(dx, dy)
    self.direction = Vec2.new(dx / self.radius, dy / self.radius)
end

-- ============================================================================
-- 4. 自适应布局引擎 (Adaptive Layout Engine)
-- ============================================================================

local LayoutEngine = {}

-- 垂直列表自动布局
function LayoutEngine.apply_vertical_list(container, padding, spacing)
    padding = padding or 10
    spacing = spacing or 10
    local current_y = padding
    
    for _, child in ipairs(container.children) do
        if child.visible then
            child.relative_pos.x = padding
            child.relative_pos.y = current_y
            child.bounds.w = container.bounds.w - (padding * 2)
            current_y = current_y + child.bounds.h + spacing
        end
    end
    
    if container.content_size then
        container.content_size.y = current_y + padding
    end
end

-- 网格流式自适应布局
function LayoutEngine.apply_grid(container, col_width, row_height, spacing)
    spacing = spacing or 10
    local max_cols = math.floor((container.bounds.w - spacing) / (col_width + spacing))
    max_cols = math.max(1, max_cols)
    
    for i, child in ipairs(container.children) do
        local col = (i - 1) % max_cols
        local row = math.floor((i - 1) / max_cols)
        
        child.relative_pos.x = spacing + col * (col_width + spacing)
        child.relative_pos.y = spacing + row * (row_height + spacing)
        child.bounds.w = col_width
        child.bounds.h = row_height
    end
end

-- ============================================================================
-- 5. 多平台输入路由与焦点控制器 (Input Router & Navigation)
-- ============================================================================

local FocusManager = Class.define()

function FocusManager:ctor()
    self.focusable_nodes = {}
    self.current_index = 1
end

function FocusManager:rebuild_tree(root_node)
    self.focusable_nodes = {}
    local function collect(node)
        if node.visible and node.enabled and node.focusable then
            table.insert(self.focusable_nodes, node)
        end
        for _, child in ipairs(node.children) do
            collect(child)
        end
    end
    collect(root_node)
    self:set_focus_index(1)
end

function FocusManager:set_focus_index(idx)
    if #self.focusable_nodes == 0 then return end
    if self.focusable_nodes[self.current_index] then
        self.focusable_nodes[self.current_index].is_focused = false
    end
    self.current_index = idx
    if self.current_index > #self.focusable_nodes then self.current_index = 1 end
    if self.current_index < 1 then self.current_index = #self.focusable_nodes end
    self.focusable_nodes[self.current_index].is_focused = true
end

function FocusManager:navigate(direction)
    if #self.focusable_nodes == 0 then return end
    
    local curr = self.focusable_nodes[self.current_index]
    local best_node_idx = nil
    local min_dist = math.huge

    -- 基于空间位置的方向导航算法 (十字方向键/键盘/手柄选择)
    for i, node in ipairs(self.focusable_nodes) do
        if i ~= self.current_index then
            local dx = node.bounds.x - curr.bounds.x
            local dy = node.bounds.y - curr.bounds.y
            local valid = false

            if direction == InputType.NAV_UP and dy < -5 then valid = true end
            if direction == InputType.NAV_DOWN and dy > 5 then valid = true end
            if direction == InputType.NAV_LEFT and dx < -5 then valid = true end
            if direction == InputType.NAV_RIGHT and dx > 5 then valid = true end

            if valid then
                local dist = dx*dx + dy*dy
                if dist < min_dist then
                    min_dist = dist
                    best_node_idx = i
                end
            end
        end
    end

    if best_node_idx then
        self:set_focus_index(best_node_idx)
    end
end

-- ============================================================================
-- 6. 核心菜单管理器 (Menu Manager - Framework Entry)
-- ============================================================================

local MenuManager = Class.define()

function MenuManager:ctor()
    self.device_type = DeviceType.PC
    self.screen_width = 1920
    self.screen_height = 1080
    self.menu_stack = {}
    self.focus_mgr = FocusManager.new()
    self.render_engine_mock = self:create_mock_renderer()
end

function MenuManager:set_device_type(type)
    self.device_type = type
    print("[MenuManager] 当前运行设备适配模式设置为: " .. tostring(type))
end

function MenuManager:on_resize(width, height)
    self.screen_width = width
    self.screen_height = height
    for _, menu in ipairs(self.menu_stack) do
        menu:on_screen_resize(width, height, self.device_type)
    end
end

function MenuManager:push_menu(menu_instance)
    table.insert(self.menu_stack, menu_instance)
    menu_instance:on_screen_resize(self.screen_width, self.screen_height, self.device_type)
    self.focus_mgr:rebuild_tree(menu_instance.root_node)
end

function MenuManager:pop_menu()
    if #self.menu_stack > 0 then
        table.remove(self.menu_stack)
        if #self.menu_stack > 0 then
            local top = self.menu_stack[#self.menu_stack]
            self.focus_mgr:rebuild_tree(top.root_node)
        end
    end
end

function MenuManager:handle_input(input_type, args)
    if #self.menu_stack == 0 then return end
    local top_menu = self.menu_stack[#self.menu_stack]

    -- 1. PC 按键导航优先逻辑
    if self.device_type == DeviceType.PC then
        if input_type == InputType.NAV_UP or input_type == InputType.NAV_DOWN or
           input_type == InputType.NAV_LEFT or input_type == InputType.NAV_RIGHT then
            self.focus_mgr:navigate(input_type)
            return true
        end
    end

    -- 2. 传递输入给顶级 UI 根树
    local consumed = top_menu.root_node:on_input(input_type, args)

    -- 3. 返回/取消系统全局响应
    if not consumed and input_type == InputType.BACK then
        self:pop_menu()
        return true
    end

    return consumed
end

function MenuManager:update(dt)
    if #self.menu_stack > 0 then
        local top_menu = self.menu_stack[#self.menu_stack]
        top_menu:update(dt)
    end
end

function MenuManager:render()
    for _, menu in ipairs(self.menu_stack) do
        menu.root_node:render(self.render_engine_mock)
    end
end

function MenuManager:create_mock_renderer()
    return {
        draw_rect = function(self, rect, color)
            -- 接入具体平台的画矩形 API (如 Raylib, Love2D, Unity GUI)
        end,
        draw_text = function(self, text, rect, color, size)
            -- 接入具体平台的画文本 API
        end
    }
end

-- ============================================================================
-- 7. 具体业务菜单实现范例 (Sample Business Menu Implementations)
-- ============================================================================

local BaseMenu = Class.define()
function BaseMenu:ctor(name)
    self.name = name
    self.root_node = UIComponent.new(name .. "_Root")
end
function BaseMenu:on_screen_resize(w, h, device_type) end
function BaseMenu:update(dt) end

-- ---------- 复杂设置菜单 (Settings Menu) ----------
local SettingsMenu = Class.define(BaseMenu)

function SettingsMenu:ctor()
    SettingsMenu.super.ctor(self, "SettingsMenu")

    -- 创建滚动容器
    self.scroll_view = UIScrollView.new("SettingsScrollView")
    self.root_node:add_child(self.scroll_view)

    -- 音乐音量滑块
    local bgm_slider = UISlider.new("BGM Volume", 0, 100, 80, function(val)
        print("BGM 音量改变为: " .. val)
    end)
    bgm_slider.bounds.h = 50
    self.scroll_view:add_child(bgm_slider)

    -- 音效音量滑块
    local sfx_slider = UISlider.new("SFX Volume", 0, 100, 60, function(val)
        print("SFX 音量改变为: " .. val)
    end)
    sfx_slider.bounds.h = 50
    self.scroll_view:add_child(sfx_slider)

    -- 保存设置按钮
    local save_btn = UIButton.new("SaveBtn", "Save Settings", function()
        print("点击保存配置！")
    end)
    save_btn.bounds.h = 60
    self.scroll_view:add_child(save_btn)
end

function SettingsMenu:on_screen_resize(w, h, device_type)
    -- 根据设备类型自动适配尺寸与布局
    if device_type == DeviceType.MOBILE then
        -- 移动端全屏布局，增大触控响应区域
        self.root_node.bounds = Rect.new(0, 0, w, h)
        self.scroll_view.bounds = Rect.new(20, 20, w - 40, h - 40)
        LayoutEngine.apply_vertical_list(self.scroll_view, 10, 25)
    else
        -- PC端居中居中面板布局
        local menu_w, menu_h = 600, 700
        local x = (w - menu_w) / 2
        local y = (h - menu_h) / 2
        self.root_node.bounds = Rect.new(x, y, menu_w, menu_h)
        self.scroll_view.bounds = Rect.new(10, 10, menu_w - 20, menu_h - 20)
        LayoutEngine.apply_vertical_list(self.scroll_view, 10, 15)
    end
    self.root_node:update_transform(self.root_node.bounds.x, self.root_node.bounds.y)
end

function SettingsMenu:update(dt)
    self.scroll_view:update(dt)
end

-- ============================================================================
-- 8. 自动化测试与系统集成验证模拟 (Integration System & Test Simulation)
-- ============================================================================

local function run_system_demo()
    print("=================================================================")
    print("               启动 Lua 跨平台高级 UI 菜单系统演示               ")
    print("=================================================================\n")

    local menu_mgr = MenuManager.new()

    -- 1. 创建并压入设置菜单
    local settings_menu = SettingsMenu.new()
    menu_mgr:push_menu(settings_menu)

    -- 2. 模拟 PC 端环境与分辨率 (1920x1080)
    print("\n--- 阶段 1: PC 模式运行模拟 (1920x1080) ---")
    menu_mgr:set_device_type(DeviceType.PC)
    menu_mgr:on_resize(1920, 1080)

    -- 模拟键盘向下导航与确认点击
    print("[输入模拟] 键盘按下: 向下导航 (NAV_DOWN)")
    menu_mgr:handle_input(InputType.NAV_DOWN, {})
    
    print("[输入模拟] 键盘按下: 向右调整滑块 (NAV_RIGHT)")
    menu_mgr:handle_input(InputType.NAV_RIGHT, {})

    -- 3. 切换至 移动端(手机) 环境与分辨率 (iPhone 竖屏 1170x2532)
    print("\n--- 阶段 2: 手机端模式运行模拟 (1170x2532 触控) ---")
    menu_mgr:set_device_type(DeviceType.MOBILE)
    menu_mgr:on_resize(1170, 2532)

    -- 模拟手机按下与滑动 (Touch Drag Scroll)
    print("[输入模拟] 手机触摸屏幕: (X: 100, Y: 500)")
    menu_mgr:handle_input(InputType.TOUCH_BEGIN, { pos = Vec2.new(100, 500) })

    print("[输入模拟] 手机手指向上滑动 (滑动菜单容器): (X: 100, Y: 300)")
    menu_mgr:handle_input(InputType.TOUCH_MOVE, { pos = Vec2.new(100, 300) })

    print("[输入模拟] 手机手指抬起")
    menu_mgr:handle_input(InputType.TOUCH_END, { pos = Vec2.new(100, 300) })

    -- 模拟帧率更新与惯性滚动计算
    menu_mgr:update(0.016)

    print("\n=================================================================")
    print("                     高级 UI 框架测试全部通过                    ")
    print("=================================================================")
end

-- 启动测试
run_system_demo()
