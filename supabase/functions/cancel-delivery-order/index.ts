// 快递100 同城急送「取消订单」入口（method=cancel）。
//
// 职责边界：只做取消。发单在 dispatch-delivery-order，状态回调在 delivery-order-callback，
// 加小费将来另建函数 —— 不要往任何一个函数里堆 method 分支。
//
// ⚠️ 取消可能产生费用（文档：「注意可能产生费用」），cancelFee 即我方真实成本。
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'npm:@supabase/supabase-js@2';
import md5 from 'npm:blueimp-md5@2.19.0';
console.info('server started');

// 测试环境地址。快递100 同城急送的测试环境 = 把正式地址换成下面这个。
// ⚠️ 正式环境是 https://api.kuaidi100.com/bsamecity/order。
//    部署前务必确认打到哪个环境 —— 误打到正式会真实扣费。
const KUAIDI100_URL = 'http://e-test.kuaidilab.com/api/bsamecity/order';

// 可取消的本地状态。终态（delivered / received）与尚未发单的状态都拒绝。
// 不含 cancelled：它走幂等分支返回成功，不算「拒绝」。
const CANCELLABLE_STATUSES = ['awaiting_delivery', 'delivering'];

// 客户端传的取消原因 key → 快递100 的 cancelMsgType（参数字典三，闭集 1-8）。
// 让客户端传 key 而非数字码：码表是对方私有枚举，映射收在函数里，改文案不必发版。
// https://api.kuaidi100.com/document/tong-cheng-ji-jian-can-shu-zi-dian#section_2
const CANCEL_REASON_MAP: Record<string, number> = {
  no_longer_needed: 1, // 不需要寄件了
  wrong_order_info: 2, // 填错订单信息
  courier_requested: 3, // 配送员要求取消
  goods_unavailable: 4, // 暂时无法提供待配送物品
  duplicate: 5, // 重复下单，取消此单
  courier_no_show: 6, // 配送员没来取货
  no_courier: 7, // 没有配送员接单
  other: 8 // 其他
};

// 默认 8「其他」：商家端不给原因时也必须能取消。
// ⚠️ 不能用表外值（如 99），cancelMsgType 是必填 Int，会换回 30001。
const DEFAULT_CANCEL_MSG_TYPE = 8;

// 统一响应包装：JSON body + Content-Type，避免每处 return 重复三行 headers。
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

/**
 * 调用快递100 同城急送**取消**接口。
 *
 * 签名规则：sign = MD5(param + t + key + secret)，32 位大写。
 * param 必须与签名使用同一份序列化结果，否则会 30002 验证签名失败。
 */
async function callKuaidi100(method: string, param: Record<string, unknown>) {
  const key = Deno.env.get('KUAIDI100_KEY');
  const secret = Deno.env.get('KUAIDI100_SECRET');
  if (!key || !secret) {
    throw new Error('缺少 KUAIDI100_KEY / KUAIDI100_SECRET');
  }
  const t = Date.now().toString();
  const paramJson = JSON.stringify(param);
  const sign = md5(paramJson + t + key + secret).toUpperCase();
  console.log(`kuaidi100 request, method: ${method}, t: ${t}, param: ${paramJson}`);
  const res = await fetch(KUAIDI100_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ method, key, t, sign, param: paramJson })
  });
  const text = await res.text();
  console.log(`kuaidi100 response: ${text}`);
  if (!res.ok) {
    throw new Error(`快递100 HTTP ${res.status}: ${text}`);
  }
  // 网关可能在 HTTP 200 下回 HTML；显式抛错，别伪装成我方的「服务器内部错误」。
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`快递100 返回非 JSON（HTTP ${res.status}）: ${text.slice(0, 200)}`);
  }
}

