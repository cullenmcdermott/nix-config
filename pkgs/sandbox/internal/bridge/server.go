package bridge

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"sync"
	"time"
)

// Handlers implements the three handler methods required by the bridge server.
type Handlers interface {
	Secret(ctx context.Context, ref string) (string, error)
	Open(ctx context.Context, url string) error
	Auth(ctx context.Context) (token string, expiresAt time.Time, err error)
}

// Server is a per-VM bridge daemon. It listens on a unix socket and dispatches
// validated requests to the provided Handlers.
type Server struct {
	socketPath     string
	token          string
	handlers       Handlers
	handlerTimeout time.Duration // bounds per-request handler duration; zero means no limit

	mu  sync.Mutex
	lis net.Listener
}

// NewServer creates a bridge server that will listen on socketPath. The token
// must match the one passed in each request. handlerTimeout bounds how long
// each handler call runs; zero means no per-request timeout.
func NewServer(socketPath, token string, h Handlers, handlerTimeout time.Duration) *Server {
	return &Server{socketPath: socketPath, token: token, handlers: h, handlerTimeout: handlerTimeout}
}

// Serve starts listening and handling requests until the passed context is
// cancelled or Close is called. The socket is removed when Serve returns.
func (s *Server) Serve(ctx context.Context) error {
	if err := os.RemoveAll(s.socketPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("remove socket: %w", err)
	}
	lis, err := net.Listen("unix", s.socketPath)
	if err != nil {
		return fmt.Errorf("listen: %w", err)
	}
	if err := os.Chmod(s.socketPath, 0o600); err != nil {
		_ = lis.Close()
		return fmt.Errorf("chmod: %w", err)
	}

	s.mu.Lock()
	s.lis = lis
	s.mu.Unlock()

	// Watch ctx cancellation using a derived context so we can close the
	// listener when cancelled without relying on the select loop timing.
	ctx, cancel := context.WithCancel(ctx)
	go func() {
		<-ctx.Done()
		s.mu.Lock()
		if s.lis != nil {
			_ = s.lis.Close()
			s.lis = nil
		}
		s.mu.Unlock()
		cancel()
	}()

	connCh := make(chan net.Conn, 1)
	go s.accept(lis, connCh)

	for {
		select {
		case <-ctx.Done():
			return nil
		case c, ok := <-connCh:
			if !ok {
				return nil
			}
			go s.handle(c)
		}
	}
}

func (s *Server) accept(lis net.Listener, connCh chan<- net.Conn) {
	defer close(connCh)
	for {
		c, err := lis.Accept()
		if err != nil {
			return
		}
		connCh <- c
	}
}

// Close stops the server and removes the socket file.
func (s *Server) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.lis == nil {
		return nil
	}
	err := s.lis.Close()
	s.lis = nil
	_ = os.Remove(s.socketPath)
	return err
}

// handle reads one JSON request from the connection and dispatches it.
func (s *Server) handle(c net.Conn) {
	defer c.Close()

	// Set a connection-level deadline: if the client doesn't send a complete
	// request within the timeout, the connection is closed. This prevents a
	// slow-reader or malicious client from holding the goroutine indefinitely.
	if s.handlerTimeout > 0 {
		_ = c.SetReadDeadline(time.Now().Add(s.handlerTimeout))
	}

	br := bufio.NewReader(c)

	// Read exactly one JSON request per connection.
	line, err := br.ReadBytes('\n')
	if err != nil {
		return
	}

	var req Request
	if err := json.Unmarshal(line, &req); err != nil {
		writeErr(c, "bad json: "+err.Error())
		return
	}

	// Derive a per-request context with timeout. If handlerTimeout is zero,
	// pass context.Background() (no timeout). If set, each handler call gets
	// at most handlerTimeout to complete.
	var ctx context.Context
	var cancel context.CancelFunc
	if s.handlerTimeout > 0 {
		ctx, cancel = context.WithTimeout(context.Background(), s.handlerTimeout)
	} else {
		ctx, cancel = context.WithCancel(context.Background())
	}
	defer cancel()

	s.handleRequest(ctx, c, req)
}

// handleRequest dispatches a parsed request to the appropriate handler method.
// Exported for testing without socket I/O.
func (s *Server) handleRequest(ctx context.Context, c io.Writer, req Request) {
	if req.Token != s.token {
		writeErr(c, "invalid token")
		return
	}
	switch req.Type {
	case "secret.read":
		if !strings.HasPrefix(req.Ref, "op://") {
			writeErr(c, "ref must start with op://")
			return
		}
		v, err := s.handlers.Secret(ctx, req.Ref)
		if err != nil {
			writeErr(c, err.Error())
			return
		}
		_ = json.NewEncoder(c).Encode(OKReply{OK: true, Value: v})

	case "url.open":
		if !strings.HasPrefix(req.URL, "http://") && !strings.HasPrefix(req.URL, "https://") {
			writeErr(c, "only http(s) URLs allowed")
			return
		}
		if err := s.handlers.Open(ctx, req.URL); err != nil {
			writeErr(c, err.Error())
			return
		}
		_ = json.NewEncoder(c).Encode(Reply{OK: true})

	case "claude.auth":
		tok, exp, err := s.handlers.Auth(ctx)
		if err != nil {
			writeErr(c, err.Error())
			return
		}
		_ = json.NewEncoder(c).Encode(AuthReply{OK: true, Token: tok, ExpiresAt: exp})

	default:
		writeErr(c, "unknown type: "+req.Type)
	}
}

func writeErr(w io.Writer, msg string) {
	_ = json.NewEncoder(w).Encode(Reply{OK: false, Error: msg})
}

// waitForSocketReady uses net.Dial to confirm the server is listening.
func waitForSocketReady(sockPath string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if c, err := net.Dial("unix", sockPath); err == nil {
			c.Close()
			return nil
		}
		time.Sleep(10 * time.Millisecond)
	}
	return fmt.Errorf("socket %s not reachable within %v", sockPath, timeout)
}