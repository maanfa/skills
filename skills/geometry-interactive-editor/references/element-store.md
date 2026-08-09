# 元素管理（ElementStore）

## 1. 定位

ElementStore 是对 `EditorState.elements` 的**可选管理 / 查询接口**（可类比 repository）：负责增删改查、查找、空间查询、过滤、遍历。

- **不重复存储**：数据唯一权威在 `EditorState`（`getState / setState` 依据，见 geometry.md §4），ElementStore 只读写其中的 `elements`，不持有第二份拷贝。
- **可选设计**：简单编辑器只需一个数组 + 直接遍历即可；元素量大、需要空间查询时再上空间索引等基建。
- **但推荐保留**：多一个“管家”可以**缓存整体统计量**（总数、总范围等），避免每次全量重算。

## 2. 增删改查与统计

```ts
interface ElementStore {
  add(element: Element): void;
  remove(id: string): boolean;
  update(id: string, partial: Partial<Element>): Element;
  get(id: string): Element | undefined;

  count(): number;                 // 元素总数（缓存）
  bounds(): Bounds | null;         // 全部元素总范围（缓存，随变更增量维护；Bounds 见 coords.md §7）
}
```

- `update` 内部合并出新元素（不可变风格），并走同步链路（controllers.md §5）通知变更器 / 策略 / 辅助图形。
- 变更统一派发 `element:added / element:changed / element:removed`（见 event-system.md 目录）。
- `count()` / `bounds()` 是 ElementStore 的典型统计量，可再按需扩展（按类型计数、最小/最大等）。

## 3. 查找

- **按 id**：`findById(id)`
- **空间搜索**：传入点 / 线 / 面做空间查询
- **遍历**：`each(fn)` 或可迭代
- **条件过滤**：`filter(predicate)`

```ts
type QueryGeometry = Point | LineString | Polygon;   // 空间查询输入（几何原语，见 geometry.md §1）

interface SearchOptions {
  tolerance?: number;              // 命中容差（屏幕像素距离）
  mode?: 'intersects' | 'contains' | 'within';       // 空间语义
}

interface ElementStore {
  findById(id: string): Element | undefined;
  search(geo: QueryGeometry, opts?: SearchOptions): Element[];
  each(fn: (e: Element) => void): void;
  filter(predicate: (e: Element) => boolean): Element[];
  [Symbol.iterator](): Iterator<Element>;
}
```

- `search` 的空间语义（相交 / 包含 / 在范围内）由宿主按需选，命中容差 `tolerance` 用屏幕像素距离（见 coords.md）。

## 4. 与外观类的关系

- 增删改查入口挂在外观类上（`duck.addElement(type, params) / removeElement / updateElement / findById / search`…，`duck` 是什么？你别管，可能是 `cat`），内部转发给 ElementStore；`addElement` 统一创建并入库。
- 外部不应直接修改 `EditorState.elements` 数组，统一经外观类 / ElementStore 走链路，保证事件与同步正确触发。

## 5. 索引与统计缓存

- 权威数据是数组（保证序列化与顺序，见 geometry.md §4）；ElementStore 内部用 `Map<id, Element>` 做 O(1) 查找，弥补数组 O(n)。
- 元素量大时再建空间索引（网格 / R-tree）加速 `search` 与命中检测（与 `hit-test` 共用）。
- `count()` / `bounds()` 等统计量在 `element:added / changed / removed` 时**增量维护**，避免全量重算。
