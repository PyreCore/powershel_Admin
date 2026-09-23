#!/bin/bash

echo "======================================"
echo "       ÉTAT DU SYSTÈME"
echo "======================================"

echo ""
echo "🖥️  SYSTÈME"
echo "OS       : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
echo "Hostname : $(hostname)"
echo "Kernel   : $(uname -r)"

echo ""
echo "⏱️  TEMPS DE FONCTIONNEMENT"
uptime -p

echo ""
echo "🧠 MÉMOIRE"
free -h

echo ""
echo "💾 DISQUE"
df -h /

echo ""
echo "⚙️  CPU"
echo "Processeurs : $(nproc)"
echo "Charge      : $(uptime | awk -F'load average:' '{print $2}')"

echo ""
echo "🌐 RÉSEAU"
ip -br addr

echo ""
echo "👤 UTILISATEUR"
echo "Utilisateur : $(whoami)"

echo ""
echo "======================================"
echo "       FIN DU RAPPORT"
echo "======================================"
