# Security Fix Guide: Addressing Exposed API Key

This guide provides step-by-step instructions for removing the exposed Google API key from the GitHub repository and implementing proper security practices.

## 1. Remove the exposed API key file

Go to GitHub and remove the file containing the sensitive key:

1. Navigate to: https://github.com/daog869/ios-sdk/blob/main/Vizion%20Gateway/GoogleService-Info.plist
2. Click the "Delete this file" button (trash icon)
3. Add a commit message: "Remove GoogleService-Info.plist with exposed API key"
4. Commit the change

## 2. Regenerate your Google API key

Since the previous key has been exposed, you should regenerate it in Google Cloud Console:

1. Log in to [Google Cloud Console](https://console.cloud.google.com/)
2. Go to the "Vizion Gateway" project
3. Navigate to "APIs & Services" > "Credentials"
4. Find the exposed API key (<<<<YOUR><</YOUR>API>>>>>>)
5. Either:
   - Click on it and select "Regenerate key", or
   - Create a new key and delete the compromised one
6. Apply appropriate restrictions to the new key:
   - Limit it to specific APIs that you're actually using
   - Restrict by HTTP referrers or IP addresses if possible

## 3. Update your local environment

After removing the file from GitHub and regenerating the key:

1. Create a local version of `GoogleService-Info.plist` using the template
2. Add your new API key and other Firebase configuration values
3. Test to ensure everything works correctly

## 4. Optional: Purge sensitive data from Git history

If you need to completely remove the sensitive data from Git history:

```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch 'Vizion Gateway/GoogleService-Info.plist'" \
  --prune-empty --tag-name-filter cat -- --all

# Force push the changes to GitHub
git push origin --force --all
```

Note: This rewrites Git history and should be used with caution, especially on shared repositories.

## 5. Best practices moving forward

- Always use the `.gitignore` file to exclude sensitive configuration files
- Use template files with placeholders for sensitive values
- Consider using environment variables or secure storage for API keys
- Regularly audit your repository for accidentally committed secrets
- Add API key restrictions in Google Cloud Console (IP, referrer, or API restrictions)
- Consider using a secret scanning service for your repository 
