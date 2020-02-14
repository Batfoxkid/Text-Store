SEC=$(date "+%s")
HOUR=$(expr $((SEC)) / 3600)
echo ::set-env name=DATE_VERSION::$HOUR
