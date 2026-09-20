package core

import "regexp"

var rankingSourceID = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,100}$`)
