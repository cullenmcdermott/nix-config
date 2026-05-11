package backend

import (
	"context"
	"fmt"
	"sync"
)

// Fake is an in-memory backend used by tests of higher layers.
type Fake struct {
	mu       sync.Mutex
	vms      map[VMID]Status
	LastSpec VMSpec
}

func NewFake() *Fake {
	return &Fake{vms: map[VMID]Status{}}
}

func (f *Fake) Create(_ context.Context, s VMSpec) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, ok := f.vms[s.ID]; ok {
		return fmt.Errorf("vm %s already exists", s.ID)
	}
	f.vms[s.ID] = StatusStopped
	f.LastSpec = s
	return nil
}

func (f *Fake) Start(_ context.Context, id VMID) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, ok := f.vms[id]; !ok {
		return fmt.Errorf("vm %s not found", id)
	}
	f.vms[id] = StatusRunning
	return nil
}

func (f *Fake) Stop(_ context.Context, id VMID) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, ok := f.vms[id]; !ok {
		return fmt.Errorf("vm %s not found", id)
	}
	f.vms[id] = StatusStopped
	return nil
}

func (f *Fake) Destroy(_ context.Context, id VMID) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, ok := f.vms[id]; !ok {
		return nil
	}
	f.vms[id] = StatusGone
	return nil
}

func (f *Fake) Status(_ context.Context, id VMID) (Status, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	s, ok := f.vms[id]
	if !ok {
		return StatusGone, nil
	}
	return s, nil
}

func (f *Fake) SSHConfig(_ context.Context, id VMID) (SSHConfig, error) {
	return SSHConfig{ConfigFile: "/dev/null", Host: "fake-" + string(id)}, nil
}

func (f *Fake) List(_ context.Context) ([]VMInfo, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := make([]VMInfo, 0, len(f.vms))
	for id, s := range f.vms {
		out = append(out, VMInfo{ID: id, Status: s})
	}
	return out, nil
}

// Compile-time check.
var _ Backend = (*Fake)(nil)
