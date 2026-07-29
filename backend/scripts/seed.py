#!/usr/bin/env python3
"""
Database Seeder

Usage:
    python scripts/seed.py --action all
    python scripts/seed.py --action admin
    python scripts/seed.py --action departments
    python scripts/seed.py --action rules
    python scripts/seed.py --action config

Run this after Alembic migrations to populate initial data.
"""

import argparse
import asyncio
import json
import sys
import uuid
from datetime import datetime, timezone

sys.path.insert(0, ".")

from app.config import settings
from app.database import async_session_factory, engine, Base
from app.models import Department, ProductivityRule, SystemConfig, User
from app.services.auth_service import hash_password


async def seed_admin():
    """Seed default admin user."""
    async with async_session_factory() as session:
        # Check if admin already exists
        from sqlalchemy import select

        result = await session.execute(
            select(User).where(User.email == "admin@company.com")
        )
        existing = result.scalar_one_or_none()

        if existing:
            print("✓ Admin user already exists (email: admin@company.com)")
            return

        admin = User(
            id=uuid.uuid4(),
            email="admin@company.com",
            password_hash=hash_password("admin123"),
            full_name="System Administrator",
            role="admin",
            is_active=True,
        )
        session.add(admin)
        await session.commit()
        print("✓ Admin user created (email: admin@company.com, password: admin123)")


async def seed_departments():
    """Seed default departments."""
    async with async_session_factory() as session:
        from sqlalchemy import select

        departments_data = [
            {"name": "IT", "description": "Information Technology Department"},
            {"name": "Human Resources", "description": "HR Department"},
            {"name": "Finance", "description": "Finance and Accounting Department"},
            {"name": "Marketing", "description": "Marketing Department"},
            {"name": "Operations", "description": "Operations Department"},
        ]

        created_count = 0
        for dept_data in departments_data:
            result = await session.execute(
                select(Department).where(Department.name == dept_data["name"])
            )
            existing = result.scalar_one_or_none()
            if not existing:
                dept = Department(
                    id=uuid.uuid4(),
                    name=dept_data["name"],
                    description=dept_data["description"],
                )
                session.add(dept)
                created_count += 1

        if created_count > 0:
            await session.commit()
            print(f"✓ Created {created_count} departments")
        else:
            print("✓ All departments already exist")


async def seed_rules():
    """Seed built-in productivity rules."""
    async with async_session_factory() as session:
        from sqlalchemy import select

        rules_data = [
            # --- Productive Apps ---
            {
                "pattern_type": "app_name",
                "pattern": "Microsoft Visual Studio Code",
                "category": "productive",
            },
            {
                "pattern_type": "app_name",
                "pattern": "IntelliJ IDEA",
                "category": "productive",
            },
            {
                "pattern_type": "app_name",
                "pattern": "Postman",
                "category": "productive",
            },
            {
                "pattern_type": "app_name",
                "pattern": "DBeaver",
                "category": "productive",
            },
            {
                "pattern_type": "app_name",
                "pattern": "Microsoft Excel",
                "category": "productive",
            },
            # --- Productive Domains ---
            {
                "pattern_type": "domain",
                "pattern": "github.com",
                "category": "productive",
            },
            {
                "pattern_type": "domain",
                "pattern": "stackoverflow.com",
                "category": "productive",
            },
            {
                "pattern_type": "domain",
                "pattern": "gitlab.com",
                "category": "productive",
            },
            {
                "pattern_type": "domain",
                "pattern": "docs.python.org",
                "category": "productive",
            },
            # --- Neutral ---
            {"pattern_type": "app_name", "pattern": "Spotify", "category": "neutral"},
            {"pattern_type": "domain", "pattern": "youtube.com", "category": "neutral"},
            {
                "pattern_type": "domain",
                "pattern": "linkedin.com",
                "category": "neutral",
            },
            # --- Non-Productive ---
            {
                "pattern_type": "app_name",
                "pattern": "Netflix",
                "category": "non_productive",
            },
            {
                "pattern_type": "domain",
                "pattern": "instagram.com",
                "category": "non_productive",
            },
            {
                "pattern_type": "domain",
                "pattern": "facebook.com",
                "category": "non_productive",
            },
            {
                "pattern_type": "domain",
                "pattern": "twitter.com",
                "category": "non_productive",
            },
            {
                "pattern_type": "domain",
                "pattern": "tiktok.com",
                "category": "non_productive",
            },
            {
                "pattern_type": "domain",
                "pattern": "reddit.com",
                "category": "non_productive",
            },
        ]

        created_count = 0
        for rule_data in rules_data:
            result = await session.execute(
                select(ProductivityRule).where(
                    ProductivityRule.pattern == rule_data["pattern"],
                    ProductivityRule.pattern_type == rule_data["pattern_type"],
                )
            )
            existing = result.scalar_one_or_none()
            if not existing:
                rule = ProductivityRule(
                    id=uuid.uuid4(),
                    pattern_type=rule_data["pattern_type"],
                    pattern=rule_data["pattern"],
                    category=rule_data["category"],
                    is_builtin=True,
                )
                session.add(rule)
                created_count += 1

        if created_count > 0:
            await session.commit()
            print(f"✓ Created {created_count} productivity rules")
        else:
            print("✓ All productivity rules already exist")


async def seed_config():
    """Seed default system configuration."""
    async with async_session_factory() as session:
        from sqlalchemy import select

        result = await session.execute(select(SystemConfig).where(SystemConfig.id == 1))
        existing = result.scalar_one_or_none()

        if existing:
            print("✓ System config already exists")
            return

        config = SystemConfig(
            id=1,
            screenshot_interval_seconds=300,
            idle_threshold_seconds=300,
            work_start_hour=datetime.strptime("08:00", "%H:%M").time(),
            work_end_hour=datetime.strptime("17:00", "%H:%M").time(),
            work_days=json.dumps([1, 2, 3, 4, 5]),
            screenshot_retention_days=30,
            data_purge_enabled=True,
            max_sessions_per_user=3,
        )
        session.add(config)
        await session.commit()
        print("✓ System config created")


async def main():
    parser = argparse.ArgumentParser(description="Seed database with initial data")
    parser.add_argument(
        "--action",
        type=str,
        choices=["all", "admin", "departments", "rules", "config"],
        default="all",
        help="Seed action to perform",
    )
    args = parser.parse_args()

    action_map = {
        "all": [seed_admin, seed_departments, seed_rules, seed_config],
        "admin": [seed_admin],
        "departments": [seed_departments],
        "rules": [seed_rules],
        "config": [seed_config],
    }

    actions = action_map.get(args.action, [])
    for action in actions:
        try:
            await action()
        except Exception as e:
            print(f"✗ Error running {action.__name__}: {e}")
            raise

    print("\n✅ Seeding complete!")


if __name__ == "__main__":
    asyncio.run(main())
