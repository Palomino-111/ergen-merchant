# 配送价格预估：`get-delivery-price`

在向运力平台正式发单（呼叫骑手）**前**，获取该配送单的**预估配送费**与**预估配送距离**。内部转发**快递100 同城急送价格查询接口**（`method=price`）。

> 💡 **业务特性说明**  
> 1. **纯预估、无副作用**：本接口**并非真正发单**，不会落库，也不会扣除账户的配送费用，仅用于发单前预估算费与配送可行性校验。  
> 2. **预估 ≠ 最终成本**：获取的运费为“此刻”的预估报价。骑手呼叫成功后的实际扣费成本以发单接口（`dispatch-delivery-order`）返回并写入数据库的 `provider_fee` 为准。

---

## 1. 接口信息

| 项 | 值 | 说明 |
| :--- | :--- | :--- |
| **请求 URL** | `https://wmioylfpdbdwnbybkpju.supabase.co/functions/v1/get-delivery-price` | 线上 Edge Function 地址 |
| **请求方法** | `POST` | |
| **认证方式** | `Bearer <access_token>` | 需携带商家登录 JWT |
| **调用角色** | 仅限商家老板（`merchant.user_id`） | 必须是配送单所属商家的 Owner |
| **副作用** | **无** | 只读接口，不写库，不触发发单 |

---

## 2. 认证与 Headers

前端必须在 HTTP 请求头中携带以下信息：

```http
Authorization: Bearer <当前登录商家的 session access_token>
apikey: <Supabase anon / publishable key>
Content-Type: application/json
```

> **权限校验说明**：  
> 服务端会从 JWT 解析当前调用者 UID，并校验 `merchant.user_id === auth.uid()`。若不匹配，返回 `403 无权查询该配送单`；若订单不存在，返回 `404 配送单不存在或无权访问`。

---

## 3. 请求参数 (Request Body)

```json
{
  "meal_delivery_order_id": "007ab983-550e-49d0-8f44-dbdcb0ba93a5"
}
```

### 字段定义

| 字段名 | 类型 | 必填 | 示例值 | 说明 |
| :--- | :--- | :---: | :--- | :--- |
| `meal_delivery_order_id` | String (UUID) | **是** | `"007ab983..."` | 我方餐品配送单 ID（`meal_delivery_order.id`） |

> **为什么只需传一个 ID？**  
> 服务端会自动根据该配送单联表查询商家发件地址/坐标、收件人地址/坐标、餐品快照与金额，自动完成高精度经纬度组装与加密签名。前端无需也不能自行构造地址和金额，防范伪造与越权嗅探。

---

## 4. 响应数据 (Response)

### 4.1 查询成功（HTTP 200）

```json
{
  "provider_fee": 9.38,
  "fee_known": true,
  "delivery_distance": 4702,
  "kuaidicom": "dadatongcheng"
}
```

### 响应字段说明

| 字段名 | 类型 | 说明 | 前端处理建议 |
| :--- | :--- | :--- | :--- |
| `provider_fee` | Number \| null | **预估**配送成本费用（单位：元） | 如为 `9.38`，表示预估需支付 9.38 元配送费。非数字或未返回时为 `null` |
| `fee_known` | Boolean | 是否成功解析出明确有效的价格 | **`false` 时绝对不代表免费**（仅表示上游未回传明确金额），UI 应展示为“待呼叫时结算”或“--” |
| `delivery_distance` | Number \| null | 预估配送骑行距离（单位：**米**） | 可转为公里展示（如 `(distance / 1000).toStringAsFixed(1) + 'km'`） |
| `kuaidicom` | String | 本次询价报价的运力平台代码 | 当前固定为 `"dadatongcheng"`（达达同城急送） |

---

## 5. 错误码与异常处理

所有错误响应均返回统一 JSON 格式：`{ "error": "...", "detail": "..." }`。

