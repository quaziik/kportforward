package utils

import (
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
