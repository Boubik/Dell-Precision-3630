#!/bin/bash

# ------------------------------------------------------------
# BIOS patch generator
#
# Default behavior:
#   - write MAC to ALL MAC offsets
#   - generate Service Tag variants separately
#
# Optional behavior:
#   - generate all MAC offset combinations
#   - generate MAC+TAG combined variants
#
# Use at your own risk. Always keep the original dump unchanged.
# ------------------------------------------------------------

set -e

# ============================================================
# User configuration
# ============================================================

# Input BIOS image
INPUT_FILE="Dumps/good/8PXKD03.bin"

# Output directory
OUTPUT_DIR="Dumps/moded/JXP2K03"

# Base output filename prefix
OUTPUT_PREFIX="JXP2K03"

# ---------------- MAC ----------------
NEW_MAC="00:4e:01:a5:85:35"
MAC_OFFSETS=(0x1000 0x1004b48 0x1044b48)

# ---------------- Service Tag ----------------
NEW_TAG="JXP2K03"
#TAG_OFFSETS=(0x108002a) # Original offset but it is broke so use the offset bellow to make it reset.
TAG_OFFSETS=(0x1080027)

# ============================================================
# Generation switches
# ============================================================

# Default: create one file with MAC written to all MAC offsets
GENERATE_MAC_ALL=0

# Optional: create all non-empty MAC offset combinations
# Example with 3 offsets:
#   mac_1, mac_2, mac_3, mac_1_2, mac_1_3, mac_2_3, mac_1_2_3
GENERATE_MAC_VARIANTS=0

# Create one file with TAG written to all TAG offsets
GENERATE_TAG_ALL=0

# Create all non-empty TAG offset combinations
GENERATE_TAG_VARIANTS=0

# Create files with:
#   MAC written to all MAC offsets
#   +
#   all TAG combinations
GENERATE_MAC_ALL_PLUS_TAG_VARIANTS=1

# Create files with:
#   all MAC combinations
#   +
#   all TAG combinations
# Warning: this grows quickly
GENERATE_MAC_VARIANTS_PLUS_TAG_VARIANTS=0

# ============================================================
# Helper functions
# ============================================================

mac_hex() {
    echo "$1" | tr -d ':'
}

write_hex_at_offset() {
    local hexstr="$1"
    local offset="$2"
    local file="$3"

    local bin
    bin=$(echo "$hexstr" | sed 's/\(..\)/\\x\1/g')
    printf "$bin" | dd of="$file" bs=1 seek="$offset" conv=notrunc status=none
}

to_dec() {
    local off="$1"
    if [[ "$off" =~ ^0x ]]; then
        printf "%d" "$off"
    else
        echo "$off"
    fi
}

patch_mac_selected() {
    local file="$1"
    shift
    local offsets=("$@")
    local off

    for off in "${offsets[@]}"; do
        local dec_off
        dec_off=$(to_dec "$off")
        echo "    MAC -> $off (dec $dec_off)"
        write_hex_at_offset "$MAC_HEX" "$dec_off" "$file"
    done
}

patch_tag_selected() {
    local file="$1"
    shift
    local offsets=("$@")
    local off

    for off in "${offsets[@]}"; do
        local dec_off
        dec_off=$(to_dec "$off")
        echo "    TAG -> $off (dec $dec_off)"
        write_hex_at_offset "$TAG_HEX" "$dec_off" "$file"
    done
}

make_output_copy() {
    local outfile="$1"
    cp "$INPUT_FILE" "$outfile"
    echo "Created: $outfile"
}

build_suffix_from_mask() {
    local prefix="$1"
    local mask="$2"
    shift 2
    local arr=("$@")

    local count="${#arr[@]}"
    local i=0
    local suffix="$prefix"

    while [ "$i" -lt "$count" ]; do
        if (( mask & (1 << i) )); then
            suffix="${suffix}_$((i+1))"
        fi
        i=$((i+1))
    done

    echo "$suffix"
}

