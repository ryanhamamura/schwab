package schwab

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

const (
	defaultBaseURL   = "https://api.schwab.com/v1/"
	defaultUserAgent = "schwab-go-client/1.0"
	defaultTimeout   = 30 * time.Second
	authEndpoint     = "oauth/token"
)

// Client manages communication with the Charles Schwab API
type Client struct {
	// HTTP client used to communicate with the API
	client *http.Client

	// Base URL for API requests
	baseURL *url.URL

	// User agent for client
	userAgent string

	// Auth credentials and tokens
	clientID     string
	clientSecret string
	accessToken  string
	tokenExpiry  time.Time
	authMutex    sync.Mutex

	// Logger function
	logger func(format string, args ...interface{})

	// API endpoints as services
	Accounts  *AccountsService
	Positions *PositionsService
	Orders    *OrdersService
	Quotes    *QuotesService
}

// NewClient returns a new Charles Schwab API client
func NewClient(clientID, clientSecret string, options ...ClientOption) *Client {
	baseURL, _ := url.Parse(defaultBaseURL)

	c := &Client{
		client:       &http.Client{Timeout: defaultTimeout},
		baseURL:      baseURL,
		userAgent:    defaultUserAgent,
		clientID:     clientID,
		clientSecret: clientSecret,
		logger:       func(format string, args ...interface{}) {}, // No-op logger by default
	}

	// Apply options
	for _, option := range options {
		option(c)
	}

	// Initialize services
	c.Accounts = &AccountsService{client: c}
	c.Positions = &PositionsService{client: c}
	c.Orders = &OrdersService{client: c}
	c.Quotes = &QuotesService{client: c}

	return c
}

// log formats and outputs a log message if logging is enabled
func (c *Client) log(format string, args ...interface{}) {
	c.logger(format, args...)
}

// Authenticate obtains or refreshes the access token
func (c *Client) Authenticate(ctx context.Context) error {
	c.authMutex.Lock()
	defer c.authMutex.Unlock()

	// Skip if we have a valid token
	if c.accessToken != "" && time.Now().Add(30*time.Second).Before(c.tokenExpiry) {
		return nil
	}

	c.log("Authenticating with Schwab API")

	data := url.Values{}
	data.Set("grant_type", "client_credentials")
	data.Set("client_id", c.clientID)
	data.Set("client_secret", c.clientSecret)

	req, err := http.NewRequestWithContext(
		ctx,
		"POST",
		c.baseURL.String()+authEndpoint,
		strings.NewReader(data.Encode()),
	)
	if err != nil {
		return fmt.Errorf("failed to create auth request: %w", err)
	}

	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Add("Accept", "application/json")
	req.Header.Add("User-Agent", c.userAgent)

	resp, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("auth request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read auth response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%w: %s (status code: %d)",
			ErrAuthentication, string(body), resp.StatusCode)
	}

	var authResp struct {
		AccessToken string `json:"access_token"`
		TokenType   string `json:"token_type"`
		ExpiresIn   int    `json:"expires_in"`
	}

	err = json.Unmarshal(body, &authResp)
	if err != nil {
		return fmt.Errorf("failed to parse auth response: %w", err)
	}

	if authResp.AccessToken == "" {
		return fmt.Errorf("%w: empty access token", ErrAuthentication)
	}

	c.accessToken = authResp.AccessToken
	c.tokenExpiry = time.Now().Add(time.Duration(authResp.ExpiresIn) * time.Second)
	c.log("Authentication successful, token expires at %s", c.tokenExpiry)

	return nil
}

// NewRequest creates an API request with proper headers
func (c *Client) NewRequest(ctx context.Context, method, urlStr string, body interface{}) (*http.Request, error) {
	// Ensure we have a valid token
	if err := c.Authenticate(ctx); err != nil {
		return nil, err
	}

	rel, err := url.Parse(urlStr)
	if err != nil {
		return nil, fmt.Errorf("invalid URL: %w", err)
	}

	u := c.baseURL.ResolveReference(rel)
	c.log("Creating %s request to %s", method, u.String())

	var buf io.ReadWriter
	if body != nil {
		buf = new(bytes.Buffer)
		err = json.NewEncoder(buf).Encode(body)
		if err != nil {
			return nil, fmt.Errorf("failed to encode request body: %w", err)
		}
	}

	req, err := http.NewRequestWithContext(ctx, method, u.String(), buf)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Add("Content-Type", "application/json")
	req.Header.Add("Accept", "application/json")
	req.Header.Add("Authorization", "Bearer "+c.accessToken)
	req.Header.Add("User-Agent", c.userAgent)

	return req, nil
}

// Do sends an API request and returns the API response
func (c *Client) Do(req *http.Request, v interface{}) (*http.Response, error) {
	c.log("Executing request to %s", req.URL.String())
	start := time.Now()

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	c.log("Request completed in %s with status code %d", time.Since(start), resp.StatusCode)

	// Read the body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp, fmt.Errorf("failed to read response body: %w", err)
	}

	// Check for API errors based on status code
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		apiErr := &ErrorResponse{
			Response: resp,
			Body:     string(body),
		}

		// Try to decode error response
		if err := json.Unmarshal(body, apiErr); err != nil {
			c.log("Failed to unmarshal error response: %v", err)
		}

		switch resp.StatusCode {
		case http.StatusNotFound:
			return resp, fmt.Errorf("%w: %s", ErrResourceNotFound, apiErr)
		case http.StatusBadRequest:
			return resp, fmt.Errorf("%w: %s", ErrInvalidRequest, apiErr)
		case http.StatusUnauthorized, http.StatusForbidden:
			return resp, fmt.Errorf("%w: %s", ErrPermissionDenied, apiErr)
		case http.StatusTooManyRequests:
			return resp, fmt.Errorf("%w: %s", ErrRateLimitExceeded, apiErr)
		case http.StatusInternalServerError, http.StatusBadGateway, http.StatusServiceUnavailable:
			return resp, fmt.Errorf("%w: %s", ErrServerError, apiErr)
		default:
			return resp, fmt.Errorf("API error (%d): %s", resp.StatusCode, apiErr)
		}
	}

	// If response body should be parsed
	if v != nil && len(body) > 0 {
		// Create a new Reader with our already-read body
		if err := json.Unmarshal(body, v); err != nil {
			c.log("Failed to decode response: %v", err)
			c.log("Response body: %s", string(body))
			return resp, fmt.Errorf("failed to decode response: %w", err)
		}
	}

	return resp, nil
}

// PaginationParams contains parameters for paginated list requests
type PaginationParams struct {
	Limit  int
	Offset int
}

// AddQueryParams adds pagination parameters to a URL
func (p PaginationParams) AddQueryParams(urlStr string) string {
	if p.Limit <= 0 && p.Offset <= 0 {
		return urlStr
	}

	separator := "?"
	if strings.Contains(urlStr, "?") {
		separator = "&"
	}

	params := []string{}
	if p.Limit > 0 {
		params = append(params, fmt.Sprintf("limit=%d", p.Limit))
	}
	if p.Offset > 0 {
		params = append(params, fmt.Sprintf("offset=%d", p.Offset))
	}

	return urlStr + separator + strings.Join(params, "&")
}
