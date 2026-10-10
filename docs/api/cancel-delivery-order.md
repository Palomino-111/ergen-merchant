# 取消配送：`cancel-delivery-order`

取消一笔已发单的同城配送。**商家端与用户端共用**：商家取消配送，用户取消自己这一单。内部转发**快递100 同城急送取消接口**（`method=cancel`），同步返回结果并落库。

---

## 1. 接口信息

| 项 | 值 | 说明 |
| :--- | :--- | :--- |
| **请求 URL** | `https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/cancel-delivery-order` | 线上 Edge Function 地址 |
| **请求方法** | `POST` | |
| **认证方式** | `Bearer <access_token>` | 需携带用户登录 JWT |
| **调用角色** | 商家老板（`merchant.user_id`）**或** 下单用户（`recipe_order.user_id`） | 双方均有权取消属于自己的订单 |
| **是否幂等** | **是** | 重复对已取消的单发起请求，直接返回成功，不重复扣费/不重复打上游 |

---

## 2. 认证与 Headers

前端必须在 HTTP 请求头中携带以下信息：

```http
Authorization: Bearer <当前登录用户的 session access_token>
apikey: <Supabase anon / publishable key>
Content-Type: application/json
```

> **权限校验说明**：  
> 服务端会从 JWT 解析当前调用者 UID，并核对该配送单对应的商家 Owner 或关联订单的用户 UID。若均不匹配，统一返回 `404 配送单不存在或无权访问`（避免越权或泄露单号是否存在）。

---

## 3. 请求参数 (Request Body)

```json
{
  "meal_delivery_order_id": "007ab983-550e-49d0-8f44-dbdcb0ba93a5",
  "reason": "no_courier",
  "cancel_msg": "配送超时，联系不上顾客协商取消"
}
```

### 字段定义

| 字段名 | 类型 | 必填 | 默认值 | 示例值 | 说明 |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `meal_delivery_order_id` | String (UUID) | **是** | - | `"007ab983..."` | 我方餐品配送单 ID（`meal_delivery_order.id`） |
| `reason` | String | **是** | - | `"no_courier"` | 取消原因 key，**枚举值必填**，取值见下表 |
| `cancel_msg` | String | 否 | `null` | `"联系不上顾客"` | 自由文本备注，选填。首尾空格会自动去除，空文本则不下发上游 |

### `reason` 枚举字典表

上游快递100 要求传递强枚举代码（1-8），前端**必须传语义化 key**，请在 UI 取消弹窗中提供选择器供用户或商家点选：

| `reason` (前端传值) | 对应文案 | 适用场景 |
| :--- | :--- | :--- |
| `no_longer_needed` | 不需要寄件了 | 顾客临时改变计划 / 商家自送 |
| `wrong_order_info` | 填错订单信息 | 地址、电话、姓名等填错 |
| `courier_requested` | 配送员要求取消 | 骑手爆胎/车辆故障/无法履约要求发起取消 |
| `goods_unavailable` | 暂时无法提供待配送物品 | 商家餐品售罄/材料不足 |
| `duplicate` | 重复下单，取消此单 | 误操作重复下发配送 |
| `courier_no_show` | 配送员没来取货 | 骑手长时间未来店取货 |
| `no_courier` | 没有配送员接单 | 高峰期超时无骑手接单 |
| `other` | 其他 | 其它特殊原因（明确选了其他，非兜底默认） |

> ⚠️ `reason` 缺失、空串或不在上述列表中时，服务端会返回 `400` 并给出 `allowed` 列表。

---

## 4. 响应数据 (Response)

### 4.1 取消成功（HTTP 200）

首次成功取消，服务端已更新数据库并将订单置为 `cancelled`。

```json
{
  "provider_order_id": "108219",
  "cancel_fee": 2.0,
  "cancel_fee_known": true,
  "status": "cancelled"
}
```

### 4.2 幂等返回（HTTP 200）

当订单**此前已被取消**，再次调用时直接返回成功，不再调用快递100，避免重复收费：

```json
{
  "already_cancelled": true,
  "provider_order_id": "108219",
  "provider_status": 720,
  "status": "cancelled",
  "cancel_fee": null
}
```

### 响应字段说明

| 字段名 | 类型 | 说明 | 前端处理建议 |
| :--- | :--- | :--- | :--- |
| `status` | String | 固定为 `"cancelled"` | 成功时统一可凭此字段刷新本地订单状态 |
| `cancel_fee` | Number \| null | 取消费用（单位：元） | 如为 `2.0` 代表产生了 2 元取消费。若为 `null` 代表费用未知或为幂等返回 |
| `cancel_fee_known` | Boolean | 取消费用是否明确已知 | **为 `false` 且 `cancel_fee` 为 `null` 时不代表免费**，仅表示上游未回传明确数字 |
| `provider_order_id` | String \| null | 快递100 第三方订单号 | 便于前端展示或问题对账 |
| `already_cancelled` | Boolean | 是否为已取消订单的幂等返回 | 仅在重复取消时返回 `true`，可弱提示“订单此前已取消” |
| `provider_status` | Number \| null | 上游状态码 | 幂等时通常为 `720`（已取消） |

---

## 5. 错误码与异常处理

所有错误响应均返回 JSON 格式：`{ "error": "...", "detail": "..." }`。

