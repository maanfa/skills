# 地图库适配器约定

## 0. 适配器在哪里用

适配器是**最后一段管道**：把 core 的状态 / 事件翻译成地图库的渲染与拾取，并把地图事件翻译回 core 指令。它由外观类持有，在四个环节被使用：

| 环节 | 使用方 | 适配器承担 |
| --- | --- | --- |
| 输入 | MouseEventManager | 订阅库事件 / 原生 DOM，产出 `leftdown`、`mousemove` 等 |
| 坐标 | 控制器 / 辅助图形 / 变换器 | 实现 `CoordinateAdapter`（`worldToScreen / screenToWorld`） |
| 渲染 | 外观类（事件驱动） | `render / updateElement / removeElement`，把 Element 翻译为库对象 |
| 拾取 | Picker / Hover | `hitTest`，返回 `elementId` |

装配方式二选一：

- **自动识别**：外观类构造时按宿主类型识别并创建对应适配器（Leaflet / OpenLayers / MapLibre / Cesium / canvas2d）；
- **显式注入**：宿主在 options 传入适配器实例（`new Facade(host, { adapter: new CesiumMapAdapter() })`）。

一段完整链路示例：

```
duck.startEdit(id)
  → Modifier 进入编辑态
  → 辅助图形经 adapter.coords 换算落点
  → 拖拽手柄 → EditMotion → 策略更新几何 → element:changed
  → 外观类调用 adapter.updateElement(element) 增量刷新渲染
```

（`duck` 是什么？你别管，你封装什么它是什么——也可能是 `cat`。）

单库集成可跳过适配器（见 §2 注）。

## 1. 适配器职责

适配器把 core 的模型/状态/事件桥接到具体地图库：

- 实现 `CoordinateAdapter`（见 coords.md）
- `attach` 时创建渲染元素（图层/实体）并订阅地图事件
- 监听 core 事件 → 增量更新渲染元素
- 把地图事件（click、mousemove、dblclick）翻译为 core 的编辑指令
- 提供鼠标事件管家（MouseEventManager）的适配实现（如 Cesium 的 `ScreenSpaceEventHandler`，见 mouse-event-manager.md）
- `detach` 时完整销毁：移除图层、退订事件、清空引用

## 2. 适配器最小接口

```ts
interface MapAdapter {
  attach(host: EditorHost): void;
  detach(): void;
  render(state: EditorState): void;        // 全量刷新（如 setState 后）
  updateElement(element: Element): void;   // 增量更新
  removeElement(elementId: string): void;
  hitTest(screen: ScreenCoord, tolerance: number): string | null; // 返回 elementId
  coords: CoordinateAdapter;
}
```

- `render / updateElement` 由 events 触发调用；`hitTest` 供 core 命中检测回调。
- 各地图库“添加元素”代价不同，**增量更新必须优先于整层重建**。
- 辅助图形与变换器的渲染适配统一抽取到 `editor-transformers-adapters` 包（见 transformers.md §6）。
- **单库集成**：若只针对某个地图库设计，可放弃本适配器，直接在 Element 中承载库数据对象（如 Cesium `Primitive` / `LabelCollection`，见 geometry.md §3 渲染适配）。

### 适配器使用 demo

**Canvas2D 适配器（最简实现）**：

