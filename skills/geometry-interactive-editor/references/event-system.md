# 事件系统与对外通信

## 1. 事件库选型

- 默认采用 EventEmitter3 这类 TypeScript 友好的事件库（泛型事件表、退订返回函数）。
- 若认为依赖过重、想完全自集成，或该库未来过期，可自封装最小事件库，接口对齐即可：
  - `on(event, handler): () => void`
  - `once(event, handler): () => void`
  - `off(event, handler)`
  - 泛型事件映射表（事件名 → 载荷类型）

## 2. 事件分层

- **输入事件**：由 MouseEventManager / HotkeyManager 产出（`leftdown`、`mousemove`、`keydown` 等）。
- **元素事件**：`element:added / element:changed / element:removed`，含分支状态事件。
- **阶段事件**：绘制/编辑/悬停各阶段（开始、进行、结束、取消、悬停进入/离开、选中/取消选中、进入/退出编辑）。
- **生命周期事件**：`attached / detached`。

## 3. 对外通信（阶段事件）

- 绘制、编辑、悬停的每个阶段都必须**通过外观类实例对外派发事件**，宿主据此做 UI 提示、画布辅助元素等联动。
- 事件载荷一律用 core 类型，不得用地图库类型。

## 4. 事件目录（唯一权威清单）

| 事件 | 载荷 | 触发方 |
| --- | --- | --- |
| `draw:started` | `{ drawType }` | Drawer |
| `draw:vertex-added` | `{ point }` | Drawer |
| `draw:vertex-removed` | `{ index }` | Drawer |
| `draw:finished` | `{ geometry }` | Drawer |
| `draw:cancelled` | `{ branch? }` | Drawer |
| `draw:branch-triggered` | `{ branch, draft, allowed }` | Drawer 策略 |
| `edit:started` | `{ elementId }` | Modifier |
| `edit:ended` | `{ elementId }` | Modifier |
| `edit:switched` | `{ from, to }` | Modifier |
| `edit:handle-selected` | `{ elementId, handle, value }` | Modifier |
| `edit:handle-hover-enter` | `{ elementId, handle }` | Modifier |
| `edit:handle-hover-leave` | `{ elementId, handle }` | Modifier |
| `edit:vertex-dragging` | `{ elementId, vertexIndex }` | Modifier |
| `edit:vertex-dragged` | `{ elementId, vertexIndex, coord }` | Modifier |
| `edit:transform-dragging` | `{ elementId, kind: 'translate' \| 'rotate' \| 'scale', delta }` | Modifier / TransformerManager |
| `edit:transform-dragged` | `{ elementId, kind, result }` | Modifier / TransformerManager |
| `edit:branch-triggered` | `{ branch, elementId, allowed }` | Modifier 策略 |
| `hover:enter` | `{ elementId, hitPoint }` | HoverManager |
| `hover:leave` | `{ elementId }` | HoverManager |
| `select:changed` | `{ elementId: string \| null }` | 外观类 |
| `select:cancel-rejected` | `{ reason }` | 仲裁器 / 外观类 |
| `element:added` | `{ element }` | 外观类 |
| `element:changed` | `{ elementId, previous, current }` | 外观类 |
| `element:removed` | `{ elementId }` | 外观类 |
| `change` | `EditorState` | 外观类 |
| `attached` / `detached` | `{}` | 外观类 |

新增阶段事件时：先在**此处登记**，再在对应控制器实现，避免事件名漂移。

上表的 TypeScript 类型化版本（供 `on/once/off` 与宿主订阅用）：

```ts
interface EditorEvents {
  attached: void;
  detached: void;
  change: EditorState;

  'element:added': { element: Element };
  'element:changed': { elementId: string; previous: Element; current: Element };
  'element:removed': { elementId: string };

  'draw:started': { drawType: ElementType };
  'draw:vertex-added': { point: WorldCoord };
  'draw:vertex-removed': { index: number };
  'draw:finished': { geometry: Geometry };
  'draw:cancelled': { branch?: string };
  'draw:branch-triggered': { branch: string; draft: unknown; allowed: boolean };

  'edit:started': { elementId: string };
  'edit:ended': { elementId: string };
  'edit:switched': { from: string; to: string };
  'edit:handle-selected': { elementId: string; handle: HandleId; value: number };
  'edit:handle-hover-enter': { elementId: string; handle: HandleId };
  'edit:handle-hover-leave': { elementId: string; handle: HandleId };
  'edit:vertex-dragging': { elementId: string; vertexIndex: number };
  'edit:vertex-dragged': { elementId: string; vertexIndex: number; coord: WorldCoord };
  'edit:transform-dragging': { elementId: string; kind: 'translate' | 'rotate' | 'scale'; delta: Vec3 };
  'edit:transform-dragged': { elementId: string; kind: 'translate' | 'rotate' | 'scale'; result: unknown };
  'edit:branch-triggered': { branch: string; elementId: string; allowed: boolean };

  'hover:enter': { elementId: string; hitPoint: WorldCoord };
  'hover:leave': { elementId: string };

  'select:changed': { elementId: string | null };
  'select:cancel-rejected': { reason: string };
}
```

`EditorEvents` 由外观类实现（`on/once/off` 的泛型事件表，见 facade.md）。

## 5. 触发时机

- 事件在**状态已更新、渲染尚未发生**时派发，保证处理函数读到一致状态。
- 处理函数抛错不得中断派发链：统一捕获并 console.error，避免一个 handler 影响其他。

## 6. 批量合并

- 一次“逻辑操作”只派发一个最终事件（如一次拖拽结束只发一次 `element:changed` + `change`）。
- 事件携带最新状态，不携带中间态。

## 7. 同步 vs 异步

- 默认同步派发（简单可预测）。
- 适配器需要合并渲染时，由该适配器在收到事件后用 rAF 批量绘制——events 负责“通知”，渲染时机归适配器。
