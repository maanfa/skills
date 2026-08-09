<#
  一键安装技能到目标目录（默认 opencode 全局技能目录）
  用法:
    .\install.ps1                               # 安装到 ~/.config/opencode/skills/
    .\install.ps1 -Target "$HOME\.claude\skills" # 安装到 Claude Code 用户技能目录
    .\install.ps1 -Skill <other-skill>          # 安装仓库中的其它技能
#>
param(
  [string]$Skill = "geometry-interactive-editor",
  [string]$Target = "$HOME\.config\opencode\skills",
  [string]$Repo = "https://github.com/maanfa/skills.git"
)

$ErrorActionPreference = "Stop"

# 克隆到临时目录
$tmp = Join-Path $env:TEMP ("skills-install-" + [guid]::NewGuid().ToString("N"))
git clone --depth 1 $Repo $tmp 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "克隆仓库失败：$Repo"; exit 1 }

$src = Join-Path $tmp "skills\$Skill"
if (-not (Test-Path -LiteralPath $src)) {
  Write-Error "仓库中未找到技能目录 skills\$Skill"
  Remove-Item -LiteralPath $tmp -Recurse -Force
  exit 1
}

# 复制到目标
New-Item -ItemType Directory -Path $Target -Force | Out-Null
$dest = Join-Path $Target $Skill
Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
Remove-Item -LiteralPath $tmp -Recurse -Force

Write-Host ""
Write-Host "已安装：$dest"
Write-Host "请重启 opencode（或对应工具）后生效。"
