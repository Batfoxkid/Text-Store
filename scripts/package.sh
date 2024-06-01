# Go to build dir
cd build

# Create package dir
mkdir -p package/addons/sourcemod/plugins/disabled
mkdir -p package/addons/sourcemod/data/textstore
mkdir -p package/addons/sourcemod/configs

# Copy all required stuffs to package
cp -r addons/sourcemod/plugins/textstore.smx package/addons/sourcemod/plugins
cp -r addons/sourcemod/plugins/textstore_defaults.smx package/addons/sourcemod/plugins/disabled
cp -r addons/sourcemod/plugins/textstore_generic.smx package/addons/sourcemod/plugins/disabled
cp -r addons/sourcemod/plugins/textstore_sqlite.smx package/addons/sourcemod/plugins/disabled
cp -r addons/sourcemod/plugins/textstore_mysql.smx package/addons/sourcemod/plugins/disabled
cp -r addons/sourcemod/plugins/textstore_tf2.smx package/addons/sourcemod/plugins/disabled
cp -r ../addons/sourcemod/configs/textstore package/addons/sourcemod/configs