# Troubleshooting Guide

## Common Issues and Solutions

### Controller Not Reconciling

**Symptom:** Changes to resources don't trigger reconciliation.

**Diagnostics:**
```bash
# Check controller logs
kubectl logs -n <namespace> deployment/<operator>-controller-manager -f

# Check if CRD is installed
kubectl get crd <resource>.<group>

# Check if controller is running
kubectl get pods -n <namespace>

# Describe the resource to see events
kubectl describe <resource> <name> -n <namespace>
```

**Common Causes:**

1. **RBAC permissions missing**
   ```bash
   # Check for permission errors in logs
   kubectl logs -n system deployment/controller-manager | grep "forbidden"

   # Verify RBAC
   kubectl get clusterrole <operator>-manager-role -o yaml
   ```

   Fix: Add missing RBAC markers and regenerate:
   ```go
   //+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
   ```

2. **Watch not configured**
   ```go
   // Ensure SetupWithManager includes all watched resources
   func (r *MyResourceReconciler) SetupWithManager(mgr ctrl.Manager) error {
       return ctrl.NewControllerManagedBy(mgr).
           For(&myv1.MyResource{}).
           Owns(&appsv1.Deployment{}). // Add this if missing
           Complete(r)
   }
   ```

3. **Reconcile returning too quickly**
   ```go
   // Don't forget to requeue if needed
   return ctrl.Result{RequeueAfter: 30 * time.Second}, nil
   ```

### CRD Changes Not Applied

**Symptom:** Updated fields or validation not working.

**Diagnostics:**
```bash
# Check installed CRD version
kubectl get crd <resource>.<group> -o yaml | grep -A 20 "spec:"

# Compare with generated CRD
cat config/crd/bases/<group>_<resource>.yaml
```

**Solutions:**

1. **Regenerate manifests**
   ```bash
   make manifests
   ```

2. **Reinstall CRD**
   ```bash
   make uninstall
   make install
   ```

3. **Check for CRD validation errors**
   ```bash
   kubectl apply -f config/crd/bases/<group>_<resource>.yaml --dry-run=server -o yaml
   ```

### Webhooks Not Working

**Symptom:** Validation/defaulting not triggered.

**Diagnostics:**
```bash
# Check webhook configuration
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations

# Check webhook service
kubectl get svc -n <namespace> webhook-service

# Check certificate
kubectl get secret -n <namespace> webhook-server-cert
```

**Common Issues:**

1. **Webhook not registered**
   - Ensure webhook markers are present in API types
   - Run `make manifests`
   - Redeploy: `make deploy`

2. **Certificate issues**
   ```bash
   # Check cert-manager logs
   kubectl logs -n cert-manager deployment/cert-manager

   # Recreate certificate
   kubectl delete secret -n <namespace> webhook-server-cert
   # Restart controller to regenerate
   kubectl rollout restart deployment -n <namespace> <operator>-controller-manager
   ```

3. **Service endpoint missing**
   ```bash
   kubectl get endpoints -n <namespace> webhook-service
   ```

   If empty, check pod labels match service selector.

### Reconciliation Loops (Infinite Requeuing)

**Symptom:** Controller constantly reconciles, high CPU usage.

**Diagnostics:**
```bash
# Watch reconciliation frequency
kubectl logs -n <namespace> deployment/<operator>-controller-manager | grep "Reconciling"

# Enable verbose logging
# In main.go, set zap development mode:
ctrl.SetLogger(zap.New(zap.UseDevMode(true)))
```

**Common Causes:**

1. **Status updates triggering reconciliation**
   ```go
   // WRONG: Updates trigger reconciliation
   func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
       resource.Status.Phase = "Ready"
       r.Update(ctx, resource) // This triggers reconciliation!
       return ctrl.Result{}, nil
   }

   // RIGHT: Use Status().Update()
   func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
       resource.Status.Phase = "Ready"
       r.Status().Update(ctx, resource) // Won't trigger reconciliation
       return ctrl.Result{}, nil
   }
   ```

2. **Modifying owned resources without checking**
   ```go
   // Add checks before updating
   func (r *MyResourceReconciler) ensureDeployment(ctx context.Context, resource *myv1.MyResource) error {
       existing := &appsv1.Deployment{}
       err := r.Get(ctx, types.NamespacedName{Name: name, Namespace: namespace}, existing)

       if err != nil && apierrors.IsNotFound(err) {
           // Create new deployment
           return r.Create(ctx, deployment)
       } else if err != nil {
           return err
       }

       // Only update if different
       if !reflect.DeepEqual(existing.Spec, deployment.Spec) {
           existing.Spec = deployment.Spec
           return r.Update(ctx, existing)
       }

       return nil
   }
   ```

3. **Always requeuing**
   ```go
   // Don't always requeue unless needed
   return ctrl.Result{Requeue: true}, nil // Only use if necessary
   ```

### Finalizer Issues

**Symptom:** Resources stuck in Terminating state.

**Diagnostics:**
```bash
# Check finalizers on stuck resource
kubectl get <resource> <name> -o yaml | grep -A 5 finalizers

# Check deletion timestamp
kubectl get <resource> <name> -o yaml | grep deletionTimestamp
```

**Solutions:**

1. **Finalizer not removed**
   ```go
   func (r *MyResourceReconciler) reconcileDelete(ctx context.Context, resource *myv1.MyResource) (ctrl.Result, error) {
       if controllerutil.ContainsFinalizer(resource, myFinalizerName) {
           // Cleanup must succeed
           if err := r.cleanupExternalResources(ctx, resource); err != nil {
               // Don't remove finalizer if cleanup fails
               return ctrl.Result{}, err
           }

           // Remove finalizer only after successful cleanup
           controllerutil.RemoveFinalizer(resource, myFinalizerName)
           if err := r.Update(ctx, resource); err != nil {
               return ctrl.Result{}, err
           }
       }
       return ctrl.Result{}, nil
   }
   ```

