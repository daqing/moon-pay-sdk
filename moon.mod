// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "daqing/moon-pay-sdk"

version = "0.8.6"

readme = "README.mbt.md"

repository = "https://github.com/daqing/moon-pay-sdk"

license = "MIT"

keywords = [ "payment", "wechat-pay", "alipay", "sdk" ]

preferred_target = "native"

description = "Native MoonBit SDK for WeChat Pay and Alipay"

import {
  "moonbitlang/async@0.22.4",
  "moonbitstack/mooncrypt@0.3.1",
  "moonbitstack/mooncred@0.6.1",
  "moonbitstack/moonbase@0.4.0",
}
