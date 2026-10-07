# webdemo — 微信支付 & 支付宝集成测试 Web 应用

一个最小化的 Web 应用，用**真实**网关驱动 `daqing/moon-pay-sdk` 的微信支付
Native（扫码）流程和支付宝电脑网站支付（page pay）流程。它用于人工集成
测试：打开页面、完成支付，观察订单走完 SDK 真实的签名、查单与回调验签路径。

服务监听 **1943** 端口，每个网关一个独立页面；页面只有在对应网关凭证配置
齐全时才启用（页面加载时查询 `GET /api/config`）：

1. **`/` — 微信 · Native 扫码** — 通过 `Client::native_order` 创建 Native
   订单（`POST /api/orders`），把返回的 `code_url` 渲染成二维码；每 2 秒
   通过 `Client::query_order` 轮询订单
   （`GET /api/orders/<out_trade_no>`）；通过 `Client::verify_callback`
   接收微信支付的签名回调（`POST /api/wechat/notify`），核对金额后应答
   确认。页面还带一个 JSAPI 区块：
   `POST /api/wechat/jsapi/orders?amount_yuan=…&openid=…` 通过
   `Client::jsapi_order` 在微信内下单，返回签名好的
   `wx.requestPayment` 参数集（`Client::jsapi_pay_params`）——可粘到微信
   开发者工具验证，或作为小程序后端调用；订单走同一轮询端点。
2. **`/alipay` — 支付宝 · 电脑网站支付** — 通过 `Client::page_pay_url`
   构造签名收银台地址（`POST /api/alipay/orders`，
   `alipay.trade.page.pay`）并把浏览器跳转过去；支付宝把用户带回
   `/alipay?alipay_order=<out_trade_no>` 后，页面恢复轮询
   （`GET /api/alipay/orders/<out_trade_no>`）；通过
   `Client::verify_notify` 接收支付宝的异步通知
   （`POST /api/alipay/notify`），核对后应答纯文本 `success`，支付宝才会
   停止重试。

在没有公网域名的笔记本上，轮询也能照常工作；只要网关能访问到配置的
notify URL，notify 端点就会走完整的回调验签路径。

## 配置

所有凭证都来自环境变量，仓库里不保存任何机密。应用从启动它的 shell 环境中
读取 `WXPAY_*` 和 `ALIPAY_*` 变量——可以直接 export，也可以 source 一份填好
的模板（推荐；`cmd/webdemo/env.sh` 已加入 gitignore）：

```bash
cp cmd/webdemo/env.example.sh cmd/webdemo/env.sh
$EDITOR cmd/webdemo/env.sh          # 填入真实网关凭证
source cmd/webdemo/env.sh && moon run cmd/webdemo
```

**至少一个**网关的必填变量齐全时应用即可启动，另一个网关的页面保持停用；
启动时会打印每个不完整配置缺了什么，配置不齐的网关不会收到任何请求。

### 微信支付（`WXPAY_*`）

| 环境变量 | 必填 | 说明 |
| --- | --- | --- |
| `WXPAY_APPID` | 是 | 商户 app id，例如 `wx…` |
| `WXPAY_MCHID` | 是 | 商户号 |
| `WXPAY_SERIAL_NO` | 是 | 商户 API 证书序列号 |
| `WXPAY_PRIVATE_KEY` | 是 | API 证书私钥，可以是 PEM 文本，也可以是 PEM 文件路径 |
| `WXPAY_API_V3_KEY` | 是 | 用于回调解密的 APIv3 密钥 |
| `WXPAY_BASE_URL` | 否 | 网关地址，默认 `https://api.mch.weixin.qq.com` |
| `WXPAY_PUBLIC_KEY` | 否 | 公钥模式：商户控制台下载的微信支付公钥（`pub_key.pem`），PEM 文本或文件路径 |
| `WXPAY_PUBLIC_KEY_ID` | 否 | 公钥模式：控制台显示的公钥序列号，例如 `PUB_KEY_ID_25566888`——两个都填或都不填 |
| `WXPAY_NOTIFY_URL` | 否 | 下单时传入的回调地址，默认为占位符 |

设置 `WXPAY_PUBLIC_KEY`/`WXPAY_PUBLIC_KEY_ID` 后，微信的签名会用这把公钥
验证，不再下载平台证书（公钥模式，新商户账号默认）；不设置则走证书模式
（`/v3/certificates`）。

### 支付宝（`ALIPAY_*`）

| 环境变量 | 必填 | 说明 |
| --- | --- | --- |
| `ALIPAY_APPID` | 是 | 支付宝开放平台「网页应用」的 APPID，例如 `2021…` |
| `ALIPAY_PRIVATE_KEY` | 是 | 应用私钥（RSA2，用支付宝密钥工具生成），PEM 文本或文件路径 |
| `ALIPAY_PUBLIC_KEY` | 是 | **支付宝公钥**——开放平台控制台「接口加签方式 → 公钥模式」显示的那把，**不是**你自己的应用公钥；PEM 文本或文件路径 |
| `ALIPAY_GATEWAY_URL` | 否 | 网关地址，默认 `https://openapi.alipay.com/gateway.do`；用沙箱凭证测试时指向沙箱网关 |
| `ALIPAY_NOTIFY_URL` | 否 | 支付宝异步通知 POST 的地址，默认为占位符 |

SDK 只实现了**公钥模式**集成：没有 `app_cert_sn`/`alipay_root_sn` 字段，
所以控制台的加签方式必须选「公钥模式」，不要选「公钥证书」。应用需要先
添加「电脑网站支付」能力；正式环境收款需要企业/个体工商户资质并提交审核
上线。

