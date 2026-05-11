package wizard

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/charmbracelet/huh"
)

// RunOptions controls history-aware behaviour of the wizard TUI.
type RunOptions struct {
	// History is the ordered list of previously used extra mount paths (most
	// recent first). Entries matching CurrentPath are filtered out.
	History []HistoryEntry
	// CurrentPath is the project directory being mounted automatically; it is
	// excluded from the history list to avoid redundant selections.
	CurrentPath string
}

// Run prompts the user for the six fields, mutating f in place. Returns the
// validated form (or an error on cancel/validation failure).
func Run(f Form, opts RunOptions) (Form, error) {
	cpus := strconv.Itoa(f.CPUs)
	mem := strconv.Itoa(f.MemoryGiB)
	disk := strconv.Itoa(f.DiskGiB)
	arch := f.Arch
	agent := f.Agent
	mountsText := strings.Join(f.ExtraMounts, "\n")

	// Build history options, filtering the current project path.
	var historyOpts []huh.Option[string]
	existingSet := make(map[string]bool, len(f.ExtraMounts))
	for _, m := range f.ExtraMounts {
		existingSet[expandTilde(m)] = true
	}
	for _, e := range opts.History {
		p := expandTilde(e.Path)
		if p == opts.CurrentPath {
			continue
		}
		historyOpts = append(historyOpts, huh.NewOption(p, p))
	}

	// Pre-select history items that are already in the form's ExtraMounts.
	selectedHistory := make([]string, 0)
	for _, o := range historyOpts {
		if existingSet[o.Value] {
			selectedHistory = append(selectedHistory, o.Value)
		}
	}

	// Build the field list dynamically so the history multi-select only appears
	// when there is something to show.
	fields := []huh.Field{
		huh.NewInput().Title("CPU cores").Value(&cpus).
			Validate(intGreaterThanZero("cpus")),
		huh.NewInput().Title("Memory (GiB)").Value(&mem).
			Validate(intGreaterThanZero("memory")),
		huh.NewInput().Title("Disk (GiB)").Value(&disk).
			Validate(intGreaterThanZero("disk")),
		huh.NewSelect[string]().Title("Architecture").
			Options(
				huh.NewOption("aarch64 (Apple Silicon)", "aarch64"),
				huh.NewOption("x86_64", "x86_64"),
			).Value(&arch),
		huh.NewSelect[string]().Title("Agent").
			Options(
				huh.NewOption("claude", "claude"),
			).Value(&agent),
	}

	if len(historyOpts) > 0 {
		fields = append(fields,
			huh.NewMultiSelect[string]().
				Title("Recent extra directories (space to toggle)").
				Options(historyOpts...).
				Value(&selectedHistory),
		)
	}

	fields = append(fields,
		huh.NewText().
			Title("Additional extra mounts (one path per line; ~ is expanded)").
			Value(&mountsText),
	)

	form := huh.NewForm(huh.NewGroup(fields...))
	if err := form.Run(); err != nil {
		return Form{}, err
	}

	// Merge: history selections + new paths from text area (deduped).
	seen := make(map[string]bool)
	var merged []string
	for _, p := range selectedHistory {
		p = expandTilde(p)
		if !seen[p] {
			seen[p] = true
			merged = append(merged, p)
		}
	}
	for _, p := range splitNonEmpty(mountsText) {
		p = expandTilde(p)
		if !seen[p] {
			seen[p] = true
			merged = append(merged, p)
		}
	}

	out := Form{
		Arch:        arch,
		Agent:       agent,
		ExtraMounts: merged,
	}
	if v, err := strconv.Atoi(cpus); err == nil {
		out.CPUs = v
	}
	if v, err := strconv.Atoi(mem); err == nil {
		out.MemoryGiB = v
	}
	if v, err := strconv.Atoi(disk); err == nil {
		out.DiskGiB = v
	}

	if err := out.Validate(); err != nil {
		return out, err
	}
	return out, nil
}

func intGreaterThanZero(field string) func(string) error {
	return func(s string) error {
		v, err := strconv.Atoi(strings.TrimSpace(s))
		if err != nil {
			return fmt.Errorf("%s must be an integer", field)
		}
		if v <= 0 {
			return fmt.Errorf("%s must be > 0", field)
		}
		return nil
	}
}

func splitNonEmpty(s string) []string {
	var out []string
	for _, line := range strings.Split(s, "\n") {
		if t := strings.TrimSpace(line); t != "" {
			out = append(out, t)
		}
	}
	return out
}

// expandTilde replaces a leading ~ with the user's home directory.
func expandTilde(p string) string {
	if p == "~" {
		if home, err := os.UserHomeDir(); err == nil {
			return home
		}
		return p
	}
	if strings.HasPrefix(p, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, p[2:])
		}
	}
	return p
}
