#!/bin/bash
# Remove stale network services that networksetup can't remove
# by editing the preferences plist directly with PlistBuddy

set -e

PREFS="/Library/Preferences/SystemConfiguration/preferences.plist"
NETIFS="/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist"

# Backup
sudo cp "$PREFS" "${PREFS}.backup2"
sudo cp "$NETIFS" "${NETIFS}.backup2"

# Convert to XML for editing
sudo plutil -convert xml1 "$PREFS"
sudo plutil -convert xml1 "$NETIFS"

echo "Removing stale services from preferences.plist..."

# Iterate through all NetworkServices keys and remove stale ones
# We need to keep going until no more stale entries are found
while true; do
    FOUND=0
    # List all service UUIDs
    KEYS=$(/usr/libexec/PlistBuddy -c "Print :NetworkServices" "$PREFS" 2>/dev/null | grep "Dict" | awk '{print $1}' | tr -d ':')
    
    for key in $KEYS; do
        # Skip if key is empty or is "Dict" itself
        [ -z "$key" ] && continue
        name=$(/usr/libexec/PlistBuddy -c "Print :NetworkServices:${key}:UserDefinedName" "$PREFS" 2>/dev/null) || continue
        
        if echo "$name" | grep -qE "USB ACM|ThinkPad|Ethernet Gadget|ESP32|USB JTAG"; then
            echo "  Removing service: $name ($key)"
            sudo /usr/libexec/PlistBuddy -c "Delete :NetworkServices:${key}" "$PREFS" 2>/dev/null || true
            FOUND=1
            break  # restart loop since dict changed
        fi
        # Remove service named just "2"
        if [ "$name" = "2" ]; then
            echo "  Removing service: 2 ($key)"
            sudo /usr/libexec/PlistBuddy -c "Delete :NetworkServices:${key}" "$PREFS" 2>/dev/null || true
            FOUND=1
            break
        fi
    done
    
    [ $FOUND -eq 0 ] && break
done

# Clean up ServiceOrder array - remove references to deleted services
idx=0
while true; do
    svc=$(/usr/libexec/PlistBuddy -c "Print :ServiceOrder:${idx}" "$PREFS" 2>/dev/null) || break
    # Check if this service still exists
    /usr/libexec/PlistBuddy -c "Print :NetworkServices:${svc}" "$PREFS" 2>/dev/null >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "  Removing stale service order entry: $svc"
        sudo /usr/libexec/PlistBuddy -c "Delete :ServiceOrder:${idx}" "$PREFS" 2>/dev/null || true
        # Don't increment, array shifts down
    else
        idx=$((idx + 1))
    fi
done

echo "Removing stale interfaces from NetworkInterfaces.plist..."

# Remove stale interface entries
idx=0
while true; do
    name=$(/usr/libexec/PlistBuddy -c "Print :Interfaces:${idx}:DeviceName" "$NETIFS" 2>/dev/null) || break
    
    if echo "$name" | grep -qE "usbmodem|^en[5678]$"; then
        echo "  Removing interface: $name"
        sudo /usr/libexec/PlistBuddy -c "Delete :Interfaces:${idx}" "$NETIFS" 2>/dev/null || true
        # Don't increment, array shifts down
    else
        idx=$((idx + 1))
    fi
done

# Re-enable the USB 10/100/1000 LAN if it exists
sudo networksetup -setnetworkserviceenabled "USB 10/100/1000 LAN" on 2>/dev/null || true

echo ""
echo "Done. Reboot for changes to take effect:"
echo "  sudo shutdown -r now"
