#!/bin/bash
echo "==================================================="
echo "           macOS RDP Connection Details            "
echo "==================================================="
echo "Waiting for Ngrok tunnel..."
sleep 5
echo "IP Address (Use in VNC Viewer):"
curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | sed 's/"public_url":"//'
echo ""
echo "Username: usertestddd"
echo "Password: Zxxz4444"
echo "==================================================="
echo "IMPORTANT: If screen is black:"
echo "1. Connect via VNC."
echo "2. Don't close the window."
echo "3. Wait for the 'Keep Alive' script to move the mouse."
echo "==================================================="
