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

// Record is the on-disk state record. LastFailedStep is set when State is
// StateDestroyFailed to allow --recover to resume the tear-down sequence.
type Record struct {
	State          State  `json:"state"`
	LastFailedStep string `json:"last_failed_step,omitempty"`
}

func ReadRecord(path string) (Record, error) {
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return Record{State: StateNew}, nil
	}
	if err != nil {
		return Record{}, fmt.Errorf("read %s: %w", path, err)
	}
	var r Record
	if err := json.Unmarshal(b, &r); err != nil {
		return Record{}, fmt.Errorf("parse %s: %w", path, err)
	}
	return r, nil
}

func WriteRecord(path string, r Record) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	b, err := json.Marshal(r)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// onDisk exists for backwards-compat deserialization only; new code uses Record directly.
type onDisk = Record

func Read(path string) (State, error) {
	r, err := ReadRecord(path)
	return r.State, err
}

func Write(path string, s State) error {
	return WriteRecord(path, Record{State: s})
}

func Clear(path string) error {
	if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}
