//go:build !windows

package utils

import (
	"fmt"
	"os/exec"
	"syscall"
)

// StartKubectlPortForward starts a kubectl port-forward process with Unix-specific settings
func StartKubectlPortForward(namespace, target string, localPort, targetPort int) (*exec.Cmd, error) {
	args := []string{
		"port-forward",
		"-n", namespace,
		target,
		fmt.Sprintf("%d:%d", localPort, targetPort),
	}

	cmd := exec.Command("kubectl", args...)

	// Set up process group for proper cleanup on Unix systems
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setpgid: true,
	}

	err := cmd.Start()
	if err != nil {
		return nil, fmt.Errorf("failed to start kubectl port-forward: %w", err)
	}

	return cmd, nil
}
