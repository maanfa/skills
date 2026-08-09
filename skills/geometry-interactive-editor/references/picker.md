# 拾取器（Picker）

## 1. 定位

拾取器提供命中检测（hit-testing）：把屏幕位置换算为“命中了哪个元素 / 哪个编辑手柄”。它**只出结果、不做裁决**——是否进入编辑、是否切换元素，交由仲裁器决定（见 race-arbiter.md）。

## 2. 接口

```ts
interface Picker {
  pick(screen: ScreenCoord, tolerance?: number): PickResult | null;   // 最近命中
  pickAll(screen: ScreenCoord, tolerance?: number): PickResult[];     // 全部命中，按距离排序
  query(geo: QueryGeometry, opts?: SearchOptions): Element[];         // 空间查询（见 element-store.md）
}

interface PickResult {
  elementId: string;
  handle?: HandleId;        // 命中编辑辅助手柄（见 editing-helpers.md）
  point: WorldCoord;        // 命中点（世界坐标）
  distance: number;         // 屏幕像素距离（容差内）
}
```

## 3. 命中优先级

- **手柄（辅助图形）命中优先于元素命中**：编辑态内手柄 hover 优先于被编辑元素（见 editing-helpers.md §3 hover 一节）；
- 元素按 `Hoverable / Editable` 标记过滤（见 architecture.md）。

## 4. 使用方

- **HoverManager**：划过时查询 → 派发 `hover:enter / hover:leave`；
- **Modifier / Drawer**：点击时查询 → 决定接管（先经仲裁器问询）；
- 底层与 `ElementStore.search` 共用命中 / 空间索引（见 element-store.md §5）。

## 5. 与地图库

- 命中计算由适配层实现（`MapAdapter.hitTest`），Picker 调用它（见 adapters.md）；
- `tolerance` 用屏幕像素距离，与 coords.md 的屏幕坐标约定一致。
