"""
Screenshot Compression Task

Celery task for compressing screenshots and generating thumbnails
using Pillow. Scheduled to run asynchronously after screenshot upload.
"""

import logging
from pathlib import Path

from PIL import Image

from app.celery_app import celery_app

logger = logging.getLogger(__name__)

THUMBNAIL_SIZE = (320, 240)
COMPRESSION_QUALITY = 70


@celery_app.task(
    name="screenshot.compress",
    bind=True,
    max_retries=3,
    soft_time_limit=120,
    time_limit=180,
)
def compress_screenshot(
    self,
    screenshot_id: str,
    file_path: str,
    thumbnail_path: str | None = None,
) -> dict:
    """
    Compress a single screenshot and generate a thumbnail.

    Args:
        screenshot_id: UUID string of the screenshot record.
        file_path: Absolute path to the screenshot file.
        thumbnail_path: Path to save the thumbnail. Auto-generated if None.

    Returns:
        dict with status, original_size, compressed_size, and thumbnail info.
    """
    try:
        source = Path(file_path)
        if not source.exists():
            error_msg = f"Screenshot file not found: {file_path}"
            logger.error(error_msg)
            return {"status": "error", "error": error_msg}

        original_size = source.stat().st_size

        # Open and compress
        with Image.open(source) as img:
            # Convert RGBA/P to RGB for JPEG compression
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")

            # Save compressed version (overwrite original with compressed)
            img.save(
                source,
                "JPEG",
                quality=COMPRESSION_QUALITY,
                optimize=True,
            )

        compressed_size = source.stat().st_size
        ratio = round((1 - compressed_size / original_size) * 100, 1)

        # Generate thumbnail
        thumb_result = generate_thumbnail_task(file_path, thumbnail_path)

        result = {
            "status": "success",
            "screenshot_id": screenshot_id,
            "original_size": original_size,
            "compressed_size": compressed_size,
            "compression_ratio": ratio,
            "thumbnail": thumb_result,
        }
        logger.info(
            "Compressed screenshot %s: %d → %d bytes (%s%%)",
            screenshot_id,
            original_size,
            compressed_size,
            ratio,
        )
        return result

    except Exception as exc:
        logger.exception("Failed to compress screenshot %s", screenshot_id)
        try:
            self.retry(exc=exc, countdown=60)
        except Exception:
            pass
        return {
            "status": "error",
            "screenshot_id": screenshot_id,
            "error": str(exc),
        }


@celery_app.task(
    name="screenshot.generate_thumbnail",
    bind=True,
    max_retries=2,
    soft_time_limit=60,
)
def generate_thumbnail_task(
    self,
    file_path: str,
    thumbnail_path: str | None = None,
) -> dict:
    """
    Generate a thumbnail from a screenshot file.

    Args:
        file_path: Absolute path to the source image.
        thumbnail_path: Path to save the thumbnail. Auto-generated if None.

    Returns:
        dict with thumbnail status and path.
    """
    try:
        source = Path(file_path)
        if not source.exists():
            return {"status": "error", "error": f"File not found: {file_path}"}

        # Auto-generate thumbnail path if not provided
        if thumbnail_path is None:
            thumb_dir = source.parent / "thumbnails"
            thumb_dir.mkdir(exist_ok=True)
            thumbnail_path = str(thumb_dir / f"{source.stem}_thumb.jpg")

        with Image.open(source) as img:
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")
            img.thumbnail(THUMBNAIL_SIZE, Image.LANCZOS)

            thumb = Path(thumbnail_path)
            thumb.parent.mkdir(parents=True, exist_ok=True)
            img.save(thumb, "JPEG", quality=60)

        logger.info("Thumbnail generated: %s", thumbnail_path)
        return {
            "status": "success",
            "thumbnail_path": thumbnail_path,
            "thumbnail_size": img.size,
        }

    except Exception as exc:
        logger.exception("Failed to generate thumbnail for %s", file_path)
        return {"status": "error", "error": str(exc)}
