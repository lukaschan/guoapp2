package core

import "time"

type hongguoDanmakuItem struct {
	ID     string `json:"id"`
	Text   string `json:"text"`
	TimeMS int64  `json:"timeMs"`
}

type hongguoDanmakuPage struct {
	Items   []hongguoDanmakuItem `json:"items"`
	StartMS int64                `json:"startMs"`
	NextMS  int64                `json:"nextMs"`
	Total   int64                `json:"total"`
}

type hongguoDanmakuCacheEntry struct {
	page    hongguoDanmakuPage
	err     error
	expires time.Time
}

type hongguoDanmakuCall struct {
	done  chan struct{}
	entry hongguoDanmakuCacheEntry
}
