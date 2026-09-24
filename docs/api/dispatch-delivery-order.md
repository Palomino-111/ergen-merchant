# 发单：`dispatch-delivery-order`

商家备餐完成后点「呼叫骑手」，由本边缘函数向**快递100 同城急送**下发真实运力订单（method=`order`）。

本文档描述的是**线上实际部署的行为**，2026-09-23 端到端实测。文中所有响应示例均为真实调用返回。

**验证状态：成功路径已跑通。** 实测一笔真实发单返回：

```json
{"provider_order_id":"108219","provider_task_id":"D3DAE4DBD396490784F610B474CB223D","provider_fee":9.38,"status":"awaiting_delivery"}
```

落库核对无误（`status=awaiting_delivery`、`provider_status=0`、`provider_fee=9.38`、`dispatch_failed_reason` 已清空）；
对同一单重复调用正确返回 `already_dispatched`，未产生第二笔单。

---

## 基本信息

| 项 | 值 |
| --- | --- |
| 函数名 | `dispatch-delivery-order` |
| 项目 | `wmioylfpdbdwnbybkpju` |
| URL | `https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/dispatch-delivery-order` |
| 方法 | `POST` |
| `verify_jwt` | `true` |
| 源码 | `supabase/functions/dispatch-delivery-order/index.ts` |
| 源码真源 | 本仓库；此前 11 个函数只存在于云端，无版本控制 |

> ⚠️ **本函数会产生真实费用**。每次成功调用都会在快递100 侧创建一笔真实运力订单并扣费，不是模拟单。文档第 5 步的幂等保护就是为此而设。

---

## 鉴权

必须携带**用户 JWT**。函数把它显式转发给 PostgREST，因此 RLS 以该用户身份生效；随后还会显式校验 `merchant.user_id === auth.uid()`。

```http
Authorization: Bearer <access_token>
apikey: <publishable key>
Content-Type: application/json
```

JWT 由客户端 `supabase.auth` 会话提供，客户端**不需要**、也不应该自己传商家归属或地址信息。

> 手机号登录注意：`phone` 字段要用**不带国家码**的形式（`13560522844`）。传 `+8613560522844` 会得到 `invalid_credentials`。

---

## 请求体

