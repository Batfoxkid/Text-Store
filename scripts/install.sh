# Create build folder
mkdir build
cd build

# Install SourceMod
wget --input-file=http://sourcemod.net/smdrop/$SM_VERSION/sourcemod-latest-linux
tar -xzf $(cat sourcemod-latest-linux)

# Copy sp to build dir
cp -r ../addons/sourcemod/scripting addons/sourcemod
cd addons/sourcemod/scripting

# Install Dependency
wget "https://www.doctormckay.com/download/scripting/include/morecolors.inc" -O include/morecolors.inc

# Install Third-Parties
wget "https://raw.githubusercontent.com/Batfoxkid/FreakFortressBat/master/addons/sourcemod/scripting/include/freak_fortress_2.inc" -O include/freak_fortress_2.inc
wget "https://raw.githubusercontent.com/Totenfluch/tVip/master/include/tVip.inc" -O include/tVip.inc
