SEC=$(date "+%s")
MIN=$(expr $((SEC)) / 60)
echo "DATA_VERSION=$MIN" >> $GITHUB_ENV