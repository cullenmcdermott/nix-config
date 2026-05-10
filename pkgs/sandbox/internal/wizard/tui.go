package wizard

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/charmbracelet/huh"
)

// Run prompts the user for the six fields, mutating f in place. Returns the
// validated form (or an error on cancel/validation failure).
func Run(f Form) (Form, error) {
	cpus := strconv.Itoa(f.CPUs)
	mem := strconv.Itoa(f.MemoryGiB)
	disk := strconv.Itoa(f.DiskGiB)
	arch := f.Arch
	agent := f.Agent
	mountsText := strings.Join(f.ExtraMounts, "\n")

	form := huh.NewForm(
		huh.NewGroup(
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
					huh.NewOption("codex (coming soon)", "codex"),
					huh.NewOption("omp (coming soon)", "omp"),
				).Value(&agent),
			huh.NewText().Title("Extra mounts (one absolute path per line; blank to skip)").
				Value(&mountsText),
		),
	)
	if err := form.Run(); err != nil {
		return Form{}, err
	}

	out := Form{
		Arch:        arch,
		Agent:       agent,
		ExtraMounts: splitNonEmpty(mountsText),
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
