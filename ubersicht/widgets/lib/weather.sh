#!/usr/bin/env bash
# Weather, reduced to one line the widget can parse without jq.
#
#   tempF|feelsF|desc|code|humidity|windMph|windDir|maxF|minF|HH:temp:code,...
#
# No location is passed on purpose: wttr.in geolocates by IP, so this follows
# you between South Bend and Atlanta without a config change. Override with
# WEATHER_LOCATION if the campus network geolocates somewhere silly.
#
# The raw j1 payload is ~40KB; python trims it to ~120 bytes so Übersicht isn't
# shuttling a JSON blob through a pipe every half hour.
set -uo pipefail

LOC="${WEATHER_LOCATION:-}"
JSON=$(curl -fsS --max-time 12 "https://wttr.in/${LOC}?format=j1" 2>/dev/null) || exit 0
[[ -n "$JSON" ]] || exit 0

printf '%s' "$JSON" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    c = d["current_condition"][0]
    w = d["weather"][0]
    hourly = ",".join(
        "%d:%s:%s" % (int(h["time"]) // 100, h["tempF"], h["weatherCode"])
        for h in w["hourly"]
    )
    print("|".join([
        c["temp_F"], c["FeelsLikeF"], c["weatherDesc"][0]["value"].strip(),
        c["weatherCode"], c["humidity"], c["windspeedMiles"], c["winddir16Point"],
        w["maxtempF"], w["mintempF"], hourly,
    ]))
except Exception:
    pass
' 2>/dev/null
