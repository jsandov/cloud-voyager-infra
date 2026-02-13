# MCP Server Infrastructure — Production Readiness Review

**Date:** 2026-02-13
**Scope:** `mcp_server`, `mcp_token_vending_machine`, `mcp_tenant_metering` patterns + all supporting modules
**Verdict:** NOT READY for production — 11 Critical findings, 27 High findings require remediation

---

## Executive Summary

The MCP server infrastructure pattern demonstrates strong foundational security with FedRAMP-aligned controls (KMS encryption, scoped IAM, VPC placement, Cognito JWT auth). However, five review domains identified **11 Critical** and **27 High** severity findings that block production deployment.

The three highest-impact gaps are:

1. **No WAF protection** — HTTP API v2 cannot use WAFv2 directly, and no CloudFront+WAF workaround is provided (FedRAMP SC-7 gap)
2. **Missing VPC Interface Endpoints** — Lambda in VPC cannot reach STS, KMS, CloudWatch, or ECR without NAT Gateway, which defaults to disabled
3. **Alerting pipeline is inert** — SNS topics have zero subscriptions; all alarms fire into the void

| Domain | Critical | High | Medium | Low | Total |
|--------|----------|------|--------|-----|-------|
| Security | 3 | 6 | 8 | 6 | 23 |
| Resilience | 4 | 9 | 8 | 5 | 26 |
| Observability | 4 | 8 | 9 | 5 | 26 |
| Cost & Performance | 2 | 5 | 9 | 7 | 23 |
| Networking & API | 3 | 7 | 8 | 7 | 25 |
| **Total** | **16** | **35** | **42** | **30** | **123** |

> Note: Some findings overlap across domains (e.g., CORS wildcard, missing VPC endpoints). Deduplicated unique actionable items: ~65.

---

## Critical Findings (Must Fix Before Production)

### SEC-CRIT-1: CORS Wildcard Origin Default

- **File:** `infra/example_infra_patterns/mcp_server/variables.tf:169`
- `cors_allowed_origins` defaults to `["*"]`, permitting any origin to make cross-origin requests to the authenticated MCP API

### SEC-CRIT-2: Authentication Disableable in Production

- **File:** `infra/example_infra_patterns/mcp_server/variables.tf:116`
- `enable_auth` can be set to `false` even when `environment = "prod"`, removing all API authentication

### SEC-CRIT-3: No `versions.tf` — Provider Versions Unpinned

- **Files:** All modules and example patterns
- No `versions.tf` exists anywhere; `.terraform.lock.hcl` is gitignored — supply chain risk

### RES-CRIT-1: No Dead Letter Queue on MCP Server Lambda

- **File:** `infra/example_infra_patterns/mcp_server/main.tf:238-276`
- Failed async invocations are silently dropped with no recovery mechanism

### RES-CRIT-2: Single NAT Gateway Default (No HA)

- **File:** `infra/modules/vpc/variables.tf:57-61`
- Single NAT failure takes down all private subnet connectivity across all AZs

### RES-CRIT-3: No DynamoDB Throttle Alarms

- **Files:** `mcp_server/main.tf:477-522`, `mcp_tenant_metering/main.tf:36-76`
- On-demand tables can throttle under burst; no alarm detects this

### RES-CRIT-4: MCP Server API Gateway Missing `prevent_destroy`

- **File:** `mcp_server/main.tf:282-295`
- Accidental `tofu destroy` deletes the API Gateway with no protection

### OBS-CRIT-1: Access Logs Missing `tenant_id`

- **File:** `mcp_server/main.tf:304-314`
- Log format omits tenant identifier despite architecture docs claiming it exists

### OBS-CRIT-2: No CloudWatch Dashboards

- Zero `aws_cloudwatch_dashboard` resources exist anywhere in the codebase

### OBS-CRIT-3: Tenant Metering Metrics Are Aggregate-Only

- **File:** `mcp_tenant_metering/main.tf:120-148`
- Metric filters count all requests, not per-tenant — defeats the module's purpose

### OBS-CRIT-4: SNS Topics Have Zero Subscriptions

- All SNS alarm topics are created but no `aws_sns_topic_subscription` exists — alarms are a no-op

### NET-CRIT-1: No CloudFront + WAF Module

- WAFv2 unsupported on HTTP API v2 is documented, but no workaround module exists (FedRAMP SC-7)

### NET-CRIT-2: Missing Interface VPC Endpoints

- **File:** `infra/modules/vpc_endpoints/main.tf`
- Only S3 and DynamoDB Gateway endpoints exist; STS, KMS, Logs, ECR, X-Ray are missing

### COST-CRIT-1: 30-Second Hard Timeout

