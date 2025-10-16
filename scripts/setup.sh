#!/bin/bash

echo "================================================"
echo " NoctisApp Setup Script"
echo "================================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Initializing NoctisApp environment...${NC}"

# Example setup steps
python3 -m venv venv
source venv/bin/activate
pip install -r backend/requirements.txt

cd frontend/
flutter pub get

echo -e "${GREEN}✅ NoctisApp environment setup complete!${NC}"
echo "Run the backend and frontend to start your app."
