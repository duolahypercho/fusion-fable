# Pinchpoint Fusion-Fable Integration

This branch preserves the live Pinchpoint implementation work that installs a Fusion-Fable-inspired profile on top of the existing Claude Max proxy and gateway stack.

## What changed

- Claude Max proxy no longer strips `tools` or `tool_choice` from `claude-fable-5` compressed Fusion-Fable requests.
- Proxy remaps `tool_choice` names alongside tool schemas and remaps Fusion-Fable tool-use responses back to original client names.
- Proxy streaming fallback now serializes Anthropic `tool_use` blocks instead of flattening them into text.
- Fusion-Fable proxy prompt can load the synced public Claude Fable source prompt from `config/fusion-fable-source-prompt.md` via `scripts/sync-fusion-fable-source.mjs`.
- Gateway advertises only the starter tool surface: `tool_search`, `recall`, and `remember`.
- Gateway preserves the full request/client tool catalog for `tool_search` and promotes discovered gateway or request tools for reruns.
- Gateway forwards Anthropic `tool_choice` through the Claude SDK path.
- Local Pinchpoint Agent `shell_exec` stream output is preserved and normalized as `stdout`/`stderr`.

## Live verification evidence

All tests were run against the live `pinchpoint` host on June 14, 2026.

- Gateway health: HTTP 200 from `http://127.0.0.1:3777/health`.
- Proxy health: HTTP 200 from Docker bridge `http://172.19.0.1:9340/health`.
- Source prompt sync: `fusion-fable-source-prompt.md` fetched from the public CL4R1T4S raw URL, 1,585 lines, 119,726 chars; proxy log confirmed load at 119,725 chars after trim.
- Direct proxy forced tool: `claude-fable-5` returned `stop_reason: "tool_use"`, tool `get_marker`, input marker `DIRECT_PROXY_TOOL_OK_20260614`.
- Direct proxy forced streaming tool: SSE contained `tool_use`, original tool name `get_marker`, `input_json_delta`, and marker `DIRECT_PROXY_STREAM_TOOL_OK_20260614`.
- Full gateway/local-machine E2E: `claude-fable-5` used `tool_search`, promoted `shell_exec`, routed to connected Mac agent `joshs-MacBook-Pro.local`, and returned exactly `FUSION_LOCAL_OK_20260614`.
- Proxy tests: `node --test test/cch.test.js test/server-config.test.js`, 14/14 passing.
- Gateway visible test: `node --test src/tools/tool-search-index.test.js`, passing.

## Patch files

The `patches/` directory contains unified diffs generated from live timestamped backups to the current live files. They are intended as a preservation and review bundle rather than a directly applicable upstream patch to this repository.

## Source prompt sync

The source sync script intentionally does not vendor the third-party prompt into this repository. It fetches the public prompt into a local runtime file and writes an attribution sidecar.
