# oc-tgtylab

oc-tgtylab = opencode 版 open-tgtylab。Ghost security-operator 工作区根。

板块路由：`kb/`（ctf-website / apk-reverse / pe-reverse / general）。

约束：
- `samples/` 只读，修改一律复制到 `patches/`
- 删除用 `samples/_quarantine/`，不直接 rm
- 凭据/Token 出现即停，报告，不记录
