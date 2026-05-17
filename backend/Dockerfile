# --- 1) Deps stage: install only backend workspace using the ROOT lockfile ---
FROM node:18-bullseye-slim AS deps

WORKDIR /app

# Copy root manifests (workspaces + lock live at repo root)
COPY package.json package-lock.json ./

# Copy backend manifest so npm can resolve that workspace
COPY backend/package.json backend/package.json

# Install ONLY the backend workspace using the root lockfile
# (omit devDependencies for a lean runtime)
RUN npm ci -w backend --include-workspace-root=false --omit=dev


# --- 2) Runtime stage ---
FROM node:18-bullseye-slim

# Provide a human-readable description for the image
LABEL org.opencontainers.image.description="Fusion Electronics Backend – a backend server for Fusion Electronics, a MERN-stack e-commerce website."

WORKDIR /app
ENV NODE_ENV=production

# Bring in workspace dependencies. npm may place workspace packages in both
# root node_modules and backend/node_modules depending on package metadata.
COPY --from=deps /app/node_modules /app/node_modules
COPY --from=deps /app/backend/node_modules /app/backend/node_modules

# Copy backend sources
COPY backend/ backend/

# Run from backend folder
WORKDIR /app/backend

# Expose the port your app listens on by default
EXPOSE 8000

# Start your app
CMD ["node", "index.js"]
