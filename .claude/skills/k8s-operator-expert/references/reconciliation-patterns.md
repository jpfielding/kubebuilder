# Reconciliation Patterns

## Core Controller Pattern

The reconciliation loop is the heart of any operator. It must be idempotent and handle partial states.

### Basic Structure

```go
func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // 1. Fetch the resource
    var resource myv1.MyResource
    if err := r.Get(ctx, req.NamespacedName, &resource); err != nil {
        if apierrors.IsNotFound(err) {
            // Resource deleted, nothing to do
            return ctrl.Result{}, nil
        }
        return ctrl.Result{}, err
    }

    // 2. Handle deletion with finalizers
    if !resource.ObjectMeta.DeletionTimestamp.IsZero() {
        return r.reconcileDelete(ctx, &resource)
    }

    // 3. Ensure finalizer is present
    if !controllerutil.ContainsFinalizer(&resource, myFinalizerName) {
        controllerutil.AddFinalizer(&resource, myFinalizerName)
        if err := r.Update(ctx, &resource); err != nil {
            return ctrl.Result{}, err
        }
        return ctrl.Result{Requeue: true}, nil
    }

    // 4. Reconcile the desired state
    return r.reconcileNormal(ctx, &resource)
}
```

## Finalizer Pattern

Finalizers ensure cleanup happens before resource deletion.

```go
const myFinalizerName = "myresource.example.com/finalizer"

func (r *MyResourceReconciler) reconcileDelete(ctx context.Context, resource *myv1.MyResource) (ctrl.Result, error) {
    if controllerutil.ContainsFinalizer(resource, myFinalizerName) {
        // Perform cleanup (delete external resources, etc.)
        if err := r.cleanupExternalResources(ctx, resource); err != nil {
            // Retry on failure
            return ctrl.Result{}, err
        }

        // Remove finalizer
        controllerutil.RemoveFinalizer(resource, myFinalizerName)
        if err := r.Update(ctx, resource); err != nil {
            return ctrl.Result{}, err
        }
    }
    return ctrl.Result{}, nil
}
```

## Status Management

Always update status separately from spec to avoid conflicts.

```go
func (r *MyResourceReconciler) updateStatus(ctx context.Context, resource *myv1.MyResource, condition metav1.Condition) error {
    // Update conditions
    meta.SetStatusCondition(&resource.Status.Conditions, condition)

    // Use Status().Update() not Update()
    if err := r.Status().Update(ctx, resource); err != nil {
        return err
    }
    return nil
}

// Common condition types
const (
    TypeReady     = "Ready"
    TypeDegraded  = "Degraded"
)

// Example usage
condition := metav1.Condition{
    Type:               TypeReady,
    Status:             metav1.ConditionTrue,
    Reason:             "ReconciliationSucceeded",
    Message:            "Resource reconciled successfully",
    ObservedGeneration: resource.Generation,
}
```

## Error Handling Patterns

### Requeue Strategies

```go
// Immediate requeue
return ctrl.Result{Requeue: true}, nil

// Requeue after delay
return ctrl.Result{RequeueAfter: 30 * time.Second}, nil

// Error (exponential backoff applied automatically)
return ctrl.Result{}, fmt.Errorf("failed to reconcile: %w", err)
```

### Transient vs Permanent Errors

```go
func (r *MyResourceReconciler) reconcileNormal(ctx context.Context, resource *myv1.MyResource) (ctrl.Result, error) {
    // Try to create/update external resource
    if err := r.createExternalResource(ctx, resource); err != nil {
        // Check if error is transient
        if isTransientError(err) {
            // Requeue with delay for transient errors
            return ctrl.Result{RequeueAfter: 30 * time.Second}, nil
        }

        // Permanent error - update status and don't requeue
        condition := metav1.Condition{
            Type:    TypeDegraded,
            Status:  metav1.ConditionTrue,
            Reason:  "ConfigurationError",
            Message: err.Error(),
        }
        _ = r.updateStatus(ctx, resource, condition)
        return ctrl.Result{}, nil
    }

    // Success
    condition := metav1.Condition{
        Type:    TypeReady,
        Status:  metav1.ConditionTrue,
        Reason:  "ReconciliationSucceeded",
        Message: "Resource reconciled successfully",
    }
    _ = r.updateStatus(ctx, resource, condition)
    return ctrl.Result{}, nil
}
```

