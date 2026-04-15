package standardrouter

import (
	"net"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/time/rate"
)

type client struct {
	limiter  *rate.Limiter
	lastSeen atomic.Int64
}

func (c *client) updateSeen() {
	c.lastSeen.Store(time.Now().UnixNano())
}

func (c *client) seenAt() time.Time {
	return time.Unix(0, c.lastSeen.Load())
}

type IPRateLimiter struct {
	clients sync.Map
	rate    rate.Limit
	burst   int
}

func NewIPRateLimiter(r rate.Limit, burst int) *IPRateLimiter {
	rl := &IPRateLimiter{
		rate:  r,
		burst: burst,
	}
	go rl.cleanup()
	return rl
}

func (rl *IPRateLimiter) getLimiter(ip string) *rate.Limiter {
	val, loaded := rl.clients.Load(ip)
	if loaded {
		c := val.(*client)
		c.updateSeen()
		return c.limiter
	}

	c := &client{
		limiter: rate.NewLimiter(rl.rate, rl.burst),
	}
	c.updateSeen()
	actual, _ := rl.clients.LoadOrStore(ip, c)
	return actual.(*client).limiter
}

func (rl *IPRateLimiter) cleanup() {
	for {
		time.Sleep(time.Minute)
		rl.clients.Range(func(key, val any) bool {
			if time.Since(val.(*client).seenAt()) > 3*time.Minute {
				rl.clients.Delete(key)
			}
			return true
		})
	}
}

func (rl *IPRateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip, _, err := net.SplitHostPort(r.RemoteAddr)
		if err != nil {
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}

		if !rl.getLimiter(ip).Allow() {
			http.Error(w, "Too Many Requests", http.StatusTooManyRequests)
			return
		}

		next.ServeHTTP(w, r)
	})
}
