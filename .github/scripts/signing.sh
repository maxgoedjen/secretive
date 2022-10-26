#!/bin/bash

# Create directories for ASC key
mkdir .private_keys
echo -n "$APPLE_API_KEY_DATA" > $(pwd)/.private_keys/AuthKey.p8
