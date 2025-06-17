from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from datetime import datetime, timedelta, timezone
import os
import math

from app.database import SessionLocal
from app.models.models import Rental, Item, User, Message, ItemStatus
from app.schemas.schemas import Rental as RentalSchema, RentalCreate
from app.routers.ai import is_item_damaged

router = APIRouter(tags=["rentals"])


# DB 세션 의존성
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# KST 타임존 정의
KST = timezone(timedelta(hours=9))

# ✅ 요금 미리보기
from pydantic import BaseModel


class RentalPreviewRequest(BaseModel):
    item_id: int
    end_time: datetime


@router.post("/preview")
def rental_preview(request: RentalPreviewRequest, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == request.item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    start_time = datetime.now(KST)
    hours = int((request.end_time - start_time).total_seconds() // 3600)
    price_per_hour = item.price_per_day / 24
    total_fee = hours * price_per_hour

    insurance_fee = round(total_fee * 0.05)  # 보험금 5%
    service_fee = round(total_fee * 0.05)  # 수수료 5%
    total = total_fee + insurance_fee + service_fee

    print(f"[Preview] 요청 item_id: {request.item_id}")
    print(f"[Preview] 아이템 조회됨: {item.name}, 가격(1일): {item.price_per_day}")
    print(f"[Preview] 현재시간(start_time): {start_time}")
    print(f"[Preview] 대여 예상 시간(시): {hours}")
    print(f"[Preview] 시간당 가격: {price_per_hour}")
    print(f"[Preview] 기본 대여료: {total_fee}")
    print(f"[Preview] 보험료: {insurance_fee}, 수수료: {service_fee}")
    print(f"[Preview] 총 결제 금액: {total}")

    return {
        "item_name": item.name,
        "hours": hours,
        "price_per_hour": price_per_hour,
        "usage_fee": total_fee,
        "insurance_fee": insurance_fee,
        "service_fee": service_fee,
        "total": total,
    }


# ✅ 1. 대여 등록
@router.post("/", response_model=RentalSchema)
def create_rental(rental: RentalCreate, db: Session = Depends(get_db)):
    db_item = db.query(Item).filter(Item.id == rental.item_id).first()
    if not db_item or db_item.status != "registered":
        raise HTTPException(status_code=400, detail="대여할 수 없는 아이템입니다.")

    if db_item.owner_id == rental.borrower_id:
        raise HTTPException(
            status_code=400, detail="자신이 등록한 물품은 대여할 수 없습니다."
        )

    active_rental = (
        db.query(Rental)
        .filter(Rental.item_id == rental.item_id, Rental.is_returned == False)
        .first()
    )
    if active_rental:
        raise HTTPException(
            status_code=400, detail="해당 아이템은 아직 반납되지 않았습니다."
        )

    start_time = datetime.now(KST)  # 현재 시간 (KST 기준)

    end_time = rental.end_time
    if end_time.tzinfo is None or end_time.tzinfo.utcoffset(end_time) is None:
        end_time = end_time.replace(tzinfo=KST)

    if end_time <= start_time:
        raise HTTPException(
            status_code=400, detail="종료시간은 시작시간보다 나중이어야 합니다."
        )

    hours = max(1, math.ceil((end_time - start_time).total_seconds() / 3600))
    # 단위(per_day or per_hour)에 따라 시간당 가격 계산
    if db_item.unit == "per_day":
        price_per_hour = db_item.price_per_day / 24
    else:
        price_per_hour = db_item.price_per_day  # per_hour일 경우

    rental_price = price_per_hour * hours
    insurance_fee = round(rental_price * 0.05) if rental.has_insurance else 0
    service_fee = round(rental_price * 0.05)  # 수수료 5%
    total_pay = rental_price + insurance_fee + service_fee

    db_user = db.query(User).filter(User.id == rental.borrower_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    if db_user.point < total_pay:
        raise HTTPException(status_code=400, detail="포인트가 부족합니다.")

    db_user.point -= int(total_pay)
    db_item.status = "rented"

    new_rental = Rental(
        item_id=rental.item_id,
        borrower_id=rental.borrower_id,
        start_time=start_time,
        end_time=end_time,
        is_returned=False,
        has_insurance=rental.has_insurance,
        damage_reported=False,
        deducted_amount=0,
    )

    db.add(new_rental)
    db.commit()
    db.refresh(new_rental)

    return new_rental


# ✅ 2. 전체 대여 조회 + 필터링
@router.get("/", response_model=List[RentalSchema])
def get_rentals(
    is_returned: Optional[bool] = Query(None),
    borrower_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    
):
    query = db.query(Rental).options(joinedload(Rental.item))
    if is_returned is not None:
        query = query.filter(Rental.is_returned == is_returned)
    if borrower_id is not None:
        query = query.filter(Rental.borrower_id == borrower_id)
    return query.all()


# ✅ 3. 반납 처리 + AI 분석 + 보증금 정산
@router.put("/{rental_id}/return", response_model=RentalSchema)
async def return_rental(
    rental_id: int,
    user_id: int = Form(...),
    item_id: int = Form(...),
    after_file: UploadFile = File(...),
    has_insurance: Optional[str] = Form(None),  # ✅ 추가됨
    db: Session = Depends(get_db),
):
    rental = db.query(Rental).filter(Rental.id == rental_id).first()
    if not rental:
        raise HTTPException(status_code=404, detail="대여 기록을 찾을 수 없습니다.")
    if rental.borrower_id != user_id:
        raise HTTPException(status_code=403, detail="본인만 반납할 수 있습니다.")
    if rental.is_returned:
        raise HTTPException(status_code=400, detail="이미 반납된 대여입니다.")

    user = db.query(User).filter(User.id == rental.borrower_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    db_item = db.query(Item).filter(Item.id == rental.item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="아이템을 찾을 수 없습니다.")

    before_img = get_before_image(item_id, db)

    rental_key = f"{item_id}_{rental_id}_{rental.start_time.strftime('%Y%m%d')}"

    rental_dir = f"results/{rental_key}/after"
    os.makedirs(rental_dir, exist_ok=True)
    after_path = os.path.join(rental_dir, "after.jpg")
    with open(after_path, "wb") as f:
        f.write(await after_file.read())

    _, damage_detected, damage_info = is_item_damaged(
        item_id, rental_id, before_img, after_path
    )

    # ✅ 문자열 처리: "true" -> True
    insurance_checked = has_insurance == "true"

    # 연체 계산
    now = datetime.now(KST)
    end_time = rental.end_time
    if end_time.tzinfo is None or end_time.tzinfo.utcoffset(end_time) is None:
        end_time = end_time.replace(tzinfo=KST)
    late_hours = 0
    late_fee = 0
    if now > end_time:
        late_hours = math.ceil((now - end_time).total_seconds() / 3600)
        late_fee = late_hours * 10000

    # ✅ 보험 여부 반영한 파손 감지 비용
    damage_fee = 30000 if damage_detected and insurance_checked else 0
    total_deduction = late_fee + damage_fee

    if user.point < total_deduction:
        raise HTTPException(status_code=400, detail="포인트가 부족합니다.")

    user.point -= total_deduction

    rental.is_returned = True
    rental.damage_reported = damage_detected
    rental.deducted_amount = total_deduction
    db_item.damage_reported = damage_detected
    db_item.status = ItemStatus.returned if damage_detected else ItemStatus.registered
    if damage_detected:
        insurance_text = "가입됨" if insurance_checked else "미가입"
        message = f"[파손 감지] '{db_item.name}'이(가) 반납 시 파손되었습니다.\n보험 가입 여부: {insurance_text}"

        db.add(Message(
            sender_id=None,
            receiver_id=db_item.owner_id,
            content=message,
            created_at=datetime.now(KST)
        ))

    rental.after_image_url = f"/results/{rental_key}/after/after.jpg".replace("\\", "/")   
    db.commit()
    db.refresh(rental)

    return JSONResponse(content={
        "id": rental.id,
        "item_id": rental.item_id,
        "borrower_id": rental.borrower_id,
        "start_time": rental.start_time.isoformat(),
        "end_time": rental.end_time.isoformat(),
        "is_returned": rental.is_returned,
        "damage_reported": rental.damage_reported,
        "deducted_amount": rental.deducted_amount,
        "item": {
            "id": db_item.id,
            "name": db_item.name,
            "description": db_item.description,
            "price_per_day": db_item.price_per_day,
            "status": db_item.status,
            "images": db_item.images
        },
        "damage_info": damage_info,
        "late_hours": late_hours,
        "late_fee": late_fee,
        "damage_fee": damage_fee,
        "total_deducted": total_deduction,
        "user_point_after": user.point,
        "has_insurance": insurance_checked,  # ✅ 클라에 다시 전달
        "after_image_url": f"/results/{rental_key}/after/after.jpg".replace("\\", "/")
    })



# 보관 이미지 가져오기 함수
def get_before_image(item_id: int, db: Session):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item or not item.images:
        raise HTTPException(status_code=404, detail="아이템 이미지가 없습니다.")
    relative_path = item.images[0].lstrip("/")
    absolute_path = os.path.join("app", relative_path)
    if not os.path.isfile(absolute_path):
        raise HTTPException(
            status_code=404, detail="비포 이미지 파일이 존재하지 않습니다."
        )
    return absolute_path


# ✅ 4. 대여 상세 조회
@router.get("/{rental_id}", response_model=RentalSchema)
def get_rental_detail(rental_id: int, db: Session = Depends(get_db)):
    rental = db.query(Rental).filter(Rental.id == rental_id).first()
    if not rental:
        raise HTTPException(
            status_code=404, detail="해당 대여 기록을 찾을 수 없습니다."
        )
    
    return rental


# ✅ 5. 사용자별 대여 통계
@router.get("/stats/{user_id}")
def get_user_rental_stats(user_id: int, db: Session = Depends(get_db)):
    total = db.query(Rental).filter(Rental.borrower_id == user_id).count()
    returned = (
        db.query(Rental)
        .filter(Rental.borrower_id == user_id, Rental.is_returned == True)
        .count()
    )
    not_returned = (
        db.query(Rental)
        .filter(Rental.borrower_id == user_id, Rental.is_returned == False)
        .count()
    )
    return {
        "user_id": user_id,
        "total_rentals": total,
        "returned": returned,
        "not_returned": not_returned,
    }


# ✅ 6. 대여 연장
@router.put("/{rental_id}/extend")
def extend_rental(
    rental_id: int,
    hours: Optional[int] = Query(None),
    days: Optional[int] = Query(None),
    has_insurance: bool = Query(False),  # ✅ 쿼리 파라미터 명시적으로 받기
    db: Session = Depends(get_db),
):
    rental = db.query(Rental).filter(Rental.id == rental_id).first()
    if not rental:
        raise HTTPException(status_code=404, detail="대여 기록을 찾을 수 없습니다.")
    if rental.is_returned:
        raise HTTPException(status_code=400, detail="이미 반납된 대여입니다.")

    item = db.query(Item).filter(Item.id == rental.item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="아이템을 찾을 수 없습니다.")

    user = db.query(User).filter(User.id == rental.borrower_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    # 단가 계산
    if item.unit == "per_day":
        price_per_hour = item.price_per_day / 24
    else:
        price_per_hour = item.price_per_day

    if days is not None:
        if days <= 0:
            raise HTTPException(status_code=400, detail="연장 기간은 1 이상이어야 합니다.")
        extension_hours = days * 24
    elif hours is not None:
        if hours <= 0:
            raise HTTPException(status_code=400, detail="연장 시간은 1 이상이어야 합니다.")
        extension_hours = hours
    else:
        raise HTTPException(status_code=400, detail="days 또는 hours 중 하나는 제공되어야 합니다.")

    usage_fee = price_per_hour * extension_hours
    insurance_fee = round(usage_fee * 0.05) if has_insurance else 0  # ✅ 여기 변경
    service_fee = round(usage_fee * 0.05)
    total_cost = int(usage_fee + insurance_fee + service_fee)

    if user.point < total_cost:
        raise HTTPException(status_code=400, detail="포인트가 부족합니다.")

    user.point -= total_cost
    rental.end_time += timedelta(hours=extension_hours)
    rental.has_insurance = has_insurance  # ✅ rental에도 반영해주는 게 좋음

    db.commit()
    db.refresh(rental)
    db.refresh(user)

    return {
        "rental_id": rental.id,
        "extended_hours": extension_hours,
        "deducted_point": total_cost,
        "user_point": user.point,
        "new_end_time": rental.end_time.isoformat(),
        "has_insurance": rental.has_insurance,
    }

# ✅ 연체료 결제
@router.post("/{rental_id}/pay_late_fee")
def pay_late_fee(rental_id: int, db: Session = Depends(get_db)):
    rental = db.query(Rental).filter(Rental.id == rental_id).first()
    if not rental:
        raise HTTPException(status_code=404, detail="대여 기록을 찾을 수 없습니다.")
    if not rental.is_returned:
        raise HTTPException(status_code=400, detail="반납되지 않은 대여입니다.")

    item = db.query(Item).filter(Item.id == rental.item_id).first()
    user = db.query(User).filter(User.id == rental.borrower_id).first()
    if not item or not user:
        raise HTTPException(status_code=404, detail="대여 정보가 올바르지 않습니다.")

    now = datetime.now(KST)
    end_time = rental.end_time
    if end_time.tzinfo is None or end_time.tzinfo.utcoffset(end_time) is None:
        end_time = end_time.replace(tzinfo=KST)
    if now <= end_time:
        return {"deducted_points": 0, "user_point": user.point, "late_hours": 0}

    late_hours = math.ceil((now - end_time).total_seconds() / 3600)
    if item.unit == "per_day":
        price_per_hour = item.price_per_day / 24
    else:
        price_per_hour = item.price_per_day
    late_fee = late_hours * price_per_hour + 10000
    if rental.has_insurance:
        late_fee *= 0.95
    late_fee = int(late_fee)

    if user.point < late_fee:
        raise HTTPException(status_code=400, detail="포인트가 부족합니다.")

    user.point -= late_fee
    db.commit()
    db.refresh(user)

    return {
        "deducted_points": late_fee,
        "user_point": user.point,
        "late_hours": late_hours,
    }

@router.get("/messages/{user_id}")
def get_messages(user_id: int, db: Session = Depends(get_db)):
    messages = db.query(Message).filter(Message.receiver_id == user_id).order_by(Message.created_at.desc()).all()
    return [
        {
            "id": msg.id,
            "content": msg.content,
            "created_at": msg.created_at.isoformat()
        }
        for msg in messages
    ]


@router.delete("/{rental_id}")
def delete_rental(rental_id: int, db: Session = Depends(get_db)):
    rental = db.query(Rental).filter(Rental.id == rental_id).first()
    if not rental:
        raise HTTPException(status_code=404, detail="Rental not found")

    db.delete(rental)
    db.commit()
    return {"message": "Rental deleted successfully"}


