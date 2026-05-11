package graph

import "sync/atomic"

type Vertex struct {
	label    string
	edges    []*Edge
	inDegree int
	metadata *Stop
}

func NewVertex(label string) *Vertex         { return &Vertex{label: label} }
func (v *Vertex) Label() string              { return v.label }
func (v *Vertex) Metadata() *Stop            { return v.metadata }
func (v *Vertex) SetMetadata(data *Stop)     { v.metadata = data }
func (v *Vertex) OutDegree() int             { return len(v.edges) }
func (v *Vertex) InDegree() int              { return v.inDegree }
func (v *Vertex) Degree() int                { return v.inDegree + len(v.edges) }
func (v *Vertex) Edges() []*Edge {
	cp := make([]*Edge, len(v.edges))
	copy(cp, v.edges)
	return cp
}

func (v *Vertex) AddEdge(edge *Edge) {
	v.edges = append(v.edges, edge)
	edge.dest.inDegree++
}

func (graph *SLGraph) AddVertex(v *Vertex) {
	if v == nil {
		return
	}
	if _, ok := graph.vertices[v.label]; ok {
		return
	}
	graph.vertices[v.label] = v
	atomic.AddUint32(&graph.verticesCount, 1)
}

func (graph *SLGraph) AddVertexByLabel(label string) *Vertex {
	v := &Vertex{label: label}
	graph.AddVertex(v)
	return v
}

func (graph *SLGraph) GetVertexByID(label string) *Vertex { return graph.vertices[label] }

func (graph *SLGraph) ContainsVertex(v *Vertex) bool {
	if v == nil {
		return false
	}
	_, ok := graph.vertices[v.label]
	return ok
}

func (graph *SLGraph) GetAllVertices() []*Vertex {
	out := make([]*Vertex, 0, len(graph.vertices))
	for _, v := range graph.vertices {
		out = append(out, v)
	}
	return out
}

func (graph *SLGraph) RemoveVertices(vertices ...*Vertex) {
	for _, v := range vertices {
		if v == nil || graph.vertices[v.label] == nil {
			continue
		}
		if destMap, ok := graph.edges[v.label]; ok {
			for _, edge := range destMap {
				edge.dest.inDegree--
			}
			delete(graph.edges, v.label)
		}
		for _, destMap := range graph.edges {
			if edge, ok := destMap[v.label]; ok {
				edge.source.edges = removeEdgeFromSlice(edge.source.edges, edge)
				delete(destMap, v.label)
			}
		}
		delete(graph.vertices, v.label)
		atomic.AddUint32(&graph.verticesCount, ^(uint32(1) - 1))
	}
}
