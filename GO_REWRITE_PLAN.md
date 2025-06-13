# kportforward Go Rewrite Plan

## Overview

Rewrite the existing Bash-based kportforward tool in Go with a modern terminal UI, cross-platform support, and auto-update capabilities. The new tool will maintain all existing functionality while providing better performance and user experience.

## Project Setup

### Repository Structure
```
kportforward/
├── cmd/
│   └── kportforward/
│       └── main.go
├── internal/
│   ├── config/
│   │   ├── config.go
│   │   ├── embedded.go
│   │   └── merge.go
│   ├── portforward/
│   │   ├── manager.go
│   │   ├── service.go
│   │   └── kubectl.go
│   ├── ui/
│   │   ├── tui.go
│   │   ├── components.go
│   │   └── events.go
│   ├── updater/
│   │   ├── checker.go
│   │   └── downloader.go
│   └── utils/
│       ├── ports.go
│       ├── processes.go
│       └── logging.go
├── configs/
│   └── default.yaml
├── scripts/
│   ├── build.sh
│   └── release.sh
├── .github/
│   └── workflows/
│       ├── build.yml
│       └── release.yml
├── go.mod
├── go.sum
├── README.md
└── CHANGELOG.md
```

### Dependencies
- **bubbletea**: Modern TUI framework
- **lipgloss**: Styling for terminal UI
- **cobra**: CLI framework
- **viper**: Configuration management
- **go-yaml**: YAML parsing
- **client-go**: Kubernetes API client
- **logrus**: Structured logging

## Core Features

### 1. Configuration System

**Bundled Configuration:**
- Embed current 18 services from `kportforward.yaml` using Go's `embed` package
- Store in `configs/default.yaml` within the binary

**User Configuration:**
- Location: `~/.config/kportforward/config.yaml` (Unix) / `%APPDATA%/kportforward/config.yaml` (Windows)
- Additive merging with bundled config
- User config can add new services or override existing ones

**Configuration Structure:**
```go
type Config struct {
    MonitoringInterval time.Duration     `yaml:"monitoring_interval"`
    PortForwards      map[string]Service `yaml:"port_forwards"`
    UIOptions         UIConfig           `yaml:"ui_options"`
}

type Service struct {
    Target      string `yaml:"target"`
    TargetPort  int    `yaml:"target_port"`
    LocalPort   int    `yaml:"local_port"`
    Namespace   string `yaml:"namespace"`
    Type        string `yaml:"type"`
    SwaggerPath string `yaml:"swagger_path,omitempty"`
    APIPath     string `yaml:"api_path,omitempty"`
}
```

### 2. Port Forward Management

**Service Manager:**
- Manage up to 30+ concurrent port-forwards using goroutines
- Each service runs in its own goroutine with proper error handling
- Graceful shutdown with context cancellation
- Exponential backoff for failing services

**Kubectl Integration:**
- Use `client-go` for Kubernetes API interactions
- Fall back to `kubectl port-forward` command execution for compatibility
- Detect Kubernetes context changes and restart all services

**Health Monitoring:**
- Configurable monitoring interval (default: 1 second)
- Port connectivity checks using net.Dial
- Automatic restart of failed services
- Track uptime, restart counts, and last error messages

### 3. Terminal UI

**Framework:**
- Built with Bubble Tea for reactive terminal UI
- Lipgloss for styling and layout
- Support for terminal resizing and proper cleanup

**Main Screen Layout:**
```
┌─ kportforward v1.0.0 ─ Context: my-cluster ─ Update Available! ──┐
│                                                                   │
│ Services (18/18 running)  [↑↓] Navigate [Enter] Details [q] Quit  │
│                                                                   │
│ Name                 Status    Local     Target    Type    Uptime │
│ ──────────────────────────────────────────────────────────────── │
│ flyte-console       ●Running   8088      80        web     2h3m   │
│ flyte-admin-rpc     ●Running   8089      81        rpc     2h3m   │
│ flyte-admin-web     ●Failed    8081      80        web     0s     │
│ api-gateway         ●Running   8080      443       rest    1h45m  │
│ ...                                                               │
│                                                                   │
│ Last Error: flyte-admin-web: connection refused                   │
│ Monitoring: 1s intervals | Next update check: 23h                │
└───────────────────────────────────────────────────────────────────┘
```

**UI Features:**
- Real-time status updates without flickering
- Color-coded status indicators (green=running, red=failed, yellow=starting)
- Sortable columns (by name, status, uptime)
- Status bar with context info and update notifications
- Keyboard navigation with arrow keys
- Responsive layout that adapts to terminal size

