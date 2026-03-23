#!/bin/bash
set -euo pipefail; trap 'debugger $LINENO "$BASH_COMMAND"' ERR # Debug Mode (Comment/Uncomment as needed)

# ⚙ CONFIGURATION
declare -Ar INFO=( [NAME]="Lost Builder" [VERSION]="1.4.2" [CREATOR]="Rai López" [DESC]="Lost Project's Development Helper" )
declare -ar INCLUDE=( "Embed" "Menu" "Modules" "ScriptResources" "Smart" "Tool" "Utility" "docs" "README.md" "LICENSE" )
declare -Ar VARS=( [DEP]="ScriptDep" [VER]="ScriptVersion" [BLD]="ScriptBuild" [DSC]="ScriptDesc" [TAR]="ScriptTarget" )
declare -Ar VAREXS=( [S]='s/.*=[[:space:]]*["'\'']\([^"'\'']*\)["'\''].*/\1/p' [A]='s/[^=]*=[[:space:]]*//; s/[^"'\'']*["'\'']\([^"'\'']*\)["'\'']/\1 /g' )
declare -Ar FORGE=( [BASE]="github.com" [BRAW]="raw.githubusercontent.com" [USER]="RaiLopez" [PREF]="git@github-railopez" ) # URL, contentUrl, username, remotePrefix (SSH Alias)
declare -r  CORE="ls"
declare -r  CORE_DEST="../$CORE"
declare -r  STRIP_YAML=true
declare -r  DISTDIR="_dist" # Specifying a directory implies creating ZIPs (assuming zip.exe & bzip2.dll exist in %ProgramFiles%\Git\usr\bin)
declare -ar ZIPIGNORE=( "README.md" "LICENSE" "docs" "docs/*" "*/docs/*" "*.zip" )
declare --  PUBLISH=false # Requires the script folder has a repo and 'origin' remote
declare --  CATALOG_DATA=$(mktemp)
declare -A  REPORT=( [LOC]=0 [PUB]=0 [ISS]=0 ) # TODO!
declare --  T_R='\e[1;31m'; T_G='\e[1;32m'; T_Y='\e[1;33m'; T_B='\e[1;34m'; T_D='\e[2m'; T_S='\e[1m' ; T_U='\e[4m'; T_C='\e['; _T='\e[0m' # Text: Red, Green, Yellow, Blue, Dim; Strong, UL; Custom; Reset (_T)

# 🛠️ HELPER FUNCTIONS
debugger(){ # Debug Mode helper for catching errors before closing
	echo -e "\n❌ ERROR at line $1\n   💻 $2"; read -n1 -p "🏁 Press any key to exit..."; exit 1
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
echo -e "--- 🛈  \e[2;4m${INFO[NAME]} v${INFO[VERSION]} by ${INFO[CREATOR]}\e[0m ---"
read -n 1 -p "--- ？ Publish to ${FORGE[BASE]}/${FORGE[USER]}/$CORE… when applies? ([Y]es/[N]o/[C]ancel): " confirm
case "$confirm" in
	y|Y) PUBLISH=true; echo -e "\n--- 🎯 GOAL: Build & ${T_S}Publish${_T} ${T_D}(💡 'Ctrl+C' to abort)${_T}"; sleep 1 ;;
	c|C) echo -e "\n--- 🛑 CANCELLED: Exiting... "; sleep 0.5; exit 0 ;;
	*) PUBLISH=false; echo -e "\n--- 🎯 GOAL: Build & Kept Local" ;;
esac

