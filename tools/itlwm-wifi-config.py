r"""Stores a Wi-Fi SSID and password in itlwm's Info.plist so the card auto-connects in the installer.
Usage:  python itlwm-wifi-config.py E      (E = drive letter of the mounted EFI partition)
The password is written only into <drive>:\EFI\OC\Kexts\itlwm.kext\Contents\Info.plist."""
import sys, os, plistlib, getpass
usb = sys.argv[1].rstrip(":") + ":\\"
p = os.path.join(usb, "EFI", "OC", "Kexts", "itlwm.kext", "Contents", "Info.plist")
assert os.path.exists(p), "itlwm.kext not found: " + p
ssid = input("Wi-Fi network name (SSID): ").strip()
pw = getpass.getpass("Wi-Fi password (hidden while typing): ").strip()
assert ssid, "empty SSID"
plist = plistlib.load(open(p, "rb"))
plist["IOKitPersonalities"]["itlwm"]["WiFiConfig"] = {"WiFi_1": {"ssid": ssid, "password": pw}}
plistlib.dump(plist, open(p, "wb"))
print("written:", p, "| SSID:", ssid, "| password length:", len(pw))
