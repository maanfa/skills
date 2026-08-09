# 竞态接管与仲裁器

## 1. 竞态来源

绘制 / 编辑 / 悬停 / 选中会同时竞争鼠标输入，必须规定优先级与接管规则。元素通过 `Hoverable / Editable` 标记（见 architecture.md）决定是否被悬停器、编辑器接管；悬停拾取到的信息（元素 id、命中点）交由外观类裁决。

拾取器（Picker）只提供命中结果（`elementId | null`），**不做裁决**；裁决全部归仲裁器。

## 2. 接管规则

**绘制：**

- 空闲时可悬停其它已加载元素（**推荐**）；悬停后点击 → 从绘制模式切换为编辑模式。
- 也可配置为空闲时不允许悬停（由开发者自选）。
- **绘制进行中**（处于某元素绘制阶段）→ 不允许与其它已加载元素悬停、选中、编辑。

**编辑：**

- 编辑空闲（已选中且进入编辑态）→ 可悬停其它元素，点击后切换编辑元素。
- **编辑进行中**（如正在拖拽某辅助图形）→ 不允许悬停与切换其它元素。

| 场景 | 悬停 | 点击行为 |
| --- | --- | --- |
| 空闲（无绘制/编辑） | 可悬停 | 悬停 → 点击进入编辑（若可编辑） |
| 绘制空闲 | 可悬停 | 悬停 → 点击切到编辑 |
| 绘制进行中 | 禁止 | 仅消费当前草稿 |
| 编辑空闲 | 可悬停 | 点击切换编辑元素 |
| 编辑进行中 | 禁止 | 仅消费当前编辑操作 |

## 3. 仲裁器设计

- **轻量**：在保证互斥的前提下，仲裁逻辑可直接内联在外观类（一组条件判断即可）。
- **复杂**：设计为外观类的**私有成员**状态机，命名 `StateMachine` / `StateArbiter` 等。

```ts
type EditorPhase =
  | { kind: 'idle' }
  | { kind: 'draw'; sub: 'idle' | 'in-progress' }
  | { kind: 'edit'; sub: 'idle' | 'in-progress' };

type AllowResult =
  | { ok: true }
  | { ok: false; reason: 'busy' | 'drawing' | 'editing' };

interface StateArbiter {
  request(consumer: 'hover' | 'select' | 'draw' | 'edit'): AllowResult; // 申请消费，校验互斥
  enter(phase: EditorPhase): void;                                      // 状态转移
  onTransition(cb: (from: EditorPhase, to: EditorPhase) => void): () => void;
}
```

- 所有控制器（HoverManager / Drawer / Modifier / Picker）的输入先经仲裁器问询，拿到允许才继续，否则让位。
- 任何时刻只有一个“活动消费者”，保证状态机不打架。
- 状态转移统一派发事件（见 event-system.md 目录），外部据此同步 UI。

## 4. 取消与降级规则

- 取消选中时若处于 `edit` 相位，**应拒绝取消选中**（`{ ok: false, reason: 'editing' }`）：须先 `cancelEdit()` 退出编辑，才能取消选中（对外 API 见 canvas-interaction.md）。
- 进入编辑后不可直接降级回“仅选中”态，必须显式退出编辑。
- 拒绝时派发 `select:cancel-rejected` 事件。
- **样式恢复与仲裁结果绑定**：取消被拒时**保持当前层级样式**（editing / selected），不恢复；只有真正通过仲裁的取消，才按层级回退下一级样式（见 canvas-interaction.md §6）。

## 5. 与其它文档的关系

- 仲裁器是跨控制器横切能力：controllers.md（引擎）用它仲裁输入，canvas-interaction.md（对外契约）靠它实现取消语义。
- 竞态规则表是设计/评审时的对照基准。
