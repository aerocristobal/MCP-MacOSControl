# Audit Log Operations (STORY-024)

This document is for operators running MCP-MacOSControl in a regulated or
production-adjacent environment. It covers where audit records live, how
they're rotated, how to verify chain integrity, and what to do when something
goes wrong.

If you're a developer hacking on the audit code, also read
[`SECURITY.md`](SECURITY.md) §4.1, §4.4, and §7.

---

## 1. What the audit log captures

Every invocation of `run_applescript` and `click_menu_item` produces an
`AuditRecord` containing:

| Field | Description |
|---|---|
| `record_id` | UUID v4, unique per record |
| `timestamp_iso8601` | UTC, ms precision |
| `event_type` | `applescript_execute`, `menu_click`, `menu_alternatives_lookup`, `administrative_force_rotate_unacked`, `chain_verification_failure` |
| `script_sha256` | SHA-256 of the AppleScript source — **never the verbatim source** (STORY-024 §9 Q7) |
| `target_apps_extracted` | Apps named in `tell application "X"` clauses |
| `filter_disposition` | `allowed`, `rejected_security`, `rejected_permission`, `not_applicable` |
| `execution_outcome` | `success`, `script_error`, `timeout`, `io_error`, `not_executed`, `administrative` |
| `prev_hash` | SHA-256 of the prior record's `record_hash`; first record's is the per-install genesis |
| `record_hash` | SHA-256 of this record's canonical JSON (excluding `record_hash` + delivery annotations) |
| `delivery_status` | `pending`, `acknowledged`, `failed` |
| `remote_ack_timestamp` | ISO8601 of the remote sink's ack; `null` until acknowledged |
| `host_identifier` | POSIX `gethostname()` of the server's host |
| `server_version` | Server binary version |
| `audit_schema_version` | Currently `1` |
| `duration_ms` | Execution duration (0 for filter-rejected / permission-denied records) |
| `rejection_reason` *(optional)* | Filter rule name when `filter_disposition=rejected_security` |
| `denied_app` *(optional)* | App name when `filter_disposition=rejected_permission` |
| `script_error_code` *(optional)* | AppleScript exit code when `execution_outcome=script_error` |

The script SOURCE is intentionally **not** recorded — see
[`SECURITY.md`](SECURITY.md) §4.2.

---

## 2. Where records live

Default location:

```
~/Library/Logs/com.mcp.macos-control/audit/
├── audit-YYYY-MM-DD.jsonl     # active records (one line per record)
├── ack-YYYY-MM-DD.jsonl       # delivery ack ledger (one line per ack)
└── archive/                   # rotated records (older than retention window)
    └── audit-YYYY-MM-DD.jsonl
    └── ack-YYYY-MM-DD.jsonl
```

Override with `MCP_MACOS_CONTROL_AUDIT_DIR=/some/other/path`.

Files are **append-only** during normal operation. The only place the
server rewrites an audit file is the retention sweep (which moves records
out of an active file to archive). The retention sweeper preserves record
content byte-for-byte — it never modifies a record.

---

## 3. Environment variables

| Variable | Default | Description |
|---|---|---|
| `MCP_MACOS_CONTROL_AUDIT_DIR` | `~/Library/Logs/com.mcp.macos-control/audit/` | Log directory |
| `MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS` | `365` | Retention window in days |
| `MCP_MACOS_CONTROL_AUDIT_REMOTE` | `oslog` | Remote sink: `oslog`, `http`, or `syslog` |
| `MCP_MACOS_CONTROL_AUDIT_REMOTE_URL` | — | Required when `REMOTE=http`. Must be `http(s)://...` |
| `MCP_MACOS_CONTROL_AUDIT_ACK_TIMEOUT_MS` | `5000` | Per-record ack timeout for the remote sink |
| `MCP_MACOS_CONTROL_AUDIT_ADMIN_ENABLED` | `false` | Set `true` to expose `force_rotate_unacked` |
| `MCP_MACOS_CONTROL_AUDIT_HOST_IDENTIFIER` | `gethostname()` | Override host identifier (testing) |
| `MCP_MACOS_CONTROL_AUDIT_INSTALL_UUID` | persisted file | Override install UUID (testing) |

The server refuses to start when config is internally inconsistent — e.g.
`REMOTE=http` with no `REMOTE_URL`, retention < 1 day, or ack timeout
< 100ms. The error code is `audit_config_invalid` and the message names
the missing/invalid variable.

---

## 4. Remote sinks

### OSLog (default)

Records ship to the unified log under subsystem
`com.mcp.macos-control.audit`, category `audit`. View with:

```
log show --predicate 'subsystem == "com.mcp.macos-control.audit"' --last 1h
log stream --predicate 'subsystem == "com.mcp.macos-control.audit"'
```

Console.app's File menu can also point at the unified log live.

