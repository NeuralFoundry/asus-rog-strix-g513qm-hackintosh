#!/bin/sh
# Runs on the Mac: copies an EFI folder (packed as EFI.tgz containing "EFI/") to the EFI partition of the
# disk macOS is running from. Usage: sh copy-efi-to-esp.sh ~/EFI.tgz
set -e
TGZ="$1"; [ -f "$TGZ" ] || { echo "archive not found: $TGZ"; exit 1; }
SYSDISK=$(diskutil info / | sed -n 's/.*Part of Whole: *//p')                          # e.g. disk1 (APFS container)
PHYS=$(diskutil info "$SYSDISK" | sed -n 's/.*APFS Physical Store: *//p' | head -1)     # e.g. disk0s2
WHOLE=$(echo "$PHYS" | sed 's/s[0-9]*$//')                                              # disk0
ESP=$(diskutil list "$WHOLE" | awk '/EFI/ {print $NF; exit}')                           # disk0s1
echo "system: $SYSDISK  physical store: $PHYS  disk: $WHOLE  ESP: $ESP"
sudo diskutil mount "$ESP" >/dev/null
MP=$(diskutil info "$ESP" | sed -n 's/.*Mount Point: *//p'); echo "ESP mounted at: $MP"
[ -d "$MP/EFI" ] && sudo mv "$MP/EFI" "$MP/EFI.old.$(date +%H%M%S)"
sudo tar xzf "$TGZ" -C "$MP"
ls "$MP/EFI" "$MP/EFI/OC" && echo "kexts: $(ls "$MP/EFI/OC/Kexts" | wc -l)"
sudo diskutil unmount "$ESP" >/dev/null && echo "EFI written to $ESP"
