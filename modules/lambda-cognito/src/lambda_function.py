import os
from typing import Dict, Any
from botocore.exceptions import ClientError
from pydantic import ValidationError


from aws_lambda_powertools import Logger, Tracer
from aws_lambda_powertools.event_handler import APIGatewayRestResolver
from aws_lambda_powertools.logging import correlation_paths
from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.event_handler.exceptions import (
    BadRequestError,
    InternalServerError,
    NotFoundError,
    UnauthorizedError,
    ForbiddenError
)


from models import (
    CreateUserRequest, CreateUserResponse,
    GetUsersRequest, GetUsersResponse,
    DisableUserRequest, DisableUserResponse,
    EnableUserRequest, EnableUserResponse,
    UpdateUserRequest, UpdateUserResponse,
    ForgotPasswordRequest, ForgotPasswordResponse,
    ConfirmForgotPasswordRequest, ConfirmForgotPasswordResponse,
    LoginRequest, LoginResponse,
    RespondToChallengeRequest, RespondToChallengeResponse,
    RefreshTokenRequest, RefreshTokenResponse,
    LogoutRequest, LogoutResponse
)
from cognito_service import CognitoService


# Initialize Powertools utilities
tracer = Tracer(service="auth-service")
logger = Logger(service="auth-service")
app = APIGatewayRestResolver()


# Authorization decorator that checks user roles from JWT claims
def require_role(allowed_roles):
    """
    Decorator to require specific roles for API Gateway endpoints
    Extracts user claims from Cognito JWT token validated by API Gateway
    """
    def decorator(func):
        def wrapper(*args, **kwargs):
            try:
                # Get user claims from API Gateway authorizer context
                user = get_current_user()

                if not user:
                    raise UnauthorizedError("Authentication required")

                # Extract role from custom claims (adjust based on your Cognito setup)
                user_role = user.get('custom:role') or user.get('cognito:groups', [])

                # Check if user has required role
                if isinstance(user_role, list):
                    has_permission = any(role in allowed_roles for role in user_role)
                else:
                    has_permission = user_role in allowed_roles

                if not has_permission:
                    logger.warning(f"Access denied - User role: {user_role}, Required: {allowed_roles}")
                    raise ForbiddenError(f"Insufficient permissions. Required role: {allowed_roles}")

                return func(*args, **kwargs)

            except (UnauthorizedError, ForbiddenError):
                raise
            except Exception as e:
                logger.error(f"Authorization error: {str(e)}")
                raise UnauthorizedError("Authorization failed")

        wrapper.__name__ = func.__name__
        return wrapper
    return decorator


def get_current_user():
    """
    Get current user from API Gateway authorizer context
    When Cognito User Pool Authorizer is enabled, claims are available in request context

    Returns:
        dict: User claims from JWT token, or None if not authenticated
    """
    try:
        # API Gateway puts Cognito claims in authorizer context
        authorizer = app.current_event.request_context.authorizer

        if not authorizer or not authorizer.get('claims'):
            return None

        claims = authorizer.get('claims', {})

        # Common Cognito JWT claims:
        # - sub: User's unique ID
        # - email: User's email
        # - cognito:username: Username
        # - cognito:groups: User groups (if using Cognito groups)
        # - custom:role: Custom attribute for roles

        return {
            'sub': claims.get('sub'),
            'username': claims.get('cognito:username'),
            'email': claims.get('email'),
            'groups': claims.get('cognito:groups', '').split(',') if claims.get('cognito:groups') else [],
            'custom:role': claims.get('custom:role'),
            **claims  # Include all other claims
        }
    except Exception as e:
        logger.error(f"Error extracting user from context: {str(e)}")
        return None


# Initialize Cognito service
cognito_service = CognitoService()


@app.get("/health")
@tracer.capture_method
def health_check():
    """Health check endpoint"""
    return {
        'status': 'healthy',
        'service': 'auth-lambda-service',
        'version': '1.0.0'
    }, 200