collect_offsets_from_mask() {
    local mask="$1"
    shift
    local arr=("$@")

    local count="${#arr[@]}"
    local i=0
    local result=""

    while [ "$i" -lt "$count" ]; do
        if (( mask & (1 << i) )); then
            result="$result ${arr[$i]}"
        fi
        i=$((i+1))
    done

    echo "$result"
}

# ============================================================
# Validation
# ============================================================

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: input file not found: $INPUT_FILE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

MAC_HEX=$(mac_hex "$NEW_MAC")
if [ ${#MAC_HEX} -ne 12 ]; then
    echo "Error: MAC address must be exactly 6 bytes"
    exit 1
fi

if [ ${#NEW_TAG} -ne 7 ]; then
    echo "Error: Service Tag must be exactly 7 ASCII characters"
    exit 1
fi

TAG_HEX=$(echo -n "$NEW_TAG" | od -A n -t x1 | tr -d ' \n')

echo "Input file : $INPUT_FILE"
echo "Output dir : $OUTPUT_DIR"
echo "MAC        : $NEW_MAC"
echo "TAG        : $NEW_TAG"
echo

# ============================================================
# 1) MAC to all offsets
# ============================================================

if [ "$GENERATE_MAC_ALL" -eq 1 ]; then
    OUTFILE="${OUTPUT_DIR}/${OUTPUT_PREFIX}_mac_all.bin"
    echo "[MAC ONLY - ALL OFFSETS]"
    make_output_copy "$OUTFILE"
    patch_mac_selected "$OUTFILE" "${MAC_OFFSETS[@]}"
    echo
fi

# ============================================================
# 2) All MAC combinations
# ============================================================

if [ "$GENERATE_MAC_VARIANTS" -eq 1 ]; then
    echo "[MAC ONLY - ALL VARIANTS]"
    MAC_COUNT="${#MAC_OFFSETS[@]}"
    MAX_MASK=$(( (1 << MAC_COUNT) - 1 ))
    MASK=1

    while [ "$MASK" -le "$MAX_MASK" ]; do
        SUFFIX=$(build_suffix_from_mask "mac" "$MASK" "${MAC_OFFSETS[@]}")
        OUTFILE="${OUTPUT_DIR}/${OUTPUT_PREFIX}_${SUFFIX}.bin"

        OFFSETS_STR=$(collect_offsets_from_mask "$MASK" "${MAC_OFFSETS[@]}")
        # shellcheck disable=SC2206
        SELECTED_OFFSETS=( $OFFSETS_STR )

        echo "Variant mask=$MASK suffix=$SUFFIX"
        make_output_copy "$OUTFILE"
        patch_mac_selected "$OUTFILE" "${SELECTED_OFFSETS[@]}"
        echo

        MASK=$((MASK + 1))
    done
fi

# ============================================================
# 3) TAG to all offsets
# ============================================================

if [ "$GENERATE_TAG_ALL" -eq 1 ]; then
    OUTFILE="${OUTPUT_DIR}/${OUTPUT_PREFIX}_tag_all.bin"
    echo "[TAG ONLY - ALL OFFSETS]"
    make_output_copy "$OUTFILE"
    patch_tag_selected "$OUTFILE" "${TAG_OFFSETS[@]}"
    echo
fi

# ============================================================
# 4) All TAG combinations
# ============================================================

if [ "$GENERATE_TAG_VARIANTS" -eq 1 ]; then
    echo "[TAG ONLY - ALL VARIANTS]"
    TAG_COUNT="${#TAG_OFFSETS[@]}"
    MAX_MASK=$(( (1 << TAG_COUNT) - 1 ))
    MASK=1

    while [ "$MASK" -le "$MAX_MASK" ]; do
        SUFFIX=$(build_suffix_from_mask "tag" "$MASK" "${TAG_OFFSETS[@]}")
        OUTFILE="${OUTPUT_DIR}/${OUTPUT_PREFIX}_${SUFFIX}.bin"

        OFFSETS_STR=$(collect_offsets_from_mask "$MASK" "${TAG_OFFSETS[@]}")
        # shellcheck disable=SC2206
        SELECTED_OFFSETS=( $OFFSETS_STR )

        echo "Variant mask=$MASK suffix=$SUFFIX"
        make_output_copy "$OUTFILE"
        patch_tag_selected "$OUTFILE" "${SELECTED_OFFSETS[@]}"
        echo

        MASK=$((MASK + 1))
    done
fi

# ============================================================
# 5) MAC all + TAG variants
# ============================================================

if [ "$GENERATE_MAC_ALL_PLUS_TAG_VARIANTS" -eq 1 ]; then
    echo "[MAC ALL + TAG VARIANTS]"
    TAG_COUNT="${#TAG_OFFSETS[@]}"
    MAX_MASK=$(( (1 << TAG_COUNT) - 1 ))
    MASK=1

    while [ "$MASK" -le "$MAX_MASK" ]; do
        TAG_SUFFIX=$(build_suffix_from_mask "tag" "$MASK" "${TAG_OFFSETS[@]}")
        OUTFILE="${OUTPUT_DIR}/${OUTPUT_PREFIX}_mac_all_${TAG_SUFFIX}.bin"

        OFFSETS_STR=$(collect_offsets_from_mask "$MASK" "${TAG_OFFSETS[@]}")
        # shellcheck disable=SC2206
        SELECTED_TAG_OFFSETS=( $OFFSETS_STR )

        echo "Variant mask=$MASK suffix=mac_all_${TAG_SUFFIX}"
        make_output_copy "$OUTFILE"
        patch_mac_selected "$OUTFILE" "${MAC_OFFSETS[@]}"
        patch_tag_selected "$OUTFILE" "${SELECTED_TAG_OFFSETS[@]}"
        echo

        MASK=$((MASK + 1))
    done
fi

# ============================================================
# 6) MAC variants + TAG variants
# ============================================================

if [ "$GENERATE_MAC_VARIANTS_PLUS_TAG_VARIANTS" -eq 1 ]; then
    echo "[MAC VARIANTS + TAG VARIANTS]"
    MAC_COUNT="${#MAC_OFFSETS[@]}"
    TAG_COUNT="${#TAG_OFFSETS[@]}"


    MAX_MAC_MASK=$(( (1 << MAC_COUNT) - 1 ))
    MAX_TAG_MASK=$(( (1 << TAG_COUNT) - 1 ))

    MAC_MASK=1
    while [ "$MAC_MASK" -le "$MAX_MAC_MASK" ]; do
        MAC_SUFFIX=$(build_suffix_from_mask "mac" "$MAC_MASK" "${MAC_OFFSETS[@]}")
        MAC_OFFSETS_STR=$(collect_offsets_from_mask "$MAC_MASK" "${MAC_OFFSETS[@]}")
        # shellcheck disable=SC2206
        SELECTED_MAC_OFFSETS=( $MAC_OFFSETS_STR )

        TAG_MASK=1
        while [ "$TAG_MASK" -le "$MAX_TAG_MASK" ]; do
            TAG_SUFFIX=$(build_suffix_from_mask "tag" "$TAG_MASK" "${TAG_OFFSETS[@]}")
            TAG_OFFSETS_STR=$(collect_offsets_from_mask "$TAG_MASK" "${TAG_OFFSETS[@]}")
            # shellcheck disable=SC2206
            SELECTED_TAG_OFFSETS=( $TAG_OFFSETS_STR )

            OUTFILE="${OUTPUT_DIR}/${OUTPUT_PREFIX}_${MAC_SUFFIX}_${TAG_SUFFIX}.bin"

            echo "Variant mac_mask=$MAC_MASK tag_mask=$TAG_MASK suffix=${MAC_SUFFIX}_${TAG_SUFFIX}"
            make_output_copy "$OUTFILE"
            patch_mac_selected "$OUTFILE" "${SELECTED_MAC_OFFSETS[@]}"
            patch_tag_selected "$OUTFILE" "${SELECTED_TAG_OFFSETS[@]}"
            echo

            TAG_MASK=$((TAG_MASK + 1))
        done

        MAC_MASK=$((MAC_MASK + 1))
    done
fi

echo "Done."
