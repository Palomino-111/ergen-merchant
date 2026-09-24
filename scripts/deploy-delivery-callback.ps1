# deploy-delivery-callback.ps1 —— 部署快递100 回调接收端并验证。
#
# 为什么需要这个脚本：`supabase` CLI 在本机装的是 win32-x64 缺失的 npm 包，
# 直接报 "No matching Supabase CLI binary package found"，跑不了 supabase functions deploy。
# 所以改走 Management API，只需要一个 sbp_ 开头的 Personal Access Token。
#
# 用法：
#   $env:SUPABASE_ACCESS_TOKEN = 'sbp_xxx'   # https://supabase.com/dashboard/account/tokens
#   pwsh -File scripts/deploy-delivery-callback.ps1
#
# 做三件事：
#   1. 部署 delivery-order-callback（verify_jwt=false，回调不带 JWT，必须关）
#   2. 写 DELIVERY_CALLBACK_URL secret（短路径跳板 URL，见 supabase/config.toml 注释）
#   3. 用一份伪造的 kuaidi100 回调（正确签名）打一次，确认验签+落库链路通

param(
  [string]$ProjectRef = 'wmioylfpdbdwnbybkpju',
  [string]$SupabaseUrl = 'https://wmioylfpdbdwnbybkpju.supabase.co',
  # 回调 URL。文档写「最长50字符」，但 2026-09-24 逐个长度实测**并不强制**
  # （不带/50/70/88/255 字符全部 code 200），所以直接用真实 slug，无需短域名或跳板。
  # ⚠️ slug 会变：首次部署时被自动生成成 clever-responder，重新部署后才变成
  #    delivery-order-callback。换项目/重部署后先用 supabase functions list 核对再改这里。
  [string]$CallbackUrl = 'https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/delivery-order-callback',
  # 必须与线上真实 slug 一致：写成别的会另建一个函数，而回调仍打在旧 slug 上。
  [string]$Slug = 'delivery-order-callback'
)

$ErrorActionPreference = 'Stop'
$token = $env:SUPABASE_ACCESS_TOKEN
if (-not $token) { throw '请先设置 $env:SUPABASE_ACCESS_TOKEN（sbp_ 开头的 Personal Access Token）' }

$root = Join-Path $PSScriptRoot '..'
$headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }

Write-Host ''
Write-Host '=== 1/4 检查 callbackUrl ===' -ForegroundColor Cyan
Write-Host ("URL    : {0}" -f $CallbackUrl)
Write-Host ("长度   : {0} 字符（文档写上限 50，实测不强制）" -f $CallbackUrl.Length)
if ($CallbackUrl -notmatch "/$([regex]::Escape($Slug))$") {
  Write-Host ("⚠️  URL 结尾与 slug '{0}' 不一致，确认不是笔误。" -f $Slug) -ForegroundColor Yellow
}
Write-Host ''

Write-Host '=== 2/4 部署 delivery-order-callback（verify_jwt=false）===' -ForegroundColor Cyan
$fnPath = Join-Path $root 'supabase\functions\delivery-order-callback\index.ts'
if (-not (Test-Path $fnPath)) { throw "找不到函数源码: $fnPath" }
$fnSource = Get-Content $fnPath -Raw
$deployBody = @{
  # slug 是 URL 里真正生效的那一段，必须与线上已有的一致（clever-responder）。
  # 函数还有个 name（显示名，这里是 delivery-order-callback），那只是标签，
  # 网关不认 —— 实测 /functions/v1/delivery-order-callback 返回 404，
  # 而 /functions/v1/clever-responder 返回 401（存在，仅被 JWT 挡）。
  slug     = $Slug
  name     = 'delivery-order-callback'
  verify_jwt = $false          # ⚠️ 必须 false：回调不带 JWT，true 会在网关层被 401 挡掉
  entrypoint_path = 'index.ts'
  files    = @(@{ name = 'index.ts'; content = $fnSource })
} | ConvertTo-Json -Depth 8 -Compress

# 先查再决定 PATCH 还是 POST。
# 无脑 POST 会在函数已存在时**再建一个**，并由服务端另发一个新随机 slug，
# 于是 URL 又变了、回调继续打空 —— 这个坑不值得踩第二次。
$fnUrl = "https://api.supabase.com/v1/projects/$ProjectRef/functions/$Slug"
$exists = $true
try { Invoke-RestMethod -Uri $fnUrl -Method GET -Headers $headers | Out-Null }
catch { $exists = $false }

