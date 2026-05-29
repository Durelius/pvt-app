package priority_queue

// StateKey encodes a (vertexIdx, tripID, walked) routing state as two uint32s.
// V = vertexIdx<<1 | (walked ? 1 : 0), Trip = tripID.
type StateKey struct {
	V    uint32
	Trip uint32
}

func MakeKey(vertexIdx uint32, tripID uint32, walked bool) StateKey {
	k := vertexIdx << 1
	if walked {
		k |= 1
	}
	return StateKey{V: k, Trip: tripID}
}

func (k StateKey) VertexIdx() uint32 { return k.V >> 1 }
func (k StateKey) Walked() bool      { return k.V&1 == 1 }

// Item is stored by value (no pointer) to avoid heap allocation per queue push.
type Item struct {
	Key StateKey
	G   int
	F   int
}

// PriorityQueue is a min-heap of Items ordered by F.
type PriorityQueue []Item

func (pq PriorityQueue) Len() int           { return len(pq) }
func (pq PriorityQueue) Less(i, j int) bool { return pq[i].F < pq[j].F }
func (pq PriorityQueue) Swap(i, j int)      { pq[i], pq[j] = pq[j], pq[i] }

func (pq *PriorityQueue) Push(x any) {
	*pq = append(*pq, x.(Item))
}

func (pq *PriorityQueue) Pop() any {
	old := *pq
	n := len(old)
	item := old[n-1]
	*pq = old[:n-1]
	return item
}
