# Bezier.gd
# 贝塞尔曲线计算库 - 支持任意阶贝塞尔曲线
extends Node

# ============================================
# 计算阶乘
# ============================================
func _factorial(n: int) -> float:
    var result: float = 1.0
    for i in range(2, n + 1):
        result *= i
    return result


# ============================================
# 计算贝塞尔曲线上的点
# controlPoints: Array[Vector2] 控制点数组
# t: float 0~1 曲线进度
# 返回: Vector2 曲线上的点
# ============================================
func _time_to_x(controlPoints: Array[Vector2], t: float) -> Vector2:
    var n: int = controlPoints.size() - 1  # 控制点数量减1 = 阶数
    var result: Vector2 = Vector2.ZERO
    
    for i in range(0, n + 1):
        # 计算贝塞尔基函数
        var binomialCoeff: float = _factorial(n) / (_factorial(i) * _factorial(n - i))
        var term: float = binomialCoeff * pow(t, i) * pow(1 - t, n - i)
        
        result.x += term * controlPoints[i].x
        result.y += term * controlPoints[i].y
    
    return result


# ============================================
# 贝塞尔曲线插值（核心函数）
# startTime: 起始时间
# endTime: 结束时间
# startValue: 起始值
# endValue: 结束值
# nowtime: 当前时间
# bezierTable: 控制点数组 [x1, y1, x2, y2, ...]
# accuracy: 精度（可选，默认0.0005）
# 返回: 插值后的值
# ============================================
func get_bezier(
    startTime: float,
    endTime: float,
    startValue: float,
    endValue: float,
    nowtime: float,
    bezierTable: Array,
    accuracy: float = 0.0005
) -> float:
    # 计算时间点在时间范围内的百分比
    var timePercent: float = (nowtime - startTime) / (endTime - startTime)
    
    # 限制时间范围在 0 到 1 之间
    timePercent = clamp(timePercent, 0.0, 1.0)
    
    # 检查控制点数量是否为偶数
    if bezierTable.size() % 2 != 0:
        push_error("贝塞尔控制点数量必须为偶数")
        return 0.0
    
    # 常见三阶曲线直接求值，避免每帧构造控制点、阶乘和幂运算。
    if bezierTable.size() == 4:
        return startValue + (endValue - startValue) * _cubic_value(bezierTable, timePercent, accuracy)

    # 构建控制点数组
    var bezier_tab: Array[Vector2] = [Vector2(0, 0)]
    for i in range(0, bezierTable.size(), 2):
        bezier_tab.append(Vector2(bezierTable[i], bezierTable[i + 1]))
    bezier_tab.append(Vector2(1, 1))
    
    # 二分求解
    var lf: float = 0.0
    var rl: float = 1.0
    var mid: float = 0.5
    
    # 处理边界情况
    if timePercent == 0.0 or timePercent == 1.0:
        var point = _time_to_x(bezier_tab, timePercent)
        return startValue + (endValue - startValue) * point.y
    
    # 二分查找
    while rl - lf > accuracy:
        mid = (lf + rl) / 2.0
        var mid_x: float = _time_to_x(bezier_tab, mid).x
        
        if mid_x < timePercent:
            lf = mid
        elif mid_x > timePercent:
            rl = mid
        else:
            break
    
    # 计算最终值
    var point = _time_to_x(bezier_tab, mid)
    return startValue + (endValue - startValue) * point.y


# ============================================
# 低精度贝塞尔插值（精度0.05）
# ============================================
func low_bezier(
    startTime: float,
    endTime: float,
    startValue: float,
    endValue: float,
    bezierTable: Array,
    nowtime: float
) -> float:
    return get_bezier(startTime, endTime, startValue, endValue, nowtime, bezierTable, 0.05)


# ============================================
# 标准精度贝塞尔插值（精度0.005）
# ============================================
func bezier(
    startTime: float,
    endTime: float,
    startValue: float,
    endValue: float,
    bezierTable: Array,
    nowtime: float
) -> float:
    return get_bezier(startTime, endTime, startValue, endValue, nowtime, bezierTable, 0.005)


# ============================================
# 便捷函数：只计算曲线上的点（不插值）
# controlPoints: Array[Vector2] 控制点
# t: float 0~1
# 返回: Vector2 曲线上的点
# ============================================
func evaluate(controlPoints: Array[Vector2], t: float) -> Vector2:
    return _time_to_x(controlPoints, t)


# ============================================
# 便捷函数：用数组创建控制点
# points: Array[float] 扁平数组 [x1, y1, x2, y2, ...]
# 返回: Array[Vector2]
# ============================================
func create_control_points(points: Array) -> Array[Vector2]:
    if points.size() % 2 != 0:
        push_error("控制点数量必须为偶数")
        return []
    
    var result: Array[Vector2] = []
    for i in range(0, points.size(), 2):
        result.append(Vector2(points[i], points[i + 1]))
    return result

func _cubic_value(points: Array, progress: float, accuracy: float) -> float:
    if progress <= 0.0 or progress >= 1.0:
        return progress
    var x1: float = points[0]
    var x2: float = points[2]
    var low := 0.0
    var high := 1.0
    var mid := 0.5
    # 与通用路径使用相同的二分精度与终止条件，保留 y 超出 0~1 的回弹。
    while high - low > accuracy:
        mid = (low + high) * 0.5
        var inverse := 1.0 - mid
        var x := 3.0 * inverse * inverse * mid * x1 + 3.0 * inverse * mid * mid * x2 + mid * mid * mid
        if x < progress:
            low = mid
        elif x > progress:
            high = mid
        else:
            break
    var inverse := 1.0 - mid
    return 3.0 * inverse * inverse * mid * float(points[1]) + 3.0 * inverse * mid * mid * float(points[3]) + mid * mid * mid
