package schwab

import (
	"context"
	"fmt"
	"strings"
)

const quotesEndpoint = "quotes"

// QuotesService handles operations related to market quotes
type QuotesService struct {
	client *Client
}

// Quote represents market data for a symbol
type Quote struct {
	Symbol        string  `json:"symbol"`
	Description   string  `json:"description"`
	BidPrice      float64 `json:"bidPrice"`
	AskPrice      float64 `json:"askPrice"`
	LastPrice     float64 `json:"lastPrice"`
	OpenPrice     float64 `json:"openPrice"`
	HighPrice     float64 `json:"highPrice"`
	LowPrice      float64 `json:"lowPrice"`
	ClosePrice    float64 `json:"closePrice"`
	Volume        int64   `json:"volume"`
	Change        float64 `json:"change"`
	ChangePercent float64 `json:"changePercent"`
	Exchange      string  `json:"exchange"`
	Timestamp     string  `json:"timestamp"`
}

// Get retrieves quotes for one or more symbols
func (s *QuotesService) Get(ctx context.Context, symbols []string) (map[string]Quote, error) {
	if len(symbols) == 0 {
		return nil, fmt.Errorf("%w: at least one symbol is required", ErrInvalidRequest)
	}

	url := fmt.Sprintf("%s?symbols=%s", quotesEndpoint, strings.Join(symbols, ","))
	req, err := s.client.NewRequest(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	var quotesResponse struct {
		Quotes map[string]Quote `json:"quotes"`
	}

	_, err = s.client.Do(req, &quotesResponse)
	if err != nil {
		return nil, err
	}

	return quotesResponse.Quotes, nil
}
