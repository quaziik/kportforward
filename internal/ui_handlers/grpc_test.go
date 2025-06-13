package ui_handlers

import (
	"testing"

	"github.com/victorkazakov/kportforward/internal/config"
	"github.com/victorkazakov/kportforward/internal/utils"
)

func TestNewGRPCUIManager(t *testing.T) {
	logger := utils.NewLogger(utils.LevelInfo)
	manager := NewGRPCUIManager(logger)

	if manager == nil {
		t.Fatal("Manager should not be nil")
	}

	if manager.logger != logger {
		t.Error("Logger not set correctly")
	}

	if manager.services == nil {
		t.Error("Services map should be initialized")
	}

	if manager.IsEnabled() {
		t.Error("Manager should not be enabled initially")
	}
}

func TestGRPCUIManagerEnable(t *testing.T) {
	logger := utils.NewLogger(utils.LevelInfo)
	manager := NewGRPCUIManager(logger)

	// Initially disabled
	if manager.IsEnabled() {
		t.Error("Manager should be disabled initially")
	}

	// Test enable (will likely fail since grpcui is not installed in test environment)
	err := manager.Enable()
	// We expect this to fail in test environment, so we just check that it doesn't panic
	if err != nil {
		t.Logf("Enable failed as expected in test environment: %v", err)
	}
}

func TestGRPCUIManagerDisable(t *testing.T) {
	logger := utils.NewLogger(utils.LevelInfo)
	manager := NewGRPCUIManager(logger)

	// Test disable on non-enabled manager (should not panic)
	err := manager.Disable()
	if err != nil {
		t.Errorf("Disable should not return error: %v", err)
	}

	if manager.IsEnabled() {
		t.Error("Manager should be disabled after calling Disable")
	}
}

func TestGRPCUIManagerStartService(t *testing.T) {
	logger := utils.NewLogger(utils.LevelInfo)
	manager := NewGRPCUIManager(logger)

	// Test starting service when not enabled (should return early)
	serviceStatus := config.ServiceStatus{
		Name:      "test-rpc",
		Status:    "Running",
		LocalPort: 8080,
	}

	serviceConfig := config.Service{
		Target:     "service/test-rpc",
		TargetPort: 8080,
		LocalPort:  9080,
		Namespace:  "default",
		Type:       "rpc",
	}

	err := manager.StartService("test-rpc", serviceStatus, serviceConfig)
	if err != nil {
		t.Errorf("StartService should not return error when disabled: %v", err)
	}
}

func TestGRPCUIManagerStartServiceNonRPC(t *testing.T) {
	logger := utils.NewLogger(utils.LevelInfo)
	manager := NewGRPCUIManager(logger)

	// Force enable for testing
	manager.enabled = true

	// Test starting non-RPC service (should return early)
	serviceStatus := config.ServiceStatus{
		Name:      "test-web",
		Status:    "Running",
		LocalPort: 8080,
	}

	serviceConfig := config.Service{
		Target:     "service/test-web",
		TargetPort: 8080,
		LocalPort:  9080,
		Namespace:  "default",
		Type:       "web", // Not RPC
	}

	err := manager.StartService("test-web", serviceStatus, serviceConfig)
	if err != nil {
		t.Errorf("StartService should not return error for non-RPC service: %v", err)
	}

	// Should not have created a service entry
	if len(manager.services) != 0 {
		t.Error("Should not have created service entry for non-RPC service")
	}
}

func TestGRPCUIManagerStopService(t *testing.T) {
	logger := utils.NewLogger(utils.LevelInfo)
	manager := NewGRPCUIManager(logger)

	// Test stopping non-existent service (should not error)
	err := manager.StopService("non-existent")
	if err != nil {
		t.Errorf("StopService should not return error for non-existent service: %v", err)
	}
}

func TestGRPCUIManagerGetServiceInfo(t *testing.T) {
	logger := utils.NewLogger(utils.LevelInfo)
	manager := NewGRPCUIManager(logger)

	// Test getting info for non-existent service
	info := manager.GetServiceInfo("non-existent")
	if info != nil {
		t.Error("GetServiceInfo should return nil for non-existent service")
	}
}

func TestGRPCUIManagerGetServiceURL(t *testing.T) {
	logger := utils.NewLogger(utils.LevelInfo)
	manager := NewGRPCUIManager(logger)

	// Test getting URL for non-existent service
	url := manager.GetServiceURL("non-existent")
	if url != "" {
		t.Error("GetServiceURL should return empty string for non-existent service")
	}
}

func TestGRPCUIManagerMonitorServices(t *testing.T) {
	logger := utils.NewLogger(utils.LevelInfo)
	manager := NewGRPCUIManager(logger)

	// Test monitoring when disabled (should return early)
	services := map[string]config.ServiceStatus{
		"test-rpc": {
			Name:      "test-rpc",
			Status:    "Running",
			LocalPort: 8080,
		},
	}

	configs := map[string]config.Service{
		"test-rpc": {
			Target:     "service/test-rpc",
			TargetPort: 8080,
			LocalPort:  9080,
			Namespace:  "default",
			Type:       "rpc",
		},
	}

	// Should not panic when disabled
	manager.MonitorServices(services, configs)
}

func TestGRPCUIServiceStruct(t *testing.T) {
	// Test GRPCUIService struct creation
	service := &GRPCUIService{
		serviceName:  "test",
		localPort:    8080,
		grpcuiPort:   9090,
		restartCount: 0,
		status:       "Running",
	}

	if service.serviceName != "test" {
		t.Error("Service name not set correctly")
	}

	if service.localPort != 8080 {
		t.Error("Local port not set correctly")
	}

	if service.grpcuiPort != 9090 {
		t.Error("gRPC UI port not set correctly")
	}

	if service.status != "Running" {
		t.Error("Status not set correctly")
	}
}

func TestGRPCUIManagerIsGRPCUIAvailable(t *testing.T) {
	logger := utils.NewLogger(utils.LevelInfo)
	manager := NewGRPCUIManager(logger)

	// Test the availability check (will likely return false in test environment)
	available := manager.isGRPCUIAvailable()
	// We just check that it doesn't panic
	t.Logf("gRPC UI available: %v", available)
}
