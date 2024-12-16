#!/bin/bash
set -e

function check_variables() {
    if [ -z "$INDEX_NAME" ]; then
        echo "INDEX_NAME is not set"
        exit 1
    fi

    if [ -z "$SEARCH_SERVICE_ENDPOINT" ]; then
        echo "SEARCH_SERVICE_ENDPOINT is not set"
        exit 1
    fi

    if [ -z "$SEARCH_SERVICE_SECRET" ]; then
        echo "SEARCH_SERVICE_SECRET is not set"
        exit 1
    fi

    if [ -z "$SEMANTIC_CONFIGURATION_NAME" ]; then
        echo "SEMANTIC_CONFIGURATION_NAME is not set"
        exit 1
    fi

    if [ -z "$VECTOR_PROFILE_NAME" ]; then
        echo "VECTOR_PROFILE_NAME is not set"
        exit 1
    fi

    if [ -z "$BASE_INDEX_FILE" ]; then
        echo "BASE_INDEX_FILE is not set"
        exit 1
    fi

    if [ -z "$VECTOR_ALGORITHM_NAME" ]; then
        echo "VECTOR_ALGORITHM_NAME is not set"
        exit 1
    fi
}

check_variables

# Constants
SEARCH_SERVICE_APIVERSION="2024-07-01"

# Create Index
INDEX_FILE="index.json"

echo "Updating index file with environment variables..."

echo "${BASE_INDEX_FILE//__INDEX_NAME__/$INDEX_NAME}" > $INDEX_FILE
sed -i "s/__SEMANTIC_CONFIGURATION_NAME__/${SEMANTIC_CONFIGURATION_NAME}/g" $INDEX_FILE
sed -i "s/__VECTOR_PROFILE_NAME__/${VECTOR_PROFILE_NAME}/g" $INDEX_FILE
sed -i "s/__VECTOR_ALGORITHM_NAME__/${VECTOR_ALGORITHM_NAME}/g" $INDEX_FILE

echo "Creating index ${INDEX_NAME} in ${SEARCH_SERVICE_ENDPOINT}..."

# Json string with header
headers='{"Content-Type": "application/json", "api-key": "'${SEARCH_SERVICE_SECRET}'", "cache-control": "no-cache"}'

az rest --method PUT --skip-authorization-header \
    --url "${SEARCH_SERVICE_ENDPOINT}/indexes('${INDEX_NAME}')?api-version=${SEARCH_SERVICE_APIVERSION}" \
    --headers "$headers" \
    --body @"${INDEX_FILE}" --verbose
