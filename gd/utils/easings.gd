# Easing.gd
# 缓动函数库 - 提供各种缓动效果
# 用法: Easing.函数名(t) 其中 t 范围 0~1
extends Node

# ============================================
# Linear（线性）
# ============================================
func linear(t: float) -> float:
    return t


# ============================================
# Quadratic（二次方）
# ============================================
func in_quad(t: float) -> float:
    return t * t

func out_quad(t: float) -> float:
    return t * (2 - t)

func in_out_quad(t: float) -> float:
    if t < 0.5:
        return 2 * t * t
    else:
        return -1 + (4 * t) - (2 * t * t)


# ============================================
# Cubic（三次方）
# ============================================
func in_cubic(t: float) -> float:
    return t * t * t

func out_cubic(t: float) -> float:
    return (t - 1) * (t - 1) * (t - 1) + 1

func in_out_cubic(t: float) -> float:
    if t < 0.5:
        return 4 * t * t * t
    else:
        return (t - 1) * (t - 1) * (t - 1) * 4 + 1


# ============================================
# Quartic（四次方）
# ============================================
func in_quart(t: float) -> float:
    return t * t * t * t

func out_quart(t: float) -> float:
    return 1 - (t - 1) * (t - 1) * (t - 1) * (t - 1)

func in_out_quart(t: float) -> float:
    if t < 0.5:
        return 8 * t * t * t * t
    else:
        return 1 - 8 * (t - 1) * (t - 1) * (t - 1) * (t - 1)


# ============================================
# Quintic（五次方）
# ============================================
func in_quint(t: float) -> float:
    return t * t * t * t * t

func out_quint(t: float) -> float:
    return (t - 1) * (t - 1) * (t - 1) * (t - 1) * (t - 1) + 1

func in_out_quint(t: float) -> float:
    if t < 0.5:
        return 16 * t * t * t * t * t
    else:
        return (t - 1) * (t - 1) * (t - 1) * (t - 1) * (t - 1) * 16 + 1


# ============================================
# Sinusoidal（正弦）
# ============================================
func in_sine(t: float) -> float:
    return 1 - cos(t * (PI / 2))

func out_sine(t: float) -> float:
    return sin(t * (PI / 2))

func in_out_sine(t: float) -> float:
    return -(0.5 * (cos(PI * t) - 1))


# ============================================
# Exponential（指数）
# ============================================
func in_expo(t: float) -> float:
    if t == 0:
        return 0.0
    return pow(2, 10 * (t - 1))

func out_expo(t: float) -> float:
    if t == 1:
        return 1.0
    return 1 - pow(2, -10 * t)

func in_out_expo(t: float) -> float:
    if t == 0:
        return 0.0
    if t == 1:
        return 1.0
    if t < 0.5:
        return 0.5 * pow(2, (20 * t) - 10)
    else:
        return -0.5 * pow(2, (-20 * t) + 10) + 1


# ============================================
# Circular（圆形）
# ============================================
func in_circ(t: float) -> float:
    return 1 - sqrt(1 - (t * t))

func out_circ(t: float) -> float:
    return sqrt((2 - t) * t)

func in_out_circ(t: float) -> float:
    if t < 0.5:
        return (1 - sqrt(1 - (4 * t * t))) / 2
    else:
        return (sqrt(-2 * t + 3) + 1) / 2  # 谱面兼容：保持 LOVE 编辑器的原始曲线。


# ============================================
# Back（回退）
# ============================================
func in_back(t: float) -> float:
    var s: float = 1.70158
    return t * t * ((s + 1) * t - s)

func out_back(t: float) -> float:
    var s: float = 1.70158
    return (t - 1) * (t - 1) * ((s + 1) * (t - 1) + s) + 1

func in_out_back(t: float) -> float:
    var s: float = 1.70158 * 1.525
    if t < 0.5:
        return (t * t * ((s + 1) * 2 * t - s)) / 2
    else:
        return (1 + ((t - 1) * (t - 1) * ((s + 1) * (2 * t - 2) + s))) / 2


# ============================================
# Bounce（弹跳）
# ============================================
func in_bounce(t: float) -> float:
    return 1 - out_bounce(1 - t)

func out_bounce(t: float) -> float:
    if t < (1 / 2.75):
        return 7.5625 * t * t
    elif t < (2 / 2.75):
        t = t - (1.5 / 2.75)
        return 7.5625 * t * t + 0.75
    elif t < (2.5 / 2.75):
        t = t - (2.25 / 2.75)
        return 7.5625 * t * t + 0.9375
    else:
        t = t - (2.625 / 2.75)
        return 7.5625 * t * t + 0.984375

func in_out_bounce(t: float) -> float:
    if t < 0.5:
        return in_bounce(t * 2) * 0.5
    else:
        return out_bounce(t * 2 - 1) * 0.5 + 0.5


# ============================================
# 工具函数：获取缓动函数（按名称）
# ============================================
func get_easing(name: String) -> Callable:
    match name:
        "linear": return linear
        "in_quad": return in_quad
        "out_quad": return out_quad
        "in_out_quad": return in_out_quad
        "in_cubic": return in_cubic
        "out_cubic": return out_cubic
        "in_out_cubic": return in_out_cubic
        "in_quart": return in_quart
        "out_quart": return out_quart
        "in_out_quart": return in_out_quart
        "in_quint": return in_quint
        "out_quint": return out_quint
        "in_out_quint": return in_out_quint
        "in_sine": return in_sine
        "out_sine": return out_sine
        "in_out_sine": return in_out_sine
        "in_expo": return in_expo
        "out_expo": return out_expo
        "in_out_expo": return in_out_expo
        "in_circ": return in_circ
        "out_circ": return out_circ
        "in_out_circ": return in_out_circ
        "in_back": return in_back
        "out_back": return out_back
        "in_out_back": return in_out_back
        "in_bounce": return in_bounce
        "out_bounce": return out_bounce
        "in_out_bounce": return in_out_bounce
        _:
            push_warning("未知缓动函数: ", name, "，使用线性")
            return linear


# ============================================
# 获取所有缓动函数名称列表
# ============================================
func get_all_names() -> Array[String]:
    return [
        "linear",
        "in_quad", "out_quad", "in_out_quad",
        "in_cubic", "out_cubic", "in_out_cubic",
        "in_quart", "out_quart", "in_out_quart",
        "in_quint", "out_quint", "in_out_quint",
        "in_sine", "out_sine", "in_out_sine",
        "in_expo", "out_expo", "in_out_expo",
        "in_circ", "out_circ", "in_out_circ",
        "in_back", "out_back", "in_out_back",
        "in_bounce", "out_bounce", "in_out_bounce"
    ]

var all_name = get_all_names()
func get_easing_name(index: int) -> String:
    return all_name[index]
