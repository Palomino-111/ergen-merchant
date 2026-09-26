# 取消：`cancel-delivery-order`

当商家处发生异常需要取消配送时，由本边缘函数向**快递100 同城急送**调用取消接口（method=`cancel`），同步返回结果。

> ⚠️ **本函数可能产生费用。** 快递100 文档第 3 节原文：「注意可能产生费用」。返回的 `cancelFee` 是我方真实支出，会落库到 `cancel_fee` 列。

本文档格式与快递100 官方接口文档（[同城急送接口文档](https://api.kuaidi100.com/document/tong-cheng-ji-jian-jie-kou-wen-dang#section_2)第三点）保持一致，便于对照阅读。

**验证状态：尚未端到端实测。** 函数已按线上既有的两个快递100 函数（`dispatch-delivery-order`、`delivery-order-callback`）的实测结论编写，但取消链路本身还没有跑过一笔真实取消。

> ## ⛔ 部署顺序：必须先跑迁移，再部署函数
>
> 本函数会写 `cancel_fee` / `cancel_reason` 两列，而它们在**线上库里还不存在** ——
> 需要 `supabase/migrations/20260924100000_add_cancel_fields.sql`。
>
> **PostgREST 遇到未知列会整条 update 拒绝（PGRST204），不会部分应用。**
> 因此迁移没跑就部署，后果是：快递100 侧取消成功（可能已扣费），而
> `status='cancelled'` / `provider_status=720` **一个字都写不进去**，
> 函数每次都返回 500「取消已成功但本地落库失败」，订单永远停在 `delivering`。
> 更糟的是幂等判断依赖 `status==='cancelled'`，而这个状态永远写不出来，重试永远不会收敛。
>
> 正确顺序：
> ```bash
> # 1) 先迁移
> supabase db push --project-ref wmioylfpdbdwnbybkpju
> #    或直接执行 supabase/migrations/20260924100000_add_cancel_fields.sql
> # 2) 确认列已存在
> #    select column_name from information_schema.columns
> #    where table_name='meal_delivery_order' and column_name like 'cancel%';
> # 3) 再部署函数
> ```
> 迁移本身是纯 `add column if not exists` + 注释，可空、无默认值，对历史数据无影响、可安全重跑。

---

## 1. 接口格式

提供统一格式的 HTTP POST 调用接口，并返回统一格式 JSON 数据。

本函数是**快递100 取消接口在我方的封装**，不是原样透传：入参只收我方配送单 id，快递100 所需的 `taskId` / `orderId` 一律由服务端查库补全。

## 2. 请求地址

生产环境：`https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/cancel-delivery-order`

**请求参数（header）**

| 名称 | 类型 | 默认值 |
| :-- | :-- | :-- |
| Authorization | `String` | 必填，`Bearer <access_token>` |
| apikey | `String` | 必填，`sb_publishable_...` |
| Content-Type | `String` | application/json |

**请求参数（body）**

| 参数名 | 是否必填 | 类型 | 说明 |
| :-- | :-- | :-- | :-- |
| meal_delivery_order_id | 是 | `String` | 我方配送单 id（UUID） |
| reason | 否 | `String` | 取消原因 key，见 2.1。缺省按 `other` 处理 |

### 2.1 reason 取值

**传 key，不传快递100 的整数码。** 码表是快递100 的私有枚举，语义对客户端毫无意义；由本函数统一映射，将来补文案、改码值都不必发版。

key 按**商家端实际会遇到的场景**命名，与快递100 的中文原因是多对一映射。码值取自官方 [参数字典 · 三、取消原因类型对照表（cancelMsgType）](https://api.kuaidi100.com/document/tong-cheng-ji-jian-can-shu-zi-dian#section_2)，对方取值闭集为 **1-8**：

| key | cancelMsgType | 快递100 原始原因 |
| :-- | :-- | :-- |
| `no_longer_needed` | 1 | 不需要寄件了 |
| `wrong_order_info` | 2 | 填错订单信息 |
| `courier_requested` | 3 | 配送员要求取消 |
| `goods_unavailable` | 4 | 暂时无法提供待配送物品 |
| `duplicate` | 5 | 重复下单，取消此单 |
| `courier_no_show` | 6 | 配送员没来取货 |
| `no_courier` | 7 | 没有配送员接单 |
| `other` | 8 | 其他（默认值） |

默认值 `8`（其他）：商家端 UI 不给原因时必须仍能取消，否则等于把「选原因」变成取消的前置条件。

> ⚠️ 不要传表外的 `99` 之类取值 —— `cancelMsgType` 是必填 `Int` 且参照这张闭集表，
> 表外值只会换回 `30001`，白白多一次真实往返。

传了不在表里的值 → `400`，`allowed` 字段回传全部合法 key。**不会**静默换成默认值 —— 那会让「取消原因全是其他」这种问题永远查不出来。

## 3. 返回结果

| 字段 | 类型 | 说明 | 备注 |
| :-- | :-- | :-- | :-- |
| provider_order_id | `String` | 快递100 订单号 | |
| cancel_fee | `Number` \| `null` | 取消费用，单位：元 | 非数字或为空时返回 `null` |
| cancel_fee_known | `Boolean` | 是否拿到了上游的费用数据 | 上游 `data` 缺失时为 `false`，此时 `cancel_fee` 为 `null` 但**不代表免费** |
| status | `String` | 我方配送单状态 | 固定 `cancelled` |

**幂等返回**

已取消的单重复调用直接返回成功，**不会**再打一次快递100：

| 字段 | 类型 | 说明 |
| :-- | :-- | :-- |
| already_cancelled | `Boolean` | 固定 `true` |
| provider_order_id | `String` \| `null` | 快递100 订单号 |
| provider_status | `Int` \| `null` | 快递100 原始状态码 |
| status | `String` | 固定 `cancelled` |
| cancel_fee | `null` | 幂等路径不重新计费，恒为 `null` |

> 两条成功路径都带 `status` / `cancel_fee`，客户端可以用同一个解析器。

## 4. 提供数据内容

**请求参数示例**

```json
{
    "meal_delivery_order_id": "007ab983-550e-49d0-8f44-dbdcb0ba93a5",
    "reason": "no_courier"
}
```

**返回结果示例**

```json
{
    "provider_order_id": "108219",
    "cancel_fee": 2,
    "cancel_fee_known": true,
    "status": "cancelled"
}
```

**幂等返回示例**

```json
{
    "already_cancelled": true,
    "provider_order_id": "108219",
    "provider_status": 720,
    "status": "cancelled",
    "cancel_fee": null
}
```

**错误返回示例**

| HTTP | error | 触发条件 | 响应 |
| :-- | :-- | :-- | :-- |
| 400 | `缺少 meal_delivery_order_id` | body 缺字段 | `{"error":"缺少 meal_delivery_order_id"}` |
| 400 | `未知的取消原因 X` | `reason` 不在码表内，附 `allowed` | `{"error":"未知的取消原因 xx","allowed":["no_longer_needed",...]}` |
| 401 | `缺少 Authorization` | 无 Auth 头 | `{"error":"缺少 Authorization"}` |
| 401 | `token 无效或已过期` | JWT 格式合法但无效/过期 | — |
| 403 | `无权取消该配送单` | `merchant.user_id !== auth.uid()` | — |
| 404 | `配送单不存在或无权访问` | id 不存在，或被 RLS 挡住 | `{"error":"配送单不存在或无权访问"}` |
| 404 | `商家不存在` | `merchant_id` 指向的商家已删 | — |
| 409 | `当前状态 X 不可取消` | 状态不在 5.1 白名单内 | `{"error":"当前状态 delivered 不可取消"}` |
| 409 | `该配送单非快递100 运力，无法取消` | `delivery_provider !== 'kuaidi100'` | — |
| 409 | `该配送单缺少第三方单号，无法取消` | 没有 `provider_order_id` / `provider_task_id` | — |
| 500 | `读取配送单失败` / `读取商家失败` | 查库报错，附 `detail` | — |
| 500 | `服务器内部错误` | 兜底异常（body 非 JSON、fetch 抛错等） | — |
| 500 | `取消已成功但本地落库失败，请人工核对后补录` | **见下方「危险状态」** | — |
| 502 | `取消失败` | 快递100 拒绝，附 `code` / `detail` | `{"error":"取消失败","code":30001,"detail":"..."}` |
| 200 | — | **例外**：`30005` 且 message 含「已取消」→ 按成功返回 | 见 5.4 |

> 401 有两种来源，别混淆：**格式非法**的 JWT 会被 Supabase 网关先拦下，返回
> `{"code":"UNAUTHORIZED_INVALID_JWT_FORMAT","message":"Invalid JWT"}`，请求根本到不了函数；
> `token 无效或已过期` 只会出现在格式合法但过期/失效的情况。

## 5. 业务规则

### 5.1 可取消状态

仅 `awaiting_delivery`、`delivering` 可取消。

| 状态 | 是否可取消 | 原因 |
| :-- | :-- | :-- |
| `awaiting_preparation` / `preparing` | ❌ | 还没发单，没有 `provider_order_id`。商家此时该取消的是**顾客订单**，不是配送 |
| `awaiting_delivery` | ✅ | 已发单、骑手可能已接单 |
| `delivering` | ✅ | 在途，取消可能产生费用 |
| `delivered` / `received` | ❌ | 已送达，下游必然拒绝 |
| `cancelled` | ✅（幂等） | 返回 `already_cancelled`，不重复调用 |

### 5.2 幂等的判定顺序

**幂等判断在状态与服务商校验之前，但在归属校验之后。**

- 在**状态/服务商校验之前**：重试取消必须是无害的，让商家在「其实已经取消了」的单上拿到成功，而不是 `409`。
- 在**归属校验之后**：幂等只要求「不再打一次快递100」，**不要求跳过鉴权**。先返回 `already_cancelled` 会把别人的单号泄露给任何登录用户 —— 而配送单 id 是 UUID、`merchant` 表又可公开读，这不是一个够高的门槛。与 `get-courier-position` 一致：**先归属，后状态**。

整体顺序固定为：归属 → 幂等 → 状态 → 服务商。

### 5.3 ⚠️ 危险状态：取消已生效但本地落库失败

落库失败时返回 **500 而非成功**。此时快递100 侧**已经取消**（可能已扣费），而库里仍显示「配送中」。响应里给出 `provider_order_id` / `provider_task_id`，须人工核对后补录，**不能**当成功处理。

**这个失败态可以自愈**：库里状态没改成 `cancelled`，所以重试不会命中幂等分支，而是重新打一次快递100；
对方回 `30005`「订单已取消」→ 命中 5.4 的分支把本地状态补齐。也就是说重试一次即可收敛，不会永远卡住。

> 这也是 5.4 存在的第二个理由：它同时是「落库失败」的恢复路径。

### 5.4 下游「订单已取消」按成功处理

若快递100 返回 `30005` 且 message 含「已取消」，说明**对方侧已经是取消态**，只是我方库里没跟上（上一次取消落库失败，或该单是在快递100 后台被人取消的）。

此时**按成功处理并补齐本地状态**（`status=cancelled` / `provider_status=720`）。
若按失败返回，商家会永远卡在「取消不了」—— 重试永远撞同一句话，没有任何出路。

**判定收得很紧**：只有 `code === 30005` **且** message 明确包含「已取消」才走这个分支。
其余 `30005`（官方定义是「快递公司返回异常」的**通用**码，消息由下游透传）一律仍按失败返回 `502`。
宁可多一次人工核对，不可把失败当成功。

## 6. 处理流程

1. 取 `Authorization` 头 → 缺失返回 401
2. 建 supabase 客户端（**转发该 JWT**，RLS 才有身份）
3. 解析 body 取 `meal_delivery_order_id` / `reason` → 缺 id 400；`reason` 不在码表 400
4. `auth.getUser()` 校验 JWT → 无用户返回 401
5. 读配送单 → 不存在返回 404
6. 读商家 → 不存在 404；`user_id` 不匹配 403（**先归属**）
7. **幂等**：状态已是 `cancelled` → 直接返回 `already_cancelled`
8. 校验状态可取消 → 否则 409
9. 校验 `delivery_provider === 'kuaidi100'` 且有第三方单号 → 否则 409
10. 组装 `param`（`taskId` + `orderId` + `cancelMsgType`），调快递100 `method=cancel`
11. 失败 → 写 `dispatch_failed_reason`，返回 502（**例外**：`30005` 且 message 含「已取消」→ 按成功走下一步，见 5.4）
12. 成功 → 落库 `status=cancelled` / `provider_status=720` / `cancel_fee` / `cancel_reason`，返回 200

## 7. 快递100 调用细节

| 项 | 值 |
| :-- | :-- |
| 地址 | 线上为 `http://e-test.kuaidilab.com/api/bsamecity/order`（测试网关） |
| 编码 | `application/x-www-form-urlencoded` |
| 字段 | `method=cancel`、`key`、`t`、`sign`、`param` |
| 签名 | `sign = MD5(param + t + key + secret)`，**32 位大写** |
| 关键 | `param` 必须与签名使用**同一份**序列化结果，否则报 `30002 验证签名失败` |
| 非 JSON 响应 | 网关可能在 HTTP 200 下回 HTML（维护页、风控页）。函数会显式抛错而不是让 `JSON.parse` 抛出裸异常，避免把上游故障伪装成「服务器内部错误」 |

> 💡 测试环境**可以**验证取消：发单在测试环境是通的（`dadatongcheng` + 北京地址），
> 发出去的单就能拿来取消。

### 7.1 上游错误码（快递100 信息代码含义）

| 信息代码 | 信息内容描述 | 原因及建议处理方式 |
| :-- | :-- | :-- |
| 200 | 成功 | 成功 |
| -1 | 服务器错误 | 快递100 的服务器出现间歇或临时性异常，有时如果因为不按规范提交请求，比如快递公司参数写错等，也会报此错误 |
| 30001 | 参数错误 | 请根据技术文档请求，注意参数类型及是否必填 |
| 30002 | 验证签名失败 | 检查加密方式，param + t + key + secret 的顺序进行 MD5 加密，加密后字符串转 32 位大写，不用加上“+”号 |
| 30003 | 账号信息不正确 | 检查 key 是否正确 |
| 30004 | 账号余额不足 | 余额不足需要充值 |
| 30005 | 快递公司返回异常 | 例：订单已取消，按照描述可以自行检查参数的数据类型是否正确 |
| 30006 | 参数转换异常 | 按照描述可以自行检查参数的数据类型是否正确 |

## 8. 服务端 Secrets

复用发单函数已有的两个，**本函数不新增任何 secret**。

| 名称 | 必填 | 说明 |
| :-- | :-- | :-- |
| `KUAIDI100_KEY` | 是 | 快递100 授权 key。缺失 → 500 |
| `KUAIDI100_SECRET` | 是 | 快递100 授权 secret。缺失 → 500 |

## 9. 相关数据表

本函数写入 `meal_delivery_order` 的这些列：

| 列 | 说明 |
| :-- | :-- |
| `status` | 置为 `cancelled` |
| `provider_status` | 置为 `720`（订单取消），与回调写入的值一致 |
| `provider_status_desc` | 置为 `订单取消` |
| `cancel_fee` | 取消费用（元）。**本次新增**，见迁移 `20260924100000_add_cancel_fields.sql` |
| `cancel_reason` | 取消原因 key。**本次新增**，同上 |
| `dispatch_failed_reason` | 失败时写入原因。**成功后刻意不清空**（见下） |

> **成功路径刻意不写 `dispatch_failed_reason: null`。** 回调在状态 `720` 时会把**下游的取消原因**
> （如「长时间无人接单,自动取消」）写进这一列，那是对方的口径，与本函数的 `cancel_reason`
> （我方传上去的 key）来源不同、不可互相替代。清掉它等于把「为什么被取消」的唯一答案抹掉，
> 且没有任何收益 —— 发单失败的原因早在第 11 步就被覆盖了。

> **`cancel_fee` 与 `provider_fee` 不可互相覆盖**：前者是取消罚金，后者是配送费，会在同一行同时存在。

## 10. 调用示例

```bash
# 1) 取 JWT（手机号不带国家码）
curl -s -X POST 'https://wmioylfpdbdwnbybkpju.supabase.co/auth/v1/token?grant_type=password' \
  -H 'apikey: <publishable key>' -H 'Content-Type: application/json' \
  -d '{"phone":"16675959975","password":"<password>"}'

# 2) 取消
curl -s -X POST 'https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/cancel-delivery-order' \
  -H "Authorization: Bearer <access_token>" \
  -H 'apikey: <publishable key>' \
  -H 'Content-Type: application/json' \
  -d '{"meal_delivery_order_id":"007ab983-550e-49d0-8f44-dbdcb0ba93a5","reason":"no_courier"}'
```

Dart 侧：

```dart
final response = await client.functions.invoke(
  'cancel-delivery-order',
  body: {
    'meal_delivery_order_id': deliveryOrderId,
    'reason': 'no_courier',
  },
);
```

## 11. 设计要点（改动前先读）

**为什么只收配送单 id**
客户端传 `taskId` / `orderId`，等于允许任何人取消别人的配送单 —— 而取消是**真实扣费**动作。

**为什么显式比对 `merchant.user_id`**
`merchant` 表的 SELECT 策略是公开可读（`USING true`），RLS **不构成**归属校验。不显式比对，任何登录用户都能取消别人的单。

**为什么 `reason` 传 key 而不是数字码**
见 2.1。数字码是快递100 的私有枚举，散落在 App 里既难维护，也无法在换服务商时保持客户端不变。

**为什么本地直接把状态置为 `cancelled`，不等 720 回调**
`DELIVERY_CALLBACK_URL` 是可空配置（见 `dispatch-delivery-order` 文档）。回调没配时，等回调就意味着商家点完取消、界面一直显示「配送中」，只能人工查库。720 回调随后到达会写入同样的状态，是幂等的。

**函数职责边界**
只做**取消**。发单在 `dispatch-delivery-order`，加小费将来另建函数 —— **不要**往任何一个函数里堆 `method` 分支。

**为什么 `code` 用 `Number()` 比较**
官方文档把 `cancelFee`、`lbsType` 都标成 `String`，说明这个网关会输出**字符串化的数字字段**，`code` 同样可能是 `"200"`。严格 `!== 200` 会把一次成功判成失败 —— 而取消是补救动作，误判的代价是商家取消不掉单。

## 12. 注意事项

**1. ⛔ 部署顺序：先迁移，后部署**
见文首告警。这是本函数唯一会「每次都失败」的部署陷阱。

**2. 未端到端实测**
原因码表已对照官方参数字典核实（见 2.1），但取消链路本身还没跑过一笔真实取消。首次联调要重点确认两件事：
- 取消后的 `cancelFee` 实际取值口径（是否按骑手是否已接单分档）
- 未接单即取消是否也收费

**3. 下游「订单已取消」（30005）按成功处理**
若快递100 回 `30005` 且 message 含「已取消」，说明对方侧已是取消态，只是我方库里没跟上。
此时**按成功处理并补齐本地状态**，否则商家会永远卡在「取消不了」—— 重试永远撞同一句话。
其余 `30005` 仍按失败返回（`502`）：宁可多一次人工核对，不可把失败当成功。

**4. 部署环境与仓库不一致 —— 有真实扣费风险**

| 位置 | 地址 |
| :-- | :-- |
| 线上部署 | `http://e-test.kuaidilab.com/api/bsamecity/order`（**测试环境**）|
| 仓库 `index.ts` | 同上（本函数与发单函数保持一致）|

与 `dispatch-delivery-order` 文档第 2 条同样的隐患：直接部署会把线上切到正式环境并开始真实扣费，且目前没有任何机制拦截这个差异。建议改为读 `KUAIDI100_URL` 环境变量。

**5. `cancel_reason` 存的是 key，不是快递100 的码**
换服务商后这列仍可读；而 `provider_status` 存的是对方枚举原值（720），换家后语义不通用。

**6. 客户端尚未接入**
`lib/common/models/meal_delivery_order.dart` 未映射 `cancel_fee` / `cancel_reason`。
客户端走 `select()` 全字段 + 忽略未知字段，故新增列不会破坏解析；商家端要展示"取消费"时再补。