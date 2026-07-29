from celery import Celery

celery_app = Celery(
    "monitoring",
    broker="redis://redis:6379/0",
    backend="redis://redis:6379/1",
    include=[
        "tasks.screenshot_compress",
        "tasks.score_calculator",
        "tasks.report_generator",
        "tasks.data_retention",
    ],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Asia/Jakarta",
    enable_utc=True,
    task_track_started=True,
    task_soft_time_limit=300,
    task_time_limit=600,
)