### 每个值必须填什么

这些值填错是网关拒单的最常见原因。运行 `bash cmd/webdemo/diagnose.sh`
可以机械化核对全部配置。

| 环境变量 | 必须是 | 不能是 |
| --- | --- | --- |
| `WXPAY_SERIAL_NO` | 商户 **API 证书**序列号——40 位十六进制，来自证书 zip 里的 `apiclient_cert.pem`，或 商户平台 → API安全 → **API证书** 页面 | `PUB_KEY_ID_...` 开头的**公钥**序列号 |
| `WXPAY_PRIVATE_KEY` | 与上面序列号**同一次申请**的证书 zip 里的 `apiclient_key.pem` | `pub_key.pem`（那是公钥）、自己用 openssl 生成的密钥——微信按请求里的序列号找到证书来验签，私钥必须与该证书配套 |
| `WXPAY_API_V3_KEY` | 商户平台 → API安全 里设置的 32 位 APIv3 密钥 | 登录密码或 APIv2 密钥 |
| `WXPAY_PUBLIC_KEY` | 控制台「**微信支付公钥**」下载的 `pub_key.pem`（公钥模式） | 自己证书的公钥 |
| `WXPAY_PUBLIC_KEY_ID` | `pub_key.pem` 旁边显示的 `PUB_KEY_ID_...` 公钥序列号 | API 证书序列号 |
| `ALIPAY_PRIVATE_KEY` | 支付宝密钥工具生成的应用私钥，与上传到控制台的应用公钥配对 | 支付宝公钥 |
| `ALIPAY_PUBLIC_KEY` | 上传应用公钥后控制台显示的**支付宝公钥** | 自己的应用公钥或应用私钥——支付宝侧最常见的错误 |

补充说明：

- 小程序 appid 也可以做 Native 扫码支付（全程不涉及 openid），前提是与
  商户号完成绑定（商户平台 → 产品中心 → AppID账号管理）。如果要做**小程序内**
  拉起支付，对应的是 JSAPI 下单，SDK 暂未实现。
- `SIGN_ERROR` 是签名层的拒绝，发生在 appid / 产品权限校验之前：说明私钥、
  请求里的证书序列号或时钟有问题，不是权限问题。
- 支付宝首个真实请求返回 `40002 invalid-signature`，说明网关找到了这个应用，
  但**控制台登记的应用公钥**与 `ALIPAY_PRIVATE_KEY` 不配对。重新上传由该
  私钥导出的应用公钥（`openssl pkey -in <private_key.pem> -pubout`），并确认
  控制台「接口加签方式」是**公钥模式**——公钥证书模式同样报 invalid-signature，
  本 SDK 不支持。
- 收银台页返回 `订单信息无法识别 / INVALID_PARAMETER`（或跳到
  `errorCode=FISHING_RISK`），说明签名已通过但该应用无法创建交易：应用必须
  **已上线**（不能是「开发中」），且已签约「电脑网站支付」（商家平台 →
  产品中心 → 我的产品；需企业/个体工商户资质）。未签约时想跑通流程可用
  沙箱：沙箱凭证 + `ALIPAY_GATEWAY_URL=https://openapi-sandbox.dl.alipaydev.com/gateway.do`。

### 支付宝回跳地址

`page_pay_url` 需要传 `return_url`。webdemo 根据请求的 `Host` 头生成
`http://<host>/alipay?alipay_order=<out_trade_no>`，付款后浏览器落回支付宝
页面并自动恢复该订单的轮询。支付宝会在回跳时往这个 URL 追加带签名的 GET
参数；demo 忽略这些参数，只信任 `query_order` 和验签过的 `notify`——生产
代码也应该这样做（仅凭 `return_url` 回跳永远不能证明已支付）。

## 运行

在仓库根目录执行（应用启动时会读取 `cmd/webdemo/assets/`），并保证 shell 里
带有 `WXPAY_*` / `ALIPAY_*` 变量——可以直接内联传入：

```bash
WXPAY_APPID=wx… WXPAY_MCHID=1900… WXPAY_SERIAL_NO=… \
WXPAY_PRIVATE_KEY=./apiclient_key.pem WXPAY_API_V3_KEY=… \
moon run cmd/webdemo
```

或者按[配置](#配置)一节的方式 source 填好的 `cmd/webdemo/env.sh`。

然后打开 <http://127.0.0.1:1943>（微信）或 <http://127.0.0.1:1943/alipay>
（支付宝），选择金额，用想测的网关付款：微信扫码，或点击按钮跳转支付宝
收银台。每个页面的调试日志会记录每次查单响应。

如果网关返回 `SIGN_ERROR (http 401)`，运行 `bash cmd/webdemo/diagnose.sh`——
它会检查时钟、序列号/密钥格式、私钥 ↔ 证书的配对关系，以及支付宝密钥变量
（包括「公钥其实填成了自己的钥匙」这种错误），不会打印任何私钥内容。

缺少凭证时，启动会打印缺了哪些变量；两个网关都没有配置时应用直接退出——
变量不齐全就不会向网关发起任何请求。

## 真实扣款提醒

每一笔订单都是真实扣款。金额选择器默认 ¥0.01，除非确有需要，不要调大。
单号以 `IT` 开头，便于在商户后台辨认测试订单并在事后退款。

页面附带的 `assets/qrcode.js` 是 Kazuhiko Arase 的
[qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator)
（MIT 许可），已内嵌到仓库中，页面可离线工作。