# 1. MIRROR RESET
mkdir -p "$CORE_DEST"
rm -rf "$CORE_DEST"/* 2>/dev/null

for item in "${INCLUDE[@]}"; do
	[ -e "$item" ] && cp -r "$item" "$CORE_DEST/"
done

# 2. PROCESSING (Fixed new UUID based "Sacred Logic")
echo -e "--- ✨ Distributing From Cleaned Mirror: $CORE_DEST"
PACKS=$(find "$CORE_DEST" -type f -name "*.lua" -exec grep -l "${VARS[DEP]}" {} + | xargs -I {} basename {} .lua | sort -u) # Generate the "Sacred List" of pack IDs (we look for the Dependency Key in all .lua files)
MONO_MSG=$(git log -1 --pretty=%B | tr -d '\r' | head -n 1)
MONO_HASH=$(git rev-parse --short HEAD)

for script_id in $PACKS; do
	[[ "$script_id" == "$CORE" ]] && continue # Skip the core itself to avoid self-processing
	
	echo -e "📦 Processing pack: ${T_U}$script_id${_T}"
	TARGET_DIR="../$script_id"
	mkdir -p "$TARGET_DIR"

	# --- 🔽 2.1. MOVE COMPONENT FILES: Find anything starting with the ID (scripts, icons, tool lists) excluding the ScriptResources folder to handle it separately
	find "$CORE_DEST" -name "${script_id}*" -not -path "*/ScriptResources/*" -type f | while read -r file; do
		rel_path=$(dirname "${file#$CORE_DEST/}")
		mkdir -p "$TARGET_DIR/$rel_path"
		mv "$file" "$TARGET_DIR/$rel_path/"
	done

	# --- ⏬ 2.2 MOVE RESOURCES
	if [ -d "$CORE_DEST/ScriptResources/$script_id" ]; then
		mkdir -p "$TARGET_DIR/ScriptResources"
		rm -rf "$TARGET_DIR/ScriptResources/$script_id"
		mv "$CORE_DEST/ScriptResources/$script_id" "$TARGET_DIR/ScriptResources/"
	fi

	# --- 🔍 2.3 INJECT DEPENDENCIES (The "Smart Search" Logic)
	while read -r main_file; do # We look for ALL namesake script files in TARGET_DIR
		header=$(head -n 25 "$main_file" | tr -d '\r') # We check the header to see if it's the one that contains the info
		echo "$header" | grep -q "${VARS[DEP]}" || continue # Guard clause: if ScriptDep variable not found, skip to next file...
		
		deps=$(echo "$header" | grep "${VARS[DEP]}" | sed -e "${VAREXS[A]}") # If we get here, we have found the "parent file" (the UUID with info)
		for dep in $deps; do
			target_dep=$(echo "$dep" | tr -d '{}," ' | tr '\\' '/') # Complete removal of unwanted characters
			if [[ -n "$target_dep" && "$target_dep" != "/" ]]; then # We verify that it is not an empty string or an orphaned bar
				if [ -f "./$target_dep" ]; then
					mkdir -p "$TARGET_DIR/$(dirname "$target_dep")"
					cp "./$target_dep" "$TARGET_DIR/$target_dep"
					echo "    ✅ Dependency injected: $target_dep"
				else
					echo -e "    ❎ ${T_R}Missing dependency:${_T} ./$target_dep" # Just in case there in the path or a renamed a dependency
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

	# --- 🧹 2.5. CLEANUP: Purge orphaned files in target
	for folder in "Modules" "Tool" "Utility" "ScriptResources" "Menu" "Embed" "Smart"; do
		if [ -d "$TARGET_DIR/$folder" ]; then
			find "$TARGET_DIR/$folder" -type f | while read -r target_file; do
				rel_file="${target_file#$TARGET_DIR/}"
				if [ ! -f "./$rel_file" ]; then
					rm "$target_file"
				fi
			done
		fi
	done
	find "$TARGET_DIR" -type d -empty -not -path "*/.git*" -delete 2>/dev/null || true

	# --- 🚀 2.6. GIT SYNC & CATALOG DATA
	if [ -d "$TARGET_DIR/.git" ]; then
		cd "$TARGET_DIR" || exit
		# 📶 A. REMOTE CHECK (Necessary to know if the script is "catalogeable")
		HAS_REMOTE=false
		if git remote | grep -q "origin"; then
			HAS_REMOTE=true
		elif [ "$PUBLISH" = true ]; then # If publish was choesn but there is no remote, try to add one
			REMOTE_URL="${FORGE[PREF]}:${FORGE[USER]}/${script_id}.git"
			echo -e "    ⚠️  ${T_Y}Warning:${_T} No remote 'origin' detected..."
			read -n 1 -p "    🔗 Add '$REMOTE_URL' and push? (y/n): " answer < /dev/tty; echo ""
			if [[ "$answer" =~ ^[yY]$ ]]; then
				git remote add origin "$REMOTE_URL" && echo "    ✅ Remote added."
				HAS_REMOTE=true
			fi
		fi
		# 🗳 B. DATA COLLECTION & SYNC
		if [ "$HAS_REMOTE" = true ]; then
			# B1. COLLECTION (Whenever there is a remote, publishing or not)
			v_name=$(echo "$script_id" | sed 's/ls_//g; s/_/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
			v_ver=$(echo "$header" | grep "${VARS[VER]}" | sed -n "${VAREXS[S]}") || true
			v_bld=$(echo "$header" | grep "${VARS[BLD]}" | sed -n "${VAREXS[S]}") || true
			v_dsc=$(echo "$header" | grep "${VARS[DSC]}" | sed -n "${VAREXS[S]}") || true
			v_tar=$(echo "$header" | grep "${VARS[TAR]}" | sed -n "${VAREXS[S]}") || true
			[[ -z "$v_dsc" ]] && v_dsc="Lost Script $v_name for Moho®."
			[[ -z "$v_tar" ]] && v_tar="N/D"
			git tag | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+' && zip_url="https://${FORGE[BASE]}/${FORGE[USER]}/$script_id/releases/latest/download/${script_id}.zip" || zip_url="https://${FORGE[BASE]}/${FORGE[USER]}/$script_id/archive/refs/heads/main.zip"
			echo "$script_id|$v_name|$v_ver|$v_bld|$v_dsc|$v_tar|$zip_url" >> "$CATALOG_DATA" # Records addition (DRY RUN enabled: results will show locally)
			# B2. SYNC LOGIC (Only if global OK was given at the beginning)
			if [ "$PUBLISH" = true ]; then
				echo "    🌐 Syncing Git: $script_id"
				git add .
				if ! git diff --cached --quiet || ! git rev-parse @{u} >/dev/null 2>&1; then
					git diff --cached --quiet && MSG="Initial upload" || MSG="$MONO_MSG [ref:$MONO_HASH]"
					git commit -m "$MSG" >/dev/null 2>&1 # Committing silently
					echo -e "    ⬆️  ${T_G}Commit:${_T} $MSG"
					
					if git push -u origin main >/dev/null 2>&1; then
						echo "    🚀 [Git] SUCCESS: Done!"
					else
						echo -e "    ❎ [Git] ${T_R}ERROR:${_T} Push failed!"
						git rev-parse HEAD >/dev/null 2>&1 && git reset --soft HEAD~1 >/dev/null 2>&1 || true
					fi
				else
					echo "    🧼 [Git] CLEAN: Up to date."
				fi
			fi
		else
			echo -e "    ⏭️  [Git] SKIP: $script_id has no remote 'origin'. Skipping catalog."
		fi
		cd - > /dev/null
	else
		echo "    ℹ️  $script_id is local-only (No .git folder)."
	fi

	# --- 🎁 2.7. SCRIPT ZIP GENERATION (Optional & Local)
	zipper "$script_id" "$TARGET_DIR"
done

# 3. FINALIZING CORE & CLEANUP
echo -e "📦 Finalizing Core: ${T_U}$CORE${_T}"
REC_C="./ScriptResources/$CORE"

if [ -d "$REC_C" ]; then # We only proceed if the Core does NOT already have the files (taking INCLUDE into account)
	[ ! -f "$CORE_DEST/README.md" ] && [ -f "$REC_C/README.md" ] && cp "$REC_C/README.md" "$CORE_DEST/" # If there is no README.md in the Core, we try to include the specific one
	[ ! -d "$CORE_DEST/docs" ] && [ -d "$REC_C/docs" ] && cp -r "$REC_C/docs" "$CORE_DEST/" # If there is no 'docs' folder in the Core directory, we include the specific one
	[ ! -f "$CORE_DEST/LICENSE" ] && [ -f "$REC_C/LICENSE" ] && cp "$REC_C/LICENSE" "$CORE_DEST/" # If there is no LICENSE file in the Core, we include the specific one
fi
if [ ! -f "$CORE_DEST/README.md" ]; then # Final fallback (if after all there is still nothing...)
	echo "# $CORE" > "$CORE_DEST/README.md"
	echo -e "\nPart of the Lost Scripts collection." >> "$CORE_DEST/README.md"
fi
[ ! -f "$CORE_DEST/LICENSE" ] && [ -f "./LICENSE" ] && cp "./LICENSE" "$CORE_DEST/"
find "$CORE_DEST" -type d -empty -delete 2>/dev/null || true

# 3a. CORE ZIP GENERATION (Optional & Local)
zipper "$CORE" "$CORE_DEST" # 🎁 CORE ZIP GENERATION (Optional & Local)

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
| :--: | -- | -- | :--: |
| [<img src="${URL_RAW_CORE}/${CORE}@2x.png" width="48">](./${CORE}/ 'Go to \"$CORE\" (Core) repo...') | [***LS&nbsp;<sup>Core</sup>***](./${CORE}/ 'Go to \"$CORE\" (Core) repo...') | ***<sup>Essential shared/common resources, utils, and core modules required by the [Lost Scripts™](https://lost-scripts.github.io/ "Go to Lost Scripts™ site...") project for MOHO<sup> Pro</sup> Animation Software.&nbsp;</sup>*** | [ &nbsp;⏬&nbsp; ](${URL_BASE}/${CORE}/archive/refs/heads/main.zip 'Download: ${CORE}.zip') |
EOF

# 4b. Append Collected Data (Dynamic rows)
if [ -s "$CATALOG_DATA" ]; then
	while IFS="|" read -r id name ver bld dsc tar url; do
		PACK_RAW="${URL_RAW}/${id}/main/ScriptResources/${id}"
		PACK_LNK="${URL_BASE}/${id}/"
		FALLBACK="${URL_RAW_CORE}/ls_fallback@2x.png"
		echo "| [<img src='${PACK_RAW}/${id}@2x.png' width='48' onerror=\"this.src='${FALLBACK}'\">](${PACK_LNK} 'Go to \"$id\" repo...') | [<sup>**$name**</sup>](${PACK_LNK} 'Go to \"$id\" repo...')<br><sub><sup title='Build: $bld'>v$ver</sup></sub> | <sup>$dsc</sup><br><sub><sup>🛈 For Moho $tar</sup></sub> | [ &nbsp;⏬&nbsp; ]($url 'Download: ${id}.zip') |" >> "$TEMP_TABLE"
	done < "$CATALOG_DATA"
	echo -e "\n<p align='right'><sub>🛈 <em>Generated by <strong>${INFO[NAME]}</strong><sup> v${INFO[VERSION]}</sup> @ <code>$(date +'%Y%m%d-%H%M')</code></em></sub></p>" >> "$TEMP_TABLE"
fi

# 4c. Surgical Injection (Shielded Version)
if grep -q "$CAT_START" "$OUTPUT_FILE" && grep -q "$CAT_END" "$OUTPUT_FILE"; then # Both markers are present
	sed -i "\|$CAT_START|,\|$CAT_END|{ \|$CAT_START|b; \|$CAT_END|b; d; }" "$OUTPUT_FILE" # First, we delete ONLY what is strictly BETWEEN the markers
	sed -i "\|$CAT_START|r $TEMP_TABLE" "$OUTPUT_FILE" # We insert the content immediately after the start marker
	echo "--- ✅ Catalog Injected Between Markers ---"
else
	echo -e "--- ⚠️  ${T_R} Warning:${_T} Markers missing in README (appending at end to prevent data loss)" # Nothing gets deleted, just added at the end
	{
		echo -e "\n$CAT_START"; cat "$TEMP_TABLE"; echo -e "$CAT_END\n"
	} >> "$OUTPUT_FILE"
fi

# 4d. Final Cleanup
rm -f "$TEMP_TABLE" "$CATALOG_DATA"

# 5. RESTART?
echo -ne "--- 🏁 DONE! \e[1;5mRestart?\e[0m ${T_D}('y' confirms; any other key exits)${_T}: "; read -n 1 action; #read -n 1 -p "--- 🏁 DONE! Restart? Press 'y' to confirm (or any key to exit): " action
if [ "$action" == "y" ] || [ "$action" == "Y" ]; then
	echo -e "\n--- 🔁 Restarting... \n"; sleep 0.5; exec bash "$0"
else
	echo -e "\n--- ❎ Exiting... "; sleep 0.5; exit 0
fi