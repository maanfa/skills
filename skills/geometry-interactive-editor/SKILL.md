---
name: geometry-interactive-editor
description: 在浏览器（含 Electron）中用 JavaScript/TypeScript 开发地图或 canvas 几何“交互式编辑器”的通用最佳实践与 SOP。产物是无内置 UI、纯指令式、可被业务系统二次开发集成的可复用库，覆盖 2D（Leaflet/OpenLayers）与 3D（MapLibre GL/CesiumJS）及任意 canvas 几何编辑器。凡是用户提到地图绘制工具、几何编辑、图形标注、矢量要素编辑、canvas 图形编辑器、图层交互工具的开发需求，即使没明说“编辑器”，都应触发本技能。
---

# 前端通用交互式几何编辑器开发技能

## 这是什么

本技能约束在浏览器（含 Electron）中、用 JS/TS 编写“交互式编辑器”的最佳 SOP。编辑器指在地图或 canvas 上**绘制与编辑几何图形**（点/线/面、顶点拖拽、吸附）的可复用库。产物纯指令式、无内置 UI，可二次开发集成；不绑定具体地图库，但应在 2D（Leaflet、OpenLayers）与 3D（MapLibre GL、CesiumJS）上可运行。

## 核心思想

- **外观类统一入口**：一个 facade 类（类比 maplibre 的 map）接收地图总对象（Viewer / map / canvas），构造时校验可用性，直接拥有全部子控制器。
- **控制器装配**：外观类之下是鼠标事件管家（MouseEventManager）、绘制器（Drawer）、变更器（Modifier）、悬停器（Hover）、拾取器（Picker）、热键管理器（HotkeyManager）、指针管理器（CursorManager，可选）。
- **接口优先、组合优先**：优先用 interface 约束共同能力并用其组合 class；组合 > 继承，但不否定继承。
- **库无关、依赖单向**：core 与策略不感知地图库，依赖只出现在适配层。
- **双入口**：悬停、选中、编辑都具备画布交互与指令式两个入口，UI 通过函数调用联动。
- **竞态接管**：绘制 / 编辑 / 悬停之间的优先级与接管规则是本技能核心，见 `race-arbiter.md`。
- **状态即数据**：库不维护 undo/redo 历史，宿主用快照回放（getState/setState）。
- **推荐而非强制**：本技能所有类型、接口、命名、参数均为参考建议，调用者按需取舍、裁剪或重命名，不必照搬。

## 标准工作流

1. 外观类与控制器装配（`facade.md`、`architecture.md`）
2. 输入层：鼠标事件管家、热键管理器（`mouse-event-manager.md`、`hotkey-manager.md`）
3. 事件系统（`event-system.md`）
4. 几何模型与状态、元素与快照（`geometry.md`）、样式规范（`styles.md`）
5. 绘制器 / 变更器策略、拾取与竞态接管（`controllers.md`、`picker.md`、`race-arbiter.md`）
6. 悬停 / 选中 / 编辑行为与双入口（`canvas-interaction.md`）
7. 编辑辅助图形与整体变换器（`editing-helpers.md`、`transformers.md`）
8. 元素管理、日志、光标（`element-store.md`、`logging.md`、`cursor-manager.md`）
9. 坐标适配层与地图库适配器（`coords.md`、`adapters.md`）
10. 工程化：TS strict、单测、demo、打包（`build.md`）

## 质量验收（完成前自检）

- TypeScript `strict` 编译零错误；
- 核心逻辑（坐标换算、状态变更、命中检测、策略流转）有单元测试；
- 附可运行 demo（HTML 或 vite 示例），走通“绘制 → 编辑”闭环。

## 详细约束（按需查阅）

| 参考文档 | 内容 |
| --- | --- |
| `architecture.md` | 外观类、控制器装配、接口/组合、依赖方向 |
| `facade.md` | 外观类（Facade）总览：API 分组与装配 |
| `mouse-event-manager.md` | 鼠标事件管家与事件粒度 |
| `event-system.md` | 事件系统与事件目录 |
| `hotkey-manager.md` | 热键管理器与上下文 |
| `controllers.md` | 绘制/变更策略（策略+状态）与引擎机制 |
| `race-arbiter.md` | 竞态接管规则与仲裁器 |
| `picker.md` | 拾取器：命中检测与空间查询 |
| `canvas-interaction.md` | 画布交互：悬停/选中/编辑、双入口与取消接口 |
| `editing-helpers.md` | 编辑辅助图形（顶点/中点/距离标签、自持编号与精确编辑） |
| `transformers.md` | 整体编辑：平移/旋转/缩放变换器 |
| `geometry.md` | 几何原语、元素、状态与快照契约 |
| `styles.md` | 样式规范：line/fill/symbol/label 与着色器入口 |
| `element-store.md` | 元素管理：增删改查、空间查询、过滤 |
| `cursor-manager.md` | 指针管理器与三级优先级 |
| `logging.md` | 日志适配器 |
| `coords.md` | 坐标适配层与精度约束 |
| `adapters.md` | 2D/3D 地图库适配器约定 |
| `build.md` | 工程化：TS、单测、demo、打包发布 |
