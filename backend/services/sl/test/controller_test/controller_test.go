package controller_test

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/durelius/pvt-app/backend/services/sl/internal/controller"
)

func TestTripEndpoint_MissingParams(t *testing.T) {
	req := httptest.NewRequest("GET", "/trips", nil)
	w := httptest.NewRecorder()
	controller.TripEndpoint(w, req)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestTripEndpoint_InvalidFromFormat(t *testing.T) {
	req := httptest.NewRequest("GET", "/trips?from=felaktigjson&to={}", nil)
	w := httptest.NewRecorder()
	controller.TripEndpoint(w, req)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestTripEndpoint_MissingArrivalTime(t *testing.T) {
	from := url.QueryEscape(`{"street":"Drottninggatan 1","city":"Stockholm"}`)
	to := url.QueryEscape(`{"street":"Kungsgatan 5","city":"Stockholm"}`)
	testUrl := "/trips?from=" + from + "&to=" + to
	// arrivalTime saknas medvetet
	req := httptest.NewRequest("GET", testUrl, nil)
	w := httptest.NewRecorder()
	controller.TripEndpoint(w, req)
	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d\nResponse body: %s", w.Code, w.Body.String())
	}
}

func TestTripEndpoint_ValidRequest(t *testing.T) {
	from := url.QueryEscape(`{"street":"Drottninggatan 1","city":"Stockholm"}`)
	to := url.QueryEscape(`{"street":"Kungsgatan 5","city":"Stockholm"}`)
	arrivalTime := url.QueryEscape("2026-04-21T09:00:00")
	testUrl := "/trips?from=" + from + "&to=" + to + "&arrivalTime=" + arrivalTime
	req := httptest.NewRequest("GET", testUrl, nil)
	w := httptest.NewRecorder()
	controller.TripEndpoint(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d\nResponse body: %s", w.Code, w.Body.String())
	}
}
