#!/bin/bash

# Setup Test Environment Script for Vizion Gateway
# This script sets up the Firebase emulators and seeds the database with test data

# Error handling
set -e  # Exit on any error
trap 'echo "Error: Command failed at line $LINENO. Exiting..."; exit 1' ERR

# Print colorful messages
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=======================================${NC}"
echo -e "${YELLOW}   Vizion Gateway Test Environment     ${NC}"
echo -e "${YELLOW}=======================================${NC}"

# Change to functions directory
cd ./functions

# Check if service account key exists
if [ ! -f "service-account-key.json" ]; then
  echo -e "${RED}Error: service-account-key.json not found in functions directory${NC}"
  echo -e "Please download your Firebase service account key and save it as:"
  echo -e "service-account-key.json in the functions directory"
  exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
  echo -e "${YELLOW}Installing dependencies...${NC}"
  npm install
  echo -e "${GREEN}Dependencies installed successfully!${NC}"
else
  echo -e "${GREEN}Dependencies already installed${NC}"
fi

# Start Firebase emulators in the background
echo -e "${YELLOW}Starting Firebase emulators...${NC}"
firebase emulators:start --only firestore,auth,functions --project vizion-gateway &
EMULATOR_PID=$!

# Wait for emulators to start
echo -e "${YELLOW}Waiting for emulators to start...${NC}"
sleep 10

# Seed the database with test data
echo -e "${YELLOW}Seeding database with test data...${NC}"
node seed-data.js

echo -e "${GREEN}Test environment is ready!${NC}"
echo -e "${YELLOW}=======================================${NC}"
echo -e "${YELLOW}   Test Accounts:                     ${NC}"
echo -e "${YELLOW}   Admin: admin@viziongateway.com     ${NC}"
echo -e "${YELLOW}   Password: Password123!             ${NC}"
echo -e "${YELLOW}=======================================${NC}"
echo -e "${GREEN}Press Ctrl+C to stop the emulators when done${NC}"

# Keep the script running until user presses Ctrl+C
wait $EMULATOR_PID 