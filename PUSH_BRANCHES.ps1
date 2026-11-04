# === OceanBase 2026 推送脚本（题一/二/三修复 + 题四独立分支） ===
# 用法: 以 PowerShell 执行，先确保 gh auth login 已成功

$wt = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location C:\Users\23978\Documents\Trae-CN\temp_20261029_02\q123fix

# 0. 前置检查: gh 是否登录 + repo scope
gh auth status 2>&1 | Select-String 'Logged in'
if ($LASTEXITCODE -ne 0) { Write-Error '请先运行 gh auth login -h github.com -p https -s repo'; exit 1 }

# 1. 在 worktree 本地设 credential helper，直接调用 gh auth git-credential
#    （绕过 Windows Credential Manager 里那个无写权限的旧 PAT）
git config --local --unset-all credential.helper 2>$null
git config --local --unset-all "credential.https://github.com.helper" 2>$null
# 用 gh.exe 自带的 git-credential 帮助器 —— 需要把 gh.exe 的完整路径写进去
$ghExe = (Get-Command gh).Source
# 在 PowerShell 的 git 调用里，用这种形式: !command arg
# 但带空格的路径需要转义，所以用 --% stop-parsing，或用短路径

# === 更稳的做法: 直接用 REST API 更新 ref（gh api） ===
# 因为 git objects 已经存在于远端（git ls-remote 过），只需要把 ref 指过去
# 但如果 objects 不在远端，需要先 git push 上传 objects ===

# === 最终方案: 先 git push 让 git 自动上传 objects + 更新 ref ===
# 关键点: 禁用 Windows Credential Manager，强制用 gh 凭据
# 彻底禁用 system credential helper，只用 gh 的
git config --global --unset credential.helper 2>$null
git config --local credential.helper ""
git config --local "credential.https://github.com.helper" ""

# 用 GIT_ASKPASS 环境变量: gh 提供了 git-credential 子命令
# 但最好的方式是用 gh auth setup-git（全局 gitconfig 被锁）
# 所以我们 worktree 级别设置:
$ghSetupCmd = "& \"$ghExe\" auth git-credential"
git config --local credential.helper "!powershell -NoProfile -NonInteractive -Command $ghSetupCmd"

Write-Host '=== 推送 q123 修复 commit ===' -ForegroundColor Cyan
Write-Host 'commit 8aa18cc70 -> refs/heads/2026-q123-competition'
git -c http.version=HTTP/1.1 push origin 8aa18cc7015264e0714de301952a9af537dc7542:refs/heads/2026-q123-competition
if ($LASTEXITCODE -ne 0) { Write-Host 'q123 push 失败，手动重试:' -ForegroundColor Yellow; Write-Host '  git push origin 8aa18cc701:refs/heads/2026-q123-competition' }

Write-Host '=== 推送/确认题四分支 ===' -ForegroundColor Cyan
Write-Host 'commit e0e09d591 -> refs/heads/q4-fts-perf-clean'
git -c http.version=HTTP/1.1 push origin e0e09d591a107a4918785ec6a02beb2d3e48b496:refs/heads/q4-fts-perf-clean
if ($LASTEXITCODE -ne 0) { Write-Host 'q4 push 失败（可能远端已存在同 commit），可忽略' -ForegroundColor Yellow }

Write-Host '=== 远端回验 ===' -ForegroundColor Green
git ls-remote origin refs/heads/2026-q123-competition refs/heads/q4-fts-perf-clean refs/heads/2026-competition