- HTTP API v2 immutable limit; cold starts + STS consume 10s, leaving 20s for execution

### COST-CRIT-2: NAT Gateway Costs Without VPC Endpoints

- ECR image pulls through NAT: ~$270/month at 1000 cold starts/day

---

## High Findings (Fix Before GA)

### Security

| ID | Finding | File |
|----|---------|------|
| SEC-H-1 | Permission boundary `Resource = ["*"]` with self-referencing tag condition | `mcp_token_vending_machine/main.tf:77` |
| SEC-H-2 | KMS root policy uses `kms:*` wildcard | `modules/kms/main.tf:36-47` |
| SEC-H-3 | Tenant template role accepts any `tenant-id` value via wildcard | `mcp_token_vending_machine/main.tf:144-148` |
| SEC-H-4 | Lambda module KMS key defaults to null | `modules/lambda/variables.tf:85-89` |
| SEC-H-5 | Function URL allows `auth_type = "NONE"` in production | `modules/lambda/main.tf:154-159` |
| SEC-H-6 | Security groups default `restrict_egress = false` | `modules/security_groups/variables.tf:73-77` |

### Resilience

| ID | Finding | File |
|----|---------|------|
| RES-H-1 | No provisioned concurrency — 5-15s container cold starts | `mcp_server/variables.tf:66-70` |
| RES-H-2 | No `deletion_protection_enabled` on DynamoDB tables | `mcp_server/main.tf:477-522` |
| RES-H-3 | No Lambda alias/version pinning — $LATEST only | `mcp_server/main.tf:238-276` |
| RES-H-4 | No `prevent_destroy` on DynamoDB tables | `mcp_server/main.tf:477-522` |
| RES-H-5 | No ConcurrentExecutions alarm | Lambda module |
| RES-H-6 | ECR has no cross-region replication | `mcp_server/main.tf:418-434` |
| RES-H-7 | CloudWatch log groups lack `prevent_destroy` | All log group resources |
| RES-H-8 | `auto_deploy = true` with no canary/rollback | `mcp_server/main.tf:297-333` |
| RES-H-9 | SNS alarm topics have zero subscribers | All SNS topic resources |

### Observability

| ID | Finding | File |
|----|---------|------|
| OBS-H-1 | API Gateway log format missing security fields | `modules/api_gateway/main.tf:46-56` |
| OBS-H-2 | No Lambda ConcurrentExecutions alarm | Lambda module |
| OBS-H-3 | No DynamoDB ThrottledRequests alarms | DynamoDB resources |
| OBS-H-4 | No API 4xx alarm in MCP server pattern | `mcp_server/main.tf` |
| OBS-H-5 | HTTP API v2 does not support X-Ray at stage level | Architecture limitation |
| OBS-H-6 | No Lambda memory utilization monitoring | Lambda module |
| OBS-H-7 | Architecture docs claim per-tenant metrics — not implemented | `mcp-tenant-metering.md` |
| OBS-H-8 | No alarm routing tiers (P1/P2/P3) | All alarm resources |

### Networking & API

| ID | Finding | File |
|----|---------|------|
| NET-H-1 | `auto_deploy = true` risks instant production changes | `modules/api_gateway/variables.tf:40-44` |
| NET-H-2 | No per-route throttle differentiation (SSE vs RPC) | `mcp_server/main.tf:317-319` |
| NET-H-3 | NAT Gateway disabled by default in networking example | `networking/variables.tf:32` |
| NET-H-4 | No custom domain support in API Gateway module | `modules/api_gateway/main.tf` |
| NET-H-5 | Lambda permission `source_arn` uses wildcard method | `modules/api_gateway_routes/main.tf:66` |
| NET-H-6 | No multi-region failover architecture | Architecture-wide |
| NET-H-7 | Stale docs claim LeadingKeys not enforced (it is) | `mcp-server.md:213` |

### Cost & Performance

| ID | Finding | File |
|----|---------|------|
| COST-H-1 | No ARM64/Graviton architecture support | `modules/lambda/variables.tf` |
| COST-H-2 | No provisioned concurrency option | `modules/lambda/variables.tf` |
| COST-H-3 | Missing VPC endpoints cost $270/month in NAT charges | `modules/vpc_endpoints/main.tf` |
| COST-H-4 | Missing tenant cost allocation tags | All `main.tf` files |
| COST-H-5 | STS AssumeRole latency (200ms) with no VPC endpoint | `mcp_token_vending_machine/main.tf` |

---

## Positive Findings (Already Production-Grade)

The following controls are well-implemented and should be preserved:

