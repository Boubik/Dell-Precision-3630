# BIOS Patch Generator

This script helps you build modified BIOS images with a custom MAC address and Service Tag.  It is intended for situations where you need to re‑program a replacement board with identifiers that match another known‑good machine.

## Requirements
-	A dump of a working BIOS from the same model and board revision.  Never run the script against your only copy; always keep the original file unchanged.
-	A Linux or macOS system with bash, dd, sed and od available.

## Configuration

Open the script in a text editor and adjust the variables at the top:
-	INPUT_FILE – path to your good BIOS binary.
-	OUTPUT_DIR – directory where the patched images will be written.
-	OUTPUT_PREFIX – base name used for output files.
-	NEW_MAC – the new MAC address in colon‑separated form (exactly six bytes).
-	MAC_OFFSETS – addresses in the BIOS file where the MAC should be written.
-	NEW_TAG – the new Service Tag (exactly seven ASCII characters).
-	TAG_OFFSETS – addresses in the BIOS file where the Service Tag should be written.

Generation switches further down let you control whether the script writes the MAC at all offsets, generates all tag combinations, or produces cross‑combinations.  Set them to 1 to enable or 0 to disable.

## Usage

After adjusting the variables, make the script executable and run it:
```sh
chmod +x modify_bin.sh
./modify_bin.sh
```

The script makes a copy of your input file, patches the identifiers at the specified offsets and writes the result into OUTPUT_DIR.  Use your preferred programmer (e.g. flashrom) to flash the resulting .bin file back to the chip.

Warning

Modifying firmware always carries a risk.  Using an incorrect input file or wrong offsets can brick your hardware.  Work only on hardware you can recover, and proceed at your own risk.  No warranty or support is provided.
