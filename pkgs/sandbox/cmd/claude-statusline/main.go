// claude-statusline renders a starship-style status line for Claude Code.
//
// Claude pipes JSON session data to stdin; this binary parses it and writes
// ANSI-formatted output to stdout.  It is a static Go binary with zero
// runtime dependencies — the same build works on macOS hosts and Linux VMs.
//
// Line 1: model ─ branch ─ tokens/total  ctx-bar  · $cost
// Line 2: 5h usage bar · weekly usage bar
// Line 3: reset times
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

// ── ANSI colors (starship-inspired palette) ──────────────────────────────────

const (
	cBlue   = "\033[38;2;82;139;255m"
	cPurple = "\033[38;2;187;154;255m"
	cCyan   = "\033[38;2;86;211;232m"
	cGreen  = "\033[38;2;80;250;123m"
	cOrange = "\033[38;2;255;176;85m"
	cRed    = "\033[38;2;255;85;85m"
	cYellow = "\033[38;2;241;250;140m"
	cDim    = "\033[38;2;118;118;118m"
	cReset  = "\033[0m"
	cBold   = "\033[1m"
)

// ── Nerd Font icons ──────────────────────────────────────────────────────────

const (
	iconModel    = ""
	iconDir      = "\033[38;2;82;139;255m"
	iconGit      = "\033[38;2;187;154;255m"
	iconCost     = "\033[38;2;241;250;140m"
	iconInterval = "\033[38;2;86;211;232m"
	iconWeekly   = "\033[38;2;187;154;255m"
	iconReset    = "\033[38;2;86;211;232m"
)

// Segment separators.
var (
	seg  = cDim + " · " + cReset
	segd = cDim + " ─ " + cReset
)

const usageCacheTTL = 60 * time.Second

// ── Claude session JSON shape ────────────────────────────────────────────────

type claudeInput struct {
	Model struct {
		DisplayName string `json:"display_name"`
	} `json:"model"`
	ContextWindow struct {
		Size    int     `json:"context_window_size"`
		UsedPct float64 `json:"used_percentage"`
		Current struct {
			Input         int `json:"input_tokens"`
			Output        int `json:"output_tokens"`
			CacheCreation int `json:"cache_creation_input_tokens"`
			CacheRead     int `json:"cache_read_input_tokens"`
		} `json:"current_usage"`
	} `json:"context_window"`
	Cwd       string `json:"cwd"`
	Workspace struct {
		CurrentDir string `json:"current_dir"`
	} `json:"workspace"`
	Cost struct {
		Total float64 `json:"total_cost_usd"`
	} `json:"cost"`
}

type usageData struct {
	FiveHour period `json:"five_hour"`
	SevenDay period `json:"seven_day"`
}

type period struct {
	Utilization float64 `json:"utilization"`
	ResetsAt    string  `json:"resets_at"`
}

// ── Entry point ──────────────────────────────────────────────────────────────

