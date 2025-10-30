"""
Data models for CRM User Management API
"""
import re
from enum import Enum
from typing import Optional
from pydantic import BaseModel, EmailStr, Field, field_validator


class UserRole(str, Enum):
    """User roles in the CRM system (mapped to Cognito User Groups)"""
    ROOT_ADMIN = "root-admin"
    ADMIN = "admin"
    AGENT = "agent"


class UserResponse(BaseModel):
    """User response model"""
    email: EmailStr
    first_name: str
    last_name: str
    role: UserRole
    enabled: bool = True

    class Config:
        use_enum_values = True

class CreateUserRequest(BaseModel):
    """Request model for creating a new user"""
    email: EmailStr
    first_name: str = Field(..., min_length=1, max_length=100, description="User's first name")
    last_name: str = Field(..., min_length=1, max_length=100, description="User's last name")
    role: UserRole
    temporary_password: str = Field(..., min_length=8)
    
class CreateUserResponse(BaseModel):
    """Response model for successful user creation"""
    message: str
    user: UserResponse
    code: int

class GetUsersRequest(BaseModel):
    """Request model for getting users with optional pagination"""
    limit: Optional[int] = Field(default=60, ge=1, le=60, description="Number of users to return per page (max 60)")
    pagination_token: Optional[str] = Field(default=None, description="Token for pagination to get next page of results")

class GetUsersResponse(BaseModel):
    """Response model for getting users"""
    users: list[UserResponse]
    pagination_token: Optional[str] = Field(default=None, description="Token to fetch next page of results")
    message: str
    code: int

class DisableUserRequest(BaseModel):
    """Request model for disabling a user"""
    email: EmailStr = Field(..., description="Email address of the user to disable")

class DisableUserResponse(BaseModel):
    """Response model for successful user disable"""
    message: str
    email: EmailStr
    code: int

class EnableUserRequest(BaseModel):
    """Request model for enabling a user"""
    email: EmailStr = Field(..., description="Email address of the user to enable")

class EnableUserResponse(BaseModel):
    """Response model for successful user enable"""
    message: str
    email: EmailStr
    code: int

class UpdateUserRequest(BaseModel):
    """Request model for updating user attributes"""
    email: EmailStr = Field(..., description="Email address of the user to update")
    first_name: Optional[str] = Field(None, min_length=1, max_length=100, description="Updated first name")
    last_name: Optional[str] = Field(None, min_length=1, max_length=100, description="Updated last name")
    role: Optional[UserRole] = Field(None, description="Updated role")

    def model_post_init(self, __context):
        """Ensure at least one field is provided for update"""
        if self.first_name is None and self.last_name is None and self.role is None:
            raise ValueError("At least one field (first_name, last_name, or role) must be provided for update")

    class Config:
        use_enum_values = True

class UpdateUserResponse(BaseModel):
    """Response model for successful user update"""
    message: str
    user: UserResponse
    code: int

class ForgotPasswordRequest(BaseModel):
    """Request model for initiating forgot password flow"""
    email: EmailStr = Field(..., description="Email address of the user who forgot their password")

class ForgotPasswordResponse(BaseModel):
    """Response model for forgot password initiation"""
    message: str
    destination: Optional[str] = Field(None, description="Masked email/phone where code was sent")
    code: int

class ConfirmForgotPasswordRequest(BaseModel):
    """Request model for confirming forgot password with verification code"""
    email: EmailStr = Field(..., description="Email address of the user")
    confirmation_code: str = Field(..., min_length=6, max_length=6, description="6-digit verification code sent to user")
    new_password: str = Field(..., min_length=8, description="New password for the user")

class ConfirmForgotPasswordResponse(BaseModel):
    """Response model for successful password reset"""
    message: str
    code: int

class LoginRequest(BaseModel):
    """Request model for user login"""
    email: EmailStr = Field(..., description="User's email address")
    password: str = Field(..., min_length=8, description="User's password")

class LoginResponse(BaseModel):
    """Response model for successful login"""
    message: str
    access_token: str = Field(..., description="JWT access token")
    id_token: str = Field(..., description="JWT ID token")
    refresh_token: str = Field(..., description="Refresh token for getting new access tokens")
    expires_in: int = Field(..., description="Access token expiration time in seconds")
    token_type: str = Field(default="Bearer", description="Token type")
    code: int

class RefreshTokenRequest(BaseModel):
    """Request model for refreshing access token"""
    refresh_token: str = Field(..., description="Refresh token from login")

class RefreshTokenResponse(BaseModel):
    """Response model for token refresh"""
    message: str
    access_token: str = Field(..., description="New JWT access token")
    id_token: str = Field(..., description="New JWT ID token")
    expires_in: int = Field(..., description="Access token expiration time in seconds")
    token_type: str = Field(default="Bearer", description="Token type")
    code: int

class LogoutRequest(BaseModel):
    """Request model for user logout"""
    access_token: str = Field(..., description="Access token to revoke")

class LogoutResponse(BaseModel):
    """Response model for successful logout"""
    message: str
    code: int