@app.post("/api/users")
@require_role(['root-admin'])
@tracer.capture_method
def create_user() -> tuple[dict, int]:
    """
    Create a new user in the CRM system

    Authorization: Requires 'root-admin' role

    Returns:
        tuple[dict, int]: Response body and HTTP status code (201)
    """
    try:
        # Parse and validate request body
        body = app.current_event.json_body
        
        if not body:
            raise BadRequestError("Request body is required")
        
        # can throw ValidationError
        request = CreateUserRequest(**body)

        logger.info("Creating user", extra={
            "endpoint": "POST /api/users",
            "action": "create_user",
            "email": request.email,
            "role": request.role
        })
        
        # Create user in Cognito
        cognito_user = cognito_service.create_user(request)

        logger.info("User created successfully", extra={
            "endpoint": "POST /api/users",
            "action": "create_user",
            "email": request.email,
            "status": "success"
        })

        # Map Cognito user to UserResponse
        user_response = cognito_service._map_user_response(cognito_user)

        # Return validated response using CreateUserResponse model
        response = CreateUserResponse(
            message="User created successfully",
            user=user_response,
            code=201
        )

        return response.model_dump(), 201

    # catch ValidationError from pydantic model parsing
    except ValidationError as e:
        logger.warning("Validation error", extra={
            "endpoint": "POST /api/users",
            "action": "create_user",
            "error_type": "validation_error",
            "errors": e.errors()
        })
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request data: {errors}")
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        
        if error_code == 'UsernameExistsException':
            logger.warning(f"Attempt to create duplicate user: {body.get('username')}")
            raise BadRequestError(f"Username already exists")
        elif error_code == 'InvalidPasswordException':
            logger.warning(f"Invalid password provided for user: {body.get('username')}")
            raise BadRequestError(f"Password does not meet requirements: {error_message}")
        elif error_code == 'InvalidParameterException':
            logger.warning(f"Invalid parameter: {error_message}")
            raise BadRequestError(f"Invalid parameter: {error_message}")
        elif error_code == 'UserLambdaValidationException':
            logger.error(f"Lambda validation error: {error_message}")
            raise InternalServerError("User validation failed")
        else:
            logger.error(f"Cognito error ({error_code}): {error_message}")
            raise InternalServerError(f"Failed to create user. Please try again later.")
            
    except BadRequestError:
        # Re-raise BadRequestError as-is
        raise
        
    except Exception as e:
        logger.exception("Unexpected error creating user")
        raise InternalServerError(f"An unexpected error occurred while creating the user")


@app.get("/api/users")
@tracer.capture_method
def get_users() -> tuple[dict, int]:
    """
    Get all users from the CRM system with optional pagination

    Query Parameters:
        limit (optional): Number of users to return (default: 60, max: 60)
        pagination_token (optional): Token for fetching next page of results

    Returns:
        tuple[dict, int]: Response body with users list and HTTP status code (200)
    """
    try:
        # Get query parameters
        query_params = app.current_event.query_string_parameters or {}

        # Parse limit parameter
        limit = query_params.get('limit', 60)
        try:
            limit = int(limit)
        except (ValueError, TypeError):
            raise BadRequestError("Invalid limit parameter. Must be an integer.")

        # Get pagination token
        pagination_token = query_params.get('pagination_token')

        # Create request object
        request = GetUsersRequest(
            limit=limit,
            pagination_token=pagination_token
        )

        logger.info("Fetching users", extra={
            "endpoint": "GET /api/users",
            "action": "get_users",
            "limit": request.limit,
            "has_pagination_token": bool(pagination_token)
        })

        # Get users from Cognito
        result = cognito_service.get_users(request)

        logger.info("Users retrieved successfully", extra={
            "endpoint": "GET /api/users",
            "action": "get_users",
            "user_count": len(result.get('Users', [])),
            "has_more_results": bool(result.get('PaginationToken'))
        })

        # Build response using GetUsersResponse model
        response = GetUsersResponse(
            users=result['Users'],
            pagination_token=result.get('PaginationToken'),
            message="Users retrieved successfully",
            code=200
        )

        return response.model_dump(exclude_none=True), 200

    except ValidationError as e:
        logger.warning(f"Validation error for get users: {e.errors()}")
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request parameters: {errors}")

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        logger.error(f"Cognito error ({error_code}): {error_message}")
        raise InternalServerError(f"Failed to retrieve users. Please try again later.")

    except BadRequestError:
        # Re-raise BadRequestError as-is
        raise

    except Exception as e:
        logger.exception("Unexpected error retrieving users")
        raise InternalServerError(f"An unexpected error occurred while retrieving users")


