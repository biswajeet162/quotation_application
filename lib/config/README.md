# OAuth Configuration

This folder contains OAuth 2.0 configuration for Google Drive authentication.

## Files

- **`oauth_config.dart`** - Your actual configuration (DO NOT commit to git)
- **`oauth_config.example.dart`** - Example template (safe to commit)

## Setup Instructions

1. **Get OAuth Client ID**:
   - Go to: https://console.cloud.google.com/apis/credentials
   - Create OAuth 2.0 Client ID (Desktop app type)
   - Copy the Client ID

2. **Configure**:
   - Open `oauth_config.dart`
   - Replace `YOUR_CLIENT_ID_HERE.apps.googleusercontent.com` with your actual Client ID
   - Save the file

3. **Done!** The app will now use your credentials for Google Drive authentication.

## Security

- ✅ `oauth_config.dart` is in `.gitignore` - your credentials won't be committed
- ✅ `oauth_config.example.dart` is safe to commit (no real credentials)
- ✅ Never share your Client ID publicly

## Configuration Options

All OAuth settings are in `oauth_config.dart`:

- `clientId` - Your OAuth Client ID (REQUIRED)
- `callbackPort` - Local server port (default: 8080)
- `scopes` - API permissions (default: drive.file)
- `redirectUri` - OAuth callback URL (auto-generated from port)

