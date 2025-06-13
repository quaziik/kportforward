package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/spf13/cobra"
	"github.com/victorkazakov/kportforward/internal/config"
	"github.com/victorkazakov/kportforward/internal/portforward"
	"github.com/victorkazakov/kportforward/internal/ui"
	"github.com/victorkazakov/kportforward/internal/updater"
	"github.com/victorkazakov/kportforward/internal/utils"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	var rootCmd = &cobra.Command{
		Use:   "kportforward",
		Short: "A modern Kubernetes port-forward manager",
		Long: `kportforward is a cross-platform tool for managing multiple Kubernetes port-forwards
with a modern terminal UI, automatic recovery, and built-in update system.`,
		Run: runPortForward,
	}

	rootCmd.AddCommand(&cobra.Command{
		Use:   "version",
		Short: "Print version information",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Printf("kportforward %s\n", version)
			fmt.Printf("commit: %s\n", commit)
			fmt.Printf("built: %s\n", date)
		},
	})

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runPortForward(cmd *cobra.Command, args []string) {
	// Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize logger
	logger := utils.NewLogger(utils.LevelInfo)
	logger.Info("Starting kportforward with %d services", len(cfg.PortForwards))

	// Create port forward manager
	manager := portforward.NewManager(cfg, logger)

	// Set up signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Start port forwarding
	if err := manager.Start(); err != nil {
		logger.Error("Failed to start port forwarding: %v", err)
		os.Exit(1)
	}

	// Initialize and start update manager
	updateManager := updater.NewManager("catio-tech", "kportforward", version, logger)
	if err := updateManager.Start(); err != nil {
		logger.Error("Failed to start update manager: %v", err)
		// Don't exit - updates are not critical
	}

	// Initialize and start TUI
	tui := ui.NewTUI(manager.GetStatusChannel())
	if err := tui.Start(); err != nil {
		logger.Error("Failed to start TUI: %v", err)
		os.Exit(1)
	}

	// Update TUI with initial context
	tui.UpdateKubernetesContext(manager.GetKubernetesContext())

	// Listen for update notifications
	go func() {
		updateChan := updateManager.GetUpdateChannel()
		for updateInfo := range updateChan {
			tui.NotifyUpdateAvailable(updateInfo)
		}
	}()

	// Wait for shutdown signal
	<-sigChan
	logger.Info("Received shutdown signal, stopping services...")

	// Graceful shutdown
	if err := updateManager.Stop(); err != nil {
		logger.Error("Error stopping update manager: %v", err)
	}

	if err := tui.Stop(); err != nil {
		logger.Error("Error stopping TUI: %v", err)
	}

	if err := manager.Stop(); err != nil {
		logger.Error("Error during shutdown: %v", err)
		os.Exit(1)
	}

	logger.Info("Shutdown complete")
}

func displayStatus(status map[string]config.ServiceStatus, kubeContext string) {
	fmt.Printf("\n=== kportforward Status (Context: %s) ===\n", kubeContext)
	fmt.Printf("%-25s %-10s %-8s %-8s %-10s %s\n", 
		"Service", "Status", "Local", "PID", "Uptime", "Error")
	fmt.Println(string(make([]byte, 80, 80)))

	for name, svc := range status {
		uptime := ""
		if !svc.StartTime.IsZero() {
			uptime = utils.FormatUptime(svc.StartTime.Sub(svc.StartTime))
		}

		errorMsg := svc.LastError
		if len(errorMsg) > 30 {
			errorMsg = errorMsg[:27] + "..."
		}

		fmt.Printf("%-25s %-10s %-8d %-8d %-10s %s\n",
			name, svc.Status, svc.LocalPort, svc.PID, uptime, errorMsg)
	}
}