2. **Force remove finalizer (last resort)**
   ```bash
   kubectl patch <resource> <name> -p '{"metadata":{"finalizers":[]}}' --type=merge
   ```

### Resource Not Found Errors

**Symptom:** Controller logs show "not found" errors.

**Common Pattern:**
```go
func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    var resource myv1.MyResource
    if err := r.Get(ctx, req.NamespacedName, &resource); err != nil {
        if apierrors.IsNotFound(err) {
            // Resource deleted, this is normal
            return ctrl.Result{}, nil
        }
        // Actual error
        return ctrl.Result{}, err
    }
    // ... rest of reconciliation
}
```

### Owner Reference Issues

**Symptom:** Child resources not deleted when parent is deleted.

**Check:**
```bash
# Verify owner reference is set
kubectl get deployment <name> -o yaml | grep -A 10 ownerReferences
```

**Fix:**
```go
import "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"

func (r *MyResourceReconciler) createDeployment(ctx context.Context, resource *myv1.MyResource) error {
    deployment := &appsv1.Deployment{...}

    // Set owner reference
    if err := controllerutil.SetControllerReference(resource, deployment, r.Scheme); err != nil {
        return err
    }

    return r.Create(ctx, deployment)
}
```

### Testing Issues

**envtest setup fails**
```bash
# Install/update envtest binaries
setup-envtest use

# Set environment variable
export KUBEBUILDER_ASSETS=$(setup-envtest use -p path)

# Verify
echo $KUBEBUILDER_ASSETS
ls $KUBEBUILDER_ASSETS
```

**Tests timing out**
```go
// Increase timeout values
const (
    timeout  = time.Second * 30  // Increase from 10
    interval = time.Millisecond * 500  // Increase interval
)

// Use Eventually with proper timeout
Eventually(func() bool {
    err := k8sClient.Get(ctx, key, resource)
    return err == nil && resource.Status.Phase == "Ready"
}, timeout, interval).Should(BeTrue())
```

### Deployment Issues

**Image pull errors**
```bash
# Check image name and tag
kubectl describe pod <operator-pod> -n <namespace>

# Verify image exists
docker pull <image>:<tag>

# Check image pull secrets
kubectl get secrets -n <namespace>
```

**Webhook timeout errors**
```bash
# Check webhook is running
kubectl get pods -n <namespace> -l control-plane=controller-manager

# Check webhook endpoint
kubectl get endpoints -n <namespace> webhook-service

# Check for certificate issues
kubectl logs -n cert-manager deployment/cert-manager
```

**Operator crashes on startup**
```bash
# Check logs for panic
kubectl logs -n <namespace> deployment/<operator>-controller-manager

# Common causes:
# - Scheme not registered: Add your API to scheme in main.go
# - Port conflicts: Check if port 8080 (metrics) or 9443 (webhook) are in use
# - RBAC issues: Check service account has needed permissions
```

## Debugging Techniques

### Enable Verbose Logging

In `main.go`:
```go
import "sigs.k8s.io/controller-runtime/pkg/log/zap"

func main() {
    opts := zap.Options{
        Development: true,  // Enable development mode
        TimeEncoder: zapcore.ISO8601TimeEncoder,
    }

    ctrl.SetLogger(zap.New(zap.UseFlagOptions(&opts)))
    // ...
}
```

### Add Debug Logging

```go
func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    log.Info("Reconciling", "resource", req.NamespacedName)

    // Log important state
    log.Info("Current state", "phase", resource.Status.Phase, "generation", resource.Generation)

    // Log before/after changes
    log.V(1).Info("Updating deployment", "name", deployment.Name, "replicas", *deployment.Spec.Replicas)

    return ctrl.Result{}, nil
}
```

### Use Events for Debugging

```go
// Record events for important actions
r.Recorder.Event(resource, corev1.EventTypeNormal, "Created", "Created deployment successfully")
r.Recorder.Event(resource, corev1.EventTypeWarning, "Failed", fmt.Sprintf("Failed to create service: %v", err))

// View events
// kubectl describe <resource> <name>
```

### Local Debugging with Delve

```bash
# Run operator locally with delve
dlv debug ./main.go

# Set breakpoints
break controllers.(*MyResourceReconciler).Reconcile

# Continue execution
continue
```

## Performance Issues

**High memory usage**
- List operations without pagination
- Caching too many resources
- Memory leaks in reconciliation

**Fix:**
```go
// Use pagination for large lists
var resources myv1.MyResourceList
opts := []client.ListOption{
    client.Limit(100),
}
if err := r.List(ctx, &resources, opts...); err != nil {
    return ctrl.Result{}, err
}
```

**High CPU usage**
- Reconciliation loops (see above)
- Too frequent reconciliation
- Inefficient queries

**Fix:**
```go
// Add reasonable requeue delays
return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil

// Use watches efficiently - only watch what you need
```

## Getting Help

If still stuck:

1. **Check controller-runtime issues**: https://github.com/kubernetes-sigs/controller-runtime/issues
2. **Check Kubebuilder issues**: https://github.com/kubernetes-sigs/kubebuilder/issues
3. **Enable verbose logging and analyze patterns**
4. **Use `kubectl describe` and `kubectl get events` liberally**
5. **Test locally with `make run` before deploying**
