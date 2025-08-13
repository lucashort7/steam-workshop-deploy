#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

steamdir=${STEAM_HOME:-$HOME/Steam}
# this is relative to the action
contentroot=$(pwd)/$rootPath

manifest_path=$(pwd)/manifest.vdf

echo ""
echo "##########################"
echo "# Calculating Deployment #"
echo "##########################"
echo ""

if [ "$concurrentStaging" == "true" ]; then
    stagingPath="$stagingPath/$GITHUB_SHA"
fi

mkdir -p "$stagingPath"

echo "Staging Path: $stagingPath"

if [ -z "$deployIgnore" ]; then
    if [ -f "$contentroot/.deployignore" ]; then
        deployIgnore="$contentroot/.deployignore"
        echo "Using user content root .deployignore at $deployIgnore"
    else
        deployIgnore=""
        echo "no user .deployignore found"
    fi
else
    # Make deployIgnore absolute if relative
    if [[ ! "$deployIgnore" = /* ]]; then
        deployIgnore="$contentroot/$deployIgnore"
    fi
    echo "Using user supplied deploy ignore file at $deployIgnore"
fi

RSYNC_EXCLUDE_PARAMS=()

if [ "$useBuiltinDeployIgnore" == "true" ]; then
    echo "Including built-in deploy ignore"
    RSYNC_EXCLUDE_PARAMS+=(--exclude-from=/root/.defaultdeployignore)
else
    echo "!!!!!!NOT USING BUILT IN DEPLOY IGNORE FILE!!!!!!"
fi

if [ -n "$deployIgnore" ]; then
    echo "Including user deploy ignore file $deployIgnore"
    RSYNC_EXCLUDE_PARAMS+=(--exclude-from="$deployIgnore")
fi

echo "# BuildIgnore Start #"

if [ "$useBuiltinDeployIgnore" = "true" ]; then
    cat /root/.defaultdeployignore || true
fi
echo ""
if [ -n "$deployIgnore" ]; then
    cat "$deployIgnore" || true
fi

echo "# BuildIgnore End #"

echo "Running rsync to package content..."

if [ "$verbosity" != "NORMAL" ]; then #NOTE: Documentation states that valid values are NORMAL and TRACE.
    rsync -av "${RSYNC_EXCLUDE_PARAMS[@]}" "$contentroot/" "$stagingPath"
else #assume TRACE
    rsync -a "${RSYNC_EXCLUDE_PARAMS[@]}" "$contentroot/" "$stagingPath"
fi


echo ""
echo "#################################"
echo "#    Generating Item Manifest   #"
echo "#################################"
echo ""

cat << EOF > "manifest.vdf"
"workshopitem"
{
    "appid" "$appId"
    "publishedfileid" "$itemId"
    "contentfolder" "$stagingPath"
    "changenote" "$changeNote"
}
EOF

cat manifest.vdf
echo ""

if [ ! -n "$configVdf" ]; then
  echo ""
  echo "#################################"
  echo "#     Using SteamGuard TOTP     #"
  echo "#################################"
  echo ""

  steamcmd +set_steam_guard_code "$steam_totp" +login "$steam_username" "$steam_password" +quit;

  ret=$?
  if [ $ret -eq 0 ]; then
      echo ""
      echo "#################################"
      echo "#        Successful login       #"
      echo "#################################"
      echo ""
  else
        echo ""
        echo "#################################"
        echo "#        FAILED login           #"
        echo "#################################"
        echo ""
        echo "Exit code: $ret"

        exit $ret
  fi
else
  if [ ! -n "$configVdf" ]; then
    echo "Config VDF input is missing or incomplete! Cannot proceed."
    exit 1
  fi

  steam_totp="INVALID"

  echo ""
  echo "#################################"
  echo "#    Copying SteamGuard Files   #"
  echo "#################################"
  echo ""

  echo "Steam is installed in: $steamdir"

  mkdir -p "$steamdir/config"

  echo "Copying $steamdir/config/config.vdf..."
  echo "$configVdf" > "$steamdir/config/config.vdf"
  chmod 777 "$steamdir/config/config.vdf"

  echo "Finished Copying SteamGuard Files!"
  echo ""

  echo ""
  echo "#################################"
  echo "#        Test login             #"
  echo "#################################"
  echo ""

  steamcmd +login "$steam_username" +quit;

  ret=$?
  if [ $ret -eq 0 ]; then
      echo ""
      echo "#################################"
      echo "#        Successful login       #"
      echo "#################################"
      echo ""
  else
        echo ""
        echo "#################################"
        echo "#        FAILED login           #"
        echo "#################################"
        echo ""
        echo "Exit code: $ret"

        exit $ret
  fi
fi

echo ""
echo "#################################"
echo "#        Uploading item         #"
echo "#################################"
echo ""

steamcmd +login "$steam_username" +workshop_build_item "$manifest_path" +quit || (
    echo ""
    echo "#################################"
    echo "#             Errors            #"
    echo "#################################"
    echo ""
    echo "Listing current folder and root path"
    echo ""
    ls -alh
    echo ""
    ls -alh "$rootPath" || true
    echo ""
    echo "Listing logs folder:"
    echo ""
    ls -Ralph "$steamdir/logs/"

    for f in "$steamdir"/logs/*; do
      if [ -e "$f" ]; then
        echo "######## $f"
        cat "$f"
        echo
      fi
    done

    echo ""
    echo "Displaying error log"
    echo ""
    cat "$steamdir/logs/stderr.txt"
    echo ""
    echo "Displaying bootstrapper log"
    echo ""
    cat "$steamdir/logs/bootstrap_log.txt"

    exit 1
  )

echo "manifest=${manifest_path}" >> $GITHUB_OUTPUT
