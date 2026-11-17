# Terms of Service & Privacy Policy

> Last updated: 2026-11-17

Welcome to Songloft. Please read the following agreement carefully before using this software. By using this software, you acknowledge that you have read, understood, and agreed to be bound by this agreement.

## 1. Service Description

Songloft is an open-source, self-hosted local music server software released under the Apache-2.0 license. It allows users to deploy a music management and playback service on their own devices.

- **Self-hosted mode**: Users deploy the server themselves; all data is stored entirely on the user's own devices.
- **Local mode (Bundle)**: The Go backend runs embedded within the client; all data is stored locally.

## 2. User Conduct

By using this software, you agree to:

- **Lawful use**: Only use it to manage and play music content that you legally own or have authorization to use.
- **Respect copyrights**: Do not use this software to download, distribute, or disseminate unauthorized copyrighted content.
- **Personal responsibility**: You bear legal responsibility for all content stored and managed through this software.
- **No misuse**: Do not use this software for any activity that violates applicable laws and regulations.

## 3. Privacy Policy

### 3.1 Data Collection

Songloft **does not collect any personal user data**. All data is stored within your own deployment environment.

### 3.2 Telemetry & Monitoring

Pre-compiled releases include the Tracely monitoring SDK. Reported data includes only:

- Panic stack traces on crashes
- First installation events and version upgrade events
- Periodic activity heartbeats

This **does not include** user data, music files, account information, or any personally identifiable information. Self-compiled builds do not enable any telemetry.

### 3.3 Outbound Requests

| Scenario | Target | Content |
|----------|--------|---------|
| Crash reports (pre-compiled) | Maintainer's Tracely service | Error stack, version, platform info |
| Update checks | GitHub | HTTP GET version.json, no user identifiers |
| JS plugin network requests | Determined by plugin | Determined by plugin implementation |

### 3.4 Data Storage

| Data | Location | Notes |
|------|----------|-------|
| Account/Password | Local SQLite database | bcrypt hashed, no plaintext |
| JWT Token | Client local storage | Server only stores refresh token hash |
| Music/Covers/Lyrics | Local database + cache directory | Local only, never uploaded |
| Play history/Favorites | Local SQLite database | Local only |

### 3.5 Third-Party Plugins

JS plugins may access external services through host network capabilities. Data collection by third-party plugins is determined by the plugins themselves and is unrelated to the Songloft project. Please verify the network scope of any third-party plugin before installation.

## 4. Intellectual Property

- The Songloft software itself is open-sourced under the Apache-2.0 license.
- Copyright of music content managed through this software belongs to the original copyright holders.
- This software makes no guarantees regarding the legality of user-stored content.

## 5. Disclaimer

- This software is provided "as is" without any express or implied warranties.
- The developers are not liable for any direct or indirect damages arising from the use of this software.
- If you deploy this software for others to use, you become the data controller and must assume relevant legal responsibilities (including but not limited to compliance obligations under PIPL, GDPR, and other applicable regulations).

## 6. Changes to This Agreement

This agreement may be revised with software updates. Significant changes will be noted in the version changelog. Continued use of this software constitutes acceptance of the revised agreement.

## 7. Contact

If you have questions about this agreement, please provide feedback via GitHub Issues.
