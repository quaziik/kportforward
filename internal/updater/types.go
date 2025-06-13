package updater

import (
	"time"
)

// Release represents a GitHub release
type Release struct {
	TagName     string    `json:"tag_name"`
	Name        string    `json:"name"`
	Body        string    `json:"body"`
	Draft       bool      `json:"draft"`
	Prerelease  bool      `json:"prerelease"`
	PublishedAt time.Time `json:"published_at"`
	Assets      []Asset   `json:"assets"`
}

// Asset represents a release asset
type Asset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
	Size               int64  `json:"size"`
	ContentType        string `json:"content_type"`
}

// UpdateInfo contains information about an available update
type UpdateInfo struct {
	Available       bool
	CurrentVersion  string
	LatestVersion   string
	ReleaseNotes    string
	DownloadURL     string
	AssetSize       int64
	PublishedAt     time.Time
}

// UpdateConfig contains configuration for the updater
type UpdateConfig struct {
	RepoOwner       string
	RepoName        string
	CurrentVersion  string
	CheckInterval   time.Duration
	LastCheckFile   string
	UpdateChannel   string // "stable" or "beta"
}

// UpdateStatus represents the current update status
type UpdateStatus int

const (
	UpdateStatusUnknown UpdateStatus = iota
	UpdateStatusCurrent
	UpdateStatusAvailable
	UpdateStatusChecking
	UpdateStatusError
)

var updateStatusNames = map[UpdateStatus]string{
	UpdateStatusUnknown:   "Unknown",
	UpdateStatusCurrent:   "Current",
	UpdateStatusAvailable: "Available",
	UpdateStatusChecking:  "Checking",
	UpdateStatusError:     "Error",
}