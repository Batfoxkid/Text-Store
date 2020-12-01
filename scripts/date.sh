SEC=$(date "+%s")
echo "DATA_VERSION<<EOF" >> $GITHUB_ENV
echo $(expr $((SEC)) / 60) >> $GITHUB_ENV
echo 'EOF' >> $GITHUB_ENV