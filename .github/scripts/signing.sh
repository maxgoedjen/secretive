#!/bin/bash

# Create directories for ASC key
mkdir ~/.private_keys
echo -n "$APPLE_API_KEY_DATA" > ~/.private_keys/AuthKey_$APPLE_API_KEY_ID.p8
