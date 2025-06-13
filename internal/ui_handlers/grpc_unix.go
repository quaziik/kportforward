//go:build !windows

package ui_handlers

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

// startGRPCUIProcess starts the grpcui process with Unix-specific settings
func (gm *GRPCUIManager) startGRPCUIProcessPlatform(cmd *exec.Cmd, logFileHandle *os.File) error {
	cmd.Stdout = logFileHandle
	cmd.Stderr = logFileHandle

	// Set up process group for proper cleanup on Unix systems
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setpgid: true,
	}

	if err := cmd.Start(); err != nil {
		logFileHandle.Close()
		return fmt.Errorf("failed to start grpcui: %w", err)
	}

	return nil
}