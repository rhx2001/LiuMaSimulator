# FlowMahjong — Agent 工作约定

> 这是一个 Godot 4.x 的 PC 端流麻视觉/物理原型，同时也是我学习 Godot 的练习项目。请始终以仓库中的实际工程和当前文档为准。

## 每次开始工作
1. 阅读 `docs/PROJECT.md`，再看 `docs/EXPERIMENTS.md` 的最后一条有效记录；检查工作区改动和已有场景/脚本。
2. 使用已连接的 Godot MCP **只读**检查项目、场景、节点和报错（如果工具可用）；不要凭想象假设节点、API、插件或资源已存在。
3. 简述目前状态，**只推进一个可验收的小步骤**。先解释关键概念和方案，再实施；尽量让我自己理解和操作。

## 技术边界
- 当前引擎：Godot 4.x（以本地安装的实际版本为准）；优先 GDScript、Godot 内置节点和粒子系统，暂不引入 C++、GDExtension、Compute Shader，除非瓶颈被验证。
- 当前阶段：PC 2D/2.5D 原型。先完成粒子可见、可运动、重力方向切换、等效油阻尼、两类颗粒及基础反光。
- 暂不做移动端、前摄、动态壁纸、完整流体求解、真实粒间堆积、多人大框架或复杂编辑器。
- 物理与渲染分开：先以阻尼/重力比例近似流麻油；视觉油层材质不应影响粒子位置。
- `docs/archive/` 是历史资料；其中 UE/Niagara 内容**不能当成当前 Godot 实施指令**。

## 协作与教学
- 每次改动前说明：目标、涉及文件/节点、预期现象、最小反例测试和验收标准。
- 优先改动范围小、易回滚的内容。不要以“大重构”代替查明原因；一次主要只调整一个变量。
- 重要技术结论要标明是文档事实、实测结果还是暂时假设。
- 修改后用 MCP / Godot 实际验证可运行性；做不到时如实说明，不能声称测试通过。
- 每完成一个实验后先让我不看答案解释做法，再补充遗漏；Agent 不直接代替我完成复盘回答。
- 只有遇到值得复用的错误、关键决策或验证结果，才在 `docs/EXPERIMENTS.md` 追加简短记录；不写流水账。

## Git 与权限
- 尊重已有的文件改动；禁止擅自覆盖未提交工作、删场景、清历史、强推、改远端或修改 MCP 身份/认证配置。
- 创建公开远程仓库、提交大体积资源、引入第三方插件、安装依赖或做破坏性操作之前先征得确认。
- 若被明确要求初始化远程仓库，默认 GitHub **Private**，先检查忽略规则、暂存清单和敏感文件；使用现有 Git/gh 登录态，不读取或展示密钥。
- 完成一个可运行的实验可建议一次 Git commit；不要对每个细小调整自动 commit/push。

## 响应方式
- 用中文交流，简洁但解释清楚原因。介绍 Godot 新概念时，可以与 UE 作对应比较，但避免把两者当作完全等价。
- 每次结束时说明：已完成 / 尚未验证 / 下一步；最多给我 1～2 个闭卷回忆问题。

---

# 附录：Godot MCP 通道（本机实测，2026-11-12）

> 上面的规则优先。检查项目时按约定用只读命令；下面的通道说明只是告诉你「怎么连、有哪些命令、哪里会坑」。

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
- **git 走 Windows OpenSSH**：Git 自带的 MSYS `ssh.exe` 在这个沙箱里起不来（`couldn't create signal pipe, Win32 error 5`），远端操作前先 `$env:GIT_SSH = 'C:\Windows\System32\OpenSSH\ssh.exe'`。

