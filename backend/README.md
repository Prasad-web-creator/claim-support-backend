# Claim Support - Backend

This is the Node.js REST API for the Claim Support application. It handles user authentication, file uploads (PDF/Images), document extraction, AI-powered coverage analysis using Gemini, and persistent storage via MongoDB and GridFS.

## Architecture

- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: MongoDB (Mongoose for ODM, GridFS for file streaming)
- **AI Integration**: Google Generative AI (`@google/generative-ai`)
- **Logging**: Winston

## Getting Started

### Prerequisites

- Node.js (v18+ recommended)
- MongoDB running locally or a MongoDB Atlas URI
- API Keys for Gemini

### Installation

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Copy the environment template and fill in your secrets:
   ```bash
   cp .env.example .env
   ```

### Running the Server

Start the development server (runs on port 3000 by default):
```bash
npm start
```

## Structure
- `/src/controllers` - Request handlers (e.g. `authController.js`)
- `/src/routes` - Express route definitions
- `/src/services` - Core business logic and AI pipelines
- `/src/models` - Mongoose schemas
- `/src/middleware` - Auth, file upload validation, and custom storage engines
- `/src/utils` - Centralized logger and AI client helpers

> **Note**: The `uploads/` and `logs/` directories are generated automatically at runtime and are ignored by git. Do not commit temporary files.
