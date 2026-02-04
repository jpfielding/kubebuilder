# Kubebuilder Markers Reference

Kubebuilder uses Go comment markers to generate code and manifests. This reference covers the most commonly used markers.

## RBAC Markers

Add to controller file (`controllers/myresource_controller.go`).

### Basic RBAC

```go
//+kubebuilder:rbac:groups=apps.example.com,resources=myresources,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=apps.example.com,resources=myresources/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=apps.example.com,resources=myresources/finalizers,verbs=update
```

### Common Resource Permissions

```go
// Core resources
//+kubebuilder:rbac:groups="",resources=pods,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups="",resources=secrets,verbs=get;list;watch
//+kubebuilder:rbac:groups="",resources=events,verbs=create;patch

// Apps resources
//+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=apps,resources=statefulsets,verbs=get;list;watch;create;update;patch;delete

// Batch resources
//+kubebuilder:rbac:groups=batch,resources=jobs,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=batch,resources=cronjobs,verbs=get;list;watch;create;update;patch;delete
```

### Cluster-scoped RBAC

For ClusterRole instead of Role:

```go
//+kubebuilder:rbac:groups="",resources=nodes,verbs=get;list;watch
//+kubebuilder:rbac:groups="",resources=namespaces,verbs=get;list;watch
```

## Validation Markers

Add to API types (`api/v*/myresource_types.go`).

### Field Validation

```go
type MyResourceSpec struct {
    // +kubebuilder:validation:Required
    // +kubebuilder:validation:MinLength=1
    Name string `json:"name"`

    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=100
    Replicas int32 `json:"replicas"`

    // +kubebuilder:validation:Pattern=`^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`
    // +kubebuilder:validation:MaxLength=63
    ServiceName string `json:"serviceName,omitempty"`

    // +kubebuilder:validation:Enum=ClusterIP;NodePort;LoadBalancer
    ServiceType string `json:"serviceType,omitempty"`

    // +kubebuilder:validation:Format=email
    AdminEmail string `json:"adminEmail,omitempty"`

    // +kubebuilder:validation:MinItems=1
    // +kubebuilder:validation:MaxItems=10
    Endpoints []string `json:"endpoints,omitempty"`

    // +kubebuilder:validation:XValidation:rule="self.size() > 0",message="labels cannot be empty"
    Labels map[string]string `json:"labels,omitempty"`
}
```

### CEL Validation (Kubebuilder v3.7+)

Common Expression Language for complex validation:

```go
// Field-level validation
// +kubebuilder:validation:XValidation:rule="self.size() <= 100",message="too many items"
Tags []string `json:"tags,omitempty"`

// Cross-field validation at struct level
// +kubebuilder:validation:XValidation:rule="self.minReplicas <= self.maxReplicas",message="minReplicas must be <= maxReplicas"
type AutoScaling struct {
    MinReplicas int32 `json:"minReplicas"`
    MaxReplicas int32 `json:"maxReplicas"`
}

// Transition validation (old vs new object)
// +kubebuilder:validation:XValidation:rule="self.type == oldSelf.type",message="type is immutable"
Type string `json:"type"`
```

### Required Fields

```go
// Make field required (not nullable)
// +kubebuilder:validation:Required
Image string `json:"image"`

// Optional field
// +optional
Config string `json:"config,omitempty"`
```

## Defaulting Markers

```go
type MyResourceSpec struct {
    // +kubebuilder:default=1
    Replicas int32 `json:"replicas,omitempty"`

    // +kubebuilder:default="nginx:latest"
    Image string `json:"image,omitempty"`

    // +kubebuilder:default=ClusterIP
    ServiceType string `json:"serviceType,omitempty"`

    // +kubebuilder:default=true
    Enabled bool `json:"enabled,omitempty"`
}
```

## Webhook Markers

Add to API types file.

```go
// Enable webhooks for this type
//+kubebuilder:webhook:path=/mutate-apps-example-com-v1-myresource,mutating=true,failurePolicy=fail,groups=apps.example.com,resources=myresources,verbs=create;update,versions=v1,name=mmyresource.kb.io,admissionReviewVersions=v1,sideEffects=None

//+kubebuilder:webhook:path=/validate-apps-example-com-v1-myresource,mutating=false,failurePolicy=fail,groups=apps.example.com,resources=myresources,verbs=create;update;delete,versions=v1,name=vmyresource.kb.io,admissionReviewVersions=v1,sideEffects=None
```

### Webhook Interface Implementation

