package cli

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/spf13/cobra"

	"github.com/cullenmcdermott/system-config/sandbox/internal/bridge"
)

func newBridgedCmd() *cobra.Command {
	var socket, token, credentials string
	cmd := &cobra.Command{
		Use:    "bridged",
		Hidden: true,
		Short:  "Internal: run the host bridge daemon for one VM",
		RunE: func(c *cobra.Command, _ []string) error {
			ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
			defer cancel()
			h := &bridge.ProdHandlers{CredentialsPath: credentials}
			s := bridge.NewServer(socket, token, h)
			return s.Serve(ctx)
		},
	}
	cmd.Flags().StringVar(&socket, "socket", "", "unix socket path (required)")
	cmd.Flags().StringVar(&token, "token", "", "session token (required)")
	cmd.Flags().StringVar(&credentials, "credentials", os.Getenv("HOME")+"/.claude/.credentials.json", "path to Claude credentials file")
	_ = cmd.MarkFlagRequired("socket")
	_ = cmd.MarkFlagRequired("token")
	return cmd
}
