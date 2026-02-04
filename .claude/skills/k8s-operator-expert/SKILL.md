---
name: k8s-operator-expert
description: Expert Kubernetes operator development with Kubebuilder and controller-runtime. Use when building, debugging, or enhancing Kubernetes operators for (1) Creating new operators or APIs, (2) Implementing reconciliation logic and controllers, (3) Adding webhooks, validation, or defaulting, (4) Writing tests with envtest, (5) Debugging operator issues or reconciliation loops, (6) Working with finalizers, status management, or RBAC, (7) Performance optimization or troubleshooting. Also covers Operator SDK alternatives (Helm/Ansible-based operators) when appropriate.
---

# Kubernetes Operator Expert

Expert guidance for building production-ready Kubernetes operators using Kubebuilder, with support for Operator SDK alternatives.

## Core Capabilities

### 1. Operator Scaffolding and Setup

Create new operators with best practices from the start.

**Quick scaffold with script:**
```bash
scripts/scaffold_operator.sh -n my-operator -r github.com/myorg/my-operator -k MyResource --webhook
```

**Manual scaffolding:**
```bash
# Initialize project
kubebuilder init --domain example.com --repo github.com/myorg/my-operator

# Create API and controller
kubebuilder create api --group apps --version v1 --kind MyResource --resource --controller

# Create webhooks (optional)
kubebuilder create webhook --group apps --version v1 --kind MyResource --defaulting --programmatic-validation

# Generate manifests
make manifests generate
```

**Template controller available:** See `assets/controller-template.go` for a complete controller implementation with finalizers, status management, and error handling.

### 2. Reconciliation Logic

Implement idempotent reconciliation loops. See `references/reconciliation-patterns.md` for:
- Basic controller structure with finalizers
- Status condition management
- Error handling and requeue strategies
- Owner references for automatic cleanup
- External resource reconciliation
- Event recording patterns

**Key patterns:**
- Always use `Status().Update()` for status changes (not `Update()`)
- Check `IsNotFound()` errors when fetching resources
- Add finalizers before creating external resources
- Implement idempotent operations
- Use appropriate requeue strategies

### 3. API Design and Validation

Define CRDs with proper validation and defaults.

**Common markers:** See `references/kubebuilder-markers.md` for comprehensive marker reference including:
- Field validation (Required, MinLength, Pattern, Enum, etc.)
- CEL validation for complex rules
- Defaulting values
- RBAC permissions
- Webhook configuration
- PrintColumns for kubectl output
- Status subresources

**Example API with validation:**
```go
type MyResourceSpec struct {
    // +kubebuilder:validation:Required
    // +kubebuilder:validation:MinLength=1
    Name string `json:"name"`

    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=100
    // +kubebuilder:default=1
    Replicas int32 `json:"replicas,omitempty"`

    // +kubebuilder:validation:Pattern=`^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`
    ServiceName string `json:"serviceName,omitempty"`
}
```

### 4. Testing Strategies

Comprehensive testing with envtest. See `references/testing-guide.md` for:
- envtest setup and configuration
- Controller integration tests with Ginkgo/Gomega
- Unit tests for business logic
- Webhook validation tests
- Test helpers and best practices
- Debugging techniques

**Setup envtest:**
```bash
scripts/setup_envtest.sh --install-tool
scripts/setup_envtest.sh  # Setup test environment
```

**Common test pattern:**
```go
It("Should reconcile successfully", func() {
    resource := createTestResource("test", "default")
    Expect(k8sClient.Create(ctx, resource)).Should(Succeed())

    Eventually(func() bool {
        err := k8sClient.Get(ctx, client.ObjectKeyFromObject(resource), resource)
        if err != nil {
            return false
        }
        return meta.IsStatusConditionTrue(resource.Status.Conditions, "Ready")
    }, timeout, interval).Should(BeTrue())
})
```

### 5. Webhooks

Implement admission control with mutating and validating webhooks.

**Markers for webhooks:**
```go
//+kubebuilder:webhook:path=/mutate-apps-v1-myresource,mutating=true,failurePolicy=fail,sideEffects=None,groups=apps.example.com,resources=myresources,verbs=create;update,versions=v1,name=mmyresource.kb.io,admissionReviewVersions=v1

//+kubebuilder:webhook:path=/validate-apps-v1-myresource,mutating=false,failurePolicy=fail,sideEffects=None,groups=apps.example.com,resources=myresources,verbs=create;update;delete,versions=v1,name=vmyresource.kb.io,admissionReviewVersions=v1
```

**Implementation:**
```go
func (r *MyResource) Default() {
    if r.Spec.Replicas == 0 {
        r.Spec.Replicas = 1
    }
}

func (r *MyResource) ValidateCreate() (admission.Warnings, error) {
    if r.Spec.Replicas < 1 {
        return nil, fmt.Errorf("replicas must be positive")
    }
    return nil, nil
}
```

### 6. Troubleshooting

Debug common operator issues. See `references/troubleshooting.md` for:
- Controller not reconciling (RBAC, watches, requeue issues)
- CRD changes not applied
- Webhook issues (certificates, registration)
- Reconciliation loops and infinite requeuing
- Finalizer problems (stuck resources)
- Owner reference issues
- Testing problems
- Deployment failures
- Performance optimization

**Quick diagnostics:**
```bash
# Check controller logs
kubectl logs -n <namespace> deployment/<operator>-controller-manager -f

# Check resource events
kubectl describe <resource> <name>

# Verify CRD
kubectl get crd <resource>.<group> -o yaml

# Check RBAC
kubectl get clusterrole <operator>-manager-role -o yaml
```

### 7. Alternative Approaches

When Kubebuilder isn't the best fit. See `references/operator-sdk.md` for:
- Operator SDK overview and comparison
- Helm-based operators (wrap existing charts)
- Ansible-based operators (use playbooks)
- OLM integration for operator distribution
- Scorecard testing for quality checks

**Use Operator SDK when:**
- Wrapping Helm charts as operators
- Using Ansible for automation
- Publishing to OperatorHub
- Need built-in OLM support

## Quick Reference

### Common Commands

```bash
# Generate code and manifests
make manifests generate

# Run tests
make test

# Run locally
make run

# Install CRDs
make install

# Build and push image
make docker-build docker-push IMG=<registry>/<image>:tag

# Deploy to cluster
make deploy IMG=<registry>/<image>:tag

# Cleanup
make undeploy uninstall
```

### Development Workflow

1. **Design API** - Define spec and status in `api/v*/types.go`
2. **Add markers** - Validation, RBAC, defaults
3. **Generate** - Run `make manifests generate`
4. **Implement controller** - Reconciliation logic in `controllers/`
5. **Write tests** - Integration tests with envtest
6. **Test locally** - `make install run`
7. **Deploy** - Build image and deploy to cluster

### Best Practices

- Use status subresources (`+kubebuilder:subresource:status`)
- Implement finalizers for cleanup
- Add conditions to status for observability
- Record events for important actions
- Use owner references for dependent resources
- Test reconciliation with envtest
- Handle all error cases appropriately
- Use appropriate requeue strategies
- Validate inputs with webhooks or markers
- Document your CRD with descriptions

## Resources

This skill includes:

- **scripts/** - Operator scaffolding and envtest setup utilities
- **references/** - Detailed guides for reconciliation, testing, markers, troubleshooting, and Operator SDK
- **assets/** - Controller template with best practices
