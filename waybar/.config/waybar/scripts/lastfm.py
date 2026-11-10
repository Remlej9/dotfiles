#!/usr/bin/env python3
import urllib.request
import json
import time
import threading
import sys
import os

USER = "Remlej9"


def load_api_key():
    """The key is kept out of the dotfiles repo: $LASTFM_API_KEY, or the first
    line of ~/.config/lastfm/api_key (chmod 600)."""
    key = os.environ.get("LASTFM_API_KEY", "").strip()
    if key:
        return key
    path = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                        "lastfm", "api_key")
    try:
        with open(path) as f:
            return f.readline().strip()
    except OSError:
        return ""


API_KEY = load_api_key()
if not API_KEY:
    # No key configured: show nothing instead of erroring in the bar
    if len(sys.argv) > 1 and sys.argv[1] in ("--anim", "--text"):
        print(json.dumps({"text": "", "tooltip": "Last.fm: no API key in ~/.config/lastfm/api_key"}), flush=True)
        while True:
            time.sleep(3600)
    sys.exit(0)

current_song = ""
current_album = ""
is_playing = False

def fetch_lastfm():
    """Background thread to poll Last.fm every 10 seconds."""
    global current_song, is_playing, current_album
    url = f"http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user={USER}&api_key={API_KEY}&format=json&limit=1"
    
    while True:
        try:
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req) as response:
                data = json.loads(response.read().decode())
                track = data['recenttracks']['track'][0]
                
                if '@attr' in track and track['@attr'].get('nowplaying') == 'true':
                    artist = track['artist']['#text']
                    title = track['name']
                    album = track['album']['#text']
                    current_song = f"{artist} - {title}"
                    current_album = f"{album}"
                    is_playing = True
                else:
                    is_playing = False
        except Exception:
            pass
        
        time.sleep(10)

# Start API fetching
threading.Thread(target=fetch_lastfm, daemon=True).start()
time.sleep(0.5)

mode = sys.argv[1] if len(sys.argv) > 1 else "--text"

if mode == "--anim":
    frames = ["▃▆▄", "▅▃▇", "▇▅▃", "▄█▆", "▂▆█", "▆▃▅", "█▇▂", "▅▄▆", "▃█▃", "▆▅▇", "▇▂▄", "▄▆▃"]
    frame_index = 0
    while True:
        if is_playing:
            anim = frames[frame_index % len(frames)]
            print(json.dumps({"text": anim, "class": "playing"}))
            frame_index += 1
        else:
            print(json.dumps({"text": "", "class": "stopped"}))
        sys.stdout.flush()
        time.sleep(0.12) # Fast loop for animation

elif mode == "--text":
    # Text Mode
    last_song = None
    last_state = None
    while True:
        # Only print a new UI update if the track or playback state actually changed
        if is_playing != last_state or current_song != last_song:
            if is_playing:
                print(json.dumps({
                    "text": current_song,
                    "tooltip": f"Song:  {current_song}\nAlbum: {current_album}",
                    "class": "playing"
                }))
            else:
                print(json.dumps({"text": "", "class": "stopped"}))
            
            sys.stdout.flush()
            last_song = current_song
            last_state = is_playing
            
        time.sleep(2) # Slow loop allows GTK tooltips to register

elif mode == "--open":
    import webbrowser
    
    # Make a quick call to get the exact URL of the current song
    url = f"http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user={USER}&api_key={API_KEY}&format=json&limit=1"
    
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            track = data['recenttracks']['track'][0]
            
            # If a song is currently playing, open its specific Last.fm page
            if '@attr' in track and track['@attr'].get('nowplaying') == 'true':
                song_url = track.get('url')
                if song_url:
                    webbrowser.open(song_url)
                    sys.exit(0)
                    
    except Exception:
        pass # Fallback to user profile if network fails or no url exists
        
    # Fallback: Open your main profile if nothing is playing
    webbrowser.open(f"https://www.last.fm/user/{USER}")