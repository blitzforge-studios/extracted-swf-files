#!/bin/bash

# Script to organize mob body parts and create JSON configuration
# Usage: ./organize_mob_parts.sh <source_directory> <mob_name>
# Example: ./organize_mob_parts.sh Needs_Attention/AbominationSpider Abominent_Spider
#
# Special handling for "_Animation" directory:
# - Files in the "_Animation" directory are copied with their original filenames preserved
# - These files are included in the JSON configuration under the "_Animation" section

# Check if required arguments are provided
if [ $# -lt 2 ]; then
  echo "Usage: $0 <source_directory> <mob_name>"
  echo "Example: $0 Needs_Attention/AbominationSpider Abominent_Spider"
  exit 1
fi

SOURCE_DIR=$1
MOB_NAME=$2
TARGET_DIR="Sprite/Body_Parts/$MOB_NAME"
JSON_DIR="Sprite/Body_Parts/JSON"
JSON_FILE="$JSON_DIR/body_$(echo $MOB_NAME | tr '[:upper:]' '[:lower:]').json"

# Create target directories
mkdir -p "$TARGET_DIR"
mkdir -p "$JSON_DIR"

echo "Creating directories for $MOB_NAME..."

# Find all unique part types (directories) in the source
PART_TYPES=$(find "$SOURCE_DIR" -type d -depth 1 | grep -v "_Animation" | sed 's/.*\///' | sort)

# Create part type directories
for part in $PART_TYPES; do
  # Skip directories that start with "DefineSprite"
  if [[ "$part" == DefineSprite* ]]; then
    continue
  fi

  mkdir -p "$TARGET_DIR/$part"
  echo "Created directory: $TARGET_DIR/$part"
done

# Find all variants for each part type
echo "Identifying variants and copying files..."

# Initialize JSON structure
JSON_CONTENT="{
  \"metadata\": {
    \"version\": \"1.0\",
    \"created\": \"$(date +%Y-%m-%d)\",
    \"description\": \"$MOB_NAME body configurations for different variants\",
    \"author\": \"BlitzForge Studios\"
  },
  \"variants\": {"

# Process each part type
VARIANTS=()
PART_TYPES_ARRAY=()

