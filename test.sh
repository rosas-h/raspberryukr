#!/bin/bash
# Test script for LanceDB Search API

set -e

API_URL="${API_URL:-http://localhost:8001}"
TABLE_NAME="${TABLE_NAME:-ukr_qa_chunked}"

echo "=================================="
echo "LanceDB Search API - Test Script"
echo "=================================="
echo "API URL: $API_URL"
echo "Table: $TABLE_NAME"
echo ""

# Test 1: Health check
echo "Test 1: Health Check"
echo "--------------------"
HEALTH=$(curl -s "$API_URL/health")
STATUS=$(echo $HEALTH | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

if [ "$STATUS" = "healthy" ]; then
    echo "✅ Health check passed"
    echo "$HEALTH" | python3 -m json.tool
else
    echo "❌ Health check failed"
    echo "$HEALTH"
    exit 1
fi
echo ""

# Test 2: List tables
echo "Test 2: List Tables"
echo "-------------------"
TABLES=$(curl -s "$API_URL/tables")
echo "$TABLES" | python3 -m json.tool
echo ""

# Test 3: Search with test query
echo "Test 3: Search Query"
echo "--------------------"
SEARCH_RESULT=$(curl -s -X POST "$API_URL/search" \
-H "Content-Type: application/json" \
-d "{\"query\":\"test\",\"table_name\":\"$TABLE_NAME\",\"limit\":3}")
SOURCES_COUNT=$(echo $SEARCH_RESULT | grep -o '"sources_count":[0-9]*' | cut -d':' -f2)
if [ ! -z "$SOURCES_COUNT" ]; then
echo "✅ Search successful - Found $SOURCES_COUNT sources"
echo "$SEARCH_RESULT" | python3 -m json.tool | head -30
else
echo "❌ Search failed"
echo "$SEARCH_RESULT"
exit 1
fi
echo ""

# Test 4: QA Search (if available)
echo "Test 4: QA Search"
echo "-----------------"
QA_RESULT=$(curl -s -X POST "$API_URL/qa/search" \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"test\",\"limit\":2}")

if echo "$QA_RESULT" | grep -q '"query"'; then
    echo "✅ QA search successful"
    echo "$QA_RESULT" | python3 -m json.tool | head -20
else
    echo "⚠️  QA search not available (may need dataset)"
    echo "$QA_RESULT" | python3 -m json.tool
fi
echo ""

echo "=================================="
echo "All tests completed!"
echo "=================================="
echo ""
echo "API Endpoints:"
echo "- Health: GET $API_URL/health"
echo "- Stats: GET $API_URL/stats"
echo "- Tables: GET $API_URL/tables"
echo "- Search: POST $API_URL/search"
echo "- QA Search: POST $API_URL/qa/search"
