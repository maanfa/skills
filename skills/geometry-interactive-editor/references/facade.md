# 外观类（Facade）总览

外观类（Facade）是宿主与编辑器之间**唯一的门面**，行为上类比 maplibre 的 `map` 对象。本文件是它的设计总结；各部分细节见对应文档。

> 命名统一为 **Facade**（别名 `EditorAppearance` / `Appearance`），**不用 `Map` 前缀**——封装对象可能是地图，也可能是纯 canvas 等非地图场景。实例名可自定义（品牌化）：`const duck = new Facade(host, { ... })`。

**关于 `duck`**：它只是外观实例的占位名——原则是“好记 + 不撞车”。为什么是鸭子？因为它既不咬人、也不会跟你的变量重名。实例名完全由开发者自定义，`hamburger`、你的产品名都可以。

## 1. 定位

- 构造接收**宿主总对象 `host`**，校验可用性，不可用即抛错；
- 直接拥有全部子控制器，并把输入源注入给 Drawer / Modifier；
- 所有对外阶段事件统一经它派发；
- **库无关**：只依赖控制器接口与 core 类型，不依赖具体地图库实现（渲染 / 输入由适配器承担，见 adapters.md）。

### host 是什么

`host` 是被封装的总对象，二选一：

- **地图场景**：地图库实例——Cesium `Viewer`、OpenLayers `map`、Leaflet `map`、MapLibre `Map`；
- **非地图场景**：canvas 宿主——如 `{ canvas: HTMLCanvasElement; width: number; height: number }` 结构体，或 canvas 元素 + 上下文。

构造器校验 `host` 的必要能力（`on/off`、canvas / 容器、尺寸）是否可用，不可用即抛带信息的错误。

```ts
// 被封装的总对象：地图实例或 canvas 宿主
interface EditorHost {
  canvas: HTMLCanvasElement;                       // 渲染画布
  width: number;                                   // 像素宽
  height: number;                                  // 像素高
  on?(event: string, handler: (evt: unknown) => void): unknown;   // 地图事件（可选，地图场景必有）
  off?(event: string, handler: (evt: unknown) => void): unknown;
  // 其余字段承载地图库实例（Cesium Viewer / OL map / Leaflet map / MapLibre Map…）
}
```

## 2. 构造与装配

```ts
const duck = new Facade(host, options);

interface FacadeOptions {
  adapter?: MapAdapter;         // 地图库适配器（缺省按 host 类型自动识别；可显式注入实例）
  logger?: LogAdapter;          // 日志适配器（缺省用 console 默认实现，见 logging.md）
  hotkeys?: boolean | HotkeyOptions;  // 是否装配热键管理器（建议 true，见 hotkey-manager.md）
  cursor?: boolean | CursorOptions;   // 是否装配指针管理器（true = 默认装配，见 cursor-manager.md）
  styles?: ElementStyles;       // 全局默认反馈样式（fallback），元素实例级可各自覆盖（见 canvas-interaction.md §7）
}
```

参数说明：

- **`adapter`**：实现 `MapAdapter` 的实例；不传则外观类按 `host` 类型自动识别并创建（Leaflet / OpenLayers / MapLibre / Cesium / canvas2d，见 adapters.md §0）。
- **`logger`**：`LogAdapter` 接口（`debug/info/warn/error`）；缺省用默认 console 实现。
- **`hotkeys`**：`true`（默认装配 + 常用绑定）或 `HotkeyOptions`（自定义绑定）；`false` 则不装配。
- **`cursor`**：`true`（默认装配）或 `CursorOptions`（注册图标、初始层）；`false` 则不装配。
- **`styles`**：`ElementStyles`（`hoverStyle / selectedStyle / editingStyle`）——**全局默认**，元素实例可各自配置覆盖（见 canvas-interaction.md §7）；复用 styles.md 的基础样式。

## 3. 控制器清单

| 控制器 | 必选 | 职责 | 详见 |
| --- | --- | --- | --- |
| MouseEventManager | 必选 | 鼠标事件管家 | mouse-event-manager.md |
| Drawer | 必选 | 绘制策略容器 | controllers.md |
| Modifier | 必选 | 变更策略容器 | controllers.md |
| HoverManager | 必选 | 悬停行为 | canvas-interaction.md |
| Picker | 必选 | 命中拾取 | picker.md |
| HotkeyManager | 可选（建议） | 键盘状态 | hotkey-manager.md |
| CursorManager | 可选 | 指针图标 | cursor-manager.md |
| ElementStore | 可选（建议） | 元素管理 / 统计 | element-store.md |

## 4. 对外 API 分组

```ts
interface Facade {
  // 生命周期
  attach(): void;
  detach(): void;

  // 事件（唯一出口，见 event-system.md）
  on<E extends keyof EditorEvents>(e: E, h: (p: EditorEvents[E]) => void): () => void;
  once<E>(e: E, h: (p: EditorEvents[E]) => void): () => void;
  off<E>(e: E, h: (p: EditorEvents[E]) => void): void;

  // 状态快照（undo/redo 由宿主回放，见 geometry.md §5）
  getState(): EditorState;
  setState(state: EditorState): void;

  // 元素管理（见 element-store.md）
  addElement(type: ElementType, params: ElementCreateParams): Element;   // 统一创建并入库（内部走 ElementFactory）
  removeElement(id: string): boolean;
  updateElement(el: Element, params: UpdateParams): void;   // 双参数，走同步链路
  findById(id: string): Element | undefined;
  search(geo: QueryGeometry, opts?: SearchOptions): Element[];

  // 绘制 / 编辑入口
  startDraw(type: ElementType, options?: DrawOptions): void; // 便捷方法，转发给 Drawer
  cancelDraw(): void;
  startEdit(id: string): void;
  cancelEdit(): void;

  // 选中 / 悬停（双入口之一，见 canvas-interaction.md）
  select(id: string): void;
  deselect(): DeselectResult;
  hover(id: string | null): void;
  unhover(): void;

  // 精确编辑辅助量（见 editing-helpers.md §6）
  setHandleValue(elementId: string, handle: HandleId, value: number): void;

  // 控制器 getter（如无必要可不暴露，保持门面最小）
  readonly mouse?: MouseEventManager;
  readonly drawer?: Drawer;
  readonly modifier?: Modifier;
  readonly hoverer?: HoverManager;
  readonly picker?: Picker;
  readonly hotkeys?: HotkeyManager;
  readonly cursor?: CursorManager;
  readonly store?: ElementStore;

  // 日志
  readonly logger: LogAdapter;
}
```

## 5. 双入口

画布交互（点击 / 划过）与指令式（函数调用）两个入口都由外观类提供，走同一套裁决逻辑（命中 → 标记 → 样式 → 事件），保证 UI 与画布一致（见 canvas-interaction.md §2）。

## 6. 事件出口

所有阶段事件（`draw:* / edit:* / hover:* / select:* / element:* / change`）经外观类实例派发；新增事件先在 event-system.md 目录登记（见 event-system.md §4）。

## 7. 相关文档

- 装配与依赖方向：architecture.md
- 竞态仲裁：race-arbiter.md
- 引擎机制：controllers.md
- 行为契约：canvas-interaction.md
