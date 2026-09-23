# repro-login.ps1 —— 一次性调试脚本（用完可删）
#
# 目的：判定 App「登录失败」到底是 ①手机号格式 ②密码 ③网络 ④项目/账号不对。
# 做法：把 App 实际会发的那条请求，和「加上 +86」的版本各发一次，只差一个变量，
#       再（可选）用 service_role 直接查库里账号真实存的 phone 是什么。
#
# 用法（凭据只放环境变量，避免进命令行历史/截图）：
#   $env:TEST_PHONE    = '13800138000'            # 就填 App 里输入的那个裸号
#   $env:TEST_PASSWORD = '<测试账号密码>'
#   $env:HTTPS_PROXY   = 'http://127.0.0.1:7890'  # 本机直连 supabase 实测 curl exit=35，需代理
#   pwsh -File scripts/repro-login.ps1
#
# 可选：
#   $env:SB_SERVICE_ROLE = '<service_role key>'   # 填了会额外列出账号真实存储的手机号/是否确认/登录方式
#
# 输出里不会打印密码、access_token、refresh_token。

param(
  [string]$SupabaseUrl = 'https://redkowdpjduavcmzjfep.supabase.co',
  [string]$AnonKey = $env:SB_ANON,
  [string]$Proxy = $env:HTTPS_PROXY
)

$ErrorActionPreference = 'Stop'

# ---- anon key 缺省时从 lib/main.dart 读取，不在这里重复写死密钥 ----
if (-not $AnonKey) {
  $mainPath = Join-Path $PSScriptRoot '..\lib\main.dart'
  if (-not (Test-Path $mainPath)) { throw '找不到 lib/main.dart，请用 $env:SB_ANON 传入 anonKey' }
  $src = Get-Content $mainPath -Raw
  $m = [regex]::Match($src, "anonKey:\s*'([^']+)'")
  if (-not $m.Success) { throw '没能从 main.dart 解析出 anonKey，请用 $env:SB_ANON 传入' }
  $AnonKey = $m.Groups[1].Value
}

if (-not $env:TEST_PHONE)    { throw '请先设置 $env:TEST_PHONE（11 位裸号，和 App 里输入的一致）' }
if (-not $env:TEST_PASSWORD) { throw '请先设置 $env:TEST_PASSWORD' }

$bare = ($env:TEST_PHONE -replace '\D', '')      # App 实际发送的形态：纯数字
$e164 = if ($bare.StartsWith('86')) { "+$bare" } else { "+86$bare" }

function Show-Phone([string]$p) {
  $masked = if ($p.Length -gt 7) { $p.Substring(0, 3) + '****' + $p.Substring($p.Length - 4) } else { '***' }
  "{0} (len={1}, startsWithPlus={2})" -f $masked, $p.Length, $p.StartsWith('+')
}

# ---- 发一次密码登录请求，返回 @{ status; body } ----
function Invoke-PasswordGrant([string]$phone) {
  $body = @{ phone = $phone; password = $env:TEST_PASSWORD } | ConvertTo-Json -Compress
  $curlArgs = @(
    '-s', '-X', 'POST', "$SupabaseUrl/auth/v1/token?grant_type=password",
    '-H', "apikey: $AnonKey",
    '-H', 'Content-Type: application/json',
    '-d', $body,
    '-w', "`nHTTP_STATUS:%{http_code}"
  )
  if ($Proxy) { $curlArgs = @('--proxy', $Proxy) + $curlArgs }
  $raw = & curl.exe @curlArgs 2>&1 | Out-String
  $status = if ($raw -match 'HTTP_STATUS:(\d+)') { $Matches[1] } else { '000' }
  $json = ($raw -replace "`r?`nHTTP_STATUS:\d+\s*$", '').Trim()
  $errCode = ''; $msg = ''
  try {
    $o = $json | ConvertFrom-Json
    $errCode = $o.error_code; $msg = $o.msg
    if (-not $errCode -and $o.code) { $errCode = $o.code }
  } catch { $msg = $json }
  return [pscustomobject]@{ Status = $status; ErrorCode = $errCode; Msg = $msg }
}

