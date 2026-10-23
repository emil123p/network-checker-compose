#!/usr/bin/env python3

import os
import smtplib
import socket
import ssl
from datetime import datetime, timezone
from email.message import EmailMessage

smtp_user = os.environ["SMTP_USER"]
smtp_password = os.environ["SMTP_APP_PASSWORD"]

message = EmailMessage()
message["Subject"] = "BŁĄD wdrożenia Network Checker"
message["From"] = smtp_user
message["To"] = smtp_user

message.set_content(
    f"""Automatyczne wdrożenie Network Checker zakończyło się błędem.

Host: {socket.gethostname()}
Czas UTC: {datetime.now(timezone.utc).isoformat()}

Sprawdź logi poleceniem:
sudo journalctl -u network-checker-deploy.service --no-pager
"""
)

with smtplib.SMTP("smtp.gmail.com", 587, timeout=20) as server:
    server.starttls(context=ssl.create_default_context())
    server.login(smtp_user, smtp_password)
    server.send_message(message)

print("Powiadomienie e-mail wysłane.")
