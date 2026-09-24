# dispatch-order.ps1 —— 调用 dispatch-delivery-order 发单，并核对结果。
#
# ⚠️ 关键：下单人 ≠ 发单人，用错账号必然 403
#   本函数是**商家端**接口，函数里硬性校验 merchant.user_id === auth.uid()。
#   而"13421670967 的订单"里的 13421670967 是**下单的顾客**，不是商家。
#   两个身份（2026-09-23 查库确认）：
#     顾客 13421670967 -> auth.users.id = ff7a28ea-459e-4e31-a1f6-cda119a6f793
#        └ 名下订单 recipe_order.order_number = BJ-TEST-20260923115816
#     该订单的商家「李测试」-> merchant.id = 9cf341c2-8a00-4264-a958-8978afce1cdc
#        └ 老板账号 16675959975 -> auth.users.id = edbd8c4b-a4a2-4636-97f1-1eca33f35fcf
#   所以：**用 16675959975 登录发单**，发的才是 13421670967 的那张单。
#   用 13421670967 登录调用只会拿到 403「无权为该商家发单」。
#
#   该订单挂在**多条** meal_delivery_order 上（按餐次拆单），全部是北京地址。
#   其中 5436864a-be71-4ca3-bee5-08c21ac3b532 已发过单（provider_order_id=108219），
#   再发会被函数幂等拦下 —— 可先用它验证鉴权链路，不会产生新订单。
#
# 用法：
#   $env:MERCHANT_PHONE    = '16675959975'      # 商家老板账号，不是下单的顾客号
#   $env:MERCHANT_PASSWORD = '<该账号密码>'
#   pwsh -File scripts/dispatch-order.ps1
#
# 可选：
#   -DeliveryOrderId <uuid>   # 指定要发的配送单；默认用下面那条北京单
#   -DryRun                   # 只打印将要发的内容，不真的调用

param(
  [string]$SupabaseUrl = 'https://wmioylfpdbdwnbybkpju.supabase.co',
  [string]$AnonKey = 'sb_publishable_nUsNeaF2lPNRywuwqqSX9g_4T8uvxpC',
  # 默认 = 目标商家的老板账号（不是下单顾客 13421670967）。
  [string]$MerchantPhone = $(if ($env:MERCHANT_PHONE) { $env:MERCHANT_PHONE } else { '16675959975' }),
  [string]$Password = $env:MERCHANT_PASSWORD,
  [string]$DeliveryOrderId = '',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if (-not $Password -and -not $DryRun) { throw '请先设置 $env:MERCHANT_PASSWORD（商家老板账号的密码）' }

# 期望登录到的用户 id。用来挡住"密码填成顾客号"这类错误 ——
# 否则会在发单时才拿到 403，白跑一趟还容易误判成函数有 bug。
$ExpectedUserId = 'edbd8c4b-a4a2-4636-97f1-1eca33f35fcf'   # 16675959975，商家老板
$CustomerUserId = 'ff7a28ea-459e-4e31-a1f6-cda119a6f793'   # 13421670967，下单顾客
$TargetOrderNumber = 'BJ-TEST-20260923115816'

function Show-Phone([string]$p) {
  if ($p.Length -gt 7) { $p.Substring(0, 3) + '****' + $p.Substring($p.Length - 4) } else { '***' }
}

Write-Host ''
Write-Host '=== 1/3 密码登录，换取用户 JWT ===' -ForegroundColor Cyan
# 用 curl.exe + 临时文件，而不是 Invoke-RestMethod / 内联 -d：
#   - 内联 -d '{"phone":"..."}' 会被 PowerShell 吞掉内层双引号，Supabase 报 bad_json；
#   - Invoke-WebRequest 在 PS 5.1 下读不出非 2xx 的响应体（实测恒为空串），
#     而本脚本恰恰要靠错误体区分「密码错」和「服务不可达」。
# 把 body 落到临时文件用 --data-binary @file，两个问题一起解决。
function Invoke-SbJson([string]$Url, [string]$Method, [hashtable]$Body, [string]$Bearer) {
  $json = $Body | ConvertTo-Json -Compress
  $tmp = [System.IO.Path]::GetTempFileName()
  try {
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    $curlArgs = @('-s', '-X', $Method, $Url,
      '-H', "apikey: $AnonKey",
      '-H', 'Content-Type: application/json',
      '--data-binary', "@$tmp",
      '-w', "`nHTTP_STATUS:%{http_code}")
    if ($Bearer) { $curlArgs = @('-H', "Authorization: Bearer $Bearer") + $curlArgs }
    $raw = (& curl.exe @curlArgs 2>&1 | Out-String)
  } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }

  $status = if ($raw -match 'HTTP_STATUS:(\d+)') { [int]$Matches[1] } else { 0 }
  $text = ($raw -replace "`r?`nHTTP_STATUS:\d+\s*$", '').Trim()
  if ($status -lt 200 -or $status -ge 300) {
    throw ("HTTP {0}: {1}" -f $status, $text)
  }
  return $text | ConvertFrom-Json
}

