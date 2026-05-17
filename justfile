# jglance development commands

# Default: list commands
default:
    @just --list

# Format R and client code
format:
    @echo "Formatting R code with air..."
    @air format R
    @echo "Formatting client code with prettier..."
    @cd client && npm run format

# Build the client bundle and install the jamovi module
build:
    @cd client && npm run build
    @./scripts/install-module.sh

# Install the jamovi module (R/YAML only, skips client build)
install:
    @./scripts/install-module.sh

# Regenerate the demo dataset
demo-data:
    @Rscript scripts/generate-demo-data.R

# Run client development server
dev:
    @cd client && npm run dev
