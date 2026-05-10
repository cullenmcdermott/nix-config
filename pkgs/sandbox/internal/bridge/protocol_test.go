package bridge

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestRequest_Marshal(t *testing.T) {
	r := Request{Type: "secret.read", Token: "tok", Ref: "op://X/Y/Z"}
	b, err := json.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	s := string(b)
	for _, must := range []string{`"type":"secret.read"`, `"token":"tok"`, `"ref":"op://X/Y/Z"`} {
		if !strings.Contains(s, must) {
			t.Errorf("missing %s in %s", must, s)
		}
	}
}

func TestRequest_Unmarshal(t *testing.T) {
	blob := `{"type":"url.open","token":"tok","url":"https://example.com"}`
	var r Request
	if err := json.Unmarshal([]byte(blob), &r); err != nil {
		t.Fatal(err)
	}
	if r.Type != "url.open" {
		t.Errorf("Type = %q", r.Type)
	}
	if r.Token != "tok" {
		t.Errorf("Token = %q", r.Token)
	}
	if r.URL != "https://example.com" {
		t.Errorf("URL = %q", r.URL)
	}
}

func TestReply_Marshal(t *testing.T) {
	r := OKReply{OK: true, Value: "hello"}
	b, _ := json.Marshal(r)
	s := string(b)
	if !strings.Contains(s, `"ok":true`) {
		t.Errorf("missing ok:true in %s", s)
	}
	if !strings.Contains(s, `"value":"hello"`) {
		t.Errorf("missing value in %s", s)
	}
}

func TestErrorReply_Marshal(t *testing.T) {
	r := Reply{OK: false, Error: "boom"}
	b, _ := json.Marshal(r)
	s := string(b)
	if !strings.Contains(s, `"ok":false`) {
		t.Errorf("missing ok:false in %s", s)
	}
	if !strings.Contains(s, `"error":"boom"`) {
		t.Errorf("missing error in %s", s)
	}
}

func TestAuthReply_Marshal(t *testing.T) {
	exp := time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC)
	r := AuthReply{OK: true, Token: "jwt-token", ExpiresAt: exp}
	b, _ := json.Marshal(r)
	s := string(b)
	if !strings.Contains(s, `"ok":true`) {
		t.Errorf("missing ok:true in %s", s)
	}
	if !strings.Contains(s, `"token":"jwt-token"`) {
		t.Errorf("missing token in %s", s)
	}
	if !strings.Contains(s, "2030-01-01") {
		t.Errorf("missing expires_at in %s", s)
	}
}

func TestRequest_WithPayload(t *testing.T) {
	// The wire format uses top-level Ref/URL fields, not a nested payload map.
	r := Request{Type: "secret.read", Token: "tok", Ref: "op://Vault/Item/secret"}
	b, _ := json.Marshal(r)
	var got map[string]any
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatal(err)
	}
	if got["type"] != "secret.read" {
		t.Errorf("type = %v", got["type"])
	}
	if got["ref"] != "op://Vault/Item/secret" {
		t.Errorf("ref = %v", got["ref"])
	}
	// payload key should NOT be present (ref is top-level)
	if _, ok := got["payload"]; ok {
		t.Errorf("payload should not be in wire format for simple ref/url fields")
	}
}

func TestReply_ImplementsJSON(t *testing.T) {
	// Ensure Reply is JSON-marshalable via its fields (no extra interface).
	var r Reply
	_, err := json.Marshal(r)
	if err != nil {
		t.Fatalf("Reply marshal failed: %v", err)
	}
}