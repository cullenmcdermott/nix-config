package cli

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/pelletier/go-toml/v2"
	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/config"
	"github.com/cullenmcdermott/system-config/sandbox/internal/paths"
	"github.com/cullenmcdermott/system-config/sandbox/internal/vmid"
)

func newConfigCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "config",
		Short: "Show the resolved per-VM config (or edit it)",
		RunE: func(c *cobra.Command, args []string) error {
			return runConfigPrint(c)
		},
	}
	cmd.AddCommand(&cobra.Command{
		Use:   "edit",
		Short: "Open the per-VM config.toml in $EDITOR",
		RunE: func(c *cobra.Command, args []string) error {
			return runConfigEdit(c)
		},
	})
	return cmd
}

func runConfigPrint(c *cobra.Command) error {
	id, p, vp, r, err := loadResolved()
	if err != nil {
		return err
	}
	_ = id
	_ = vp
	_ = p
	b, err := toml.Marshal(r)
	if err != nil {
		return err
	}
	fmt.Fprint(c.OutOrStdout(), string(b))
	return nil
}

func runConfigEdit(c *cobra.Command) error {
	id, _, vp, r, err := loadResolved()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(vp.ConfigDir, 0o755); err != nil {
		return err
	}
	if _, err := os.Stat(vp.ConfigFile); os.IsNotExist(err) {
		v := config.PerVM{
			CPUs:      r.CPUs,
			MemoryGiB: r.MemoryGiB,
			DiskGiB:   r.DiskGiB,
			Arch:      r.Arch,
			Agent:     r.Agent,
			Mounts:    r.Mounts,
		}
		if err := config.SavePerVM(vp.ConfigFile, v); err != nil {
			return err
		}
	}
	editor := firstNonEmpty(os.Getenv("VISUAL"), os.Getenv("EDITOR"), "vi")
	cmd := exec.Command(editor, vp.ConfigFile)
	cmd.Stdin = os.Stdin
	cmd.Stdout = c.OutOrStdout()
	cmd.Stderr = c.ErrOrStderr()
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("edit %s for vm %s: %w", vp.ConfigFile, id, err)
	}
	return nil
}

func loadResolved() (vmid.ID, *paths.Paths, paths.VMPaths, config.Resolved, error) {
	id, err := vmid.ForCwd()
	if err != nil {
		return "", nil, paths.VMPaths{}, config.Resolved{}, err
	}
	p, err := paths.Resolve()
	if err != nil {
		return "", nil, paths.VMPaths{}, config.Resolved{}, err
	}
	if err := p.EnsureDirs(); err != nil {
		return "", nil, paths.VMPaths{}, config.Resolved{}, err
	}
	vp := p.VM(string(id))
	r, err := config.LoadResolved(p.GlobalConfig, vp.ConfigFile)
	if err != nil {
		return "", nil, paths.VMPaths{}, config.Resolved{}, err
	}
	return id, p, vp, r, nil
}

func firstNonEmpty(s ...string) string {
	for _, v := range s {
		if v != "" {
			return v
		}
	}
	return ""
}
