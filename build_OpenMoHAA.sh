#!/usr/bin/env zsh

# ANSI colour codes
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

# This just gets the location of the folder where the script is run from. 
SCRIPT_DIR=${0:a:h}
cd "$SCRIPT_DIR"

introduction() {
	echo "\n${PURPLE}This script uses OpenMoHAA to create a macOS bundle of:${NC}"
	echo "${GREEN}Medal of Honor: Allied Assault${NC}"
	echo "${GREEN}Medal of Honor: Spearhead${NC}"
	echo "${GREEN}Medal of Honor: Breakthrough${NC}"
	
	echo "${PURPLE}Place the macOS build of OpenMoHAA into your GoG game data folder.${NC}"
	echo "${PURPLE}Place this script in as well and run it from there.${NC}"
}

homebrew_check() {
	echo "${PURPLE}Checking for Homebrew...${NC}"
	if ! command -v brew &> /dev/null; then
		echo "${PURPLE}Homebrew not found. Installing Homebrew...${NC}"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		if [[ "${ARCH}" == "arm64" ]]; then 
			(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
			eval "$(/opt/homebrew/bin/brew shellenv)"
		else 
			(echo; echo 'eval "$(/usr/local/bin/brew shellenv)"') >> $HOME/.zprofile
			eval "$(/usr/local/bin/brew shellenv)"
		fi
		
		# Check for errors
		if [ $? -ne 0 ]; then
			echo "${RED}There was an issue installing Homebrew${NC}"
			echo "${PURPLE}Quitting script...${NC}"	
			exit 1
		fi
	else
		echo "${PURPLE}Homebrew found. Updating Homebrew...${NC}"
		brew update
	fi
}

# Function for checking for an individual dependency
single_dependency_check() {
	if [ -d "$(brew --prefix)/opt/$1" ]; then
		echo "${GREEN}Found $1. Checking for updates...${NC}"
		brew upgrade $1
	else
		 echo "${PURPLE}Did not find $1. Installing...${NC}"
		brew install $1
	fi
}

# Install required dependencies
check_all_dependencies() {
	echo "${PURPLE}Checking for Homebrew dependencies...${NC}"
	# Required Homebrew packages
	deps=( bison cmake flex ninja openal-soft sdl2 )
	
	for dep in $deps[@]
	do 
		single_dependency_check $dep
	done
}

set_vars() {
	echo "${PURPLE}Setting variables...${NC}"
	ARCH="$(uname -m)"
	APP_SUPP=~/Library/Application\ Support/openmohaa
	GAME_ID="openmohaa"
	PKGINFO_TITLE="OMOH"
	
	if [[ $1 == 0 ]]; then 
		GAME_TITLE="MoH Allied Assault"
		LAUNCH_CODE="0"
		ICON_URL="https://parsefiles.back4app.com/JPaQcFfEEQ1ePBxbf6wvzkPMEqKYHhPYv8boI1Rc/87512f5188f252cd2211156668142c54_Medal_of_Honor_Allied_Assault.icns"
	elif [[ $1 == 1 ]]; then 
		GAME_TITLE="MoH Spearhead"
		LAUNCH_CODE="1"
		ICON_URL="https://parsefiles.back4app.com/JPaQcFfEEQ1ePBxbf6wvzkPMEqKYHhPYv8boI1Rc/9f16790bc29e081b0fe923a8e84cd5da_Medal_of_Honor_Spearhead.icns"
	elif [[ $1 == 2 ]]; then 
		GAME_TITLE="MoH Breakthrough"
		LAUNCH_CODE="2"
		ICON_URL="https://parsefiles.back4app.com/JPaQcFfEEQ1ePBxbf6wvzkPMEqKYHhPYv8boI1Rc/bb0753c58736863e6b5f68e83028cf6f_Medal_of_Honor_Breakthrough.icns"
	fi
}

check_for_main() {
	if [ -d "${SCRIPT_DIR}/main" ]; then 
		echo "${GREEN}Found \"main\" game data in script folder${NC}"
		MAIN_DIR="${SCRIPT_DIR}/main"
	elif if [ -d "${APP_SUPP}/main" ]; then
		echo "${GREEN}Found \"main\" game data in the Application Support folder${NC}"
		MAIN_DIR="${APP_SUPP}/main"
	else 
		echo "${RED}Couldn't find the \"main\" game data folder${NC}"
		echo "${PURPLE}Please run this script alongside the game data${NC}"
		exit 0
	fi
}

check_for_mainta() {
	if [ -d "${SCRIPT_DIR}/mainta" ]; then 
		echo "${GREEN}Found \"mainta\" game data in script folder${NC}"
		MAINTA_DIR="${SCRIPT_DIR}/mainta"
	elif if [ -d "${APP_SUPP}/mainta" ]; then
		echo "${GREEN}Found \"mainta\" game data in the Application Support folder${NC}"
		MAINTA_DIR="${APP_SUPP}/mainta"
	else 
		echo "${RED}Couldn't find the \"mainta\" game data folder${NC}"
		echo "${PURPLE}Please run this script alongside the game data${NC}"
		exit 0
	fi
}

check_for_maintt() {
	if [ -d "${SCRIPT_DIR}/maintt" ]; then 
		echo "${GREEN}Found \"maintt\" game data in script folder${NC}"
		MAINTT_DIR="${SCRIPT_DIR}/maintt"
	elif if [ -d "${APP_SUPP}/maintt" ]; then
		echo "${GREEN}Found \"maintt\" game data in the Application Support folder${NC}"
		MAINTT_DIR="${APP_SUPP}/maintt"
	else 
		echo "${RED}Couldn't find the \"maintt\" game data folder${NC}"
		echo "${PURPLE}Please run this script alongside the game data${NC}"
		exit 0
	fi
}

build() {
	echo "${PURPLE}Cloning repository...${NC}"
	git clone https://github.com/openmoh/openmohaa
	cd openmohaa
	
	echo "${PURPLE}Setting build parameters...${NC}"
	cmake . -B build -GNinja -DOPENAL_INCLUDE_DIR="$(brew --prefix)/Cellar/openal-soft/1.24.0/include/AL"
	echo "${PURPLE}Building...${NC}"
	ninja -C build
	
	cd ..
	mv openmohaa/build/omohaaded.$ARCH .
	mv openmohaa/build/openmohaa.$ARCH .
	mv openmohaa/build/code/client/cgame/cgame.$ARCH.dylib .
	mv openmohaa/build/code/server/fgame/game.$ARCH.dylib .
}

# Create the app bundle
bundle() {
	
	# removing any pre-existing app bundle
	rm -rf "${GAME_TITLE}.app"
	mkdir -p "${GAME_TITLE}.app/Contents/Resources"
	mkdir -p "${GAME_TITLE}.app/Contents/MacOS"
	
	# create Info.plist
	PLIST="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
	<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
	<plist version=\"1.0\">
	<dict>
		<key>CFBundleDevelopmentRegion</key>
		<string>English</string>
		<key>CFBundleGetInfoString</key>
		<string>${GAME_TITLE}</string>
		<key>CFBundleExecutable</key>
		<string>launch_${GAME_ID}.sh</string>
		<key>CFBundleIconFile</key>
		<string>${GAME_ID}.icns</string>
		<key>CFBundleIdentifier</key>
		<string>com.github.openmoh.${GAME_ID}.${LAUNCH_CODE}</string>
		<key>CFBundleInfoDictionaryVersion</key>
		<string>6.0</string>
		<key>CFBundleName</key>
		<string>${GAME_TITLE}</string>
		<key>CFBundlePackageType</key>
		<string>APPL</string>
		<key>CFBundleSupportedPlatforms</key>
		<array>
			<string>MacOSX</string>
		</array>
		<key>CFBundleShortVersionString</key>
		<string>1.0</string>
		<key>CFBundleVersion</key>
		<string>1.0</string>
		<key>LSMinimumSystemVersion</key>
		<string>11.0</string>
		<key>NSPrincipalClass</key>
		<string>NSApplication</string>
		<key>NSHumanReadableCopyright</key>
		<string>OpenMoH Contributors</string>
		<key>NSHighResolutionCapable</key>
		<true/>
		<key>LSApplicationCategoryType</key>
		<string>public.app-category.games</string>
		<key>LSArchitecturePriority</key>
		<array>
			<string>arm64</string>
		</array>
	</dict>
	</plist>
	"
	echo "${PLIST}" > "${GAME_TITLE}.app/Contents/Info.plist"
	
	# Create PkgInfo
	PKGINFO="-n APPL${PKGINFO_TITLE}"
	echo "${PKGINFO}" > "${GAME_TITLE}.app/Contents/PkgInfo"
	
	# Create launch script and set executable permissions
	echo "${PURPLE}Creating launcher script...${NC}"
	LAUNCHER="#!/usr/bin/env zsh
	
	SCRIPT_DIR=\${0:a:h}
	cd "\$SCRIPT_DIR"
	
	./${GAME_ID} +set com_target_game ${LAUNCH_CODE}"
	echo "${LAUNCHER}" > "${GAME_TITLE}.app/Contents/MacOS/launch_${GAME_ID}.sh"
	chmod +x "${GAME_TITLE}.app/Contents/MacOS/launch_${GAME_ID}.sh"
	
	# Copy resources
	echo "${PURPLE}Copying resources...${NC}"
	cp openmohaa.${ARCH} ${GAME_TITLE}.app/Contents/MacOS/openmohaa
	cp omohaaded.${ARCH} ${GAME_TITLE}.app/Contents/MacOS/omohaaded
	cp cgame.${ARCH}.dylib ${GAME_TITLE}.app/Contents/MacOS
	cp game.${ARCH}.dylib ${GAME_TITLE}.app/Contents/MacOS
	
	ditto $(brew --prefix)/opt/openal-soft/lib/libopenal.1.dylib ${GAME_TITLE}.app/Contents/MacOS/libopenal.1.dylib
	
	echo "${PURPLE}Copying game data...${NC}"
	
	if [[ $LAUNCH_CODE == "0" ]]; then 
		copy_main
	elif [[ $LAUNCH_CODE == "1" ]]; then 
		copy_main
		copy_mainta
	elif [[ $LAUNCH_CODE == "2" ]]; then
		copy_main
		copy_maintt
	fi
	
	echo "${PURPLE}Retrieving icon from macosicons.com...${NC}"
	curl -o ${GAME_TITLE}.app/Contents/Resources/${GAME_ID}.icns ${ICON_URL}
	
	dylibbundler -of -cd -b -x ${GAME_TITLE}.app/Contents/MacOS/openmohaa -d ${GAME_TITLE}.app/Contents/libs/

	# Check for errors
	if [ $? -ne 0 ]; then
		echo "\n${RED}An error occured when bundling the app${NC}\n"	
	else 
		echo "\n${PURPLE}App bundled successfully...${NC}\n"
	fi
}

copy_main() {	
	mkdir -p $DATA_DESTINATION/main
	cp -a "${MAIN_DIR}/sound" $DATA_DESTINATION/main/sound
	cp -a "${MAIN_DIR}/video" $DATA_DESTINATION/main/video
	cp ${MAIN_DIR}/*.pk3 $DATA_DESTINATION/main
	
	if [ ! -e $APP_SUPP/main/configs/omconfig.cfg ]; then
		mkdir -p $APP_SUPP/main/configs
		set_config main
	fi
	
}

copy_mainta() {
	mkdir -p $DATA_DESTINATION/mainta/configs
	cp -a "${MAINTA_DIR}/music" $DATA_DESTINATION/mainta/music
	cp -a "${MAINTA_DIR}/sound" $DATA_DESTINATION/mainta/sound
	cp -a "${MAINTA_DIR}/video" $DATA_DESTINATION/mainta/video
	cp ${MAINTA_DIR}/*.pk3 $DATA_DESTINATION/mainta
	
	if [ ! -e $APP_SUPP/mainta/configs/omconfig.cfg ]; then
		mkdir -p $APP_SUPP/mainta/configs
		set_config mainta
	fi
	
}

copy_maintt() {
	mkdir -p $DATA_DESTINATION/maintt/configs
	cp -a "${MAINTT_DIR}/sound" $DATA_DESTINATION/maintt/sound
	cp -a "${MAINTT_DIR}/video" $DATA_DESTINATION/maintt/video
	cp ${MAINTT_DIR}/*.pk3 $DATA_DESTINATION/maintt
	
	if [ ! -e $APP_SUPP/maintt/configs/omconfig.cfg ]; then
		mkdir -p $APP_SUPP/maintt/configs 
		set_config maintt
	fi
	
}

set_config() {
	echo "${PURPLE}Getting screen resolution and creating config file for $1...${NC}"

	WIDTH=$(system_profiler SPDisplaysDataType | awk '/Resolution/{print $2}')
	HEIGHT=$(system_profiler SPDisplaysDataType | awk '/Resolution/{print $4}')
	
	# This differs from the default config only for: r_customheight, r_customwidth, r_mode
	CONFIG='// generated by openmohaa
//
// Key Bindings
//
unbindall
bind TAB "+scores"
bind ESCAPE "togglemenu"
bind SPACE "+moveup"
bind 1 "useweaponclass pistol"
bind 2 "useweaponclass rifle"
bind 3 "useweaponclass smg"
bind 4 "useweaponclass mg"
bind 5 "useweaponclass grenade"
bind 6 "useweaponclass heavy"
bind 7 "toggleitem"
bind ` "toggleconsole"
bind a "+moveleft"
bind c "+leanright"
bind d "+moveright"
bind e "+use"
bind h "weapdrop"
bind p "pushmenu_weaponselect"
bind q "holster"
bind r "reload"
bind s "+back"
bind t "sayteam"
bind u "pushmenu_teamselect"
bind v "instamsg_main"
bind w "+forward"
bind y "say"
bind z "+leanleft"
bind PAUSE "pause"
bind CTRL "+movedown"
bind SHIFT "+speed"
bind F2 "ui_getplayermodel;pushmenu_dm mpoptions"
bind F3 "pushmenu Controls"
bind F4 "pushmenu_sp LoadSave"
bind F5 "savegame quick"
bind F6 "messagemode"
bind F9 "loadgame quick"
bind F12 "screenshot"
bind MOUSE1 "+attackprimary"
bind MOUSE2 "+attacksecondary"
bind MWHEELDOWN "weapprev"
bind MWHEELUP "weapnext"
//
// Cvars
//
seta net_socksPassword ""
seta net_socksUsername ""
seta net_socksPort "1080"
seta net_socksServer ""
seta net_socksEnabled "0"
seta net_mcast6iface ""
seta net_mcast6addr "ff04::696f:7175:616b:6533"
seta net_enabled "3"
seta com_pipefile ""
seta ui_startmap ""
seta cl_greenfps "0"
seta ui_itemsbar "0"
seta ui_weaponsbartime "2500"
seta ui_weaponsbar "1"
seta ui_console "0"
seta ui_consoleposition ""
seta ui_gmbox "1"
seta ui_minicon "0"
seta ui_compass_scale "0.5"
seta s_obstruction_cal_time "500"
seta s_speaker_type "0"
seta s_reverb "0"
seta s_milesdriver "auto"
seta s_dialogscale "1"
seta s_mixPreStep "0.05"
seta s_loadas8bit "0"
seta s_khz "11"
seta s_separation "0.5"
seta s_ambientvolume "1.00"
seta s_musicvolume "0.9"
seta s_volume "0.9"
seta joy_threshold "0.15"
seta in_joystick "0"
seta in_nograb "0"
seta in_mouse "1"
seta in_keyboardDebug "0"
seta r_preferOpenGLES "-1"
seta r_centerWindow "0"
seta r_allowResize "0"
seta r_screenshotJpegQuality "90"
seta r_stereoEnabled "0"
seta r_ext_texture_filter_anisotropic "0"
seta r_noborder "0"
seta r_ext_multisample "0"
seta ter_fastMarks "1"
seta ter_minMarkRadius "8"
seta r_sse "0"
seta vss_smoothsmokelight "1"
seta r_debuglines_depthmask "0"
seta r_lightcoronasize ".1"
seta r_light_nolight "0"
seta r_light_int_scale "0.05"
seta r_stipplelines "1"
seta r_entlight_maxcalc "2"
seta r_entlight_cubefraction "0.5"
seta r_entlight_cubelevel "0"
seta r_entlight_errbound "6"
seta r_fastentlight "1"
seta r_lodviewmodelcap "0.25"
seta r_lodcap "0.35"
seta r_lodscale "5"
seta r_primitives "0"
seta r_facePlaneCull "1"
seta r_gamma "1"
seta r_swapInterval "0"
seta r_textureMode "GL_LINEAR_MIPMAP_NEAREST"
seta r_finish "0"
seta r_dlightBacks "1"
seta r_drawSun "0"
seta r_fastdlights "1"
seta r_ignoreGLErrors "1"
seta r_flares "0"
seta r_lodCurveError "250"
seta r_subdivisions "4"
seta r_ignoreFastPath "0"
seta r_smp "0"
seta r_vertexLight "0"
seta r_customaspect "1"
seta r_customheight "'$HEIGHT'"
seta r_customwidth "'$WIDTH'"
seta r_mode "-1"
seta r_vidmodemax "1"
seta r_vidmode1024 "1"
seta r_maxmode "6"
seta r_ignorehwgamma "0"
seta r_overBrightBits "0"
seta r_depthbits "0"
seta r_stencilbits "8"
seta r_stereo "0"
seta r_colorbits "0"
seta r_texturebits "0"
seta r_textureDetails "1"
seta r_roundImagesDown "1"
seta r_picmip "1"
seta r_reset_tc_array "1"
seta r_geForce3WorkAround "1"
seta r_ext_max_anisotropy "2"
seta r_ext_aniso_filter "0"
seta r_ext_texture_env_combine "0"
seta r_ext_texture_env_add "1"
seta r_ext_compiled_vertex_array "1"
seta r_ext_multitexture "1"
seta r_ext_gamma_control "1"
seta r_ext_compressed_textures "0"
seta r_allowExtensions "1"
seta r_glDriver "libGL.so"
seta cg_viewsize "100"
seta cg_predictItems "1"
seta dm_playergermanmodel "german_wehrmacht_soldier"
seta dm_playermodel "american_army"
seta snaps "20"
seta rate "5000"
seta name "UnnamedSoldier"
seta cl_consoleKeys "~ ` 0x7e 0x60"
seta cl_forceModel "0"
seta cl_maxPing "800"
seta cg_autoswitch "1"
seta cl_guidServerUniq "1"
seta cl_lanForcePackets "1"
seta cl_radar_blink_time "0.333"
seta cl_radar_speak_time "3"
seta cl_radar_icon_size "10"
seta j_up_axis "4"
seta j_side_axis "0"
seta j_forward_axis "1"
seta j_yaw_axis "2"
seta j_pitch_axis "3"
seta j_up "0"
seta j_side "0.25"
seta j_forward "-0.25"
seta j_yaw "-0.022"
seta j_pitch "0.022"
seta m_filter "1"
seta m_side "0.25"
seta m_forward "0.25"
seta m_yaw "0.022"
seta m_pitch "0.022"
seta r_fullscreen "1"
seta r_inGameVideo "0"
seta cl_allowDownload "0"
seta cl_mouseAccelOffset "5"
seta cl_mouseAccelStyle "0"
seta cl_freelook "1"
seta cl_mouseAccel "0"
seta sensitivity "5"
seta cl_run "1"
seta cl_packetdup "1"
seta cl_maxpackets "30"
seta cl_pitchspeed "140"
seta cl_yawspeed "140"
seta cl_aviMotionJpeg "1"
seta cl_aviFrameRate "25"
seta cl_autoRecordDemo "0"
seta cl_timedemoLog ""
seta cl_master "master.2015.com"
seta g_ddayshingleguys "0"
seta g_ddayfog "2"
seta g_ddayfodderguys "0"
seta sv_banFile "serverbans.dat"
seta sv_strictAuth "1"
seta sv_lanForceRate "1"
seta sv_master5 ""
seta sv_master4 ""
seta sv_master3 ""
seta sv_master2 ""
seta sv_dlURL ""
seta sv_maplist ""
seta sv_floodProtect "0"
seta sv_maxPing "0"
seta sv_minPing "0"
seta sv_dlRate "100"
seta sv_maxRate "0"
seta sv_minRate "0"
seta sv_hostname "Nameless OpenMoHAA Battle"
seta con_autochat "1"
seta com_busyWait "0"
seta com_maxfpsMinimized "0"
seta com_maxfpsUnfocused "0"
seta com_ansiColor "0"
seta com_radar_range "1024"
seta fps "0"
seta autopaused "1"
seta com_maxfps "85"
seta com_altivec "0"
seta g_m6l3 "0"
seta g_m6l2 "0"
seta g_m6l1 "0"
seta g_m5l3 "0"
seta g_m5l2 "0"
seta g_m5l1 "0"
seta g_m4l3 "0"
seta g_m4l2 "0"
seta g_m4l1 "0"
seta g_m3l3 "0"
seta g_m3l2 "0"
seta g_m3l1 "0"
seta g_m2l3 "0"
seta g_m2l2 "0"
seta g_m2l1 "0"
seta g_m1l3 "0"
seta g_m1l2 "0"
seta g_m1l1 "1"
seta g_eogmedal2 "0"
seta g_eogmedal1 "0"
seta g_eogmedal0 "0"
seta g_medal5 "0"
seta g_medal4 "0"
seta g_medal3 "0"
seta g_medal2 "0"
seta g_medal1 "0"
seta g_medal0 "0"
seta g_subtitle "0"
seta g_skill "1"
seta detail "1"
seta ui_hostname "Nameless Battle"
seta ui_maplist_obj "obj/obj_team1 obj/obj_team2 obj/obj_team3 obj/obj_team4"
seta ui_maplist_round "dm/mohdm1 dm/mohdm2 dm/mohdm3 dm/mohdm4 dm/mohdm5 dm/mohdm6 dm/mohdm7"
seta ui_maplist_team "dm/mohdm1 dm/mohdm2 dm/mohdm3 dm/mohdm4 dm/mohdm5 dm/mohdm6 dm/mohdm7"
seta ui_maplist_ffa "dm/mohdm1 dm/mohdm2 dm/mohdm3 dm/mohdm4 dm/mohdm5 dm/mohdm6 dm/mohdm7"
seta ui_inactivekick "900"
seta ui_inactivespectate "60"
seta ui_connectip "0.0.0.0"
seta ui_teamdamage "0"
seta ui_timelimit "0"
seta ui_fraglimit "0"
seta ui_gamespy "1"
seta ui_maxclients "32"
seta ui_voodoo "0"
seta cl_ctrlbindings "0"
seta cl_altbindings "0"
seta ui_crosshair "1"
seta viewsize "100"
seta developer "0"
//
// Aliases
//'

echo "${PURPLE}Copying config file...${NC}"
echo "${CONFIG}" > "$APP_SUPP/$1/configs/omconfig.cfg" 

}


main_menu() {
	PS3='Which game would you like to bundle? '
	OPTIONS=(
		"Allied Assault"
		"Spearhead"
		"Breakthrough"
		"Quit")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Allied Assault")
				set_vars 0
				homebrew_check
				data_destination_menu
				if [ ! -d openmohaa ]; then 
					build
				fi
				check_for_main
				bundle
				repeat_menu
				;;
			"Spearhead")
				set_vars 1
				homebrew_check
				data_destination_menu
				if [ ! -d openmohaa ]; then 
					build
				fi
				check_for_main
				check_for_mainta
				bundle
				repeat_menu
				;;
			"Breakthrough")
				set_vars 2
				homebrew_check
				data_destination_menu
				if [ ! -d openmohaa ]; then 
					build
				fi
				check_for_main
				check_for_maintt
				bundle
				repeat_menu
				;;
			"Quit")
				echo -e "${RED}Quitting${NC}"
				exit 0
				;;
			*) 
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

data_destination_menu() {
	echo "${PURPLE}The game data can be copied into the app bundle or into the Application Support folder${NC}\n"
	echo "${PURPLE}If it is copied into the app, it will be more portable.${NC}"
	echo "${PURPLE}If it is copied to the Application Support folder, it is more convenient when updating the app and the game data does not need to be duplicated. This will save about 3.5GB of storage${NC}\n"
	
	PS3='Where would you like to copy the game data to? '
	OPTIONS=(
		"App Bundle"
		"Application Support")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"App Bundle")
				DATA_DESTINATION="${GAME_TITLE}.app/Contents/MacOS"
				break
				;;
			"Application Support")
				if [ ! -d "$APP_SUPP" ]; then
					mkdir $APP_SUPP
				fi
				DATA_DESTINATION="$APP_SUPP"
				break
				;;
			*) 
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

repeat_menu() {
	PS3='Would you like to create another app bundle? '
	OPTIONS=(
		"Yes"
		"Quit")
	select opt in $OPTIONS[@]
	do
		case $opt in
			"Yes")
				main_menu
				;;
			"Quit")
				cleanup
				echo -e "${RED}Quitting${NC}"
				exit 0
				;;
			*) 
				echo "\"$REPLY\" is not one of the options..."
				echo "Enter the number of the option and press enter to select"
				;;
		esac
	done
}

cleanup() {
	echo "${PURPLE}Cleaning up...${NC}"
	rm openmohaa.${ARCH}
	rm omohaaded.${ARCH}
	rm cgame.${ARCH}.dylib 
	rm game.${ARCH}.dylib
	
	rm -rf openmohaa
}

introduction
main_menu