1. KMS customer-managed key encryption on all data stores
2. KMS key rotation enabled by default
3. DynamoDB PITR and TTL on all tables
4. `dynamodb:LeadingKeys` IAM condition for tenant isolation
5. VPC placement with default SG/NACL/RT hardened to deny-all
6. VPC flow logs enabled by default
7. X-Ray tracing enabled by default
8. ECR immutable tags and scan-on-push
9. Permission boundaries on tenant roles with IAM escalation deny
10. Comprehensive input validation blocks on variables
11. Route prefix enforcement preventing cross-team collisions
12. Cognito deletion protection in production
13. `prevent_destroy` on shared API Gateway
14. Per-route throttle override support
15. Container-only Lambda deployment (security best practice for MCP)

---

## Remediation Priority

### Phase 1: Production Blockers (Immediate)

| Priority | Finding | Effort |
|----------|---------|--------|
| P0 | Add `versions.tf` to all modules (SEC-CRIT-3) | S |
| P0 | Remove CORS `["*"]` default (SEC-CRIT-1) | S |
| P0 | Add SNS topic subscriptions (OBS-CRIT-4) | S |
| P0 | Add `prevent_destroy` to DynamoDB, API GW, ECR, logs (RES-CRIT-4, RES-H-4, RES-H-7) | S |
| P0 | Fix `statistic = "p99"` bug in cloudwatch_alarms module | S |
| P0 | Block auth disable in prod (SEC-CRIT-2) | S |
| P0 | Add `tenant_id` to access log format (OBS-CRIT-1) | S |

### Phase 2: Security & Resilience (Sprint 1)

| Priority | Finding | Effort |
|----------|---------|--------|
| P1 | Build CloudFront + WAF module (NET-CRIT-1) | L |
| P1 | Add interface VPC endpoints (NET-CRIT-2) | M |
| P1 | Add DLQ to MCP Lambda (RES-CRIT-1) | S |
| P1 | Add DynamoDB throttle alarms (RES-CRIT-3) | S |
| P1 | Fix permission boundary resource scoping (SEC-H-1) | M |
| P1 | Add Lambda alias/version for safe deployments (RES-H-3) | M |
| P1 | Per-route throttle defaults for SSE vs RPC (NET-H-2) | S |

### Phase 3: Observability & Cost (Sprint 2)

| Priority | Finding | Effort |
|----------|---------|--------|
| P2 | Create CloudWatch dashboards (OBS-CRIT-2) | M |
| P2 | Implement per-tenant metric dimensions (OBS-CRIT-3) | M |
| P2 | Add ARM64/Graviton support (COST-H-1) | S |
| P2 | Add provisioned concurrency option (COST-H-2) | S |
| P2 | Add custom domain support (NET-H-4) | M |
| P2 | Add alarm escalation tiers (OBS-H-8) | M |
| P2 | Add cost allocation tags (COST-H-4) | S |

### Phase 4: Hardening (Sprint 3+)

| Priority | Finding | Effort |
|----------|---------|--------|
| P3 | Multi-region DR architecture (NET-H-6) | XL |
| P3 | IPv6 dual-stack support | M |
| P3 | mTLS for machine-to-machine auth | M |
| P3 | Canary deployment support | M |

---

## Estimated Monthly Cost Profile

For a single MCP server at 1M requests/month in a 3-AZ VPC:

| Component | Current | Optimized |
|-----------|---------|-----------|
| Lambda (512 MB, x86) | $43.75 | $28.00 (ARM64) |
| API Gateway HTTP API | $1.00 | $1.00 |
| NAT Gateway (single) | $32.40 | $32.40 |
| VPC Endpoints (new) | $0 | $50.40 |
| DynamoDB | $5.00 | $3.50 |
| KMS | $16.00 | $6.00 |
| CloudWatch | $8.50 | $5.00 |
| X-Ray | $4.50 | $0.25 (sampled) |
| Cognito | $0 | $0 |
| **Total** | **~$111** | **~$127** |

VPC endpoint investment eliminates NAT data processing ($270/month at scale) and reduces latency by 100-200ms per request.

---

## FedRAMP Control Gap Summary

| Control | ID | Status | Gap |
|---------|-----|--------|-----|
| Boundary Protection | SC-7 | PARTIAL | No WAF (CloudFront+WAF module needed) |
| Audit Logging | AU-2/3 | PARTIAL | Missing `tenant_id` in logs; 30-day retention < 90-day requirement |
| Monitoring | SI-4 | PARTIAL | Alarms exist but SNS has no subscribers |
| Incident Response | IR-4 | FAILED | SNS no-op; no escalation tiers |
| Provider Version Control | CM-2 | FAILED | No `versions.tf`; lock file gitignored |
| Alternate Processing | CP-7 | MISSING | No multi-region architecture |
