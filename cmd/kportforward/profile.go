package main

import (
	"fmt"
	"log"
	"os"
	"runtime"
	"runtime/pprof"
	"time"

	"github.com/spf13/cobra"
	"github.com/victorkazakov/kportforward/internal/config"
	"github.com/victorkazakov/kportforward/internal/portforward"
	"github.com/victorkazakov/kportforward/internal/utils"
)

var (
	cpuProfile      string
	memProfile      string
	profileDuration time.Duration
)

func init() {
	profileCmd := &cobra.Command{
		Use:   "profile",
		Short: "Run performance profiling",
		Long: `Run performance profiling to analyze CPU and memory usage.
This command runs the port forward manager for a specified duration while collecting profiling data.`,
		Run: runProfiling,
	}

	profileCmd.Flags().StringVar(&cpuProfile, "cpuprofile", "", "Write CPU profile to file")
	profileCmd.Flags().StringVar(&memProfile, "memprofile", "", "Write memory profile to file")
	profileCmd.Flags().DurationVar(&profileDuration, "duration", 30*time.Second, "Duration to run profiling")

	rootCmd.AddCommand(profileCmd)
}

func runProfiling(cmd *cobra.Command, args []string) {
	fmt.Printf("Starting performance profiling for %v\n", profileDuration)

	// Start CPU profiling if requested
	if cpuProfile != "" {
		f, err := os.Create(cpuProfile)
		if err != nil {
			log.Fatalf("Could not create CPU profile: %v", err)
		}
		defer f.Close()

		if err := pprof.StartCPUProfile(f); err != nil {
			log.Fatalf("Could not start CPU profile: %v", err)
		}
		defer pprof.StopCPUProfile()
		fmt.Printf("CPU profiling enabled, writing to %s\n", cpuProfile)
	}

	// Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize logger
	logger := utils.NewLogger(utils.LevelInfo)
	logger.Info("Starting profiling with %d services", len(cfg.PortForwards))

	// Create port forward manager
	manager := portforward.NewManager(cfg, logger)

	// Simulate workload
	simulateWorkload(manager, logger)

	// Write memory profile if requested
	if memProfile != "" {
		f, err := os.Create(memProfile)
		if err != nil {
			log.Fatalf("Could not create memory profile: %v", err)
		}
		defer f.Close()

		runtime.GC() // Force garbage collection before profiling
		if err := pprof.WriteHeapProfile(f); err != nil {
			log.Fatalf("Could not write memory profile: %v", err)
		}
		fmt.Printf("Memory profiling enabled, writing to %s\n", memProfile)
	}

	printMemoryStats()
	fmt.Println("Profiling completed successfully")
}

func simulateWorkload(manager *portforward.Manager, logger *utils.Logger) {
	fmt.Println("Simulating workload...")

	// Create a ticker to simulate monitoring
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	endTime := time.Now().Add(profileDuration)

	for time.Now().Before(endTime) {
		select {
		case <-ticker.C:
			// Simulate the work that the manager does
			status := manager.GetCurrentStatus()
			context := manager.GetKubernetesContext()

			// Simulate some processing
			processServices(status)

			_ = context // Use the context to avoid unused variable warning

		default:
			// Simulate other work
			time.Sleep(10 * time.Millisecond)
		}
	}

	fmt.Println("Workload simulation completed")
}

func processServices(status map[string]config.ServiceStatus) {
	// Simulate processing of service status
	for name, svc := range status {
		// Simulate some work with the service
		_ = fmt.Sprintf("Processing %s: %s", name, svc.Status)
	}
}

func printMemoryStats() {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	fmt.Printf("\n=== Memory Statistics ===\n")
	fmt.Printf("Allocated memory: %d KB\n", bToKb(m.Alloc))
	fmt.Printf("Total allocations: %d KB\n", bToKb(m.TotalAlloc))
	fmt.Printf("System memory: %d KB\n", bToKb(m.Sys))
	fmt.Printf("Number of GC cycles: %d\n", m.NumGC)
	fmt.Printf("Number of goroutines: %d\n", runtime.NumGoroutine())
	fmt.Printf("========================\n")
}

func bToKb(b uint64) uint64 {
	return b / 1024
}
