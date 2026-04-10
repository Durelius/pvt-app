package location

type Point struct {
	Latitude  float64 `json:"lat"`
	Longitude float64 `json:"lon"`
}
type Location struct {
	Point *Point
}
