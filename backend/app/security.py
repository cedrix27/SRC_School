import hashlib
import hmac
import secrets


def hash_password(password):
    if len(password) < 10:
        raise ValueError('Mot de passe : 10 caractères minimum')
    salt = secrets.token_hex(16)
    result = hashlib.scrypt(password.encode(), salt=salt.encode(), n=16384, r=8, p=1)
    return salt + ':' + result.hex()


def verify_password(password, stored):
    salt, digest = stored.split(':')
    result = hashlib.scrypt(password.encode(), salt=salt.encode(), n=16384, r=8, p=1)
    return hmac.compare_digest(result.hex(), digest)


def token_hash(token):
    return hashlib.sha256(token.encode()).hexdigest()
