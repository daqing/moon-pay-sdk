# 微信公众号支付（JSAPI）测试指南

本文记录公众号支付（JSAPI，微信内网页 / 小程序网页两种载体）在 moon-pay-sdk
中的测试现状，以及继续推进测试的具体步骤。与 SDK 的其余部分一样，公众号支付
的代码路径已经全部有离线测试覆盖；剩下的工作是把真实网关联调走完。

## 一、测试现状

截至本文撰写时（v0.10.0，develop 分支），`moon test` 全绿（131/131）。

### 已覆盖（离线，mock transport）

`wechat/jsapi_test.mbt` 三条用例：

1. **下单请求与解析** — `jsapi_order` 正确 POST
   `/v3/pay/transactions/jsapi`，请求体携带 `payer.openid`，并从响应解析出
   `prepay_id`。
2. **支付参数与 paySign** — `jsapi_pay_params` 生成的参数集
   （`appId` / `timeStamp` / `nonceStr` / `package` / `signType=RSA` /
   `paySign`）中，`paySign` 能用测试商户公钥对四行规范串
   `appId\ntimeStamp\nnonceStr\npackage\n` 做 RSA-SHA256 验签通过。
3. **本地拒绝** — 空 `openid`、空 `prepay_id` 在本地直接以 `Config` 错误
   拒绝，不发出任何 HTTP 请求。

`cmd/webdemo`（集成测试 Web 应用）已内置 JSAPI 区块：输入 openid → 下单 →
返回签名好的 `wx.requestPayment` 参数集；订单走与 Native 相同的查单轮询端点。

### 未覆盖

1. **真实网关联调** — 上述测试全部针对 mock transport；微信网关尚未真实
   接受过一次 JSAPI 下单并成功扣款。
2. **e2e 回环测试不含 JSAPI** — `e2e/` 只覆盖 Native 流程（下单 → 回调 →
   验签解密 → 应答），没有 JSAPI 用例。
3. **公众号网页授权（OAuth2 换 openid）未实现** — `miniprogram` 包只封装了
   小程序的 code2session；公众号页面的 openid 目前需要自行获取，这是公众号
   支付端到端测试的主要堵点。

## 二、继续测试的步骤

### 第一步：准备凭证并核对

公众号支付比 Native 多两个硬性前提：

- **appid 必须是已认证的服务号**（或与商户号完成绑定的小程序 appid）；
- 下单用的 **openid 必须属于这个 appid**（openid 按 appid 隔离）。

```bash
cd ~/mzevo/open-source/moonbit/month10/moon-pay-sdk
cp cmd/webdemo/env.example.sh cmd/webdemo/env.sh
$EDITOR cmd/webdemo/env.sh      # 填 WXPAY_APPID / MCHID / SERIAL_NO / PRIVATE_KEY / API_V3_KEY
bash cmd/webdemo/diagnose.sh    # 机械核对时钟、序列号格式、私钥↔证书配对
```

变量含义与常见填错见 `docs/wechat.zh-CN.md` 的「环境变量」一节。

### 第二步：拿到该 appid 下的一个 openid

三选一：

1. **公众号网页授权**（正规途径）。在微信内打开：

   ```text
   https://open.weixin.qq.com/connect/oauth2/authorize?appid=<APPID>&redirect_uri=<你的页面>&response_type=code&scope=snsapi_base#wechat_redirect
   ```

   拿到 `code` 后换取 openid：

   ```text
   https://api.weixin.qq.com/sns/oauth2/access_token?appid=<APPID>&secret=<SECRET>&code=<CODE>&grant_type=authorization_code
   ```

   响应中的 `openid` 即为所需值。注意：需在公众平台「公众号设置 → 功能设置 →
   网页授权域名」配置好回调域名。

2. **借用小程序链路**。给 webdemo 配置 `WXPAY_APP_SECRET`，用页面上的小程序
   区块走 `wx.login` code 换 openid——前提是支付客户端的 appid 就是这个
   小程序 appid（openid 按 appid 隔离，跨 appid 的 openid 无效）。

3. **历史 openid**。该 appid 下任何一笔历史交易的付款人 openid（可在商户
   平台订单详情里查到）。

### 第三步：真实下单，验证网关接受

```bash
source cmd/webdemo/env.sh && moon run cmd/webdemo   # 监听 1943 端口
```

