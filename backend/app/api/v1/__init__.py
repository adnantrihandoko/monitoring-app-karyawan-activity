from fastapi import APIRouter
from app.api.v1.auth import router as auth_router
from app.api.v1.activities import router as activities_router

api_router = APIRouter()
api_router.include_router(auth_router, prefix="/auth", tags=["Authentication"])
api_router.include_router(activities_router, prefix="", tags=["Activities"])