Write-Host ''
Write-Host '=== Supabase Auth 密码登录：两种手机号形态对比 ===' -ForegroundColor Cyan
Write-Host ("项目: {0}" -f $SupabaseUrl)
Write-Host ("代理: {0}" -f $(if ($Proxy) { $Proxy } else { '(未设置，直连)' }))
Write-Host ''

$r1 = Invoke-PasswordGrant $bare
Write-Host ("[A] App 实际发送   phone = {0}" -f (Show-Phone $bare))
Write-Host ("    HTTP {0}  error_code={1}  msg={2}" -f $r1.Status, $r1.ErrorCode, $r1.Msg)
Write-Host ''
$r2 = Invoke-PasswordGrant $e164
Write-Host ("[B] 加国家码版本   phone = {0}" -f (Show-Phone $e164))
Write-Host ("    HTTP {0}  error_code={1}  msg={2}" -f $r2.Status, $r2.ErrorCode, $r2.Msg)
Write-Host ''

# ---- 可选：用 service_role 查账号真实存储的手机号 ----
if ($env:SB_SERVICE_ROLE) {
  Write-Host '=== admin 查询：账号在库里真实存了什么 ===' -ForegroundColor Cyan
  $adminArgs = @(
    '-s', "$SupabaseUrl/auth/v1/admin/users?per_page=200",
    '-H', "apikey: $($env:SB_SERVICE_ROLE)",
    '-H', "Authorization: Bearer $($env:SB_SERVICE_ROLE)"
  )
  if ($Proxy) { $adminArgs = @('--proxy', $Proxy) + $adminArgs }
  try {
    $users = (& curl.exe @adminArgs 2>&1 | Out-String) | ConvertFrom-Json
    foreach ($u in $users.users) {
      $phone = $u.phone
      if (-not $phone) { continue }
      if (-not (($phone -replace '\D', '').EndsWith($bare.Substring([Math]::Max(0, $bare.Length - 4))))) { continue }
      Write-Host ("  stored phone      = {0}" -f (Show-Phone $phone))
      Write-Host ("  phone_confirmed_at= {0}" -f $u.phone_confirmed_at)
      Write-Host ("  identities        = {0}" -f (($u.identities | ForEach-Object { $_.provider }) -join ', '))
      Write-Host ("  last_sign_in_at   = {0}" -f $u.last_sign_in_at)
      Write-Host ''
    }
  } catch { Write-Host ("  admin 查询失败: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }
}

Write-Host '=== 结论 ===' -ForegroundColor Cyan
if ($r1.Status -eq '200') {
  Write-Host '裸号就能登录 → 手机号格式不是根因。App 里的失败另有原因（看下面的 B/网络/本地校验）。'
} elseif ($r2.Status -eq '200' -and $r1.Status -ne '200') {
  Write-Host '根因确认：App 少发了国家码。库里存的是 +86…，App 发的是裸号 → GoTrue 查不到用户，返回 invalid_credentials。' -ForegroundColor Green
  Write-Host '修复：所有把手机号发给 Supabase 的地方统一转成 E.164（+86 前缀）。'
} elseif ($r1.Status -eq '000' -and $r2.Status -eq '000') {
  Write-Host '两个都没发出去（HTTP 000）→ 网络问题。设 $env:HTTPS_PROXY 重试；手机端同理，没代理就连不上 supabase.co。' -ForegroundColor Yellow
} elseif ($r1.ErrorCode -eq 'invalid_credentials' -and $r2.ErrorCode -eq 'invalid_credentials') {
  Write-Host '两种形态都是 invalid_credentials → 手机号格式不是根因。看 admin 输出：该账号可能没设密码（OTP 注册的账号没有 password），或密码/项目不对。' -ForegroundColor Yellow
} else {
  Write-Host '结果不典型，把上面两行 HTTP/error_code 原样贴出来。'
}