func main() {
	data, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Println("Claude")
		return
	}

	var in claudeInput
	if err := json.Unmarshal(data, &in); err != nil {
		fmt.Println("Claude")
		return
	}

	model := in.Model.DisplayName
	if model == "" {
		model = "Unknown"
	}

	cwd := in.Cwd
	if cwd == "" {
		cwd = in.Workspace.CurrentDir
	}
	if cwd == "" {
		cwd = "~"
	}

	// Directory basename for display.
	dirName := filepath.Base(cwd)
	if dirName == "." || dirName == "/" {
		dirName = cwd
	}
	cwdSeg := segd + iconDir + cBlue + dirName + cReset

	tokens := in.ContextWindow.Current.Input +
		in.ContextWindow.Current.Output +
		in.ContextWindow.Current.CacheCreation +
		in.ContextWindow.Current.CacheRead

	// Git branch (best-effort).
	gitSeg := ""
	if branch := gitBranch(cwd); branch != "" {
		gitSeg = segd + iconGit + cPurple + cBold + branch + cReset
	}

	// Session cost.
	costSeg := ""
	if in.Cost.Total > 0 {
		costSeg = fmt.Sprintf("%s%s$%s%s%.4f%s",
			seg, iconCost, cReset, cYellow, in.Cost.Total, cReset)
	}

	// ── Line 1: model ─  cwd ─  branch ─ tokens/total ctx-bar · $cost
	fmt.Printf("%s%s%s%s%s%s%s%s%s/%s%s%s %s%s\n",
		iconModel, cBlue, cBold, model, cReset,
		cwdSeg,
		gitSeg,
		segd,
		fmtTokens(tokens),
		cOrange, fmtTokens(in.ContextWindow.Size), cReset,
		contextBar(in.ContextWindow.UsedPct),
		costSeg,
	)

	// ── Lines 2–3: API usage (best-effort) ───────────────────────────────
	if u := getUsage(); u != nil {
		fiveBar := usageBar(u.FiveHour.Utilization)
		weekBar := usageBar(u.SevenDay.Utilization)
		fiveReset := fmtReset(u.FiveHour.ResetsAt)
		weekReset := fmtReset(u.SevenDay.ResetsAt)

		fmt.Printf("%s%s5h:%s %s %s%.0f%%%s%s%s%sweekly:%s %s %s%.0f%%%s\n",
			iconInterval, cDim, cReset,
			fiveBar, cCyan, u.FiveHour.Utilization, cReset,
			seg,
			iconWeekly, cDim, cReset,
			weekBar, cCyan, u.SevenDay.Utilization, cReset,
		)

		fmt.Printf("%s%s%s%s%s%s%sweekly:%s %s%s%s\n",
			iconReset, cCyan, fiveReset, cReset,
			seg,
			iconReset, cDim, cReset,
			cCyan, weekReset, cReset,
		)
	}
}

// ── Formatting helpers ───────────────────────────────────────────────────────

// fmtTokens renders a token count with k/m suffixes.
func fmtTokens(n int) string {
	switch {
	case n >= 1_000_000:
		return fmt.Sprintf("%.1fm", float64(n)/1_000_000)
	case n >= 1_000:
		if n%1000 == 0 {
			return fmt.Sprintf("%dk", n/1000)
		}
		return fmt.Sprintf("%.1fk", float64(n)/1_000)
	default:
		return strconv.Itoa(n)
	}
}

// contextBar renders a 10-wide bar with percentage label.
// Thresholds: green < 40%, yellow 40–75%, red ≥ 75%.
func contextBar(pct float64) string {
	const width = 10
	pi := int(math.Round(pct))
	filled := clamp(pi*width/100, 0, width)

	color := cGreen
	switch {
	case pi >= 75:
		color = cRed
	case pi >= 40:
		color = cYellow
	}

	return fmt.Sprintf("%s%.0f%% %s%s%s",
		color, pct,
		strings.Repeat("●", filled),
		strings.Repeat("○", width-filled),
		cReset,
	)
}

