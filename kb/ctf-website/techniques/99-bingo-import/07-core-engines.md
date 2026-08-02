# Bingo Core Engines — 补学文档 (ip_block_detector / verification / anti_hallucination / execution_anchor / phantom_guard)

来源: bingo v7.0.66 core/ 引擎层。这批是"判定置信"类资产，与 hunter 的 dual_ledger/EventKernel 互补。

## 1. IP Block Detector — 5 信号交叉判定 (ip_block_detector.py) ⭐⭐⭐

**哲学: 零误报 — 单信号不判, ≥3/5 才确认封禁。**

```
S1 http_code: status ∈ {403,429,503,999,530} 或 (WAF头 且 status>=400)
S2 multipath: /robots.txt,/favicon.ico,/sitemap.xml 中 ≥2 个被禁 (惰性, 仅 S1/S5 命中才跑)
S3 baseline:  基线(<400) → 封禁码 或 延迟 > 基线×10
S4 tcp_layer: HTTP 无响应 但 TCP connect 成功 = WAF HTTP 层封禁
S5 dns_vs_http: DNS 正常解析 但 HTTP 失败 = 防火墙
blocked = fired >= 3; confidence = fired/5
```

关键常量:
```python
_MIN_SIGNALS     = 3
_REPEAT_REQUIRED = 2
_PROBE_PATHS     = ["/robots.txt", "/favicon.ico", "/sitemap.xml"]
_BLOCK_CODES     = {403, 429, 503, 999, 530}   # 999=Cloudflare, 530=?
_WAF_HEADERS     = {"cf-ray","x-sucuri-id","x-fw-hash","x-akamai-session-info","x-cache-status"}
_WAF_BODIES      = ["access denied","your ip","ip address","has been blocked","automated request",
                    "captcha","cloudflare","sucuri website firewall","wordfence","rate limit",
                    "please wait","ddos protection","you have been blocked"]
```

机制要点:
- 响应指纹 = SHA256(body[:4096])[:16]; WAF body 命中时前缀 "waf_" 破坏指纹 → 后续对比不匹配
- 基线 TTL 缓存 300s + reset_baseline() ← 代理/指纹切换后强制重置点
- 连续封禁计数器: 连续多次确认才算"稳定封禁", 单次不算
- 404/500 明确排除; 1-2 次 timeout 明确排除

**接 hunter**: broker_state 的 SOFT_BAN 升级第二意见 + 指纹轮换触发条件。

## 2. Verification — P1-P5 置信度加权验证 (verification.py) ⭐⭐⭐

判级: VERIFIED | LIKELY | INCONCLUSIVE | REFUTED (置信度 0-1)

```
P5 Deterministic First:  确定性检查通过 +0.4   (15 漏洞类型专属检查, 6 个已实现)
P1 Reproducibility:      reproduction_count >= 3 次复现 +0.25
P2 Causal Isolation:     baseline_response != response_raw +0.2   (正常vs恶意对比)
P3 Narrow Questions:     payload 中 ? 数量 <= 2 +0.1
P4 Generate≠Validate:    reproduction_count > 0 +0.05
判定: confidence>=0.75 → VERIFIED; >=0.45 → LIKELY; >=0.2 → INCONCLUSIVE; else REFUTED
```