@app.post("/api/users/disable")
@tracer.capture_method
def disable_user() -> tuple[dict, int]:
    """
    Disable a user in the CRM system

    Request Body:
        email: Email address of the user to disable

    Returns:
        tuple[dict, int]: Response body with success message and HTTP status code (200)
    """
    try:
        # Parse and validate request body
        body = app.current_event.json_body

        if not body:
            raise BadRequestError("Request body is required")

        # Validate request
        request = DisableUserRequest(**body)

        logger.info(f"Disabling user: {request.email}")

        # Disable user in Cognito
        result = cognito_service.disable_user(request.email)

        logger.info(f"User {request.email} disabled successfully")

        # Build response
        response = DisableUserResponse(
            message=f"User {request.email} disabled successfully",
            email=request.email,
            code=200
        )

        return response.model_dump(), 200

    except ValidationError as e:
        logger.warning(f"Validation error for disable user: {e.errors()}")
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request data: {errors}")

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']

        if error_code == 'UserNotFoundException':
            logger.warning(f"Attempt to disable non-existent user: {body.get('email')}")
            raise NotFoundError(f"User not found")
        else:
            logger.error(f"Cognito error ({error_code}): {error_message}")
            raise InternalServerError(f"Failed to disable user. Please try again later.")

    except BadRequestError:
        # Re-raise BadRequestError as-is
        raise

    except NotFoundError:
        # Re-raise NotFoundError as-is
        raise

    except Exception as e:
        logger.exception("Unexpected error disabling user")
        raise InternalServerError(f"An unexpected error occurred while disabling the user")


@app.post("/api/users/enable")
@tracer.capture_method
def enable_user() -> tuple[dict, int]:
    """
    Enable a user in the CRM system

    Request Body:
        email: Email address of the user to enable

    Returns:
        tuple[dict, int]: Response body with success message and HTTP status code (200)
    """
    try:
        # Parse and validate request body
        body = app.current_event.json_body

        if not body:
            raise BadRequestError("Request body is required")

        # Validate request
        request = EnableUserRequest(**body)

        logger.info(f"Enabling user: {request.email}")

        # Enable user in Cognito
        result = cognito_service.enable_user(request.email)

        logger.info(f"User {request.email} enabled successfully")

        # Build response
        response = EnableUserResponse(
            message=f"User {request.email} enabled successfully",
            email=request.email,
            code=200
        )

        return response.model_dump(), 200

    except ValidationError as e:
        logger.warning(f"Validation error for enable user: {e.errors()}")
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request data: {errors}")

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']

        if error_code == 'UserNotFoundException':
            logger.warning(f"Attempt to enable non-existent user: {body.get('email')}")
            raise NotFoundError(f"User not found")
        else:
            logger.error(f"Cognito error ({error_code}): {error_message}")
            raise InternalServerError(f"Failed to enable user. Please try again later.")

    except BadRequestError:
        # Re-raise BadRequestError as-is
        raise

    except NotFoundError:
        # Re-raise NotFoundError as-is
        raise

    except Exception as e:
        logger.exception("Unexpected error enabling user")
        raise InternalServerError(f"An unexpected error occurred while enabling the user")


