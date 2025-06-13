package portforward

import (
	"context"
	"fmt"
	"os/exec"
	"sync"
	"time"

	"github.com/victorkazakov/kportforward/internal/config"
	"github.com/victorkazakov/kportforward/internal/utils"
)

// Manager coordinates multiple port-forward services
type Manager struct {
	services         map[string]*ServiceManager
	config           *config.Config
	logger           *utils.Logger
	ctx              context.Context
	cancel           context.CancelFunc
	mutex            sync.RWMutex
	kubernetesContext string
	
	// Monitoring
	monitoringTicker *time.Ticker
	statusChan       chan map[string]config.ServiceStatus
}

// NewManager creates a new port-forward manager
func NewManager(cfg *config.Config, logger *utils.Logger) *Manager {
	ctx, cancel := context.WithCancel(context.Background())
	
	return &Manager{
		services:   make(map[string]*ServiceManager),
		config:     cfg,
		logger:     logger,
		ctx:        ctx,
		cancel:     cancel,
		statusChan: make(chan map[string]config.ServiceStatus, 1),
	}
}

// Start initializes and starts all port-forward services
func (m *Manager) Start() error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	// Get current Kubernetes context
	if err := m.updateKubernetesContext(); err != nil {
		return fmt.Errorf("failed to get Kubernetes context: %w", err)
	}

	// Create service managers
	for name, serviceConfig := range m.config.PortForwards {
		sm := NewServiceManager(name, serviceConfig, m.logger)
		m.services[name] = sm
	}

	// Start all services
	var startErrors []error
	for name, sm := range m.services {
		if err := sm.Start(); err != nil {
			m.logger.Error("Failed to start service %s: %v", name, err)
			startErrors = append(startErrors, err)
		}
	}

	// Start monitoring
	m.startMonitoring()

	if len(startErrors) > 0 {
		return fmt.Errorf("failed to start %d services", len(startErrors))
	}

	m.logger.Info("Started %d port-forward services", len(m.services))
	return nil
}

// Stop gracefully stops all services
func (m *Manager) Stop() error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	// Stop monitoring
	if m.monitoringTicker != nil {
		m.monitoringTicker.Stop()
	}

	// Stop all services
	for name, sm := range m.services {
		if err := sm.Stop(); err != nil {
			m.logger.Error("Failed to stop service %s: %v", name, err)
		}
	}

	m.cancel()
	close(m.statusChan)
	
	m.logger.Info("Stopped all port-forward services")
	return nil
}

// GetStatusChannel returns a channel that receives status updates
func (m *Manager) GetStatusChannel() <-chan map[string]config.ServiceStatus {
	return m.statusChan
}

// GetCurrentStatus returns the current status of all services
func (m *Manager) GetCurrentStatus() map[string]config.ServiceStatus {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	status := make(map[string]config.ServiceStatus)
	for name, sm := range m.services {
		status[name] = sm.GetStatus()
	}
	return status
}

// RestartService restarts a specific service
func (m *Manager) RestartService(name string) error {
	m.mutex.RLock()
	sm, exists := m.services[name]
	m.mutex.RUnlock()

	if !exists {
		return fmt.Errorf("service %s not found", name)
	}

	return sm.Restart()
}

// GetKubernetesContext returns the current Kubernetes context
func (m *Manager) GetKubernetesContext() string {
	m.mutex.RLock()
	defer m.mutex.RUnlock()
	return m.kubernetesContext
}

// startMonitoring begins the monitoring loop for all services
func (m *Manager) startMonitoring() {
	m.monitoringTicker = time.NewTicker(m.config.MonitoringInterval)
	
	go func() {
		defer m.monitoringTicker.Stop()
		
		for {
			select {
			case <-m.ctx.Done():
				return
			case <-m.monitoringTicker.C:
				m.monitorServices()
				m.checkKubernetesContext()
			}
		}
	}()
}

// monitorServices checks the health of all services and restarts failed ones
func (m *Manager) monitorServices() {
	m.mutex.RLock()
	services := make(map[string]*ServiceManager, len(m.services))
	for name, sm := range m.services {
		services[name] = sm
	}
	m.mutex.RUnlock()

	statusMap := make(map[string]config.ServiceStatus)
	
	for name, sm := range services {
		status := sm.GetStatus()
		statusMap[name] = status

		// Check if service needs to be restarted
		if status.Status == "Failed" && !status.InCooldown {
			m.logger.Info("Restarting failed service: %s", name)
			go func(serviceName string, serviceManager *ServiceManager) {
				if err := serviceManager.Restart(); err != nil {
					m.logger.Error("Failed to restart service %s: %v", serviceName, err)
				}
			}(name, sm)
		}
	}

	// Send status update (non-blocking)
	select {
	case m.statusChan <- statusMap:
	default:
		// Channel is full, skip this update
	}
}

// checkKubernetesContext monitors for Kubernetes context changes
func (m *Manager) checkKubernetesContext() {
	newContext, err := m.getCurrentKubernetesContext()
	if err != nil {
		m.logger.Error("Failed to get Kubernetes context: %v", err)
		return
	}

	m.mutex.RLock()
	currentContext := m.kubernetesContext
	m.mutex.RUnlock()

	if newContext != currentContext {
		m.logger.Info("Kubernetes context changed from %s to %s, restarting all services", 
			currentContext, newContext)
		
		m.mutex.Lock()
		m.kubernetesContext = newContext
		m.mutex.Unlock()
		
		// Restart all services in the new context
		go m.restartAllServices()
	}
}

// restartAllServices restarts all services (typically after context change)
func (m *Manager) restartAllServices() {
	m.mutex.RLock()
	services := make([]*ServiceManager, 0, len(m.services))
	for _, sm := range m.services {
		services = append(services, sm)
	}
	m.mutex.RUnlock()

	for _, sm := range services {
		if err := sm.Restart(); err != nil {
			m.logger.Error("Failed to restart service during context change: %v", err)
		}
		// Small delay between restarts to avoid overwhelming the system
		time.Sleep(100 * time.Millisecond)
	}
}

// updateKubernetesContext gets and stores the current Kubernetes context
func (m *Manager) updateKubernetesContext() error {
	context, err := m.getCurrentKubernetesContext()
	if err != nil {
		return err
	}
	m.kubernetesContext = context
	return nil
}

// getCurrentKubernetesContext retrieves the current kubectl context
func (m *Manager) getCurrentKubernetesContext() (string, error) {
	cmd := exec.Command("kubectl", "config", "current-context")
	output, err := cmd.Output()
	if err != nil {
		return "N/A", err
	}
	
	// Remove trailing newline
	context := string(output)
	if len(context) > 0 && context[len(context)-1] == '\n' {
		context = context[:len(context)-1]
	}
	
	return context, nil
}