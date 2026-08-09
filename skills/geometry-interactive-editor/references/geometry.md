# 几何模型、元素、状态与快照

## 1. 底层几何原语（Geometry）

几何原语是**最底层**的几何数据，不携带业务语义；上层数据对象 Element（见 §3）组合它。

**几何类型来源二选一**：

- **方案 A（推荐）**：直接复用官方 `geojson` 类型包（`geojson` / `@types/geojson`），Geometry 用其 `Point / LineString / Polygon`；坐标（Position）天然支持二维 / 三维（含高程），生态互操作最省心。
- **方案 B**：完全自定义类型，适合非经纬度、自定义维度语义的场景。

每类几何都带可编辑的**顶点**概念：编辑操作按顶点而非整条几何进行。

```ts
// 方案 A：复用官方 geojson 类型包
import type { Point, LineString, Polygon } from 'geojson';
type Geometry = Point | LineString | Polygon;   // 坐标支持 [x, y] 与 [x, y, z]

// 方案 B：完全自定义（type 判别字段也可按需命名，不必照抄 geojson 规范）
type Coord = [number, number] | [number, number, number];  // 语义由适配层决定
type Geometry =
  | { type: 'point'; coordinates: Coord }
  | { type: 'ring'; coordinates: Coord[] }
  | { type: 'face'; coordinates: Coord[][] };   // 示例判别名，可自定义
```

若 Element 需要 `mesh`（三角网格）等原生几何未覆盖的数据，可在元素层自行扩展，与上述原语并存（见 §3 渲染适配）。

## 2. 不可变性

- 模型数据一律视为不可变：编辑返回“新的几何 / 新状态”，不原地修改。
- 好处：快照对比、diff 计算、宿主缓存都更简单可靠。
- 实现可用浅拷贝 + 结构共享，数据量小时直接生成新对象也足够。

## 3. 元素（Element）数据对象

元素是**纯数据对象封装**，无状态管理——不感知任何控制器、不感知编辑，只是数据 + 能力方法。能力包括：

- **统一创建**：`ElementFactory` 为内部实现，**不对外导出**；对外经外观类 `addElement(type, params)` 创建并入库，保持外观对象的集中性；
- **更新**：`update({ geometry | style })` 返回新元素；
- **快照**：`snapshot()` 深拷贝，供持久化与 undo/redo；
- **取样式**：`getStyle()` / `getStyleFor(state)` 获取基础样式与指定反馈样式，与快照一样是只读查询；
- **基本能力**：稳定 `id`、可读 `name`；
- **标记**：`hoverable / editable`（见 architecture.md），决定是否被悬停器 / 变更器接管。

`ElementType` 是**建议值集合**，不要求全部实现；按项目需要取子集即可：

```ts
type ElementType =
  | 'marker'      // 图标 + 文字
  | 'label'       // 仅文字
  | 'billboard'   // 仅图标
  | 'polyline'    // 单线
  | 'polygon'     // 单面（可带洞）
  | 'circle'      // 圆心 + 半径（底层仍是多边形）
  | 'mesh'        // 纯三角形几何输入
  | 'prism'       // 棱柱（多部件）
  | 'cylinder';   // 圆柱（多部件）

interface Element {
  readonly id: string;
  readonly name: string;
  readonly type: ElementType;
  geometry: Geometry | Geometry[];   // 多部件类型（prism/cylinder 等）可为数组
  style?: ElementStyle;              // 元素自身基础样式（每个实例可不同）
  hoverStyle?: ElementStyle;         // 悬停反馈（实例级，可选）
  selectedStyle?: ElementStyle;      // 选中反馈（实例级，可选）
  editingStyle?: ElementStyle;       // 编辑反馈（实例级，可选）
  readonly hoverable: boolean;
  readonly editable: boolean;

  update(partial: {
    geometry?: Geometry | Geometry[];
    style?: ElementStyle;
    hoverStyle?: ElementStyle;
    selectedStyle?: ElementStyle;
    editingStyle?: ElementStyle;
    name?: string;
  }): Element;
  getStyle(): ElementStyle | undefined;                                      // 获取基础样式
  getStyleFor(state: 'hover' | 'selected' | 'editing'): ElementStyle | undefined;  // 获取指定反馈样式
  snapshot(): ElementSnapshot;       // 深拷贝，供持久化 / undo-redo
}
```