@app.put("/api/users")
@tracer.capture_method
def update_user() -> tuple[dict, int]:
    """
    Update user attributes in the CRM system

    Request Body:
        email: Email address of the user to update
        first_name: Updated first name (optional)
        last_name: Updated last name (optional)
        role: Updated role (optional)

    Returns:
        tuple[dict, int]: Response body with updated user information and HTTP status code (200)
    """
    try:
        # Parse and validate request body
        body = app.current_event.json_body

        if not body:
            raise BadRequestError("Request body is required")

        # Validate request
        request = UpdateUserRequest(**body)

        logger.info(f"Updating user: {request.email}")

        # Update user attributes in Cognito
        result = cognito_service.update_user_attributes(
            email=request.email,
            first_name=request.first_name,
            last_name=request.last_name,
            role=request.role if request.role else None
        )

        logger.info(f"User {request.email} updated successfully")

        # Build response
        response = UpdateUserResponse(
            message=f"User {request.email} updated successfully",
            user=result['user'],
            code=200
        )

        return response.model_dump(), 200

    except ValidationError as e:
        logger.warning(f"Validation error for update user: {e.errors()}")
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request data: {errors}")

    except ValueError as e:
        # Handle custom validation errors from models
        logger.warning(f"Validation error for update user: {str(e)}")
        raise BadRequestError(str(e))

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']

        if error_code == 'UserNotFoundException':
            logger.warning(f"Attempt to update non-existent user: {body.get('email')}")
            raise NotFoundError(f"User not found")
        else:
            logger.error(f"Cognito error ({error_code}): {error_message}")
            raise InternalServerError(f"Failed to update user. Please try again later.")

    except BadRequestError:
        # Re-raise BadRequestError as-is
        raise

    except NotFoundError:
        # Re-raise NotFoundError as-is
        raise

    except Exception as e:
        logger.exception("Unexpected error updating user")
        raise InternalServerError(f"An unexpected error occurred while updating the user")


@app.post("/api/auth/forgot-password")
@tracer.capture_method
def forgot_password() -> tuple[dict, int]:
    """
    Initiate forgot password flow

    Request Body:
        email: Email address of the user who forgot their password

    Returns:
        tuple[dict, int]: Response with code delivery details and HTTP status code (200)
    """
    try:
        # Parse and validate request body
        body = app.current_event.json_body

        if not body:
            raise BadRequestError("Request body is required")

        # Validate request
        request = ForgotPasswordRequest(**body)

        logger.info(f"Initiating forgot password for: {request.email}")

        # Initiate forgot password flow in Cognito
        result = cognito_service.forgot_password(request.email)

        logger.info(f"Forgot password initiated for {request.email}")

        # Build response
        response = ForgotPasswordResponse(
            message=f"Password reset code sent to {result.get('destination', 'your registered email')}",
            destination=result.get('destination'),
            code=200
        )

        return response.model_dump(exclude_none=True), 200

    except ValidationError as e:
        logger.warning(f"Validation error for forgot password: {e.errors()}")
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request data: {errors}")

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']

        if error_code == 'UserNotFoundException':
            # For security, don't reveal if user exists or not
            logger.warning(f"Forgot password attempt for non-existent user: {body.get('email')}")
            # Return success anyway to prevent user enumeration
            response = ForgotPasswordResponse(
                message="If an account exists, a password reset code has been sent",
                code=200
            )
            return response.model_dump(exclude_none=True), 200
        elif error_code == 'LimitExceededException':
            logger.warning(f"Rate limit exceeded for forgot password: {body.get('email')}")
            raise BadRequestError("Too many requests. Please try again later.")
        elif error_code == 'InvalidParameterException':
            logger.warning(f"Invalid parameter for forgot password: {error_message}")
            raise BadRequestError(f"Invalid request: {error_message}")
        else:
            logger.error(f"Cognito error ({error_code}): {error_message}")
            raise InternalServerError("Failed to process password reset request. Please try again later.")

    except BadRequestError:
        # Re-raise BadRequestError as-is
        raise

    except Exception as e:
        logger.exception("Unexpected error initiating forgot password")
        raise InternalServerError("An unexpected error occurred while processing password reset request")


