# 指针管理器（CursorManager）

## 1. 定位

管理画布上的鼠标指针图标：**可配置、注册图标**，通过上下文注入到热键管理器、绘制 / 编辑阶段对象（见 hotkey-manager.md、editing-helpers.md）。

## 2. 接口与图标注册

```ts
type CursorKind =
  | 'default' | 'crosshair' | 'grab' | 'grabbing' | 'move' | 'pointer'
  | 'text' | 'not-allowed'
  | 'rotate' | 'scale'
  | 'ew-resize' | 'ns-resize' | 'nesw-resize' | 'nwse-resize'
  | 'custom';                       // 自定义图标

type Cursor = {
  name: string;
  icon: string;                    // CSS cursor 值或 SVG/data-URL
};
type CursorLayer = 'idle' | 'state' | 'transient';

interface CursorManager {
  set(kind: CursorKind, cursor: Cursor): void;     // 注册 / 覆盖某类指针
  apply(layer: CursorLayer, kind: CursorKind): void; // 在指定优先级层应用某类指针
  reset(): void;                                   // 清空所有层，回到 idle
}
```

外观类装配参数 `cursor`（见 facade.md）即构造 CursorManager 的选项：

```ts
interface CursorOptions {
  icons?: Partial<Record<CursorKind, Cursor>>;    // 覆盖默认图标
  initial?: CursorLayer;                          // 初始层
}
```

## 3. 三级优先级

**瞬时（transient）> 状态（state）> 空闲（idle）**

- **瞬时（transient）**：随键鼠交互的瞬间状态——悬停手柄 / 元素、热键按下、鼠标按下等；移出 / 松开即回落。
- **状态（state）**：进入编辑 / 绘制状态，或自定义状态（如自交分支状态）。
- **空闲（idle）**：默认图标。

三层各自独立设置；渲染时取当前**最高优先级层**的值。

示例：

```ts
duck.cursor.apply('idle', 'default');           // 空闲：默认（duck 是什么？你别管，可能是 cat）
duck.cursor.apply('state', 'crosshair');        // 进入绘制：十字
duck.cursor.apply('state', 'move');             // 进入编辑：移动
duck.cursor.apply('transient', 'grab');         // 悬停可编辑元素
duck.cursor.apply('transient', 'grabbing');     // 按住拖拽顶点
duck.cursor.apply('transient', 'custom');       // 按住 Shift：自定义吸附图标
duck.cursor.reset();                            // 移出 / 松开：回 idle
```

## 4. 与热键、绘制 / 编辑阶段的关联

- 按下某热键（如画线空闲 + Shift）→ 经注入的 CursorManager 在 `transient` 层设置新指针（见 hotkey-manager.md）。
- 绘制 / 编辑阶段对象在阶段切换时设置 `state` 层指针。
- 分支状态（如自交）→ `state` 层警告光标（见 controllers.md §4）。
- 辅助图形手柄 hover → `transient` 层指针（见 editing-helpers.md）。

示例：

```ts
// 画线空闲 + 按住 Shift → 吸附光标（transient）
hotkeys.onDown('ShiftLeft', () => cursor.apply('transient', 'custom'));
hotkeys.onUp('ShiftLeft',   () => cursor.reset());

// 进入编辑态 → state 层 move
duck.startEdit(id);                 // 内部: cursor.apply('state', 'move')

// 自交分支状态 → state 层警告
cursor.apply('state', 'not-allowed');
```

## 5. 图标注册与可配置

- 支持注册自定义图标：CSS cursor（`crosshair`、`move`、`grab`）或 SVG / data-URL 图标。
- 未注册的层可缺省（不改变指针），覆盖默认图标按需注册。

```ts
cursor.set('custom', { name: 'snap', icon: 'data:image/svg+xml,...' });
```
