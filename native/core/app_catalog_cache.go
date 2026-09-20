package core

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"time"
)

const nativeCatalogTTL = 15 * time.Minute

type nativeCatalogState struct {
	UpdatedAt time.Time `json:"updatedAt"`
	Page      int       `json:"page"`
	HasMore   bool      `json:"hasMore"`
}

type nativeCatalogDisk struct {
	Version  int                           `json:"version"`
	Catalogs map[string][]nativeDrama      `json:"catalogs"`
	States   map[string]nativeCatalogState `json:"states"`
}

func (engine *nativeEngine) loadCatalogCache() {
	file, err := os.Open(filepath.Join(engine.directory, "catalogs.json"))
	if err != nil {
		return
	}
	defer file.Close()
	body, err := io.ReadAll(io.LimitReader(file, (32<<20)+1))
	if err != nil || len(body) > 32<<20 {
		return
	}
	var disk nativeCatalogDisk
	if json.Unmarshal(body, &disk) == nil && disk.Version == 2 {
		if disk.Catalogs != nil {
			engine.catalogs = disk.Catalogs
		}
		if disk.States != nil {
			engine.catalogStates = disk.States
		}
		return
	}
	var legacy map[string][]nativeDrama
	if json.Unmarshal(body, &legacy) == nil && legacy != nil {
		engine.catalogs = legacy
	}
}

func (engine *nativeEngine) nativeCached(source string) nativeCatalogResult {
	source = canonicalProviderSource(source)
	engine.mu.Lock()
	defer engine.mu.Unlock()
	items := append([]nativeDrama{}, engine.catalogs[source]...)
	state, found := engine.catalogStates[source]
	age := time.Since(state.UpdatedAt)
	return nativeCatalogResult{
		Items: items, Page: max(1, state.Page), HasMore: !found || state.HasMore,
		Fresh: len(items) > 0 && !state.UpdatedAt.IsZero() && age >= 0 && age < nativeCatalogTTL,
	}
}

func mergeNativeCatalog(first, second []nativeDrama) []nativeDrama {
	items := append([]nativeDrama{}, first...)
	indices := make(map[string]int, len(items))
	for index, item := range items {
		indices[item.ID] = index
	}
	for _, item := range second {
		if index, found := indices[item.ID]; found {
			items[index] = item
		} else {
			indices[item.ID] = len(items)
			items = append(items, item)
		}
	}
	return items
}

func (engine *nativeEngine) saveCatalogCache(source string, result *nativeCatalogResult) {
	engine.mu.Lock()
	defer engine.mu.Unlock()
	previous := engine.catalogs[source]
	state := engine.catalogStates[source]
	var items []nativeDrama
	if result.Page == 1 {
		items = result.Items
		if source == sourceHongguo && len(previous) > 0 {
			fresh := make(map[string]bool, len(items))
			for _, item := range items {
				fresh[item.ID] = true
			}
			for _, item := range previous {
				if !fresh[item.ID] {
					items = append(items, item)
				}
			}
			result.Items = items
			result.Page = max(1, state.Page)
		}
	} else {
		items = mergeNativeCatalog(previous, result.Items)
	}
	if len(items) > 6000 {
		items = items[:6000]
	}
	engine.catalogs[source] = items
	state = nativeCatalogState{Page: result.Page, HasMore: result.HasMore}
	if result.Warning == "" {
		state.UpdatedAt = time.Now()
		result.Fresh = true
	}
	engine.catalogStates[source] = state
	body, err := json.Marshal(nativeCatalogDisk{Version: 2, Catalogs: engine.catalogs, States: engine.catalogStates})
	if err != nil || len(body) > 32<<20 {
		return
	}
	_ = writeNativeCacheFile(filepath.Join(engine.directory, "catalogs.json"), body)
}

func writeNativeCacheFile(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".cache-write-*")
	if err != nil {
		return err
	}
	defer os.Remove(temporary.Name())
	_, writeErr := temporary.Write(data)
	closeErr := temporary.Close()
	if writeErr != nil {
		return writeErr
	}
	if closeErr != nil {
		return closeErr
	}
	return os.Rename(temporary.Name(), path)
}
