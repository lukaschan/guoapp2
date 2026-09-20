package core

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
	"unicode/utf8"
)

func (engine *nativeEngine) suggestions(ctx context.Context, query string) ([]string, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return []string{}, nil
	}
	if utf8.RuneCountInString(query) > 100 {
		return nil, errors.New("搜索词过长")
	}
	address := "https://hongguoduanju.com/incent_resource/suggestion?" +
		url.Values{"app_id": {"8662"}, "query": {query}, "count": {"10"}}.Encode()
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, address, nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("Accept", "application/json")
	request.Header.Set("Referer", "https://hongguoduanju.com/")
	request.Header.Set("User-Agent", "Mozilla/5.0")
	response, err := engine.downloader.doCatalogRequestWithTimeout(request, 8_000_000_000)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 256*1024+1))
	if err != nil {
		return nil, err
	}
	if len(body) > 256*1024 {
		return nil, errors.New("联想接口返回内容过大")
	}
	if response.StatusCode != http.StatusOK {
		return nil, engine.downloader.catalogResponseError(request, response, body)
	}
	return nativeParseSuggestions(body)
}

func nativeParseSuggestions(body []byte) ([]string, error) {
	var result map[string]json.RawMessage
	if json.Unmarshal(body, &result) != nil {
		return nil, errors.New("搜索联想暂不可用")
	}
	list := result["suggest_list"]
	if len(list) == 0 {
		var data map[string]json.RawMessage
		if json.Unmarshal(result["data"], &data) == nil {
			list = data["suggest_list"]
		}
	}
	if len(list) == 0 || string(list) == "null" {
		return []string{}, nil
	}
	var entries []struct {
		Name string `json:"name"`
	}
	if json.Unmarshal(list, &entries) != nil {
		return nil, errors.New("搜索联想暂不可用")
	}
	names, seen := []string{}, map[string]bool{}
	for _, entry := range entries {
		name := strings.TrimSpace(entry.Name)
		if name != "" && !seen[name] && utf8.RuneCountInString(name) <= 200 {
			names = append(names, name)
			seen[name] = true
			if len(names) == 10 {
				break
			}
		}
	}
	return names, nil
}
