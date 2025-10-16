#!/usr/bin/env python3
"""Generate encryption and JWT keys for NoctisApp"""

import base64
import secrets
import os

def generate_jwt_secret(length=64):
    """Generate JWT secret key"""
    return secrets.token_urlsafe(length)

def generate_encryption_key():
    """Generate AES-256 encryption key (32 bytes)"""
    key = os.urandom(32)
    return base64.b64encode(key).decode()

def main():
    print("=" * 60)
    print("NoctisApp Security Keys Generator")
    print("=" * 60)
    print()
    
    jwt_secret = generate_jwt_secret()
    encryption_key = generate_encryption_key()
    
    print("JWT_SECRET_KEY:")
    print(jwt_secret)
    print()
    
    print("ENCRYPTION_KEY:")
    print(encryption_key)
    print()
    
    print("=" * 60)
    print("⚠️  IMPORTANT: Store these keys securely!")
    print("Add them to your .env file and never commit them to git")
    print("=" * 60)
    
    # Optionally write to file
    response = input("\nWrite to .env file? (y/n): ")
    if response.lower() == 'y':
        with open('.env', 'a') as f:
            f.write(f"\n# Generated keys - {os.popen('date').read()}")
            f.write(f"JWT_SECRET_KEY={jwt_secret}\n")
            f.write(f"ENCRYPTION_KEY={encryption_key}\n")
        print("✅ Keys written to .env file")

if __name__ == "__main__":
    main()
