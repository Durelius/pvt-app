package graph

import (
	"log"
	"sync"
	"sync/atomic"
)

type SLGraph struct {
	vertices          map[string]*Vertex
	edges             map[string]map[string]*Edge
	verticesCount     uint32
	edgesCount        uint32
	travelCache       sync.Map // key: "startID:destID", value: int (minutes)
	skipAPIValidation bool
}

func New() *SLGraph {
	return &SLGraph{
		vertices: make(map[string]*Vertex),
		edges:    make(map[string]map[string]*Edge),
	}
}

var (
	instance *SLGraph
	once     sync.Once
)

func NewWithData() (*SLGraph, error) {
	var initErr error
	once.Do(func() {
		graph := New()
		log.Println("loading SL graph data...")
		if err := graph.init(); err != nil {
			initErr = err
			return
		}
		instance = graph
		log.Printf("SL graph loaded: %d stops, %d edges", graph.Order(), graph.Size())
	})
	if initErr != nil {
		return nil, initErr
	}
	return instance, nil
}

func Instance() *SLGraph {
	if instance == nil {
		log.Fatal("graph is nil, call NewWithData first")
	}
	return instance
}

func (graph *SLGraph) Order() uint32 { return atomic.LoadUint32(&graph.verticesCount) }
func (graph *SLGraph) Size() uint32  { return atomic.LoadUint32(&graph.edgesCount) }

// NewWithDataDir creates a fresh non-singleton graph loading CSV files from dir.
// Intended for testing — production code should use NewWithData.
// API validation is disabled to avoid real HTTP calls in tests.
func NewWithDataDir(dir string) (*SLGraph, error) {
	g := New()
	g.skipAPIValidation = true
	if err := g.initFromDir(dir); err != nil {
		return nil, err
	}
	return g, nil
}
