from pydantic import BaseModel, ConfigDict


class UserCreate(BaseModel):
    name: str


class User(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    name: str