样式是**实例级**的：每个元素可各自配置基础样式与悬停 / 选中 / 编辑反馈样式；外观类的 `styles` 只是**全局默认（fallback）**，元素实例未配置时兜底（解析优先级见 canvas-interaction.md §7）。
```

样式规范（LineStyle / FillStyle / SymbolStyle / LabelStyle、颜色与透明度约定、自定义着色器入口）见独立文档 `styles.md`。

### 各类型语义与构造参数

| 类型 | 语义 | 构造参数（示例） |
| --- | --- | --- |
| `marker` | 图标 + 文字 | `{ coord, icon, text }` |
| `label` | 仅文字 | `{ coord, text }` |
| `billboard` | 仅图标 | `{ coord, icon }` |
| `polyline` | 单线 | `{ coords }` |
| `polygon` | 单面，可带洞 | `{ rings, holes }` |
| `circle` | 圆心 + 半径，底层仍是多边形 | `{ center, radius, segments }` |
| `mesh` | 纯三角形几何输入 | `{ positions: Float32Array, indices: Uint32Array }` |
| `prism` | 棱柱（多部件） | `{ base, height }` |
| `cylinder` | 圆柱（多部件） | `{ center, radius, height, segments }` |

```ts
type ElementCreateParams = Record<string, unknown>;   // 具体字段见上表，内部按 type 校验

// 对外统一入口：外观类 addElement(type, params)，内部按 kind 分发到 ElementFactory
duck.addElement('polygon',  { rings, holes });
duck.addElement('marker',   { coord, icon, text });
duck.addElement('circle',   { center, radius, segments: 64 });
duck.addElement('prism',    { base, height });
duck.addElement('mesh',     { positions, indices });
```

### 渲染适配

- **通用方案**：经适配层（MapAdapter，见 adapters.md）把 Element 翻译为地图库 / canvas 库的数据对象。
- **单库集成**：若只针对某个地图库设计，Element 可放弃数据对象适配器，直接集成该库提供的类型——如 Cesium 的 `Primitive`、`PrimitiveCollection`、`LabelCollection` 等，`geometry` / 渲染字段直接承载对应对象。

## 4. 状态是唯一事实来源

`EditorState` 携带元素数组，是全部数据的唯一权威；`ElementStore` **不重复存储**，它只是对该元素集合的增删改查 / 查询接口（见 element-store.md）。

```ts
interface EditorState {
  elements: Element[];                 // 元素数据（唯一权威）
  activeElementId: string | null;      // 当前选中 / 编辑的元素
  mode: 'view' | 'draw' | 'edit';      // 当前交互模式
  drawType?: ElementType;              // draw 模式下的目标类型
}
```

**为什么权威数据用数组而非 Map / Set**：快照（`getState / setState`）需要深拷贝与结构化克隆，数组天然可 JSON 序列化、可做纯函数变换与 diff、可保持稳定插入顺序（z 层级 / 绘制顺序）；Map / Set 的 O(1) 查找优势由 ElementStore 内部用 `Map<id, Element>` + 空间索引补足（见 element-store.md §5），不必牺牲状态的序列化能力。

## 5. 快照契约（替代命令栈 / undo-redo）

库**不维护历史**。撤销 / 重做由宿主基于快照实现，库只提供两个方法：

```ts
getState(): EditorState;               // 导出当前状态（返回深拷贝）
setState(state: EditorState): void;    // 整体替换状态，触发一次 change 事件
```

宿主用法：里程碑动作前保存一份 `getState()` 结果；撤销 `setState(prev)`、重做 `setState(next)`。

约束：

- `getState` 必须返回深拷贝，防止宿主误改库内部状态。
- `setState` 必须做一致性校验（重复 id、非法几何），不合法则拒绝并抛出带信息的错误。
- `setState` 与普通编辑动作一样，只派发一次 `change` 事件（合并见 event-system.md）。

## 6. 快照与持久化

- 库**只提供快照**（`getState()` / `element.snapshot()`），**不内置任何格式的序列化**——要转 GeoJSON 等格式由调用方自行完成。
- 快照必须是纯数据（无函数、无循环引用），保证可结构化克隆与存储。

## 7. 编辑操作 = 对状态做纯函数变换

每个编辑动作可表示为 `(state, action) => nextState` 的纯函数，由变更器内部调度：

- 顶点拖拽：`moveVertex(state, elementId, vertexIndex, newCoord)`
- 添加 / 删除顶点、闭合 / 断开、吸附等同理。

纯变换让单测、快照 diff、宿主自定义操作都变得容易。

## 8. 分支状态检测

几何层提供分支状态检测的**纯函数能力**，由绘制 / 编辑策略调用：

- `isSelfIntersecting(geometry): boolean`（多边形 / 棱柱边自交）；
- 策略检测到分支后派发 `draw:branch-triggered` / `edit:branch-triggered`（见 controllers.md §4 与 event-system.md 目录）。

纯函数便于单测，也是单测优先覆盖的逻辑之一。

## 9. ID 体系

- 元素 id 由库生成（uuid / 自增前缀），宿主不应依赖其格式；也允许宿主传入以维持业务关联。
- id 在库运行期间唯一且稳定。
