package schwab

import (
	"context"
	"fmt"
)

const accountsEndpoint = "accounts"

// AccountsService handles operations related to accounts
type AccountsService struct {
	client *Client
}

// Account represents a Schwab account
type Account struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	AccountNumber string `json:"accountNumber"`
	AccountType   string `json:"accountType"`
	Status        string `json:"status"`
	Balance       struct {
		Cash           float64 `json:"cash"`
		MarketValue    float64 `json:"marketValue"`
		TotalValue     float64 `json:"totalValue"`
		BuyingPower    float64 `json:"buyingPower"`
		MaintenanceReq float64 `json:"maintenanceReq"`
	} `json:"balance"`
}

// ListAccountsResponse contains the response for list accounts
type ListAccountsResponse struct {
	Accounts []Account `json:"accounts"`
	Metadata struct {
		TotalCount int `json:"totalCount"`
		Limit      int `json:"limit"`
		Offset     int `json:"offset"`
	} `json:"metadata,omitempty"`
}

// List retrieves all accounts for the authenticated user with pagination
func (s *AccountsService) List(ctx context.Context, params *PaginationParams) (*ListAccountsResponse, error) {
	url := accountsEndpoint
	if params != nil {
		url = params.AddQueryParams(url)
	}

	req, err := s.client.NewRequest(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	var response ListAccountsResponse
	_, err = s.client.Do(req, &response)
	if err != nil {
		return nil, err
	}

	return &response, nil
}

// Get retrieves a specific account by ID
func (s *AccountsService) Get(ctx context.Context, accountID string) (*Account, error) {
	if accountID == "" {
		return nil, fmt.Errorf("%w: account ID is required", ErrInvalidRequest)
	}

	url := fmt.Sprintf("%s/%s", accountsEndpoint, accountID)
	req, err := s.client.NewRequest(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	var account Account
	_, err = s.client.Do(req, &account)
	if err != nil {
		return nil, err
	}

	return &account, nil
}
