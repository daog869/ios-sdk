#!/bin/bash

# Deploy Functions Script for Vizion Gateway
# This script only deploys the Firebase functions to production

# Error handling
set -e  # Exit on any error
trap 'echo "Error: Command failed at line $LINENO. Exiting..."; exit 1' ERR

# Print colorful messages
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=======================================${NC}"
echo -e "${YELLOW}   Deploying Vizion Gateway Functions   ${NC}"
echo -e "${YELLOW}=======================================${NC}"

# Change to functions directory
cd ./functions

# Check for the Firebase project ID
echo -e "${YELLOW}Checking Firebase project...${NC}"
FIREBASE_PROJECT=$(firebase projects:list | grep "vizion-gateway" | awk '{print $1}')

if [ -z "$FIREBASE_PROJECT" ]; then
  echo -e "${RED}Error: Firebase project not found.${NC}"
  echo -e "Please make sure you're logged in with: firebase login"
  exit 1
fi

echo -e "${GREEN}Found Firebase project: $FIREBASE_PROJECT${NC}"

# Build functions (if TypeScript is used)
echo -e "${YELLOW}Building functions...${NC}"
npm run build

# Deploy only functions
echo -e "${YELLOW}Deploying functions to Firebase...${NC}"
firebase deploy --only functions --project $FIREBASE_PROJECT

echo -e "${GREEN}Functions deployed successfully!${NC}"
echo -e "${YELLOW}=======================================${NC}" 