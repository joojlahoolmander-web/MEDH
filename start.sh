#!/bin/bash
# start.sh — print ngrok public URL and credentials
echo ".........................................................."
echo "ngrok public URL(s):"
curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[]?.public_url' 2>/dev/null || curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | sed 's/"public_url":"//'
echo ""
echo "VNC Username: usertestddd"
echo "VNC Password: Zxxz4444"
