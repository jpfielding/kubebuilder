# Testing Guide

## Test Structure Overview

Kubernetes operators should have three types of tests:
1. **Unit tests** - Test business logic in isolation
2. **Integration tests with envtest** - Test controller logic against a real API server
3. **End-to-end tests** - Test the full operator in a real cluster (optional)

## Setup envtest

### Installation

```bash
# Install setup-envtest
go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest

# Download test binaries
setup-envtest use

# Get the path for your shell
export KUBEBUILDER_ASSETS=$(setup-envtest use -p path)
```

### In CI/CD

```yaml
# GitHub Actions example
- name: Setup envtest
  run: |
    go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest
    echo "KUBEBUILDER_ASSETS=$(setup-envtest use -p path)" >> $GITHUB_ENV
```

## Controller Integration Tests

### Basic Test Suite

```go
package controllers

import (
    "context"
    "path/filepath"
    "testing"
    "time"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes/scheme"
    "k8s.io/client-go/rest"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/envtest"
    logf "sigs.k8s.io/controller-runtime/pkg/log"
    "sigs.k8s.io/controller-runtime/pkg/log/zap"

    myv1 "github.com/myorg/myoperator/api/v1"
)

var (
    cfg       *rest.Config
    k8sClient client.Client
    testEnv   *envtest.Environment
    ctx       context.Context
    cancel    context.CancelFunc
)

func TestControllers(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Controller Suite")
}

var _ = BeforeSuite(func() {
    logf.SetLogger(zap.New(zap.WriteTo(GinkgoWriter), zap.UseDevMode(true)))

    ctx, cancel = context.WithCancel(context.TODO())

    By("bootstrapping test environment")
    testEnv = &envtest.Environment{
        CRDDirectoryPaths:     []string{filepath.Join("..", "config", "crd", "bases")},
        ErrorIfCRDPathMissing: true,
    }

    var err error
    cfg, err = testEnv.Start()
    Expect(err).NotTo(HaveOccurred())
    Expect(cfg).NotTo(BeNil())

    err = myv1.AddToScheme(scheme.Scheme)
    Expect(err).NotTo(HaveOccurred())

    k8sClient, err = client.New(cfg, client.Options{Scheme: scheme.Scheme})
    Expect(err).NotTo(HaveOccurred())
    Expect(k8sClient).NotTo(BeNil())

    // Start the controller manager
    k8sManager, err := ctrl.NewManager(cfg, ctrl.Options{
        Scheme: scheme.Scheme,
    })
    Expect(err).ToNot(HaveOccurred())

    err = (&MyResourceReconciler{
        Client: k8sManager.GetClient(),
        Scheme: k8sManager.GetScheme(),
    }).SetupWithManager(k8sManager)
    Expect(err).ToNot(HaveOccurred())

    go func() {
        defer GinkgoRecover()
        err = k8sManager.Start(ctx)
        Expect(err).ToNot(HaveOccurred(), "failed to run manager")
    }()
})

var _ = AfterSuite(func() {
    cancel()
    By("tearing down the test environment")
    err := testEnv.Stop()
    Expect(err).NotTo(HaveOccurred())
})
```

### Example Test Cases

```go
var _ = Describe("MyResource Controller", func() {
    const (
        timeout  = time.Second * 10
        interval = time.Millisecond * 250
    )

    Context("When creating a MyResource", func() {
        It("Should create a Deployment", func() {
            ctx := context.Background()

            // Create test resource
            resource := &myv1.MyResource{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "test-resource",
                    Namespace: "default",
                },
                Spec: myv1.MyResourceSpec{
                    Replicas: 3,
                },
            }

            Expect(k8sClient.Create(ctx, resource)).Should(Succeed())

            // Check that deployment was created
            deployment := &appsv1.Deployment{}
            Eventually(func() error {
                return k8sClient.Get(ctx, types.NamespacedName{
                    Name:      resource.Name + "-deployment",
                    Namespace: resource.Namespace,
                }, deployment)
            }, timeout, interval).Should(Succeed())

            // Verify deployment spec
            Expect(*deployment.Spec.Replicas).Should(Equal(int32(3)))
        })

        It("Should update status conditions", func() {
            ctx := context.Background()

            resource := &myv1.MyResource{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "test-resource-2",
                    Namespace: "default",
                },
                Spec: myv1.MyResourceSpec{
                    Replicas: 1,
                },
            }

            Expect(k8sClient.Create(ctx, resource)).Should(Succeed())

            // Wait for Ready condition
            Eventually(func() bool {
                err := k8sClient.Get(ctx, types.NamespacedName{
                    Name:      resource.Name,
                    Namespace: resource.Namespace,
                }, resource)
                if err != nil {
                    return false
                }

                for _, cond := range resource.Status.Conditions {
                    if cond.Type == "Ready" && cond.Status == metav1.ConditionTrue {
                        return true
                    }
                }
                return false
            }, timeout, interval).Should(BeTrue())
        })
    })

    Context("When deleting a MyResource", func() {
        It("Should cleanup external resources", func() {
            ctx := context.Background()

            resource := &myv1.MyResource{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "test-resource-delete",
                    Namespace: "default",
                },
                Spec: myv1.MyResourceSpec{
                    Replicas: 1,
                },
            }

            Expect(k8sClient.Create(ctx, resource)).Should(Succeed())

            // Wait for reconciliation
            time.Sleep(2 * time.Second)

            // Delete resource
            Expect(k8sClient.Delete(ctx, resource)).Should(Succeed())

            // Verify finalizer removed and resource deleted
            Eventually(func() bool {
                err := k8sClient.Get(ctx, types.NamespacedName{
                    Name:      resource.Name,
                    Namespace: resource.Namespace,
                }, resource)
                return err != nil && apierrors.IsNotFound(err)
            }, timeout, interval).Should(BeTrue())
        })
    })
})
```

