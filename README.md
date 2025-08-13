
## IMPORTANT NOTICE

Versions v1, and v1.0.1 of this action have been disabled due to a potential security risk. Please upgrade to v2, which contains a fix for the issue.

If you have previously used this action with the upload directory (`path` parameter) pointed at the repository root (or a different directory containing a `.git` directory)
please note that before v4 this action did not exclude the `.git` directory from the upload. If you are affected by this, you should check your uploaded workshop items for any `.git` directories,
and in case they contain any stored credentials, invalidate/revoke them as soon as possible.

For more details, see the full security advisory published here:
https://github.com/BoldestDungeon/steam-workshop-deploy/security/advisories/GHSA-x6gv-2rvh-qmp6

The new version v4 of this action excludes `.git` directories and other common sensitive files by default. It also adds support for custom exclusion rules through a `.deployignore` file.

Thanks to @Gamebuster19901 for reporting this issue and implementing the fix.


# Steam Workshop Deploy

Github Action to upload items to the Steam Workshop. 
Supports an alternative Steam Guard 2FA approach that does not require the TOTP seed.
Instead, you can login through SteamCMD on your local computer once, and then add the session data to a GitHub secret.

Based on [Steam Deploy](https://github.com/game-ci/steam-deploy) by Webber Takken

## Setup

In order to configure this action, add a step that looks like the following:

_(The parameters are explained below)_

Option A. Using SteamCMD MFA files

```yaml
jobs:
  workshopUpload:
    runs-on: ubuntu-latest
    steps:
      - uses: m00nl1ght-dev/steam-workshop-deploy@v3
        with:
          username: ${{ secrets.STEAM_USERNAME }}          
          configVdf: ${{ secrets.STEAM_CONFIG_VDF }}
          path: build
          appId: 1234560
          publishedFileId: 1234560
```

Option B. Using TOTP

```yaml
jobs:
  workshopUpload:
    runs-on: ubuntu-latest
    steps:
      - uses: CyberAndrii/steam-totp@v1
        name: Generate TOTP
        id: steam-totp
        with:
          shared_secret: ${{ secrets.STEAM_SHARED_SECRET }}
      - uses: m00nl1ght-dev/steam-workshop-deploy@v3
        with:
          username: ${{ secrets.STEAM_USERNAME }}
          password: ${{ secrets.STEAM_PASSWORD }}
          totp: ${{ steps.steam-totp.outputs.code }}
          path: build
          appId: 1234560
          publishedFileId: 1234560
```

## Configuration

#### username

The username of the Steam Account that owns the workshop item.

#### configVdf

If Multi-Factor Authentication (MFA) through Steam Guard is enabled for the account, a valid TOTP code is required for login.
This means that simply using username and password isn't enough to authenticate with Steam. 
However, it is possible to go through the MFA process only once by setting up GitHub Secrets for `configVdf` with these steps:
1. Install [Valve's offical steamcmd](https://partner.steamgames.com/doc/sdk/uploading#1) on your local machine. All following steps will be done on your local machine.
1. Try to login with `steamcmd +login <username> <password> +quit`, which may prompt for the MFA code. If so, type in the MFA code that was emailed to your Steam account's email address.
1. Validate that the MFA process is complete by running `steamcmd +login <username> +quit` again. It should not ask for the MFA code again.
1. The folder from which you run `steamcmd` will now contain an updated `config/config.vdf` file. Copy the contents of `config.vdf` to a GitHub Secret `STEAM_CONFIG_VDF`.
1. `If:` when running the action you receive another MFA code via email, run `steamcmd +set_steam_guard_code <code>` on your local machine and replace the secret `STEAM_CONFIG_VDF` with the new `config.vdf` file contents.

#### password

The password of the Steam Account that owns the workshop item. Only required if `configVdf` is not set.

#### totp

A valid Steam Guard TOTP code. Only required if `configVdf` is not set, and Steam Guard is enabled for the account.

#### appId

The app identifier of the workshop to upload the item to.

#### publishedFileId

The id of the workshop item to be uploaded.

#### path

The path of the directory to be uploaded, relative to the repository root.

#### changeNote

An optional changenote to describe the update.
