// Package state persists the sandbox state-machine value for one VM.
//
// StateNew is implicit: a missing state file means NEW. Every other state
// transition writes a single-field JSON file.
package state

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

type State string

const (
	StateNew           State = "NEW"
	StateProvisioning  State = "PROVISIONING"
	StateStopped       State = "STOPPED"
	StateRunning       State = "RUNNING"
	StateFailed        State = "FAILED"
	StateDestroying    State = "DESTROYING"
	StateGone          State = "GONE"
	StateDestroyFailed State = "DESTROY_FAILED"
)

type onDisk struct {
	State State `json:"state"`
}

func Read(path string) (State, error) {
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return StateNew, nil
	}
	if err != nil {
		return "", fmt.Errorf("read %s: %w", path, err)
	}
	var d onDisk
	if err := json.Unmarshal(b, &d); err != nil {
		return "", fmt.Errorf("parse %s: %w", path, err)
	}
	return d.State, nil
}

func Write(path string, s State) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	b, err := json.Marshal(onDisk{State: s})
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func Clear(path string) error {
	if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}
