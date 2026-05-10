package graph

const (
	PATH_AGENCY    = "/data/sl_agency.csv"
	PATH_ROUTES    = "/data/sl_routes.csv"
	PATH_STOPTIMES = "/data/sl_stop_times.csv"
	PATH_STOPS     = "/data/sl_stops.csv"
	PATH_TRIPS     = "/data/sl_trips.csv"
)

type Agency struct {
	AgencyID       string `csv:"agency_id"`
	AgencyName     string `csv:"agency_name"`
	AgencyURL      string `csv:"agency_url"`
	AgencyTimezone string `csv:"agency_timezone"`
	AgencyLanguage string `csv:"agency_lang"`
}

type Routes struct {
	RouteID        string `csv:"route_id"`
	AgencyID       string `csv:"agency_id"`
	RouteShortName string `csv:"route_short_name"`
	RouteLongName  string `csv:"route_long_name"`
	RouteType      string `csv:"route_type"`
	RouteURL       string `csv:"route_url"`
}

type StopTimes struct {
	TripID        string `csv:"trip_id"`
	ArrivalTime   string `csv:"arrival_time"`
	DepartureTime string `csv:"departure_time"`
	StopID        string `csv:"stop_id"`
	StopSequence  int    `csv:"stop_sequence"`
	PickupType    string `csv:"pickup_type"`
	DropOffType   string `csv:"drop_off_type"`
}

type Stop struct {
	StopID        string `csv:"stop_id"`
	StopName      string `csv:"stop_name"`
	StopNameLower string `csv:"-"`
	StopLatitude  string `csv:"stop_lat"`
	StopLongitude string `csv:"stop_lon"`
	LocationType  string `csv:"location_type"`
}

type Trips struct {
	RouteID       string `csv:"route_id"`
	ServiceID     string `csv:"service_id"`
	TripID        string `csv:"trip_id"`
	TripHeadsign  string `csv:"trip_headsign"`
	TripShortName string `csv:"trip_short_name"`
}
