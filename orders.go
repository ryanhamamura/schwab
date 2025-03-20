package schwab

import (
	"context"
	"fmt"
	"strconv"
)

const ordersEndpoint = "orders"

// OrdersService handles operations related to orders
type OrdersService struct {
	client *Client
}

// OrderStatus represents the status of an order
type OrderStatus string

const (
	OrderStatusOpen       OrderStatus = "OPEN"
	OrderStatusExecuted   OrderStatus = "EXECUTED"
	OrderStatusCanceled   OrderStatus = "CANCELED"
	OrderStatusRejected   OrderStatus = "REJECTED"
	OrderStatusExpired    OrderStatus = "EXPIRED"
	OrderStatusPartial    OrderStatus = "PARTIAL"
	OrderStatusPendingNew OrderStatus = "PENDING_NEW"
)

// OrderType represents the type of order
type OrderType string

const (
	OrderTypeMarket       OrderType = "MARKET"
	OrderTypeLimit        OrderType = "LIMIT"
	OrderTypeStop         OrderType = "STOP"
	OrderTypeStopLimit    OrderType = "STOP_LIMIT"
	OrderTypeTrailingStop OrderType = "TRAILING_STOP"
)

// OrderSide represents the side of an order (buy/sell)
type OrderSide string

const (
	OrderSideBuy  OrderSide = "BUY"
	OrderSideSell OrderSide = "SELL"
)

// TimeInForce represents how long an order will remain active
type TimeInForce string

const (
	TimeInForceDay               TimeInForce = "DAY"
	TimeInForceGoodTillCanceled  TimeInForce = "GTC"
	TimeInForceImmediateOrCancel TimeInForce = "IOC"
	TimeInForceFillOrKill        TimeInForce = "FOK"
)

// Order represents a trading order
type Order struct {
	ID            string      `json:"id,omitempty"`
	AccountID     string      `json:"accountId"`
	Symbol        string      `json:"symbol"`
	Quantity      float64     `json:"quantity"`
	FilledQty     float64     `json:"filledQty,omitempty"`
	Type          OrderType   `json:"type"`
	Side          OrderSide   `json:"side"`
	LimitPrice    float64     `json:"limitPrice,omitempty"`
	StopPrice     float64     `json:"stopPrice,omitempty"`
	TimeInForce   TimeInForce `json:"timeInForce"`
	Status        OrderStatus `json:"status,omitempty"`
	CreatedAt     string      `json:"createdAt,omitempty"`
	UpdatedAt     string      `json:"updatedAt,omitempty"`
	ExecutedPrice float64     `json:"executedPrice,omitempty"`
}

// Validate checks if an order is valid
func (o *Order) Validate() error {
	if o.AccountID == "" {
		return fmt.Errorf("%w: accountId is required", ErrInvalidRequest)
	}
	if o.Symbol == "" {
		return fmt.Errorf("%w: symbol is required", ErrInvalidRequest)
	}
	if o.Quantity <= 0 {
		return fmt.Errorf("%w: quantity must be positive", ErrInvalidRequest)
	}
	if o.Type == "" {
		return fmt.Errorf("%w: type is required", ErrInvalidRequest)
	}
	if o.Side == "" {
		return fmt.Errorf("%w: side is required", ErrInvalidRequest)
	}
	if o.TimeInForce == "" {
		return fmt.Errorf("%w: timeInForce is required", ErrInvalidRequest)
	}

	// Check for required prices based on order type
	switch o.Type {
	case OrderTypeLimit, OrderTypeStopLimit:
		if o.LimitPrice <= 0 {
			return fmt.Errorf("%w: limitPrice is required for %s orders", ErrInvalidRequest, o.Type)
		}
	case OrderTypeStop, OrderTypeStopLimit:
		if o.StopPrice <= 0 {
			return fmt.Errorf("%w: stopPrice is required for %s orders", ErrInvalidRequest, o.Type)
		}
	}

	return nil
}

// ListOrdersResponse contains the response for list orders
type ListOrdersResponse struct {
	Orders   []Order `json:"orders"`
	Metadata struct {
		TotalCount int `json:"totalCount"`
		Limit      int `json:"limit"`
		Offset     int `json:"offset"`
	} `json:"metadata,omitempty"`
}

// Create places a new order
func (s *OrdersService) Create(ctx context.Context, order *Order) (*Order, error) {
	if err := order.Validate(); err != nil {
		return nil, err
	}

	url := fmt.Sprintf("%s/%s/%s", accountsEndpoint, order.AccountID, ordersEndpoint)
	req, err := s.client.NewRequest(ctx, "POST", url, order)
	if err != nil {
		return nil, err
	}

	var createdOrder Order
	_, err = s.client.Do(req, &createdOrder)
	if err != nil {
		return nil, err
	}

	return &createdOrder, nil
}

// List retrieves orders for a specific account with optional status filter and pagination
func (s *OrdersService) List(ctx context.Context, accountID string, status OrderStatus, params *PaginationParams) (*ListOrdersResponse, error) {
	if accountID == "" {
		return nil, fmt.Errorf("%w: account ID is required", ErrInvalidRequest)
	}

	url := fmt.Sprintf("%s/%s/%s", accountsEndpoint, accountID, ordersEndpoint)

	// Build query parameters
	query := make(map[string]string)
	if status != "" {
		query["status"] = string(status)
	}

	// Add pagination if provided
	if params != nil {
		if params.Limit > 0 {
			query["limit"] = strconv.Itoa(params.Limit)
		}
		if params.Offset > 0 {
			query["offset"] = strconv.Itoa(params.Offset)
		}
	}

	// Append query parameters to URL
	if len(query) > 0 {
		url += "?"
		queryParts := make([]string, 0, len(query))
		for k, v := range query {
			queryParts = append(queryParts, k+"="+v)
		}
		url += strconv.Quote(queryParts[0])[1 : len(strconv.Quote(queryParts[0]))-1]
		for i := 1; i < len(queryParts); i++ {
			url += "&" + strconv.Quote(queryParts[i])[1:len(strconv.Quote(queryParts[i]))-1]
		}
	}

	req, err := s.client.NewRequest(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	var response ListOrdersResponse
	_, err = s.client.Do(req, &response)
	if err != nil {
		return nil, err
	}

	return &response, nil
}

// Get retrieves a specific order by ID
func (s *OrdersService) Get(ctx context.Context, accountID, orderID string) (*Order, error) {
	if accountID == "" {
		return nil, fmt.Errorf("%w: account ID is required", ErrInvalidRequest)
	}
	if orderID == "" {
		return nil, fmt.Errorf("%w: order ID is required", ErrInvalidRequest)
	}

	url := fmt.Sprintf("%s/%s/%s/%s", accountsEndpoint, accountID, ordersEndpoint, orderID)
	req, err := s.client.NewRequest(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	var order Order
	_, err = s.client.Do(req, &order)
	if err != nil {
		return nil, err
	}

	return &order, nil
}

// Cancel cancels an open order
func (s *OrdersService) Cancel(ctx context.Context, accountID, orderID string) error {
	if accountID == "" {
		return fmt.Errorf("%w: account ID is required", ErrInvalidRequest)
	}
	if orderID == "" {
		return fmt.Errorf("%w: order ID is required", ErrInvalidRequest)
	}

	url := fmt.Sprintf("%s/%s/%s/%s", accountsEndpoint, accountID, ordersEndpoint, orderID)
	req, err := s.client.NewRequest(ctx, "DELETE", url, nil)
	if err != nil {
		return err
	}

	_, err = s.client.Do(req, nil)
	return err
}
