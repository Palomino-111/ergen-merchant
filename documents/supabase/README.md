# 备餐提醒：部署、验收、踩坑记录

> 2026-10-15 实测。相关提交见 `remain_prepare_dzy` 分支。
> 本目录的 `.ts` 是 Edge Function 源码副本，**需复制到 Supabase 控制台去部署**
> （本仓库不含 `supabase/functions/`）。

---

## 1. 功能概述

**做什么**：订单到达 `delivery_time - 45 分钟` 时，向该商家的设备推一条「该备餐了」的提醒。

**不做什么**：
- 不加「开始备餐/备餐完成」按钮
- 不引入 `preparing` 状态
- 不做商家侧提醒时间设置页（默认值写死）
- 不做全量广播（只走 `token_list` 定向）

**架构**：

    Supabase meal_delivery_order
      ↓ preparation_reminded_at（幂等标记）
    pg_cron 每分钟触发
      ↓ net.http_post
    Edge Function meal-prep-remind
      ↓ claim_due_meal_reminders RPC
      ↓ merchant_device 查 token
      ↓ TPNS REST API
    商家手机

---

## 2. 部署步骤

### 2.1 数据层

在 Supabase SQL Editor 执行 `schema.sql` 全部内容。

### 2.2 Edge Function

1. 控制台 → Edge Functions → Deploy a new function → Via Editor
2. Function name：`meal-prep-remind`
3. 代码：见 `meal-prep-remind.ts`
4. 部署后进入 **Settings** → 关闭 **Verify JWT with legacy secret**
   （否则 pg_cron 调用会被拦）

### 2.3 Secrets

在 Edge Functions → Secrets 添加：

- `TPNS_ACCESS_ID`：TPNS 控制台商家端应用的 AccessID
- `TPNS_SECRET_KEY`：TPNS 控制台商家端应用的 SecretKey（**绝不进仓库**）
- `CRON_SECRET`：随机字符串（可用 PowerShell 生成 64 位 hex）

**注意**：`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` 是 Supabase 自动注入的，
不需要手动配。

### 2.4 cron

执行 `cron-setup.sql`（把里面的 `CRON_SECRET` 占位替换成真实值）。

### 2.5 客户端

见 `lib/common/push/tpns_service.dart` 的注释。

---

## 3. 验收方法

### 3.1 dry-run：先数一遍命中条数

**上线前必须先跑**（防止历史僵尸单被一次性推）：

    select count(*) as would_remind_count
    from public.meal_delivery_order
    where status = 'awaiting_preparation'
      and preparation_reminded_at is null
      and delivery_time - interval '45 minutes' <= now()
      and delivery_time >= now() - interval '2 hours';

`0 条~几十条` 是合理范围；**上千条**说明下界窗口失效，别开 cron。

### 3.2 手动触发一次

    select net.http_post(
      url := 'https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/meal-prep-remind',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', '<你的 CRON_SECRET>'
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    );

5 秒后查结果：

    select id, status_code, content, created
    from net._http_response order by created desc limit 1;

预期：`{"claimed":N,"pushed":N,"failed":0,"elapsed_ms":xxx}`。

### 3.3 真机验收

见 `documents/待办.md` 里的验收清单。

---

## 4. 踩过的坑

### 4.1 TPNS 的 custom_content 必须是字符串，不能是对象

**症状**：Edge Function 返回 `pushed:0, failed:1`，Logs 里看到
`TPNS HTTP 422: ret_code=1008001, "field 'message.android.custom_content' is not the type: object"`。

**根因**：TPNS 要求 `custom_content` 是 **JSON 字符串**（文档 Android 示例是
`"custom_content": "{\"key\":\"value\"}"`），不是 JSON 对象。

**修法**：Edge Function 里改成 `custom_content: JSON.stringify(customContent)`。

### 4.2 Supabase Edge Function 到 TPNS 的 POST 可能挂起

**症状**：第一次实测时，多组 `fetch` 到 `api.tpns.tencent.com` 都超时（10 秒 abort），
但同样 endpoint 的 GET 请求 359ms 就返回 404。

**排查过程**：用独立测试函数从简单 body 逐步加字段，最终发现**同一份 body 两次跑结果不同**
—— 那次超时是**偶发**，不是稳定失败。

**教训**：这种「跨境链路偶发」必须**多次采样**，不能凭单次结果下结论。

