package schwab

import (
	"net/http"
	"net/url"
	"time"
)

// ClientOption allows configuration of the Client
type ClientOption func(*Client)

// WithBaseURL sets a custom base URL for the client
func WithBaseURL(baseURL string) ClientOption {
	return func(c *Client) {
		parsedURL, err := url.Parse(baseURL)
		if err == nil {
			c.baseURL = parsedURL
		}
	}
}

// WithUserAgent sets a custom user agent for the client
func WithUserAgent(userAgent string) ClientOption {
	return func(c *Client) {
		c.userAgent = userAgent
	}
}

// WithTimeout sets a custom timeout for the HTTP client
func WithTimeout(timeout time.Duration) ClientOption {
	return func(c *Client) {
		if c.client == nil {
			c.client = &http.Client{Timeout: timeout}
		} else {
			c.client.Timeout = timeout
		}
	}
}

// WithHTTPClient sets a custom HTTP client
func WithHTTPClient(httpClient *http.Client) ClientOption {
	return func(c *Client) {
		if httpClient != nil {
			c.client = httpClient
		}
	}
}

// WithLogger enables logging with the provided function
func WithLogger(logFn func(format string, args ...interface{})) ClientOption {
	return func(c *Client) {
		c.logger = logFn
	}
}