确定性检查 (6 类已实现):
- check_sqli: DB 错误串 (sql syntax/mysql_fetch/ora-/pg::/1064) 且不在 baseline; UNION 长度>1.5x baseline
- check_xss: payload 逐字反射或 <script/onerror/onload/javascript: marker 反射
- check_lfi: root:x:0:0: / [drivers] / <?php / define\( / \$db_
- check_rce: uid=\d+\( / Volume Serial Number / NT AUTHORITY\\SYSTEM / /usr/bin/
- check_auth_bypass: admin 指示词在恶意响应且不在 baseline; base 302→resp 200
- check_upload: "success":true / upload.*success / 可执行扩展 URL

FatigueMonitor (Anti-Laziness): 最近 5 次调用全同 → pivot; 最近 10 次 0 发现 → pivot; 每 30 次周期 pivot。

## 3. Anti-Hallucination — 证据分级 (anti_hallucination.py) ⭐⭐⭐

4 级: VERIFIED → LIKELY → INFERRED → AI_ANALYSIS。哲学: 不拦功能, 只标等级。

**凭据登录判定算法 (最有价值):**
```python
success_signs = ["logout","dashboard","welcome","/로그아웃","마이페이지"]
fail_signs    = ["incorrect","invalid","틀렸","아이디 또는 비밀번호"]
# 泛用 session cookie 排除集 — 有 cookie ≠ 登录成功 (ASP 误判防护):
_GENERIC_COOKIES = {"aspsessionid","phpsessid","jsessionid","cfid","cftoken"}
判定链: fail → INFERRED; success_text+(有效cookie或跳转) → VERIFIED;
       success 或 (cookie+跳转) → LIKELY; 基线长度差>200 → LIKELY
301/302 跳转且 Location 不含 login = 成功信号
```

HttpEvidence: curl_command 自动生成 + evidence_hash = sha256(url+status+body[:500])[:16]。

**接 hunter**: identity_import / 爆破验证的登录判定升级。

## 4. Execution Anchor — 执行锚定双 Layer (execution_anchor.py) ⭐⭐

```
Layer A SpeculationLanguageFilter: 推测语言(probably/might/seems/아마도/可能) × 技术安全声明同现 → BLOCK
Layer B UnexecutedClaimBlocker: exec_output 无执行证据(20+正则: [200/34610B]/STATUS: 200/curl .+https?://...)
         + 有技术主张 → BLOCK; 拦截 = 注入矫正指令 ("先 curl 执行再谈结果")
```

## 5. Phantom Guard — 幻影模式检测链 (phantom_guard.py) ⭐⭐

优先级: PHANTOM > SELF_LOOP > STALE_CACHE > ZERO_HTTP > TARGET_MISMATCH > SPA_DETECTED

- PhantomModeDetector: 三语 30+ 正则匹配"工具已禁用/模拟退出", 连续 2 次 → 强制恢复消息
- StaleCacheGuard: LLM 反复用上次 /tmp/*.txt 缓存 → 拦截
- ZeroHttpClaimGuard: 无 HTTP 证据却声称"发现漏洞" → 拦截
- TargetMismatchGuard: exec 中出现非目标域名 → 硬拦截
- SPA 假 200: 5+ 个相同大小 <!DOCTYPE html> 响应 → 判 SPA → 拦截"200 即漏洞"
- HardSessionRestarter: 连续 3 次阻断 → 会话清空重来

## 6. Code Guard — AST 无限循环预检 (code_guard.py) ⭐

LLM 生成代码执行前 AST 静态检查 4 模式:
```
A: while True/1/not False 无退出 → 拦截
B: itertools.cycle/count/repeat 无退出 → 拦截
C: range(N) N ≥ 10^8 → 拦截 (含 10**N 常量折叠)
D: 递归自调用无 base case → 拦截
```

## 7. Authorization — 只读 SQL 自动降级 (authorization.py) ⭐

- FORBIDDEN_SQL_PATTERNS: INSERT/UPDATE/DELETE/DROP/TRUNCATE/CREATE/ALTER/GRANT/REVOKE
- make_readonly_sql(): 按 ; 分割剔除危险语句重拼 — 比硬拦截更实用
- TargetScope: 8 allow_* + 4 deny_* (sql_write/data_modify/account_create/destructive)

## 8. Rollback — 快照回滚 (rollback.py) ⭐

每次 agent loop 前深拷贝快照 → snap_{ts}.json; undo(N) 恢复 N 步前并截断之后; 上限 20。

## 9. Session Parser — 域隔离过滤 (session_parser.py) ⭐⭐

三语正则解析 bingo 会话 markdown → target_memory。
域隔离: 剥离 www\d*|m|mobile|admin|cms. 前缀后对比根域, 其他域 URL 剔除 — 防跨目标记忆污染。
**接 hunter**: TargetMemory/evidence 的跨 case 隔离。

## 10. Target Memory — 长度差证据 (target_memory.py) ⭐⭐

按域名分文件 JSON。**size_normal vs size_injected** (响应长度差证据) 字段 — hunter finding evidence 可扩展。
三语 context 注入模板。

## 汇总: 接 hunter 优先级

| 优先级 | 内容 | 接入点 |
|---|---|---|
| ⭐⭐⭐ | 5 信号 IP 封禁判定 | broker_state SOFT_BAN 第二意见 + 指纹轮换触发 |
| ⭐⭐⭐ | P1-P5 置信度加权验证 | 补 hunter 判定 (现只有分类无数值评分) |
| ⭐⭐⭐ | 凭据判定算法 (cookie 排除集) | identity_import / 登录验证 |
| ⭐⭐ | 执行锚定双 Layer | 零幻觉治理 |
| ⭐⭐ | Phantom Guard 链 | 防 LLM 幻影模式 |
| ⭐⭐ | 域隔离过滤 | TargetMemory 防污染 |
| ⭐ | 只读 SQL 降级 | 授权层 |
| ⭐ | AST 循环预检 | 代码执行安全 |
