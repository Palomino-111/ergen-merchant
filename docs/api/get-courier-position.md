# 骑手位置：`get-courier-position`

订单创建且骑手接单后，由本边缘函数向**快递100 同城急送**查询骑手位置信息（method=`queryCourier`）。

> ⚠️ **本接口在快递100 侧计费。** 文档 6.6 把 `30004` 的描述写成「您不是合法的用户（即授权 Key 出错）」，
> 但同一行的「原因及建议处理方式」写的是「账号无可用余额，需要充值」—— 即余额不足会在这个接口上扣响应。
> 因此函数**不做任何轮询/重试**：一次请求只打一次快递100，刷新频率由客户端控制。

本文档格式与快递100 官方接口文档（[同城急送接口文档](https://api.kuaidi100.com/document/tong-cheng-ji-jian-jie-kou-wen-dang#section_5)第六点）保持一致，便于对照阅读。

**验证状态：鉴权/归属/状态/错误透传已实测；成功分支未验证。**

2026-09-26 在测试网关（`e-test.kuaidilab.com`）实测，订单 `108304`：

| 回调状态 | 我方放行 | 上游返回 |
| :-- | :-- | :-- |
| 0 下单成功 | ✅ | `30005 无法查询配送员位置!` → 502 |
| 100 已接单 | ✅ | `30005 无法查询配送员位置!` → 502 |
| 230 已到店 | ✅ | `30005 无法查询配送员位置!` → 502 |
| 310 配送中 | ✅ | `30005 无法查询配送员位置!` → 502 |

**测试平台不模拟骑手 GPS**，所以 `has_position: true` 这条路径至今没跑过，`lbsType` 的真实取值也仍未确认。

---

## 1. 接口格式

提供统一格式的 HTTP POST 调用接口，并返回统一格式 JSON 数据。

本函数是**快递100 骑手位置接口在我方的封装**：入参只收我方配送单 id，快递100 所需的 `orderId` 由服务端查库补全。

**为什么不做成客户端直连的读接口**：位置查询有副作用（计费），且骑手位置属于 PII。放在边缘函数里才能同时做「归属校验」与「调用频次控制」。

## 2. 请求地址

生产环境：`https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/get-courier-position`

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

> 请求参数只此一个。**不接受客户端传 `orderId`** —— 那等于允许任何登录用户查任意订单的骑手位置。

## 3. 返回结果

| 字段 | 类型 | 说明 | 备注 |
| :-- | :-- | :-- | :-- |
| has_position | `Boolean` | 是否拿到坐标 | false 见 3.2 |
| courier_lat | `String` | 骑手位置纬度 | 仅 `has_position=true` 时返回 |
| courier_lng | `String` | 骑手位置经度 | 仅 `has_position=true` 时返回 |
| lbs_type | `Int` | 坐标类型，2：高德坐标 | 上游缺省或非数字时按 2 兜底 |
| provider_order_id | `String` | 快递100 订单号 | 仅 `has_position=true` 时返回 |

### 3.1 坐标统一为字符串

`courier_lat` / `courier_lng` **固定以字符串返回**，即使上游给的是数字。客户端不必纠结两种形态，直接丢给地图 SDK 解析即可。

**能这么承诺是因为函数做了数值校验**：只有能通过 `Number.isFinite(Number(v))` 的值才会返回。
空白串（`'  '`）、`'NaN'`、`'abc'` 一律判为「没有位置」，不会漏给客户端 ——
否则文档第 10 节的 `double.parse` 示例会直接抛错。

`lbs_type` 同理**归一成数字**：上游可能回 `2` 也可能回 `'2'`，函数两种都收，
避免客户端写 `lbs_type == 2` 时在上游回字符串的情况下静默失效。

### 3.2 `has_position = false`

> ⚠️ **实测后这条分支的触发条件要改写。** 测试网关在「骑手未上报定位」时回的是
> `code=30005 无法查询配送员位置!`，走 3.3 的 502，**根本到不了这里**（见开头实测表）。
> 代码里的分支保留，只是防「上游回 200 但坐标缺失」这一种未观测到的情况。

骑手已接单但尚未上报定位时，若上游仍回 `code=200`，`data` 可能整体缺失，或 `courierLat` / `courierLng` 为空串、空白串、非数字。此时返回：

```json
{
    "has_position": false,
    "message": "骑手尚未上报位置"
}
```

**显式返回 `has_position` 而不是回一个空 `data`** —— 否则客户端拿到 `undefined` 并在渲染地图时崩掉。

### 3.3 不返回骑手姓名/电话

骑手姓名（`courier_name`）、电话（`courier_mobile`）由**状态回调**写入 `meal_delivery_order`，客户端从已经拿到的配送单数据里读即可，本函数不回传，也不额外查库。

## 4. 提供数据内容

**请求参数示例**

```json
{
    "meal_delivery_order_id": "007ab983-550e-49d0-8f44-dbdcb0ba93a5"
}
```

**返回结果示例**

```json
{
    "has_position": true,
    "courier_lat": "31.26731662",
    "courier_lng": "120.63341715",
    "lbs_type": 2,
    "provider_order_id": "108219"
}
```

**骑手未上报位置示例**

```json
{
    "has_position": false,
    "message": "骑手尚未上报位置"
}
```

**错误返回示例**

| HTTP | error | 触发条件 | 响应 |
| :-- | :-- | :-- | :-- |
| 400 | `缺少 meal_delivery_order_id` | body 缺字段 | `{"error":"缺少 meal_delivery_order_id"}` |
| 401 | `缺少 Authorization` | 无 Auth 头 | `{"error":"缺少 Authorization"}` |
| 401 | `token 无效或已过期` | JWT 格式合法但无效/过期 | — |
| 403 | `无权查询该配送单` | `merchant.user_id !== auth.uid()` | — |
| 404 | `配送单不存在或无权访问` | id 不存在，或被 RLS 挡住 | `{"error":"配送单不存在或无权访问"}` |
| 404 | `商家不存在` | `merchant_id` 指向的商家已删 | — |
| 409 | `当前状态 X 无法查询骑手位置` | 状态不在 5.1 白名单内 | `{"error":"当前状态 delivered 无法查询骑手位置"}` |
| 409 | `该配送单非快递100 运力，无法查询骑手位置` | `delivery_provider !== 'kuaidi100'` | — |
| 409 | `该配送单缺少第三方单号，无法查询骑手位置` | 没有 `provider_order_id` | — |
| 500 | `读取配送单失败` / `读取商家失败` | 查库报错，附 `detail` | — |
| 500 | `服务器内部错误` | 兜底异常（body 非 JSON、fetch 抛错等） | — |
| 502 | `查询骑手位置失败` | 快递100 拒绝，附 `code` / `detail` | `{"error":"查询骑手位置失败","code":30004,"detail":"..."}` |

> 401 有两种来源，别混淆：**格式非法**的 JWT 会被 Supabase 网关先拦下，返回
> `{"code":"UNAUTHORIZED_INVALID_JWT_FORMAT","message":"Invalid JWT"}`，请求根本到不了函数；
> `token 无效或已过期` 只会出现在格式合法但过期/失效的情况。

## 5. 业务规则

### 5.1 可查询状态

仅 `awaiting_delivery`、`delivering` 可查询。

| 状态 | 是否可查 | 原因 |
| :-- | :-- | :-- |
| `awaiting_preparation` / `preparing` | ❌ | 还没发单，没有 `provider_order_id` |
| `awaiting_delivery` | ✅ | 已发单，骑手可能已接单 |
| `delivering` | ✅ | 在途，正是要看位置的时候 |
| `delivered` / `received` | ❌ | 行程已结束，查到的坐标没有意义，白花一次计费调用 |
| `cancelled` | ❌ | 已取消的单没有在途骑手 |

### 5.2 校验顺序

归属校验 → 状态校验 → 服务商校验。**先归属后状态**：反过来会泄露「这单存不存在」的旁路信息。

### 5.3 不做轮询

函数内**没有**任何重试或定时逻辑。快递100 拒绝时直接返回 502，不做退避重试 —— 每次重试都是一次计费。
若客户端要做「自动刷新轨迹」，频率与停止条件必须由客户端负责，且**不要**在 `has_position=false` 时高频重试。

## 6. 处理流程

1. 取 `Authorization` 头 → 缺失返回 401
2. 建 supabase 客户端（**转发该 JWT**，RLS 才有身份）
3. 解析 body 取 `meal_delivery_order_id` → 缺失返回 400
4. `auth.getUser()` 校验 JWT → 无用户返回 401
5. 读配送单 → 不存在返回 404
6. 读商家 → 不存在 404；`user_id` 不匹配 403
7. 校验状态可查询 → 否则 409
8. 校验 `delivery_provider === 'kuaidi100'` 且有 `provider_order_id` → 否则 409
9. 调快递100 `method=queryCourier`，`param = {"orderId": "..."}`
10. 失败 → 返回 502，附上游 `code` / `detail`
11. 成功但坐标为空白 → 返回 `has_position: false`
12. 成功 → 返回坐标 + `lbs_type`

## 7. 快递100 调用细节

| 项 | 值 |
| :-- | :-- |
| 地址 | 代码里**写死**的是测试网关 `http://e-test.kuaidilab.com/api/bsamecity/order`。正式环境是 `https://api.kuaidi100.com/bsamecity/order`（注意正式地址**没有** `/api` 段） |
| 编码 | `application/x-www-form-urlencoded` |
| 字段 | `method=queryCourier`、`key`、`t`、`sign`、`param` |
| 签名 | `sign = MD5(param + t + key + secret)`，**32 位大写** |
| `param` | `{"orderId": "<快递100 订单号>"}`，仅此一个字段 |
| 关键 | `param` 必须与签名使用**同一份**序列化结果，否则报 `30002 验证签名失败` |
| 非 JSON 响应 | 网关可能在 HTTP 200 下回 HTML（维护页、风控页）。此时 `JSON.parse` 抛错，被外层 catch 兜成 500，和「上游 5xx」同一出口 |

### 7.1 上游错误码（快递100 信息代码含义）

| 信息代码 | 信息内容描述 | 原因及建议处理方式 |
| :-- | :-- | :-- |
| 200 | 提交成功 | 提交成功 |
| 500、-1 | 提交失败 | 快递品牌不支持时返回不支持修改订单，任务号查询失败问题也会报非法操作，网络抖动等 |
| 30002 | 验证签名失败 | 请检查加密方式，param + t + key + secret 的顺序进行 MD5 加密，加密后字符串转大写，不用加上“+”号 |
| 30004 | 您不是合法的用户（即授权 Key 出错） | 账号无可用余额，需要充值 |
| 30004 | KEY 已过期 | 账号无可用余额，需要充值 |
| 30003 | 获取用户信息失败 | 请检查 key 是否正确 |
| **30005** | **（本节错误码表未列出）快递公司返回异常** | **实测「骑手未上报定位」走的就是它，message=`无法查询配送员位置!`** |

**错误码本身就是「我方传参对不对」的判据**（这张表来自文档第一、二节的通用码表，本节只摘了一部分）：

| 码 | 含义 | 说明我方调用 |
| :-- | :-- | :-- |
| 30001 | 参数错误 | 参数缺失/类型错 —— 我方传错会落到这里 |
| 30002 | 验证签名失败 | `param`/`t`/`key`/`secret` 拼接或大小写错 |
| 30003 | 账号信息不正确 | key 错 |
| 30004 | 账号余额不足 | key 对、但没钱 |
| 30006 | 参数转换异常 | 类型不对 |
| **30005** | **快递公司返回异常** | **请求已被网关接收、验签通过、并转发给了下游运力 —— 出问题的是下游** |

实测拿到的是 **30005 而不是 30001/30002/30003/30006**，这正是「我方接口没写错」的判据：
传参错会死在网关的参数/验签校验上，根本到不了下游。

> 注意 `30004` 在官方文档里一行一个含义（「Key 出错」与「Key 已过期」共用同一码），
> 靠 `message` 区分。两者本函数都原样透传到 502 的 `detail` 里。

## 8. 服务端 Secrets

复用发单函数已有的两个，**本函数不新增任何 secret**。

| 名称 | 必填 | 说明 |
| :-- | :-- | :-- |
| `KUAIDI100_KEY` | 是 | 快递100 授权 key。缺失 → 500 |
| `KUAIDI100_SECRET` | 是 | 快递100 授权 secret。缺失 → 500 |

## 9. 相关数据表

本函数**只读**，不写任何列。

| 列 | 用途 |
| :-- | :-- |
| `meal_delivery_order.merchant_id` | 取商家，做归属校验 |
| `meal_delivery_order.status` | 判断是否可查询 |
| `meal_delivery_order.delivery_provider` | 确认是快递100 的单 |
| `meal_delivery_order.provider_order_id` | 作为 `orderId` 传给快递100 |
| `meal_delivery_order.courier_name` / `courier_mobile` | **本函数不读**，由客户端从已有配送单数据里取（回调写入） |

## 10. 调用示例

```bash
# 1) 取 JWT（手机号不带国家码）
curl -s -X POST 'https://wmioylfpdbdwnbybkpju.supabase.co/auth/v1/token?grant_type=password' \
  -H 'apikey: <publishable key>' -H 'Content-Type: application/json' \
  -d '{"phone":"16675959975","password":"<password>"}'

# 2) 查骑手位置
curl -s -X POST 'https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/get-courier-position' \
  -H "Authorization: Bearer <access_token>" \
  -H 'apikey: <publishable key>' \
  -H 'Content-Type: application/json' \
  -d '{"meal_delivery_order_id":"007ab983-550e-49d0-8f44-dbdcb0ba93a5"}'
```

Dart 侧：

```dart
final response = await client.functions.invoke(
  'get-courier-position',
  body: {'meal_delivery_order_id': deliveryOrderId},
);
final data = response.data as Map<String, dynamic>;
if (data['has_position'] == true) {
  final lat = double.parse(data['courier_lat'] as String);
  final lng = double.parse(data['courier_lng'] as String);
  // lbs_type == 2 表示高德坐标，选地图 SDK 时要用对应的坐标系
}
```

## 11. 设计要点（改动前先读）

**为什么只收配送单 id**
见第 2 节。骑手位置是 PII，且查询计费；只认我方单 id，才能把「你是谁、这单是不是你的」两件事一次判掉。

**为什么显式比对 `merchant.user_id`**
`merchant` 表的 SELECT 策略是公开可读（`USING true`），RLS **不构成**归属校验。不显式比对，任何登录用户都能查任意订单的骑手位置。

**为什么把空坐标做成 `has_position` 而不是 `200 {}`**
回空对象会让客户端拿到 `undefined` 再去做数值运算，是典型的崩溃点。用显式布尔量把「没有位置」变成调用方必须处理的一等状态。

**为什么坐标要按数值校验，而不是只判空串**
`'  '` / `'NaN'` / `'abc'` 都能通过空串判断，却会让客户端的 `double.parse` 抛错。文档承诺「可直接解析」，就必须由函数保证这个前提。

**为什么 `code` 用 `Number()` 比较**
官方文档把 `lbsType` 标成 `String`，说明这个网关会输出**字符串化的数字字段**，`code` 同样可能是 `"200"`。严格 `!== 200` 会把一次成功判成失败。

**为什么不返回骑手姓名/电话**
回调已经把 `courier_name` / `courier_mobile` 写进配送单，客户端本来就有。本函数再查一次库属于多余往返，且会让「骑手信息以回调为准」这条数据来源变得含糊。

**为什么不做轮询**
见 5.3。计费接口的调用节奏是产品决策，不该藏在边缘函数里。

**函数职责边界**
只做**位置查询**。发单在 `dispatch-delivery-order`，取消在 `cancel-delivery-order`，加小费将来另建函数。

## 12. 注意事项

**1. 成功分支仍未验证**
2026-09-26 实测已确认三件事中的两件：
- 测试环境**支持** `queryCourier`（请求能打到上游并拿到业务码，不是 404/不支持）
- 未上报定位时上游走的是 `code != 200`（30005），**不是** `code = 200` + 空 `data`

仍未确认：
- 测试平台不模拟骑手 GPS，`has_position: true` 与 `lbsType` 的真实取值都还没跑过。
  要验证成功分支只能等真实骑手在正式环境上报定位，或用能回坐标的 mock 网关。

**2. 部署环境与仓库不一致 —— 有真实扣费风险**
与 `dispatch-delivery-order` 文档第 2 条同样的隐患。建议改为读 `KUAIDI100_URL` 环境变量。

**3. 客户端尚未接入**
本项目 Flutter 端目前**没有**调用 `cancel-delivery-order` / `get-courier-position` 这两个新函数的代码
（发单函数同样尚未接入，见 `dispatch-delivery-order.md` 第 4 条）。
商家端要做「看骑手位置」时，需要新写数据源 + 控制器，并确认 `supabase_flutter` 的 `functions.invoke` 已可用。

**4. 地图坐标系**
`lbs_type = 2` 是高德坐标。若客户端用其他地图 SDK（如百度），需要在渲染前做坐标转换，**不要**直接把高德坐标丢进去。