@app.post("/api/auth/confirm-forgot-password")
@tracer.capture_method
def confirm_forgot_password() -> tuple[dict, int]:
    """
    Confirm forgot password with verification code and set new password

    Request Body:
        email: Email address of the user
        confirmation_code: 6-digit verification code
        new_password: New password

    Returns:
        tuple[dict, int]: Response with success message and HTTP status code (200)
    """
    try:
        # Parse and validate request body
        body = app.current_event.json_body

        if not body:
            raise BadRequestError("Request body is required")

        # Validate request
        request = ConfirmForgotPasswordRequest(**body)

        logger.info(f"Confirming forgot password for: {request.email}")

        # Confirm forgot password in Cognito
        result = cognito_service.confirm_forgot_password(
            email=request.email,
            confirmation_code=request.confirmation_code,
            new_password=request.new_password
        )

        logger.info(f"Password reset confirmed for {request.email}")

        # Build response
        response = ConfirmForgotPasswordResponse(
            message="Password has been reset successfully",
            code=200
        )

        return response.model_dump(), 200

    except ValidationError as e:
        logger.warning(f"Validation error for confirm forgot password: {e.errors()}")
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request data: {errors}")

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']

        if error_code == 'CodeMismatchException':
            logger.warning(f"Invalid verification code for {body.get('email')}")
            raise BadRequestError("Invalid verification code. Please check and try again.")
        elif error_code == 'ExpiredCodeException':
            logger.warning(f"Expired verification code for {body.get('email')}")
            raise BadRequestError("Verification code has expired. Please request a new code.")
        elif error_code == 'UserNotFoundException':
            logger.warning(f"User not found for confirm forgot password: {body.get('email')}")
            raise NotFoundError("User not found")
        elif error_code == 'InvalidPasswordException':
            logger.warning(f"Invalid password for {body.get('email')}: {error_message}")
            raise BadRequestError(f"Password does not meet requirements: {error_message}")
        elif error_code == 'LimitExceededException':
            logger.warning(f"Rate limit exceeded for confirm forgot password: {body.get('email')}")
            raise BadRequestError("Too many attempts. Please try again later.")
        else:
            logger.error(f"Cognito error ({error_code}): {error_message}")
            raise InternalServerError("Failed to reset password. Please try again later.")

    except BadRequestError:
        # Re-raise BadRequestError as-is
        raise

    except NotFoundError:
        # Re-raise NotFoundError as-is
        raise

    except Exception as e:
        logger.exception("Unexpected error confirming forgot password")
        raise InternalServerError("An unexpected error occurred while resetting password")


@app.post("/api/auth/login")
@tracer.capture_method
def login() -> tuple[dict, int]:
    """
    Authenticate user with email and password

    Request Body:
        email: User's email address
        password: User's password

    Returns:
        tuple[dict, int]: Response with authentication tokens and HTTP status code (200)
    """
    try:
        # Parse and validate request body
        body = app.current_event.json_body

        if not body:
            raise BadRequestError("Request body is required")

        # Validate request
        request = LoginRequest(**body)

        logger.info("Login attempt", extra={
            "endpoint": "POST /api/auth/login",
            "action": "login",
            "email": request.email
        })

        # Authenticate user in Cognito
        result = cognito_service.login(request.email, request.password)

        # Check if challenge is required
        if result.get('challenge'):
            logger.info("Authentication challenge required", extra={
                "endpoint": "POST /api/auth/login",
                "action": "login",
                "email": request.email,
                "challenge": result.get('challenge')
            })
            # Return challenge details so frontend can handle it
            response = LoginResponse(
                message=f"Authentication challenge required: {result.get('challenge')}",
                challenge=result.get('challenge'),
                session=result.get('session'),
                challenge_parameters=result.get('challenge_parameters', {}),
                code=200
            )
            return response.model_dump(exclude_none=True), 200

        logger.info("Login successful", extra={
            "endpoint": "POST /api/auth/login",
            "action": "login",
            "email": request.email,
            "status": "success"
        })

        # Build response
        response = LoginResponse(
            message="Login successful",
            access_token=result['access_token'],
            id_token=result['id_token'],
            refresh_token=result['refresh_token'],
            expires_in=result['expires_in'],
            token_type=result['token_type'],
            code=200
        )

        return response.model_dump(), 200

    except ValidationError as e:
        logger.warning(f"Validation error for login: {e.errors()}")
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request data: {errors}")

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']

        if error_code == 'NotAuthorizedException':
            logger.warning("Failed login attempt", extra={
                "endpoint": "POST /api/auth/login",
                "action": "login",
                "email": body.get('email'),
                "error_code": error_code,
                "reason": "invalid_credentials"
            })
            raise UnauthorizedError("Invalid email or password")
        elif error_code == 'UserNotFoundException':
            logger.warning("Failed login attempt", extra={
                "endpoint": "POST /api/auth/login",
                "action": "login",
                "email": body.get('email'),
                "error_code": error_code,
                "reason": "user_not_found"
            })
            # Don't reveal user doesn't exist - same error as wrong password
            raise UnauthorizedError("Invalid email or password")
        elif error_code == 'UserNotConfirmedException':
            logger.warning(f"Login attempt for unconfirmed user: {body.get('email')}")
            raise BadRequestError("User account is not confirmed. Please check your email for verification.")
        elif error_code == 'PasswordResetRequiredException':
            logger.warning(f"Password reset required for user: {body.get('email')}")
            raise BadRequestError("Password reset required. Please use forgot password flow.")
        elif error_code == 'TooManyRequestsException':
            logger.warning(f"Too many login attempts for: {body.get('email')}")
            raise BadRequestError("Too many login attempts. Please try again later.")
        else:
            logger.error(f"Cognito error ({error_code}): {error_message}")
            raise InternalServerError("Failed to authenticate. Please try again later.")

    except BadRequestError:
        # Re-raise BadRequestError as-is
        raise

    except UnauthorizedError:
        # Re-raise UnauthorizedError as-is
        raise

    except Exception as e:
        logger.exception("Unexpected error during login")
        raise InternalServerError("An unexpected error occurred during login")


