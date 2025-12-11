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
echo "NOTE: If screen is black, just move your mouse inside VNC."
echo "      Don't worry, the Keep-Alive script is running."
echo "==================================================="
