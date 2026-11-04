#!/bin/bash

ALB="k8s-saasshared-aaa5b53ee9-1851498258.eu-north-1.elb.amazonaws.com"

echo "=== Checking all tenants ==="

for tenant in alpha beta gamma; do
  echo ""
  echo "--- Tenant: $tenant ---"

  echo -n "Frontend (/): "
  curl -s -k -H "Host: ${tenant}.saas.example.com" "https://${ALB}/"

  echo ""
  echo -n "API (/api): "
  curl -s -k -H "Host: ${tenant}.saas.example.com" "https://${ALB}/api"

  echo ""
done

echo ""
echo "=== Done ==="