## Owner References

Use owner references for automatic cleanup of dependent resources.

```go
import "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"

func (r *MyResourceReconciler) createDeployment(ctx context.Context, resource *myv1.MyResource) error {
    deployment := &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      resource.Name + "-deployment",
            Namespace: resource.Namespace,
        },
        Spec: appsv1.DeploymentSpec{
            // ... deployment spec
        },
    }

    // Set owner reference
    if err := controllerutil.SetControllerReference(resource, deployment, r.Scheme); err != nil {
        return err
    }

    // Create or update
    return r.Create(ctx, deployment)
}
```

## Watching Related Resources

Watch resources owned by your CR for automatic reconciliation.

```go
func (r *MyResourceReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&myv1.MyResource{}).
        Owns(&appsv1.Deployment{}). // Reconcile when owned Deployments change
        Owns(&corev1.Service{}).    // Reconcile when owned Services change
        Complete(r)
}
```

## External Resource Reconciliation

For resources outside the cluster (cloud resources, databases, etc.).

```go
func (r *MyResourceReconciler) reconcileExternalResource(ctx context.Context, resource *myv1.MyResource) error {
    // Check if external resource exists
    exists, err := r.ExternalClient.Exists(ctx, resource.Spec.ExternalID)
    if err != nil {
        return err
    }

    if !exists {
        // Create external resource
        id, err := r.ExternalClient.Create(ctx, resource.Spec)
        if err != nil {
            return err
        }

        // Store ID in status
        resource.Status.ExternalID = id
        return r.Status().Update(ctx, resource)
    }

    // Update external resource to match spec
    return r.ExternalClient.Update(ctx, resource.Status.ExternalID, resource.Spec)
}
```

## Periodic Reconciliation

Force periodic reconciliation even without changes.

```go
func (r *MyResourceReconciler) reconcileNormal(ctx context.Context, resource *myv1.MyResource) (ctrl.Result, error) {
    // ... reconciliation logic

    // Requeue every 5 minutes to check drift
    return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
}
```

## Status Subresource Best Practices

When using status subresources (recommended), follow these patterns:

```go
// Define status in API with conditions
type MyResourceStatus struct {
    // +optional
    Conditions []metav1.Condition `json:"conditions,omitempty"`

    // +optional
    ObservedGeneration int64 `json:"observedGeneration,omitempty"`

    // Add your custom status fields
    Phase string `json:"phase,omitempty"`
}

// Always set ObservedGeneration
func (r *MyResourceReconciler) updateStatus(ctx context.Context, resource *myv1.MyResource) error {
    resource.Status.ObservedGeneration = resource.Generation
    return r.Status().Update(ctx, resource)
}
```

## Event Recording

Add events for important state changes.

```go
import "k8s.io/client-go/tools/record"

type MyResourceReconciler struct {
    client.Client
    Scheme   *runtime.Scheme
    Recorder record.EventRecorder
}

func (r *MyResourceReconciler) reconcileNormal(ctx context.Context, resource *myv1.MyResource) (ctrl.Result, error) {
    // Record normal event
    r.Recorder.Event(resource, corev1.EventTypeNormal, "Created", "Successfully created deployment")

    // Record warning event
    r.Recorder.Event(resource, corev1.EventTypeWarning, "Failed", "Failed to create service")

    return ctrl.Result{}, nil
}

// In SetupWithManager
func (r *MyResourceReconciler) SetupWithManager(mgr ctrl.Manager) error {
    r.Recorder = mgr.GetEventRecorderFor("myresource-controller")
    // ...
}
```
