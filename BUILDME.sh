#!/bin/bash
set -euo pipefail; trap 'debugger $LINENO "$BASH_COMMAND"' ERR # Debug Mode (Comment/Uncomment as needed)

# ⚙ CONFIGURATION
declare -Ar INFO=( [NAME]="Lost Builder" [VERSION]="1.5.1" [CREATOR]="Rai López" [DESC]="Lost Project's Development Helper" )
declare -ar INCLUDE=( "Embed" "Menu" "Modules" "ScriptResources" "Smart" "Tool" "Utility" "docs" "README.md" "LICENSE" ) # Note: Make sure the element doesn't remain orphaned in Core if you remove it from here!
declare -ar SYNC=( "Modules" "Tool" "Utility" "ScriptResources" "Menu" "Embed" "Smart" ) # Pack folders for syncing...
declare -Ar VARS=( [DEP]="ScriptDep" [VER]="ScriptVersion" [BLD]="ScriptBuild" [DSC]="ScriptDesc" [TAR]="ScriptTarget" ) # Script header variables (if "ScriptDep" is present in a .lua file, it's considered a pack!)
declare -Ar VAREXS=( [S]='s/.*=[[:space:]]*["'\'']\([^"'\'']*\)["'\''].*/\1/p' [A]='s/[^=]*=[[:space:]]*//; s/[^"'\'']*["'\'']\([^"'\'']*\)["'\'']/\1 /g' ) # Script header variable extractors
declare -Ar FORGE=( [BASE]="github.com" [BRAW]="raw.githubusercontent.com" [USER]="RaiLopez" [PREF]="git@github-railopez" ) # URL, contentUrl, username, remotePrefix (SSH Alias)
declare -r  CORE="ls"
declare -r  CORE_DEST="../$CORE"
declare -r  STRIP_YAML=true
declare -r  DISTDIR="_dist" # Specifying a directory implies creating ZIPs (assuming zip.exe & bzip2.dll exist in %ProgramFiles%\Git\usr\bin)
declare -ar ZIPIGNORE=( "README.md" "LICENSE" "docs" "docs/*" "*/docs/*" "*.zip" )
declare --  PUBLISH=false # Requires the script folder has a repo and 'origin' remote
declare --  CATALOG_DATA=$(mktemp)
declare -A  REPORT=( [DUR]=0 [TOT]=0 [LOC]=0 [PUB]=0 [ISS]=0)
declare --  T_R='\e[1;31m'; T_G='\e[1;32m'; T_Y='\e[1;33m'; T_B='\e[1;34m'; T_D='\e[2m'; T_S='\e[1m' ; T_U='\e[4m'; T_C='\e['; T_N='\e[0m' # Text: Red; Green; Yellow; Blue; Dim; Strong, UL; Custom; Normal (reset)

# 🛠️ HELPER FUNCTIONS
debugger(){ # Debug Mode helper for catching errors before closing
	echo -ne "--- ❌ ${T_R}ERROR @ line $1${T_N}: $2 ${T_D}(Press any key to exit) ${T_N}" && read -n 1 -s && exit
} # USAGE: unnatended (to be used by trap)

zipper() { # .ZIP packaging function: id ($1), target_path ($2)
	local id="$1"; local target="$2"
	[[ -z "$DISTDIR" ]] || ! command -v zip >/dev/null 2>&1 && return
	(
		cd "$target" || exit
		mkdir -p "$DISTDIR"
		local exclude_args=(-x ".git*" "$DISTDIR/*" "$DISTDIR") # Build exclusions array (Bash-friendly)
		for p in "${ZIPIGNORE[@]}"; do exclude_args+=("-x" "$p"); done
		zip -rq "$DISTDIR/${id}.zip" . "${exclude_args[@]}" # Execute zip with the array of arguments (preserves quotes/spaces)
	)
	[ -f "$target/$DISTDIR/${id}.zip" ] && echo "    🗜  ZIP updated in $target/$DISTDIR/${id}.zip"
} # USAGE: zipper "$script_id" "$TARGET_DIR"

# 0. INTENT SELECTION
echo -e "--- 🛈  ${T_C}2;4m${INFO[NAME]} v${INFO[VERSION]} by ${INFO[CREATOR]}${T_N} ---"
echo -ne "--- ？ Publish to ${FORGE[BASE]}/${FORGE[USER]}/$CORE… when applies? (${T_S}Y${T_N}es/${T_S}N${T_N}o/${T_S}C${T_N}ancel): "; read -n 1 confirm;
case "$confirm" in
	y|Y) PUBLISH=true; echo -e "\n--- 🎯 ${T_B}GOAL:${T_N} Build & ${T_S}Publish${T_N} ${T_D}(💡 'Ctrl+C' to abort)${T_N}"; sleep 1 ;;
	c|C) echo -e "\n--- 🛑 CANCELLED: Exiting... "; sleep 0.5; exit 0 ;;
	*) PUBLISH=false; echo -e "\n--- 🎯 ${T_B}GOAL:${T_N} Build & Kept Local" ;;
