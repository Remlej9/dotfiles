#!/bin/bash
# Waybar custom/updates. Empty text hides the module when up to date.

official_updates=$(checkupdates 2>/dev/null | wc -l)
aur_updates=$(yay -Qua 2>/dev/null | wc -l)

total_updates=$((official_updates + aur_updates))

if [ "$total_updates" -gt 0 ]; then
    echo "{\"text\": \"$total_updates\", \"tooltip\": \"Updates available: $total_updates\nOfficial: $official_updates\nAUR: $aur_updates\n\nClick to update via yay.\"}"
else
    echo "{\"text\": \"\", \"tooltip\": \"System is up-to-date!\"}"
fi
