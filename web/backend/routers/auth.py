from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import get_conn
import bcrypt
from jose import jwt # type: ignore
import os

router = APIRouter()

class LoginRequest(BaseModel):
    username: str
    password: str

class RegisterRequest(BaseModel):
    username: str
    password: str
    email: str
    full_name: str
    is_admin: bool = False

@router.post("/login")
def login(req: LoginRequest):
    conn = get_conn()
    cur = conn.cursor()

    query = f"SELECT id, username, password, is_admin FROM users WHERE username = '{req.username}'"
    cur.execute(query)
    user = cur.fetchone()
    cur.close()
    conn.close()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid username")

    if not bcrypt.checkpw(req.password.encode(), user[2].encode()):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = jwt.encode(
        {"sub": str(user[0]), "username": user[1], "is_admin": user[3]},
        os.getenv("JWT_SECRET"),
        algorithm="HS256"
    )
    return {"access_token": token, "token_type": "bearer"}

@router.post("/register")
def register(req: RegisterRequest):
    conn = get_conn()
    cur = conn.cursor()
    hashed = bcrypt.hashpw(req.password.encode(), bcrypt.gensalt()).decode()
    try:
        cur.execute("""
            INSERT INTO users (username, password, email, full_name, is_admin)
            VALUES (%s, %s, %s, %s, %s) RETURNING id
        """, (req.username, hashed, req.email, req.full_name, req.is_admin))
        user_id = cur.fetchone()[0]

        import random
        acc_num = f"ACC{random.randint(1000000, 9999999)}"
        cur.execute("""
            INSERT INTO accounts (user_id, account_number, balance)
            VALUES (%s, %s, %s)
        """, (user_id, acc_num, 1000.00))

        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()

    return {"message": "Account created successfully"}