# 编辑辅助图形（EditorVertexHelper 与编辑态装饰）

## 1. 定位

编辑是基于选中的高阶模式。进入编辑后，画布上会出现服务于编辑的辅助图形——顶点手柄、中点手柄、距离标签、半径线、垂线、轴向辅助线等。这些图形**仅存在于编辑态**，退出编辑即销毁。

编辑模式互斥，一次只激活一个：

- **点模式**（基础）：`EditorVertexHelper` 提供顶点 / 中点 / 圆心手柄与标签类辅助图形。
- **线模式 / 面模式**：需要更高阶辅助元素（多段、孔洞环、细分等），机制相同，本技能不展开细述。
- **整体模式**（最高阶）：走变换器，见 `transformers.md`。

## 2. 轻量原则

辅助图形必须比被编辑元素轻量：

- 是纯展示 / 拾取用的临时对象，**不进入元素仓库**（ElementStore），不参与业务状态；
- 不携带业务数据，只持有定位所需的几何量（坐标、方向、轴向）；
- 由 `EditorVertexHelper` 统一创建与回收。

## 3. 辅助图形清单

| 图形 | 可交互 | 用途 |
| --- | --- | --- |
| 顶点手柄 | 是 | 拖拽移动顶点 |
| 中点手柄 | 是 | 在线段中点加顶点 / 拖拽 |
| 圆心手柄 | 是 | 拖拽圆心（圆 / 弧） |
| 距离标签 | 否 | 显示边长 / 半径等测量值 |
| 半径线 | 否 | 表示圆 / 弧半径方向 |
| 垂线 | 否 | 显示垂足 / 正交约束 |
| 轴向辅助线 | 否 | 表示当前取点平面 / 轴向（配合 PickMode） |

只有“可交互”的辅助图形（手柄类）才接收画布事件；纯展示图形（标签、辅助线）不接收。

### 辅助图形类名推荐

与 architecture.md 常用类名同风格，辅助图形按角色命名（PascalCase）：

| 角色 | 推荐类名 | 可交互 | 说明 |
| --- | --- | --- | --- |
| 顶点手柄 | `VertexHandle` | 是 | 拖拽移动顶点 |
| 中点手柄 | `MidpointHandle` | 是 | 在线段中点加顶点 / 拖拽 |
| 圆心手柄 | `CenterHandle` | 是 | 拖拽圆心 |
| 距离标签 | `DistanceLabel` | 否 | 显示边长 / 半径等测量值 |
| 半径线 | `RadiusLine` | 否 | 表示圆 / 弧半径方向 |
| 垂线 | `PerpendicularLine` | 否 | 显示垂足 / 正交约束 |
| 轴向辅助线 | `AxisGuideLine` | 否 | 表示当前取点平面 / 轴向 |

公共契约用接口约束。**可交互手柄** 统一实现 `IHandle`（带稳定 `HandleId`）：

```ts
interface IHandle {
  readonly id: string;                 // 稳定编号（对应 HandleId）
  hitTest(screen: ScreenCoord, tolerance: number): boolean;
  onHover?(entered: boolean): void;
  onDrag?(motion: EditMotion): void;   // 拖拽 → 向上发射运动量
  render(ctx: RenderCtx): void;
}
```

**纯展示图形**（标签 / 辅助线）只实现轻量的 `IHelper`（挂载 / 同步 / 销毁），不参与交互：

```ts
interface IHelper {
  attach(element: Element): void;
  sync(element: Element): void;
  detach(): void;
}
```

命名要点：手柄类用 `XxxHandle`（可交互、带 `HandleId`），展示类用 `XxxLabel / XxxLine`（纯展示），统一由 `EditorVertexHelper` 创建与回收。

### 辅助图形的 hover 能力

可交互的辅助图形同样具备 hover 能力，因为鼠标指针可能受其影响：

- 鼠标划过手柄时进入“手柄悬停”状态，派发 `edit:handle-hover-enter` / `edit:handle-hover-leave`（携带 `{ elementId, handle }`），外部据此做高亮 / 光标变化。
- 手柄悬停驱动 CursorManager 的**瞬时优先级**指针（如 `move` / `grab` / 旋转光标），移出后回落到状态 / 空闲优先级（见 cursor-manager.md）。
- 编辑态内，**手柄的 hover 优先于被编辑元素的 hover**：正在编辑的元素，其元素级悬停让位于手柄级悬停，避免光标 / 高亮打架。

