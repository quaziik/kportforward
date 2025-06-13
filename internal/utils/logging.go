package utils

import (
	"fmt"
	"log"
	"os"
	"time"
)

// Logger represents a simple logger for the application
type Logger struct {
	*log.Logger
	level LogLevel
}

// LogLevel represents different logging levels
type LogLevel int

const (
	LevelDebug LogLevel = iota
	LevelInfo
	LevelWarn
	LevelError
)

var logLevelNames = map[LogLevel]string{
	LevelDebug: "DEBUG",
	LevelInfo:  "INFO",
	LevelWarn:  "WARN",
	LevelError: "ERROR",
}

// NewLogger creates a new logger instance
func NewLogger(level LogLevel) *Logger {
	return &Logger{
		Logger: log.New(os.Stdout, "", 0),
		level:  level,
	}
}

// logf formats and logs a message at the specified level
func (l *Logger) logf(level LogLevel, format string, args ...interface{}) {
	if level < l.level {
		return
	}

	timestamp := time.Now().Format("2006-01-02 15:04:05")
	levelName := logLevelNames[level]
	message := fmt.Sprintf(format, args...)
	
	l.Printf("[%s] %s: %s", timestamp, levelName, message)
}

// Debug logs a debug message
func (l *Logger) Debug(format string, args ...interface{}) {
	l.logf(LevelDebug, format, args...)
}

// Info logs an info message
func (l *Logger) Info(format string, args ...interface{}) {
	l.logf(LevelInfo, format, args...)
}

// Warn logs a warning message
func (l *Logger) Warn(format string, args ...interface{}) {
	l.logf(LevelWarn, format, args...)
}

// Error logs an error message
func (l *Logger) Error(format string, args ...interface{}) {
	l.logf(LevelError, format, args...)
}

// SetLevel changes the logging level
func (l *Logger) SetLevel(level LogLevel) {
	l.level = level
}

// FormatUptime formats a duration as a human-readable uptime string
func FormatUptime(duration time.Duration) string {
	if duration < time.Minute {
		return fmt.Sprintf("%ds", int(duration.Seconds()))
	} else if duration < time.Hour {
		return fmt.Sprintf("%dm", int(duration.Minutes()))
	} else if duration < 24*time.Hour {
		hours := int(duration.Hours())
		minutes := int(duration.Minutes()) % 60
		return fmt.Sprintf("%dh%dm", hours, minutes)
	} else {
		days := int(duration.Hours()) / 24
		hours := int(duration.Hours()) % 24
		return fmt.Sprintf("%dd%dh", days, hours)
	}
}