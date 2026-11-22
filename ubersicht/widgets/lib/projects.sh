#!/bin/bash
# Data for projects.jsx — one TSV row per project from `proj status`.
# stderr is silenced first: Übersicht turns the first stderr byte into a
# 500 and the widget into an error card (see CLAUDE.md).
exec 2>/dev/null
exec "$HOME/.local/bin/proj" status --tsv
