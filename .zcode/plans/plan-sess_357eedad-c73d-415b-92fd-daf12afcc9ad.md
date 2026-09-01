# 将 ctrl、alt、redo 转换为插件

## 目标
按照现有插件模式（hit、directEventEditing），将 ctrl、alt、redo 迁移到 `src/plugins/`，注册到 PluginManager，加上 nil 保护使其真正可选。

## 变更步骤

### 1. 创建插件文件（复制 + 添加注册）
将 `src/objects/play/{ctrl,alt,redo}.lua` 复制到 `src/plugins/`，底部添加：
```lua
if PluginManager then
    PluginManager:register({ name = "...", version = "1.0.0", description = "..." })
end
```

### 2. alt.lua 添加 nil 保护
`ctrl:copy_add(...)` → `if ctrl then ctrl:copy_add(...) end`

### 3. meta.lua 添加 nil 保护
`redo:writeRevoke(...)` → `if redo then redo:writeRevoke(...) end`（共 3 处）

### 4. sidebar/events.lua 添加 nil 保护
`ctrl:get_copy()` → 检查 ctrl 是否存在

### 5. 更新 rooms/play.lua
```lua
redo = require('src.plugins.redo')
play:addObject(redo)
play:addObject(require 'src.plugins.alt')
ctrl = require('src.plugins.ctrl')
play:addObject(ctrl)
```

### 6. 更新 plugins/init.lua
添加 ctrl、alt、redo 的 pcall 加载

### 7. 删除旧文件
删除 `src/objects/play/{ctrl,alt,redo}.lua`

## 不变的部分
- 所有功能逻辑不变
- 生命周期仍通过 addObject 分发
- Event/Note 类位置不变