package config

import (
	"errors"
	"fmt"
	"os"

	"github.com/pelletier/go-toml/v2"
)

func LoadGlobal(path string) (Global, error) {
	g := DefaultGlobal()
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return g, nil
	}
	if err != nil {
		return g, fmt.Errorf("read %s: %w", path, err)
	}
	if err := toml.Unmarshal(b, &g); err != nil {
		return g, fmt.Errorf("parse %s: %w", path, err)
	}
	return g, nil
}

func LoadPerVM(path string) (PerVM, error) {
	var v PerVM
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return v, nil
	}
	if err != nil {
		return v, fmt.Errorf("read %s: %w", path, err)
	}
	if err := toml.Unmarshal(b, &v); err != nil {
		return v, fmt.Errorf("parse %s: %w", path, err)
	}
	return v, nil
}

func SavePerVM(path string, v PerVM) error {
	b, err := toml.Marshal(v)
	if err != nil {
		return err
	}
	return os.WriteFile(path, b, 0o644)
}

// LoadResolved merges global + per-VM. perVMPath="" means no per-VM override.
func LoadResolved(globalPath, perVMPath string) (Resolved, error) {
	g, err := LoadGlobal(globalPath)
	if err != nil {
		return Resolved{}, err
	}
	v, err := LoadPerVM(perVMPath)
	if err != nil {
		return Resolved{}, err
	}
	return Resolved{
		CPUs:      pick(v.CPUs, g.CPUs),
		MemoryGiB: pick(v.MemoryGiB, g.MemoryGiB),
		DiskGiB:   pick(v.DiskGiB, g.DiskGiB),
		Arch:      pickStr(v.Arch, g.Arch),
		Agent:     pickStr(v.Agent, g.Agent),
		Mounts:    v.Mounts, // global has no mounts
	}, nil
}

func pick(a, b int) int {
	if a != 0 {
		return a
	}
	return b
}

func pickStr(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
