package cli

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/tabwriter"

	"github.com/spf13/cobra"
	"github.com/cullenmcdermott/system-config/local-symphony/internal/config"
	"github.com/cullenmcdermott/system-config/local-symphony/internal/db"
	"github.com/cullenmcdermott/system-config/local-symphony/internal/project"
)

// RunWithStore executes a command using an injected store (for testing).
func RunWithStore(store *db.Store, cfg *config.Config, out io.Writer, args []string) error {
	root := buildRoot(cfg, func(_ *config.Config) (*db.Store, error) {
		return store, nil
	}, out)
	root.SetArgs(args)
	return root.Execute()
}

type openStoreFn func(*config.Config) (*db.Store, error)

func buildRoot(cfg *config.Config, openStore openStoreFn, out io.Writer) *cobra.Command {
	root := &cobra.Command{Use: "symphony", SilenceErrors: true, SilenceUsage: true}
	root.AddCommand(
		newAddCmdWith(cfg, openStore, out),
		newLsCmdWith(cfg, openStore, out),
		newGetCmdWith(cfg, openStore, out),
		newMvCmdWith(cfg, openStore, out),
		newNoteCmdWith(cfg, openStore, out),
		newHandoffCmdWith(cfg, openStore, out),
		newDoneCmdWith(cfg, openStore, out),
		newCancelCmdWith(cfg, openStore, out),
	)
	return root
}

func defaultOpenStore(cfg *config.Config) (*db.Store, error) {
	dbPath := filepath.Join(cfg.DataDir, "symphony.db")
	return db.Open(dbPath)
}

// Public constructors for main.go (use default store opener).

// NewServeCmd is defined in serve.go (separate file so it can be built
// without the server package when only CLI commands are needed).
func NewServeCmd(cfg *config.Config) *cobra.Command {
	return &cobra.Command{Use: "serve", Short: "Start the HTTP daemon"}
}

func NewAddCmd(cfg *config.Config) *cobra.Command {
	return newAddCmdWith(cfg, defaultOpenStore, os.Stdout)
}
func NewLsCmd(cfg *config.Config) *cobra.Command {
	return newLsCmdWith(cfg, defaultOpenStore, os.Stdout)
}
func NewGetCmd(cfg *config.Config) *cobra.Command {
	return newGetCmdWith(cfg, defaultOpenStore, os.Stdout)
}
func NewMvCmd(cfg *config.Config) *cobra.Command {
	return newMvCmdWith(cfg, defaultOpenStore, os.Stdout)
}
func NewNoteCmd(cfg *config.Config) *cobra.Command {
	return newNoteCmdWith(cfg, defaultOpenStore, os.Stdout)
}
func NewHandoffCmd(cfg *config.Config) *cobra.Command {
	return newHandoffCmdWith(cfg, defaultOpenStore, os.Stdout)
}
func NewDoneCmd(cfg *config.Config) *cobra.Command {
	return newDoneCmdWith(cfg, defaultOpenStore, os.Stdout)
}
func NewCancelCmd(cfg *config.Config) *cobra.Command {
	return newCancelCmdWith(cfg, defaultOpenStore, os.Stdout)
}
func NewOpenCmd(cfg *config.Config) *cobra.Command {
	return &cobra.Command{
		Use:   "open",
		Short: "Open the web UI in the default browser",
		RunE: func(cmd *cobra.Command, args []string) error {
			url := fmt.Sprintf("http://localhost:%d", cfg.Port)
			return exec.Command("open", url).Run()
		},
	}
}

// --- add ---

func newAddCmdWith(cfg *config.Config, open openStoreFn, out io.Writer) *cobra.Command {
	var projectSlug, desc string
	var priority int
	var state string

	cmd := &cobra.Command{
		Use:   "add TITLE",
		Short: "Create a new issue",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			store, err := open(cfg)
			if err != nil {
				return err
			}
			defer func() { _ = store.Close() }()

			if projectSlug == "" {
				projectSlug = project.Detect()
			}
			if state == "" {
				state = string(db.StateIdea)
			}
			var p *int
			if priority > 0 {
				p = &priority
			}
			issue := &db.Issue{
				ProjectSlug: projectSlug,
				Title:       strings.Join(args, " "),
				Description: desc,
				Priority:    p,
				State:       db.State(state),
			}
			if err := store.CreateIssue(issue); err != nil {
				return err
			}
			fmt.Fprintf(out, "%s  %s\n", issue.Identifier, issue.Title)
			return nil
		},
	}
	cmd.Flags().StringVarP(&projectSlug, "project", "p", "", "project slug (default: detected from cwd)")
	cmd.Flags().StringVar(&desc, "desc", "", "issue description")
	cmd.Flags().IntVar(&priority, "priority", 0, "priority 1 (high) to 4 (low)")
	cmd.Flags().StringVar(&state, "state", "", "initial state (default: idea)")
	return cmd
}

