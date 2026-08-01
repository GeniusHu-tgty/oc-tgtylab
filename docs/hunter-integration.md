# Hunter Integration

[Hunter](https://github.com/GeniusHu-tgty/Hunter) is an independent penetration-testing framework. It is integrated as a git submodule under `mcp/hunter/` and exposed through the `hunter_tools` MCP server (179 tools).

## What it provides

- Recon: `hunter_fast_recon` `hunter_recon` `hunter_subdomain` `hunter_port_scan` `hunter_tech_detect` `hunter_dir_enum`
- Auto vulnerability scan: `hunter_auto_sqli` `hunter_auto_xss` `hunter_auto_ssrf` `hunter_auto_ssti` `hunter_auto_xxe` `hunter_auto_cmd` `hunter_auto_idor` `hunter_auto_jwt` `hunter_auto_race` ...
- RequestBroker: all HTTP egress via `hunter_stealth_request` — WAF/captcha/rate-limit classified, never false findings
- Evidence loop: `hunter_experiment_run` → `hunter_evidence_register` → `hunter_finding_promote`
- Workflow: `hunter_workflow_create` / `hunter_auto_pentest` (seven-stage orchestrator)
- Reverse lab merge: 105 `re_*` tools merged from `mcp/reverse-lab-tools/` (PE/Android/crypto/rules)

## Update

```bash
git submodule update --init --recursive
cd mcp/hunter && git fetch origin && git checkout origin/main && cd ../..
```

## Verify

```bash
./scripts/healthcheck.sh
```