```json
{ "meal_delivery_order_id": "50467e0e-4b32-4e69-b041-3671c3e95505" }
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `meal_delivery_order_id` | string (uuid) | 是 | 配送单 id |

**只收这一个字段。** 收件地址、金额、重量一律由服务端查库组装，不接受客户端传入 —— 见「设计要点」。

---

## 响应

### 成功 `200`

```json
{
  "provider_order_id": "1000000000000000001",
  "provider_task_id": "1234567890",
  "provider_fee": 5.5,
  "status": "awaiting_delivery"
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `provider_order_id` | string | 快递100 `orderId`，回调对账主键，有唯一索引 |
| `provider_task_id` | string | 快递100 `taskId`，取消/加小费时必填 |
| `provider_fee` | number \| null | 折扣配送费（我方实际成本，元）。非数字则返回 `null` |
| `status` | string | 固定 `awaiting_delivery` |

同时落库：`delivery_provider='kuaidi100'`、`provider_status=0`、`dispatched_at`，并把 `dispatch_failed_reason` 清空。

> `provider_fee` 是**我方支出成本**，与向用户收取的 `delivery_fee` 是两回事，展示时勿混用。

### 幂等 `200`

已发过单且未取消时直接返回，**不会**重复下单：

```json
{
  "already_dispatched": true,
  "provider_order_id": "...",
  "provider_task_id": "...",
  "status": "awaiting_delivery"
}
```

### 错误

所有错误都是统一 JSON，不会出现 runtime 裸 500。

| HTTP | `error` | 触发条件 | 实测响应 |
| --- | --- | --- | --- |
| 400 | `缺少 meal_delivery_order_id` | body 缺字段 | `{"error":"缺少 meal_delivery_order_id"}` |
| 401 | `缺少 Authorization` | 无 Auth 头 | `{"error":"缺少 Authorization"}` |
| 401 | `token 无效或已过期` | JWT 格式合法但无效/过期 | — |
| 403 | `无权为该商家发单` | `merchant.user_id !== auth.uid()` | — |
| 404 | `配送单不存在或无权访问` | id 不存在，或被 RLS 挡住 | `{"error":"配送单不存在或无权访问"}` |
| 409 | `当前状态 X 不可发单` | 状态不是可发单状态 | `{"error":"当前状态 delivering 不可发单"}` |
| 500 | `读取配送单失败` / `读取商家失败` | 查库报错，附 `detail` | — |
| 500 | `服务器内部错误` | 兜底异常（body 非 JSON、fetch 抛错等） | — |
| 500 | `发单已成功但本地落库失败…` | **见下方「危险状态」** | — |
| 502 | `发单失败` | 快递100 拒绝，附 `code`/`detail` | `{"error":"发单失败","code":30001,"detail":"收件人经度需精确到小数点后6位"}` |

> 401 有两种来源，别混淆：**格式非法**的 JWT 会被 Supabase 网关先拦下，返回 `{"code":"UNAUTHORIZED_INVALID_JWT_FORMAT","message":"Invalid JWT"}`，请求根本到不了函数；`token 无效或已过期` 只会出现在格式合法但过期/失效的情况。

### 可发单状态

仅 `awaiting_preparation`、`preparing` 可发单。

**刻意不含 `awaiting_delivery`** —— 那是本函数成功后的目标状态，放行它等于允许对已发单的单重复发单。

---

## 发单前置条件

函数从库里读取并直接交给快递100，因此数据必须满足：

**配送单（`meal_delivery_order`）**

| 字段 | 要求 |
| --- | --- |
| `status` | `awaiting_preparation` 或 `preparing` |
| `recipient_name` / `phone` | 非空 |
| `province` / `city` / `district` / `detailed_address` | 非空 |
| `latitude` / `longitude` | 非空，**且恰好 6 位小数、末位非 0** |

**商家（`merchant`）**

| 字段 | 要求 |
| --- | --- |
| `user_id` | 必须等于当前登录用户 |
| `name` / `phone` | 非空 |
| `province` / `city` / `district` / `detailed_address` | 非空 |
| `latitude` / `longitude` | 非空，**且恰好 6 位小数、末位非 0** |

---

## 服务端 Secrets

| 名称 | 必填 | 说明 |
| --- | --- | --- |
| `KUAIDI100_KEY` | 是 | 快递100 授权 key。缺失 → 500 |
| `KUAIDI100_SECRET` | 是 | 快递100 授权 secret。缺失 → 500 |
| `DELIVERY_CALLBACK_SALT` | 是 | 回调验签盐，随单发出。**缺失即抛错**，不静默跳过 |
| `DELIVERY_CALLBACK_URL` | 否 | 回调地址。受快递100 **50 字符**限制，未配置时单仍可发，只是拿不到状态回调 |

配置命令：

```bash
supabase secrets set KUAIDI100_KEY=... KUAIDI100_SECRET=... --project-ref wmioylfpdbdwnbybkpju
```

---

## 快递100 调用细节

- 地址：线上为 `http://e-test.kuaidilab.com/api/bsamecity/order`（测试网关），仓库文件里写的是 `https://api.kuaidi100.com/bsamecity/order`（正式）
- 编码：`application/x-www-form-urlencoded`，字段 `method=order`、`key`、`t`、`sign`、`param`
- 签名：`sign = MD5(param + t + key + secret)`，**32 位大写**
- 关键：`param` 必须与签名使用**同一份**序列化结果，否则报 `30002 验证签名失败`
- 运力：`kuaidicom = dadatongcheng`（达达）。同级编码：`shunfengtongcheng`（顺丰同城）/ `meituantongcheng`（美团跑腿）/ `fengniaotongcheng`（蜂鸟）
- 重量：固定 `1` kg（餐品实际重量未采集）
- 订单类型：`orderType = 0` 立即单，不传预约时间
- `thirdId`：传我方配送单 UUID，作为回调对账的兜底标识

### 测试环境（`e-test.kuaidilab.com`）约束 —— 重要

测试门户 `testapi.kuaidilab.com` 明确列出：同城急送的测试环境就是把请求地址换成
`http://e-test.kuaidilab.com/api/bsamecity/order`。实测到的约束：

| 约束 | 说明 |
| --- | --- |
| **运力** | 测试账号实测**只有 `dadatongcheng`（达达）能发单成功**；`shunfengtongcheng`、`meituantongcheng` 均返回 `30005` |
| **地址** | 仅支持**北京**地址（快递100 客服口径）|
| **坐标** | 必须恰好 6 位小数、末位非 0 |

> ⚠️ 快递100 公开 FAQ 页 `api.kuaidi100.com/document/tongchengceshi` 写着
> 「同城急送接口下单暂无测试环境、沙箱环境」—— **该页过时/有误**。
> 不要据此判断测试环境不存在，以测试门户 `testapi.kuaidilab.com` 为准。

### 已实测的错误码

| code | message | 含义 |
| --- | --- | --- |
| `30001` | `收件人经度需精确到小数点后6位` | 坐标不是恰好 6 位小数 |
| `30001` | `收件人的手机号格式不正确` | 手机号带 `86` 国家码前缀等格式问题 |
| `30003` | `账号信息不对` | key/secret 与网关不匹配 |
| `30004` | `账号单量不足需要充值` | 测试账号余额/额度不足 |
| `30005` | `该运力暂不支持该地址` | 测试环境下**运力选错**（应选达达）或地址不受支持 |

`30005` 官方定义是「快递公司返回异常」的**通用**错误码，消息由下游透传 ——
不要只按字面理解成「地址问题」。我们排查时被这句话误导了很久。

---

## 处理流程

1. 取 `Authorization` 头 → 缺失返回 401
2. 建 supabase 客户端（**转发该 JWT**，RLS 才有身份）
3. 解析 body 取 `meal_delivery_order_id` → 缺失返回 400
4. `auth.getUser()` 校验 JWT → 无用户返回 401
5. 读配送单 → 不存在返回 404
6. **幂等**：已有 `provider_order_id` 且未取消 → 直接返回 `already_dispatched`
7. 校验状态可发单 → 否则 409
8. 读商家 → 不存在 404；`user_id` 不匹配 403
9. 组装 `param`（寄件人=商家，收件人=配送单），附 `salt` / `callbackUrl`
10. 调快递100 `method=order`
11. 失败 → 写 `dispatch_failed_reason`，返回 502
12. 成功 → 落库单号/成本，状态推进 `awaiting_delivery`，返回 200

---

## 设计要点（改动前先读）

**为什么不信任客户端地址与金额**
只收配送单 id，其余全部服务端查库。客户端传地址＝任何人可伪造发单地址与金额，而发单是**真实扣费**行为。

**为什么显式比对 `merchant.user_id`**
`merchant` 表的 SELECT 策略是公开可读（`USING true`），RLS **不构成**归属校验。不显式比对，任何登录用户都能拿别人的商家地址发单。

**为什么不能不转发 JWT**
不能用 `headers: req.headers` —— `req.headers` 是 `Headers` 实例，而 supabase-js 用对象展开（`{...headers}`）合并，展开 `Headers` 得到 `{}`，`Authorization` 会被**静默丢弃**。必须显式取 `get('Authorization')` 再塞进 `global.headers`。

**为什么 `DELIVERY_CALLBACK_SALT` 缺失要抛错**
salt 用于快递100 给回调签名。没配则回调**无法验签**，属部署失误，必须立刻暴露，而不是静默发单留下无法验签的通道。

**`provider_fee` 为什么显式判空**
`discountFee` 可能是 `''` 或非数字，而 `Number('') === 0` 会写成**假成本**，因此显式判断 `discountFee && Number.isFinite(...)`。

**函数职责边界**
只做**发单**。取消、加小费是另外的 method，将来另建函数，**不要**往这里堆 `method` 分支。

### ⚠️ 危险状态：真实单已发出但本地落库失败

落库失败时返回 **500 而非成功**，因为此时真实运力单**已经产生**（已扣费）却无本地单号。调用方须按 `thirdId` 去快递100 后台核对后人工补录，**不能**当成功处理。

---

## 相关数据表

| 列 | 分组 | 说明 |
| --- | --- | --- |
| `delivery_provider` | 通用 | 写死 `kuaidi100`。为将来换服务商预留的判别字段 |
| `provider_order_id` | 服务商凭证 | 回调对账主键，有唯一索引 |
| `provider_task_id` | 服务商凭证 | 取消/加小费必填 |
| `provider_status` | 服务商凭证 | 快递100 原始码 `0/100/210/230/310/515/510/520/720`，换家后语义不通用 |
| `provider_status_desc` | 服务商凭证 | 上述码的中文描述 |
| `provider_fee` | 通用 | 我方实际成本（元） |
| `courier_name` / `courier_mobile` | 通用 | 骑手信息，由**回调**写入。`courier_mobile` 属 PII |
| `dispatched_at` | 通用 | 发单成功时间 |
| `dispatch_failed_reason` | 通用 | 最近一次失败原因；成功后清空 |
| `last_callback_at` | 通用 | 最后一次收到回调的时间 |

回调原文另存 `delivery_callback_event`（仅 `service_role` 可访问）。

---

## 注意事项

**1. 坐标必须「恰好 6 位小数」—— 不是「不超过 6 位」**

函数用裸 `String()` 把库里的值直接发出去：

```ts
recManLng: String(deliveryOrder.longitude)
```

快递100 要求**恰好 6 位**，多一位、少一位都报
`30001 收件人经度需精确到小数点后6位`。三个实测数据点：

| 库里的值 | 小数位 | 结果 |
| --- | --- | --- |
| `113.9145` | 4（不足） | ❌ 30001 |
| `113.91463099999999` | 14（浮点噪声） | ❌ 30001 |
| `113.979399` | 6 | ✅ 通过 |

⚠️ **末位不能是 0**：`116.483000` 存进 `numeric` 确实是 6 位，但 PostgREST 返回 JSON 时
变成数字 `116.483`，JS `String()` 得到 **3 位**，照样失败。造测试数据时要挑末位非 0 的坐标。

修法 —— 出口统一归一到 6 位（四个坐标字段都要套）：

```ts
const coord = (v: unknown) => Number(v).toFixed(6);
```

`toFixed(6)` 一次修好两种失败：`113.9145 → 113.914500`（补零）、
`113.91463099999999 → 113.914631`（消噪）。

**2. 部署地址与仓库不一致 —— 有真实扣费风险**

| 位置 | 地址 |
| --- | --- |
| 线上部署 | `http://e-test.kuaidilab.com/...`（**测试环境**）|
| 仓库 `index.ts` | `https://api.kuaidi100.com/...`（**正式环境**）|

直接 `supabase functions deploy dispatch-delivery-order` 会把线上**从测试环境切到正式环境并开始真实扣费**，且目前没有任何机制拦截这个差异。建议改为读 `KUAIDI100_URL` 环境变量。

**3. 骑手信息尚未展示**
`courier_name` / `courier_mobile` 由回调写入，Dart 模型 `MealDeliveryOrder` 目前**未映射**这两列。客户端走 `select()` 全字段 + 忽略未知字段，故不影响解析；商家端/用户端要展示骑手时再补。

**4. 回调函数尚未实现**
`delivery-order-callback` 还不存在。当前发出的单即使配了 `callbackUrl` 也收不到状态回调，`provider_status` 会一直停在 `0`。实现时注意：快递100 **不带** Supabase JWT，该函数必须 `verify_jwt = false`，改用 `MD5(param + salt)` 自校验。

---

## 调用示例

```bash
# 1) 取 JWT（手机号不带国家码）
curl -s -X POST 'https://wmioylfpdbdwnbybkpju.supabase.co/auth/v1/token?grant_type=password' \
  -H 'apikey: <publishable key>' -H 'Content-Type: application/json' \
  -d '{"phone":"13560522844","password":"<password>"}'

# 2) 发单
curl -s -X POST 'https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/dispatch-delivery-order' \
  -H "Authorization: Bearer <access_token>" \
  -H 'apikey: <publishable key>' \
  -H 'Content-Type: application/json' \
  -d '{"meal_delivery_order_id":"50467e0e-4b32-4e69-b041-3671c3e95505"}'
```

Dart 侧（客户端接入后应与此一致）：

```dart
final response = await client.functions.invoke(
  'dispatch-delivery-order',
  body: {'meal_delivery_order_id': deliveryOrderId},
);
```