// --- ls ---

func newLsCmdWith(cfg *config.Config, open openStoreFn, out io.Writer) *cobra.Command {
	var projectSlug, state string
	var all bool
	var limit int

	cmd := &cobra.Command{
		Use:   "ls",
		Short: "List issues",
		RunE: func(cmd *cobra.Command, args []string) error {
			store, err := open(cfg)
			if err != nil {
				return err
			}
			defer func() { _ = store.Close() }()

			if !all && projectSlug == "" {
				projectSlug = project.Detect()
			}
			issues, err := store.ListIssues(db.ListIssuesOpts{
				ProjectSlug: projectSlug,
				State:       state,
				Limit:       limit,
			})
			if err != nil {
				return err
			}
			if len(issues) == 0 {
				fmt.Fprintln(out, "no issues")
				return nil
			}
			w := tabwriter.NewWriter(out, 0, 0, 2, ' ', 0)
			fmt.Fprintln(w, "ID\tSTATE\tPRI\tTITLE")
			for _, i := range issues {
				pri := "-"
				if i.Priority != nil {
					pri = fmt.Sprintf("%d", *i.Priority)
				}
				fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", i.Identifier, i.State, pri, i.Title)
			}
			return w.Flush()
		},
	}
	cmd.Flags().StringVarP(&projectSlug, "project", "p", "", "filter by project (default: detected from cwd)")
	cmd.Flags().StringVarP(&state, "state", "s", "", "filter by state")
	cmd.Flags().BoolVar(&all, "all", false, "show all projects")
	cmd.Flags().IntVar(&limit, "limit", 0, "max results")
	return cmd
}

// --- get ---

func newGetCmdWith(cfg *config.Config, open openStoreFn, out io.Writer) *cobra.Command {
	return &cobra.Command{
		Use:   "get IDENTIFIER",
		Short: "Show full issue detail including notes",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			store, err := open(cfg)
			if err != nil {
				return err
			}
			defer func() { _ = store.Close() }()

			issue, err := store.GetIssue(args[0])
			if err != nil {
				return fmt.Errorf("issue %q not found", args[0])
			}
			fmt.Fprintf(out, "Identifier: %s\n", issue.Identifier)
			fmt.Fprintf(out, "Project:    %s\n", issue.ProjectSlug)
			fmt.Fprintf(out, "Title:      %s\n", issue.Title)
			fmt.Fprintf(out, "State:      %s\n", issue.State)
			if issue.Priority != nil {
				fmt.Fprintf(out, "Priority:   %d\n", *issue.Priority)
			}
			if issue.Description != "" {
				fmt.Fprintf(out, "\nDescription:\n%s\n", issue.Description)
			}

			notes, _ := store.ListNotes(args[0])
			events, _ := store.ListEvents(args[0])
			if len(notes)+len(events) > 0 {
				fmt.Fprintln(out, "\nActivity:")
				for _, e := range events {
					meta := ""
					if e.Metadata != "{}" {
						meta = " " + e.Metadata
					}
					fmt.Fprintf(out, "  [%s] %s: %s%s\n",
						e.CreatedAt.Format("2006-01-02 15:04"), e.Actor, e.EventType, meta)
				}
				for _, n := range notes {
					fmt.Fprintf(out, "  [%s] %s: %s\n",
						n.CreatedAt.Format("2006-01-02 15:04"), n.Author, n.Body)
				}
			}
			return nil
		},
	}
}

// --- mv ---

