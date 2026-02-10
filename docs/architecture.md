# Infrastructure Architecture

This diagram represents the AWS infrastructure provisioned by the modules in `infra/modules/`.

## VPC Network Topology

```mermaid
flowchart TB
    Internet(["Internet"])

    subgraph AWS["AWS Region (var.aws_region)"]
        IGW["Internet Gateway<br/><i>aws_internet_gateway.this</i>"]

        subgraph VPC["VPC — var.cidr_block (default: 10.0.0.0/16)<br/><i>aws_vpc.this</i><br/>DNS Support ✓ | DNS Hostnames ✓"]

            subgraph Defaults["Default Resources (deny-all)"]
                DefSG["Default Security Group<br/><i>aws_default_security_group.this</i><br/>No ingress | No egress"]
                DefNACL["Default Network ACL<br/><i>aws_default_network_acl.this</i><br/>No rules"]
                DefRT["Default Route Table<br/><i>aws_default_route_table.this</i><br/>No routes"]
            end

            subgraph PublicRT["Public Route Table<br/><i>aws_route_table.public</i><br/>0.0.0.0/0 → IGW"]
            end

            subgraph PrivateRT["Private Route Table<br/><i>aws_route_table.private</i><br/>0.0.0.0/0 → NAT (if enabled)"]
            end

            subgraph AZ1["Availability Zone 1"]
                PubSub1["Public Subnet<br/>10.0.1.0/24<br/><i>map_public_ip = true</i>"]
                PrivSub1["Private Subnet<br/>10.0.11.0/24"]
            end

            subgraph AZ2["Availability Zone 2"]
                PubSub2["Public Subnet<br/>10.0.2.0/24<br/><i>map_public_ip = true</i>"]
                PrivSub2["Private Subnet<br/>10.0.12.0/24"]
            end

            subgraph AZ3["Availability Zone 3"]
                PubSub3["Public Subnet<br/>10.0.3.0/24<br/><i>map_public_ip = true</i>"]
                PrivSub3["Private Subnet<br/>10.0.13.0/24"]
            end

            NAT["NAT Gateway<br/><i>aws_nat_gateway.this</i><br/>(conditional: var.enable_nat_gateway)<br/>Placed in Public Subnet AZ1"]
            EIP["Elastic IP<br/><i>aws_eip.nat</i>"]
        end

        subgraph FlowLogs["VPC Flow Logs (conditional: var.enable_flow_logs)"]
            FL["Flow Log<br/><i>aws_flow_log.this</i><br/>Traffic: ALL"]
            CWLog["CloudWatch Log Group<br/><i>/aws/vpc/$env-flow-logs</i><br/>Retention: var.flow_log_retention_days"]
            FLRole["IAM Role<br/><i>$env-vpc-flow-logs-role</i>"]
        end
    end

    Internet <-->|"inbound/outbound"| IGW
    IGW --- PublicRT

    PublicRT --- PubSub1
    PublicRT --- PubSub2
    PublicRT --- PubSub3

    EIP --- NAT
    NAT -.->|"placed in"| PubSub1
    NAT --- PrivateRT

    PrivateRT --- PrivSub1
    PrivateRT --- PrivSub2
    PrivateRT --- PrivSub3

    VPC -.->|"logs traffic"| FL
    FL --> CWLog
    FL -.->|"assumes"| FLRole
```

## Security Groups (infra/modules/security_groups)

```mermaid
flowchart LR
    Internet(["Internet"]) -->|"80, 443"| WebSG
    BastionCIDRs(["Allowed CIDRs"]) -->|"22"| BastionSG

    subgraph SGs["Security Groups"]
        WebSG["Web Tier SG<br/>Ingress: 80, 443<br/>from 0.0.0.0/0"]
        AppSG["App Tier SG<br/>Ingress: var.app_port<br/>from Web SG only"]
        DBSG["DB Tier SG<br/>Ingress: var.db_port<br/>from App SG only"]
        BastionSG["Bastion SG<br/>Ingress: 22<br/>from allowed CIDRs<br/>(off by default)"]
    end

    WebSG -->|"var.app_port"| AppSG
    AppSG -->|"var.db_port"| DBSG
    BastionSG -.->|"access"| AppSG
```

## Resource Summary

### VPC Module

| Resource                              | Count        | Conditional                |
| ------------------------------------- | ------------ | -------------------------- |
| `aws_vpc`                             | 1            | No                         |
| `aws_default_security_group`          | 1            | No                         |
| `aws_default_network_acl`            | 1            | No                         |
| `aws_default_route_table`            | 1            | No                         |
| `aws_internet_gateway`                | 1            | No                         |
| `aws_subnet` (public)                 | 3 (per AZ)   | No                         |
| `aws_subnet` (private)                | 3 (per AZ)   | No                         |
| `aws_route_table` (public)            | 1            | No                         |
| `aws_route_table` (private)           | 1            | No                         |
| `aws_route` (public → IGW)           | 1            | No                         |
| `aws_route` (private → NAT)          | 1            | `var.enable_nat_gateway`   |
| `aws_route_table_association` (public) | 3           | No                         |
| `aws_route_table_association` (private)| 3           | No                         |
| `aws_nat_gateway`                     | 1            | `var.enable_nat_gateway`   |
| `aws_eip`                             | 1            | `var.enable_nat_gateway`   |
| `aws_flow_log`                        | 1            | `var.enable_flow_logs`     |
| `aws_cloudwatch_log_group`            | 1            | `var.enable_flow_logs`     |
| `aws_iam_role` (flow logs)            | 1            | `var.enable_flow_logs`     |
| `aws_iam_role_policy` (flow logs)     | 1            | `var.enable_flow_logs`     |

### Security Groups Module

| Resource                     | Count | Conditional            |
| ---------------------------- | ----- | ---------------------- |
| `aws_security_group` (web)   | 1     | `var.create_web_sg`    |
| `aws_security_group` (app)   | 1     | `var.create_app_sg`    |
| `aws_security_group` (db)    | 1     | `var.create_db_sg`     |
| `aws_security_group` (bastion)| 1    | `var.create_bastion_sg`|
| `aws_security_group_rule`    | 3 per SG | Per SG toggle       |

## Key Design Decisions

- **Default resources managed with deny-all** — prevents use of AWS default SG/NACL/RT which have permissive rules
- **Single NAT Gateway** in AZ1 for cost efficiency — suitable for dev/staging. For production HA, deploy one NAT per AZ.
- **Subnet CIDRs** computed dynamically via `cidrsubnet()` — public subnets use offsets 1-3, private subnets use offsets 11-13.
- **3 AZs** selected automatically from available zones in the region via `data.aws_availability_zones`.
- **NAT Gateway** is conditional (`var.enable_nat_gateway`, default `false`) to avoid cost when not needed.
- **VPC Flow Logs** enabled by default (`var.enable_flow_logs`, default `true`) for security monitoring.
- **Layered security groups** — each tier only accepts traffic from the tier above it (Internet → Web → App → DB).
- **Bastion off by default** — must explicitly enable and provide allowed CIDRs.
- **Default tags** (`ManagedBy = "opentofu"`, `Environment`) applied at both provider level and resource level.