try {
  $login = Invoke-SbJson "$SupabaseUrl/auth/v1/token?grant_type=password" 'POST' `
    @{ phone = $MerchantPhone; password = $Password }
} catch {
  throw ("登录失败 —— {0}" -f $_.Exception.Message)
}
if (-not $login.access_token) { throw '登录未返回 access_token' }
$token = $login.access_token
# 核对拿到的是不是**商家老板**账号。用顾客号登录也能成功登录，
# 但调用发单时会被函数判 403，所以在这里就拦下来并说明原因。
if ($login.user.id -eq $CustomerUserId) {
  throw ('登录到的是**下单顾客** 13421670967，而发单是商家端接口，' +
    '必须用商家老板账号 16675959975。请把 $env:MERCHANT_PHONE 改成 16675959975。')
}
if ($login.user.id -ne $ExpectedUserId) {
  throw ("登录到的账号不对: {0}，期望 {1}（商家老板 16675959975）" -f $login.user.id, $ExpectedUserId)
}
Write-Host ("登录成功: user={0} phone={1}（商家老板）" -f $login.user.id, (Show-Phone $MerchantPhone)) -ForegroundColor Green
Write-Host ("目标订单: {0}（下单顾客 13421670967）" -f $TargetOrderNumber)
Write-Host ''

Write-Host '=== 2/3 调用 dispatch-delivery-order ===' -ForegroundColor Cyan
if (-not $DeliveryOrderId) {
  # 默认目标：BJ-TEST-20260923115816 拆出来的一条北京配送单，
  # 属目标商家、尚未发单、状态 awaiting_preparation（在可发单白名单内）。
  $DeliveryOrderId = '007ab983-550e-49d0-8f44-dbdcb0ba93a5'
  Write-Host ("未指定 -DeliveryOrderId，使用默认目标: {0}" -f $DeliveryOrderId)
}
$body = @{ meal_delivery_order_id = $DeliveryOrderId } | ConvertTo-Json -Compress
Write-Host ("POST /functions/v1/dispatch-delivery-order  body={0}" -f $body)
if ($DryRun) { Write-Host 'DryRun，不实际调用。' -ForegroundColor Yellow; return }

$resp = $null
try {
  $resp = Invoke-SbJson "$SupabaseUrl/functions/v1/dispatch-delivery-order" 'POST' `
    @{ meal_delivery_order_id = $DeliveryOrderId } $token
  Write-Host 'HTTP 200'
} catch {
  # 函数用 4xx/5xx 表达业务失败（幂等、状态不符、发单被拒），
  # 这些是**预期结果**而非脚本故障，必须把响应体原样打出来再决定下一步。
  # Invoke-SbJson 已把响应体拼进异常消息，这里只负责展示。
  Write-Host $_.Exception.Message
  $resp = $null
}
if ($resp) { Write-Host ($resp | ConvertTo-Json -Depth 6) }
# 注意：这里不打印 token。
Write-Host ''
Write-Host '=== 3/3 结论 ===' -ForegroundColor Cyan
Write-Host '若上面返回 provider_order_id，说明已真实下发到快递100；'
Write-Host '随后快递100 会回调 DELIVERY_CALLBACK_URL，状态变更可查 meal_delivery_order 表的'
Write-Host 'provider_status / courier_name / last_callback_at 字段。'