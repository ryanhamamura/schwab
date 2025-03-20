package schwab

import (
	"context"
	"fmt"
)

const positionsEndpoint = "positions"

// PositionsService handles operations related to positions
type PositionsService struct {
	client *Client
}

// Position represents a position in a portfolio
type Position struct {
	Symbol          string  `json:"symbol"`
	Description     string  `json:"description"`
	Quantity        float64 `json:"quantity"`
	CostBasis       float64 `json:"costBasis"`
	MarketValue     float64 `json:"marketValue"`
	UnrealizedPL    float64 `json:"unrealizedPL"`
	UnrealizedPLPct float64 `json:"unrealizedPLPct"`
	AssetType       string  `json:"assetType"`
}

// ListPositionsResponse contains the response for list positions
type ListPositionsResponse struct {
	Positions []Position `json:"positions"`
	Metadata  struct {
		TotalCount int `json:"totalCount"`
		Limit      int `json:"limit"`
		Offset     int `json:"offset"`
	} `json:"metadata,omitempty"`
}

// List retrieves all positions for a specific account with pagination
func (s *PositionsService) List(ctx context.Context, accountID string, params *PaginationParams) (*ListPositionsResponse, error) {
	if accountID == "" {
		return nil, fmt.Errorf("%w: account ID is required", ErrInvalidRequest)
	}

	url := fmt.Sprintf("%s/%s/%s", accountsEndpoint, accountID, positionsEndpoint)
	if params != nil {
		url = params.AddQueryParams(url)
	}

	req, err := s.client.NewRequest(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	var response ListPositionsResponse
	_, err = s.client.Do(req, &response)
	if err != nil {
		return nil, err
	}

	return &response, nil
}
