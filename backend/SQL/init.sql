-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create a sample table just to verify connectivity
CREATE TABLE IF NOT EXISTS test_connection (
    id SERIAL PRIMARY KEY,
    info TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO test_connection (info) VALUES ('Database connected successfully!');
