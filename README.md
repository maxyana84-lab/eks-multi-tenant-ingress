# Production-Grade Multi-Tenant Ingress on AWS EKS

Multi-tenant SaaS platform architecture on a single shared ALB, built on AWS EKS
using the AWS Load Balancer Controller. 3 isolated tenants, each with their own
namespace, frontend/api services, TLS, WAF, access logging, and verified failure
isolation.

## Architecture
