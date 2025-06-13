//go:build windows

package utils

import (
	"fmt"
	"os/exec"
)

// StartKubectlPortForward starts a kubectl port-forward process with Windows-specific settings
func StartKubectlPortForward(namespace, target string, localPort, targetPort int) (*exec.Cmd, error) {
	args := []string{
		"port-forward",
		"-n", namespace,
		target,
		fmt.Sprintf("%d:%d", localPort, targetPort),
	}

	cmd := exec.Command("kubectl", args...)
	
	// No special process group setup needed on Windows

	err := cmd.Start()
	if err != nil {
		return nil, fmt.Errorf("failed to start kubectl port-forward: %w", err)
	}

	return cmd, nil
}