@app.post("/api/auth/respond-to-challenge")
@tracer.capture_method
def respond_to_challenge() -> tuple[dict, int]:
    """
    Respond to authentication challenge (e.g., NEW_PASSWORD_REQUIRED)

    Used after receiving a challenge from /api/auth/login

    Request Body:
        session: Session token from login challenge response
        new_password: New password to set

    Returns:
        tuple[dict, int]: Response with authentication tokens and HTTP status code (200)
    """
    try:
        # Parse and validate request body
        body = app.current_event.json_body

        if not body:
            raise BadRequestError("Request body is required")

        # Validate request
        request = RespondToChallengeRequest(**body)

        logger.info("Responding to authentication challenge", extra={
            "endpoint": "POST /api/auth/respond-to-challenge",
            "action": "respond_to_challenge"
        })

        # Respond to challenge in Cognito
        result = cognito_service.respond_to_challenge(
            challenge_name='NEW_PASSWORD_REQUIRED',
            session=request.session,
            username=request.email,
            new_password=request.new_password
        )

        # Check if another challenge is required
        if result.get('challenge'):
            logger.info("Another authentication challenge required", extra={
                "endpoint": "POST /api/auth/respond-to-challenge",
                "action": "respond_to_challenge",
                "challenge": result.get('challenge')
            })
            raise BadRequestError(f"Another authentication challenge required: {result.get('challenge')}")

        logger.info("Challenge response successful", extra={
            "endpoint": "POST /api/auth/respond-to-challenge",
            "action": "respond_to_challenge",
            "status": "success"
        })

        # Build response
        response = RespondToChallengeResponse(
            message="Password updated successfully, authentication complete",
            access_token=result['access_token'],
            id_token=result['id_token'],
            refresh_token=result['refresh_token'],
            expires_in=result['expires_in'],
            token_type=result['token_type'],
            code=200
        )

        return response.model_dump(), 200

    except ValidationError as e:
        logger.warning(f"Validation error for challenge response: {e.errors()}")
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request data: {errors}")

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']

        if error_code == 'NotAuthorizedException':
            logger.warning("Failed challenge response", extra={
                "endpoint": "POST /api/auth/respond-to-challenge",
                "action": "respond_to_challenge",
                "error_code": error_code,
                "reason": "invalid_password_or_session"
            })
            raise UnauthorizedError("Invalid password or session expired")
        elif error_code == 'InvalidPasswordException':
            logger.warning("Password validation failed", extra={
                "endpoint": "POST /api/auth/respond-to-challenge",
                "action": "respond_to_challenge",
                "error_code": error_code
            })
            raise BadRequestError(f"Password does not meet requirements: {error_message}")
        else:
            logger.error(f"Cognito error ({error_code}): {error_message}")
            raise InternalServerError("Failed to process challenge response. Please try again later.")

    except BadRequestError:
        raise

    except UnauthorizedError:
        raise

    except Exception as e:
        logger.exception("Unexpected error during challenge response")
        raise InternalServerError("An unexpected error occurred during challenge response")


