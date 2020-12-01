SEC=$(date "+%s")
DATA_VERSION=$(expr $((SEC)) / 60)
echo "DATA_VERSION<<EOF" >> $GITHUB_ENV
echo $DATA_VERSION >> $GITHUB_ENV
echo 'EOF' >> $GITHUB_ENV