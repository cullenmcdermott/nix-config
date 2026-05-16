package mutagen

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os/exec"
)

// Runner abstracts `mutagen` invocations so tests can stub it.
type Runner interface {
	Output(ctx context.Context, stdin io.Reader, args ...string) ([]byte, error)
}

type realRunner struct {
	bin string
}

func NewRunner(bin string) Runner {
	if bin == "" {
		bin = "mutagen"
	}
	return &realRunner{bin: bin}
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
		return nil, fmt.Errorf("%s %v: %w (%s)", r.bin, args, err, stderr.String())
	}
	return stdout.Bytes(), nil
}
