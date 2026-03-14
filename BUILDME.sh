#!/bin/bash

# ==============================================================================
# BUILDER: RAI LOPEZ (Hybrid Approach)
# ==============================================================================

# CONFIGURACIÓN
CORE="ls"
INCLUDE=( "Embed" "docs" "Menu" "Modules" "ScriptResources" "Smart" "Tool" "Utility" "README.md" "LICENSE" ".github" )
declare -A VARS=( [DEP]="ScriptDep" )

# 1. RESET DEL CORE (El "Nuevo Limbo" en ../ls)
DEST_CORE="../$CORE"
echo "--- 📦 Resetting Core Mirror: $DEST_CORE ---"
rm -rf "$DEST_CORE"
mkdir -p "$DEST_CORE"

# Proyectamos el taller actual al espejo Core
for item in "${INCLUDE[@]}"; do
    [ -e "$item" ] && cp -r "$item" "$DEST_CORE/"
done

# 2. PROCESADO DE PACKS INDIVIDUALES
echo "--- 🔍 Distributing Packs ---"

# Congelamos la lista de candidatos para evitar errores de lectura durante el proceso
mapfile -t CANDIDATES < <(find "$DEST_CORE" -maxdepth 4 -name "ls_*.lua" -type f)

for script_path in "${CANDIDATES[@]}"; do
    [ ! -f "$script_path" ] && continue
    
    header=$(head -n 20 "$script_path" | tr -d '\r')
    
    # Buscamos la firma de dependencia para identificar un Pack
    if echo "$header" | grep -q "${VARS[DEP]} = {"; then
        filename=$(basename "$script_path")
        script_id="${filename%.lua}"
        
        # Saltamos el Core (ya está procesado en el paso 1)
        [ "$script_id" == "$CORE" ] && continue
        
        DESTINO="../$script_id"
        echo "📦 Processing: $script_id"

        # --- A) CREACIÓN / MANTENIMIENTO DEL REPO ---
        if [ ! -d "$DESTINO" ]; then
            echo "    + New script detected! Creating: $DESTINO"
            mkdir -p "$DESTINO"
            # Aquí podrías añadir un 'git init' si quisieras automatizarlo más
        fi

        # --- B) RELLENO (Lógica Sagrada v1.0.1) ---
        rel_path=$(dirname "${script_path#$DEST_CORE/}")
        mkdir -p "$DESTINO/$rel_path"
        
        # Mover Script y archivos hermanos (iconos, etc)
        find "$DEST_CORE/$rel_path" -maxdepth 1 -name "${script_id}*" -exec mv {} "$DESTINO/$rel_path/" \;

        # Mover Recursos específicos
        if [ -d "$DEST_CORE/ScriptResources/$script_id" ]; then
            mkdir -p "$DESTINO/ScriptResources"
            rm -rf "$DESTINO/ScriptResources/$script_id"
            mv "$DEST_CORE/ScriptResources/$script_id" "$DESTINO/ScriptResources/"
        fi

        # Copiar Dependencias, README y LICENSE (sobrescribiendo)
        deps=$(echo "$header" | grep "${VARS[DEP]} =" | sed -n 's/.*{[[:space:]]*\(.*\)[[:space:]]*}.*/\1/p' | tr -d '"' | tr -d "'" | tr ',' ' ')
        for dep in $deps; do
            clean_dep=$(echo "$dep" | tr '\\' '/')
            mkdir -p "$DESTINO/$(dirname "$clean_dep")"
            [ -f "$DEST_CORE/$clean_dep" ] && cp "$DEST_CORE/$clean_dep" "$DESTINO/$clean_dep"
        done
        
        # Copiar el grueso de la raíz que el taller gestiona (LICENSE, README...)
        cp "$DEST_CORE/LICENSE" "$DESTINO/" 2>/dev/null
        cp "$DEST_CORE/README.md" "$DESTINO/" 2>/dev/null
        # Opcional: Si quieres docs en la raíz, se copiaría aquí

        # --- C) 🧹 PURGA DE HUÉRFANOS (Tu "Cortafuegos") ---
        # Limpiamos solo las subcarpetas de Moho para proteger la raíz del script
        for folder in "Modules" "Tool" "Utility" "Menu" "Embed" "Smart" "ScriptResources"; do
            if [ -d "$DESTINO/$folder" ]; then
                find "$DESTINO/$folder" -type f | while read -r target_file; do
                    rel_file="${target_file#$DESTINO/}"
                    # Si no está en el taller, es un rastro del pasado
                    if [ ! -f "./$rel_file" ]; then
                        echo "    - Removing orphan: $rel_file"
                        rm "$target_file"
                    fi
                done
            fi
        done
        
        # Limpieza de carpetas vacías (respetando .git)
        find "$DESTINO" -type d -empty -not -path "*/.git*" -delete 2>/dev/null || true
    fi
done

# 3. LIMPIEZA FINAL DEL CORE
find "$DEST_CORE" -type d -empty -delete 2>/dev/null || true

echo "--- ✅ Build Complete! ---"