### HTTP

POSTs canonical JSON of each record to `MCP_MACOS_CONTROL_AUDIT_REMOTE_URL`
with `Content-Type: application/json`. A 2xx response counts as an ack.
Timeouts and non-2xx responses are recorded as `delivery_status=pending`
and the background retry loop tries again later.

### Syslog

Same canonical JSON as HTTP, written via the `os.Logger` family with
subsystem `com.mcp.macos-control.audit`, category `syslog`. Use when
your collector pipeline scrapes the syslog category but not the audit
category.

---

## 5. Chain integrity

Every record carries `prev_hash` = SHA-256 of the prior record's
`record_hash`. The first record's `prev_hash` is a deterministic genesis
derived from `host_identifier` + per-install `install_uuid`. A verifier
walks the chain and reports the first break.

Verification runs:
- **On server start** — a failure logs SECURITY-CRITICAL but the server
  still starts (availability over an unverifiable trail). Investigate
  immediately.
- **On every retention sweep** — across the combined active + archive
  set after records are moved.
- **On operator request** via the `verify_audit_chain` MCP tool.

### Incident response when verification fails

1. **Capture the current state.** Make a read-only copy of the audit
   directory and the OSLog buffer (`log collect --output ./audit-incident.logarchive`).
2. **Don't restart the server.** A restart starts a new chain segment
   from whatever's on disk; preserve the failed-verification report
   from the SECURITY-CRITICAL log line.
3. **Identify the break point.** `first_break_at` in the report names
   the first record whose `record_hash` or `prev_hash` didn't recompute.
   The break upper bound is the most recent record.
4. **Cross-check against the remote sink.** If OSLog/HTTP/syslog has
   the original records, you can reconstruct the missing/altered ones
   from the off-host copy.
5. **Treat as a security incident.** A chain break with no innocent
   explanation (manual file edit, partial-write crash) is forensic
   evidence of tampering.

---

## 6. Retention sweep

Daily sweep moves records older than `MCP_MACOS_CONTROL_AUDIT_RETENTION_DAYS`
from active to archive — **only if** `delivery_status=acknowledged`.
Records with `delivery_status=pending` are held in active until they
either get acknowledged or the operator runs `force_rotate_unacked`.

### Why pending records are never rotated automatically

A silent log loss during a destination outage is the worst possible audit
failure mode. An archive that quietly drops records during an outage
removes the operator's signal that the outage happened. Better to grow
the active set and surface the outage than to forget records ever existed.

### `force_rotate_unacked` (admin tool)

Set `MCP_MACOS_CONTROL_AUDIT_ADMIN_ENABLED=true` to expose this tool.
Invoking it via the MCP `force_rotate_unacked` tool:

1. Writes an `administrative_force_rotate_unacked` audit record FIRST,
   so the rotation itself appears in the trail.
2. Moves every old, unacknowledged record to archive.
3. Re-verifies the chain across the combined set and returns
   `records_moved`.

**The records that move out are functionally lost** — there's no
guarantee they ever made it off-host. Document the operator action and
the outage that led to it before running this tool.

---

## 7. Reading and parsing records

JSON Lines is parseable by every log tool. Quick recipes:

```bash
# Pretty-print today's records
jq . ~/Library/Logs/com.mcp.macos-control/audit/audit-$(date -u +%F).jsonl

# Find all records that hit the security filter
jq 'select(.filter_disposition == "rejected_security")' \
   ~/Library/Logs/com.mcp.macos-control/audit/audit-*.jsonl

# Count records by event_type
jq -r .event_type ~/Library/Logs/com.mcp.macos-control/audit/audit-*.jsonl | sort | uniq -c

# Find still-pending records (delivery_status reflects latest ack)
jq 'select(.delivery_status == "pending")' \
   ~/Library/Logs/com.mcp.macos-control/audit/audit-*.jsonl
```

---

## 8. HTTP sink ingestion format

If you're building a SIEM/log-collector receiver for the HTTP sink, the
POST body is exactly the same canonical JSON Lines record written to
disk — one record per POST. Example:

```json
{
  "audit_schema_version": 1,
  "delivery_status": "pending",
  "duration_ms": 42,
  "event_type": "applescript_execute",
  "execution_outcome": "success",
  "filter_disposition": "allowed",
  "host_identifier": "alice-mbp",
  "prev_hash": "be3a3b...e8",
  "record_hash": "8a1f...0c",
  "record_id": "0F1B5D27-...-3E4A",
  "remote_ack_timestamp": null,
  "script_sha256": "2cf24dba...9824",
  "server_version": "1.0.0",
  "target_apps_extracted": ["Finder"],
  "timestamp_iso8601": "2026-05-20T12:34:56.789Z"
}
```

Acknowledge with HTTP 2xx. The recorder treats anything else as
"pending" and retries.
