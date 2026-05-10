//go:build unix

package cli

import (
	"os/exec"
	"syscall"
)

func syscallExec(name string, args []string) error {
	bin, err := exec.LookPath(name)
	if err != nil {
		return err
	}
	return syscall.Exec(bin, append([]string{name}, args...), syscall.Environ())
}
