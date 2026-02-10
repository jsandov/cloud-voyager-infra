# Lambda Architecture

```mermaid
flowchart TB
    subgraph DeploymentSource["Deployment Source"]
        Zip["Local Zip"]
        S3["S3 Bucket"]
        ECR["ECR Container Image"]
    end

    subgraph IAM["IAM"]
        Role["Execution Role<br/>Least-privilege"]
        BasicPolicy["AWSLambdaBasicExecutionRole"]
        VPCPolicy["AWSLambdaVPCAccessExecutionRole<br/>(conditional)"]
        XRayPolicy["AWSXRayDaemonWriteAccess<br/>(conditional)"]
    end

    subgraph VPC["VPC (optional)"]
        subgraph PrivateSubnets["Private Subnets"]
            Lambda["Lambda Function<br/>Runtime: var.runtime<br/>Memory: var.memory_size<br/>Timeout: var.timeout"]
        end
        SGs["Security Groups<br/>var.vpc_security_group_ids"]
    end

    subgraph Encryption["Encryption"]
        KMSEnv["KMS Key<br/>Environment Variables"]
        KMSLogs["KMS Key<br/>CloudWatch Logs"]
    end

    subgraph Observability["Observability"]
        CWLogs["CloudWatch Log Group<br/>Retention: var.log_retention_days"]
        XRay["X-Ray Tracing<br/>(default: Active)"]
    end

    DLQ["Dead Letter Queue<br/>SQS / SNS<br/>(optional)"]
    FuncURL["Function URL<br/>Auth: AWS_IAM / NONE<br/>(optional)"]

    BasicPolicy --> Role
    VPCPolicy -.-> Role
    XRayPolicy -.-> Role
    Role --> Lambda

    Zip -.-> Lambda
    S3 -.-> Lambda
    ECR -.-> Lambda

    SGs -.->|"controls traffic"| Lambda

    Lambda --> CWLogs
    Lambda -.-> XRay
    Lambda -.-> DLQ
    Lambda -.-> FuncURL

    KMSEnv -.->|"encrypts env vars"| Lambda
    KMSLogs -.->|"encrypts"| CWLogs
```

## FedRAMP Control Mapping

| Control | ID | Implementation |
| --- | --- | --- |
| Encryption in Transit | SC-8 | VPC deployment, TLS for function URLs |
| Encryption at Rest | SC-28 | KMS encryption for env vars and CloudWatch logs |
| Least Privilege | AC-6 | Scoped execution role, no wildcard IAM actions |
| Audit Events | AU-2 | CloudWatch log group with configurable retention |
| Monitoring | SI-4 | X-Ray tracing enabled by default |
| Boundary Protection | SC-7 | Optional VPC placement with security groups |

## Design Decisions

- **VPC placement optional** — not all Lambda functions need VPC access; VPC adds cold start latency
- **X-Ray tracing on by default** — provides distributed tracing for debugging and compliance
- **KMS encryption separated** — distinct keys for env vars vs logs allows independent key rotation
- **Dead letter queue optional** — for async invocations, prevents silent message loss
- **Function URL auth defaults to AWS_IAM** — prevents unauthenticated public access
- **Log group created before function** — explicit dependency ensures logs are captured from first invocation
- **Reserved concurrency configurable** — prevents runaway invocations from consuming account-wide limits
