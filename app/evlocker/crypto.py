import base64
import hashlib
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


class EvidenceCipher:
    def __init__(self, key_b64: str):
        key = base64.b64decode(key_b64)
        if len(key) != 32:
            raise ValueError("APP_ENC_KEY must decode to 32 bytes")
        self._aead = AESGCM(key)

    def encrypt(self, data: bytes, digest: str) -> tuple[bytes, bytes]:
        nonce = os.urandom(12)
        return nonce, self._aead.encrypt(nonce, data, digest.encode())

    def decrypt(self, nonce: bytes, ciphertext: bytes, digest: str) -> bytes:
        return self._aead.decrypt(nonce, ciphertext, digest.encode())


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


GENESIS = "0" * 64


def chain_hash(prev_hash: str, evidence_id: int, action: str, actor: str, created_at: str) -> str:
    material = f"{prev_hash}|{evidence_id}|{action}|{actor}|{created_at}".encode()
    return hashlib.sha256(material).hexdigest()