## Unit Tests

Test business logic without the API server.

```go
func TestValidateSpec(t *testing.T) {
    tests := []struct {
        name    string
        spec    myv1.MyResourceSpec
        wantErr bool
    }{
        {
            name: "valid spec",
            spec: myv1.MyResourceSpec{
                Replicas: 3,
                Image:    "nginx:latest",
            },
            wantErr: false,
        },
        {
            name: "invalid replicas",
            spec: myv1.MyResourceSpec{
                Replicas: -1,
                Image:    "nginx:latest",
            },
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := validateSpec(tt.spec)
            if (err != nil) != tt.wantErr {
                t.Errorf("validateSpec() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

## Webhook Tests

### Validation Webhook Tests

```go
var _ = Describe("MyResource Webhook", func() {
    Context("When creating MyResource", func() {
        It("Should reject invalid replicas", func() {
            resource := &myv1.MyResource{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "test-invalid",
                    Namespace: "default",
                },
                Spec: myv1.MyResourceSpec{
                    Replicas: -1,
                },
            }

            err := k8sClient.Create(context.Background(), resource)
            Expect(err).Should(HaveOccurred())
            Expect(err.Error()).Should(ContainSubstring("replicas must be positive"))
        })

        It("Should accept valid spec", func() {
            resource := &myv1.MyResource{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "test-valid",
                    Namespace: "default",
                },
                Spec: myv1.MyResourceSpec{
                    Replicas: 3,
                },
            }

            Expect(k8sClient.Create(context.Background(), resource)).Should(Succeed())
        })
    })
})
```

## Test Helpers

### Create Test Resources

```go
func createTestResource(name, namespace string) *myv1.MyResource {
    return &myv1.MyResource{
        ObjectMeta: metav1.ObjectMeta{
            Name:      name,
            Namespace: namespace,
        },
        Spec: myv1.MyResourceSpec{
            Replicas: 1,
            Image:    "nginx:latest",
        },
    }
}

func createAndWaitForResource(ctx context.Context, resource *myv1.MyResource) error {
    if err := k8sClient.Create(ctx, resource); err != nil {
        return err
    }

    // Wait for resource to be ready
    return wait.PollImmediate(250*time.Millisecond, 10*time.Second, func() (bool, error) {
        if err := k8sClient.Get(ctx, client.ObjectKeyFromObject(resource), resource); err != nil {
            return false, err
        }

        for _, cond := range resource.Status.Conditions {
            if cond.Type == "Ready" && cond.Status == metav1.ConditionTrue {
                return true, nil
            }
        }
        return false, nil
    })
}
```

## Running Tests

```bash
# Run all tests
make test

# Run with coverage
go test ./... -coverprofile cover.out
go tool cover -html=cover.out

# Run specific test
go test -v ./controllers -run TestMyResourceController

# Run with race detector
go test -race ./...

# Run only fast tests
go test -short ./...
```

## Makefile Integration

Add to your Makefile:

```makefile
.PHONY: test
test: envtest
    KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) -p path)" go test ./... -coverprofile cover.out

.PHONY: envtest
envtest: $(ENVTEST)
$(ENVTEST): $(LOCALBIN)
    test -s $(LOCALBIN)/setup-envtest || GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest
```

## Test Best Practices

1. **Use Eventually/Consistently** for async assertions with envtest
2. **Clean up resources** in test teardown to avoid state leakage
3. **Test error paths** including transient failures
4. **Mock external dependencies** (cloud APIs, databases)
5. **Test finalizer logic** thoroughly, including cleanup failures
6. **Verify status updates** separately from spec changes
7. **Test owner reference cleanup** by deleting parent resources
8. **Use table-driven tests** for validation logic
9. **Test concurrent reconciliation** if your controller handles it
10. **Include negative test cases** for invalid inputs

## Debugging Tests

```go
// Enable verbose logging in tests
import (
    logf "sigs.k8s.io/controller-runtime/pkg/log"
    "sigs.k8s.io/controller-runtime/pkg/log/zap"
)

func init() {
    logf.SetLogger(zap.New(zap.WriteTo(GinkgoWriter), zap.UseDevMode(true)))
}

// Dump resource state for debugging
func dumpResource(resource *myv1.MyResource) {
    fmt.Printf("Resource: %+v\n", resource)
    fmt.Printf("Status: %+v\n", resource.Status)
    fmt.Printf("Conditions: %+v\n", resource.Status.Conditions)
}
```
