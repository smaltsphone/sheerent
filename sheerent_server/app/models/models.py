from sqlalchemy import Column, Integer, String, Text, ForeignKey, Enum, DateTime, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.types import JSON
from datetime import datetime
from app.database import Base
import enum

# 사용자 모델
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50))
    email = Column(String(100), unique=True, index=True)
    phone = Column(String(20))
    password = Column(String(100))
    point = Column(Integer, default=0)
    is_admin = Column(Boolean, default=False)

    items = relationship("Item", back_populates="owner")

# 아이템 상태 ENUM
class ItemStatus(str, enum.Enum):
    registered = "registered"
    rented = "rented"
    returned = "returned"

# 아이템 모델
class Item(Base):
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100))
    description = Column(String(300))
    price_per_day = Column(Integer)
    status = Column(String(20))
    owner_id = Column(Integer, ForeignKey("users.id"))
    images = Column(JSON)
    unit = Column(String(20))
    locker_number = Column(String(20), nullable=True)
    damage_reported = Column(Boolean, default=False)
    has_insurance = Column(Boolean, default=False)

    owner = relationship("User", back_populates="items")
    rentals = relationship("Rental", back_populates="item")

# 대여 모델
class Rental(Base):
    __tablename__ = "rentals"

    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("items.id"))
    borrower_id = Column(Integer, ForeignKey("users.id"))
    start_time = Column(DateTime)
    end_time = Column(DateTime)
    is_returned = Column(Boolean, default=False)
    damage_reported = Column(Boolean, default=False)
    has_insurance = Column(Boolean, default=False)
    deducted_amount = Column(Integer, default=0)
    after_image_url = Column(String(300), nullable=True)

    item = relationship("Item", back_populates="rentals")

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, nullable=True)
    receiver_id = Column(Integer, ForeignKey("users.id"))
    content = Column(Text)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)