```ts
class Canvas2DMapAdapter implements MapAdapter {
  private ctx!: CanvasRenderingContext2D;
  private lastState: EditorState = { elements: [], activeElementId: null, mode: 'view' };
  private scale = 100;
  private listeners = new Map<string, (e: MouseEvent) => void>();   // 输入转发（MouseEventManager 订阅）

  coords: CoordinateAdapter = {
    worldToScreen: (w) => [w[0] * this.scale, this.height - w[1] * this.scale],
    screenToWorld: (s) => [s[0] / this.scale, (this.height - s[1]) / this.scale],
  };

  private get height(): number { return this.ctx.canvas.height; }

  attach(host: EditorHost): void {
    this.ctx = host.canvas.getContext('2d')!;
    for (const type of ['mousemove', 'mousedown', 'mouseup'] as const) {
      const h = (e: MouseEvent) => this.emitInput(type, e);
      host.canvas.addEventListener(type, h);
      this.listeners.set(type, h);
    }
  }
  detach(): void {
    this.listeners.forEach((h, type) => this.ctx.canvas.removeEventListener(type, h));
    this.listeners.clear();
    this.ctx = undefined!;
  }

  private emitInput(type: string, e: MouseEvent): void {
    // 把原生事件转成 MouseInputEvent 交给 MouseEventManager（见 mouse-event-manager.md）
  }

  render(state: EditorState): void {
    this.lastState = state;
    this.clear();
    for (const el of state.elements) this.draw(el);              // 全量重绘
  }
  updateElement(element: Element): void { this.draw(element); }  // 增量：只重绘该元素
  removeElement(): void { this.render(this.lastState); }

  hitTest(screen: ScreenCoord, tolerance: number): string | null {
    for (const el of this.lastState.elements) {
      if (this.hit(el, screen, tolerance)) return el.id;
    }
    return null;
  }

  private clear(): void { this.ctx.clearRect(0, 0, this.ctx.canvas.width, this.ctx.canvas.height); }

  private hit(el: Element, screen: ScreenCoord, tolerance: number): boolean {
    const w = this.coords.screenToWorld(screen);
    const geo = el.geometry;
    return (Array.isArray(geo) ? geo : [geo]).some((g) => this.hitGeo(g, w, tolerance));
  }
  private hitGeo(geo: Geometry, w: WorldCoord, tolerance: number): boolean {
    if (geo.type === 'point') return this.dist(geo.coordinates, w) <= tolerance;
    const pts = geo.type === 'line' ? geo.coordinates : geo.coordinates[0];
    return pts.some((p) => this.dist(p, w) <= tolerance);          // 容差按世界尺度换算
  }
  private dist(a: Coord, b: WorldCoord): number { return Math.hypot(a[0] - b[0], a[1] - b[1]); }

  private draw(el: Element): void {
    const s = el.style;                                           // 先 fill 后 line；立体组合 line+fill（见 styles.md）
    if (s?.fill) { this.applyFill(s.fill); this.fillGeometry(el.geometry); }
    if (s?.line) { this.applyLine(s.line); this.strokeGeometry(el.geometry); }
  }
  private applyFill(f: FillStyle): void {
    this.ctx.fillStyle = f.color;
    this.ctx.globalAlpha = f.opacity;
  }
  private applyLine(l: LineStyle): void {
    this.ctx.strokeStyle = l.color;
    this.ctx.globalAlpha = l.opacity;
    this.ctx.lineWidth = l.width;
    this.ctx.setLineDash(l.dash ?? []);
  }
  private toPx(w: Coord): [number, number] { return [w[0] * this.scale, this.height - w[1] * this.scale]; }
  private fillGeometry(geo: Geometry | Geometry[]): void {
    for (const g of Array.isArray(geo) ? geo : [geo]) {
      if (g.type !== 'polygon') continue;
      this.ctx.beginPath();
      for (const ring of g.coordinates) {
        ring.forEach((p, i) => { const [x, y] = this.toPx(p); i ? this.ctx.lineTo(x, y) : this.ctx.moveTo(x, y); });
        this.ctx.closePath();
      }
      this.ctx.fill('evenodd');
    }
  }
  private strokeGeometry(geo: Geometry | Geometry[]): void {
    for (const g of Array.isArray(geo) ? geo : [geo]) {
      this.ctx.beginPath();
      if (g.type === 'point') { const [x, y] = this.toPx(g.coordinates); this.ctx.arc(x, y, 3, 0, Math.PI * 2); }
      else if (g.type === 'line') { g.coordinates.forEach((p, i) => { const [x, y] = this.toPx(p); i ? this.ctx.lineTo(x, y) : this.ctx.moveTo(x, y); }); }
      else { g.coordinates.forEach((ring) => { ring.forEach((p, i) => { const [x, y] = this.toPx(p); i ? this.ctx.lineTo(x, y) : this.ctx.moveTo(x, y); }); this.ctx.closePath(); }); }
      this.ctx.stroke();
    }
  }
}
```

