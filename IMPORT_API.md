# Dakumi 导入与读取 API

本文档面向两类读者：

- 只想把自制素材／谱面放进游戏里的玩家：看「[存储位置](#存储位置)」和「[导入方式](#导入方式)」。
- 想接入自定义格式（例如自己的谱面格式、加密音频、私有图片格式）的开发者：看「[读取器契约](#读取器契约)」与「[公共 API](#公共-api)」。

游戏内置的谱面 JSON 格式见 [CHART_FORMAT.md](CHART_FORMAT.md)。

## 分层

| 层 | 自动加载名 | 职责 |
| --- | --- | --- |
| 存储 | `Storage` | 所有文件 I/O。公有目录探测、Android SAF 授权、复制、目录枚举、限额。 |
| 导入/加载 | `ImportAPI` | 选择用哪个读取器读文件，回退到内置解码器；清单与读者注册表。 |
| 上下文 | `DakumiImportContext` | 交给读取器的、对「玩家选中的那个文件夹」的完整访问能力。 |

读取器只拿到 `DakumiImportContext`，拿不到任意路径的写权限，也拿不到真实文件系统路径——它看到的路径可能是不透明的 SAF `content://` URI。

## 内置支持

不装任何读取器也能直接读取：

- 谱面：JSON 对象（[CHART_FORMAT.md](CHART_FORMAT.md)）。
- 音频：MP3、WAV、OGG。按扩展名判断，扩展名缺失时嗅探文件头（`RIFF` / `OggS` / `ID3` / MPEG 帧同步）。
- 背景：PNG、JPEG、WebP（按文件头判断）。

解码失败或格式不支持时，`ImportAPI.last_error` 会给出可读原因，`load_*()` 返回 `null`。

## 导入方式

设置界面「分散文件导入」区块支持四选三：

1. **谱面文件**：必填。JSON 谱面，或能被已启用读取器识别的任意文件。
2. **音乐文件**：可选。与谱面分开存放时使用。
3. **背景图片**：可选。
4. **谱面文件夹**：可选但推荐。选中后整个目录树会被复制，谱面、音频、背景由目录扫描自动发现（见下）。

导入的落点始终是当前素材目录（可能是公有目录，也可能是私有目录），**不会覆盖**已存在的谱面：重名时自动加 `(2)`、`(3)` 后缀。

### 目录扫描规则

只导入文件夹（或读取一个包含多个文件的目录）时，`ImportAPI.scan_folder()` 按以下顺序收集**该文件夹里所有能读的谱面**：

1. 目录内存在 `dakumi.bundle.json` → 清单指名的那张谱面排第一，音频／封面以清单为准（见下）。
2. 任一已启用读取器实现 `scan_bundle(context)` → 由它一次给出多张谱面（TAKANA 的各难度就走这里）；只实现了 `resolve_bundle(context)` 的读取器按单张处理。
3. 扫描目录内文件：
   - 第一个 `mp3` / `wav` / `ogg` 作为音乐，第一个 `png` / `jpg` / `jpeg` / `webp` 作为背景；
   - 名为 `chart.json` 的 JSON 优先，其它包含 `note` / `bpm` / `event` 字段的 JSON 依次候补；
   - 能被某个读取器 `can_read("chart", ...)` 识别的文件也会成为候选。
4. 都没找到时递归进入子目录（最多 8 层，兼容压缩包解出的「单层歌曲文件夹」结构）。

`ImportAPI.resolve_directory()` 仍然只返回**一张**谱面（扫描结果里的第一张），旧调用方不必改；要多张请用 `list_charts()`。

### 多谱面文件夹

一个歌曲文件夹里可以放多张谱面：`chart.json`、`easy.json` / `hard.json` 这类额外的 JSON，或读取器给出的任意文件。规则：

- **顺序即显示顺序**：清单与读取器给的顺序优先，内置扫描把 `chart.json` 排在这些候选的前面；其余按文件名排序。
- **同一张谱面只列一次**：身份是去掉 `.editing` 后的小写路径（`ImportAPI.chart_identity()`），所以 TAKANA 的 `master.json` 与 `master.editing.json` 算同一张，正式谱优先。
- **标签**：读取器给的难度名优先，其次是 `chart.json` 之外的内置候选自报的 `info.difficulty` / `info.chart_name`（等级取 `info.level`），都没有就退回大写文件名。
- **音频／封面是共享的**：整个文件夹一份，属于歌曲而不属于某张谱面。

```gdscript
var charts: Array[Dictionary] = ImportAPI.list_charts(folder)   # [{chart, label, detail}, ...]
ChartLoader.load_from_folder(folder, charts[1].chart)            # 空串 = 用第一张
```

选曲界面里，点开一首歌会在它下面展开全部谱面（`●` 标出当前选中的那张），点谱面行即切换。删除入口在「管理 ▾」菜单里，删谱面与删整首歌都要在确认框里点「删除」才生效。

成绩按「文件夹 + 谱面」记录（`Scores.key_of()`）：**文件夹里只有一张谱面时沿用文件夹名**，所以这次改动之前记的成绩照样读得出来；有多张时键变成 `文件夹#谱面文件名`，各难度互不覆盖。

### TAKANA 曲包（.t3bundle / .t3pkg）

TAKANA 的 `.t3bundle` 把一批歌打成一个文件，`.t3pkg` 是其中的单曲包——两者都是 ZIP 外壳，**导入结果等同于导入一个歌曲文件夹**：

```gdscript
var folder: String = ImportAPI.import_bundle(path)   # 空串 = 失败，原因在 last_error
```

- 落点是 `chart/<曲包名的文件夹>/`，里面每首歌各占一个子文件夹；内层 `.t3pkg` 会被解开并删掉包本身，所以整包歌天然被分到了同一个文件夹里。
- 只认这两种扩展名，其它文件仍走 `import_zip()` / `import_folder()`。
- 压缩包常见的「再套一层同名文件夹」会被提上来，免得库里出现 `chart/曲包名/曲包名/歌`。
- 解不出任何谱面的包（空包、坏包）会被整个撤掉，并写进 `last_error`——不在库里留一个点不开的空文件夹。

界面入口在谱面库的导入菜单第三项：**导入 TAKANA 曲包（.t3bundle / .t3pkg）**。

### 歌曲文件夹（分组）

`chart/` 下可以任意套文件夹，纯用来给歌分组。判据很便宜——只看文件名、不解析内容（`ImportAPI.is_song_folder()`）：**一个目录是「歌」当且仅当**它里面有 `dakumi.bundle.json`、`.t3proj`、任何不是保留清单（`dakumi.bundle.json` / `skin.json` / `manifest.json` / `settings.json` / `reader_plugins.json`）的 `.json`，或某个已启用读取器能识别（`can_read("chart", ...)`）的文件；否则它就是分组文件夹。所以损坏的 `chart.json` 仍算一首歌（点开报读取失败），不会被当成文件夹藏起来。

```gdscript
var catalog: Array[Dictionary] = ImportAPI.library_catalog()      # 深度优先的扁平表
var songs: Array[String] = ImportAPI.songs_under(folder, false)   # 这个文件夹下面所有歌的路径
var created: String = Storage.create_folder(root, "练习曲")        # 重名自动加 (2)，不报错
var moved: String = Storage.move_tree(song, created)               # 空串 = 挪回库根目录
```

- `library_catalog()` 每条是 `{kind: "song" | "folder", path, name, depth, songs}`：`folder` 条目后面紧跟着它的内容，`songs` 是它下面有多少首歌（不含自己），下钻上限 `CATALOG_DEPTH`（8 层）。
- 成绩与单曲延迟按**文件夹名**记（`Setting.song_key()` 只取最后一段路径），所以把歌挪进 / 挪出文件夹不会丢成绩；目标重名时自动加 `(2)`。
- 移动优先用改名（同一卷最快），跨卷（私有目录 ↔ 公有目录）退回「复制 + 删除」；万一源目录删不掉，`last_error` 会说明新位置仍然可用。
- 删文件夹会连带删掉里面的歌：确认之后按 `ImportAPI.songs_under(folder)` 列出的每一首清掉它的成绩与单曲延迟。

选曲界面里文件夹占一行（`▸` / `▾` 开头，行尾写「· N 首歌」或「· 空文件夹」），轻点展开／收起；搜索时命中的文件夹一律按展开显示，否则命中项等于藏在收起的文件夹里。「文件夹 ▾」菜单里有新建 / 移动到 / 删除，删除要二次确认。

## 存储位置

启动时 `Storage.refresh_storage()` 依次探测：

```text
/storage/emulated/0/date/dakumi      # 需求指定的公有目录
/storage/emulated/0/data/dakumi      # Android 常见的数据目录
```

只有当两个候选都无法创建并写入 `chart/`、`users/` 子目录时，才退回应用私有目录 `user://`。探测方式是实际创建目录并试写，而不是读取权限标志——Android 的分区存储经常出现「有权限但目录不可写」。

```text
<root>/
├── chart/     # 导入的谱面，每首歌一个文件夹；可以再套文件夹给它们分组（见「歌曲文件夹」）
└── users/     # 玩家素材（note / 判定线 / Hit / 数字 / 判定图片、打击音、外部读取器等）
    └── readers/   # 导入的读取器 .gd，文件名是内容的 SHA-256
```

`Storage.is_public` 表示是否落在公有目录，`Storage.status_message` 是给设置界面显示的中文说明。点击「重新检测公有目录」会重新探测并发出 `storage_changed`。

## 读取器契约

一个读取器是一个 **继承 `RefCounted` 的 GDScript**，至少实现：

```gdscript
func can_read(kind: String, path: String, context: DakumiImportContext) -> bool
func read_chart(path: String, context: DakumiImportContext) -> Variant
func read_audio(path: String, context: DakumiImportContext) -> AudioStream
func read_background(path: String, context: DakumiImportContext) -> Texture2D
```

- `kind` 是 `"chart"`、`"audio"`、`"background"` 三者之一。`ImportAPI` 调用前会检查 `has_method("read_" + kind)`，所以只实现自己关心的那一两个即可。
- `can_read()` 返回 `true` 才会调用对应的 `read_*()`。
- `read_*()` 返回 `null` 表示「这个文件我读不了」：`ImportAPI` 会继续询问下一个读取器，最后回退到内置解码器。返回非 `null` 即视为成功。
- `read_chart()` 可以返回 `Dictionary`（已解析的谱面对象）或 `String`（谱面文本，交给内置 JSON 解析）。
- 可选实现 `resolve_bundle(context: DakumiImportContext) -> Dictionary`：目录扫描时用来声明「这个文件夹里谱面／音乐／背景分别是哪个文件」，返回形如 `{"chart": "song.xchart", "audio": "song.xaudio", "background": "cover.png"}`。路径可以是相对于该文件夹的相对路径，也可以是完全独立的 SAF URI。
- 可选实现 `scan_bundle(context: DakumiImportContext) -> Dictionary`：一个文件夹里有多张谱面（多个难度）时改用它：

  ```gdscript
  func scan_bundle(context: DakumiImportContext) -> Dictionary:
      return {
          "charts": [                                  # 顺序即显示顺序
              {"chart": "normal.json", "label": "NORMAL", "detail": "Lv.7"},
              "hard.json",                             # 只给路径也行，标签退回文件名
          ],
          "audio": "song.mp3",
          "background": "cover.png",
      }
  ```

  `charts` 里每条可以是路径字符串，也可以是 `{chart, label, detail}`（`label` 显示在谱面行上，`detail` 是等级之类的补充）。同时实现了 `scan_bundle` 时它优先，`resolve_bundle` 不再被调用。

约定：

- 读取器应当**只读**。它通过 `context` 读文件，不写文件；需要缓存请写 `context` 之外的、自己管理的私有目录，或干脆不缓存。
- 读取器由 `ImportAPI` 在需要时同步调用，不要做重活（例如整包解压）之外的阻塞操作；单文件读取已经受 `Storage.MAX_FILE_BYTES`（256 MiB）限制。
- 抛出错误请用 `push_error`，并把 `last_error` 之外的信息写进返回值；`ImportAPI.last_error` 由框架维护，读取器不要直接改。

### 注册方式

**界面导入（玩家用）**：设置 →「外部读取器 / 公共 API」→「导入读取器 .gd」，选中 `.gd` 文件后它被复制到 `users/readers/<sha256>.gd`，此时**不执行**。列表里打开开关会弹出信任确认，确认后才编译并注册（优先级 100，高于内置）。之后每次启动，只有仍处于启用状态的读取器会被加载；内容被改动的读取器会被拒绝并提示重新导入。

**代码注册（开发者用）**：

```gdscript
class_name MyReader
extends RefCounted

func can_read(kind: String, path: String, context: DakumiImportContext) -> bool:
	return kind == "chart" and path.get_extension().to_lower() == "mychart"

func read_chart(path: String, context: DakumiImportContext) -> Variant:
	# context.read_text 会处理好相对路径、绝对路径与 SAF URI。
	return my_parser.parse(context.read_text(path))

# 在某个初始化脚本里：
# ImportAPI.register_reader("my-reader", MyReader.new(), 50)
# 取消：ImportAPI.unregister_reader("my-reader")
```

`priority` 越大越先被询问；内置回退永远最后。同 id 重复注册会替换旧的。`ImportAPI.plugins_changed` 在读取器列表变化时发出。

## DakumiImportContext

读取器拿到的唯一文件入口。`root` 是玩家选中的文件夹（普通路径或 SAF tree URI），`source` 是当初选择它的原始路径。

| 成员 | 说明 |
| --- | --- |
| `root: String` | 授权文件夹。可能形如 `content://com.android.externalstorage.documents/tree/primary%3AMusic#songs`。 |
| `source: String` | 玩家选择时拿到的原始路径（用于展示或再次授权）。 |
| `resolve(path = "") -> String` | 把相对路径解析成可访问路径。空字符串返回 `root` 本身。已是 `content://` 或绝对路径时原样返回。**SAF 子路径分隔符是 `#` 而不是 `/`**，`resolve()` 已经处理好。 |
| `list(path = "") -> Array[Dictionary]` | 列出目录，元素为 `{"name", "path", "is_dir"}`，按名称排序。 |
| `read_bytes(path) -> PackedByteArray` | 读取整个文件。失败返回空数组，原因在 `get_error()`。 |
| `read_text(path) -> String` | 按 UTF-8 读取文本。 |
| `exists(path) -> bool` | 文件是否存在。 |
| `get_error() -> String` | 最近一次底层 I/O 的中文错误说明（透传自 `Storage.last_error`）。 |

**这套 API 就是「对谱面所在文件夹的全部访问能力」**：读取器可以列出并读取文件夹内任意文件，包括谱面未声明的 sidecar 资源（额外图片、自定义数据表、被拆分的音频块）。它读不到未授权的其它目录。

## dakumi.bundle.json

放在谱面文件夹里，用来显式声明「哪个文件是什么」。`ImportAPI.import_files()` 在玩家分别选择谱面／音乐／背景时会自动生成；也可以手写。

```json
{
  "version": 1,
  "chart": "song.json",
  "audio": "song.mp3",
  "background": "cover.png",
  "folder": ""
}
```

- 各路径相对清单所在目录，也可以是绝对路径或独立 SAF URI。
- `folder` 非空时，所有相对路径以它为基准解析（用于谱面与资源分开放的包）。
- `chart` 为空视为无效清单，此时继续按目录扫描规则处理（方便手写时先放清单再补内容）。
- 清单指向的文件读不出来时，错误信息会带上清单文件名，便于定位。

## 公共 API

### ImportAPI

| 方法 | 说明 |
| --- | --- |
| `load_chart(path, context_root = "") -> Variant` | 读取谱面。成功返回 `Dictionary` 或 `String`，失败返回 `null` 并写 `last_error`。 |
| `load_audio(path, context_root = "") -> AudioStream` | 读取音频。 |
| `load_background(path, context_root = "") -> Texture2D` | 读取背景图。 |
| `load_bundle(chart_path, audio_path = "", background_path = "", folder = "") -> Dictionary` | 一次性加载三者，返回 `{ok, data, music, bg, chart_path, audio_path, background_path, folder, error}`；任一失败即 `ok = false` 并填写 `error`。 |
| `resolve_directory(folder) -> Dictionary` | 按目录扫描规则加载整个文件夹，返回结构与 `load_bundle()` 相同；只加载第一张谱面。 |
| `scan_folder(folder) -> Dictionary` | 列出文件夹里所有可读的谱面与共享素材：`{charts: Array[Dictionary], audio, background, directories, manifest, folder}`。`charts` 每条是 `{chart, label, detail}`。 |
| `list_charts(folder) -> Array[Dictionary]` | `scan_folder()` 的谱面部分，找不到谱面时返回空数组（并把原因写进 `last_error`）；`charts[0]` 就是默认谱面。 |
| `load_bundle_in(folder, chart_path) -> Dictionary` | 读文件夹里的指定谱面，音频／封面仍取整个文件夹共享的那一份；返回结构与 `load_bundle()` 相同。 |
| `chart_identity(path) -> String`（静态） | 谱面身份：去掉 `.editing` 后的小写路径，用来判断两份文件是不是同一张谱面。 |
| `library_catalog(max_depth = 8) -> Array[Dictionary]` | 谱面库的目录树，深度优先的扁平表：每条是 `{kind, path, name, depth, songs}`，见「歌曲文件夹」。 |
| `is_song_folder(folder) -> bool` | 这个目录是「歌」还是分组文件夹（只看文件名，不解析内容）。 |
| `songs_under(folder, include_self = false) -> Array[String]` | 一个文件夹下面所有「歌」的路径，删文件夹时按它逐首清成绩与单曲延迟。 |
| `import_files(chart_path, audio_path = "", background_path = "", chart_folder = "") -> String` | 复制并登记一份谱面，返回导入后的目录；失败返回空串。只传 `chart_folder` 时整棵树被复制。 |
| `import_bundle(path) -> String` | 导入 TAKANA 曲包（`.t3bundle` / `.t3pkg`）：解到 `chart/<曲包名>/`，内层单曲包一并解开；返回新建的文件夹，失败返回空串。 |
| `import_plugin(path) -> String` | 把 `.gd` 读取器安装到 `users/readers/`，返回 id（内容 SHA-256）；**不启用**。 |
| `list_plugins() -> Array[Dictionary]` | 已安装读取器：`{id, name, path, enabled}`。 |
| `set_plugin_enabled(id, enabled) -> bool` | 启用／停用。启用包含编译与信任检查，失败写 `last_error`。 |
| `register_reader(id, reader, priority = 0)` / `unregister_reader(id)` | 运行时注册／注销读取器。 |
| `make_context(path, context_root = "") -> DakumiImportContext` | 构造上下文，`context_root` 为空时取 `path` 所在目录。 |
| `last_error: String` | 最近一次失败的中文说明。每次 `load_*` 开始时清空。 |
| `plugins_changed` | 读取器列表或启用状态变化时发出。 |

### Storage

| 方法 | 说明 |
| --- | --- |
| `refresh_storage()` | 重新探测公有目录并重建子目录。`storage_changed` 随之发出。 |
| `pick_file(owner, filters, callback)` / `pick_directory(owner, callback)` | 弹出系统文件选择器（Android 上是 SAF），回调收到路径或空串（取消）。SAF 授权会被 `persist_uri()` 持久化。 |
| `import_asset(path) -> String` | 把一个外部文件复制进 `users/`，返回目标路径；重名自动加后缀。 |
| `import_folder(source) -> String` | 把整个目录树复制进 `chart/`，返回新目录。 |
| `import_zip(path) -> String` | 解压压缩包到 `chart/`，受总字节数与文件数限额约束（1 GiB / 10000 个文件）。 |
| `extract_zip(path, target) -> bool` | 把 ZIP 解压到指定目录（曲包导入用）：先整包校验（越界路径、重名、大小）再落盘。 |
| `create_folder(folder, name) -> String` | 在谱面库里新建一个分组文件夹；重名自动加 `(2)`，返回新目录或空串。 |
| `move_tree(source, folder) -> String` | 把一首歌或一整个文件夹挪进另一个文件夹（空串 = 库根目录），返回新位置。 |
| `list_directory(folder) -> Array[Dictionary]` | 目录枚举，元素为 `{name, path, is_dir}`。 |
| `read_bytes(path)` / `write_bytes(path, bytes)` / `copy_file(source, target)` | 基础 I/O。读取上限 256 MiB。 |
| `resolve_path(folder, relative) -> String` | 相对路径解析，正确处理 SAF 的 `#` 分隔。 |
| `base_directory(path) -> String` | 取所在目录；单个 SAF 文档授权没有同级目录，返回空串。 |
| `display_name(path) -> String` | 用于显示的文件名（URI 解码、去掉 SAF 片段）。 |
| `unique_path(folder, filename) -> String` | 生成不冲突的目标路径。 |
| `delete_file(path) -> bool` | 删掉单个文件（删一张谱面用）。只允许删库内的内容，见下。 |
| `delete_tree(path) -> bool` | 递归删掉一个谱面文件夹（删整首歌用）。同样只允许删库内的内容。 |
| `library_directories() -> Array[Dictionary]` | 谱面库里所有可加载的文件夹，供开始界面列出。 |
| `library_roots() -> Array[String]` | 谱面库的根目录（`chart_dir`，以及可能的旧位置），删除操作的允许范围。 |
| `root_path` / `chart_dir` / `users_dir` / `is_public` / `status_message` / `last_error` | 当前存储状态。 |
| `storage_changed` / `library_changed(new_path)` | 存储位置变化 / 导入完成信号。 |

删除是不可回滚的，所以 `delete_file()` / `delete_tree()` 只接受 `library_roots()` 里的某个根目录的**子项**：根目录自己、`res://`、空路径、以及任何含 `..` 的路径一律拒绝（`Storage.last_error` 给中文原因）。成功后会发出 `storage_changed`，界面据此刷新。`user://` 私有库也算库，所以私有目录下的谱面同样能删——删的始终是谱面，不是素材。

## Android 说明

- 公有目录写入依赖 `MANAGE_EXTERNAL_STORAGE` 或分区存储下的可写目录；权限不可用时自动退回私有目录，功能不受影响，只是素材不在公有路径下。
- 应用启动时会申请导出清单里声明的存储权限（`android/permissions/*`）。授权对话框关闭、或玩家在系统设置里开启「所有文件访问权限」后返回应用时，`Storage` 会重新探测一次，成功即自动切到公有目录，不需要重启；设置界面的「重新检测公有目录」按钮可手动触发同一流程。
- 用系统选择器授权文件夹后，应用会持久化该授权（`updatePersistableUriPermission`），但**单文件授权不等于同级目录授权**：谱面引用同目录的 sidecar 文件时，请让玩家选择「谱面文件夹」而不是单个谱面文件。
- SAF 目录路径在应用内部表示为 `tree_uri#relative/path`。请始终用 `Storage.resolve_path()` / `context.resolve()` 拼接，不要手写字符串拼接。
- `user://` 与公有目录都是真实文件系统路径，`FileAccess` 可直接使用；`content://` 路径由 Godot 的 Android 层透明处理，`DirAccess` / `FileAccess` 同样可用。

## 示例：一个最小读取器

```gdscript
extends RefCounted
# 读取自定义文本谱面：首行是 BPM，之后每行是 "track beat"。

func can_read(kind: String, path: String, context: DakumiImportContext) -> bool:
	return kind == "chart" and path.get_extension().to_lower() == "txtchart"

func read_chart(path: String, context: DakumiImportContext) -> Variant:
	var text := context.read_text(path)
	if text.is_empty():
		return null                      # 交给下一个读取器 / 内置 JSON
	var lines := text.split("\n", false)
	if lines.size() < 2 or not lines[0].is_valid_float():
		return null
	var notes: Array = []
	for index in range(1, lines.size()):
		var parts := lines[index].split(" ", false)
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_float():
			notes.append({"type": "note", "track": parts[0].to_int(), "beat": parts[1].to_float()})
	return {
		"version": 1, "offset": 0,
		"bpm_list": [{"beat": 0.0, "bpm": lines[0].to_float(), "linear_ramp": 0}],
		"note": notes, "event": [], "effect": [],
		"info": {"song_name": "", "chart_name": "", "chartor": "", "artist": ""},
		"preference": {"x_offset": 0, "event_scale": 100},
		"track": {},
	}
```

把这段代码存成 `mychart.gd`，在设置界面导入并确认启用即可；返回的字典随后会被 `ChartData` 按正常谱面补全、校验。
