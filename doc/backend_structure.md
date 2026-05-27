# Backend Structure

```
pvt-app/
│
├── go.mod                            # Go module root (github.com/durelius/pvt-app)
├── go.sum
│
├── backend/
│   │
│   ├── api-gateway/                  # Reverse proxy — single entry point (:8080)
│   │   ├── .air.toml                 # Hot-reload config (air)
│   │   └── app/
│   │       └── main.go               # CORS middleware, dynamic reverse proxy to services
│   │
│   ├── services/
│   │   │
│   │   ├── auth/                     # Auth service placeholder (:8081)
│   │   │   ├── .air.toml
│   │   │   ├── app/
│   │   │   │   └── main.go           # /health + /example endpoints
│   │   │   └── internal/
│   │   │       ├── middleware/
│   │   │       │   └── auth.go       # (legacy) auth middleware
│   │   │       └── router/
│   │   │           └── init.go       # (legacy) router init
│   │   │
│   │   ├── middle/                   # Core feature service (:8082)
│   │   │   ├── .air.toml
│   │   │   ├── app/
│   │   │   │   └── main.go           # Loads SL graph, registers /middleplaces
│   │   │   ├── data/                 # Static GTFS data for SL transit graph
│   │   │   │   ├── sl_agency.csv
│   │   │   │   ├── sl_routes.csv
│   │   │   │   ├── sl_stop_times.csv
│   │   │   │   ├── sl_stops.csv
│   │   │   │   └── sl_trips.csv
│   │   │   ├── internal/
│   │   │   │   ├── controller/
│   │   │   │   │   └── middle.go     # HTTP handler for /middleplaces
│   │   │   │   ├── graph/
│   │   │   │   │   ├── sl_graph.go   # In-memory SL transit graph
│   │   │   │   │   ├── sl_data.go    # Loads GTFS CSVs into graph
│   │   │   │   │   ├── sl_models.go  # GTFS data models
│   │   │   │   │   ├── calculate.go  # Dijkstra shortest-path
│   │   │   │   │   ├── search.go     # Graph search helpers
│   │   │   │   │   ├── slapi.go      # SL Journey Planner API client
│   │   │   │   │   ├── edge.go       # Graph edge model
│   │   │   │   │   ├── vertex.go     # Graph vertex model
│   │   │   │   │   └── errors.go     # Graph-specific errors
│   │   │   │   ├── middle/
│   │   │   │   │   └── middle.go     # Average() and Median() midpoint calc
│   │   │   │   ├── places/
│   │   │   │   │   └── nearby.go     # Google Places API + Overpass/OSM fallback
│   │   │   │   └── priority_queue/
│   │   │   │       └── model.go      # Min-heap for Dijkstra
│   │   │   └── test/
│   │   │       ├── geocoding_test/
│   │   │       │   └── geocoding_test.go
│   │   │       ├── graph_test/
│   │   │       │   └── graph_test.go
│   │   │       └── middle_test/
│   │   │           └── middle_test.go
│   │   │
│   │   ├── sl/                       # SL trip search service (:8083)
│   │   │   ├── .air.toml
│   │   │   ├── app/
│   │   │   │   └── main.go           # /trip and /trips endpoints
│   │   │   ├── internal/
│   │   │   │   ├── controller/
│   │   │   │   │   └── trip.go       # TripEndpoint handler
│   │   │   │   └── searchaddress/
│   │   │   │       └── slsearchadress.go  # SL address search API client
│   │   │   └── test/
│   │   │       ├── controller_test/
│   │   │       │   └── controller_test.go
│   │   │       └── search_test/
│   │   │           └── slsearchaddress_test.go
│   │   │
│   │   ├── signinverification/       # Google Sign-In token verifier
│   │   │   ├── .air.toml
│   │   │   ├── app/
│   │   │   │   └── main.go           # /verify-google-signin endpoint
│   │   │   └── internal/
│   │   │       ├── controller/
│   │   │       │   └── verifygooglesignin.go  # HTTP handler
│   │   │       └── verifyer/
│   │   │           └── googleverifyer.go      # Google ID token validation
│   │   │
│   │   └── user/                     # User + friends service (:8084)
│   │       ├── app/
│   │       │   └── main.go           # Registers all user/friend/home endpoints
│   │       └── internal/
│   │           ├── controller/
│   │           │   ├── login.go      # POST /login — Google Sign-In entry
│   │           │   ├── profile.go    # User profile endpoints
│   │           │   ├── friends.go    # Friend request / accept / decline / list
│   │           │   └── search.go     # GET /search — find users
│   │           ├── googleauth/
│   │           │   └── googleauth.go # Google OAuth helpers for user service
│   │           └── repository/
│   │               ├── user_repo.go  # DB queries for users
│   │               └── friend_repo.go # DB queries for friendships
│   │
│   └── shared/                       # Code shared across all services
│       ├── db/
│       │   └── db.go                 # PostgreSQL connection via sqlx
│       ├── models/
│       │   ├── user.go               # User struct
│       │   ├── location/
│       │   │   └── location.go       # Point and Address structs
│       │   └── geocoding/
│       │       └── nominatim.go      # Nominatim geocoding response model
│       └── router/
│           ├── standard_router.go    # Init() and Start() — mux setup, health, rate limit
│           ├── auth_middleware.go    # Bearer token validation, UserClaims context injection
│           └── rate_limiter.go       # Per-IP token bucket rate limiter
```
