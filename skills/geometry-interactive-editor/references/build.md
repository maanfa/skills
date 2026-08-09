# 工程化：TS、单测、demo、打包发布

## 1. TypeScript

- `"strict": true`，零 `any` 显式放开（确有必要时局部 narrow + 注释说明）。
- `target` ES2017+；`moduleResolution` 用 `bundler` 或 `node16`。
- 生成 `.d.ts` 声明文件；公开 API 全部写 JSDoc / TSDoc。
- 公共签名不得泄漏依赖库的类型细节（避免类型泄漏、peer 升级兼容问题）。
- 几何原语可复用官方 `geojson` 类型包，或完全自定义（见 geometry.md §1）。

## 2. 单元测试（vitest 或 jest）

- **核心逻辑优先**：coords 换算、state 变换（顶点拖拽、吸附）、快照 round-trip、事件派发顺序必须覆盖。
- core 测试不依赖真实地图库（mock `CoordinateAdapter` 即可），跑得快且稳定。
- 适配器测试用真实地图库的最小实例 + jsdom，重点验证 attach/detach 无泄漏、事件解绑完整。

## 3. Demo（可运行验收）

- 用 vite 建 demo：一个地图实例 + 简短说明，走通“绘制 → 编辑 → 快照回退”闭环。
- demo 里展示纯指令式调用（控制台可执行 `duck.draw.start(...)`——`duck` 是什么？你别管，你封装什么它是什么，也可能是 `cat`），证明无 UI 约束。
- demo 是验收的一部分：TS 编译过 + 单测过 + demo 能跑，才算完成。

## 4. 打包

- 推荐 tsup / rollup / vite lib mode。
- 格式：ESM 为主（现代库），可按需附 CJS；产出 sourcemap。
- 依赖策略：地图库作为 `peerDependencies`（版本归宿主），core 自身尽量零运行时依赖。
- 树摇友好：`sideEffects: false`，支持按需导入。

## 5. Monorepo（分库分发时）

- pnpm workspace，demo 与包分开放：`apps/demo` 独立成应用，`packages/*` 放可发布包——
  `packages/core`、`packages/adapter-leaflet`、`packages/adapter-maplibre`、`packages/transformers`、`packages/transformers-adapters`…。
- core 用 `workspace:*` 被适配器引用，发布时自动替换版本。
- changeset 管理版本与 changelog。

## 6. 发布与 CI

- 发布前 `npm run typecheck && npm run test && npm run build`。
- CI（如 GitHub Actions）：main 上跑 lint + typecheck + test；tag 触发发布。
- 版本遵循 semver；core 接口变更视为 breaking。

## 7. Bun 兼容（预留）

- 工具链不绑定单一运行时：兼容 npm / pnpm / yarn / bun。
- `package.json` `exports` 可按需提供 `"bun"` 条件（如用 Bun 优化过的运行时入口）。
- 命令可对等替换：`bun install`、`bun test`、`bun build`、`bun run <script>`；CI 中 `bun install && bun test` 亦可。