# First pass: identify all variants
for part_dir in "$SOURCE_DIR"/*; do
  part=$(basename "$part_dir")

  # Skip directories that start with "DefineSprite" or "_Animation"
  if [[ "$part" == DefineSprite* ]] || [[ "$part" == _Animation* ]]; then
    continue
  fi

  # Extract variant from part name
  if [[ "$part" == *_* ]]; then
    variant=$(echo "$part" | sed 's/.*_//')
    if [[ ! " ${VARIANTS[@]} " =~ " ${variant} " ]]; then
      VARIANTS+=("$variant")
    fi
  else
    if [[ ! " ${VARIANTS[@]} " =~ " Default " ]]; then
      VARIANTS+=("Default")
    fi
  fi

  # Add part to array if not already there
  base_part=$(echo "$part" | sed 's/_.*$//')
  if [[ ! " ${PART_TYPES_ARRAY[@]} " =~ " ${base_part} " ]]; then
    PART_TYPES_ARRAY+=("$base_part")
  fi
done

# Add "Default" variant if not already in the list
if [[ ! " ${VARIANTS[@]} " =~ " Default " ]]; then
  VARIANTS=("Default" "${VARIANTS[@]}")
fi

# Copy files and build JSON
for variant in "${VARIANTS[@]}"; do
  # Start variant section in JSON
  if [ "$variant" == "Default" ]; then
    JSON_CONTENT+="
    \"Default\": {
      \"name\": \"Default\",
      \"description\": \"Default $MOB_NAME body configuration\",
      \"parts\": {"
  else
    JSON_CONTENT+="
    \"$variant\": {
      \"name\": \"$variant\",
      \"description\": \"$variant variant\",
      \"parts\": {"
  fi

  # Process each part type for this variant
  for base_part in "${PART_TYPES_ARRAY[@]}"; do
    # Skip animation sequences (handled separately)
    if [[ "$base_part" == Swoosh* ]] || [[ "$base_part" == TalonPower* ]] || [[ "$base_part" == Web ]]; then
      continue
    fi

    # Determine source and target paths
    if [ "$variant" == "Default" ]; then
      source_file="$SOURCE_DIR/$base_part/$base_part.svg"
      if [ ! -f "$source_file" ]; then
        # Try with variant in filename
        source_file=""
        continue
      fi
      target_file="$TARGET_DIR/$base_part/$variant.svg"
    else
      source_file="$SOURCE_DIR/${base_part}_${variant}/${base_part}_${variant}.svg"
      if [ ! -f "$source_file" ]; then
        # If variant-specific file doesn't exist, use default
        source_file="$SOURCE_DIR/$base_part/$base_part.svg"
        if [ ! -f "$source_file" ]; then
          # No file found for this part/variant
          source_file=""
          continue
        fi
      fi
      target_file="$TARGET_DIR/$base_part/$variant.svg"
    fi

    # Copy the file if source exists
    if [ -n "$source_file" ] && [ -f "$source_file" ]; then
      cp "$source_file" "$target_file"
      echo "Copied: $source_file -> $target_file"

      # Add to JSON
      JSON_CONTENT+="
        \"$base_part\": \"../$MOB_NAME/$base_part/$variant.svg\","
    fi
  done

  # Remove trailing comma if any parts were added
  JSON_CONTENT="${JSON_CONTENT%,}"

  # Close the parts and variant sections
  JSON_CONTENT+="
      }
    },"
done

# Remove trailing comma
JSON_CONTENT="${JSON_CONTENT%,}"

# Close variants section
JSON_CONTENT+="
  },"

# Handle animation sequences
echo "Processing animation sequences..."

# Initialize animations section
JSON_CONTENT+="
  \"animations\": {"

# Process TalonPowerOn and TalonPowerOff if they exist
for anim in TalonPowerOn TalonPowerOff; do
  if [ -d "$SOURCE_DIR/$anim" ]; then
    mkdir -p "$TARGET_DIR/$anim/Default"

    # Check if there are variant-specific animations
    ANIM_VARIANTS=("Default")
    for anim_dir in "$SOURCE_DIR/${anim}_"*; do
      if [ -d "$anim_dir" ]; then
        variant=$(basename "$anim_dir" | sed "s/${anim}_//")
        ANIM_VARIANTS+=("$variant")
        mkdir -p "$TARGET_DIR/$anim/$variant"
      fi
    done

    # Start animation section in JSON
    JSON_CONTENT+="
    \"$anim\": {"

    # Process each variant
    for variant in "${ANIM_VARIANTS[@]}"; do
      if [ "$variant" == "Default" ]; then
        source_dir="$SOURCE_DIR/$anim"
      else
        source_dir="$SOURCE_DIR/${anim}_${variant}"
      fi

      # Start variant section in JSON
      JSON_CONTENT+="
      \"$variant\": ["

      # Copy animation frames
      frame_count=0
      for frame in "$source_dir"/*.svg; do
        if [ -f "$frame" ]; then
          frame_num=$(basename "$frame" | sed "s/${anim}_\?${variant}_\?//;s/\.svg//")
          # Clean up frame number to just be the numeric part
          clean_num=$(echo "$frame_num" | grep -o '[0-9]\+')
          target_frame="$TARGET_DIR/$anim/$variant/Frame_$clean_num.svg"
          mkdir -p "$(dirname "$target_frame")"
          cp "$frame" "$target_frame"
          echo "Copied animation frame: $frame -> $target_frame"

          # Add to JSON
          JSON_CONTENT+="
        \"../$MOB_NAME/$anim/$variant/Frame_$clean_num.svg\","

          ((frame_count++))
        fi
      done

      # Remove trailing comma if frames were added
      if [ $frame_count -gt 0 ]; then
        JSON_CONTENT="${JSON_CONTENT%,}"
      fi

      # Close variant section
      JSON_CONTENT+="
      ],"
    done

    # Remove trailing comma
    JSON_CONTENT="${JSON_CONTENT%,}"

    # Close animation section
    JSON_CONTENT+="
    },"
  fi
done

# Remove trailing comma if any animations were added
JSON_CONTENT="${JSON_CONTENT%,}"

# Close animations section
JSON_CONTENT+="
  },"

# Handle effects (Swoosh, Web, etc.)
echo "Processing effects..."

# Initialize effects section
JSON_CONTENT+="
  \"effects\": {"

# Process Swoosh effects
for effect in Swoosh01 Swoosh02 Swoosh03 Swoosh04 Web; do
  if [ -d "$SOURCE_DIR/$effect" ]; then
    mkdir -p "$TARGET_DIR/$effect"

    # Start effect section in JSON
    JSON_CONTENT+="
    \"$effect\": ["

    # Copy effect frames
    frame_count=0
    for frame in "$SOURCE_DIR/$effect"/*.svg; do
      if [ -f "$frame" ]; then
        frame_num=$(basename "$frame" | sed "s/${effect}_//;s/\.svg//")
        # Clean up frame number to just be the numeric part
        clean_num=$(echo "$frame_num" | grep -o '[0-9]\+')
        target_frame="$TARGET_DIR/$effect/Frame_$clean_num.svg"
        mkdir -p "$(dirname "$target_frame")"
        cp "$frame" "$target_frame"
        echo "Copied effect frame: $frame -> $target_frame"

        # Add to JSON
        JSON_CONTENT+="
      \"../$MOB_NAME/$effect/Frame_$clean_num.svg\","

        ((frame_count++))
      fi
    done

    # Remove trailing comma if frames were added
    if [ $frame_count -gt 0 ]; then
      JSON_CONTENT="${JSON_CONTENT%,}"
    fi

    # Close effect section
    JSON_CONTENT+="
    ],"
  fi
done

# Remove trailing comma if any effects were added
JSON_CONTENT="${JSON_CONTENT%,}"

# Close effects section
JSON_CONTENT+="
  },"

# Handle _Animation directory if it exists
echo "Processing _Animation directory..."

if [ -d "$SOURCE_DIR/_Animation" ]; then
  # Create target directory for animations
  mkdir -p "$TARGET_DIR/_Animation"

  # Initialize animations section in JSON
  JSON_CONTENT+="
  \"_Animation\": {"

  # Find all animation files
  animation_files=("$SOURCE_DIR/_Animation"/*.svg)

  if [ ${#animation_files[@]} -gt 0 ] && [ -f "${animation_files[0]}" ]; then
    # Copy all animation files with their original names
    for anim_file in "$SOURCE_DIR/_Animation"/*.svg; do
      if [ -f "$anim_file" ]; then
        # Get the original filename without path
        orig_filename=$(basename "$anim_file")

        # Copy the file with its original name
        cp "$anim_file" "$TARGET_DIR/_Animation/$orig_filename"
        echo "Copied animation file (preserving name): $anim_file -> $TARGET_DIR/_Animation/$orig_filename"
      fi
    done

    # Add animation files to JSON with their original names
    JSON_CONTENT+="
    \"files\": ["

    # Add each animation file to JSON
    first_file=true
    for anim_file in "$SOURCE_DIR/_Animation"/*.svg; do
      if [ -f "$anim_file" ]; then
        orig_filename=$(basename "$anim_file")

        # Add comma before all but the first item
        if [ "$first_file" = true ]; then
          first_file=false
        else
          JSON_CONTENT+=","
        fi

        # Add file path to JSON
        JSON_CONTENT+="
      \"../$MOB_NAME/_Animation/$orig_filename\""
      fi
    done

    # Close files array
    JSON_CONTENT+="
    ]"
  fi

  # Close _Animation section
  JSON_CONTENT+="
  }"
fi

# Close the JSON structure
JSON_CONTENT+="
}"

# Write JSON to file
echo "$JSON_CONTENT" > "$JSON_FILE"
echo "Created JSON configuration: $JSON_FILE"

echo "Organization complete for $MOB_NAME!"
