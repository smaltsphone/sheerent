from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from app.database import engine
from app.models import models
from app.routers import users, items, rentals, ai, capture, lockers

app = FastAPI()

# 정적 파일 제공
app.mount("/static", StaticFiles(directory="app/static"), name="static")
app.mount("/results", StaticFiles(directory="results"), name="results")

# 테이블 자동 생성
models.Base.metadata.create_all(bind=engine)

# 라우터 등록
app.include_router(users.router)
app.include_router(items.router, prefix="/items")
app.include_router(rentals.router, prefix="/rentals")
app.include_router(ai.router, prefix="/ai")
app.include_router(capture.router)       
app.include_router(lockers.router)

@app.get("/")
def root():
    return {"message": "Sheerent API (MySQL) Running!"}