**外观类装配与事件驱动**（自动识别或显式注入，见 §0）：

```ts
const adapter = new Canvas2DMapAdapter(canvasHost);
const duck = new Facade(canvasHost, { adapter });   // 或宿主显式传入

// 外观类内部按事件调用适配器（示意，真实由外观类编排）
duck.on('element:added',   ({ element })   => adapter.updateElement(element));
duck.on('element:changed', ({ current })   => adapter.updateElement(current));
duck.on('element:removed', ({ elementId }) => adapter.removeElement(elementId));
duck.on('change',          (state)         => adapter.render(state));  // setState 全量刷新
```

**Cesium 坐标换算 demo**：

```ts
import * as Cesium from 'cesium';

const coords: CoordinateAdapter = {
  worldToScreen: (w) => {
    const c = Cesium.Cartesian3.fromDegrees(w[0], w[1], w[2] ?? 0);
    const p = Cesium.SceneTransforms.worldToWindowCoordinates(viewer.scene, c);
    return p ? [p.x, p.y] : [0, 0];
  },
  screenToWorld: (s) => {
    const cartesian = viewer.scene.pickPosition(new Cesium.Cartesian2(s[0], s[1]));
    const g = Cesium.Cartographic.fromCartesian(cartesian);
    return [Cesium.Math.toDegrees(g.longitude), Cesium.Math.toDegrees(g.latitude), g.height];
  },
};
```

## 3. 2D：Leaflet

- 用 `L.layerGroup` 管理要素图层，几何用 `L.polyline / L.polygon / L.marker`，或自绘 canvas 覆盖层。
- 顶点编辑用自绘 marker 或 canvas 覆盖层，命中以容器像素坐标为准。
- 事件如 `map.on('click')` 必须在 detach 时 `off`。

## 4. 2D：OpenLayers

- 用 `ol/layer/Vector` + `ol/source/Vector`，几何用 `ol/geom/*`。
- 投影：source 用 EPSG:4326（WGS84），view 用 EPSG:3857，适配层负责 `transform`。
- 可用 `ol/interaction/Modify`，但为了一致的编辑体验，更推荐自建顶点编辑。
- 命中用 `map.forEachFeatureAtPixel`。

## 5. 3D：MapLibre GL

- 用 `addSource`（GeoJSON source）+ `addLayer`；顶点编辑常用 canvas 覆盖层（custom layer 或 HTML overlay）叠加绘制。
- `worldToScreen` 用 `map.project(lngLat)`，`screenToWorld` 用 `map.unproject` + 高程（如 `queryTerrainElevation`）。
- move/zoom 期间的高频事件必须节流。

## 6. 3D：CesiumJS

- 简单场景用 `viewer.entities.add`（Entity），大量要素用 `CustomDataSource`。
- 拾取用 `scene.pickPosition` / `camera.pickEllipsoid`；经纬高 → 笛卡尔的换算用 `Cartesian3.fromDegrees`，注意其语义。
- 屏幕坐标以 canvas 元素坐标系为准。
- 2D / 3D / Columbus 模式切换时适配层需同步重建或切换渲染路径。

## 7. 差异对照速查

| 关注点 | Leaflet | OpenLayers | MapLibre | Cesium |
| --- | --- | --- | --- | --- |
| 元素渲染 | layerGroup + poly | Vector layer | GeoJSON source | Entity / DataSource |
| 屏幕→世界 | containerPointToLatLng | getCoordinateFromPixel | unproject + queryTerrainElevation | pickPosition |
| 世界→屏幕 | latLngToContainerPoint | getPixelFromCoordinate | project | SceneTransforms.worldToWindowCoordinates |
| 命中 | 自算容器像素距离 | forEachFeatureAtPixel | queryRenderedFeatures | pick |
| 高频事件 | mousemove | mousemove | mousemove | preRender / ScreenSpaceEvent |

## 8. 事件桥接

地图原生事件必须翻译为 core 的动作调用（如 click → `duck.startDraw('polygon')` 或 `duck.hitTest`），不要让地图事件直接改 core 状态；core 的变更再经事件系统回流刷新渲染，形成闭环。