**处置**：目前保留 10 秒超时 + 回滚标记，让下一轮 cron 重试。若后续实测失败率仍高，
再上 `TPNS_PROXY` 国内中继（消费端已经有同类方案）。

### 4.3 TPNS 客户端回调字段名和 FCM 不一样

**症状**：前台收到推送，bot_toast 里显示的文案是 fallback（「有新订单需要备餐」），
而不是服务端发的真实文案；点击也不跳转。

**根因**：TPNS Android 客户端回调结构是：

    {
      notifactionId: 30146429,
      pushChannel: 100,
      activity: "com.zheergen.zheergen_merchant_end.MainActivity",
      customMessage: "{\"type\":\"MEAL_PREP_REMIND\",\"orderId\":\"...\"}",
      msgId: 2110696737160040448,
      title: "该备餐了",
      content: "有订单预计 18:25 送达，请开始备餐",
      notifactionActionType: 1,
    }

和 FCM 风格不同：
- 通知内容在 **`content`**（不是 `body`）
- 业务字段在 **`customMessage`**（是**字符串 JSON**，不是 `customContent` 对象）

**修法**：`_showInAppNotification` 读 `content`，`_extractOrderId` 优先解析 `customMessage`，
其它字段名（`custom` / `customContent` / 顶层 `orderId`）保留作兼容。

### 4.4 部分设备 onRegisteredDeviceToken 不触发

**症状**：TPNS 日志出现 `注册完成`，但永远没有 `注册成功, token: xxx`，
`merchant_device` 表空。

**根因**：TPNS Flutter 插件底层是原生 SDK，回调触发时机依赖设备厂商/系统版本/ROM。
部分设备 `onRegisteredDeviceToken` 就是静默的。

**修法**：`onRegisteredDone` 里主动调 `XgFlutterPlugin.xgToken` 取一次，
取到了走同一条上报路径。

### 4.5 加 preparation_reminded_at 列会触发 Realtime UPDATE

给 `meal_delivery_order` 加这一列之后，每次提醒都会产生一条 UPDATE 事件推到商家端。
现有 `mergeDeliveryOrderRow` 只认已知字段、多余列会被忽略，但**上线前必须用真机验证
一次「提醒之后列表不抖、菜品列表不消失」**（这条路径以前踩过嵌套字段被冲掉的坑）。

---

## 5. 已知限制

### 5.1 无厂商通道 → App 后台/被杀后收不到

按既定决策，**不接华为/小米/OPPO/vivo/荣耀厂商 SDK**。

**实测（2026-10-15，华为 HBN-AL00）**：
- App **前台**（长连接活着）：稳定收到，延迟约 30 秒
- App **切后台**：几秒~几分钟内可能收到，之后长连接被 ROM 掐断
- App **后台超过几分钟 / 被杀**：收不到

**TPNS 控制台证据**：对后台状态的设备单设备直发，推送漏斗显示
「计划发送 1 / **实际发送 0** / 设备抵达数 0」——TPNS 已经判定设备离线，
**连发送都没执行**，与我们服务端的代码/签名/字段无关。

**这是「不接厂商通道」的必然代价**，不是 bug。华为对第三方 App 后台长连接
管控最激进（为了省电），需要接入华为推送服务（HMS Push）才能让 App
被杀/冻结后仍收到推送。

**验收标准调整**：
- 原第 3 条「App 被杀/锁屏」→ 跳过（已知限制）
- 原第 2 条「App 后台（未杀）」→ 降级为「App 前台（长连接活着）能收到 + 点击跳转」

**未来若要支持后台**：需接华为/小米/OPPO/vivo/荣耀厂商 SDK（原生配置 + 控制台
配 AppID/Key），工作量和复杂度都不小，另立任务评估。

### 5.2 同一商家多设备同时推

`merchant_device` 是 1:N（一个商家可以有多台手机登录）。
Edge Function 用 `in` 查询按 `merchant_id` 拿到所有 token，一次性推给全部设备。

### 5.3 无重试队列

推送失败只回滚标记，靠下一轮 cron 重试（每分钟一次）。
如果 TPNS 持续失败，等于这条单一直没提醒，直到过了 `now() - 2h` 的下界被放弃。

若业务量上来后需要严格重试，再演进成独立任务表 + 退避重试。