| HTTP 状态码 | 错误提示 (`error`) | 触发原因 | 前端处理推荐 |
| :--- | :--- | :--- | :--- |
| **400** | `缺少 meal_delivery_order_id` | 未传配送单 ID | 检查入参绑定 |
| **400** | `缺少取消原因 reason` / `未知的取消原因 X` | 未选原因或传值非法 | 弹窗阻断，引导用户在列表单选 |
| **400** | `cancel_msg 必须是字符串` | 备注字段类型错误 | 确保传字符串或不传 |
| **401** | `缺少 Authorization` / `token 无效或已过期` | 未登录或 Token 过期失效 | 引导重新登录并刷新 session |
| **404** | `配送单不存在或无权访问` | 配送单不存在，或者调用者既非该商家也不是该单顾客 | 提示“订单不存在或无权操作” |
| **409** | `当前状态 X 不可取消` | 订单尚未发单（`awaiting_preparation`、`preparing`）或已送达终态（`delivered`、`received`） | 刷新列表获取最新状态；若未发单应走退款/改单链路，不能调取消配送 |
| **409** | `该配送单非快递100 运力，无法取消` | 非第三方同城急送单 | 提示该运力不支持线上取消 |
| **409** | `该配送单缺少第三方单号，无法取消` | 配送单尚未成功生成第三方单号 | 提示无法取消，引导联系客服 |
| **500** | `取消已成功但本地落库失败，请人工核对后补录` | 快递100 侧已取消成功，但本地写入超时或数据库异常 | 提示“取消已在上游生效，系统正在同步”，允许用户重试（重试可自愈） |
| **502** | `取消失败` | 快递100 上游拒绝（如骑手即将送达不允许取消） | 弹窗展示上游详细原因（取 `detail`） |

---

## 6. 前端最佳实践与时序

### 6.1 前端业务流程推荐

```
[用户/商家点击“取消配送”]
       │
       ▼
[前端校验本地订单状态] ── 不在 awaiting_delivery / delivering ──> 提示不可取消或引导其他操作
       │ 是
       ▼
[弹出取消原因确认对话框]
  - 勾选 reason（必选：如“没有配送员接单”、“商家售罄”等）
  - 输入 cancel_msg（选填）
  - 明确风险提示：“骑手若已接单，取消可能产生违约取消费”
       │ 确认
       ▼
[调用 cancel-delivery-order 接口]
       │
  ┌────┴──────────────────────────┐
  ▼                               ▼
[HTTP 200 成功]              [HTTP 异常]
  - 刷新本地配送单状态为 cancelled    - 409：提示状态已变更并重新拉取
  - 若 cancel_fee > 0：           - 502：展示 detail（如“骑手已到店无法取消”）
    提示“已取消，产生取消费 X 元”     - 500：提示稍后重试
  - 关闭弹窗，通知列表刷新
```

### 6.2 前端接入代码示例

#### Dart (Flutter) 推荐实现

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, dynamic>> cancelDeliveryOrder({
  required String deliveryOrderId,
  required String reason,
  String? cancelMsg,
}) async {
  final supabase = Supabase.instance.client;
  
  try {
    final response = await supabase.functions.invoke(
      'cancel-delivery-order',
      body: {
        'meal_delivery_order_id': deliveryOrderId,
        'reason': reason,
        if (cancelMsg != null && cancelMsg.trim().isNotEmpty)
          'cancel_msg': cancelMsg.trim(),
      },
    );

    if (response.status == 200) {
      final data = response.data as Map<String, dynamic>;
      // 成功取消或幂等已取消
      final isAlready = data['already_cancelled'] == true;
      final cancelFee = data['cancel_fee'];
      final feeKnown = data['cancel_fee_known'] == true;

      if (cancelFee != null && cancelFee > 0) {
        // 产生了取消费
        print('订单取消成功，产生违约金: ¥$cancelFee');
      } else if (isAlready) {
        print('该单此前已取消');
      } else {
        print('订单取消成功');
      }
      return data;
    } else {
      final errorData = response.data as Map<String, dynamic>?;
      final errorMsg = errorData?['error'] ?? '取消失败';
      final detailMsg = errorData?['detail'] ?? '';
      throw Exception('$errorMsg ${detailMsg.isNotEmpty ? "($detailMsg)" : ""}');
    }
  } on FunctionException catch (e) {
    // 捕获 Edge Function 抛出的异常
    final details = e.details as Map<String, dynamic>?;
    final message = details?['error'] ?? e.reasonPhrase ?? '取消请求失败';
    final detail = details?['detail'];
    throw Exception('$message ${detail != null ? "($detail)" : ""}');
  } catch (e) {
    rethrow;
  }
}
```

#### TypeScript / JavaScript 推荐实现

```ts
import { supabase } from '@/lib/supabaseClient';

export interface CancelDeliveryParams {
  mealDeliveryOrderId: string;
  reason: 
    | 'no_longer_needed'
    | 'wrong_order_info'
    | 'courier_requested'
    | 'goods_unavailable'
    | 'duplicate'
    | 'courier_no_show'
    | 'no_courier'
    | 'other';
  cancelMsg?: string;
}

export interface CancelDeliveryResult {
  provider_order_id: string | null;
  cancel_fee: number | null;
  cancel_fee_known?: boolean;
  status: 'cancelled';
  already_cancelled?: boolean;
}

export async function cancelDeliveryOrder(
  params: CancelDeliveryParams
): Promise<CancelDeliveryResult> {
  const { data, error } = await supabase.functions.invoke<CancelDeliveryResult>(
    'cancel-delivery-order',
    {
      body: {
        meal_delivery_order_id: params.mealDeliveryOrderId,
        reason: params.reason,
        cancel_msg: params.cancelMsg?.trim() || undefined,
      },
    }
  );

  if (error) {
    throw new Error(error.message || '取消配送请求失败');
  }

  return data!;
}
```
