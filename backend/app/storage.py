"""
LEXIA - Almacenamiento (Supabase Storage)
============================================
Sube los contratos (PDF/imágenes) y los reportes generados a Supabase
Storage, en vez de guardarlos en disco local — necesario porque Render
(y la nube en general) tiene almacenamiento efímero: los archivos locales
se pierden cada vez que el servicio se reinicia o se redepliega.
"""

from supabase import create_client, Client

from .config import SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_BUCKET

_client: Client | None = None


def get_client() -> Client:
    global _client
    if _client is None:
        if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
            raise RuntimeError(
                "Faltan SUPABASE_URL / SUPABASE_SERVICE_KEY en las variables de entorno."
            )
        _client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    return _client


def upload_file(local_path: str, remote_name: str, content_type: str = "application/octet-stream") -> str:
    """
    Sube un archivo local al bucket de Supabase Storage y devuelve la ruta
    remota (no la URL pública, ya que el bucket es privado — se usan URLs
    firmadas para leerlo después, ver get_signed_url).
    """
    client = get_client()
    with open(local_path, "rb") as f:
        client.storage.from_(SUPABASE_BUCKET).upload(
            remote_name,
            f,
            file_options={"content-type": content_type, "upsert": "true"},
        )
    return remote_name


def get_signed_url(remote_name: str, expires_in_seconds: int = 3600) -> str:
    """Genera una URL temporal para descargar/ver el archivo (el bucket es privado)."""
    client = get_client()
    result = client.storage.from_(SUPABASE_BUCKET).create_signed_url(remote_name, expires_in_seconds)
    return result.get("signedURL") or result.get("signed_url", "")


def delete_file(remote_name: str) -> None:
    client = get_client()
    client.storage.from_(SUPABASE_BUCKET).remove([remote_name])
