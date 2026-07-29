"""Screenshot Service — handles file storage, processing, and thumbnail generation."""

import logging
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from uuid import UUID

from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import Screenshot

logger = logging.getLogger(__name__)

# Default upload directory
UPLOAD_DIR = Path("uploads/screenshots")
THUMBNAIL_DIR = Path("uploads/thumbnails")
THUMBNAIL_SIZE = (320, 240)
THUMBNAIL_QUALITY = 60


class ScreenshotService:
    """Service for managing screenshot files and records."""

    @staticmethod
    def ensure_directories():
        """Ensure upload and thumbnail directories exist."""
        UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
        THUMBNAIL_DIR.mkdir(parents=True, exist_ok=True)

    @staticmethod
    def _generate_filename(user_id: UUID, original_name: str) -> str:
        """Generate a unique filename for a screenshot.

        Args:
            user_id: ID of the user.
            original_name: Original file name.

        Returns:
            A unique filename string.
        """
        ext = os.path.splitext(original_name)[1] or ".png"
        unique_id = uuid.uuid4().hex
        return f"{user_id}_{unique_id}{ext}"

    @staticmethod
    def _generate_thumbnail_path(file_path: str) -> str:
        """Generate thumbnail file path from original file path.

        Args:
            file_path: Original screenshot file path.

        Returns:
            Thumbnail file path.
        """
        filename = os.path.basename(file_path)
        name, ext = os.path.splitext(filename)
        return str(THUMBNAIL_DIR / f"{name}_thumb{ext}")

    @staticmethod
    async def save_screenshot(
        db: AsyncSession,
        user_id: UUID,
        file_content: bytes,
        file_name: str,
        captured_at: datetime,
        width: Optional[int] = None,
        height: Optional[int] = None,
    ) -> Screenshot:
        """Save a screenshot file and create a database record.

        Args:
            db: Database session.
            user_id: ID of the user.
            file_content: Raw image bytes.
            file_name: Original file name.
            captured_at: When the screenshot was captured.
            width: Image width (optional).
            height: Image height (optional).

        Returns:
            The created Screenshot record.
        """
        ScreenshotService.ensure_directories()

        # Generate unique filename and save
        filename = ScreenshotService._generate_filename(user_id, file_name)
        file_path = UPLOAD_DIR / filename
        file_bytes = len(file_content)

        with open(file_path, "wb") as f:
            f.write(file_content)

        logger.info(
            "Saved screenshot %s (%d bytes) for user %s",
            filename,
            file_bytes,
            user_id,
        )

        # Generate thumbnail
        thumbnail_path = None
        try:
            thumbnail_path = ScreenshotService._generate_thumbnail_path(str(file_path))
            ScreenshotService.generate_thumbnail(str(file_path), thumbnail_path)
        except Exception as e:
            logger.warning("Failed to generate thumbnail: %s", e)
            thumbnail_path = None

        # Create database record
        now = datetime.now(timezone.utc)
        record = Screenshot(
            id=uuid.uuid4(),
            user_id=user_id,
            captured_at=captured_at,
            file_path=str(file_path),
            file_size_bytes=file_bytes,
            width=width,
            height=height,
            thumbnail_path=thumbnail_path,
            is_deleted=False,
            created_at=now,
        )
        db.add(record)
        await db.flush()
        await db.refresh(record)

        return record

    @staticmethod
    def generate_thumbnail(
        source_path: str,
        output_path: str,
        size: tuple[int, int] = THUMBNAIL_SIZE,
        quality: int = THUMBNAIL_QUALITY,
    ):
        """Generate a thumbnail image from a source image.

        Args:
            source_path: Path to the source image.
            output_path: Path to save the thumbnail.
            size: Thumbnail dimensions (width, height).
            quality: JPEG/WebP quality setting.
        """
        if not os.path.exists(source_path):
            logger.warning("Source image not found: %s", source_path)
            return

        try:
            with Image.open(source_path) as img:
                # Convert to RGB if necessary (for JPEG thumbnail)
                if img.mode in ("RGBA", "P"):
                    img = img.convert("RGB")

                # Create thumbnail maintaining aspect ratio
                img.thumbnail(size, Image.LANCZOS)

                # Save
                thumb_dir = os.path.dirname(output_path)
                os.makedirs(thumb_dir, exist_ok=True)
                img.save(output_path, "JPEG", quality=quality)
                logger.info(
                    "Generated thumbnail: %s (size: %s)",
                    output_path,
                    img.size,
                )
        except Exception as e:
            logger.error("Thumbnail generation failed: %s", e)
            raise

    @staticmethod
    async def mark_deleted(
        db: AsyncSession,
        screenshot_id: UUID,
        user_id: UUID,
    ) -> Optional[Screenshot]:
        """Soft-delete a screenshot record.

        Args:
            db: Database session.
            screenshot_id: ID of the screenshot to delete.
            user_id: ID of the user (for verification).

        Returns:
            The updated Screenshot record, or None if not found.
        """
        from sqlalchemy import select

        result = await db.execute(
            select(Screenshot).where(
                Screenshot.id == screenshot_id,
                Screenshot.user_id == user_id,
            )
        )
        record = result.scalar_one_or_none()

        if record:
            record.is_deleted = True
            await db.flush()
            await db.refresh(record)
            logger.info(
                "Soft-deleted screenshot %s for user %s",
                screenshot_id,
                user_id,
            )

        return record
