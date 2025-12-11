#!/bin/bash
# start.sh — طباعة معلومات الاتصال من ngrok
echo ".........................................................."
echo "IP / ngrok public URL:"
curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | sed 's/"public_url":"//'
echo "Username: usertestddd"
echo "Password: Zxxz4444"
