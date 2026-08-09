# 坐标适配层与精度约束

## 1. 坐标语义

- **世界坐标（WorldCoord）**：与地图库无关的绝对坐标。2D 为 `[lng, lat]`（WGS84 经纬度），3D 为 `[lng, lat, alt]`（含高程）。**core 与模型中只存世界坐标**（与 geometry.md 的 Coord 一致，二维 / 三维均可）。
- **屏幕坐标（ScreenCoord）**：渲染表面的像素位置 `[x, y]`（3D 为投影后屏幕位置），以容器左上角为原点。

## 2. 换算契约（接口）

```ts
type WorldCoord = [number, number] | [number, number, number];  // [lng, lat] / [lng, lat, alt]
type ScreenCoord = [number, number];                            // 容器像素 [x, y]

interface CoordinateAdapter {
  worldToScreen(world: WorldCoord): ScreenCoord;
  screenToWorld(screen: ScreenCoord, options?: { pickElevation?: boolean }): WorldCoord;
}
```

- `worldToScreen`：编辑时把世界坐标落到屏幕，用于命中与绘制。
- `screenToWorld`：用户点击/拖拽时把屏幕位置换算回世界坐标。
- 契约由 core 定义、适配层实现；core 只依赖该接口，不直接使用任何地图库 API。

## 3. 2D 投影差异

- **Leaflet**：默认 Web Mercator，提供 `latLngToContainerPoint / containerPointToLatLng`，注意 overlay pane 的偏移。
- **OpenLayers**：基于投影对象（view 默认 EPSG:3857），用 `getPixelFromCoordinate / getCoordinateFromPixel`。
- 两者统一以**容器像素**为屏幕坐标基准，各自的偏移与投影细节在适配层内部消化。

## 4. 3D 高程与相机

- MapLibre / Cesium 存在相机与地形：一个屏幕点对应一条射线，世界坐标不唯一。`screenToWorld` 需提供“射线与参考平面/地形求交”的能力（pick），或约定返回当前鼠标高程下的坐标。
- 拖拽顶点时建议固定参考高程（如要素所在高度），避免视角变化引起抖动。
- PickMode 的“平面 / 轴向取点”正是基于这些换算在策略层组合实现（见 controllers.md §4）。

## 5. 双精度与精度约束

- 世界坐标用 **float64（双精度）**；屏幕坐标计算中间过程用 float64，仅在最终 GPU 提交时用 float32。
- 坐标比较一律用容差，禁止 `===`：世界坐标 `|a - b| < 1e-9`，屏幕坐标 `< 0.5px`。
- 3D 大尺度场景下，单精度会导致远处顶点抖动；必要时在适配层做相对原点偏移（rebasing）缓解。

## 6. 换算发生在适配层

core 只持有世界坐标并调用 `CoordinateAdapter` 接口；投影细节、容器偏移、高程拾取都是适配层职责，不得泄漏进 core。

## 7. 共享类型（跨文档复用）

以下类型在 PickMode、EditMotion、TransformerEvent 等场景被引用，统一在此定义：

```ts
type Vec3 = [number, number, number];                    // 三维向量 / 增量 / 平移量

type Axis = 'x' | 'y' | 'z';

interface PlaneInfo {
  normal: Vec3;
  point: WorldCoord;
}                                          // 平面：法向 + 过点

interface AxisInfo {
  axis: Axis;
  origin: WorldCoord;
}                                          // 轴向：方向 + 原点

interface Quaternion {
  x: number;
  y: number;
  z: number;
  w: number;
}                                          // 朝向（旋转四元数）

interface Bounds {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}                                          // 轴对齐包围盒
```
