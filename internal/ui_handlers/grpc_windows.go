//go:build windows

package ui_handlers

import (
	"fmt"
	"os"
	"os/exec"
)

// startGRPCUIProcess starts the grpcui process with Windows-specific settings
func (gm *GRPCUIManager) startGRPCUIProcessPlatform(cmd *exec.Cmd, logFileHandle *os.File) error {
	cmd.Stdout = logFileHandle
	cmd.Stderr = logFileHandle

	// No special process group setup needed on Windows

	if err := cmd.Start(); err != nil {
		logFileHandle.Close()
		return fmt.Errorf("failed to start grpcui: %w", err)
	}

	return nil
}