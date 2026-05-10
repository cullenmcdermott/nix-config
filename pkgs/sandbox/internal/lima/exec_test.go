package lima

import (
	"context"
	"strings"
	"testing"
)

func TestRealRunner_PassesEnvAndStdin(t *testing.T) {
	// Use `cat` as a stand-in for limactl: it just echoes stdin to stdout.
	r := NewRunner("cat")
	out, err := r.Output(context.Background(), strings.NewReader("hello"))
	if err != nil {
		t.Fatal(err)
	}
	if string(out) != "hello" {
		t.Errorf("got %q", out)
	}
}
