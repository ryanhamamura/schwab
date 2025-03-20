# Schwab API Go Client

[![Go Reference](https://pkg.go.dev/badge/github.com/yourusername/schwab.svg)](https://pkg.go.dev/github.com/yourusername/schwab)
[![Go Report Card](https://goreportcard.com/badge/github.com/yourusername/schwab)](https://goreportcard.com/report/github.com/yourusername/schwab)

A Go client library for the Charles Schwab API. This package provides a simple and idiomatic way to interact with the Charles Schwab API from Go applications.

## Features

- Complete API coverage for accounts, positions, orders, and quotes
- Authentication and token management
- Pagination support
- Comprehensive error handling
- Customizable logging
- Configurable timeouts and retries
- Thread-safe for concurrent use

## Installation

```bash
go get github.com/yourusername/schwab
```

## Quick Start

```go
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/yourusername/schwab"
)

func main() {
	// Get API credentials from environment variables
	clientID := os.Getenv("SCHWAB_CLIENT_ID")
	clientSecret := os.Getenv("SCHWAB_CLIENT_SECRET")

	if clientID == "" || clientSecret == "" {
		log.Fatal("SCHWAB_CLIENT_ID and SCHWAB_CLIENT_SECRET environment variables must be set")
	}

	// Create a new client with options
	client := schwab.NewClient(
		clientID, 
		clientSecret,
		schwab.WithTimeout(15*time.Second),
		schwab.WithLogger(log.Printf),
	)

	// Use a context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// List accounts
	accounts, err := client.Accounts.List(ctx, nil)
	if err != nil {
		log.Fatalf("Error fetching accounts: %v", err)
	}

	fmt.Printf("Found %d accounts\n", len(accounts.Accounts))
}
```

## Usage Examples

### Fetch Account Information

```go
// Get a specific account
account, err := client.Accounts.Get(ctx, "account123")
if err != nil {
	log.Fatalf("Error fetching account: %v", err)
}
fmt.Printf("Account balance: $%.2f\n", account.Balance.TotalValue)

// List all accounts with pagination
accounts, err := client.Accounts.List(ctx, &schwab.PaginationParams{
	Limit: 50,
})
if err != nil {
	log.Fatalf("Error fetching accounts: %v", err)
}
```

### Work with Portfolio Positions

```go
// List positions for an account
positions, err := client.Positions.List(ctx, "account123", &schwab.PaginationParams{
	Limit: 100,
})
if err != nil {
	log.Fatalf("Error fetching positions: %v", err)
}

// Process positions
for _, position := range positions.Positions {
	fmt.Printf("%s: %.2f shares @ $%.2f\n", 
		position.Symbol, 
		position.Quantity, 
		position.MarketValue/position.Quantity)
}
```

### Place and Manage Orders

```go
// Create a limit order
order := &schwab.Order{
	AccountID:   "account123",
	Symbol:      "AAPL",
	Quantity:    5,
	Type:        schwab.OrderTypeLimit,
	Side:        schwab.OrderSideBuy,
	LimitPrice:  150.00,
	TimeInForce: schwab.TimeInForceDay,
}

createdOrder, err := client.Orders.Create(ctx, order)
if err != nil {
	log.Fatalf("Error creating order: %v", err)
}
fmt.Printf("Order created with ID: %s\n", createdOrder.ID)

// List open orders
openOrders, err := client.Orders.List(ctx, "account123", schwab.OrderStatusOpen, nil)
if err != nil {
	log.Fatalf("Error listing orders: %v", err)
}

// Cancel an order
err = client.Orders.Cancel(ctx, "account123", "order456")
if err != nil {
	log.Fatalf("Error cancelling order: %v", err)
}
```

### Get Market Quotes

```go
// Get quotes for multiple symbols
quotes, err := client.Quotes.Get(ctx, []string{"AAPL", "MSFT", "GOOGL"})
if err != nil {
	log.Fatalf("Error fetching quotes: %v", err)
}

for symbol, quote := range quotes {
	fmt.Printf("%s: $%.2f (Change: $%.2f / %.2f%%)\n",
		symbol,
		quote.LastPrice,
		quote.Change,
		quote.ChangePercent)
}
```

## Configuration Options

The client can be configured with functional options:

```go
client := schwab.NewClient(
	clientID, 
	clientSecret,
	// Custom options
	schwab.WithBaseURL("https://api.schwab-test.com/v1/"),
	schwab.WithTimeout(30 * time.Second),
	schwab.WithUserAgent("my-app/1.0"),
	schwab.WithHTTPClient(customHTTPClient),
	schwab.WithLogger(func(format string, args ...interface{}) {
		log.Printf("[SCHWAB] "+format, args...)
	}),
)
```

## Error Handling

The library provides specific error types for common API errors:

```go
import "errors"

// Try to fetch a non-existent account
_, err := client.Accounts.Get(ctx, "invalid-account")
if err != nil {
	if errors.Is(err, schwab.ErrResourceNotFound) {
		fmt.Println("Account not found")
	} else if errors.Is(err, schwab.ErrAuthentication) {
		fmt.Println("Authentication failed")
	} else {
		fmt.Printf("Unexpected error: %v\n", err)
	}
}
```

Common error types:
- `ErrAuthentication`: Authentication failures
- `ErrInvalidRequest`: Invalid request parameters
- `ErrResourceNotFound`: Requested resource doesn't exist
- `ErrServerError`: Server-side error
- `ErrRateLimitExceeded`: Rate limit has been exceeded
- `ErrPermissionDenied`: Insufficient permissions

## Documentation

For full API documentation, see the [Go Reference](https://pkg.go.dev/github.com/yourusername/schwab).

## License

[MIT License](LICENSE)
