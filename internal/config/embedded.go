package config

import (
	_ "embed"
)

// Embed the default configuration file
//
//go:embed default.yaml
var DefaultConfigYAML []byte
