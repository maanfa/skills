# 画布交互：悬停、选中与编辑

## 1. 三个概念

- **悬停（hover）**：鼠标划过元素时的瞬时行为。
- **选中（select）**：把某个元素标记为当前焦点，可进一步进入编辑。
- **编辑（edit）**：基于选中的高阶模式。

悬停与选中都只是“行为”，其反馈通过**改变样式**体现；不配置任何样式时，画布中的元素可以无任何反应。

## 2. 双入口

悬停、选中、编辑都必须具备两个入口：

- **画布交互入口**：划过 / 点击 → 命中 → 行为。
- **指令式入口**：外部通过外观类函数调用（UI 联动），如 `duck.select(id)`、`duck.startEdit(id)`、`duck.hover(id)`。（`duck` 是什么？你别管，你封装什么它是什么——也可能是 `cat`。）

两个入口走同一套裁决逻辑（命中 → 标记 → 样式 → 事件），保证 UI 与画布行为一致。

## 3. 行为变更统一经外观类触发

选中、悬停、取消、进入/退出编辑是一系列**有联动**的操作：涉及样式切换、辅助元素创建/销毁、仲裁器状态转移、对外事件。因此所有行为变更都应在**外观类实例**上触发与派发——外部（UI、插件、二次开发）不要绕过外观类直接操作控制器，避免联动链断裂。

## 4. 选中 ≠ 编辑

选中与编辑是两件事，可以且推荐有双入口：

- **画布交互选中**：派发 `select:changed` 事件通知外部，**由外部决定**是否进入编辑。
- **外部指令式编辑**：`duck.startEdit(id)` 的同时进入选中。
- 外部也可单独指令式选中：`duck.select(id)` 只选中不编辑。
- 选中的元素可以进一步进入编辑。

## 5. 取消接口（对外可调用；画布交互行为同样调用）

提供明确的取消入口，画布交互（鼠标移出、点击空白）与指令式调用共用同一批方法：

```ts
interface ISelectionApi {
  select(id: string): void;
  deselect(): DeselectResult;                 // 取消选中
  hover(id: string | null): void;             // null = 取消悬停
  unhover(): void;                            // 取消悬停（等价 hover(null)）
  startEdit(id: string): void;
  cancelEdit(): void;                         // 退出编辑
}

type DeselectResult =
  | { ok: true }
  | { ok: false; reason: 'editing' };         // 处于编辑态，拒绝取消
```

- **取消悬停**：随时可取消，仅清除悬停样式。
- **取消选中**：若当前只是选中态，可取消；**若已进入编辑这种更高层级状态，应拒绝取消选中**——必须先 `cancelEdit()` 退出编辑，才能取消选中。
- 拒绝逻辑交由 **race-arbiter.md 的仲裁器**（StateMachine / StateArbiter）能力完成：取消选中先问询仲裁器，处于 `edit` 相位则返回 `{ ok: false, reason: 'editing' }` 并派发 `select:cancel-rejected` 事件。

## 6. 悬停与选中的互斥反馈

- 选中的元素悬停时**不再触发悬停**（避免样式冲突）。
- 悬停后的元素可以进一步选中。
- 样式可配置：`hoverStyle` / `selectedStyle` / `editingStyle`；未配置则无反馈。
- **取消即恢复**：样式是“行为反馈”——进入悬停 / 选中 / 编辑时应用对应样式，取消该行为时**恢复原样式**（回到元素自身 `style`，或回退到更低层级的反馈样式）。
- **恢复按层级**：退出编辑 → 恢复选中样式（若仍选中）；取消选中 → 恢复悬停样式或原样式；取消悬停 → 恢复原样式。
- **恢复与仲裁一致**：选中的元素不进入悬停，因此对选中元素 `unhover()` **无效果**；编辑态被仲裁器拒绝的 `deselect()` 同样不触发样式恢复——**被仲裁拒绝的取消不改变样式**（见 race-arbiter.md §4）。

## 7. 样式反馈与渲染

- 样式是**实例级**的：每个元素可各自配置基础样式（`element.style`）与反馈样式（`hoverStyle / selectedStyle / editingStyle`）；反馈由外观类派发事件，适配层据此应用（改变 canvas 绘制颜色、线宽、填充等）。
- 外观类构造参数 `styles` 只是**全局默认（fallback）**，元素实例未配置时兜底。

```ts
interface ElementStyles {
  hoverStyle?: ElementStyle;      // 全局默认悬停反馈
  selectedStyle?: ElementStyle;   // 全局默认选中反馈
  editingStyle?: ElementStyle;    // 全局默认编辑反馈
}
```

**解析优先级**（渲染某状态时）：

```
元素实例反馈样式  >  外观类默认反馈样式  >  元素自身基础样式（element.style）
```

即：`element.selectedStyle ?? facadeDefault.selectedStyle ?? element.style`；都未配置则无反馈。取消行为时按该规则回退到更低层级（见 §6）。

## 8. 标记与接管裁决

- 元素通过 `Hoverable / Editable` 标记（见 architecture.md）决定是否被悬停器、变更器（Modifier）接管。
- 悬停拾取的信息（元素 id、命中点、位置）交由外观类裁决：是否进入编辑、是否切换编辑元素（接管规则与仲裁器见 race-arbiter.md）。
