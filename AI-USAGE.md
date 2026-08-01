# AI 使用指南

这是给 AI/Agent 的全局操作入口。任何任务先判断所属板块，再沿 kb、MCP 工具、reports 的链路推进。

## 任务路由

| 任务类型 | 工具入口 | 知识库 |
|---------|---------|--------|
| Web / Website / CVE / API | `hunter_*` 系列 | `kb/ctf-website/` |
| Android / APK / Frida | `re_android_*` | `kb/apk-reverse/` |
| PE / 逆向 / 恶意软件 | `re_triage_pe` / `re_ghidra_*` | `kb/pe-reverse/` |
| 密码学 / 协议 / 游戏安全 / 通用 | 全部 MCP | `kb/general/` |

## 默认工作流

1. **识别板块**：Web/Android/PE/通用；不确定时从 `kb/` 选择最接近的入口。
2. **查知识库**：`kb_router("<信号>")` → `kb_read_file`，获取技术文档。
3. **选工具**：按 AGENTS.md 工具优先级表选择 MCP 工具。
4. **执行**：直接调用 MCP 工具，不手动操作。
5. **落盘**：原始输出 → `exports/`，笔记 → `notes/`，报告 → `reports/`。
6. **可回放**：记录关键输入、输出路径、版本和时间。

## 跨板块联动

- **Web → CVE**：发现版本指纹后，联动 CVE 查找和利用链生成。
- **Android/PE → 加密分析**：发现加密/壳/混淆后，脚本复现放 `scripts/`，解包产物放 `samples/unpacked/`。
- **恶意样本 → IOC**：分析目标是行为、IOC、检测规则和复现证据。
- **漏洞 → 检测规则**：发现漏洞后自动生成 YARA/Sigma 检测规则。

## MCP 工具速查

```
# Web
hunter_fast_recon("<target>")                     # 快速侦察
hunter_stealth_request("GET", "<url>")            # 隐蔽请求（Broker 出口）
hunter_auto_sqli("<url>")                         # SQL 注入
run_ctf_tool("sqlmap", "-u <url> --batch")        # SQL 注入（CTF 工具）

# PE 逆向
re_triage_pe("<path>")                            # 一键初筛
re_ghidra_headless_analyze("<path>")              # Ghidra 深度分析
re_sample_full_workup("<path>")                   # 全量分析流水线
re_make_yara_stub("<path>")                       # YARA 规则

# Android
re_android_app_baseline("<package>")              # 应用基线
re_android_crypto_unpack_recipe("<package>")      # 解密/去壳
re_android_frida_run_script("<pkg>", "<script>")  # Frida hook

# 加密
re_solve_crypto_from_evidence("<json>")           # 从证据解加密
re_postprocess_frida_crypto_result("<json>")      # Frida 结果后处理
```
