# 控制器引擎：绘制器、编辑器、悬停器

本文件讲“控制器内部怎么工作”（引擎机制）；竞态与仲裁见 `race-arbiter.md`，对外行为契约见 `canvas-interaction.md`，事件清单见 `event-system.md`。

## 1. 策略 + 状态 双层模式

Drawer / Modifier 是**策略容器**：只负责数据吞吐与下发——订阅输入 → 路由给当前策略 → 收策略结果 → 更新状态 / 派发事件。它们不感知各策略内部的子状态。

具体策略对象用**状态模式**：每个策略内部管理自己的子状态机（如绘制策略：`idle → placing-vertex → completed`；编辑策略：`idle → dragging-auxiliary → done`），自管迁移与退出。

### 策略接口

可细粒度对应 MouseEventManager 事件，也可保留单一 `onMouse`，由开发者自选：

```ts
// 细粒度版（推荐）：与 MouseEventManager 派发事件一一对应
interface IDrawStrategy {
  readonly name: string;
  onLeftDown?(evt: MouseInputEvent): void;
  onLeftUp?(evt: MouseInputEvent): void;
  onMouseMove?(evt: MouseInputEvent): void;
  onLeftClick?(evt: MouseInputEvent): void;
  onDoubleClick?(evt: MouseInputEvent): void;
  onHotkey(h: HotkeyManager): void;               // 上下文注入
  onElementUpdated?(element: Element, prev: Element): void; // 指令式更新同步
  complete(): void;
  cancel(): void;
}

// 简化版（可选）：单一 onMouse 由容器转发
interface IDrawStrategySimple {
  onMouse(evt: MouseInputEvent): void;
  // ...其余同上
}

interface IModifyStrategy {
  readonly name: string;
  onLeftDown?(evt: MouseInputEvent): void;
  onLeftUp?(evt: MouseInputEvent): void;
  onMouseMove?(evt: MouseInputEvent): void;
  onHotkey(h: HotkeyManager): void;
  apply(motion: EditMotion): void;                // 消费辅助图形的运动量
  onElementUpdated?(element: Element, prev: Element): void;
  cancel(): void;
}
```

装配与路由：Drawer / Modifier 在 attach 时由外观类注入 MouseEventManager 与 HotkeyManager（若装配）；输入先到容器，容器按当前模式路由到对应策略。

## 2. 竞态与仲裁

- 所有控制器（HoverManager / Drawer / Modifier / Picker）的输入**先经仲裁器问询**（`race-arbiter.md`），拿到允许才继续，否则让位。
- 本节不再重复竞态规则表与仲裁器设计，详见 `race-arbiter.md`。

## 3. 热键与取点模式（PickMode）

各策略对象必须监听热键（见 hotkey-manager.md），因为交互中键盘会实时改变逻辑：

- **Shift**：吸附（端点 / 网格 / 角度）、沿固定角度继续画。
- **Esc**：退出当前草稿，或回退当前编辑量（回到拖拽前状态）。
- **Backspace**：删除上一个添加的点（绘制）或删除选中顶点（编辑）。

### PickMode 详细定义

策略对象在 `mousemove` 时如何把屏幕点解析为“更新几何所用的点”：

```ts
type PickCallback = (screen: ScreenCoord, state: EditorState) => WorldCoord | null;

// 可辨识联合：kind 始终是字面量，可直接收窄
type PickMode =
  | { kind: 'free' }                          // 按射线与几何 / 参考面的交点取点
  | { kind: 'plane'; plane: PlaneInfo }       // 按固定平面取点（如水平面）
  | { kind: 'axis'; axis: AxisInfo }          // 按固定轴向取点
  | { kind: 'custom'; pickCallback: PickCallback };  // 自定义：回调随取点模式携带
```

- 3D 顶点拖拽时 `leftdown / leftup` 无法区分取点方式，**必须给定 PickMode**；无输入口则拒绝进入这类有歧义的编辑。
- 来源：热键（按住键切换轴 / 平面），或外观类指令式 `setPickMode(...)` / 宿主传参。
- 策略对象持有当前 PickMode 状态，`mousemove` 按它解析点，再交给编辑逻辑。

### 自定义取点模式（扩展点）

内置三种之外，直接以**回调**扩展——取点函数随 `PickMode` 对象一起传递，无需全局注册：

```ts
const customPick: PickMode = {
  kind: 'custom',
  pickCallback: (screen, state) => projectToMySurface(screen, state),
};
```

策略对象在 `mousemove` 中按 `kind` 收窄处理：

```ts
switch (this.pickMode.kind) {
  case 'free':   return this.coords.screenToWorld(evt.screen, { pickElevation: true });
  case 'plane':  return rayPlaneIntersect(evt.screen, this.pickMode.plane);
  case 'axis':   return projectToAxis(evt.screen, this.pickMode.axis);
  case 'custom': return this.pickMode.pickCallback(evt.screen, this.editorState);
}
```

说明：回调内联的优点是——判别字段始终是字面量 `'custom'`、无需全局可变注册表、可随用随传；代价是函数不可序列化，但取点模式本就是瞬时输入、不进快照，可接受。若确需“按名字复用 / 配置一批取点器”，可另做注册表，那是可选增强而非必需。

## 4. 分支状态与入口参数

编辑 / 绘制过程中可能出现的分支状态（如多边形 / 棱柱边自交）由策略检测并派发事件；分支不多时通过外观类入口方法参数直接裁决行为：

