package config

import (
	"os"
	"path/filepath"

	"github.com/pelletier/go-toml/v2"
)

type Config struct {
	Port    int    `toml:"port"`
	DataDir string `toml:"data_dir"`
}

func Load(path string) (*Config, error) {
	home, _ := os.UserHomeDir()
	cfg := &Config{
		Port:    7437,
		DataDir: filepath.Join(home, ".local", "share", "local-symphony"),
	}
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return cfg, nil
	}
	if err != nil {
		return nil, err
	}
	return cfg, toml.Unmarshal(data, cfg)
}

func DefaultPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "local-symphony", "config.toml")
}

func DefaultDataDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "local-symphony")
}