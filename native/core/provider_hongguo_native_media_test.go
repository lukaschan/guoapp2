package core

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func newHongguoRequestTestDownloader(server *httptest.Server) *Downloader {
	return &Downloader{
		cfg:           Config{Retries: 1},
		client:        server.Client(),
		limiter:       newRequestLimiter(1, 0),
		providerHosts: map[string]string{},
	}
}

func TestHongguoVideoModelRequestOmitsLegacySignature(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != hongguoVideoModelPath {
			t.Errorf("unexpected playback request: %s %s", r.Method, r.URL.Path)
		}
		for _, name := range []string{"X-Gorgon", "X-Khronos", "X-SS-STUB", "X-SS-Req-Ticket"} {
			if value := r.Header.Get(name); value != "" {
				t.Errorf("playback request unexpectedly includes %s", name)
			}
		}
		var payload map[string]any
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			t.Errorf("decode request body: %v", err)
		}
		if payload["video_id"] != "800001" {
			t.Errorf("wrong video ID in request: %v", payload["video_id"])
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"code":0,"data":{"video_model":{"video_list":[{"main_url":"https://media.example.test/episode.mp4","video_meta":{"codec_type":"h264","definition":"1080p"}}]}}}`))
	}))
	defer server.Close()

	d := newHongguoRequestTestDownloader(server)
	d.hongguoClient().baseURL = server.URL
	media, err := d.resolveHongguoAppMedia(context.Background(), "800001")
	if err != nil {
		t.Fatal(err)
	}
	if media.URL != "https://media.example.test/episode.mp4" || media.Quality != 1080 {
		t.Fatalf("unexpected resolved playback: %+v", media)
	}
}

func TestHongguoOtherAppRequestsRemainSigned(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/novel/player/video_detail/v1/" {
			t.Errorf("unexpected detail request path: %s", r.URL.Path)
		}
		for _, name := range []string{"X-Gorgon", "X-Khronos", "X-SS-STUB", "X-SS-Req-Ticket"} {
			if value := r.Header.Get(name); value == "" {
				t.Errorf("detail request is missing %s", name)
			}
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"code":0}`))
	}))
	defer server.Close()

	d := newHongguoRequestTestDownloader(server)
	d.hongguoClient().baseURL = server.URL
	if _, err := d.hongguoAppRequest(context.Background(), http.MethodPost, "/novel/player/video_detail/v1/", nil, map[string]string{"series_id": "700001"}); err != nil {
		t.Fatal(err)
	}
}

func TestHongguoUnsignedPlaybackRequestUsesStandardDeviceHeaders(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.Header.Get("User-Agent"), "com.phoenix.read/") || r.URL.Query().Get("device_id") == "" || r.URL.Query().Get("iid") == "" {
			t.Error("unsigned playback request lost its normal App identity headers or query parameters")
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"code":0,"data":{"video_model":{"video_list":[{"main_url":"https://media.example.test/episode.mp4","video_meta":{"codec_type":"h264","definition":"720p"}}]}}}`))
	}))
	defer server.Close()

	d := newHongguoRequestTestDownloader(server)
	d.hongguoClient().baseURL = server.URL
	if _, err := d.resolveHongguoAppMedia(context.Background(), "800002"); err != nil {
		t.Fatalf("unsigned request failed: %v (at %s)", err, time.Now().Format(time.RFC3339))
	}
}
