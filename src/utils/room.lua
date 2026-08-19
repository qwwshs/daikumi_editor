--[[
    模块名: room
    描述: 房间/场景管理系统，实现 object/container/group/room 四层架构
    作者: qwwshs
    依赖: 无

    架构说明:
    - object: 基础对象，所有实体的基类
    - container: 容器，可包含子对象（objects）和子组（groups）
    - group: 容器变体，用于组合多个对象，不支持嵌套房间
    - room: 场景管理器，支持多场景切换

    生命周期方法（由 room 调度）:
    - load: 加载
    - update(dt): 每帧更新
    - draw: 绘制
    - keypressed(key): 键盘按下
    - keyreleased(key): 键盘释放
    - mousepressed(x, y, button): 鼠标按下
    - mousereleased(x, y, button): 鼠标释放
    - wheelmoved(x, y): 鼠标滚轮
    - textinput(input): 文本输入
    - resize(w, h): 窗口大小变化
    - quit: 退出
]]

-- ============================================================
-- object: 基础对象
-- ============================================================
object = {}

--- 创建新的基础对象
-- @tparam string __name 对象名称
-- @treturn table 新对象
function object:new(__name)
    local obj = {__name = "",__type = ""}
    if type(__name) == 'string' then obj.__name = __name end
    setmetatable(obj, object)
    return obj
end

-- ============================================================
-- container: 容器，可包含子对象和子组
-- ============================================================
container = object:new('')

container.objects = {}  -- 子对象列表
container.groups = {}   -- 子组列表
container.__index = container

--- 创建新的容器
-- @tparam string __name 容器名称
-- @treturn table 新容器
function container:new(__name)
    if type(__name) ~= "string" then return end
    local c = object:new(__name)
    c.objects = {}
    c.groups = {}
    setmetatable(c,container)
    return c
end

--- 添加子对象
-- @tparam table obj 子对象
function container:addObject(obj)
    if type(obj) ~= "table" then return end
    table.insert(self.objects,obj)
end

--- 按名称删除子对象
-- @tparam string __name 子对象名称
function container:deleteObject(__name)
    if type(__name) ~= "string" then return end
    for i,v in ipairs(self.objects) do
        if v.__name == __name then
            table.remove(self.objects,i)
            break
        end
    end
end

--- 按名称获取子对象
-- @tparam string __name 子对象名称
-- @treturn table|nil 子对象
function container:getObject(__name)
    if type(__name) ~= "string" then return end
    for _,v in ipairs(self.objects) do
        if v.__name == __name then
            return v
        end
    end
    return nil
end

--- 获取指定类型的所有子对象
-- @tparam string isType 类型名
-- @treturn table 子对象列表
function container:getAllTypeObject(isType)
    if type(isType) ~= "string" then return end
    local tab = {}
    for _,v in ipairs(self.objects) do
        if v.__type == isType then
            table.insert(tab,v)
        end
    end
    return tab
end

--- 获取所有子对象
-- @treturn table 子对象列表
function container:getAllObject()
    return self.objects
end

--- 对所有子对象调用指定方法
-- @tparam string methodName 方法名
-- @param ... 传递给方法的参数
function container:callAllObject(methodName,...)
    for _, obj in ipairs(self.objects) do
        if obj[methodName] then
            obj[methodName](obj,...)
        end
    end
end


--- 添加子组
-- @tparam table group 子组
function container:addGroup(group)
    if not group then return end
    if type(group) ~= "table" then return end
    table.insert(self.groups,group)
end

--- 按名称删除子组
-- @tparam string __name 子组名称
function container:deleteGroup(__name)
    if type(__name) ~= "string" then return end
    for i,v in ipairs(self.groups) do
        if v.__name == __name then
            table.remove(self.groups,i)
            break
        end
    end
end

--- 按名称获取子组
-- @tparam string __name 子组名称
-- @treturn table|nil 子组
function container:getGroup(__name)
    if type(__name) ~= "string" then return end
    for _,v in ipairs(self.groups) do
        if v.__name == __name then
            return v
        end
    end
    return nil
end

--- 获取所有子组
-- @treturn table 子组列表
function container:getAllGroup()
    return self.groups
end

--- 对所有子组调用指定方法
-- @tparam string methodName 方法名
-- @param ... 传递给方法的参数
function container:callAllGroup(methodName,...)
    for _, group in ipairs(self.groups) do
        if group[methodName] then
            group[methodName](group,...)
        end
    end
end

--- 获取指定类型的所有子组
-- @tparam string isType 类型名
-- @treturn table 子组列表
function container:getAllTypeGroup(isType)
    if type(isType) ~= "string" then return end
    local tab = {}
    for _,v in ipairs(self.groups) do
        if v.__type == isType then
            table.insert(tab,v)
        end
    end
    return tab
end

--- 调用容器的方法：对所有子对象和子组调用指定方法，然后调用当前房间的方法
-- @tparam string methodName 方法名
-- @param ... 传递给方法的参数
function container:__call(methodName,...)
    self:callAllObject(methodName,...)
    self:callAllGroup(methodName,...)

    if not self.rooms then return end
    if not self.rooms[self.__type] then return end
    if type(self.rooms[self.__type][methodName]) ~= 'function' then return end
    self.rooms[self.__type][methodName](self.rooms[self.__type],...)
end


-- ============================================================
-- group: 容器变体，用于组合多个对象
-- ============================================================
group = container:new('')
group.__index = group

--- group 的方法调用：仅对子对象和子组调用（不支持房间切换）
function group:__call(methodName,...)
    self:callAllObject(methodName,...)
    self:callAllGroup(methodName,...)
end

--- 创建新的 group
-- @tparam string __name group 名称
-- @treturn table 新 group
function group:new(__name)
    local g = {__name = '',objects = {},groups = {}}

    if type(__name) == 'string' then g.__name = __name end

    setmetatable(g,group)
    return g
end

-- ============================================================
-- room: 场景管理器，支持多场景切换
-- ============================================================
room = container:new('main')
room.rooms = {}  -- 已注册的房间表 { [name] = roomObj }
room.__index = room

--- room 的方法调用：对子对象和子组调用，然后对当前活跃房间调用
function room:__call(methodName,...)
    self:callAllObject(methodName,...)
    self:callAllGroup(methodName,...)

    if not self.rooms or not self.rooms[self.__type] or not self.rooms[self.__type][methodName] then return end

    self.rooms[self.__type][methodName](self.rooms[self.__type],...)
end

--- 创建新的 room
-- @tparam string __name room 名称
-- @treturn table 新 room
function room:new(__name)
    if not __name then return end
    local r = container:new(__name)
    r.rooms = {}
    setmetatable(r, room)
    return r
end

--- 设置当前活跃房间
-- @tparam string __name 房间名称
function room:load(__name)
    if not __name then return end
    self.__type = __name
end

--- 注册一个房间
-- @tparam table room 房间对象
function room:addRoom(room)
    self.rooms[room.__name] = room
end

--- 注销一个房间
-- @tparam table room 房间对象
function room:deleteRoom(room)
    self.rooms[room.__name] = nil
end

--- 按名称获取房间
-- @tparam string __name 房间名称
-- @treturn table|nil 房间对象
function room:getRoom(__name)
    return self.rooms[__name]
end

--- 切换到指定房间
-- @tparam string __name 房间名称
-- @param ... 传递给房间 load 方法的参数
function room:to(__name,...)
    if self.rooms[__name] then
        self.rooms[__name]:load(...)
        self.__type = __name
    end
end