esac

# 1. MIRROR RESET (Surgical to avoid deleting what we want to keep)
mkdir -p "$CORE_DEST"
for item in "${INCLUDE[@]}"; do
	target_item="$CORE_DEST/$(basename "$item")" # Delete item (file or folder) in destination if it exists. We use basename to refer to the name at the root of $CORE_DEST
	[ -e "$target_item" ] && rm -rf "$target_item"
	[ -e "$item" ] && cp -r "$item" "$CORE_DEST/"
done

# 2. PROCESSING (Fixed new ID based "Sacred Logic")
echo -e "--- ✨ Distributing From Cleaned Mirror: $CORE_DEST"
PACKS_TEMP=$(find "$CORE_DEST" -type f -name "*.lua" -exec grep -l "${VARS[DEP]}" {} + | xargs -I {} basename {} .lua | grep -v "^${CORE}$" | sort -u) # Generate the "Sacred ID List" looking for ScriptDep Key in *.lua
PACKS="$PACKS_TEMP $CORE" # The final list (first the packs, and lastly, the Core)
MONO_MSG=$(git log -1 --pretty=%B | tr -d '\r' | head -n 1)
MONO_HASH=$(git rev-parse --short HEAD)

for script_id in $PACKS; do
	# --- PATH CONFIGURATION & MOVEMENT
	if [[ "$script_id" == "$CORE" ]]; then
		TARGET_DIR="$CORE_DEST"
		echo -e "📦 Finalizing Core: ${T_U}$script_id${T_N}"
	else
		TARGET_DIR="../$script_id"
		echo -e "📦 Processing pack: ${T_U}$script_id${T_N}"
		mkdir -p "$TARGET_DIR"

		# --- 🔽 2.1 (B) MOVE NORMAL PACKS COMPONENT FILES: Find anything starting with the ID (scripts, icons...) excluding the ScriptResources folder to handle it separately
		find "$CORE_DEST" -name "${script_id}*" -not -path "*/ScriptResources/*" -type f | while read -r file; do
			rel_path=$(dirname "${file#$CORE_DEST/}")
			mkdir -p "$TARGET_DIR/$rel_path"
			mv "$file" "$TARGET_DIR/$rel_path/"
		done
		# --- ⏬ 2.2 (B) MOVE NORMAL PACKS RESOURCES
		if [ -d "$CORE_DEST/ScriptResources/$script_id" ]; then
			mkdir -p "$TARGET_DIR/ScriptResources"
			rm -rf "$TARGET_DIR/ScriptResources/$script_id"
			mv "$CORE_DEST/ScriptResources/$script_id" "$TARGET_DIR/ScriptResources/"
		fi
	fi

	# --- 🔍 2.3 INJECT DEPENDENCIES (The "Smart Search" Logic)
	while read -r main_file; do # We look for ALL namesake script files in TARGET_DIR
		header=$(head -n 25 "$main_file" | tr -d '\r') # We check the header to see if it's the one that contains the info
		echo "$header" | grep -q "${VARS[DEP]}" || continue # Guard clause: if ScriptDep variable not found, skip to next file...
		
		deps=$(echo "$header" | grep "${VARS[DEP]}" | sed -e "${VAREXS[A]}") # If we get here, we have found the "parent file" (the ID with info)
		for dep in $deps; do
			target_dep=$(echo "$dep" | tr -d '{}," ' | tr '\\' '/') # Complete removal of unwanted characters
			if [[ -n "$target_dep" && "$target_dep" != "/" ]]; then # We verify that it is not an empty string or an orphaned bar
				if [ -f "./$target_dep" ]; then
					mkdir -p "$TARGET_DIR/$(dirname "$target_dep")"
					cp "./$target_dep" "$TARGET_DIR/$target_dep"
					echo "    ✅ Dependency injected: $target_dep"
				else
					echo -e "    ❎ ${T_R}Missing dependency:${T_N} ./$target_dep"; ((++REPORT[ISS])) # Just in case there in the path or a renamed a dependency
				fi
			fi
		done
		break 
	done < <(find "$TARGET_DIR" -name "${script_id}.lua" -type f)

	# --- 📄 2.4 DOCS PROMOTION & FALLBACKS
	LOCAL_RSC="$TARGET_DIR/ScriptResources/$script_id" # We look at the destination because we've already moved it there
	if [ -d "$LOCAL_RSC" ]; then
		if [ -f "$LOCAL_RSC/README.md" ]; then
			cp "$LOCAL_RSC/README.md" "$TARGET_DIR/README.md"
			if [ "$STRIP_YAML" = true ] && head -n 1 "$TARGET_DIR/README.md" 2>/dev/null | grep -q "^---$"; then # Strip front matter (YAML) & leadings
				perl -0777 -pi -e 's/\A---\r?\n.*?---\r?\n\s*//s' "$TARGET_DIR/README.md"
			fi
		fi
		[ -d "$LOCAL_RSC/docs" ] && rm -rf "$TARGET_DIR/docs" && cp -r "$LOCAL_RSC/docs" "$TARGET_DIR/"
		[ -f "$LOCAL_RSC/LICENSE" ] && cp "$LOCAL_RSC/LICENSE" "$TARGET_DIR/LICENSE"
	fi
	if [ ! -f "$TARGET_DIR/README.md" ]; then # Fallback in case there's no README after the promotion
		echo "# $script_id" > "$TARGET_DIR/README.md"
		echo -e "\nPart of the Lost Scripts collection." >> "$TARGET_DIR/README.md"
	fi
	[ ! -f "$TARGET_DIR/LICENSE" ] && [ -f "$CORE_DEST/LICENSE" ] && cp "$CORE_DEST/LICENSE" "$TARGET_DIR/" || true # We ensure that there is a LICENSE

	# --- 🧹 2.5. FINALIZING + CLEANUP: Purge orphaned files in target (Scan the standard Monorepo folders at the destination and if the file doesn't exist in the Monorepo, delete it)
	for folder in "${SYNC[@]}"; do
		if [ -d "$TARGET_DIR/$folder" ]; then
			find "$TARGET_DIR/$folder" -type f -not -path "*/_*" | while read -r target_file; do # Note: `-not -path "*/_*"` protects any file inside folders starting with _ (anywhere)
				rel_file="${target_file#$TARGET_DIR/}"
				if [ ! -f "./$rel_file" ]; then
					rm "$target_file"
				fi
			done
		fi
	done
	#echo -e "📦 Finalizing + Cleaning Package: $TARGET_DIR"
	find "$TARGET_DIR" -type d -empty -not -path "*/.git*" -delete 2>/dev/null || true

	# --- 🚀 2.6. GIT SYNC & CATALOG DATA
	if [ -d "$TARGET_DIR/.git" ]; then
		cd "$TARGET_DIR" || exit

		# 📶 A. REMOTE CHECK (Essential to know if the script is "catalogable")
		HAS_REMOTE=false
		if git remote | grep -q "origin"; then
			HAS_REMOTE=true
		elif [ "$PUBLISH" = true ]; then # We only try to add remote if we want to publish.
			REMOTE_URL="${FORGE[PREF]}:${FORGE[USER]}/${script_id}.git"
			echo -e "    ⚠️  ${T_Y}Warning:${T_N} No remote 'origin' detected..."
			read -n 1 -p "    🔗 Add '$REMOTE_URL' and push? (y/n): " answer < /dev/tty; echo ""
			if [[ "$answer" =~ ^[yY]$ ]]; then
				if git remote add origin "$REMOTE_URL"; then
					echo "    ✅ Remote added."; HAS_REMOTE=true
				else
					echo -e "    ❎ ${T_R}ERROR:${T_N} Could not add remote."; ((++REPORT[ISS]))
				fi
			fi
		fi

		# 🗳️ B. DATA COLLECTION & SYNC (As long as there is a remote!)
		if [ "$HAS_REMOTE" = true ]; then
			# B1. COLLECTION (Whenever there is a remote, publishing or not)
			v_name=$(echo "$script_id" | sed 's/ls_//g; s/_/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
			v_ver=$(echo "$header" | grep "${VARS[VER]}" | sed -n "${VAREXS[S]}") || true
			v_bld=$(echo "$header" | grep "${VARS[BLD]}" | sed -n "${VAREXS[S]}") || true
			v_dsc=$(echo "$header" | grep "${VARS[DSC]}" | sed -n "${VAREXS[S]}") || true
			v_tar=$(echo "$header" | grep "${VARS[TAR]}" | sed -n "${VAREXS[S]}") || true
			[[ -z "$v_dsc" ]] && v_dsc="Lost Script $v_name for Moho®."
			[[ -z "$v_tar" ]] && v_tar="N/D"
			git tag | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+' && \
			zip_url="https://${FORGE[BASE]}/${FORGE[USER]}/$script_id/releases/latest/download/${script_id}.zip" || zip_url="https://${FORGE[BASE]}/${FORGE[USER]}/$script_id/archive/refs/heads/main.zip"
			echo "$script_id|$v_name|$v_ver|$v_bld|$v_dsc|$v_tar|$zip_url" >> "$CATALOG_DATA" # Records are always written, whether it's DRY RUN or not

			# B2. SYNC LOGIC (Only if PUBLISH is true)
			if [ "$PUBLISH" = true ]; then
				echo "    🌐 [Git] SYNCING: $script_id"
				git add .
				
				# B2a. Check if there are changes in the stage (index)
				HAS_CHANGES=false; ! git diff --cached --quiet && HAS_CHANGES=true

				# B2b. Check if the repo is new (it doesn't have an initial commit on the remote)
				IS_NEW=false; ! git rev-parse @{u} >/dev/null 2>&1 && IS_NEW=true

				if [ "$HAS_CHANGES" = true ] || [ "$IS_NEW" = true ]; then
					if [ "$IS_NEW" = true ] && [ "$HAS_CHANGES" = false ]; then # Decide the message: "Initial upload" if new and without stage changes, or "DNA-Sync" from the monorepo if there are changes
						MSG="Initial upload"
					else
						MSG="$MONO_MSG (@$MONO_HASH)"
					fi
					if [ "$HAS_CHANGES" = true ]; then # Commit ONLY if there is something to
						git commit -m "$MSG" >/dev/null 2>&1
						echo -e "    ⬆️  [Git] COMMIT: $MSG"
					fi
					if git push -u origin main >/dev/null 2>&1; then # Attempt the push (whether there is new commit or is a new empty repo)
						echo "    🚀 [Git] SUCCESS: Done!"
					else
						echo -e "    ❎ [Git] ${T_R}ERROR:${T_N} Push failed!"
						[ "$HAS_CHANGES" = true ] && git reset --soft HEAD~1 >/dev/null 2>&1 # Only reset if we end up creating a local commit
						((++REPORT[ISS])) 
					fi
				else
					echo "    🧼 [Git] CLEAN: Up to date."
				fi
			fi
			((++REPORT[PUB]))
		fi
		cd - > /dev/null
	else
		if [ "$PUBLISH" = true ]; then # Only log that it's local-only if the user intended to post
			echo "    ℹ️  $script_id is local-only (No .git folder)."
		fi
		((++REPORT[LOC]))
	fi

	# --- 🎁 2.7. SCRIPT ZIP GENERATION (Optional & Local)
	zipper "$script_id" "$TARGET_DIR"
	((++REPORT[TOT]))
done

# 4. GENERATING CATALOG
echo "--- 📝 Updating Monorepo's Catalog ---"
OUTPUT_FILE="./README.md"
TEMP_TABLE=$(mktemp)
CAT_START='<!-- CATALOG_START -->'
CAT_END='<!-- CATALOG_END -->'
URL_BASE="https://${FORGE[BASE]}/${FORGE[USER]}"
URL_RAW="https://${FORGE[BRAW]}/${FORGE[USER]}"
URL_RAW_CORE="${URL_RAW}/${CORE}/main/ScriptResources/${CORE}"

# 4a. Table Header (Remote icons so they're always visible)
cat <<EOF > "$TEMP_TABLE"

| Icon | &nbsp;&nbsp;Name&nbsp;&nbsp; | Description | <span title="Direct Download Links"> 📦 </span> |
| :--: | ---------------------------- | ----------- | :---------------------------------------------: |
EOF

# 4b. Reorder and Process Collected Data
if [ -s "$CATALOG_DATA" ]; then
	LINE=$(grep "^${CORE}|" "$CATALOG_DATA")
	LINES=$(grep -v "^${CORE}|" "$CATALOG_DATA" | sort -t'|' -k2)
	{ echo "$LINE"; echo "$LINES"; } | while IFS="|" read -r id name ver bld dsc tar url; do
		[[ -z "$id" ]] && continue
		PACK_LNK="${URL_BASE}/${id}/"
		
		# --- 🖼️ ICON CASCADING LOGIC (webp > png > fallback)
		ICON_URL=""
		for loc in "Tool" "Menu" "ScriptResources/${id}"; do #  Search in main folders (Tool/Menu) then Resources
			for ext in "webp" "png"; do
				if [ -f "../${id}/${loc}/${id}@2x.${ext}" ]; then
					ICON_URL="${URL_RAW}/${id}/main/${loc}/${id}@2x.${ext}"
					break 2
				fi
			done
		done
		[[ -z "$ICON_URL" ]] && ICON_URL="${URL_RAW_CORE}/ls_fallback@2x.webp"

		# --- ✨ DISPLAY CUSTOMIZATION
		if [[ "$id" == "$CORE" ]]; then
			DISPLAY_NAME="[***LS&nbsp;<sup>Core</sup>***](${PACK_LNK} 'Go to \"$CORE\" repo...') "
			DISPLAY_DESC="***<sup>Essential shared/common resources, utils, and core modules required by the [Lost Scripts™](https://lost-scripts.github.io/ \"Go to Lost Scripts™ site...\") project for [MOHO](https://moho.lostmarble.com/ \"Go to Moho® homepage...\")<sup> Pro</sup> Animation Software.</sup>***"
		else
			DISPLAY_NAME="[<sup>**$name**</sup>](${PACK_LNK} 'Go to \"$id\" repo...')<br><sub><sup title='Build: $bld'>v$ver</sup></sub>"
			DISPLAY_DESC="<sup>$dsc</sup><br><sub><sup>𝓲 For Moho $tar</sup></sub>"
		fi
		echo "| [<img src='${ICON_URL}' width='48'>](${PACK_LNK} 'Go to \"$id\" repo...') | $DISPLAY_NAME | $DISPLAY_DESC | [ &nbsp;⏬&nbsp; ]($url 'Download: ${id}.zip') |" >> "$TEMP_TABLE"
	done
	echo -e "\n<p align='right'><sub>𝓲 <em>Generated by <strong>${INFO[NAME]}</strong><sup> v${INFO[VERSION]}</sup> @ <code>$(date +'%Y%m%d')</code></em></sub></p>" >> "$TEMP_TABLE"
fi

# 4c. Surgical Injection (Shielded Version)
if grep -q "$CAT_START" "$OUTPUT_FILE" && grep -q "$CAT_END" "$OUTPUT_FILE"; then # Both markers are present
	sed -i "\|$CAT_START|,\|$CAT_END|{ \|$CAT_START|b; \|$CAT_END|b; d; }" "$OUTPUT_FILE" # First, we delete ONLY what is strictly BETWEEN the markers
	sed -i "\|$CAT_START|r $TEMP_TABLE" "$OUTPUT_FILE" # We insert the content immediately after the start marker
	echo "--- ✅ Catalog Injected Between Markers ---"
else
	echo -e "--- ⚠️  ${T_R} Warning:${T_N} Markers missing in README (appending at end to prevent data loss)"; ((++REPORT[ISS]))  # Nothing gets deleted, just added at the end
	{
		echo -e "\n$CAT_START"; cat "$TEMP_TABLE"; echo -e "$CAT_END\n"
	} >> "$OUTPUT_FILE"
fi

# 4d. Final Cleanup
rm -f "$TEMP_TABLE" "$CATALOG_DATA"

# 5. ENDING! RESTART/SHELL/EXIT?
echo -e "--- 🏁 ${T_B}DONE"'!'"${T_N} (In: $(printf '%01d:%02d' $((SECONDS/60)) $((SECONDS%60))) | Total: ${REPORT[TOT]} | Local: ${REPORT[LOC]} | Public: ${REPORT[PUB]} | $([[ ${REPORT[ISS]} -gt 0 ]] && echo -ne "${T_R}" || echo -ne "${T_N}")Issues: ${REPORT[ISS]}${T_N})"
echo -ne "--- ？ ${T_S}R${T_N}estart? (${T_S}Y${T_N}es/${T_S}S${T_N}hell/${T_S}Any${T_N} to exit): "; read -n 1 action; echo ""
if [[ "$action" =~ ^[yYrR]$ ]]; then
	echo -e "--- 🔁 Restarting... \n"; sleep 0.5; exec bash "$0"
elif [[ "$action" =~ ^[sS]$ ]]; then
	echo -e "--- 💻 Entering Shell... ${T_D}(💡 Type 'exit' to return to Builder)${T_N}"; bash --login -i; exec bash "$0"
else
	echo -e "--- ❎ Exiting... "; sleep 0.5; exit 0
fi