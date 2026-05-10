package graph

import "errors"

var (
	ErrNilVertices        = errors.New("vertices are nil")
	ErrVertexDoesNotExist = errors.New("vertex does not exist")
	ErrEdgeAlreadyExists  = errors.New("edge already exists")
	ErrDAGCycle           = errors.New("edges would create cycle")
	ErrDAGHasCycle        = errors.New("the graph contains a cycle")
)
