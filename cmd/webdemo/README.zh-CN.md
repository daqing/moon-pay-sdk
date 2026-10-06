# webdemo — 微信支付集成测试 Web 应用

一个最小化的 Web 应用,用**真实**网关驱动 `daqing/moon-pay-sdk` 的微信支付
Native(扫码)流程。它用于人工集成测试:打开页面、用微信扫码,通过 SDK 真实的
签名、查单与回调验签路径,观察订单从 `NOTPAY` 变为 `SUCCESS`。

服务监听 **1943** 端口,页面会:

1. 通过 `Client::native_order` 创建 Native 订单(`POST /api/orders`),并把返回
   的 `code_url` 渲染成二维码;
2. 每 2 秒通过 `Client::query_order` 轮询订单
   (`GET /api/orders/<out_trade_no>`);
3. 通过 `Client::verify_callback` 接收微信支付的签名回调
   (`POST /api/wechat/notify`),核对金额后应答确认。

在没有公网域名的笔记本上,轮询也能照常工作;只要微信支付能访问到配置的
`WXPAY_NOTIFY_URL`,notify 端点就会走完整的回调验签路径。

## 配置

所有凭证都来自环境变量,仓库里不保存任何机密。应用从启动它的 shell 环境中读取
`WXPAY_*` 变量——可以直接 export,也可以 source 一份填好的模板(推荐;
`cmd/webdemo/env.sh` 已加入 gitignore):

```bash
cp cmd/webdemo/env.example.sh cmd/webdemo/env.sh
$EDITOR cmd/webdemo/env.sh          # 填入真实商户凭证
source cmd/webdemo/env.sh && moon run cmd/webdemo
```

| 环境变量 | 必填 | 说明 |
| --- | --- | --- |
| `WXPAY_APPID` | 是 | 商户 app id,例如 `wx…` |
| `WXPAY_MCHID` | 是 | 商户号 |
| `WXPAY_SERIAL_NO` | 是 | 商户 API 证书序列号 |
| `WXPAY_PRIVATE_KEY` | 是 | API 证书私钥,可以是 PEM 文本,也可以是 PEM 文件路径 |
| `WXPAY_API_V3_KEY` | 是 | 用于回调解密的 APIv3 密钥 |
| `WXPAY_BASE_URL` | 否 | 网关地址,默认 `https://api.mch.weixin.qq.com` |
| `WXPAY_PUBLIC_KEY` | 否 | 公钥模式:商户控制台下载的微信支付公钥(`pub_key.pem`),PEM 文本或文件路径 |
| `WXPAY_PUBLIC_KEY_ID` | 否 | 公钥模式:控制台显示的公钥序列号,例如 `PUB_KEY_ID_25566888`——两个都填或都不填 |
| `WXPAY_NOTIFY_URL` | 否 | 下单时传入的回调地址,默认为占位符 |

设置 `WXPAY_PUBLIC_KEY`/`WXPAY_PUBLIC_KEY_ID` 后,微信的签名会用这把公钥验证,
不再下载平台证书(公钥模式,新商户账号默认);不设置则走证书模式
(`/v3/certificates`)。

### 每个值必须填什么

这些值填错是网关返回 `SIGN_ERROR (http 401)` 的最常见原因。运行
`bash cmd/webdemo/diagnose.sh` 可以机械化核对全部配置。

| 环境变量 | 必须是 | 不能是 |
| --- | --- | --- |
| `WXPAY_SERIAL_NO` | 商户 **API 证书**序列号——40 位十六进制,来自证书 zip 里的 `apiclient_cert.pem`,或 商户平台 → API安全 → **API证书** 页面 | `PUB_KEY_ID_...` 开头的**公钥**序列号 |
| `WXPAY_PRIVATE_KEY` | 与上面序列号**同一次申请**的证书 zip 里的 `apiclient_key.pem` | `pub_key.pem`(那是公钥)、自己用 openssl 生成的密钥——微信按请求里的序列号找到证书来验签,私钥必须与该证书配套 |
| `WXPAY_API_V3_KEY` | 商户平台 → API安全 里设置的 32 位 APIv3 密钥 | 登录密码或 APIv2 密钥 |
| `WXPAY_PUBLIC_KEY` | 控制台"**微信支付公钥**"下载的 `pub_key.pem`(公钥模式) | 自己证书的公钥 |
| `WXPAY_PUBLIC_KEY_ID` | `pub_key.pem` 旁边显示的 `PUB_KEY_ID_...` 公钥序列号 | API 证书序列号 |

补充说明:

- 小程序 appid 也可以做 Native 扫码支付(全程不涉及 openid),前提是与
  商户号完成绑定(商户平台 → 产品中心 → AppID账号管理)。如果要做**小程序内**
  拉起支付,对应的是 JSAPI 下单,SDK 暂未实现。
- `SIGN_ERROR` 是签名层的拒绝,发生在 appid / 产品权限校验之前:说明私钥、
  请求里的证书序列号或时钟有问题,不是权限问题。

## 运行

在仓库根目录执行(应用启动时会读取 `cmd/webdemo/assets/`),并保证 shell 里
带有 `WXPAY_*` 变量——可以直接内联传入:

```bash
WXPAY_APPID=wx… WXPAY_MCHID=1900… WXPAY_SERIAL_NO=… \
WXPAY_PRIVATE_KEY=./apiclient_key.pem WXPAY_API_V3_KEY=… \
moon run cmd/webdemo
```

或者按[配置](#配置)一节的方式 source 填好的 `cmd/webdemo/env.sh`。

然后打开 <http://127.0.0.1:1943>,选择金额,用微信扫码。页面上的调试日志会
记录每次查单响应。

如果网关返回 `SIGN_ERROR (http 401)`,运行 `bash cmd/webdemo/diagnose.sh`——
它会检查时钟、序列号格式和私钥 ↔ 证书的配对关系,不会打印任何私钥内容。

缺少凭证时,应用会打印需要设置的环境变量然后退出——变量不齐全就不会向网关
发起任何请求。

## 真实扣款提醒

每一笔订单都是真实扣款。金额选择器默认 ¥0.01,除非确有需要,不要调大。
单号以 `IT` 开头,便于在商户后台辨认测试订单并在事后退款。

页面附带的 `assets/qrcode.js` 是 Kazuhiko Arase 的
[qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator)
(MIT 许可),已内嵌到仓库中,页面可离线工作。
