#!/usr/bin/env python3
import os
import re
import shutil
from pathlib import Path
from collections import defaultdict

def extract_category(filename):
    """
    Extract the category from a filename.
    Examples:
    - "DefineSprite_265__IconArtStoreFront14/1.svg" -> "IconArt"
    - "DefineSprite_539__FrameBendBronze01/1.svg" -> "Frame"
    - "_IconArtStoreFront14.svg" -> "IconArt"
    - "_FrameBendBronze01.svg" -> "Frame"
    - "_DoodadMapArt05.svg" -> "Doodad"
    - "_WindowSkinHeaderTalents.svg" -> "Window"
    - "_ButtonFrameStandard08.svg" -> "Button"
    """
    # Handle directory structure if present
    if '/' in filename:
        filename = filename.split('/')[-1]

    # Extract the base filename without path or extension
    base_filename = os.path.basename(filename)

    # Define patterns to match common categories
    patterns = [
        (r'^_?IconArt', 'IconArt'),
        (r'^_?Frame', 'Frame'),
        (r'^_?Doodad', 'Doodad'),
        (r'^_?Window', 'Window'),
        (r'^_?Button', 'Button')
    ]

    # Try to match the patterns directly in the filename
    for pattern, category in patterns:
        if re.match(pattern, base_filename):
            return category

    # Handle DefineSprite pattern with double underscore
    if '__' in filename:
        # Extract the part after double underscore
        after_double_underscore = filename.split('__', 1)[1]

        # Try to match patterns in the part after double underscore
        for pattern, category in patterns:
            if re.match(pattern, after_double_underscore):
                return category

        # If no specific pattern matches, try to extract a general category
        # by finding the first sequence of letters before a number or special character
        match = re.match(r'([A-Za-z]+)', after_double_underscore)
        if match:
            return match.group(1)

    # If the filename starts with an underscore, try to extract the category after it
    if base_filename.startswith('_'):
        # Remove the leading underscore
        name_without_underscore = base_filename[1:]

        # Try to extract a category from the name without underscore
        match = re.match(r'([A-Za-z]+)', name_without_underscore)
        if match:
            return match.group(1)

    # If all else fails, return the filename without extension
    return os.path.splitext(filename)[0]

def organize_files(directory_path, output_dir=None, file_types=None, dry_run=False, delete_originals=False):
    """
    Organize files in the given directory by grouping them into folders based on their name patterns.

    Args:
        directory_path: Path to the directory containing files to organize
        output_dir: Path to output directory (if None, files are organized in place)
        file_types: List of file extensions to process (e.g., ['.svg', '.png'])
        dry_run: If True, only print what would be done without actually moving files
        delete_originals: If True, delete non-foldered files after organizing
    """
    directory_path = Path(directory_path)

    # If no output directory specified, use the input directory
    if output_dir is None:
        output_dir = directory_path
    else:
        output_dir = Path(output_dir)
        output_dir.mkdir(exist_ok=True)

    # If no file types specified, default to SVG files
    if file_types is None:
        file_types = ['.svg']

    # Get all files in the directory
    files = []
    for item in directory_path.iterdir():
        if item.is_file():
            if not file_types or item.suffix.lower() in file_types:
                files.append(item)

    print(f"Found {len(files)} files to organize")

    # Group files by category
    categories = defaultdict(list)
    for file_path in files:
        filename = file_path.name
        category = extract_category(filename)
        categories[category].append(file_path)

    print(f"Grouped files into {len(categories)} categories")

    # Create folders and move files
    for category, file_paths in categories.items():
        # Create category folder (even for single files)
        category_dir = output_dir / category
        if not dry_run:
            category_dir.mkdir(exist_ok=True)

        print(f"Category '{category}' has {len(file_paths)} files")

        # Move files to category folder
        for file_path in file_paths:
            dest_path = category_dir / file_path.name

            if dry_run:
                print(f"  Would move {file_path} -> {dest_path}")
            else:
                # Skip if source and destination are the same
                if file_path == dest_path:
                    print(f"  Skipping {file_path.name} (same as destination)")
                    continue

                print(f"  Moving {file_path.name} -> {category}/{file_path.name}")
                shutil.copy2(file_path, dest_path)

    print(f"\nAll done! Files have been organized into categories")

    # Delete non-foldered files if requested
    if delete_originals and not dry_run:
        delete_non_foldered_files(directory_path, file_types)

def delete_non_foldered_files(directory_path, file_types=None):
    """
    Delete non-foldered files of specified types from the directory.

    Args:
        directory_path: Path to the directory containing files
        file_types: List of file extensions to process (e.g., ['.svg', '.png'])
    """
    directory_path = Path(directory_path)

    # If no file types specified, default to SVG files
    if file_types is None:
        file_types = ['.svg']

    # Get all files in the root directory (not in subfolders)
    deleted_count = 0
    for item in directory_path.iterdir():
        if item.is_file() and item.suffix.lower() in file_types:
            # Delete the file
            item.unlink()
            deleted_count += 1
            print(f"Deleted: {item.name}")

    print(f"Deleted {deleted_count} non-foldered files")

def main():
    import argparse

    parser = argparse.ArgumentParser(description='Organize files into folders based on name patterns')
    parser.add_argument('directory', nargs='?', default='sprites_done', help='Directory containing files to organize')
    parser.add_argument('--output', '-o', help='Output directory (if not specified, files are organized in place)')
    parser.add_argument('--types', '-t', nargs='+', help='File types to process (e.g., .svg .png)')
    parser.add_argument('--dry-run', '-d', action='store_true', help='Dry run (don\'t actually move files)')
    parser.add_argument('--delete-originals', action='store_true', help='Delete non-foldered files after organizing')

    args = parser.parse_args()

    # Convert file types to lowercase with leading dot
    file_types = None
    if args.types:
        file_types = [f".{t.lower().lstrip('.')}" for t in args.types]

    organize_files(args.directory, args.output, file_types, args.dry_run, args.delete_originals)

if __name__ == "__main__":
    main()