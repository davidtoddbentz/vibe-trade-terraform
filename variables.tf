variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "vibe-trade-475704"
}

variable "region" {
  description = "GCP Region for Cloud Run and Artifact Registry"
  type        = string
  default     = "us-central1"
}

variable "firestore_location" {
  description = "Firestore location. For Native mode, use multi-region IDs: nam5 (US), eur3 (Europe), asia1 (Asia). Or single regions like us-central1, us-east1, etc."
  type        = string
  default     = "nam5"

  validation {
    condition     = can(regex("^(nam5|eur3|asia1|us-central1|us-east1|us-west1|europe-west1|asia-northeast1)$", var.firestore_location))
    error_message = "Firestore location must be a valid location: nam5, eur3, asia1 (multi-region) or us-central1, us-east1, us-west1, europe-west1, asia-northeast1 (single region)"
  }
}

variable "mcp_auth_token" {
  description = "Static authentication token for MCP server. If empty, authentication is disabled. Set this to a secure random string."
  type        = string
  default     = ""
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key for the agent"
  type        = string
  sensitive   = true
}

variable "langsmith_api_key" {
  description = "LangSmith API key for the agent"
  type        = string
  sensitive   = true
}

variable "openai_model" {
  description = "OpenAI model to use (e.g., gpt-4o-mini)"
  type        = string
  default     = "gpt-4o-mini"
}

variable "max_tokens" {
  description = "Maximum tokens per response"
  type        = string
  default     = "2000"
}

variable "max_iterations" {
  description = "Maximum agent iterations"
  type        = string
  default     = "15"
}

variable "agent_domain" {
  description = "Domain name for the agent service (optional, for Cloud Armor rate limiting with load balancer)"
  type        = string
  default     = ""
}

variable "nextauth_secret" {
  description = "NextAuth JWT secret (must match API's NEXTAUTH_SECRET if API still uses NextAuth)"
  type        = string
  sensitive   = true
}

variable "snaptrade_client_id" {
  description = "SnapTrade client ID"
  type        = string
  sensitive   = true
  default     = ""  # Optional - only needed if using SnapTrade features
}

variable "snaptrade_consumer_key" {
  description = "SnapTrade consumer key"
  type        = string
  sensitive   = true
  default     = ""  # Optional - only needed if using SnapTrade features
}

# Firebase configuration variables
# Note: These are BUILD-TIME variables (NEXT_PUBLIC_*) that get baked into the JavaScript bundle
# They're stored here for convenience/management, but are passed as Docker build args, not runtime env vars
# See vibes/quant/Makefile for how to use these during docker build

variable "firebase_api_key" {
  description = "Firebase API key (NEXT_PUBLIC_FIREBASE_API_KEY) - used at build time"
  type        = string
  sensitive   = true
  default     = ""
}

variable "firebase_auth_domain" {
  description = "Firebase Auth domain (NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN) - used at build time"
  type        = string
  default     = ""
}

variable "firebase_project_id" {
  description = "Firebase Project ID (NEXT_PUBLIC_FIREBASE_PROJECT_ID) - used at build time"
  type        = string
  default     = ""
}

variable "firebase_storage_bucket" {
  description = "Firebase Storage bucket (NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET) - optional, used at build time"
  type        = string
  default     = ""
}

variable "firebase_messaging_sender_id" {
  description = "Firebase Messaging Sender ID (NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID) - optional, used at build time"
  type        = string
  default     = ""
}

variable "firebase_app_id" {
  description = "Firebase App ID (NEXT_PUBLIC_FIREBASE_APP_ID) - optional, used at build time"
  type        = string
  default     = ""
}

variable "langgraph_api_url" {
  description = "LangGraph Agent API URL (NEXT_PUBLIC_LANGGRAPH_API_URL) - used at build time"
  type        = string
  default     = ""
}

variable "firebase_service_account_key" {
  description = "Firebase Service Account Key JSON (optional - uses Application Default Credentials on GCP if not set)"
  type        = string
  sensitive   = true
  default     = ""
}

