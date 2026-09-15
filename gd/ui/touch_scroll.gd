extends RefCounted
## 触屏拖拽滚动：设置 / 选曲 / 结算三个界面共用的一套手势处理。
##
## 为什么不能靠控件自己滚：Godot 的 ScrollContainer 与 ItemList 在触屏上都不理会手指拖动
## （只认滚轮和滚动条把手），而且按下落在一个 STOP 控件上时，后续的 Drag 事件只会发给
## 这个控件、不再冒泡到根节点。ItemList 更特殊——它自己不响应拖动，轻点选中走的却是
## 引擎生成的“模拟鼠标”事件，所以把它设成 PASS 既能上抛手势，又不影响点选。
##
## 用法（根节点是 Control）：
##     TouchScroll.pass_through(self)          # 界面建完后调用一次
##     func _gui_input(event: InputEvent) -> void:
##         if TouchScroll.handle(self, event, _scroll_target):
##             accept_event()
##
## 控件自己的拖动（滑块、滚动条把手、输入框选区）不受影响：那些事件会被控件消费，
## 根本到不了根节点。

## 桌面端滚轮一格折算的像素数。
const WHEEL_STEP := 120.0
## 手势状态存在界面根节点的 meta 上，一个界面一份。
const ACTIVE_META := "_dakumi_drag_scroll"


## 把只是装饰用的容器改成 PASS，触摸事件才能继续冒泡到根节点。
## 交互控件（按钮、滑块、输入框、列表）保持原样：落在它们上面的拖动仍然是控件自己的操作，
## 已经声明为 IGNORE 的（背景、预览、页容器）也保持原样。
## 例外是 ItemList：它自己不会拖动滚动，改 PASS 后手势上抛、轻点选中照旧。
static func pass_through(root: Node) -> void:
	for child in root.get_children():
		pass_through(child)
	if not root is Control or root is ScrollContainer:
		return
	var control := root as Control
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	if root is BaseButton or root is Range or root is LineEdit or root is TextEdit:
		return
	control.mouse_filter = Control.MOUSE_FILTER_PASS


## 处理一个 GUI 事件；返回 true 表示调用方应当 accept_event()。
## target 返回当前要滚动的对象（ScrollContainer / ItemList），没有可滚动内容时返回 null。
static func handle(screen: Control, event: InputEvent, target: Callable) -> bool:
	if event is InputEventScreenTouch:
		screen.set_meta(ACTIVE_META, (event as InputEventScreenTouch).pressed)
		# 按下必定消费：能冒泡到这里就说明没有控件要它，留着只会让下面的控件误判。
		return true
	if event is InputEventScreenDrag:
		if not bool(screen.get_meta(ACTIVE_META, false)):
			return false
		scroll_by(target, -(event as InputEventScreenDrag).relative.y)
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP:
			scroll_by(target, -WHEEL_STEP)
			return true
		if button == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(target, WHEEL_STEP)
			return true
	return false


## 把竖直位移折算成滚动：手指下滑 = 内容跟着下移 = 滚动值变小，并夹在 [0, 最大值] 内。
static func scroll_by(target: Callable, delta: float) -> void:
	var node: Object = target.call()
	var bar := scroll_bar_of(node)
	if bar == null:
		return
	# 可见高度取控件的矩形：ScrollContainer 的滚动条 page 在内容不足时会退化成内容最小高度。
	var visible := bar.page
	if node is Control and (node as Control).size.y > 0.0:
		visible = (node as Control).size.y
	var maximum := maxf(0.0, bar.max_value - visible)
	bar.value = clampf(bar.value + delta, 0.0, maximum)


## 可滚动对象对应的竖直滚动条。
static func scroll_bar_of(node: Object) -> ScrollBar:
	if node is ScrollContainer:
		return (node as ScrollContainer).get_v_scroll_bar()
	if node is ItemList:
		return (node as ItemList).get_v_scroll_bar()
	return null
