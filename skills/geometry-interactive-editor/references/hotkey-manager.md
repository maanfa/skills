# 热键管理器（HotkeyManager）

## 1. 可缺省，但建议保留

- HotkeyManager 可缺省：若宿主确定纯鼠标即可分辨全部交互，可不装配（外观类以可选方式持有）。
- 但**不建议缺省**——只要存在“仅鼠标不足以分辨”的编辑 / 绘制行为，就必须有热键或等价的状态输入口，否则策略对象无法得知如何取点。

## 2. 为什么鼠标往往不够：取点模式（PickMode）

3D 编辑中拖拽顶点手柄时，`leftdown / leftup` 无法区分“按坐标点 / 按平面 / 按轴向”取点更新，因此策略对象需要一个**取点模式（PickMode）** 状态输入口，明确 `mousemove` 时如何拾取点。它由热键或外部指令式调用驱动。

详细的 PickMode 定义与各策略对象的取点逻辑见 `controllers.md`。

## 3. 常见热键用途

- **Shift 按住**：吸附（网格 / 端点 / 角度）、沿固定角度继续画等，策略对象读取按住状态即时改变逻辑。
- **Esc**：退出当前草稿，或回退当前编辑量（回到拖拽前的状态）。
- **Backspace**：删除上一个添加的点（绘制）或删除选中顶点（编辑）。

## 4. 接口示例

```ts
interface HotkeyManager {
  isDown(code: string): boolean;                  // 查询当前是否按住
  onDown(code: string, handler: () => void): () => void;
  onUp(code: string, handler: () => void): () => void;
  press(e: KeyboardEvent): void;                  // 由适配层注入原始键盘事件
}
```

外观类装配参数 `hotkeys`（见 facade.md）即构造 HotkeyManager 的选项：

```ts
interface HotkeyOptions {
  target?: HTMLElement;           // 键盘监听目标，缺省 window
  enabled?: boolean;              // 是否默认启用（可运行时切换）
}
```

## 5. 上下文与作用域

- 热键语义可随模式变化：Draw 模式下 Backspace 删点，Edit 模式下删选中顶点。
- 由策略对象（或外观类编排）决定当前模式下的热键绑定；管理器本身只做按下 / 释放状态分发。
- 对外暴露 `key` / `code`（如 `ShiftLeft`、`Escape`、`Backspace`），不把原始键盘流散落到各处。

## 6. 与 CursorManager 联动

- 按下某热键时（如画线空闲 + Shift），应通过注入的 CursorManager 设置新指针 + 图标（见 cursor-manager.md）。

## 7. 生命周期

- attach 时监听目标元素（canvas / window）的键盘事件；detach 时完整解绑，避免热键泄漏污染宿主。