打开 <http://127.0.0.1:1943>，在 JSAPI 区块填入 openid，金额保持默认
¥0.01，点「创建 JSAPI 订单」。结果判据：

| 现象 | 含义 | 处理 |
| --- | --- | --- |
| 服务端日志 `jsapi order IT… prepay_id=…` | 网关已接受签名与 openid，下单成功 | 进入第四步 |
| `PARAM_ERROR: 无效的openid` | 请求签名已被接受；openid 不属于该 appid | 换第二步的方式 1/2 重新取 openid |
| `SIGN_ERROR (http 401)` | 签名层拒绝，发生在 appid/权限校验之前 | 回到 diagnose.sh 查密钥配对与时钟 |

### 第四步：在微信环境内真正拉起支付

webdemo 返回的参数集需要放进微信内页面调用
`WeixinJSBridge.invoke('getBrandWCPayRequest', params)`（公众号网页），或
交给小程序的 `wx.requestPayment(params)`。可选环境：

- **微信开发者工具**——「公众号网页项目」打开 webdemo 地址（真机与电脑同
  局域网时可行，需打开调试）。
- **真机微信**打开页面。注意：公众号 JSAPI 支付要求页面 URL 位于商户平台
  配置的**支付授权目录**下，否则微信报「当前页面的URL未注册」。webdemo 以
  根路径提供页面，需在 商户平台 → 产品中心 → 开发配置 把授权目录配成对应
  形式（含末尾 `/`）。

支付 ¥0.01 后，页面轮询（每 2 秒一次）应显示 `trade_state: SUCCESS`。

### 第五步：验证回调与对账

- **查单**：页面轮询走 `GET /api/orders/<out_trade_no>`，确认返回
  `Success` 状态与正确金额。
- **回调**：微信向 `WXPAY_NOTIFY_URL` POST 签名回调，落在 webdemo 的
  `POST /api/wechat/notify`，完成验签 + AES-256-GCM 解密后
  `notify_seen` 置 true。**本机无公网时回调收不到，属正常**——轮询足以证明
  支付成功；要验证回调路径需让 notify URL 公网可达（内网穿透或公网服务器）。
- **事后清理**：所有测试单号带 `IT` 前缀，在商户后台按前缀辨认并退款。

## 三、已知缺口与建议

1. **e2e 回环补 JSAPI 用例**（沿用 TASKS.md T7.3 的模式）：mock 微信服务器
   增加 `/v3/pay/transactions/jsapi` 路由，复用现有签名回调夹具，跑通
   「JSAPI 下单 → 回调验签解密 → 应答」全流程——不花钱即可锁住回归。
2. **TASKS.md 的 T9.3 已过时**——JSAPI 与小程序支付实际已实现并合入
   （commit `c6449ea`、`d1680ba`），任务清单中仍为未勾选状态，建议更新。
3. **（可选）公众号网页授权 helper**——`snsapi_base` 静默授权换 openid 是
   公众号支付的前置依赖，可考虑在 SDK 内提供（类似 `miniprogram` 的
   `code2session`），让公众号流程与小程序一样「一步到位」。

## 四、排错速查

| 报错 | 层级 | 原因与处理 |
| --- | --- | --- |
| `SIGN_ERROR (http 401)` | 请求签名层 | 私钥、序列号或时钟不对；跑 `diagnose.sh`。序列号必须是 API 证书序列号（40 位十六进制），不是 `PUB_KEY_ID_…` |
| `PARAM_ERROR: 无效的openid` | 业务参数层 | 签名已通过；openid 与下单 appid 不匹配 |
| 「当前页面的URL未注册」 | 商户平台配置 | 页面 URL 不在支付授权目录内 |
| 回调始终收不到 | 网络 | notify URL 需公网可达；本机测试可只依赖轮询查单 |
| 页面打不开 JSAPI 区块 | webdemo | `WXPAY_*` 变量未 export 或未重新 source；重启应用看启动日志缺哪些变量 |

## 相关文档

- `docs/wechat.zh-CN.md` — 微信支付总指南（凭证、变量、排错）
- `docs/wechat.md` — 同上英文版
- `cmd/webdemo/README.zh-CN.md` — webdemo 使用说明
- `wechat/jsapi_test.mbt` — JSAPI 离线测试用例
