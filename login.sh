#!/bin/bash
echo "==================================================="
echo "           macOS RDP Connection Details            "
echo "==================================================="
echo "IP Address (Use in VNC Viewer):"
curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | sed 's/"public_url":"//'
echo ""
echo "Username: usertestddd"
echo "Password: Zxxz4444"
echo "==================================================="
echo "NOTE: If screen is black, wait 1 minute."
echo "==================================================="