## 4. 输入流（Modifier → 辅助图形）

辅助图形的画布交互不直接消费输入：

- Modifier 把鼠标事件**向下传递**给当前策略对象及辅助图形（`onLeftDown / onMouseMove / onLeftUp`）；
- 消费键盘热键状态（如按住 Shift 限制角度）；
- 只把事件送达当前编辑模式的辅助图形，其余互斥模式不接收。

## 5. 输出流（辅助图形 → 策略）

辅助图形的运动结果**向上发射**：

- 拖拽手柄时发出 `edit:vertex-dragging`（携带 elementId、手柄类型、运动量 / 新坐标）；
- 松手发出 `edit:vertex-dragged`；
- Modifier 把运动量**分配给当前编辑策略对象**（`apply(motion)`），由策略按当前阶段做逻辑运算，最终更新被编辑元素。

这样辅助图形不感知几何算法，策略不感知图形表现，各自可替换。

```ts
// 辅助图形产生的运动量（向上发射给策略）
// 可辨识联合（discriminated union）：按 kind 判别，每种 kind 的字段固定且互斥
type EditMotion =
  | {
      kind: 'vertex';
      elementId: string;
      handle: { kind: 'vertex'; index: number };
      from: WorldCoord;          // 拖拽前坐标
      to: WorldCoord;            // 拖拽后坐标
      pickMode: PickMode;
    }
  | {
      kind: 'midpoint';
      elementId: string;
      handle: { kind: 'midpoint'; index: number };
      from: WorldCoord;
      to: WorldCoord;
      pickMode: PickMode;
    }
  | {
      kind: 'center';
      elementId: string;
      handle: { kind: 'center' };
      from: WorldCoord;
      to: WorldCoord;
      pickMode: PickMode;
    }
  | {
      kind: 'transform';
      elementId: string;
      handle: { kind: 'transform'; transformer: 'translate' | 'rotate' | 'scale' };
      delta: Vec3;               // 平移向量 / 旋转增量角 / 缩放因子，由策略按 transformer 解释
      pickMode: PickMode;
    };
```

## 6. 自持编号与精确编辑

每个可交互辅助图形持有**稳定编号**（`HandleId`），编辑期间不变，作为程序化寻址句柄。这使外部可以不走画布交互、直接精确操作某一辅助量（`duck` 是什么？你别管，你封装什么它是什么——也可能是 `cat`）：

```ts
type HandleId =
  | { kind: 'vertex'; index: number }
  | { kind: 'midpoint'; index: number }
  | { kind: 'center' }
  | { kind: 'transform'; transformer: 'translate' | 'rotate' | 'scale' };
```

- **精确寻址接口**：`duck.setHandleValue(elementId, handle, value)` —— 精确更新某个顶点坐标 / 中点位置 / 半径等；与画布交互走**同一条同步链路**（数据 → 策略 → 辅助图形 → 事件，见 controllers.md §5），保证结果一致。
- **独立的辅助图形选中模式**：点击手柄即进入该手柄的“二级编辑（精确编辑）”状态。Modifier（或其它控制器）向外派发 `edit:handle-selected`（携带 `{ elementId, handle, value }`），外部据此把数值输入框绑定到该辅助量——用户改数值 → 调 `setHandleValue` 精确更新。

```ts
// 外观类精确更新某一辅助量（函数调用，非画布交互）
duck.setHandleValue(elementId: string, handle: HandleId, value: number): void;
```

- 精确更新与画布拖拽最终都归结为 `EditMotion` 交给当前策略对象 `apply(motion)`，两条入口行为一致。

## 7. 生命周期

- 进入编辑（`duck.startEdit(id)`）：Modifier 创建编辑态辅助图形（`EditorVertexHelper` 挂载）；
- 退出编辑（`duck.cancelEdit()` / 切换编辑元素）：统一销毁辅助图形，避免残留；
- 指令式更新（`duck.updateElement`）时，辅助图形经同步链路（controllers.md §5）重新定位。
