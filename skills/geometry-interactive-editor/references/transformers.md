# 整体编辑模式：平移 / 旋转 / 缩放变换器

## 1. 定位

整体编辑模式是最高的编辑形态：对被编辑元素做整体平移、旋转、缩放。引入三种变换器：

- **平移变换器**（`TranslateTransformer`）
- **旋转变换器**（`RotateTransformer`）
- **缩放变换器**（`ScaleTransformer`）

三种变换器**互斥**，一次激活一个，由 `TransformerManager` 统一装配与切换（见 architecture.md 常用类名）。

## 2. 独立控制

每个变换器可独立控制出现的能力：

- **平移**：可只出现单轴（X / Y / Z）、双轴平面、或自由平移；
- **旋转**：可只出现某个旋转轴；
- **缩放**：可只出现单轴向 / 均匀缩放。

完整选项结构见 §3 的 `TransformerOptions`。

## 3. 样式参数化

样式通过构造 / 配置参数传入，可逐部位配置：

```ts
interface TransformerStyle {
  axisColor: string;      // 轴向线
  ringColor: string;      // 旋转环
  handleColor: string;    // 平移块 / 缩放控制块
  hoverColor: string;     // 悬停高亮
  opacity: number;
  size: number;           // 整体尺寸
}
```

- 悬停行为（高亮、光标）随样式可配置；
- 各部位颜色独立，便于品牌化与主题。

### 子变换器样式可自定义

除全局样式外，每个子变换器应支持自定义**外观与形态**（形态也属于“样式”的一部分）：

```ts
interface TransformerOptions {
  translate?: {
    axes?: Axis[];
    free?: boolean;
    bidirectional?: boolean;         // 是否渲染双向箭头（默认单向箭头）
    style?: TranslateStyle;          // 平移专属样式（箭头、线宽、块）
  };
  rotate?: {
    axes?: Axis[];
    style?: RotateStyle;
  };
  scale?: {
    axes?: Axis[];
    uniform?: boolean;
    style?: ScaleStyle;
  };
}
```

- 例：平移变换器默认是箭头形态，可配置 `bidirectional: true` 渲染双向箭头；也可整体替换 `TranslateStyle`（换颜色、线宽、箭头顶部样式）。
- 各子变换器的默认样式整体继承 `TransformerStyle`，再按需覆盖。

## 4. 与辅助元素解耦

- 变换器在特定阶段只**通过事件发出**被编辑元素的局部信息（朝向、轴向、平面方向、旋转角度等）；
- **由调用方决定**是否绘制额外辅助元素（如轴向辅助线）；
- 变换器自身不携带辅助元素状态，保证可替换、可测试。

```ts
// 变换器发出的阶段信息（供调用方决定是否绘制辅助元素）
interface TransformerEvent {
  kind: 'orient' | 'axis' | 'plane' | 'delta';
  orientation?: Quaternion;
  axis?: Vec3;
  plane?: PlaneInfo;
  delta: Vec3;
}
```

## 5. 与 Modifier 的配合

- Modifier 把鼠标事件、热键状态向下传给当前变换器；
- 变换器的运动量通过 `EditMotion.kind = 'transform'` 向上发射（见 editing-helpers.md）；
- Modifier 再分配当前编辑策略对象计算最终几何。

## 6. 独立包

强烈建议把变换器与它们的渲染适配拆成**两个独立包**：

- `@<scope>/editor-transformers`：变换器**核心**——纯数学 / 几何模块（变换计算、手柄命中、事件发射），与地图库完全解耦，可独立演进、测试、发版本。
- `@<scope>/editor-transformers-adapters`：变换器 / 辅助图形的**渲染适配**——变换器和其它简单辅助图形最终都要画到画布上，它们对各地图库、几何库的适配（maplibre / cesium / leaflet / ol / canvas2d）统一抽取到这个适配包，不混入核心。

这样：宿主可只装核心（配合自带 canvas 渲染），也可按需选装适配器；渲染细节（双向箭头怎么画、旋转环怎么描）留在适配层。
