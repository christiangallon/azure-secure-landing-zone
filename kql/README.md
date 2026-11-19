# KQL detections

These files are the single source of truth for the alert rules: `modules/monitoring`
loads them with `file()` so the query in the repo is exactly what runs in Azure Monitor.
You can also paste them into **Log Analytics > Logs** to hunt manually.

| File | Detection | Table | Severity |
|------|-----------|-------|----------|
| `failed_signins_same_ip.kql` | 5+ failed sign-ins from one IP in 10 min | SigninLogs | 1 (Error) |
| `pim_admin_role_activation.kql` | Admin role activated via PIM | AuditLogs | 2 (Warning) |
| `storage_access_public_ip.kql` | Storage request from a public IP | StorageBlobLogs | 1 (Error) |

Note: `SigninLogs` and `AuditLogs` only exist after the Entra ID diagnostic setting has
streamed data (Entra ID P1/P2 required). The alert rules set `skip_query_validation = true`
so they can be created before the tables exist.