@app.post("/api/auth/refresh")
@tracer.capture_method
def refresh_token() -> tuple[dict, int]:
    """
    Refresh access and ID tokens using refresh token

    Request Body:
        refresh_token: Refresh token from login

    Returns:
        tuple[dict, int]: Response with new tokens and HTTP status code (200)
    """
    try:
        # Parse and validate request body
        body = app.current_event.json_body

        if not body:
            raise BadRequestError("Request body is required")

        # Validate request
        request = RefreshTokenRequest(**body)

        logger.info("Refreshing authentication tokens")

        # Refresh tokens in Cognito
        result = cognito_service.refresh_token(request.refresh_token)

        logger.info("Tokens refreshed successfully")

        # Build response
        response = RefreshTokenResponse(
            message="Tokens refreshed successfully",
            access_token=result['access_token'],
            id_token=result['id_token'],
            expires_in=result['expires_in'],
            token_type=result['token_type'],
            code=200
        )

        return response.model_dump(), 200

    except ValidationError as e:
        logger.warning(f"Validation error for token refresh: {e.errors()}")
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request data: {errors}")

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']

        if error_code == 'NotAuthorizedException':
            logger.warning("Invalid or expired refresh token")
            raise UnauthorizedError("Invalid or expired refresh token. Please login again.")
        else:
            logger.error(f"Cognito error ({error_code}): {error_message}")
            raise InternalServerError("Failed to refresh tokens. Please try again later.")

    except BadRequestError:
        # Re-raise BadRequestError as-is
        raise

    except UnauthorizedError:
        # Re-raise UnauthorizedError as-is
        raise

    except Exception as e:
        logger.exception("Unexpected error refreshing tokens")
        raise InternalServerError("An unexpected error occurred while refreshing tokens")


@app.post("/api/auth/logout")
@tracer.capture_method
def logout() -> tuple[dict, int]:
    """
    Logout user and revoke all tokens

    Request Body:
        access_token: Access token to revoke

    Returns:
        tuple[dict, int]: Response with success message and HTTP status code (200)
    """
    try:
        # Parse and validate request body
        body = app.current_event.json_body

        if not body:
            raise BadRequestError("Request body is required")

        # Validate request
        request = LogoutRequest(**body)

        logger.info("Logging out user")

        # Logout user in Cognito
        result = cognito_service.logout(request.access_token)

        logger.info("User logged out successfully")

        # Build response
        response = LogoutResponse(
            message="Logout successful",
            code=200
        )

        return response.model_dump(), 200

    except ValidationError as e:
        logger.warning(f"Validation error for logout: {e.errors()}")
        errors = [{"field": err["loc"][0] if err["loc"] else "general", "message": err["msg"]} for err in e.errors()]
        raise BadRequestError(f"Invalid request data: {errors}")

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']

        if error_code == 'NotAuthorizedException':
            logger.warning("Invalid or expired access token for logout")
            raise UnauthorizedError("Invalid or expired access token")
        else:
            logger.error(f"Cognito error ({error_code}): {error_message}")
            raise InternalServerError("Failed to logout. Please try again later.")

    except BadRequestError:
        # Re-raise BadRequestError as-is
        raise

    except UnauthorizedError:
        # Re-raise UnauthorizedError as-is
        raise

    except Exception as e:
        logger.exception("Unexpected error during logout")
        raise InternalServerError("An unexpected error occurred during logout")


# ==========================
# ===== Lambda handler =====
# ==========================
@logger.inject_lambda_context(correlation_id_path=correlation_paths.API_GATEWAY_REST)
@tracer.capture_lambda_handler
def lambda_handler(event: dict, context: LambdaContext) -> dict:
    """
    Main Lambda handler for API Gateway events

    Args:
        event: API Gateway event
        context: Lambda context

    Returns:
        API Gateway response
    """
    return app.resolve(event, context)

