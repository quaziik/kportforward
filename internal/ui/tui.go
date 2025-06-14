package ui

import (
	"context"
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/victorkazakov/kportforward/internal/config"
	"github.com/victorkazakov/kportforward/internal/updater"
)

// TUI represents the terminal user interface
type TUI struct {
	program    *tea.Program
	model      *Model
	statusChan <-chan map[string]config.ServiceStatus
	ctx        context.Context
	cancel     context.CancelFunc
}

// NewTUI creates a new terminal user interface
func NewTUI(statusChan <-chan map[string]config.ServiceStatus, serviceConfigs map[string]config.Service) *TUI {
	ctx, cancel := context.WithCancel(context.Background())

	model := NewModel(statusChan, serviceConfigs)
	program := tea.NewProgram(
		model,
		tea.WithAltScreen(),       // Use alternate screen buffer
		tea.WithMouseCellMotion(), // Enable mouse support
	)

	return &TUI{
		program:    program,
		model:      model,
		statusChan: statusChan,
		ctx:        ctx,
		cancel:     cancel,
	}
}

// Start begins the TUI event loop
func (t *TUI) Start() error {
	// Start the program in a goroutine
	go func() {
		if _, err := t.program.Run(); err != nil {
			// Log error but don't exit the application
			fmt.Printf("TUI error: %v\n", err)
		}
	}()

	return nil
}

// Stop gracefully shuts down the TUI
func (t *TUI) Stop() error {
	t.cancel()
	if t.program != nil {
		t.program.Quit()
	}
	return nil
}

// UpdateKubernetesContext sends a context update to the TUI
func (t *TUI) UpdateKubernetesContext(context string) {
	if t.program != nil {
		t.program.Send(ContextUpdateMsg(context))
	}
}

// NotifyUpdateAvailable sends an update notification to the TUI
func (t *TUI) NotifyUpdateAvailable(updateInfo *updater.UpdateInfo) {
	if t.program != nil {
		t.program.Send(UpdateAvailableMsg(updateInfo != nil && updateInfo.Available))
	}
}
