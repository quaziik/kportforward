package utils

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestLoggerLevels(t *testing.T) {
	// Test different log levels
	tests := []struct {
		level LogLevel
		name  string
	}{
		{LevelDebug, "debug"},
		{LevelInfo, "info"},
		{LevelWarn, "warn"},
		{LevelError, "error"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			logger := NewLogger(tt.level)
			if logger == nil {
				t.Error("Logger should not be nil")
			}
		})
	}
}

func TestLoggerOutput(t *testing.T) {
	// Create a logger with info level
	logger := NewLogger(LevelInfo)

	// Test that logger methods don't panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("Logger method panicked: %v", r)
		}
	}()

	logger.Debug("debug message")
	logger.Info("info message")
	logger.Warn("warn message")
	logger.Error("error message")
}

func TestLoggerFormatting(t *testing.T) {
	logger := NewLogger(LevelInfo)

	// Test formatted logging
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("Formatted logging panicked: %v", r)
		}
	}()

	logger.Info("formatted message: %s %d", "test", 42)
	logger.Warn("warning with data: %v", map[string]int{"key": 123})
	logger.Error("error with multiple args: %s %s %d", "arg1", "arg2", 999)
}

func TestFormatUptime(t *testing.T) {
	tests := []struct {
		duration string
		expected string
	}{
		{"0s", "0s"},
		{"30s", "30s"},
		{"90s", "1m"},      // 90 seconds = 1 minute, rounds down
		{"3661s", "1h1m"},  // 3661 seconds = 1h1m1s, but seconds are dropped
		{"86461s", "1d0h"}, // 86461 seconds = 24h1m1s = 1d0h1m, minutes are dropped for days
	}

	for _, tt := range tests {
		t.Run(tt.duration, func(t *testing.T) {
			// Parse duration
			dur, err := parseDuration(tt.duration)
			if err != nil {
				t.Fatalf("Failed to parse duration %s: %v", tt.duration, err)
			}

			result := FormatUptime(dur)

			if result != tt.expected {
				t.Errorf("FormatUptime(%s) = %s, expected %s", tt.duration, result, tt.expected)
			}
		})
	}
}

func TestFormatUptimeNegative(t *testing.T) {
	// Test with negative duration
	dur, _ := parseDuration("-30s")
	result := FormatUptime(dur)

	// Should handle negative durations gracefully
	if result == "" {
		t.Error("FormatUptime should not return empty string for negative duration")
	}
}

// Helper function to parse duration string
func parseDuration(s string) (time.Duration, error) {
	return time.ParseDuration(s)
}

func TestFormatUptimeReadability(t *testing.T) {
	// Test that formatted output is readable
	testCases := []time.Duration{
		1 * time.Second,
		1 * time.Minute,
		1 * time.Hour,
		25 * time.Hour, // More than a day
	}

	for _, dur := range testCases {
		result := FormatUptime(dur)

		// Should not be empty
		if result == "" {
			t.Errorf("FormatUptime returned empty string for duration %v", dur)
		}

		// Should not contain only numbers
		if strings.TrimSpace(result) == "" {
			t.Errorf("FormatUptime returned only whitespace for duration %v", dur)
		}
	}
}

func TestNewLoggerWithFile(t *testing.T) {
	// Create a temporary file for testing
	tempDir := t.TempDir()
	logFile := filepath.Join(tempDir, "test.log")

	// Test creating logger with file
	logger, err := NewLoggerWithFile(LevelInfo, logFile)
	if err != nil {
		t.Fatalf("Failed to create logger with file: %v", err)
	}
	defer logger.Close()

	// Write a test message
	logger.Info("test message")

	// Verify file was created and contains content
	if _, err := os.Stat(logFile); os.IsNotExist(err) {
		t.Error("Log file was not created")
	}

	// Read file content
	content, err := os.ReadFile(logFile)
	if err != nil {
		t.Fatalf("Failed to read log file: %v", err)
	}

	if !strings.Contains(string(content), "test message") {
		t.Error("Log file does not contain expected message")
	}

	if !strings.Contains(string(content), "INFO") {
		t.Error("Log file does not contain log level")
	}
}

func TestLoggerFileAppend(t *testing.T) {
	// Create a temporary file for testing
	tempDir := t.TempDir()
	logFile := filepath.Join(tempDir, "append_test.log")

	// Create first logger and write a message
	logger1, err := NewLoggerWithFile(LevelInfo, logFile)
	if err != nil {
		t.Fatalf("Failed to create first logger: %v", err)
	}
	logger1.Info("first message")
	logger1.Close()

	// Create second logger and write another message
	logger2, err := NewLoggerWithFile(LevelInfo, logFile)
	if err != nil {
		t.Fatalf("Failed to create second logger: %v", err)
	}
	logger2.Info("second message")
	logger2.Close()

	// Read file content
	content, err := os.ReadFile(logFile)
	if err != nil {
		t.Fatalf("Failed to read log file: %v", err)
	}

	contentStr := string(content)
	if !strings.Contains(contentStr, "first message") {
		t.Error("Log file does not contain first message")
	}

	if !strings.Contains(contentStr, "second message") {
		t.Error("Log file does not contain second message")
	}
}

func TestLoggerWithInvalidFile(t *testing.T) {
	// Try to create logger with invalid file path
	_, err := NewLoggerWithFile(LevelInfo, "/invalid/path/that/does/not/exist/test.log")
	if err == nil {
		t.Error("Expected error when creating logger with invalid file path")
	}
}

func TestLoggerClose(t *testing.T) {
	// Test closing a stdout logger (should not error)
	logger := NewLogger(LevelInfo)
	err := logger.Close()
	if err != nil {
		t.Errorf("Unexpected error closing stdout logger: %v", err)
	}

	// Test closing a file logger
	tempDir := t.TempDir()
	logFile := filepath.Join(tempDir, "close_test.log")

	fileLogger, err := NewLoggerWithFile(LevelInfo, logFile)
	if err != nil {
		t.Fatalf("Failed to create file logger: %v", err)
	}

	err = fileLogger.Close()
	if err != nil {
		t.Errorf("Unexpected error closing file logger: %v", err)
	}

	// Try to close again (should not error)
	err = fileLogger.Close()
	if err != nil {
		t.Errorf("Unexpected error closing already closed logger: %v", err)
	}
}
