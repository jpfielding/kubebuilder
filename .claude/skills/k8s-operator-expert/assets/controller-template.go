package controllers

import (
	"context"
	"fmt"
	"time"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/meta"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/tools/record"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	// TODO: Update this import
	myv1 "github.com/example/myoperator/api/v1"
)

// TODO: Update resource name and finalizer
const (
	myFinalizerName = "myresource.example.com/finalizer"
	// Condition types
	TypeReady    = "Ready"
	TypeDegraded = "Degraded"
)

// MyResourceReconciler reconciles a MyResource object
type MyResourceReconciler struct {
	client.Client
	Scheme   *runtime.Scheme
	Recorder record.EventRecorder
}

// TODO: Update RBAC markers for your resources
//+kubebuilder:rbac:groups=apps.example.com,resources=myresources,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=apps.example.com,resources=myresources/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=apps.example.com,resources=myresources/finalizers,verbs=update
//+kubebuilder:rbac:groups="",resources=events,verbs=create;patch

// Reconcile is the main reconciliation loop
func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := log.FromContext(ctx)

	// 1. Fetch the resource
	var resource myv1.MyResource
	if err := r.Get(ctx, req.NamespacedName, &resource); err != nil {
		if apierrors.IsNotFound(err) {
			// Resource deleted, nothing to do
			log.Info("Resource not found, likely deleted")
			return ctrl.Result{}, nil
		}
		log.Error(err, "Failed to get resource")
		return ctrl.Result{}, err
	}

	// 2. Handle deletion with finalizers
	if !resource.ObjectMeta.DeletionTimestamp.IsZero() {
		return r.reconcileDelete(ctx, &resource)
	}

	// 3. Ensure finalizer is present
	if !controllerutil.ContainsFinalizer(&resource, myFinalizerName) {
		log.Info("Adding finalizer")
		controllerutil.AddFinalizer(&resource, myFinalizerName)
		if err := r.Update(ctx, &resource); err != nil {
			log.Error(err, "Failed to add finalizer")
			return ctrl.Result{}, err
		}
		return ctrl.Result{Requeue: true}, nil
	}

	// 4. Reconcile the desired state
	return r.reconcileNormal(ctx, &resource)
}

// reconcileNormal handles normal reconciliation (not deletion)
func (r *MyResourceReconciler) reconcileNormal(ctx context.Context, resource *myv1.MyResource) (ctrl.Result, error) {
	log := log.FromContext(ctx)

	// TODO: Implement your reconciliation logic here
	// Example:
	// 1. Create/update child resources (Deployments, Services, etc.)
	// 2. Check status of child resources
	// 3. Update status based on actual state

	// Example: Check if resource is ready
	isReady := true // TODO: Replace with actual check

	if isReady {
		// Resource is ready
		condition := metav1.Condition{
			Type:               TypeReady,
			Status:             metav1.ConditionTrue,
			Reason:             "ReconciliationSucceeded",
			Message:            "Resource reconciled successfully",
			ObservedGeneration: resource.Generation,
		}
		if err := r.updateStatus(ctx, resource, condition); err != nil {
			log.Error(err, "Failed to update status")
			return ctrl.Result{}, err
		}

		r.Recorder.Event(resource, corev1.EventTypeNormal, "Ready", "Resource is ready")

		// Requeue after some time to check for drift
		return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
	}

	// Resource is not ready
	condition := metav1.Condition{
		Type:               TypeDegraded,
		Status:             metav1.ConditionTrue,
		Reason:             "NotReady",
		Message:            "Resource is not ready",
		ObservedGeneration: resource.Generation,
	}
	if err := r.updateStatus(ctx, resource, condition); err != nil {
		log.Error(err, "Failed to update status")
		return ctrl.Result{}, err
	}

	r.Recorder.Event(resource, corev1.EventTypeWarning, "NotReady", "Resource is not ready")

	// Requeue to check again
	return ctrl.Result{RequeueAfter: 30 * time.Second}, nil
}

// reconcileDelete handles resource deletion with cleanup
func (r *MyResourceReconciler) reconcileDelete(ctx context.Context, resource *myv1.MyResource) (ctrl.Result, error) {
	log := log.FromContext(ctx)

	if controllerutil.ContainsFinalizer(resource, myFinalizerName) {
		log.Info("Performing cleanup")

		// TODO: Perform cleanup of external resources here
		// Example:
		// if err := r.cleanupExternalResources(ctx, resource); err != nil {
		//     // Retry on failure
		//     log.Error(err, "Failed to cleanup external resources")
		//     return ctrl.Result{}, err
		// }

		// Remove finalizer after successful cleanup
		log.Info("Removing finalizer")
		controllerutil.RemoveFinalizer(resource, myFinalizerName)
		if err := r.Update(ctx, resource); err != nil {
			log.Error(err, "Failed to remove finalizer")
			return ctrl.Result{}, err
		}

		r.Recorder.Event(resource, corev1.EventTypeNormal, "Deleted", "Resource cleanup completed")
	}

	return ctrl.Result{}, nil
}

// updateStatus updates the resource status
func (r *MyResourceReconciler) updateStatus(ctx context.Context, resource *myv1.MyResource, condition metav1.Condition) error {
	// Update condition
	meta.SetStatusCondition(&resource.Status.Conditions, condition)

	// Set observed generation
	resource.Status.ObservedGeneration = resource.Generation

	// Use Status().Update() not Update() to avoid triggering reconciliation
	if err := r.Status().Update(ctx, resource); err != nil {
		return fmt.Errorf("failed to update status: %w", err)
	}

	return nil
}

// SetupWithManager sets up the controller with the Manager
func (r *MyResourceReconciler) SetupWithManager(mgr ctrl.Manager) error {
	// Set up event recorder
	r.Recorder = mgr.GetEventRecorderFor("myresource-controller")

	return ctrl.NewControllerManagedBy(mgr).
		For(&myv1.MyResource{}).
		// TODO: Add Owns() for child resources
		// Owns(&appsv1.Deployment{}).
		// Owns(&corev1.Service{}).
		Complete(r)
}
