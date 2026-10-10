// 快递100 同城急送「取消订单」入口（method=cancel）。
//
// 调用方有两类，都要放行（归属校验见第 5 步，两者都不匹配一律 404）：
//   * 商家 —— 配送出问题要取消；身份 = merchant.user_id
//   * 用户 —— 下单后取消自己这一单；身份 = recipe_order.user_id
//
// ⚠️ 本函数整体用 **service_role（secret key）** 连库，即**绕过 RLS**，原因有两个：
//   1. RLS 的 UPDATE 策略只允许商家更新配送单（`merchant_id IN (select id from merchant
//      where user_id = auth.uid())`），顾客的取消会被静默过滤成「更新 0 行」；
//   2. 而 PostgREST 对「0 行」**不报错**（204 + error: null），照原样写下去，
//      顾客侧会拿到「取消成功」，库里却一个字都没写 —— 上游已取消（可能已扣费），本地还在配送中。
//   读也一并用同一个客户端（而不是「用户身份读 + service_role 写」）：读得到的行和写得进的
//   行必须是同一批，否则就会出现「读得见、写不进」这种半通状态，正是上面那个 bug。
//
//   代价：RLS 不再替我们把关。因此第 5 步的显式归属校验（商家老板 或 下单用户）**是唯一防线**，
//   顺序不能动；写回时还要取回受影响行数兜底（见第 10 步）。
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
//
// ⚠️ reason 是**必填**：上游 cancelMsgType 是必填 Int，我们不自造默认值 ——
//    「取消原因全是其他」的数据没有任何排障价值，宁可在入口就拒绝。
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
    // 1. 建 supabase 客户端：service_role（见文件头，本函数绕过 RLS）
    // 不能用 headers: req.headers —— req.headers 是 Headers 实例，supabase-js 用对象
    // 展开合并（{...headers}），而展开 Headers 得到 {}，Authorization 会被静默丢掉。
    // 用户身份仍从 Authorization 头单独取出来验（第 3 步），它不参与 RLS，只用于鉴权比对。
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: '缺少 Authorization' }, 401);
    }
    // service_role 由 Supabase 自动注入（delivery-order-callback 也用它读写库）。
    // 缺失就是部署环境异常，直接抛错，别退化成用用户身份去写 ——
    // 那会让顾客的取消静默写不进去，而函数还返回成功。
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!serviceKey) {
      throw new Error('缺少 SUPABASE_SERVICE_ROLE_KEY');
    }
    const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', serviceKey);
    // 2. 获取请求数据。只收配送单 id，taskId / orderId 一律查库补齐，绝不信任客户端。
    const body = await req.json();
    const deliveryOrderId: string | undefined = body?.meal_delivery_order_id;
    // reason 是字符串 key，不是快递100 的数字码（映射见 CANCEL_REASON_MAP）。
    const reasonKey = body?.reason;
    // cancel_msg：商家填的自由文本，可选，原样上行给快递100（上游字段名 cancelMsg）。
    const rawCancelMsg = body?.cancel_msg;
    console.log(`meal_delivery_order_id: ${deliveryOrderId}, reason: ${reasonKey ?? '(未传)'}, cancel_msg: ${rawCancelMsg ?? '(未传)'}`);
    if (!deliveryOrderId) {
      return json({ error: '缺少 meal_delivery_order_id' }, 400);
    }
    // reason 必填。缺了就是客户端没让商家选原因，直接 400 —— 见 CANCEL_REASON_MAP 上方注释。
    const allowedReasons = Object.keys(CANCEL_REASON_MAP);
    if (reasonKey === undefined || reasonKey === null || String(reasonKey).trim() === '') {
      return json({ error: '缺少取消原因 reason', allowed: allowedReasons }, 400);
    }
    const reason = String(reasonKey).trim();
    const cancelMsgType = CANCEL_REASON_MAP[reason];
    // 表外的值 = 客户端 bug，同样 400，不悄悄换成「其他」。
    if (cancelMsgType === undefined) {
      return json({ error: `未知的取消原因 ${reasonKey}`, allowed: allowedReasons }, 400);
    }
    // cancel_msg 可选：只收字符串，去掉首尾空白后为空就视为没填。
    let cancelMsg: string | undefined;
    if (rawCancelMsg !== undefined && rawCancelMsg !== null) {
      if (typeof rawCancelMsg !== 'string') {
        return json({ error: 'cancel_msg 必须是字符串' }, 400);
      }
      const trimmed = rawCancelMsg.trim();
      if (trimmed !== '') {
        cancelMsg = trimmed;
      }
    }
    // 3. 校验 JWT：拿到「你是谁」。service_role 客户端只负责把 token 交给 auth 服务校验，
    //    身份仍然只来自这个 token，不接受客户端自报的 user id。
    const token = authHeader.replace('Bearer ', '');
    const { data: user } = await supabase.auth.getUser(token);
    if (!user?.user) {
      return json({ error: 'token 无效或已过期' }, 401);
    }
    // 4. 读配送单。recipe_order_id 要留着做用户侧归属校验（见第 5 步）。
    const { data: deliveryOrder, error: deliveryOrderError } = await supabase
      .from('meal_delivery_order')
      .select('id, merchant_id, recipe_order_id, status, delivery_provider, provider_order_id, provider_task_id, provider_status')
      .eq('id', deliveryOrderId)
      .maybeSingle();
    console.log(`deliveryOrder: ${JSON.stringify(deliveryOrder)}, deliveryOrderError: ${JSON.stringify(deliveryOrderError)}`);
    if (deliveryOrderError) {
      return json({ error: '读取配送单失败', detail: deliveryOrderError.message }, 500);
    }
    // 5. 校验归属：商家老板 或 下单用户，二者之一是调用者才放行。
    // 必须在幂等判断之前：幂等只要求不打快递100，不要求跳过鉴权，
    // 否则会把别人的 provider_order_id 泄露给任何登录用户。
    // 注意：读库走 service_role，RLS 不会替我们过滤 —— 归属校验**必须**在这里做死。
    //
    // 5a. 商家。merchant 的 SELECT 策略本就是公开可读（USING true），
    //     必须显式比对 user_id —— 不比对的话任何登录用户都能取消别人的单。
    let isMerchantOwner = false;
    if (deliveryOrder) {
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
      isMerchantOwner = merchant.user_id === user.user.id;
    }
    // 5b. 用户。身份挂在下单的 recipe_order 上（meal_delivery_order 没有 user_id 列）。
    //     只有商家侧不匹配时才查这一条。
    let isOrderOwner = false;
    if (deliveryOrder && !isMerchantOwner) {
      const { data: recipeOrder, error: recipeOrderError } = await supabase
        .from('recipe_order')
        .select('id, user_id')
        .eq('id', deliveryOrder.recipe_order_id)
        .maybeSingle();
      console.log(`recipeOrder: ${JSON.stringify(recipeOrder)}, recipeOrderError: ${JSON.stringify(recipeOrderError)}`);
      if (recipeOrderError) {
        return json({ error: '读取订单失败', detail: recipeOrderError.message }, 500);
      }
      isOrderOwner = recipeOrder?.user_id === user.user.id;
    }
    // 5c. 单不存在 与 不是你的单 返回同一个 404：不向调用方泄露「这个 id 存不存在」。
    if (!deliveryOrder || (!isMerchantOwner && !isOrderOwner)) {
      console.log(`归属校验不通过: order=${deliveryOrderId}, exists=${!!deliveryOrder}, uid=${user.user.id}`);
      return json({ error: '配送单不存在或无权访问' }, 404);
    }
    console.log(`caller: ${isMerchantOwner ? 'merchant' : 'order_owner'} (${user.user.id})`);
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
    const param: Record<string, unknown> = {
      taskId: deliveryOrder.provider_task_id,
      orderId: deliveryOrder.provider_order_id,
      cancelMsgType
    };
    // cancelMsg 可选：没填就不带这个字段（带空串等于告诉对方「有备注但没内容」）。
    if (cancelMsg !== undefined) {
      param.cancelMsg = cancelMsg;
    }
    const resp = await callKuaidi100('cancel', param);
    // 10. 落库：直接推进到 cancelled，不等 720 回调 —— 回调可能压根没配，
    // 那样商家点完取消界面会一直显示「配送中」，只能靠人工查库。
    // cancelFee 可能是 '' 或非数字，Number('') === 0 会写成假成本（与 provider_fee 同一个坑）。
    const { cancelFee } = resp.data ?? {};
    const fee = cancelFee !== undefined && cancelFee !== null && cancelFee !== '' && Number.isFinite(Number(cancelFee))
      ? Number(cancelFee)
      : null;
    const cancelledFields = {
      status: 'cancelled',
      provider_status: 720,
      provider_status_desc: '订单取消',
      cancel_fee: fee,
      cancel_reason: reason,
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
      // 只记原因、不动状态。best-effort：这一步失败也不影响下面的 502 返回。
      await supabase.from('meal_delivery_order').update({ dispatch_failed_reason: failureReason }).eq('id', deliveryOrder.id);
      return json({ error: '取消失败', code: resp.code, detail: resp.message }, 502);
    }
    if (downstreamAlreadyCancelled) {
      console.warn(`快递100 返回「已取消」，按成功处理并补齐本地状态: ${resp.message}`);
    }
    // 收费与否不影响「已取消」这个事实，状态照改；但费用未知必须显式告诉调用方。
    // 两种未知：data 整个缺失，或 data 在而 cancelFee 是空串/非数字。
    if (fee === null) {
      console.warn(`快递100 取消成功但未拿到有效 cancelFee，费用未知: ${JSON.stringify(resp)}`);
    }
    // 落库必须取回受影响行数（.select('id')）：
    // PostgREST 对「更新 0 行」不报错（204 + error: null），只判 error 会把「一个字都没写」
    // 当成功返回 —— 上游已取消（可能已扣费），本地还停在配送中，且幂等判断依赖
    // status='cancelled'，这个状态写不进去就永远收敛不了。
    const { data: updated, error: updateError } = await supabase
      .from('meal_delivery_order')
      .update(cancelledFields)
      .eq('id', deliveryOrder.id)
      .select('id');
    console.log(`updateError: ${JSON.stringify(updateError)}, updated: ${JSON.stringify(updated)}`);
    // 取消已在对方侧生效、本地却没记上，必须显式暴露，不能当成功返回。
    // 重试会重新打一次快递100（对方回 30005）从而自愈，不会永远卡住。
    if (updateError || !updated?.length) {
      return json({
        error: '取消已成功但本地落库失败，请人工核对后补录',
        provider_order_id: deliveryOrder.provider_order_id,
        provider_task_id: deliveryOrder.provider_task_id,
        detail: updateError?.message ?? '更新命中 0 行（没写进任何数据）'
      }, 500);
    }
    return json({
      provider_order_id: deliveryOrder.provider_order_id,
      cancel_fee: fee,
      // 只有真拿到数字才算「已知」，别让调用方把「不知道」读成「免费」。
      cancel_fee_known: fee !== null,
      status: 'cancelled'
    });
  } catch (err) {
    // 兜住意外异常（body 非 JSON、header 缺失、字段访问越界、fetch 抛错等），
    // 保证前端永远拿到统一的 JSON，而不是 runtime 的裸 500。
    console.error(err);
    return json({ error: '服务器内部错误' }, 500);
  }
});
