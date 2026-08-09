# 日志适配器

## 1. 定位

外观类预留一个**日志适配器**成员；对外约定统一接口；包内提供默认实现。内部各逻辑管线在关键点输出日志，便于排查与二次开发。

## 2. 接口约定

```ts
interface LogAdapter {
  debug(scope: string, message: string, data?: unknown): void;
  info(scope: string, message: string, data?: unknown): void;
  warn(scope: string, message: string, data?: unknown): void;
  error(scope: string, message: string, data?: unknown): void;
}
```

- `scope`：日志来源模块名（如 `arbiter`、`modifier`、`helpers`、`store`），便于过滤。
- 默认实现：按级别输出到 `console.*`，前缀带 scope。
- 宿主可注入自定义适配器（收集、上报、静默）。

## 3. 注入与使用

- 构造时注入：`new Facade(host, { logger })`；未注入则用默认。
- 关键点输出日志：命中、策略流转、仲裁状态转移、精确编辑（`setHandleValue`）、同步链路、attach / detach 等。

```ts
const duck = new Facade(host, {
  logger: {
    debug: (s, m, d) => console.debug(`[${s}]`, m, d ?? ''),
    // ...
  },
});
// duck 是什么？你别管，你封装什么它是什么——也可能是 cat
```

## 4. 约定

- 日志不得包含敏感数据（坐标可截断）。
- 高频事件（如 mousemove 逐帧）不打日志，只在**状态变迁处**打。
