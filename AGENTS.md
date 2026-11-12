# AGENTS.md — FlowMahjong（目录 liumaSimulator）

Godot 4.7.2 项目（mobile 渲染后端），目录 `E:\Godot\liumaSimulator`。
本文件是给在本工作区工作的 agent 的上下文说明：一半是**协作方式**，一半是**怎么连上正在运行的 Godot 编辑器**。

## 和用户协作的方式

这是**学习项目**，开发和理解同等重要。

- 用户有 C++、Vulkan、UE 基础，Godot 是新手。讲 Godot 概念时顺手对照 UE：Node ≈ Actor/组件（更像可挂载的 Component）、Scene ≈ 一个 Blueprint 类 + 它的层级、Signal ≈ Delegate/Event、`@export` ≈ `UPROPERTY(EditAnywhere)`、`_ready()` ≈ `BeginPlay`、`_process()` ≈ `Tick`。对照完要指出差异，别硬套。
- **不要一次做完整个功能**。一次一个小实验，每步说清：为什么这么做、预期看到什么、怎么验证。
- 先用 MCP 查真实状态（场景树、属性、脚本、控制台），不要假设节点或资源已经存在。
- 遇到适合学习的问题，先给线索让用户自己判断；批量建节点、改属性、跑验证这类重复劳动才代劳。
- 重要错误、设计决策、可复用发现 → 往 `docs/EXPERIMENTS.md` 加一条极简记录（模板在文件里）。不写流水账，不写学习日志。
- Git 提交只在验证通过后做，一次提交一件事。


## 项目现状

- 项目名：`新建游戏项目`（`project.godot` 的 `config/name`，也决定 `user://` 目录名）
- 已装插件：`addons/godot_mcp_toolkit` v1.1.2 —— 在编辑器进程内起了一个 WebSocket MCP 服务
- 目前**没有主场景**；`scenes/`、`scripts/` 目录已建但为空；`application/run/main_scene` 为空
- 只要编辑器开着插件启用，MCP 服务就在跑；编辑器关闭则完全不可用

## 连接 Godot 编辑器

### 端点发现（不要硬编码端口和 token）

读 `%APPDATA%\godot-mcp-toolkit\projects.json`：

```json
{"by_path": {"e:/godot/liumasimulator": {
  "port": 6550, "token_path": ".../mcp_token", "lsp_port": 6005, "pid": 65648}}}
```

- key 是**小写、正斜杠**的项目绝对路径
- `port` 正常是 6550，被占用时会在 6550–6560 之间漂移
- `token_path` 指向该编辑器实例的会话 token（64 位 hex，**每次编辑器重启都会轮换**，所以每次现读）
- 编辑器没注册 ≠ 服务没跑；注册表缺失时直接试 6550

### 协议（不是 stdio MCP，是 WebSocket + JSON-RPC 2.0）

1. `ClientWebSocket` 连 `ws://127.0.0.1:<port>/`
2. 先发鉴权帧：`{"auth":"<token>","server_version":"1.1.2"}`
3. 收到 `{"authed":true,"godot_version":"4.7.2","headless":false,"version":"1.1.2",...}`
4. 之后每条是一个 JSON-RPC 2.0 请求：

```json
{"jsonrpc":"2.0","id":1,"method":"scene.get_tree","params":{}}
```

响应 `{"id":1,"jsonrpc":"2.0","result":{...}}`；业务失败也在 `result` 里（`{"success":false,"code":"NO_SCENE",...}`），协议层错误才是 `{"error":{"code":-32601}}`。
变更类命令可能先收到 `_queued` / `_executing` 通知帧，再过一会儿才有带 `id` 的最终响应——**按 `id` 匹配，别拿第一帧当结果**。

### 现成脚本

`.dsh/godot_mcp.ps1`（在本工作区，已实现上面的发现 + 鉴权 + 收发，输出默认截断 3500 字符）：

```powershell
pwsh -NoProfile -File '.dsh\godot_mcp.ps1' -Requests '[{"method":"scene.get_tree","params":{}}]'
# 一次多条，共用一个连接
pwsh -NoProfile -File '.dsh\godot_mcp.ps1' -Requests '[{"method":"debug.state"},{"method":"editor.screenshot","params":{}}]' -Full
```

参数：`-Requests`（JSON 数组，必填）、`-MaxChars`、`-Full`（不截断）、`-Port` / `-TokenPath` / `-ProjectPath`（跳过自动发现）。

`result` 里的某些字符串字段（`tree` / `entries` / `settings`）会包在 `<untrusted-xxxx kind="...">` 里——那是插件自己的防注入信封（`addons/godot_mcp_toolkit/security/untrusted.gd`），不是响应内容，解析前先剥掉。

### 不要做什么

- 不要用 `.mcp.json` 里的 `npx @npgamedev/godot-mcp-server` 来诊断连通性：它只是个 stdio↔WS 桥，还要装包可能联网；直连 WebSocket 一步到位
- 不要假设 `scene.get_tree` 一定成功——没有打开的场景时它返回 `NO_SCENE`

## 命令清单（插件注册了 102 条，method 就是名字）

