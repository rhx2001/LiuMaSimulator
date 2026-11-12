# liumasimulator

一个以 **Godot 4.x** 开发的 PC 流麻（透明流沙/亮片）模拟实验，同时用于逐步学习 Godot 的场景、粒子、材质和渲染系统。

> 仓库：[github.com/rhx2001/LiuMaSimulator](https://github.com/rhx2001/LiuMaSimulator)（Private）
> 本机环境：Godot 4.7.2 · mobile 渲染后端 · Windows / D3D12（PC 只做功能验证，最终目标是移动端）

## 当前阶段

首个里程碑不是“真实流体”，而是：在一个二维容器中看见粒子运动，能够改变重力方向和等效阻尼，并解释每个行为来自哪里。

- 当前设计与验收标准：[`docs/PROJECT.md`](docs/PROJECT.md)
- 实验与学习记录：[`docs/EXPERIMENTS.md`](docs/EXPERIMENTS.md)
- Agent 协作规则：[`AGENTS.md`](AGENTS.md)
- 早期 UE / Niagara 草案：`docs/archive/`，**仅供参考，不是当前待办**

## 使用方式

在包含 `project.godot` 的项目根目录打开 Godot。把本文档包的文件合并到同一目录（**不要覆盖已有文件**）；不要把整个包作为另一个嵌套 Godot 项目。

开始前，确认本机 Godot 具体版本、当前渲染器和已有项目资源。初期没有必须安装的第三方依赖。

## 记笔记约定

只有在一个现象让我们修正判断、解决了真实错误或得到可复用经验时，才向 `docs/EXPERIMENTS.md` 补一条 3～5 行记录。代码、场景文件和 Git commit 本身也是文档，不抄长篇教程。
