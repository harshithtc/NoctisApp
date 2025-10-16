from __future__ import annotations
import base64
import os
from typing import Optional, Tuple
from cryptography.hazmat.primitives import padding, hashes
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

def _b64encode(data: bytes) -> str:
    return base64.b64encode(data).decode("utf-8")

def _b64decode(text: str) -> bytes:
    s = text.strip()
    missing = (-len(s)) % 4
    if missing:
        s += "=" * missing
    return base64.b64decode(s)

def _pkcs7_pad(data: bytes, block_bits: int = 128) -> bytes:
    padder = padding.PKCS7(block_bits).padder()
    return padder.update(data) + padder.finalize()

def _pkcs7_unpad(data: bytes, block_bits: int = 128) -> bytes:
    unpadder = padding.PKCS7(block_bits).unpadder()
    return unpadder.update(data) + unpadder.finalize()

class EncryptionService:
    """
    AES-256-GCM (default, recommended) and AES-256-CBC (legacy)
    Uses base64-encoded 32-byte key.
    encrypt()/decrypt(): handles str <-> bytes with b64.
    .encrypt_bytes()/.decrypt_bytes(): direct for binary.
    """

    def __init__(self, key_b64: str, mode: Optional[str] = None, hkdf_info: Optional[bytes] = None):
        root = _b64decode(key_b64)
        if len(root) != 32:
            raise ValueError("ENCRYPTION_KEY must decode to 32 bytes")
        if hkdf_info:
            hkdf = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=hkdf_info)
            self.key = hkdf.derive(root)
        else:
            self.key = root

        self.mode = (mode or "GCM").upper()
        if self.mode not in ("GCM", "CBC"):
            self.mode = "GCM"

    def encrypt(self, plaintext: str) -> Tuple[str, str]:
        data = plaintext.encode("utf-8")
        if self.mode == "CBC":
            ct, iv = self._encrypt_cbc(data)
        else:
            ct, iv = self._encrypt_gcm(data)
        return _b64encode(ct), _b64encode(iv)

    def decrypt(self, encrypted_text_b64: str, iv_or_nonce_b64: str) -> str:
        ct = _b64decode(encrypted_text_b64)
        iv = _b64decode(iv_or_nonce_b64)
        if self.mode == "CBC":
            pt = self._decrypt_cbc(ct, iv)
        else:
            pt = self._decrypt_gcm(ct, iv)
        return pt.decode("utf-8")

    def encrypt_bytes(self, data: bytes) -> Tuple[bytes, bytes]:
        if self.mode == "CBC":
            return self._encrypt_cbc(data)
        return self._encrypt_gcm(data)

    def decrypt_bytes(self, ciphertext: bytes, iv_or_nonce: bytes) -> bytes:
        if self.mode == "CBC":
            return self._decrypt_cbc(ciphertext, iv_or_nonce)
        return self._decrypt_gcm(ciphertext, iv_or_nonce)

    # AES-GCM (recommended)
    def _encrypt_gcm(self, data: bytes, *, aad: Optional[bytes] = None) -> Tuple[bytes, bytes]:
        nonce = os.urandom(12)
        aesgcm = AESGCM(self.key)
        ct = aesgcm.encrypt(nonce, data, aad)
        return ct, nonce

    def _decrypt_gcm(self, ciphertext: bytes, nonce: bytes, *, aad: Optional[bytes] = None) -> bytes:
        aesgcm = AESGCM(self.key)
        return aesgcm.decrypt(nonce, ciphertext, aad)

    # AES-CBC (legacy compatibility)
    def _encrypt_cbc(self, data: bytes) -> Tuple[bytes, bytes]:
        iv = os.urandom(16)
        cipher = Cipher(algorithms.AES(self.key), modes.CBC(iv))
        encryptor = cipher.encryptor()
        padded = _pkcs7_pad(data, 128)
        ct = encryptor.update(padded) + encryptor.finalize()
        return ct, iv

    def _decrypt_cbc(self, ciphertext: bytes, iv: bytes) -> bytes:
        cipher = Cipher(algorithms.AES(self.key), modes.CBC(iv))
        decryptor = cipher.decryptor()
        padded = decryptor.update(ciphertext) + decryptor.finalize()
        return _pkcs7_unpad(padded, 128)
