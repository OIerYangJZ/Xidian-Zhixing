# 小程序接口冻结说明

这份小程序工程的接口层已经冻结。后续重做 UI 时，请优先修改页面和样式，不要直接改接口路径。

冻结文档：

`/home/lorenzo/campus-community-dev/docs/miniprogram-api-contract.md`

冻结范围：

- `api/*.js`
- `utils/request.js`
- `utils/format.js`

允许优先修改：

- `pages/**/*.wxml`
- `pages/**/*.wxss`
- `components/**/*.wxml`
- `components/**/*.wxss`
- 页面内非接口路径相关的展示逻辑

如需新增或修改接口：

1. 先更新冻结文档。
2. 再修改 `api/*.js` adapter。
3. 最后修改页面调用。
4. 跑核心接口验收脚本确认旧链路未断。