| HTTP 状态码 | 错误提示 (`error`) | 触发原因 | 前端处理推荐 |
| :--- | :--- | :--- | :--- |
| **400** | `缺少 meal_delivery_order_id` | 未传配送单 ID | 检查入参绑定 |
| **401** | `缺少 Authorization` / `token 无效或已过期` | 未登录或 Token 过期 | 提示登录失效，引导重新登录 |
| **403** | `无权查询该配送单` | 当前登录商家与配送单归属商家不一致 | 提示权限不足 |
| **404** | `配送单不存在或无权访问` / `商家不存在` | 配送单 ID 不存在 | 刷新列表确认订单是否存在 |
| **409** | `当前状态 X 无法查询价格` | 订单不在可询价状态（仅允许 `awaiting_preparation`、`preparing`） | 该订单已发单（如 `delivering`）或已结束，已发单的直接取库中的 `provider_fee` 即可，禁止重复询价 |
| **409** | `配送单的物品金额（total_paid）缺失或不大于 0，无法询价` | 该单餐品金额为空或 0 元 | 上游要求申报价值必须大于 0；引导商家核实订单实付金额 |
| **500** | `读取配送单失败` / `读取商家失败` / `服务器内部错误` | 数据库异常或服务异常 | 友好提示“预估运费服务暂不可用”，不阻断核心发单流程 |
| **502** | `查询价格失败` | 快递100 上游拒绝（如“该地址超出配送范围”、“运力暂不可用”等） | 弹窗或文本提示 `detail` 内容，告知商家原因 |

---

## 6. 前端最佳实践与时序

### 6.1 前端调用时机控制（避免高频浪费）

- ❌ **禁止在列表项中循环调用**：不要在订单列表滚动渲染每个 Card 时直接调用询价，上游接口有网络开销和频次限制。
- ✅ **推荐触发时机**：
  1. 商家在订单详情页准备点击“呼叫骑手”时触发查询。
  2. 商家点击“呼叫骑手”弹出的确认浮层中，进行一次性异步加载并展示：“预估运费：¥9.38（约 4.7 公里）”。
  3. 询价失败时（如 502/500），依然可允许商家点击正式呼叫，或给出明确文案。

### 6.2 前端接入代码示例

#### Dart (Flutter) 推荐实现

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryPriceEstimate {
  final double? providerFee;
  final bool feeKnown;
  final int? deliveryDistanceMeter;
  final String kuaidicom;

  DeliveryPriceEstimate({
    this.providerFee,
    required this.feeKnown,
    this.deliveryDistanceMeter,
    required this.kuaidicom,
  });

  /// 距离格式化（公里）
  String get distanceFormatted {
    if (deliveryDistanceMeter == null) return '--';
    return '${(deliveryDistanceMeter! / 1000).toStringAsFixed(1)} km';
  }

  /// 运费展示文案
  String get feeFormatted {
    if (!feeKnown || providerFee == null) return '以实际呼叫为准';
    return '¥${providerFee!.toStringAsFixed(2)}';
  }

  factory DeliveryPriceEstimate.fromJson(Map<String, dynamic> json) {
    return DeliveryPriceEstimate(
      providerFee: json['provider_fee'] != null 
          ? (json['provider_fee'] as num).toDouble() 
          : null,
      feeKnown: json['fee_known'] == true,
      deliveryDistanceMeter: json['delivery_distance'] != null 
          ? (json['delivery_distance'] as num).toInt() 
          : null,
      kuaidicom: json['kuaidicom'] ?? '',
    );
  }
}

Future<DeliveryPriceEstimate> getDeliveryPrice({
  required String deliveryOrderId,
}) async {
  final supabase = Supabase.instance.client;

  try {
    final response = await supabase.functions.invoke(
      'get-delivery-price',
      body: {
        'meal_delivery_order_id': deliveryOrderId,
      },
    );

    if (response.status == 200) {
      final data = response.data as Map<String, dynamic>;
      return DeliveryPriceEstimate.fromJson(data);
    } else {
      final errorData = response.data as Map<String, dynamic>?;
      final errorMsg = errorData?['error'] ?? '获取运费失败';
      final detailMsg = errorData?['detail'] ?? '';
      throw Exception('$errorMsg ${detailMsg.isNotEmpty ? "($detailMsg)" : ""}');
    }
  } on FunctionException catch (e) {
    final details = e.details as Map<String, dynamic>?;
    final message = details?['error'] ?? e.reasonPhrase ?? '询价请求失败';
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

export interface DeliveryPriceResult {
  provider_fee: number | null;
  fee_known: boolean;
  delivery_distance: number | null;
  kuaidicom: string;
}

export async function getDeliveryPrice(
  mealDeliveryOrderId: string
): Promise<DeliveryPriceResult> {
  const { data, error } = await supabase.functions.invoke<DeliveryPriceResult>(
    'get-delivery-price',
    {
      body: { meal_delivery_order_id: mealDeliveryOrderId },
    }
  );

  if (error) {
    throw new Error(error.message || '获取预估运费失败');
  }

  return data!;
}
```
