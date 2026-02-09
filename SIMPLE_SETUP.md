# 🚀 Simple Setup - 3 Steps

## Step 1: Get Your Client ID (5 minutes)

### Go to Google Cloud Console:
👉 **https://console.cloud.google.com/apis/credentials**

### Follow these steps:

1. **Create Project** (if you don't have one)
   - Click project dropdown → "New Project"
   - Name: `Quotation App`
   - Click "Create"

2. **Enable Google Drive API**
   - Click "APIs & Services" → "Library"
   - Search: `Google Drive API`
   - Click "Enable"

3. **Setup OAuth Consent Screen**
   - Click "APIs & Services" → "OAuth consent screen"
   - Choose "External" → Click "Create"
   - App name: `Quotation Application`
   - Your email: (select from dropdown)
   - Click "Save and Continue"
   - Click "Add or Remove Scopes"
   - Search: `drive.file` → Check the box → "Update"
   - Click "Save and Continue"
   - Click "Add Users" → Enter your Gmail → "Add"
   - Click "Save and Continue" → "Back to Dashboard"

4. **Create OAuth Client ID**
   - Click "APIs & Services" → "Credentials"
   - Click "+ CREATE CREDENTIALS" → "OAuth client ID"
   - Application type: **Desktop app**
   - Name: `Quotation App Desktop`
   - Click "CREATE"
   - **📋 COPY THE CLIENT ID** (it's a long string)
   - Click "OK"

5. **Add Redirect URI**
   - Click on your OAuth client (the one you just created)
   - Under "Authorized redirect URIs" → Click "ADD URI"
   - Enter: `http://localhost:8080/callback`
   - Click "SAVE"

---

## Step 2: Put Client ID in Code (1 minute)

### Open this file:
📁 `lib/config/oauth_config.dart`

### Find this line (line 14):
```dart
static const String clientId = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';
```

### Replace it with your Client ID:
```dart
static const String clientId = 'PASTE_YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';
```

**Example:**
If your Client ID is: `987654321-xyz123abc.apps.googleusercontent.com`

Then change to:
```dart
static const String clientId = '987654321-xyz123abc.apps.googleusercontent.com';
```

### Save the file (Ctrl+S)

---

## Step 3: Test (2 minutes)

1. Run: `flutter run -d windows`
2. Login as admin
3. Go to Settings
4. Click "Sign In to Google Drive"
5. Chrome opens → Sign in → Click "Allow"
6. Done! ✅

---

## 📋 What Your Client ID Looks Like

Your Client ID from Google will look like this:
```
123456789-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com
```

It has:
- Numbers at the start
- A hyphen (-)
- Random letters/numbers
- Ends with `.apps.googleusercontent.com`

---

## ❌ Common Mistakes

**Wrong:** 
```dart
static const String clientId = 'YOUR_CLIENT_ID_HERE.apps.googleusercontent.com';
```

**Right:**
```dart
static const String clientId = '123456789-abc...xyz.apps.googleusercontent.com';
```

**Wrong:** Copying Client Secret instead of Client ID
**Right:** Copy the **Client ID** (the first one shown)

**Wrong:** Forgetting to add redirect URI
**Right:** Add `http://localhost:8080/callback` in Google Cloud Console

---

## 🆘 Need Help?

See detailed guide: `OAUTH_CONFIGURATION_GUIDE.md`



