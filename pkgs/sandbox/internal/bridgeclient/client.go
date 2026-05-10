// Package bridgeclient is a small Go client for the sandbox host bridge.
// Used by the in-VM sandbox-claude wrapper.
package bridgeclient

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"time"
)

type Client struct {
	socketPath string
	token      string
}

func New(socketPath, token string) *Client {
	return &Client{socketPath: socketPath, token: token}
}

type AuthResult struct {
	Token     string
	ExpiresAt time.Time
}

func (c *Client) Auth(ctx context.Context) (AuthResult, error) {
	var rep struct {
		OK        bool      `json:"ok"`
		Token     string    `json:"token"`
		ExpiresAt time.Time `json:"expires_at"`
		Error     string    `json:"error"`
	}
	if err := c.do(ctx, map[string]any{"type": "claude.auth"}, &rep); err != nil {
		return AuthResult{}, err
	}
	if !rep.OK {
		return AuthResult{}, fmt.Errorf("bridge: %s", rep.Error)
	}
	return AuthResult{Token: rep.Token, ExpiresAt: rep.ExpiresAt}, nil
}

func (c *Client) Secret(ctx context.Context, ref string) (string, error) {
	var rep struct {
		OK    bool   `json:"ok"`
		Value string `json:"value"`
		Error string `json:"error"`
	}
	if err := c.do(ctx, map[string]any{"type": "secret.read", "ref": ref}, &rep); err != nil {
		return "", err
	}
	if !rep.OK {
		return "", fmt.Errorf("bridge: %s", rep.Error)
	}
	return rep.Value, nil
}

func (c *Client) OpenURL(ctx context.Context, url string) error {
	var rep struct {
		OK    bool   `json:"ok"`
		Error string `json:"error"`
	}
	if err := c.do(ctx, map[string]any{"type": "url.open", "url": url}, &rep); err != nil {
		return err
	}
	if !rep.OK {
		return fmt.Errorf("bridge: %s", rep.Error)
	}
	return nil
}

func (c *Client) do(ctx context.Context, body map[string]any, reply any) error {
	body["token"] = c.token
	deadline, ok := ctx.Deadline()
	if !ok {
		deadline = time.Now().Add(15 * time.Second)
	}
	d := net.Dialer{}
	conn, err := d.DialContext(ctx, "unix", c.socketPath)
	if err != nil {
		return err
	}
	defer conn.Close()
	_ = conn.SetDeadline(deadline)
	if err := json.NewEncoder(conn).Encode(body); err != nil {
		return err
	}
	line, err := bufio.NewReader(conn).ReadBytes('\n')
	if err != nil {
		return err
	}
	return json.Unmarshal(line, reply)
}
