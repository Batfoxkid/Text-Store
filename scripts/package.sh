# Go to build dir
cd build

# Create package dir
mkdir -p package/addons/sourcemod/plugins
mkdir -p package/addons/sourcemod/configs

# Copy all required stuffs to package
cp -r addons/sourcemod/plugins/batstore.smx package/addons/sourcemod/plugins
cp -r addons/sourcemod/plugins/batstore_defaults.smx package/addons/sourcemod/plugins
cp -r addons/sourcemod/plugins/batstore_generic.smx package/addons/sourcemod/plugins
cp -r addons/sourcemod/plugins/batstore_tf2.smx package/addons/sourcemod/plugins
cp -r ../addons/sourcemod/configs/batstore package/addons/sourcemod/configs
