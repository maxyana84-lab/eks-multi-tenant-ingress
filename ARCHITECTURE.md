# Architecture Decision Record: Multi-Tenant Ingress on Shared ALB

## Context

A SaaS platform needs to serve 3 isolated tenants (alpha, beta, gamma), each with
their own frontend and api service, behind subdomains (`<tenant>.saas.example.com`).
Requirements: TLS, WAF, access logging, independent health checks per tenant, and
failure isolation (one tenant's outage must not affect others).

## Decision: IngressGroup (shared ALB) vs. one Ingress per ALB

We used `alb.ingress.kubernetes.io/group.name` to merge 3 separate Ingress
resources (one per tenant namespace) into a **single physical ALB**, instead of
giving each tenant its own ALB.

### Why a shared ALB

- **Cost**: each ALB costs money per hour, regardless of traffic. Three ALBs for
  three tenants is 3x the fixed cost. A shared ALB scales to dozens of tenants
  without extra per-tenant infrastructure cost.
- **Operational simplicity**: one DNS record, one certificate, one WAF, one set
  of access logs to monitor, instead of duplicating all of that per tenant.
- **Still isolated where it matters**: each tenant's Ingress creates its own
  Target Groups (one per Service). Target Groups — not the ALB itself — are the
  unit of health checking and routing. So tenants share the "front door" (ALB,
  listener, TLS, WAF) but never share backend state.

### Trade-offs accepted

- All Ingress resources in the group must agree on ALB-level settings (TLS cert,
  WAF ARN, access-log bucket, listen ports) — these can't differ per tenant.
  If a tenant ever needed its own certificate or WAF rules, it would need its
  own ALB.
- A misconfigured Ingress in the group can affect how the shared ALB's listener
  rules are computed (though not another tenant's Target Group health).
- There's a soft limit on how many rules one ALB listener can hold (AWS quota),
  which caps how many tenants one shared ALB can realistically serve.

### Alternative considered: one Ingress with all rules inline

Instead of 3 separate Ingress resources, we could have put all 3 tenants' rules
in a single Ingress manifest. We rejected this because:
- It would require one team/pipeline to own and deploy all tenants' routing
  config together — breaking tenant isolation at the GitOps/deployment level,
  even though the runtime behavior would be identical.
- `IngressGroup` lets each tenant's manifests live in their own namespace, and
  in a real platform, be owned/deployed by that tenant's own pipeline — only
  the shared `group.name` ties them to the same ALB.

## Failure isolation

Each tenant's frontend/api Services are separate Target Groups. Scaling
`tenant-beta`'s `api` Deployment to 0 replicas empties only that Target Group;
ALB health checks mark it unhealthy and return 503 **only for `beta.saas.
example.com/api`**. `alpha`, `gamma`, and even `beta`'s own frontend continue
to serve traffic normally — verified live against the running cluster.

## Onboarding a 4th tenant

To add `tenant-delta`:
1. Create namespace `tenant-delta` with the `elbv2.k8s.aws/pod-readiness-gate-inject: enabled` label.
2. Deploy `frontend`/`api` Deployments + Services in that namespace.
3. Create a new Ingress in that namespace with the same `group.name: saas-shared`,
   a new `group.order`, host `delta.saas.example.com`, and the same shared
   annotations (certificate-arn, wafv2-acl-arn, access-logs bucket).
4. No changes needed to alpha/beta/gamma's manifests or to the ALB itself — the
   controller reconciles the shared ALB's listener rules automatically.
