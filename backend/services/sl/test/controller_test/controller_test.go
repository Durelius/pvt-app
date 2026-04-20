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

func TestTripEndpoint_ValidRequest(t *testing.T) {
	from := url.QueryEscape(`{"street":"Drottninggatan 1","city":"Stockholm"}`)
	to := url.QueryEscape(`{"street":"Kungsgatan 5","city":"Stockholm"}`)
	testUrl := "/trips?from=" + from + "&to=" + to

	req := httptest.NewRequest("GET", testUrl, nil)
	w := httptest.NewRecorder()

	controller.TripEndpoint(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}