func newMvCmdWith(cfg *config.Config, open openStoreFn, out io.Writer) *cobra.Command {
	var actor string
	cmd := &cobra.Command{
		Use:   "mv IDENTIFIER STATE",
		Short: "Move an issue to a new state (agent cannot use done or cancelled)",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			store, err := open(cfg)
			if err != nil {
				return err
			}
			defer func() { _ = store.Close() }()

			if err := store.UpdateIssueState(args[0], db.State(args[1]), actor); err != nil {
				// No-op is a friendly success — agents that retry on
				// failure should not see a scary "invalid transition"
				// error when the issue is already in that state.
				if errors.Is(err, db.ErrNoOpTransition) {
					fmt.Fprintf(out, "%s is already %s — no-op\n", args[0], args[1])
					return nil
				}
				return err
			}
			fmt.Fprintf(out, "%s → %s\n", args[0], args[1])
			return nil
		},
	}
	cmd.Flags().StringVar(&actor, "actor", "agent", "actor making the change (human or agent id)")
	return cmd
}

// --- note ---

func newNoteCmdWith(cfg *config.Config, open openStoreFn, out io.Writer) *cobra.Command {
	var author string
	cmd := &cobra.Command{
		Use:   "note IDENTIFIER MESSAGE",
		Short: "Add a note to an issue",
		Args:  cobra.MinimumNArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			store, err := open(cfg)
			if err != nil {
				return err
			}
			defer func() { _ = store.Close() }()

			body := strings.Join(args[1:], " ")
			if err := store.AddNote(args[0], author, body); err != nil {
				return err
			}
			fmt.Fprintf(out, "note added to %s\n", args[0])
			return nil
		},
	}
	cmd.Flags().StringVar(&author, "author", "agent", "note author")
	return cmd
}

// --- handoff ---

func newHandoffCmdWith(cfg *config.Config, open openStoreFn, out io.Writer) *cobra.Command {
	return &cobra.Command{
		Use:   "handoff IDENTIFIER [STATUS_NOTE]",
		Short: "Checkpoint mid-task: write a note, move to paused, print resume prompt",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			store, err := open(cfg)
			if err != nil {
				return err
			}
			defer func() { _ = store.Close() }()

			identifier := args[0]
			note := "Handoff checkpoint — see prior notes for context."
			if len(args) > 1 {
				note = strings.Join(args[1:], " ")
			}

			// One transaction: either both the note and the state change
			// land, or neither does. The previous two-call form could leave
			// an orphan note if the state transition failed.
			if err := store.UpdateIssueAndAddNote(identifier, db.StatePaused, "agent", note); err != nil {
				return fmt.Errorf("handoff: %w", err)
			}

			issue, _ := store.GetIssue(identifier)
			fmt.Fprintf(out, "%s is now paused.\n\n", identifier)
			fmt.Fprintf(out, "To resume in a new session:\n")
			fmt.Fprintf(out, "  symphony get %s   # read current state and notes\n", identifier)
			fmt.Fprintf(out, "  symphony mv %s in_progress --actor agent\n", identifier)
			if issue != nil {
				fmt.Fprintf(out, "\nTitle: %s\n", issue.Title)
			}
			return nil
		},
	}
}

// --- done (human-only wrapper) ---

func newDoneCmdWith(cfg *config.Config, open openStoreFn, out io.Writer) *cobra.Command {
	return &cobra.Command{
		Use:   "done IDENTIFIER",
		Short: "Mark an issue done (human action only)",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			store, err := open(cfg)
			if err != nil {
				return err
			}
			defer func() { _ = store.Close() }()

			if err := store.UpdateIssueState(args[0], db.StateDone, "human"); err != nil {
				return err
			}
			fmt.Fprintf(out, "%s → done\n", args[0])
			return nil
		},
	}
}

// --- cancel (human-only wrapper) ---

func newCancelCmdWith(cfg *config.Config, open openStoreFn, out io.Writer) *cobra.Command {
	return &cobra.Command{
		Use:   "cancel IDENTIFIER",
		Short: "Cancel an issue (human action only)",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			store, err := open(cfg)
			if err != nil {
				return err
			}
			defer func() { _ = store.Close() }()

			if err := store.UpdateIssueState(args[0], db.StateCancelled, "human"); err != nil {
				return err
			}
			fmt.Fprintf(out, "%s → cancelled\n", args[0])
			return nil
		},
	}
}