// usageBar renders a 10-wide bar WITHOUT the percentage label.
// Thresholds: green < 50%, orange 50–70%, yellow 70–90%, red ≥ 90%.
func usageBar(pct float64) string {
	const width = 10
	pi := int(math.Round(pct))
	filled := clamp(pi*width/100, 0, width)

	color := cGreen
	switch {
	case pi >= 90:
		color = cRed
	case pi >= 70:
		color = cYellow
	case pi >= 50:
		color = cOrange
	}

	return fmt.Sprintf("%s%s%s%s",
		color,
		strings.Repeat("●", filled),
		strings.Repeat("○", width-filled),
		cReset,
	)
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// ── Git ──────────────────────────────────────────────────────────────────────

func gitBranch(dir string) string {
	cmd := exec.Command("git", "-C", dir, "branch", "--show-current")
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// ── Usage API ────────────────────────────────────────────────────────────────

const usageCacheFile = "/tmp/claude-statusline-usage-cache.json"

func getUsage() *usageData {
	// Try cached data first.
	if data, err := os.ReadFile(usageCacheFile); err == nil {
		if fi, err := os.Stat(usageCacheFile); err == nil {
			if time.Since(fi.ModTime()) < usageCacheTTL {
				var u usageData
				if json.Unmarshal(data, &u) == nil {
					return &u
				}
			}
		}
	}

	// Fetch fresh data.
	token := accessToken()
	if token == "" {
		return nil
	}

	client := &http.Client{Timeout: 3 * time.Second}
	req, err := http.NewRequest("GET", "https://api.anthropic.com/api/oauth/usage", nil)
	if err != nil {
		return nil
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("anthropic-beta", "oauth-2025-04-20")

	resp, err := client.Do(req)
	if err != nil {
		return nil
	}
	defer func() { _ = resp.Body.Close() }()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil
	}

	// Validate that the response has usage data before caching.
	var raw map[string]json.RawMessage
	if json.Unmarshal(body, &raw) != nil || raw["five_hour"] == nil {
		return nil
	}

	var u usageData
	if json.Unmarshal(body, &u) != nil {
		return nil
	}

	_ = os.WriteFile(usageCacheFile, body, 0o644)
	return &u
}

// accessToken returns a Claude OAuth access token for the usage API.
// It tries, in order:
//  1. ~/.claude/.credentials.json (works on all platforms, including VMs)
//  2. macOS Keychain (host only)
func accessToken() string {
	// 1. Credentials file — written by `claude login` / `claude setup-token`.
	if home, err := os.UserHomeDir(); err == nil {
		path := filepath.Join(home, ".claude", ".credentials.json")
		if data, err := os.ReadFile(path); err == nil {
			if tok := parseCredentialsJSON(data); tok != "" {
				return tok
			}
		}
	}

	// 2. macOS Keychain — Claude Code stores OAuth tokens here on macOS.
	if runtime.GOOS == "darwin" {
		cmd := exec.Command("security", "find-generic-password",
			"-s", "Claude Code-credentials", "-w")
		if out, err := cmd.Output(); err == nil {
			var wrapper struct {
				ClaudeAiOauth struct {
					AccessToken string `json:"accessToken"`
				} `json:"claudeAiOauth"`
			}
			if json.Unmarshal(out, &wrapper) == nil && wrapper.ClaudeAiOauth.AccessToken != "" {
				return wrapper.ClaudeAiOauth.AccessToken
			}
		}
	}

	return ""
}

// parseCredentialsJSON extracts the access token from a credentials JSON blob.
// Supports both {"access_token":"..."} and {"claudeAiOauth":{"accessToken":"..."}} shapes.
func parseCredentialsJSON(data []byte) string {
	// Shape 1: {"access_token":"..."}
	var flat struct {
		AccessToken string `json:"access_token"`
		Token       string `json:"token"`
	}
	if json.Unmarshal(data, &flat) == nil {
		if flat.AccessToken != "" {
			return flat.AccessToken
		}
		if flat.Token != "" {
			return flat.Token
		}
	}
	// Shape 2: {"claudeAiOauth":{"accessToken":"..."}}
	var nested struct {
		ClaudeAiOauth struct {
			AccessToken string `json:"accessToken"`
		} `json:"claudeAiOauth"`
	}
	if json.Unmarshal(data, &nested) == nil && nested.ClaudeAiOauth.AccessToken != "" {
		return nested.ClaudeAiOauth.AccessToken
	}
	return ""
}

// ── Time formatting ──────────────────────────────────────────────────────────

// fmtReset parses an ISO 8601 / RFC 3339 timestamp and returns a local
// human-readable string like "May 11 03:04 PM".
func fmtReset(s string) string {
	if s == "" || s == "null" || s == "N/A" {
		return "N/A"
	}
	for _, layout := range []string{
		time.RFC3339,
		time.RFC3339Nano,
		"2006-01-02T15:04:05Z",
		"2006-01-02T15:04:05-07:00",
	} {
		if t, err := time.Parse(layout, s); err == nil {
			return t.Local().Format("Jan 02 03:04 PM")
		}
	}
	// Maybe it's a Unix epoch (seconds).
	if epoch, err := strconv.ParseFloat(s, 64); err == nil {
		return time.Unix(int64(epoch), 0).Local().Format("Jan 02 03:04 PM")
	}
	return "N/A"
}
