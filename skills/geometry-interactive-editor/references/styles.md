# 样式规范（ElementStyle）

样式是 Element 的可选成员（见 geometry.md §3）。颜色**一律使用 cssHexString**（如 `'#ff8c00'`），透明度**一律用 `0~1`**单独表达（不鼓励 `#rrggbbaa` 混用透明度）。

## 1. 基本样式

四类基本样式，命名与字段都**仅供参考、可按需增减**（不同库 / 业务对线、填充、符号、标签的字段需求不同，不要强行全量对齐）：

```ts
type ColorHex = string;   // css hex，如 '#ff8c00'；透明度一律用 opacity，不用 alpha 十六进制

interface LineStyle {              // 线
  color: ColorHex;
  opacity: number;                 // 0~1
  width: number;                   // 像素
  cap?: 'butt' | 'round' | 'square';
  join?: 'miter' | 'round' | 'bevel';
  dash?: number[];                 // 虚线，如 [8, 4]
  dashOffset?: number;
  arrow?: 'none' | 'start' | 'end' | 'both';   // 箭头（特定库支持）
}

interface FillStyle {              // 面
  color: ColorHex;
  opacity: number;                 // 0~1
  pattern?: string;                // 图案填充（可选）
}

interface SymbolStyle {            // 符号 / 图标
  icon?: string;                   // url / data-uri / 库自带名
  iconSize?: number;
  opacity: number;                 // 0~1
  rotation?: number;               // 弧度
}

interface LabelStyle {             // 文字
  text: string;
  color: ColorHex;
  opacity: number;                 // 0~1
  fontSize: number;
  fontFamily?: string;
  offset?: [number, number];       // 像素偏移
  anchor?: 'top' | 'bottom' | 'center' | 'left' | 'right';
}
```

## 2. 组合规则

- **立体元素**（`prism` / `cylinder` / `mesh`）= `line`（轮廓 / 边线）+ `fill`（面）组合；
- **点状元素**（`marker` / `label` / `billboard`）= `symbol` / `label`；
- **悬停 / 选中 / 编辑反馈样式**（canvas-interaction.md 的 `hoverStyle / selectedStyle / editingStyle`）复用以上基础样式。

**实例级**：基础样式与反馈样式都挂在元素实例上（`element.style`、`element.hoverStyle` 等），**每个元素可以不同**；外观类构造参数 `styles` 只是全局默认兜底（解析优先级见 canvas-interaction.md §7）。

## 3. 聚合与自定义着色器入口

```ts
interface ElementStyle {
  line?: LineStyle;
  fill?: FillStyle;
  symbol?: SymbolStyle;
  label?: LabelStyle;
  customShaders?: Record<string, ShaderSlot>;   // 高级：自定义着色器
}

interface ShaderSlot {
  kind: 'builtin' | 'custom';
  source?: string;                 // GLSL / 地图库着色器代码
  uniforms?: Record<string, unknown>;
  defines?: Record<string, string | number | boolean>;
}
```

- `customShaders` 是**自定义着色器的适配入口**：保留给高级二次开发，地图库有原生着色器语义时按需透传。
- `dash / solid / arrow` 等线型细节属于“特定库可指定”的增强项，默认 `solid`、无箭头；**适配层对不支持的项应忽略并告警**，而不是报错。
