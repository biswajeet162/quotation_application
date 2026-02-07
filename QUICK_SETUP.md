# Quick Setup Guide - Google Drive OAuth

## Step 1: Get Your OAuth Client ID (5 minutes)

1. **Go to Google Cloud Console**: https://console.cloud.google.com/

2. **Create or Select Project**:
   - Click the project dropdown at the top
   - Click "New Project" or select existing one
   - Name: "Quotation App" (or any name)

3. **Enable Google Drive API**:
   - Go to "APIs & Services" → "Library"
   - Search: "Google Drive API"
   - Click "Enable"

4. **Configure OAuth Consent Screen**:
   - Go to "APIs & Services" → "OAuth consent screen"
   - Choose "External" (for testing)
   - Fill in:
     - App name: `Quotation Application`
     - User support email: `your-email@gmail.com`
     - Developer contact: `your-email@gmail.com`
   - Click "Save and Continue"
   - Click "Add or Remove Scopes"
   - Search and add: `https://www.googleapis.com/auth/drive.file`
   - Click "Update" → "Save and Continue"
   - Click "Add Users" → Add your Gmail address → "Add"
   - Click "Save and Continue" → "Back to Dashboard"

5. **Create OAuth Client ID**:
   - Go to "APIs & Services" → "Credentials"
   - Click "+ CREATE CREDENTIALS" → "OAuth client ID"
   - Application type: **Desktop app**
   - Name: `Quotation App Desktop`
   - Click "CREATE"
   - **COPY THE CLIENT ID** (it looks like: `123456789-abcdefghijklmnop.apps.googleusercontent.com`)

## Step 2: Add Client ID to Configuration File (1 minute)

1. Open: `lib/config/oauth_config.dart`

2. Find the line:
   ```dart
   static const String clientId = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';
   ```

3. Replace with your actual Client ID:
   ```dart
   static const String clientId = '123456789-abcdefghijklmnop.apps.googleusercontent.com';
   ```
   (Use the Client ID you copied from Google Cloud Console)

4. Save the file

**Note**: The `oauth_config.dart` file is in `.gitignore` so your credentials won't be committed to version control.

## Step 3: Test (2 minutes)

1. Run: `flutter run -d windows`
2. Login as admin
3. Go to Settings
4. Click "Sign In to Google Drive"
5. Chrome opens → Sign in → Click "Allow"
6. Done! ✅

## Common Issues

**"Please configure your OAuth Client ID"**
→ You haven't replaced `YOUR_CLIENT_ID_HERE` in the code

**"Token exchange failed"**
→ Make sure you added the scope `drive.file` in OAuth consent screen

**"Authentication timeout"**
→ Complete the sign-in within 2 minutes

