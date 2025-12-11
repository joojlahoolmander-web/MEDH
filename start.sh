#!/bin/bash
# start.sh — print ngrok public URL and credentials
echo ".........................................................."
echo "ngrok public URL(s):"
# prefer jq if موجود
if command -v jq >/dev/null 2>&1; then
  curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[]?.public_url'
else
  curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | sed 's/"public_url":"//'
fi
echo ""
echo "VNC Username: usertestddd"
echo "VNC Password: Zxxz4444"