**Status Indicators:**
- ● Running (green)
- ● Failed (red)  
- ● Starting (yellow)
- ● Cooldown (orange)

### 4. Auto-Update System

**Update Checking:**
- Check GitHub releases API daily on startup
- Manual check via command flag or UI action
- Compare semantic versions
- Cache last check time to avoid rate limiting

**Update Process:**
- Download new binary to temporary location
- Verify checksums/signatures
- Show update notification in UI
- Prompt user to restart application
- Self-replace binary on next startup

**Implementation:**
```go
type Updater struct {
    CurrentVersion string
    RepoOwner      string
    RepoName       string
    Client         *http.Client
}

func (u *Updater) CheckForUpdates() (*Release, error)
func (u *Updater) DownloadUpdate(release *Release) error
func (u *Updater) ApplyUpdate() error
```

### 5. Cross-Platform Support

**Build Targets:**
- `darwin/amd64` (Intel Mac)
- `darwin/arm64` (Apple Silicon Mac)
- `windows/amd64` (Windows 64-bit)
- `linux/amd64` (Linux 64-bit)

**Platform Abstractions:**
- Use filepath package for cross-platform paths
- Graceful handling of process signals
- Platform-specific config directory detection
- Different executable naming (.exe suffix for Windows)

## Development Phases

### Phase 1: Core Infrastructure (Week 1-2)
- [ ] Project setup with Go modules
- [ ] Configuration system with embedded defaults
- [ ] Basic port forward manager
- [ ] Kubernetes integration
- [ ] Cross-platform build system

### Phase 2: Terminal UI (Week 2-3)
- [ ] Bubble Tea TUI setup
- [ ] Main service list view
- [ ] Real-time status updates
- [ ] Keyboard navigation
- [ ] Error handling and display

### Phase 3: Advanced Features (Week 3-4)
- [ ] Auto-update system
- [ ] gRPC UI and Swagger UI integration
- [ ] Configuration merging
- [ ] Performance optimization
- [ ] Comprehensive testing

### Phase 4: Release Preparation (Week 4)
- [ ] CI/CD pipeline setup
- [ ] Documentation
- [ ] Release automation
- [ ] Beta testing

## Build & Release

### Build Process
```bash
# Development build
go build -o bin/kportforward ./cmd/kportforward

# Release builds (all platforms)
./scripts/build.sh

# Creates:
# dist/kportforward-darwin-amd64
# dist/kportforward-darwin-arm64  
# dist/kportforward-windows-amd64.exe
# dist/kportforward-linux-amd64
```

### GitHub Actions
- **Build workflow**: Test and build on PRs
- **Release workflow**: Build and publish releases on tags
- Generate checksums and release notes
- Upload binaries to GitHub releases

### Version Management
- Semantic versioning (v1.0.0, v1.1.0, etc.)
- Embed version info at build time using ldflags
- Display version in UI and CLI

## Testing Strategy

### Unit Tests
- Configuration parsing and merging
- Port forward management logic
- Update checking and version comparison
- Utility functions

### Integration Tests
- End-to-end port forward lifecycle
- Kubernetes context switching
- Update download and verification

### Manual Testing
- Cross-platform testing on all target platforms
- UI testing in different terminal environments
- Performance testing with 30+ services

## Migration Strategy

### Data Migration
- Convert existing `kportforward.yaml` to new format if needed
- Provide migration tool or automatic detection

### User Transition
- Maintain feature parity with Bash version
- Document differences and improvements
- Provide side-by-side comparison guide

## Performance Goals

- **Startup time**: < 500ms
- **Memory usage**: < 50MB with 30 services
- **CPU usage**: < 1% during normal operation
- **UI responsiveness**: < 16ms frame updates (60fps)

## Security Considerations

- No sensitive data stored in plaintext
- Verify update checksums/signatures
- Proper cleanup of temporary files
- Secure handling of kubectl credentials

## Success Metrics

- **Functionality**: All existing Bash features working
- **Performance**: 2x faster startup, lower resource usage
- **Usability**: Modern UI with keyboard navigation
- **Reliability**: Auto-updates working across platforms
- **Maintainability**: Well-structured Go codebase

## Future Enhancements (Post-v1.0)

- Interactive service management (add/remove/restart)
- Configuration profiles for different environments
- Plugin system for custom UI handlers
- Metrics export to monitoring systems
- Service discovery integration
- Dark/light theme support