# 鼠标事件管家（MouseEventManager）

## 1. 定位

一个“管家”类：专门负责**接收并分发**鼠标在 canvas 上的动作。它只做分发，不做任何额外业务操作——不判断绘制/编辑/悬停，不修改状态。目的就是有一个接、发鼠标动作的统一入口。

## 2. 事件粒度

以高频、常用为主：

- 主：`leftdown`、`leftup`、`mousemove`
- 次：`leftclick`、`doubleclick`、`middledown`、`middleup`

可按需扩展 `contextmenu`、`wheel` 等。

## 3. 两类输出

派发的事件可带两类载荷，由适配层实现决定：

- **原生浏览器事件**：直接透传 `MouseEvent`，便于通用逻辑与 DOM 依赖方使用。
- **库屏幕坐标对象**：结合具体地图库输出其屏幕坐标类型，如 Cesium 的 `Cartesian2`（ScreenSpaceEventHandler 回调参数内即有）。

因此管家应把“事件类型”与“载荷格式”两个维度都暴露出来，由适配层统一。

## 4. 与地图库的结合

- **Cesium**：直接 `new ScreenSpaceEventHandler(viewer.canvas)`，把 `ScreenSpaceEventType.LEFT_DOWN` 等映射为 `leftdown` 等事件，回调参数中的 `Cartesian2` 作为屏幕坐标载荷。
- **Leaflet / OpenLayers / 纯 canvas**：监听容器 DOM 的 `mousedown / mousemove / mouseup / click / dblclick`，按需合成坐标。

## 5. 接口示例

```ts
interface MouseEventManager {
  on(
    e: 'leftdown' | 'leftup' | 'mousemove' | 'leftclick' | 'doubleclick' | 'middledown' | 'middleup',
    handler: (evt: MouseInputEvent) => void
  ): () => void;
  attach(): void;
  detach(): void;
}

interface MouseInputEvent {
  originalEvent: MouseEvent;       // 原生浏览器事件
  screen: ScreenCoord;             // 屏幕坐标（统一为 ScreenCoord；Cesium 等适配层可用 Cartesian2 换算/派生）
  picked?: PickResult;             // 经 Picker 命中后回填的元素标记（见 picker.md）
  buttons?: number;                // 当前按键位掩码
}
```

说明：`MouseInputEvent.screen` 统一为 `ScreenCoord`（见 coords.md）；适配层若要输出库自有屏幕坐标对象（如 Cesium `Cartesian2`），可在 `originalEvent` 上附带或另加可选字段，不改变统一载荷约定。

## 6. 职责边界

- 本类不感知绘制/编辑/悬停逻辑，也不消费热键。
- 谁订阅它、怎么编排，由外观类负责（外观类把本类事件注入 Drawer / Modifier 等）。
- 销毁时必须 detach：解绑 DOM / 库监听，避免泄漏。
