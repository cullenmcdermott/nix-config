package wizard

import (
	"encoding/json"
	"errors"
	"os"
	"sort"
	"time"
)

// HistoryEntry records a previously used extra mount path.
type HistoryEntry struct {
	Path     string    `json:"path"`
	LastUsed time.Time `json:"last_used"`
}

// LoadHistory reads mount history from path, returning entries sorted by
// LastUsed descending. Missing file returns an empty slice.
func LoadHistory(path string) ([]HistoryEntry, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var entries []HistoryEntry
	if err := json.Unmarshal(data, &entries); err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].LastUsed.After(entries[j].LastUsed)
	})
	return entries, nil
}

// SaveHistory writes entries to path, merging with any existing entries so
// that paths not touched in this session are preserved. New/updated entries
// overwrite existing ones by path.
func SaveHistory(path string, updated []HistoryEntry) error {
	existing, _ := LoadHistory(path) // best-effort; ignore error on read

	byPath := make(map[string]HistoryEntry, len(existing))
	for _, e := range existing {
		byPath[e.Path] = e
	}
	for _, e := range updated {
		byPath[e.Path] = e
	}

	merged := make([]HistoryEntry, 0, len(byPath))
	for _, e := range byPath {
		merged = append(merged, e)
	}
	sort.Slice(merged, func(i, j int) bool {
		return merged[i].LastUsed.After(merged[j].LastUsed)
	})

	data, err := json.MarshalIndent(merged, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o600)
}
