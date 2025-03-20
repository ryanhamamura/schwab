package schwab

import (
	"errors"
	"fmt"
	"net/http"
)

// Common errors
var (
	ErrAuthentication    = errors.New("authentication failed")
	ErrInvalidRequest    = errors.New("invalid request")
	ErrResourceNotFound  = errors.New("resource not found")
	ErrServerError       = errors.New("server error")
	ErrRateLimitExceeded = errors.New("rate limit exceeded")
	ErrPermissionDenied  = errors.New("permission denied")
)

// ErrorResponse represents an error response from the Schwab API
type ErrorResponse struct {
	Response *http.Response
	Message  string `json:"message"`
	Code     string `json:"code"`
	Body     string `json:"-"` // Raw response body
}

func (e *ErrorResponse) Error() string {
	if e.Message != "" {
		return fmt.Sprintf("%v %v: %d %v (code: %v)",
			e.Response.Request.Method,
			e.Response.Request.URL,
			e.Response.StatusCode,
			e.Message,
			e.Code,
		)
	}
	return fmt.Sprintf("%v %v: %d %v",
		e.Response.Request.Method,
		e.Response.Request.URL,
		e.Response.StatusCode,
		e.Body,
	)
}
