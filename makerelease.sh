#!/bin/bash

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

rm DebugPlus.zip 2>/dev/null

sed -i 's/"version": ".*"/"version": "'"$VERSION"'"/' smods.json
zip -r ./DebugPlus.zip lovely/ assets/ debugplus README.MD *.txt docs/ smods.json

echo "Zip made for v$VERSION!"
echo
echo "If your releasing remeber to:"
echo "- Update changelog"
echo "- git add ."
echo "- git commit -m \"chore: bump to v$VERSION\""
echo "- git tag -a v$VERSION -m \"Release v$VERSION\""
echo "- git push"
echo "- git push origin master:stable"
echo "- git push origin v$VERSION"
echo "- Make a release with title 'DebugPlus v$VERSION' and desc as the changelog'"
echo "  - https://github.com/WilsontheWolf/DebugPlus/releases/new?tag=v$VERSION&title=DebugPlus%20v$VERSION"
echo "  - Don't forget to upload zip"
echo "- Change version after release so you don't have dev versions with the same build version!"