```go
var _ webhook.Defaulter = &MyResource{}
var _ webhook.Validator = &MyResource{}

// Default implements webhook.Defaulter
func (r *MyResource) Default() {
    if r.Spec.Replicas == 0 {
        r.Spec.Replicas = 1
    }
}

// ValidateCreate implements webhook.Validator
func (r *MyResource) ValidateCreate() (admission.Warnings, error) {
    return nil, r.validateMyResource()
}

// ValidateUpdate implements webhook.Validator
func (r *MyResource) ValidateUpdate(old runtime.Object) (admission.Warnings, error) {
    return nil, r.validateMyResource()
}

// ValidateDelete implements webhook.Validator
func (r *MyResource) ValidateDelete() (admission.Warnings, error) {
    return nil, nil
}
```

## CRD Generation Markers

### Status Subresource

```go
// +kubebuilder:subresource:status
type MyResource struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   MyResourceSpec   `json:"spec,omitempty"`
    Status MyResourceStatus `json:"status,omitempty"`
}
```

### Scale Subresource

```go
// +kubebuilder:subresource:scale:specpath=.spec.replicas,statuspath=.status.replicas,selectorpath=.status.selector
type MyResource struct {
    // ...
}
```

### Categories

```go
// +kubebuilder:resource:categories={all,myoperator}
type MyResource struct {
    // ...
}
// Allows: kubectl get all, kubectl get myoperator
```

### Short Names

```go
// +kubebuilder:resource:shortName=mr;myres
type MyResource struct {
    // ...
}
// Allows: kubectl get mr
```

### Scope

```go
// +kubebuilder:resource:scope=Cluster
type MyClusterResource struct {
    // ...
}

// Default is Namespaced
// +kubebuilder:resource:scope=Namespaced
type MyResource struct {
    // ...
}
```

## PrintColumn Markers

Customize `kubectl get` output:

```go
// +kubebuilder:printcolumn:name="Status",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Replicas",type=integer,JSONPath=`.spec.replicas`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
type MyResource struct {
    // ...
}
```

### Common PrintColumn Types

- `string` - Text values
- `integer` - Numeric values
- `number` - Floating point
- `boolean` - true/false
- `date` - Timestamp (automatically formatted as duration)

## Object Markers

### Root Object

```go
// +kubebuilder:object:root=true
type MyResource struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`
    // ...
}
```

### Generate DeepCopy

```go
// +kubebuilder:object:generate=true
type MyCustomType struct {
    // ...
}
```

## Deprecation Markers

```go
// +kubebuilder:deprecatedversion:warning="apps.example.com/v1alpha1 is deprecated; use apps.example.com/v1"
type MyResourceV1Alpha1 struct {
    // ...
}
```

## Storage Version

Mark which version is the storage version:

```go
// +kubebuilder:storageversion
type MyResourceV1 struct {
    // ...
}
```

## Skip Markers

```go
// Skip validation generation for a field
// +kubebuilder:validation:Type=""
RawExtension runtime.RawExtension `json:"rawExtension,omitempty"`

// Skip entire field from CRD
// +kubebuilder:pruning:PreserveUnknownFields
Config map[string]interface{} `json:"config,omitempty"`
```

## Generate Commands

After adding/changing markers:

```bash
# Generate CRD manifests
make manifests

# Generate RBAC
make manifests

# Generate code (deepcopy, etc.)
make generate

# Both
make manifests generate
```

## Common Combinations

### Standard Resource

```go
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:shortName=mr
// +kubebuilder:printcolumn:name="Status",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
type MyResource struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   MyResourceSpec   `json:"spec,omitempty"`
    Status MyResourceStatus `json:"status,omitempty"`
}
```

### Controller RBAC

```go
//+kubebuilder:rbac:groups=apps.example.com,resources=myresources,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=apps.example.com,resources=myresources/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=apps.example.com,resources=myresources/finalizers,verbs=update
//+kubebuilder:rbac:groups="",resources=events,verbs=create;patch

func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // ...
}
```

## Troubleshooting

**Markers not working?**
- Ensure no space between `//` and `+kubebuilder`
- Run `make manifests generate` after changes
- Check controller-gen version: `controller-gen --version`

**CRD validation not applied?**
- Verify CRD was updated: `kubectl get crd myresources.apps.example.com -o yaml`
- Reinstall CRD: `make install`
- Check for validation errors in CRD status

**RBAC not generated?**
- Markers must be above `Reconcile()` function
- Run `make manifests`
- Check `config/rbac/role.yaml`
