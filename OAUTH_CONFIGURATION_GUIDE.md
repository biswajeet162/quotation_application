# Complete OAuth Configuration Guide

## 📍 WHERE to Put the Values

**File Location**: `lib/config/oauth_config.dart`

This is the file you need to edit. It's already created and ready for you to add your Client ID.

---

## 🔑 WHAT Values You Need

You only need **ONE value**:
- **OAuth 2.0 Client ID** (looks like: `123456789-abcdefghijklmnop.apps.googleusercontent.com`)

---

## 📥 HOW to Get These Values (Step-by-Step)

### Step 1: Go to Google Cloud Console
1. Open your browser
2. Go to: **https://console.cloud.google.com/**
3. Sign in with your Google account

### Step 2: Create or Select a Project
1. Click the **project dropdown** at the top (next to "Google Cloud")
2. Click **"New Project"** (or select an existing one)
3. Enter project name: `Quotation App` (or any name you like)
4. Click **"Create"**
5. Wait for project creation (takes a few seconds)
6. Select the newly created project from the dropdown

### Step 3: Enable Google Drive API
1. In the left sidebar, click **"APIs & Services"** → **"Library"**
2. In the search box, type: **"Google Drive API"**
3. Click on **"Google Drive API"** from the results
4. Click the blue **"Enable"** button
5. Wait for it to enable (takes a few seconds)

### Step 4: Configure OAuth Consent Screen
1. In the left sidebar, click **"APIs & Services"** → **"OAuth consent screen"**
2. Choose **"External"** (unless you have Google Workspace, then choose "Internal")
3. Click **"Create"**

**Fill in the form:**
- **App name**: `Quotation Application`
- **User support email**: Select your email from dropdown
- **Developer contact information**: Enter your email
- Click **"Save and Continue"**

**Add Scopes:**
- Click **"Add or Remove Scopes"**
- In the filter box, type: `drive.file`
- Check the box next to: **`../auth/drive.file`**
- Click **"Update"**
- Click **"Save and Continue"**

**Add Test Users (if External):**
- Click **"Add Users"**
- Enter your Gmail address
- Click **"Add"**
- Click **"Save and Continue"**
- Click **"Back to Dashboard"**

### Step 5: Create OAuth Client ID
1. In the left sidebar, click **"APIs & Services"** → **"Credentials"**
2. Click the **"+ CREATE CREDENTIALS"** button at the top
3. Select **"OAuth client ID"**

**Fill in the form:**
- **Application type**: Select **"Desktop app"**
- **Name**: `Quotation App Desktop` (or any name)
- Click **"CREATE"**

**IMPORTANT - Copy Your Client ID:**
- A popup will appear showing your credentials
- You'll see: **"Client ID"** (this is what you need!)
- It looks like: `123456789-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com`
- **COPY THIS CLIENT ID** (click the copy icon or select and copy)
- Click **"OK"** to close the popup

### Step 6: Add Redirect URI (Important!)
1. In the **"Credentials"** page, find your newly created OAuth client
2. Click on it to edit
3. Under **"Authorized redirect URIs"**, click **"ADD URI"**
4. Enter: `http://localhost:8080/callback`
5. Click **"SAVE"**

---

## ✏️ HOW to Add the Value to Your Code

### Step 1: Open the Configuration File
1. In your IDE, open: `lib/config/oauth_config.dart`

### Step 2: Find the Client ID Line
Look for line 14 (or search for `YOUR_CLIENT_ID_HERE`):
```dart
static const String clientId = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';
```

### Step 3: Replace with Your Actual Client ID
Replace the entire value with your copied Client ID:
```dart
static const String clientId = '123456789-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com';
```

**Example:**
If your Client ID is: `987654321-xyz123abc.apps.googleusercontent.com`

Then change:
```dart
static const String clientId = '987654321-xyz123abc.apps.googleusercontent.com';
```

### Step 4: Save the File
- Press `Ctrl+S` (or File → Save)
- The file is now configured!

---

## ✅ Verify Your Configuration

After adding your Client ID, the file should look like this:

```dart
class OAuthConfig {
  static const String clientId = 'YOUR_ACTUAL_CLIENT_ID_HERE.apps.googleusercontent.com';
  // ... rest of the file stays the same
}
```

**Check:**
- ✅ No `YOUR_CLIENT_ID_HERE` text remaining
- ✅ Client ID ends with `.apps.googleusercontent.com`
- ✅ Client ID is a long string with numbers and letters

---

## 🧪 Test It

1. Run your app: `flutter run -d windows`
2. Login as admin
3. Go to Settings
4. Click **"Sign In to Google Drive"**
5. Chrome should open → Sign in → Grant permissions
6. Should work! ✅

---

## ❌ Common Mistakes

**Mistake 1**: Forgetting to add redirect URI
- **Fix**: Add `http://localhost:8080/callback` in Google Cloud Console

**Mistake 2**: Copying the wrong value
- **Fix**: Copy the **Client ID**, NOT the Client Secret (desktop apps don't use secret)

**Mistake 3**: Leaving quotes or extra spaces
- **Fix**: Make sure it's exactly: `'your-client-id.apps.googleusercontent.com'`

**Mistake 4**: Not adding test user
- **Fix**: If using External app type, add your Gmail as a test user

---

## 📋 Quick Checklist

- [ ] Created Google Cloud project
- [ ] Enabled Google Drive API
- [ ] Configured OAuth consent screen
- [ ] Added `drive.file` scope
- [ ] Created Desktop app OAuth client ID
- [ ] Copied the Client ID
- [ ] Added redirect URI: `http://localhost:8080/callback`
- [ ] Added test user (if External)
- [ ] Pasted Client ID in `oauth_config.dart`
- [ ] Saved the file

---

## 🆘 Still Having Issues?

If you get errors after configuration:

1. **"Please configure your OAuth Client ID"**
   - Check you replaced `YOUR_CLIENT_ID_HERE` in `oauth_config.dart`

2. **"Token exchange failed"**
   - Verify redirect URI is added in Google Cloud Console
   - Check Client ID is correct (no typos)

3. **"Access denied" or "Invalid client"**
   - Make sure you copied the full Client ID
   - Verify it ends with `.apps.googleusercontent.com`

4. **Browser opens but shows error**
   - Check test user is added (if External app)
   - Verify `drive.file` scope is added in consent screen

