import os
import hmac
import hashlib
import base64
from typing import Dict, Any, Optional
import boto3
from botocore.exceptions import ClientError
from aws_lambda_powertools import Logger

from models import UserRole, UserResponse, CreateUserRequest, GetUsersRequest

logger = Logger(child=True)


class CognitoService:
    def __init__(self):
        self.client = boto3.client('cognito-idp')
        self.user_pool_id = os.environ.get('COGNITO_USER_POOL_ID')
        self.client_id = os.environ.get('COGNITO_CLIENT_ID')
        self.client_secret = os.environ.get('COGNITO_CLIENT_SECRET')  # Optional
        self.root_admin_username = os.environ.get('ROOT_ADMIN_USERNAME')

        if not self.user_pool_id or not self.client_id:
            raise ValueError("COGNITO_USER_POOL_ID and COGNITO_CLIENT_ID must be set")

        
    def create_user(self, request: CreateUserRequest) -> Dict[str, Any]:
        """
        Create a new user in Cognito User Pool

        Args:
            request: CreateUserRequest object (validated)

        Returns:
            Dict with Cognito user details (Username, Attributes, UserStatus, etc.)

        Raises:
            ClientError: If user creation fails
        """
        try:
            logger.info(f"Creating user {request.email} with role {request.role.value}")

            # Build user attributes (no custom:role - using groups instead)
            user_attributes = [
                {'Name': 'email', 'Value': request.email},
                {'Name': 'email_verified', 'Value': 'true'},
                {'Name': 'given_name', 'Value': request.first_name},  # Cognito standard attribute for first name
                {'Name': 'family_name', 'Value': request.last_name}   # Cognito standard attribute for last name
            ]

            # Create user in Cognito
            response = self.client.admin_create_user(
                UserPoolId=self.user_pool_id,
                Username=request.email,  # Use email as username
                UserAttributes=user_attributes,
                TemporaryPassword=request.temporary_password,
                MessageAction='SUPPRESS',  # Don't send welcome email
                DesiredDeliveryMediums=['EMAIL']  # Set email as delivery medium
            )

            # Add user to the appropriate group
            self.client.admin_add_user_to_group(
                UserPoolId=self.user_pool_id,
                Username=request.email,
                GroupName=request.role.value
            )

            logger.info(f"User {request.email} created successfully and added to group {request.role.value}")

            # Return the raw Cognito user object for testing/debugging
            # In production, you might want to return _map_user_response(response['User'])
            return response['User']

        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error creating user {getattr(request, 'email', None)}: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception(f"Unexpected error creating user {getattr(request, 'email', None)}")
            raise
    
    def _get_user_groups(self, username: str) -> str:
        """
        Get the primary group/role for a user

        Args:
            username: Username (email) of the user

        Returns:
            Group name (role) as string, defaults to 'agent' if no groups found
        """
        try:
            response = self.client.admin_list_groups_for_user(
                UserPoolId=self.user_pool_id,
                Username=username
            )

            groups = response.get('Groups', [])

            if not groups:
                logger.warning(f"User {username} has no groups, defaulting to agent")
                return UserRole.AGENT.value

            # Return the first group name (assuming users are in only one group)
            return groups[0]['GroupName']

        except ClientError as e:
            logger.error(f"Error fetching groups for user {username}: {e}")
            return UserRole.AGENT.value

    def _map_user_response(self, cognito_user: Dict[str, Any]) -> UserResponse:
        """
        Map Cognito user object to UserResponse model

        Args:
            cognito_user: Cognito user object from API response

        Returns:
            UserResponse object
        """
        # Extract attributes from Cognito user
        attributes = {attr['Name']: attr['Value'] for attr in cognito_user.get('Attributes', [])}

        # Get username (email)
        username = cognito_user.get('Username', attributes.get('email', ''))

        # Get role from user groups
        role = self._get_user_groups(username)

        return UserResponse(
            email=attributes.get('email', ''),
            first_name=attributes.get('given_name', ''),  # Map Cognito's given_name to first_name
            last_name=attributes.get('family_name', ''),  # Map Cognito's family_name to last_name
            role=UserRole(role),
            enabled=cognito_user.get('Enabled', True)
        )
    
    def get_users(self, request: GetUsersRequest) -> Dict[str, Any]:
        """
        Get all users from Cognito User Pool with optional pagination

        Args:
            request: GetUsersRequest object with optional limit and pagination_token

        Returns:
            Dict with:
                - Users: List of mapped UserResponse objects
                - PaginationToken: Token for next page (if more results exist)

        Raises:
            ClientError: If listing users fails
        """
        try:
            logger.info(f"Fetching users from Cognito User Pool (limit: {request.limit})")

            # Build parameters for list_users call
            params = {
                'UserPoolId': self.user_pool_id,
                'Limit': request.limit
            }

            # Add pagination token if provided
            if request.pagination_token:
                params['PaginationToken'] = request.pagination_token

            # List users in Cognito
            response = self.client.list_users(**params)

            logger.info(f"Retrieved {len(response.get('Users', []))} users from Cognito")

            # Map Cognito users to UserResponse objects
            users = [self._map_user_response(user) for user in response.get('Users', [])]

            # Prepare response
            result = {
                'Users': [user.model_dump() for user in users],
                'PaginationToken': response.get('PaginationToken')
            }

            return result

        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error listing users: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception(f"Unexpected error listing users")
            raise

    def disable_user(self, email: str) -> Dict[str, Any]:
        """
        Disable a user in Cognito User Pool

        Args:
            email: User's email address (username)

        Returns:
            Dict with success status

        Raises:
            ClientError: If user disable fails
        """
        try:
            logger.info(f"Disabling user {email}")

            # Disable user in Cognito
            self.client.admin_disable_user(
                UserPoolId=self.user_pool_id,
                Username=email
            )

            logger.info(f"User {email} disabled successfully")

            return {"success": True, "email": email}

        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error disabling user {email}: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception(f"Unexpected error disabling user {email}")
            raise

    def enable_user(self, email: str) -> Dict[str, Any]:
        """
        Enable a user in Cognito User Pool

        Args:
            email: User's email address (username)

        Returns:
            Dict with success status

        Raises:
            ClientError: If user enable fails
        """
        try:
            logger.info(f"Enabling user {email}")

            # Enable user in Cognito
            self.client.admin_enable_user(
                UserPoolId=self.user_pool_id,
                Username=email
            )

            logger.info(f"User {email} enabled successfully")

            return {"success": True, "email": email}

        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error enabling user {email}: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception(f"Unexpected error enabling user {email}")
            raise

    def update_user_attributes(self, email: str, first_name: Optional[str] = None,
                               last_name: Optional[str] = None, role: Optional[str] = None) -> Dict[str, Any]:
        """
        Update user attributes and/or group membership in Cognito User Pool

        Args:
            email: User's email address (username)
            first_name: Updated first name (optional)
            last_name: Updated last name (optional)
            role: Updated role/group (optional)

        Returns:
            Dict with updated user information

        Raises:
            ClientError: If user update fails
        """
        try:
            logger.info(f"Updating attributes for user {email}")

            # Check if there are any attributes to update
            if first_name is None and last_name is None and role is None:
                logger.warning(f"No attributes provided to update for user {email}")
                raise ValueError("At least one attribute must be provided for update")

            # Build user attributes list based on provided fields (excluding role)
            user_attributes = []

            if first_name is not None:
                user_attributes.append({'Name': 'given_name', 'Value': first_name})

            if last_name is not None:
                user_attributes.append({'Name': 'family_name', 'Value': last_name})

            # Update user attributes in Cognito (if any)
            if user_attributes:
                self.client.admin_update_user_attributes(
                    UserPoolId=self.user_pool_id,
                    Username=email,
                    UserAttributes=user_attributes
                )

            # Handle role/group change separately
            if role is not None:
                # Get current groups
                current_groups_response = self.client.admin_list_groups_for_user(
                    UserPoolId=self.user_pool_id,
                    Username=email
                )

                current_groups = current_groups_response.get('Groups', [])

                # Remove user from all current groups
                for group in current_groups:
                    self.client.admin_remove_user_from_group(
                        UserPoolId=self.user_pool_id,
                        Username=email,
                        GroupName=group['GroupName']
                    )
                    logger.info(f"Removed user {email} from group {group['GroupName']}")

                # Add user to new group
                self.client.admin_add_user_to_group(
                    UserPoolId=self.user_pool_id,
                    Username=email,
                    GroupName=role
                )
                logger.info(f"Added user {email} to group {role}")

            logger.info(f"User {email} attributes updated successfully")

            # Get updated user details
            response = self.client.admin_get_user(
                UserPoolId=self.user_pool_id,
                Username=email
            )

            # Convert admin_get_user response to the format _map_user_response expects
            user_data = {
                'Username': response.get('Username'),
                'Attributes': response.get('UserAttributes', []),
                'Enabled': response.get('Enabled', True)
            }

            # Map to UserResponse
            user_response = self._map_user_response(user_data)

            return {
                "success": True,
                "email": email,
                "user": user_response.model_dump()
            }

        except ValueError as e:
            # Re-raise validation errors
            logger.warning(f"Validation error updating user {email}: {str(e)}")
            raise
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error updating user {email}: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception(f"Unexpected error updating user {email}")
            raise

    def forgot_password(self, email: str) -> Dict[str, Any]:
        """
        Initiate forgot password flow for a user

        Args:
            email: User's email address (username)

        Returns:
            Dict with code delivery details

        Raises:
            ClientError: If forgot password initiation fails
        """
        try:
            logger.info(f"Initiating forgot password for user {email}")

            # Build parameters
            params = {
                'ClientId': self.client_id,
                'Username': email
            }

            # Add SECRET_HASH if client secret is configured
            # if self.client_secret:
            #     params['SecretHash'] = self._calculate_secret_hash(email)

            # Initiate forgot password flow
            response = self.client.forgot_password(**params)

            # Extract code delivery details
            code_delivery = response.get('CodeDeliveryDetails', {})

            logger.info(f"Forgot password code sent to user {email}")

            return {
                "success": True,
                "destination": code_delivery.get('Destination'),
                "delivery_medium": code_delivery.get('DeliveryMedium'),
                "attribute_name": code_delivery.get('AttributeName')
            }

        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error initiating forgot password for {email}: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception(f"Unexpected error initiating forgot password for {email}")
            raise

    def confirm_forgot_password(self, email: str, confirmation_code: str, new_password: str) -> Dict[str, Any]:
        """
        Confirm forgot password with verification code and set new password

        Args:
            email: User's email address (username)
            confirmation_code: Verification code sent to user
            new_password: New password to set

        Returns:
            Dict with success status

        Raises:
            ClientError: If password reset confirmation fails
        """
        try:
            logger.info(f"Confirming forgot password for user {email}")

            # Build parameters
            params = {
                'ClientId': self.client_id,
                'Username': email,
                'ConfirmationCode': confirmation_code,
                'Password': new_password
            }

            # Add SECRET_HASH if client secret is configured
            # if self.client_secret:
            #     params['SecretHash'] = self._calculate_secret_hash(email)

            # Confirm forgot password with code
            self.client.confirm_forgot_password(**params)

            logger.info(f"Password reset successful for user {email}")

            return {
                "success": True,
                "email": email
            }

        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error confirming forgot password for {email}: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception(f"Unexpected error confirming forgot password for {email}")
            raise

    def login(self, email: str, password: str) -> Dict[str, Any]:
        """
        Authenticate user with email and password

        Args:
            email: User's email address (username)
            password: User's password

        Returns:
            Dict with authentication tokens (AccessToken, IdToken, RefreshToken)

        Raises:
            ClientError: If authentication fails
        """
        try:
            logger.info(f"Authenticating user {email}")

            # Build parameters
            auth_params = {
                'USERNAME': email,
                'PASSWORD': password
            }

            # Add SECRET_HASH if client secret is configured
            # if self.client_secret:
            #     auth_params['SECRET_HASH'] = self._calculate_secret_hash(email)

            # Authenticate using USER_PASSWORD_AUTH flow
            response = self.client.initiate_auth(
                ClientId=self.client_id,
                AuthFlow='USER_PASSWORD_AUTH',
                AuthParameters=auth_params
            )

            # Check if challenge is required (e.g., NEW_PASSWORD_REQUIRED)
            if 'ChallengeName' in response:
                challenge_name = response['ChallengeName']
                logger.warning(f"Authentication challenge required for {email}: {challenge_name}")
                return {
                    "challenge": challenge_name,
                    "session": response.get('Session'),
                    "challenge_parameters": response.get('ChallengeParameters', {})
                }

            # Extract authentication result
            auth_result = response.get('AuthenticationResult', {})

            logger.info(f"User {email} authenticated successfully")

            return {
                "success": True,
                "access_token": auth_result.get('AccessToken'),
                "id_token": auth_result.get('IdToken'),
                "refresh_token": auth_result.get('RefreshToken'),
                "expires_in": auth_result.get('ExpiresIn'),
                "token_type": auth_result.get('TokenType', 'Bearer')
            }

        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error authenticating user {email}: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception(f"Unexpected error authenticating user {email}")
            raise

    def refresh_token(self, refresh_token: str) -> Dict[str, Any]:
        """
        Get new access and ID tokens using refresh token

        Args:
            refresh_token: Refresh token from initial login

        Returns:
            Dict with new access and ID tokens

        Raises:
            ClientError: If token refresh fails
        """
        try:
            logger.info("Refreshing authentication tokens")

            # Build parameters
            auth_params = {
                'REFRESH_TOKEN': refresh_token
            }

            # Refresh tokens using REFRESH_TOKEN_AUTH flow
            response = self.client.initiate_auth(
                ClientId=self.client_id,
                AuthFlow='REFRESH_TOKEN_AUTH',
                AuthParameters=auth_params
            )

            # Extract authentication result
            auth_result = response.get('AuthenticationResult', {})

            logger.info("Tokens refreshed successfully")

            return {
                "success": True,
                "access_token": auth_result.get('AccessToken'),
                "id_token": auth_result.get('IdToken'),
                "expires_in": auth_result.get('ExpiresIn'),
                "token_type": auth_result.get('TokenType', 'Bearer')
            }

        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error refreshing tokens: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception("Unexpected error refreshing tokens")
            raise

    def respond_to_challenge(self, challenge_name: str, session: str, username: str, new_password: str) -> Dict[str, Any]:
        """
        Respond to authentication challenge (e.g., NEW_PASSWORD_REQUIRED)

        Args:
            challenge_name: Name of the challenge (e.g., 'NEW_PASSWORD_REQUIRED')
            session: Session token from initial login attempt
            username: Username (email) of the user
            new_password: New password to set

        Returns:
            Dict with authentication tokens

        Raises:
            ClientError: If challenge response fails
        """
        try:
            logger.info(f"Responding to challenge {challenge_name} for user {username}")

            # Build parameters for challenge response
            params = {
                'ClientId': self.client_id,
                'ChallengeName': challenge_name,
                'Session': session,
                'ChallengeResponses': {
                    'USERNAME': username,
                    'NEW_PASSWORD': new_password
                }
            }

            # Respond to authentication challenge
            response = self.client.respond_to_auth_challenge(**params)

            # Check if another challenge is required
            if 'ChallengeName' in response:
                challenge_name = response['ChallengeName']
                logger.warning(f"Another challenge required after response: {challenge_name}")
                return {
                    "challenge": challenge_name,
                    "session": response.get('Session'),
                    "challenge_parameters": response.get('ChallengeParameters', {})
                }

            # Extract authentication result
            auth_result = response.get('AuthenticationResult', {})

            logger.info(f"Challenge response successful for user {username}")

            return {
                "success": True,
                "access_token": auth_result.get('AccessToken'),
                "id_token": auth_result.get('IdToken'),
                "refresh_token": auth_result.get('RefreshToken'),
                "expires_in": auth_result.get('ExpiresIn'),
                "token_type": auth_result.get('TokenType', 'Bearer')
            }

        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error responding to challenge for {username}: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception(f"Unexpected error responding to challenge for {username}")
            raise

    def logout(self, access_token: str) -> Dict[str, Any]:
        """
        Sign out user and revoke tokens

        Args:
            access_token: Access token to revoke

        Returns:
            Dict with success status

        Raises:
            ClientError: If logout fails
        """
        try:
            logger.info("Logging out user")

            # Global sign out - revokes all tokens for the user
            self.client.global_sign_out(
                AccessToken=access_token
            )

            logger.info("User logged out successfully")

            return {
                "success": True
            }

        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"Cognito error logging out user: {error_code} - {error_message}")

            # Re-raise with original error for handler to process
            raise
        except Exception as e:
            logger.exception("Unexpected error logging out user")
            raise

