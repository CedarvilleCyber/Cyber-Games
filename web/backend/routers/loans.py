from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel
from database import get_conn
from jose import jwt # type: ignore
import json
import base64
import os

router = APIRouter()

def get_user_from_token(authorization: str):
    token = authorization.replace("Bearer ", "")
    return jwt.decode(token, os.getenv("JWT_SECRET"), algorithms="HS256")

class LoanRequest(BaseModel):
    principal: str
    annual_rate: str
    years: str

class PreferencesRequest(BaseModel):
    data: str

@router.post("/calculate")
def calculate_loan(req: LoanRequest, authorization: str = Header(...)):
    user = get_user_from_token(authorization)

    try:
        principal = float(req.principal)
        annual_rate = float(req.annual_rate)
        years = float(req.years)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid numeric values")

    output = None
    if not isinstance(principal, (int, float)):
        output = str(principal)
        principal = 0.0
    if not isinstance(annual_rate, (int, float)):
        output = str(annual_rate)
        annual_rate = 5.5
    if not isinstance(years, (int, float)):
        output = str(years)
        years = 30

    monthly_rate = annual_rate / 100 / 12
    n = int(years) * 12

    if monthly_rate == 0:
        monthly_payment = principal / n if n else 0
    else:
        monthly_payment = principal * (monthly_rate * (1 + monthly_rate) ** n) / ((1 + monthly_rate) ** n - 1)

    total_payment = monthly_payment * n
    total_interest = total_payment - principal

    return {
        "principal": output if output else principal,
        "annual_rate": annual_rate,
        "years": years,
        "monthly_payment": round(monthly_payment, 2),
        "total_payment": round(total_payment, 2),
        "total_interest": round(total_interest, 2),
    }

@router.post("/preferences/restore")
def restore_preferences(req: PreferencesRequest, authorization: str = Header(...)):
    user = get_user_from_token(authorization)

    try:
        prefs = json.loads(base64.b64decode(req.data).decode())
        return {"preferences": prefs}
    except Exception as e:
        return {"error": str(e)}
    
@router.get("/preferences/save")
def save_preferences(authorization: str = Header(...)):
    user = get_user_from_token(authorization)

    # Default preferences
    prefs = {
        "default_rate": 5.5,
        "default_years": 30,
        "default_principal": 200000,
        "currency": "USD"
    }
    encoded = base64.b64encode(json.dumps(prefs).encode()).decode()
    return {"data": encoded}
