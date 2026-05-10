package lima

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os/exec"
)

// Runner abstracts `limactl` invocations so tests can stub it.
type Runner interface {
	// Output runs `limactl <args>` and returns its stdout.
	Output(ctx context.Context, stdin io.Reader, args ...string) ([]byte, error)
	// Run runs `limactl <args>`, streaming stdout/stderr to the provided writers.
	Run(ctx context.Context, stdin io.Reader, stdout, stderr io.Writer, args ...string) error
}

type realRunner struct {
	bin string
}

func NewRunner(limactlBin string) Runner {
	if limactlBin == "" {
		limactlBin = "limactl"
	}
	return &realRunner{bin: limactlBin}
}

func (r *realRunner) Output(ctx context.Context, stdin io.Reader, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, r.bin, args...)
	if stdin != nil {
		cmd.Stdin = stdin
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("%s %v: %w (stderr: %s)", r.bin, args, err, stderr.String())
	}
	return stdout.Bytes(), nil
}

func (r *realRunner) Run(ctx context.Context, stdin io.Reader, stdout, stderr io.Writer, args ...string) error {
	cmd := exec.CommandContext(ctx, r.bin, args...)
	cmd.Stdin = stdin
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	return cmd.Run()
}
