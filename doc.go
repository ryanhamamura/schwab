// Package schwab provides a Go client for the Charles Schwab API.
//
// The package provides a simple and idiomatic way to interact with
// the Charles Schwab API, including authentication, account management,
// portfolio positions, order placement and management, and market quotes.
//
// Usage:
//
//	// Create a new client with API credentials
//	client := schwab.NewClient(
//		"your-client-id",
//		"your-client-secret",
//		schwab.WithTimeout(15*time.Second),
//		schwab.WithLogger(log.Printf),
//	)
//
//	// Get account information
//	accounts, err := client.Accounts.List(ctx, nil)
//
//	// Place an order
//	order := &schwab.Order{
//		AccountID:   accountID,
//		Symbol:      "AAPL",
//		Quantity:    5,
//		Type:        schwab.OrderTypeLimit,
//		Side:        schwab.OrderSideBuy,
//		LimitPrice:  150.00,
//		TimeInForce: schwab.TimeInForceDay,
//	}
//	createdOrder, err := client.Orders.Create(ctx, order)
//
// For more examples, see the example directory.
package schwab
