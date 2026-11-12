# FlowMahjong

用 Godot 复刻「流麻」——麻将牌里悬浮着缓慢流动的闪粉。

> 当前处于原型阶段：还没有主场景，正在验证粒子方案。

## 环境

- Godot **4.7.2**（mobile 渲染后端，Windows 下走 D3D12）
- 插件 `addons/godot_mcp_toolkit` v1.1.2：在编辑器进程内开一个 WebSocket MCP 服务，Agent 靠它读写真实工程

## 运行

1. 用 Godot 4.7.2 打开本目录的 `project.godot`
2. 主场景还没设；按 [docs/PROJECT.md](docs/PROJECT.md) 里的实验逐个打开运行

## 和 Agent 协作

先读 [AGENTS.md](AGENTS.md)——它既是协作约定，也是 MCP 通道的技术说明。
每次新会话，让 Agent 先读 `AGENTS.md`、`README.md`、`docs/PROJECT.md`、`docs/EXPERIMENTS.md`。

## 文档

| 文件 | 用途 | 更新时机 |
|---|---|---|
| [docs/PROJECT.md](docs/PROJECT.md) | 当前目标、技术选择、里程碑 | 阶段变化时 |
| [docs/EXPERIMENTS.md](docs/EXPERIMENTS.md) | 被推翻的判断、可复用的发现 | 有价值时才写 |
| [docs/archive/](docs/archive/) | 废弃方案（UE / Niagara） | 归档时 |

## 目录

```
scenes/   场景
scripts/  GDScript
addons/   第三方插件
docs/     项目文档
```
