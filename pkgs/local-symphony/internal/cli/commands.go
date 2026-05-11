package cli

import (
	"github.com/cullenmcdermott/system-config/local-symphony/internal/config"
	"github.com/spf13/cobra"
)

func NewServeCmd(cfg *config.Config) *cobra.Command { return &cobra.Command{Use: "serve"} }
func NewAddCmd(cfg *config.Config) *cobra.Command  { return &cobra.Command{Use: "add"} }
func NewLsCmd(cfg *config.Config) *cobra.Command   { return &cobra.Command{Use: "ls"} }
func NewGetCmd(cfg *config.Config) *cobra.Command  { return &cobra.Command{Use: "get"} }
func NewMvCmd(cfg *config.Config) *cobra.Command   { return &cobra.Command{Use: "mv"} }
func NewNoteCmd(cfg *config.Config) *cobra.Command { return &cobra.Command{Use: "note"} }
func NewHandoffCmd(cfg *config.Config) *cobra.Command {
	return &cobra.Command{Use: "handoff"}
}
func NewDoneCmd(cfg *config.Config) *cobra.Command  { return &cobra.Command{Use: "done"} }
func NewCancelCmd(cfg *config.Config) *cobra.Command { return &cobra.Command{Use: "cancel"} }
func NewOpenCmd(cfg *config.Config) *cobra.Command   { return &cobra.Command{Use: "open"} }