| 类别 | 命令 |
|---|---|
| 场景 | `scene.get_tree` `scene.query` `scene.create` `scene.open` `scene.close` `scene.delete` `scene.create_node` `scene.delete_node` `scene.instantiate` `scene.create_inherited` `scene.diff` |
| 节点 | `node.manage` `node.get_property` `node.set_property` `node.get_property_list` `node.call_method` `node.set_script` `node.groups` `node.collision_from_sprite` `control.set_layout` |
| 脚本 | `script.read` `script.write` `script.edit` `script.check` `script.delete` |
| 编辑器 | `editor.screenshot` `editor.get_console` `editor.save_scene` `editor.refresh` `editor.wait_for_idle` `editor.set_lsp_status` `execute.code` |
| 运行/调试 | `game.start` `game.stop` `debugger.get_log` `debug.state` `debug.set_breakpoint` `debug.continue` `debug.list_breakpoints` |
| 工程/资源 | `project.get_settings` `project.set_setting` `autoload.manage` `project.get_layer_names` `resource.load` `resource.write` `asset.list` `asset.import` `file.delete` `folder.create` `save.read` `save.write` `input_map.list` `input_map.action` `input_map.event` `classdb.get_info` `classdb.search` |
| 美术向 | `3d.create_primitive` `3d.create_light` `3d.create_camera` `3d.setup_environment` `texture.generate` `spriteframes.create` `spriteframes.from_spritesheet` `particles.create` `theme.edit` `tileset.*` `tilemap.set_cells` `tilemap.read_cells` `animation.keyframe` `animation.get_keys` `path2d.edit_curve` `navigation.edit_polygon` `audiobus.list` `audiobus.edit` `sound.generate` `procedural.edit_curve` `procedural.edit_gradient` `procedural.edit_noise` `signal.list` `signal.manage` `signal.emit` `scene.spatial_map` |

完整的参数定义看 `addons/godot_mcp_toolkit/commands/*.gd` 里的 `registry.add("...")`，同一文件下面是 handler 实现，参数名从里面读。

## 踩坑点

- **没有打开的场景时**，凡是标记为"需要当前场景"的命令都会返回 `NO_SCENE`。先 `scene.open` 或 `scene.create`
- **改动要保存**：改完场景/脚本后调 `editor.save_scene` 才落地到 `.tscn`
- **并发**：服务端允许多个客户端同时连（已实测两个 peer 同时鉴权成功）。但 mutation 走串行队列，场景操作还有 8 秒 TTL 的 scene lease——另一个客户端正在改场景时你的命令会排队，不要把它当成卡死
- **响应可能非常大**：`project.get_settings` 会把全量工程设置吐出来（几十 KB），脚本默认只打印前 3500 字符；要全文用 `-Full`，或者让命令带上过滤参数
- **`execute.code` 直接在编辑器进程里跑 GDScript**，能力最大也最危险，改状态前先想清楚有没有现成命令
- **`editor.screenshot`** 能拿到编辑器视口截图，适合确认 UI 摆位，比反复猜坐标快
- 插件设置：`mcp_toolkit/limits/ws_buffer_kb=1024`、`mcp_toolkit/concurrency/scene_lease_ttl_ms=8000`、`mcp_toolkit/audit/enabled=true`（每次调用都会记审计日志）

## 工作约定

除用户另有指示外：

- 场景放 `res://scenes/`，脚本放 `res://scripts/`，新增资源先 `folder.create`
- 建节点/改属性优先走 MCP 命令（`scene.create_node` / `node.manage` / `node.set_property`），而不是手写 `.tscn` 文本——这样编辑器里的状态和磁盘一致，Undo 也正常
- 新建或修改 `.gd` 后跑一次 `script.check`，别等运行时报错
- `.dsh/` 是放 agent 辅助脚本的目录，Godot 的 FileSystem 面板会隐藏以 `.` 开头的目录，不会出现在资源树里

## 实测记录（2026-11-12，从零跑通）

全链路已验证：`scene.create` → `scene.open` → `scene.create_node` → `script.write` → `script.check` → `node.set_script` → `editor.save_scene` → `game.start` → `game.stop` → `editor.get_console(source:"file")` → `editor.screenshot` → `scene.delete` / `script.delete`。认证、串行队列、`NO_SCENE`、截图落盘都符合预期。

补充和勘误：

- **命令清单是子集**：下表之外还注册了 `save.list` `save.delete` `resource.delete` `folder.delete` `meta.set_limits` `project.set_layer_names` `asset.get_dependencies` `spriteframes.edit` `animationtree.list` `animationtree.edit` `extensions.list` `extensions.refresh`，以及一整批 `tileset.*`（`tileset.create` `add_source` `remove_source` `add_alternative` `remove_alternative` `setup_layers` `edit_physics` `edit_terrain` `edit_navigation` `edit_visuals` `edit_custom_data`）
- **游戏运行时读不到日志**：Windows 上游戏进程占着 `user://logs/godot.log`，`debugger.get_log` 和 `editor.get_console(source:"file")` 都返回 `LOG_BUSY`。要读 `print()` 就先 `game.stop` 再读；运行中只能看 `source:"buffer"`（只有编辑器自身日志，不含游戏输出）。
- **`editor.screenshot` 截的是当前主屏**：编辑器停在 3D 视图时，即使当前场景是 Control 也会截到 3D 网格。要截 2D/UI 就传 `node_path` 指向该 2D 节点，或先手动切 2D 主屏。
- **`game.start` 返回 `runtime_ready:false` 是正常的**：直连 WebSocket 只见编辑器侧；游戏进程的 runtime 通道是连给 `.mcp.json` 那个 stdio bridge 的。没有 bridge 就没有 runtime_* 能力（节点状态、输入模拟、运行时截图）。
- **`.dsh/godot_mcp_probe.ps1` 已过时**（硬编码 token 路径与端口），统一用 `godot_mcp.ps1`。

