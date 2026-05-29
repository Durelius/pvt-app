package priority_queue

// StateKey encodes a (vertexIdx, tripID, walked) routing state as two uint32s.
// V = vertexIdx<<1 | (walked ? 1 : 0), Trip = tripID.
// Using a fixed-size struct avoids string allocation and hashing overhead.
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

type Item struct {
	key   StateKey
	g     int
	f     int
	index int
}

func NewItem(k StateKey, g, f int) *Item {
	return &Item{key: k, f: f, g: g}
}

type PriorityQueue []*Item

func (pq PriorityQueue) Len() int { return len(pq) }

func (pq PriorityQueue) Less(i, j int) bool { return pq[i].f < pq[j].f }

func (pq PriorityQueue) Swap(i, j int) {
	pq[i], pq[j] = pq[j], pq[i]
	pq[i].index = i
	pq[j].index = j
}

func (pq *PriorityQueue) Push(x any) {
	n := len(*pq)
	item := x.(*Item)
	item.index = n
	*pq = append(*pq, item)
}

func (pq *PriorityQueue) Pop() any {
	old := *pq
	n := len(old)
	item := old[n-1]
	old[n-1] = nil
	item.index = -1
	*pq = old[0 : n-1]
	return item
}

func (i *Item) Key() StateKey { return i.key }
func (i *Item) G() int        { return i.g }
func (i *Item) F() int        { return i.f }
