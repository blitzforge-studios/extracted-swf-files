import os
import re
import shutil
from pathlib import Path

def extract_proper_name(folder_name):
    """Extract the proper name from the folder name.
    Example: "DefineSprite_2_a_WaistSide_ThunderGolem" -> "WaistSide_ThunderGolem"
    """
    print(f"  Extracting name from: {folder_name}")

    # Pattern to match: after "a_" and capture everything until the end
    match = re.search(r'a_(.+)$', folder_name)
    if match:
        result = match.group(1)
        print(f"  Found a_ pattern: {result}")
        return result

    # For folders without 'a_' pattern but with underscores, extract the meaningful part
    # Example: "DefineSprite_1234_Torso_EscapedGladiator" -> "Torso_EscapedGladiator"
    match = re.search(r'DefineSprite_(\d+)_(.+)$', folder_name)
    if match:
        result = match.group(2)
        print(f"  Found DefineSprite pattern: {result}")
        return result

    print(f"  No pattern matched, using original: {folder_name}")
    return folder_name  # Fallback to original name if pattern not found

def main():
    # Create output directory
    output_dir = Path("sprites_done")
    output_dir.mkdir(exist_ok=True)

    # Get all directories in the current folder
    directories = [d for d in os.listdir() if os.path.isdir(d) and not d.startswith("sprites_done")]

    print(f"Found {len(directories)} directories to process")

    # Process each directory
    for folder in directories:
        # Extract proper name from folder
        proper_name = extract_proper_name(folder)

        # Get all SVG files in the folder
        svg_files = [f for f in os.listdir(folder) if f.lower().endswith('.svg')]
        num_files = len(svg_files)

        print(f"Processing {folder} -> {proper_name} ({num_files} SVG files)")

        # If multiple SVG files, create a subfolder
        subfolder = None
        if num_files > 1:
            subfolder = output_dir / proper_name
            subfolder.mkdir(exist_ok=True)

        # Process each SVG file
        for i, svg_file in enumerate(sorted(svg_files), 1):
            source_path = Path(folder) / svg_file

            # Determine new filename
            if num_files == 1:
                new_filename = f"{proper_name}.svg"
                dest_path = output_dir / new_filename
            else:
                new_filename = f"{proper_name}_{i:02d}.svg"
                dest_path = subfolder / new_filename

            # Copy the file
            shutil.copy2(source_path, dest_path)
            print(f"  Copied {svg_file} -> {new_filename}")

    print(f"\nAll done! Files have been saved to {output_dir}")

if __name__ == "__main__":
    main()