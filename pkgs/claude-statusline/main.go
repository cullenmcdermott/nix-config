// claude-statusline renders a starship-style status line for Claude Code.
//
// Claude pipes JSON session data to stdin; this binary parses it and writes
// ANSI-formatted output to stdout.  Stdlib only; shells out to git and, on
// macOS, security(1) for the OAuth token.
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

// contextBar: green < 40%, yellow 40–75%, red ≥ 75%, with a percentage label.
func contextBar(pct float64) string {
	pct = math.Round(pct)
	color := cGreen
	switch {
	case pct >= 75:
		color = cRed
	case pct >= 40:
		color = cYellow
	}
	return fmt.Sprintf("%s%.0f%% %s", color, pct, bar(pct, color))
}

// usageBar: green < 50%, orange 50–70%, yellow 70–90%, red ≥ 90%, no label.
func usageBar(pct float64) string {
	pct = math.Round(pct)
	color := cGreen
	switch {
	case pct >= 90:
		color = cRed
	case pct >= 70:
		color = cYellow
	case pct >= 50:
		color = cOrange
	}
	return bar(pct, color)
}

// bar renders a 10-wide ●/○ bar in color.
func bar(pct float64, color string) string {
	const width = 10
	filled := clamp(int(math.Round(pct))*width/100, 0, width)
	return color + strings.Repeat("●", filled) + strings.Repeat("○", width-filled) + cReset
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

// Skip caching if a private per-user directory is unavailable.
func usageCachePath() string {
	root, err := os.UserCacheDir()
	if err != nil {
		return ""
	}
	dir := filepath.Join(root, "claude-statusline")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return ""
	}
	if err := os.Chmod(dir, 0o700); err != nil {
		return ""
	}
	return filepath.Join(dir, "usage-cache.json")
}

func getUsage() *usageData {
	cacheFile := usageCachePath()
	var cached *usageData
	if fi, err := os.Stat(cacheFile); err == nil {
		if data, err := os.ReadFile(cacheFile); err == nil {
			var u usageData
			if json.Unmarshal(data, &u) == nil {
				cached = &u
				if time.Since(fi.ModTime()) < usageCacheTTL {
					return cached
				}
			}
		}
	}

	body := fetchUsage()
	if body == nil {
		// Serve stale data and bump its mtime so a failing API (429, offline,
		// expired token) is retried once per TTL instead of on every render.
		if cached != nil {
			now := time.Now()
			_ = os.Chtimes(cacheFile, now, now)
		}
		return cached
	}
	var u usageData
	if json.Unmarshal(body, &u) != nil {
		return cached
	}
	if cacheFile != "" {
		_ = os.WriteFile(cacheFile, body, 0o600)
	}
	return &u
}

// fetchUsage returns the raw usage API response, or nil on any failure.
func fetchUsage() []byte {
	token := accessToken()
	if token == "" {
		return nil
	}
	req, err := http.NewRequest("GET", "https://api.anthropic.com/api/oauth/usage", nil)
	if err != nil {
		return nil
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("anthropic-beta", "oauth-2025-04-20")

	resp, err := (&http.Client{Timeout: 3 * time.Second}).Do(req)
	if err != nil {
		return nil
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return nil
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil
	}
	// Only accept responses that actually carry usage data.
	var raw map[string]json.RawMessage
	if json.Unmarshal(body, &raw) != nil || raw["five_hour"] == nil {
		return nil
	}
	return body
}

// accessToken returns Claude Code's OAuth access token, read from
// ~/.claude/.credentials.json (Linux) or the macOS Keychain. Both hold
// {"claudeAiOauth":{"accessToken":"..."}}.
func accessToken() string {
	var data []byte
	if home, err := os.UserHomeDir(); err == nil {
		data, _ = os.ReadFile(filepath.Join(home, ".claude", ".credentials.json"))
	}
	if data == nil && runtime.GOOS == "darwin" {
		data, _ = exec.Command("security", "find-generic-password",
			"-s", "Claude Code-credentials", "-w").Output()
	}
	var creds struct {
		ClaudeAiOauth struct {
			AccessToken string `json:"accessToken"`
		} `json:"claudeAiOauth"`
	}
	_ = json.Unmarshal(data, &creds)
	return creds.ClaudeAiOauth.AccessToken
}

// ── Time formatting ──────────────────────────────────────────────────────────

// fmtReset formats an RFC 3339 timestamp (fractional seconds allowed) in
// local time, e.g. "May 11 03:04 PM".
func fmtReset(s string) string {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return "N/A"
	}
	return t.Local().Format("Jan 02 03:04 PM")
}
