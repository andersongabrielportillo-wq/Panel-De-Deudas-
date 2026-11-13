#!/usr/bin/env python3
"""Auditoría estática de seguridad CL Nexus: no usa red ni modifica datos."""
from pathlib import Path
import re,sys
root=Path(__file__).resolve().parent
html=(root/"index.html").read_text(encoding="utf-8")
sw=(root/"sw.js").read_text(encoding="utf-8")
checks=[
("Supabase Auth",bool(re.search(r"signInWithPassword",html))),
("Autorización de workspace",bool(re.search(r'from\(["\']workspace_members["\']\)',html))),
("Carga del estado financiero",bool(re.search(r'from\(["\']debts["\']\)',html))),
("Canal de sincronización",bool(re.search(r"postgres_changes",html))),
("Service Worker registrado",bool(re.search(r"serviceWorker\.register",html))),
("SW evita interceptar otros orígenes","url.origin !== self.location.origin" in sw),
("Bloqueo adicional verificable en cliente",bool(re.search(r"debtGate|debtUnlock|secondFactor|unlockDebts",html,re.I))),
]
print("CL NEXUS - REVISIÓN ESTÁTICA (NO prueba seguridad servidor)\n")
for label,ok in checks:print(("[PRESENTE] " if ok else "[NO IDENTIFICADO] ")+label)
print("\nATENCIÓN: No encontrar una cadena NO demuestra ausencia del control.")
print("La verificación real exige pruebas de permisos RLS/RPC/servidor con cuentas de prueba.")
print("No ejecutar esta app de pruebas contra datos reales.")
