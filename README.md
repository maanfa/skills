# maanfa skills

围绕地理信息、地图、三维场景与 canvas 图形处理，沉淀可复用的技能规范与设计文章。

当前已收录的内容聚焦"**通用交互式几何编辑器**"的设计；后续可能陆续加入其它技能（如地理数据处理、空间分析、三维可视化等），因此采用"技能 / 文章一一对应"的目录组织：

```
├── skills/
│   └── <skill-name>/                技能（opencode / Claude Code 技能）
│       ├── SKILL.md                 技能入口：定位、核心思想、工作流、质量验收
│       └── references/              按主题切分的参考文档
└── wiki/
    └── <skill-name>/                与该技能对应的系列文章
        ├── README.md                导读与篇目索引
        └── part-N-*.md              文章
```

## 安装指南

纯 Markdown 技能，无需构建，复制目录即可（目录名须与 SKILL.md 的 `name` 一致）。

**opencode：一键脚本**

```powershell
# Windows PowerShell，在仓库根目录执行
.\install.ps1
# 默认安装到 ~/.config/opencode/skills/；也可指定目标
.\install.ps1 -Target "$HOME\.claude\skills"
```

或手动复制：

```bash
git clone https://github.com/maanfa/skills.git
cp -r skills/geometry-interactive-editor ~/.config/opencode/skills/
```

**Claude Code**

```bash
cp -r skills/geometry-interactive-editor ~/.claude/skills/
```

**通用 Agent Skills 目录**（opencode 也会自动扫描）

```bash
cp -r skills/geometry-interactive-editor ~/.agents/skills/
```

> 安装后请重启工具（技能在启动时加载）。若用 opencode，也可通过 `skills.paths` / `skills.urls` 直接指向本仓库 `skills/` 目录，免复制。

## 已收录

### skills/geometry-interactive-editor —— 前端通用交互式几何编辑器

[SKILL.md](skills/geometry-interactive-editor/SKILL.md)

references：`architecture` · `facade` · `mouse-event-manager` · `event-system` · `hotkey-manager` · `controllers` · `race-arbiter` · `picker` · `canvas-interaction` · `editing-helpers` · `transformers` · `geometry` · `styles` · `element-store` · `cursor-manager` · `logging` · `coords` · `adapters` · `build`

### wiki/geometry-interactive-editor —— 设计系列文章

- [导读](wiki/geometry-interactive-editor/README.md)
- 1 [入口的对象及其成员](wiki/geometry-interactive-editor/part-1-facade.md)
- 2 [交互事件流](wiki/geometry-interactive-editor/part-2-event-flow.md)
- 3 [数据对象的设计](wiki/geometry-interactive-editor/part-3-element-model.md)
- 4 [绘制、悬停与编辑](wiki/geometry-interactive-editor/part-4-draw-hover-modify.md)
- 5 [辅助元素的设计](wiki/geometry-interactive-editor/part-5-editing-helpers.md)
- 6 [配套设施与工程化](wiki/geometry-interactive-editor/part-6-misc.md)
- 7 [设计模式与原则](wiki/geometry-interactive-editor/part-7-design-patterns.md)
