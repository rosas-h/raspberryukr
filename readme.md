# LanceDB Search API - Docker Deployment Package

Minimal Docker package for the LanceDB search API to run on arm64 or x86. This package provides the `/search` endpoint for semantic search over Ukrainian QA datasets stored in an external LanceDB.

## Features

✅ **Minimal Dependencies** - Only includes what's needed for search operations  
✅ **External Database** - Connects to pre-populated LanceDB (no ingestion scripts)  
✅ **Flexible Embeddings** - Supports both local models or remote embedder
✅ **Easy Deployment** - Docker Compose configuration with environment variables

## Prerequisites

### Required

- Docker 20.10+ and Docker Compose 2.0+
- External LanceDB storage with pre-populated tables
- Sufficient RAM for local embedding model OR embedder service (remote) 

### External LanceDB

This package does NOT include database population scripts. Your LanceDB must be:

- Pre-populated with QA data
- Accessible as a mounted volume
- Contains at least one table (default: `ukr_qa_chunked`)

## Quick Start

### 1. Configure Environment

Copy the example environment file and edit with your settings:

```bash
cp .env.example .env
vim .env
```

Required settings:

```bash
# Path to your LanceDB storage on host
LANCEDB_HOST_PATH=/path/to/your/lancedb/storage 

# Choose ONE embedder option:

# Option B: Local embedder 
EMBEDDER_MODEL_NAME=lang-uk/ukr-paraphrase-multilingual-mpnet-base

# Option A: Remote embedder (faster but requires internet connection)
# EMBEDDER_URL=http://embedder-service:80

# QA table name
QA_TABLE_NAME=ukr_qa_chunked
```

### 2. Build and Run

```bash
# Build the Docker image
docker-compose build

# Start the service
docker-compose up -d

# Check health
curl http://localhost:8001/health

# Run test.sh
./test.sh
```

### 3. Test Chat Endpoint

```bash
curl -X POST http://localhost:8001/chat \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user123",
    "query": "я стала жертвою сексуального конфлікту, що мені робити?"
  }'
```
You can add | jq  at the end of the query for better readability

## API Endpoints

### POST /chat

Main endpoint for retrieval with formatted prompts.

**Request:**
```json
{
  "username": "user123",
  "query": "Your search query"
}
```
**Parameters:**

- `username` (string, required) — Username identifier for the chat session.
- `query` (string, required) — The natural-language search query to process.

**Response:**
```json
{
  "formatted_prompt": "<|query_start|>Your query<|query_end|><|source_start|><|source_id_start|>1<|source_id_end|>Source content...<|source_end|>...",
  "generated_text": "<|source_start|>...source content repeated...<|source_end|><|answer_start|><|answer_end|>",
  "generation_time": 0.17,
  "parsed_sections": {
    "answer": "",
    "draft": "Empty",
    "language": "ukr",
    "query_analysis": "",
    "query_report": "",
    "source_analysis": "",
    "source_report": "Empty"
  },
  "query": "Your search query",
  "source_limit": "",
  "source_urls": "",
  "sources_count": 5
}
```

### GET /health

Health check endpoint.

**Response:**

```json
{
  "status": "healthy",
  "timestamp": "2025-11-04T12:00:00",
  "database_path": "/app/storage/lancedb",
  "embedding_dimension": 768,
  "qa_table": "ukr_qa_chunked",
  "qa_documents": 1500,
  "embedding_service": "http://embedder:80"
}
```

### GET /stats

Database statistics.

### GET /tables

List all available tables.

## Configuration Reference

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `LANCEDB_HOST_PATH` | Path to LanceDB storage on host | `/data/lancedb` |
| `EMBEDDER_MODEL_NAME` | Local embedder model | `ukr-paraphrase-multilingual-mpnet-base` |
| `EMBEDDER_URL` | Remote embedder service URL | `http://embedder:80` |
| `QA_TABLE_NAME` | Default table name | `ukr_qa_chunked` |

### Embedder Options

#### Option 1: Local Embedder

```bash
EMBEDDER_MODEL_NAME=BAAI/bge-m3
# or
EMBEDDER_MODEL_NAME=lang-uk/ukr-paraphrase-multilingual-mpnet-base
```

**Advantages:**
- No external dependencies
- Simpler setup for small deployments

**Disadvantages:**
- Slower first request (model loading)
- Higher memory usage (~2GB)

#### Option 2: Remote Embedder

```bash
EMBEDDER_URL=http://text-embeddings-inference:80
```

**Advantages:**
- Faster (dedicated service)
- Lower memory usage in API container
- Better for scaling

**Disadvantages:**
- Requires online connection

## Chunk Expansion Features

This package includes advanced chunk expansion capabilities for better retrieval:

### Window Expansion

Retrieve neighboring chunks around a matched result:

```python
# Example: Get 2 chunks before and after
manager.get_chunk_neighbors(
    table_name='ukr_qa_chunked',
    doc_id='document-id',
    chunk_index=3,
    before=2,
    after=2
)
```

### Full Document Retrieval

Reconstruct complete document from chunks:

```python
manager.get_full_document_by_doc_id(
    table_name='ukr_qa_chunked',
    doc_id='document-id'
)
```

### Section Expansion

Get contextual section around a chunk:

```python
manager.get_section_for_chunk(
    table_name='ukr_qa_chunked',
    doc_id='document-id',
    chunk_index=4,
    expand_window=3
)
```

## Deployment Scenarios

### Scenario 1: Standalone with Local Embedder

```bash
# .env
EMBEDDER_MODEL_NAME=BAAI/ukr-paraphrase-multilingual-mpnet-base
LANCEDB_HOST_PATH=./storage/lancedb
```

### Scenario 2: Production with Remote Embedder

```yaml
# docker-compose.yml
services:
  embedder:
    image: ghcr.io/huggingface/text-embeddings-inference:cpu-1.8
    command: --model-id BAAI/bge-m3

  search-api:
    build: .
    environment:
      - EMBEDDER_URL=http://embedder:80
      - LANCEDB_PATH=/app/storage/lancedb
    volumes:
      - /data/lancedb:/app/storage/lancedb:ro
```
## Troubleshooting

### Container won't start

```bash
# Check logs
docker-compose logs search-api

# Common issues:
# 1. LanceDB path not mounted correctly
# 2. Embedder not configured (need EMBEDDER_URL or EMBEDDER_MODEL_NAME)
# 3. Port already in use
```

### Database not found

```bash
# Verify LanceDB path
docker-compose exec search-api ls -la /app/storage/lancedb

# Should see *.lance directories
```

### Slow first request

If using local embedder, first request loads model (~30 seconds). Subsequent requests will be faster.

### Health check fails

```bash
# Check if service is responding
curl http://localhost:8001/health

# Check table exists
curl http://localhost:8001/tables
```