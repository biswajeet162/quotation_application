# Google OAuth Setup Instructions

## For Desktop (Windows/Linux/macOS) Applications

The app now uses a desktop-compatible OAuth 2.0 flow that opens Chrome for authentication.

### Step 1: Create OAuth 2.0 Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable **Google Drive API**:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Google Drive API"
   - Click "Enable"

4. Configure OAuth Consent Screen:
   - Go to "APIs & Services" > "OAuth consent screen"
   - Choose "External" (for testing) or "Internal" (for Google Workspace)
   - Fill in required information:
     - App name: "Quotation Application"
     - User support email: Your email
     - Developer contact: Your email
   - Add scopes: Click "Add or Remove Scopes"
     - Search for and add: `https://www.googleapis.com/auth/drive.file`
   - Add test users (if using External):
     - Add your Gmail account as a test user

5. Create OAuth 2.0 Client ID:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "OAuth client ID"
   - Application type: **Desktop app**
   - Name: "Quotation App Desktop"
   - Click "Create"
   - **Copy the Client ID** (looks like: `123456789-abc...xyz.apps.googleusercontent.com`)

### Step 2: Configure in Flutter App

1. Open `lib/services/desktop_oauth_service.dart`
2. Find line 18:
   ```dart
   static const String clientId = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';
   ```
3. Replace `YOUR_CLIENT_ID_HERE.apps.googleusercontent.com` with your actual Client ID:
   ```dart
   static const String clientId = '123456789-abc...xyz.apps.googleusercontent.com';
   ```

### Step 3: Configure Redirect URI

The app uses `http://localhost:8080/callback` as the redirect URI. This is automatically configured in the code.

**Important**: In Google Cloud Console, when creating the Desktop app OAuth client, you may need to add authorized redirect URIs:
- Go to your OAuth 2.0 Client ID settings
- Add redirect URI: `http://localhost:8080/callback`

### Step 4: Test

1. Run the app: `flutter run -d windows`
2. Login as admin
3. Go to Settings
4. Click "Sign In to Google Drive"
5. Chrome should open with Google sign-in page
6. Select your Gmail account (if multiple)
7. Click "Allow" to grant permissions
8. Browser will show "Authentication Successful" and close
9. App should now show "Authenticated" status

### How It Works

1. App starts a local HTTP server on `localhost:8080`
2. Opens Chrome with Google OAuth URL
3. User signs in and grants permissions
4. Google redirects to `http://localhost:8080/callback` with authorization code
5. App exchanges code for access token
6. Token is stored securely
7. App can now access Google Drive

### Troubleshooting

- **Error: "Please configure your OAuth Client ID"**: 
  - You haven't added your Client ID in `desktop_oauth_service.dart`
  - Follow Step 2 above

- **Error: "Failed to open browser"**: 
  - Check your default browser settings
  - Make sure Chrome or another browser is installed

- **Error: "Authentication timeout"**: 
  - You didn't complete the sign-in within 2 minutes
  - Try again and complete the flow quickly

- **Error: "Token exchange failed"**: 
  - Check that redirect URI `http://localhost:8080/callback` is added in Google Cloud Console
  - Verify Client ID is correct
  - Make sure Google Drive API is enabled

- **Port 8080 already in use**: 
  - Close any other applications using port 8080
  - Or modify the port in `desktop_oauth_service.dart` (line 15)

- **Browser opens but shows error**: 
  - Check OAuth consent screen is configured
  - Verify test user email is added (if using External)
  - Check scopes include `drive.file`