if ($exists) {
  $r = Invoke-RestMethod -Uri $fnUrl -Method PATCH -Headers $headers -Body $deployBody
  Write-Host ("已更新: slug={0} version={1} verify_jwt={2}" -f $r.slug, $r.version, $r.verify_jwt) -ForegroundColor Green
} else {
  Write-Host ("slug '{0}' 不存在，将新建（新 slug 可能由服务端重新生成，记得回来核对）" -f $Slug) -ForegroundColor Yellow
  $r = Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ProjectRef/functions" -Method POST -Headers $headers -Body $deployBody
  Write-Host ("已创建: slug={0} version={1} verify_jwt={2}" -f $r.slug, $r.version, $r.verify_jwt) -ForegroundColor Green
  if ($r.slug -ne $Slug) {
    Write-Host ("⚠️ 服务端实际 slug 是 '{0}'，与传入的 '{1}' 不同；" -f $r.slug, $Slug) -ForegroundColor Yellow
    Write-Host ("   请把 -CallbackUrl 改成 .../functions/v1/{0} 后重跑第 3 步。" -f $r.slug) -ForegroundColor Yellow
  }
}
Write-Host ''

Write-Host '=== 3/4 写 DELIVERY_CALLBACK_URL secret ===' -ForegroundColor Cyan
# Management API 的 secrets 接口是「整体覆盖」语义，先读回现有 secrets 再合并，
# 否则会把 KUAIDI100_KEY / SUPABASE_* 等一次性抹掉。
$secretsUrl = "https://api.supabase.com/v1/projects/$ProjectRef/secrets"
$existing = Invoke-RestMethod -Uri $secretsUrl -Method GET -Headers $headers
$merged = @($existing | Where-Object { $_.name -ne 'DELIVERY_CALLBACK_URL' } |
  ForEach-Object { @{ name = $_.name; value = $_.value } })
$merged += @{ name = 'DELIVERY_CALLBACK_URL'; value = $CallbackUrl }
Invoke-RestMethod -Uri $secretsUrl -Method POST -Headers $headers `
  -Body (@{ secrets = $merged } | ConvertTo-Json -Depth 5 -Compress) | Out-Null
Write-Host ("已写入 DELIVERY_CALLBACK_URL（保留原有 {0} 个 secret）" -f ($merged.Count - 1)) -ForegroundColor Green
Write-Host ''

Write-Host '=== 4/4 自测回调端点（伪造 kuaidi100 请求 + 正确签名）===' -ForegroundColor Cyan
# 需要与函数同一份 salt 才能算出合法签名。salt 从环境变量读，绝不写死在仓库里。
$salt = $env:DELIVERY_CALLBACK_SALT
if (-not $salt) {
  Write-Host '跳过：未设置 $env:DELIVERY_CALLBACK_SALT（值同函数侧 secret），无法生成合法签名。' -ForegroundColor Yellow
  Write-Host '拿真实 salt 后可重跑本脚本，或直接在快递100 发单后看函数日志。' -ForegroundColor Yellow
} else {
  $paramJson = '{"orderId":"__selftest__","kuaidicom":"dadatongcheng","status":310,"statusDesc":"配送中","updateTime":"2026-09-23 12:00:00"}'
  $md5 = [System.Security.Cryptography.MD5]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($paramJson + $salt)
  $sign = ([BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', '')
  $form = @{ taskId = '__selftest__'; param = $paramJson; sign = $sign }
  try {
    $resp = Invoke-RestMethod -Uri $CallbackUrl -Method POST -Body $form -TimeoutSec 30
    Write-Host ("响应: {0}" -f ($resp | ConvertTo-Json -Compress))
    if ($resp.returnCode -eq '200') {
      Write-Host '✅ 验签通过、端点可达（orderId 是伪造的，函数会记 not found 日志，属正常）' -ForegroundColor Green
    } else {
      Write-Host '⚠️  端点返回了非 200，检查 salt 是否与函数侧一致' -ForegroundColor Yellow
    }
  } catch {
    Write-Host ("❌ 回调自测失败: {0}" -f $_.Exception.Message) -ForegroundColor Red
  }
}
Write-Host ''
Write-Host '完成。' -ForegroundColor Cyan