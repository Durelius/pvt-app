package priority_queue

type Item struct {
	value string
	g     int
	f     int
	index int
}

func NewItem(stopID string, g, f int) *Item {
	return &Item{value: stopID, f: f, g: g}
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

func (i *Item) Value() string { return i.value }
func (i *Item) G() int        { return i.g }
func (i *Item) F() int        { return i.f }