```ts
interface DrawOptions {
  allowSelfIntersect?: boolean;      // 自交时不允许落点（编辑场景则回退前一状态）
  allowCompleteOnBranch?: boolean;   // 分支状态是否允许完成
  branchStyle?: ElementStyle;        // 分支状态时的样式（见 styles.md）
  pickMode?: PickMode;               // 初始取点模式
  style?: ElementStyle;              // 新元素基础样式（实例级）
  hoverStyle?: ElementStyle;         // 新元素悬停反馈（实例级）
  selectedStyle?: ElementStyle;      // 新元素选中反馈（实例级）
  editingStyle?: ElementStyle;       // 新元素编辑反馈（实例级）
}

duck.startDraw('polygon', {
  allowSelfIntersect: false,        // 自交时不允许落点
  allowCompleteOnBranch: false,     // 分支状态不允许完成
  branchStyle: { line: { color: '#e11', opacity: 1, width: 2 } }, // 分支状态样式
  style:         { line: { color: '#36f', opacity: 1, width: 2 } },
  selectedStyle: { line: { color: '#ff8c00', opacity: 1, width: 3 } },
});
```

分支状态 demo（多边形绘制策略，`emit` 为策略注入的事件出口）：

```ts
// 草稿：有序顶点序列（未闭合）
class PolygonDraft {
  readonly points: Coord[] = [];
  concat(p: Coord): PolygonDraft {
    const d = new PolygonDraft();
    d.points.push(...this.points, p);
    return d;
  }
  closeRing(): Geometry {
    return { type: 'polygon', coordinates: [this.points.concat(this.points[0])] };
  }
}

// 极简自交检测（几何层纯函数，见 geometry.md §8）：任取两条非相邻边判断相交
function isSelfIntersecting(geo: Geometry): boolean {
  if (geo.type !== 'polygon') return false;
  const ring = geo.coordinates[0];
  const segs: [Coord, Coord][] = ring.map((p, i) => [p, ring[(i + 1) % ring.length]]);
  for (let i = 0; i < segs.length; i++) {
    for (let j = i + 1; j < segs.length; j++) {
      if (j === i + 1 || (i === 0 && j === segs.length - 1)) continue;   // 跳过相邻边
      if (segmentsIntersect(segs[i], segs[j])) return true;
    }
  }
  return false;
}

function segmentsIntersect(a: [Coord, Coord], b: [Coord, Coord]): boolean {
  const [[ax1, ay1], [ax2, ay2]] = a;
  const [[bx1, by1], [bx2, by2]] = b;
  const cross = (ox: number, oy: number, px: number, py: number, qx: number, qy: number) =>
    (px - ox) * (qy - oy) - (py - oy) * (qx - ox);
  return (
    cross(ax1, ay1, ax2, ay2, bx1, by1) * cross(ax1, ay1, ax2, ay2, bx2, by2) < 0 &&
    cross(bx1, by1, bx2, by2, ax1, ay1) * cross(bx1, by1, bx2, by2, ax2, ay2) < 0
  );
}

class PolygonDrawStrategy implements IDrawStrategy {
  private draft: PolygonDraft = new PolygonDraft();
  private allowSelfIntersect: boolean;
  private allowCompleteOnBranch: boolean;
  private emit: <K extends keyof EditorEvents>(k: K, p: EditorEvents[K]) => void;

  onLeftDown(evt: MouseInputEvent): void {
    const point = evt.picked!.point;                 // 命中点（世界坐标）
    const next = this.draft.concat(point);
    if (isSelfIntersecting(next)) {
      this.emit('draw:branch-triggered', {           // 事件通知外部
        branch: 'self-intersection',
        draft: next,
        allowed: this.allowSelfIntersect,
      });
      if (!this.allowSelfIntersect) return;          // 不允许落点：丢弃本次，回到上一状态
    }
    this.draft = next;
    this.emit('draw:vertex-added', { point });
  }

  complete(): void {
    const finished = this.draft.closeRing();
    if (isSelfIntersecting(finished) && !this.allowCompleteOnBranch) {
      this.emit('draw:cancelled', { branch: 'self-intersection' });
      return;
    }
    this.emit('draw:finished', { geometry: finished });
  }
}
```

## 5. 指令式更新的同步链路

编辑期间，外部可能直接经外观类函数调用更新元素（UI 联动）。此时更新链路除了更新被编辑元素，还必须**同步告知策略对象、变更器对象与辅助元素**：

1. 更新元素仓库 / 状态（数据先行）；
2. 通知变更器（`Modifier`）；
3. 变更器通知当前变更策略对象（`onElementUpdated`）；
4. 策略对象同步其辅助元素（`EditorVertexHelper` / `TransformerManager` 重新定位顶点、变换手柄）；
5. 派发 `element:changed` → 适配层刷新渲染。

```ts
// 更新接口双参数：第一个是元素本身，第二个是更新参数结构体
interface UpdateParams {
  geometry?: Geometry;
  style?: ElementStyle;
  hoverStyle?: ElementStyle;
  selectedStyle?: ElementStyle;
  editingStyle?: ElementStyle;
  properties?: Record<string, unknown>;
}

// duck 是什么？你别管，你封装什么它是什么——也可能是 cat
duck.updateElement(element: Element, params: UpdateParams): void {
  const prev = this.store.get(element.id);
  const next = { ...element, ...params };                             // 1. 数据
  this.store.set(next);
  this.modifier.onElementUpdated(next, prev);                         // 2. 变更器
  this.modifier.currentStrategy?.onElementUpdated?.(next, prev);      // 3. 策略
  this.modifier.helpers.sync(next);                                   // 4. 辅助元素
  this.emit('element:changed', { elementId: next.id, previous: prev, current: next }); // 5. 事件
}
```

链路顺序固定：数据 → 逻辑对象 → 辅助元素 → 渲染 / 事件，保证各环节读到的状态一致。

## 6. 生命周期

- attach：容器订阅 MouseEventManager、HotkeyManager；注册当前策略。
- detach：策略退出子状态、注销，容器全部解绑，避免泄漏。