Deno.serve(async (req) => {
  try {
    // 1. 建 supabase 客户端
    // 必须把用户 JWT 显式转发给 PostgREST，auth.uid() 才等于该用户，RLS 才有身份。
    // 不能用 headers: req.headers —— req.headers 是 Headers 实例，supabase-js 用对象
    // 展开合并（{...headers}），而展开 Headers 得到 {}，Authorization 会被静默丢掉。
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: '缺少 Authorization' }, 401);
    }
    const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')!)['default'], {
      global: {
        headers: { Authorization: authHeader }
      }
    });
    // 2. 获取请求数据。只收配送单 id，taskId / orderId 一律查库补齐，绝不信任客户端。
    const body = await req.json();
    const deliveryOrderId: string | undefined = body?.meal_delivery_order_id;
    // reason 是字符串 key，不是快递100 的数字码（映射见 CANCEL_REASON_MAP）。
    const reasonKey: string | undefined = body?.reason;
    // 注：cancelMsg（自由文本）不透传 —— 文档未给长度上限，放行有风险。
    console.log(`meal_delivery_order_id: ${deliveryOrderId}, reason: ${reasonKey ?? '(未传)'}`);
    if (!deliveryOrderId) {
      return json({ error: '缺少 meal_delivery_order_id' }, 400);
    }
    // reason 不在表里 = 客户端 bug，直接 400，不悄悄换成默认值。
    let cancelMsgType = DEFAULT_CANCEL_MSG_TYPE;
    if (reasonKey !== undefined && reasonKey !== null) {
      const mapped = CANCEL_REASON_MAP[String(reasonKey)];
      if (mapped === undefined) {
        return json({
          error: `未知的取消原因 ${reasonKey}`,
          allowed: Object.keys(CANCEL_REASON_MAP)
        }, 400);
      }
      cancelMsgType = mapped;
    }
    // 3. 通过 auth 获取 user，确认 token 有效
    const token = authHeader.replace('Bearer ', '');
    const { data: user } = await supabase.auth.getUser(token);
    if (!user?.user) {
      return json({ error: 'token 无效或已过期' }, 401);
    }
    // 4. 读配送单
    const { data: deliveryOrder, error: deliveryOrderError } = await supabase
      .from('meal_delivery_order')
      .select('id, merchant_id, status, delivery_provider, provider_order_id, provider_task_id, provider_status')
      .eq('id', deliveryOrderId)
      .maybeSingle();
    console.log(`deliveryOrder: ${JSON.stringify(deliveryOrder)}, deliveryOrderError: ${JSON.stringify(deliveryOrderError)}`);
    if (deliveryOrderError) {
      return json({ error: '读取配送单失败', detail: deliveryOrderError.message }, 500);
    }
    if (!deliveryOrder) {
      return json({ error: '配送单不存在或无权访问' }, 404);
    }
    // 5. 校验归属。merchant 的 SELECT 策略是公开可读（USING true），RLS 不构成归属校验，
    // 必须显式比对 user_id。且必须在幂等判断之前：幂等只要求不打快递100，
    // 不要求跳过鉴权，否则会把别人的 provider_order_id 泄露给任何登录用户。
    const { data: merchant, error: merchantError } = await supabase
      .from('merchant')
      .select('id, user_id')
      .eq('id', deliveryOrder.merchant_id)
      .maybeSingle();
    console.log(`merchant: ${JSON.stringify(merchant)}, merchantError: ${JSON.stringify(merchantError)}`);
    if (merchantError) {
      return json({ error: '读取商家失败', detail: merchantError.message }, 500);
    }
    if (!merchant) {
      return json({ error: '商家不存在' }, 404);
    }
    if (merchant.user_id !== user.user.id) {
      return json({ error: '无权取消该配送单' }, 403);
    }
    // 6. 幂等：已取消直接返回成功，不再打快递100。
    // 放在状态/服务商校验之前 —— 重试取消必须是无害的，而不是 409。
    if (deliveryOrder.status === 'cancelled') {
      return json({
        already_cancelled: true,
        provider_order_id: deliveryOrder.provider_order_id,
        provider_status: deliveryOrder.provider_status,
        status: 'cancelled',
        cancel_fee: null
      });
    }
    // 7. 状态校验
    if (!CANCELLABLE_STATUSES.includes(deliveryOrder.status)) {
      return json({ error: `当前状态 ${deliveryOrder.status} 不可取消` }, 409);
    }
    // 8. 服务商校验。手工建的测试单没有 provider_order_id，打过去只会换回下游错误。
    if (deliveryOrder.delivery_provider !== 'kuaidi100') {
      return json({ error: '该配送单非快递100 运力，无法取消' }, 409);
    }
    if (!deliveryOrder.provider_order_id || !deliveryOrder.provider_task_id) {
      return json({ error: '该配送单缺少第三方单号，无法取消' }, 409);
    }
    // 9. 取消。taskId / orderId 都是必填，缺一个可能取消错单，本地先拦。
    const param = {
      taskId: deliveryOrder.provider_task_id,
      orderId: deliveryOrder.provider_order_id,
      cancelMsgType
    };
    const resp = await callKuaidi100('cancel', param);
    // 10. 落库：直接推进到 cancelled，不等 720 回调 —— 回调可能压根没配，
    // 那样商家点完取消界面会一直显示「配送中」，只能靠人工查库。
    // cancelFee 可能是 '' 或非数字，Number('') === 0 会写成假成本（与 provider_fee 同一个坑）。
    const hasData = resp.data !== undefined && resp.data !== null;
    const { cancelFee } = resp.data ?? {};
    const fee = cancelFee !== undefined && cancelFee !== null && cancelFee !== '' && Number.isFinite(Number(cancelFee))
      ? Number(cancelFee)
      : null;
    const cancelledFields = {
      status: 'cancelled',
      provider_status: 720,
      provider_status_desc: '订单取消',
      cancel_fee: fee,
      cancel_reason: reasonKey ? String(reasonKey) : 'other',
      updated_at: new Date().toISOString()
      // 不清空 dispatch_failed_reason：回调在 720 时会写入下游的取消原因，
      // 那是对方的口径，与这里的 cancel_reason 来源不同，抹掉就没答案了。
    };
    // 30005「订单已取消」按成功处理：说明对方已是取消态，只是我方库里没跟上，
    // 按失败返回会让商家永远取消不掉。只有 message 明确提到「已取消」才走这条，
    // 其余 30005 仍按失败返回 —— 宁可多一次人工核对，不可把失败当成功。
    const downstreamAlreadyCancelled = Number(resp.code) === 30005
      && typeof resp.message === 'string'
      && resp.message.includes('已取消');
    // code 用 Number() 比较：该网关会输出字符串化数字字段（文档把 cancelFee 标成 String），
    // 严格 !== 200 会把一次成功判成失败。
    const codeOk = Number(resp.code) === 200;
    if (!downstreamAlreadyCancelled && (!resp.success || !codeOk)) {
      const failureReason = `${resp.code} ${resp.message}`;
      await supabase.from('meal_delivery_order').update({ dispatch_failed_reason: failureReason }).eq('id', deliveryOrder.id);
      return json({ error: '取消失败', code: resp.code, detail: resp.message }, 502);
    }
    if (downstreamAlreadyCancelled) {
      console.warn(`快递100 返回「已取消」，按成功处理并补齐本地状态: ${resp.message}`);
    }
    // data 缺失时不假装知道费用：状态照改，但显式告知调用方费用未知。
    if (!hasData) {
      console.warn(`快递100 取消成功但未返回 data，费用未知: ${JSON.stringify(resp)}`);
    }
    const { error: updateError } = await supabase.from('meal_delivery_order').update(cancelledFields).eq('id', deliveryOrder.id);
    console.log(`updateError: ${JSON.stringify(updateError)}`);
    // 取消已在对方侧生效、本地却没记上，必须显式暴露，不能当成功返回。
    // 重试会重新打一次快递100（对方回 30005）从而自愈，不会永远卡住。
    if (updateError) {
      return json({
        error: '取消已成功但本地落库失败，请人工核对后补录',
        provider_order_id: deliveryOrder.provider_order_id,
        provider_task_id: deliveryOrder.provider_task_id,
        detail: updateError.message
      }, 500);
    }
    return json({
      provider_order_id: deliveryOrder.provider_order_id,
      cancel_fee: fee,
      // data 缺失时费用未知，别让调用方把「不知道」读成「免费」。
      cancel_fee_known: hasData,
      status: 'cancelled'
    });
  } catch (err) {
    // 兜住意外异常（body 非 JSON、header 缺失、字段访问越界、fetch 抛错等），
    // 保证前端永远拿到统一的 JSON，而不是 runtime 的裸 500。
    console.error(err);
    return json({ error: '服务器内部错误' }, 500);
  }
});
