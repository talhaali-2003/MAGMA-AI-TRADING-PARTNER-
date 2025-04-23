import random, string
import datetime as dt
from flask import Blueprint, request, jsonify
from cd.models import db, User
from cd.email_service import send_email
from app import db  

# Bundles all our auth routes together so they're organized
auth = Blueprint('auth', __name__)

def validate_password(password):
    """
    Makes sure passwords are secure enough for our app:
      - Needs at least 8 characters
      - Has to have uppercase letters (A-Z)
      - Has to have lowercase letters (a-z)
      - Needs at least one number
      - Must include special characters (@#$%^&*()!?)
    Returns true if good to go, false if it's too weak
    """
    if (len(password) < 8 or
        not any(char.isupper() for char in password) or
        not any(char.islower() for char in password) or
        not any(char.isdigit() for char in password) or
        not any(char in "@#$%^&*()!?" for char in password)):
        return False
    return True

def generate_4_digit_code():
    # Creates a random 4 digit code for email verification. Just numbers, no letters
    import random
    return ''.join(random.choices(string.digits, k=4))

def generate_otp():
    # Makes a 6 digit one-time password code for password resets. Completely random.
    return ''.join(random.choices(string.digits, k=6))


@auth.route('/register', methods=['POST'])
def register():
    """
    Signs up new users to our app. Handles the whole registration flow:
    1. Checks that email and password are valid
    2. Makes sure email isn't already taken
    3. Validates the password meets security standards
    4. Creates their account with a verification code
    5. Emails them the 4-digit code to verify
    """

    data = request.json
    if not data:
        return jsonify({"error": "No data provided"}), 400

    email = data.get('email')
    password = data.get('password')
    if not email or not password:
        return jsonify({"error": "Email and password are required"}), 400

    # Prevents duplicate registrations
    if User.query.filter_by(email=email).first():
        return jsonify({"error": "User already exists"}), 400

    # Validates password strength
    if not validate_password(password):
        return jsonify({"error": (
            "Password must be at least 8 characters long, "
            "contain one uppercase letter, one lowercase letter, "
            "one digit, and one special character (@#$%^&*()!?)"
        )}), 400

    # Create and store the new user
    new_user = User(email=email, is_verified=False)
    new_user.set_password(password)
    code = generate_4_digit_code()
    new_user.verification_token = code
    db.session.add(new_user)
    db.session.commit()

    # Sends the verification code to the user’s email
    subject = "Verify Your Account (MAGMA)"
    body = (
        f"Welcome to MAGMA!\n\n"
        f"Your 4-digit verification code is: {code}\n\n"
        f"Please enter this code in the app to verify your account."
    )
    send_email(subject, [email], body)

    return jsonify({"message": "Registration successful. Check your email for a 4-digit code."}), 201

@auth.route("/verify_account", methods=["POST"])
def verify_account():
    """
    Activates a new account when user enters the 4 digit verification code.
    Checks if the code matches what we sent to their email, then marks
    the account as verified so they can use the app.
    """

    data = request.get_json() or {}
    email = data.get("email")
    code = data.get("code")

    if not email or not code:
        return jsonify({"error": "Email and code are required"}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({"error": "User not found."}), 404

    if user.is_verified:
        return jsonify({"message": "Account already verified"}), 200

    if user.verification_token != code:
        return jsonify({"error": "Invalid verification code"}), 400

    user.is_verified = True
    user.verification_token = None
    db.session.commit()

    return jsonify({"message": "Account verified successfully. You can now log in."}), 200

@auth.route("/change_email_request", methods=["POST"])
def change_email_request():
    """
    Starts the process for users to update their email address.
    Generates a verification code and sends it to their new email.
    The change isn't complete until they verify the code.
    """
 
    data = request.get_json() or {}
    current_email = data.get("current_email")
    new_email = data.get("new_email")

    if not current_email or not new_email:
        return jsonify({"error": "Current email and new email are required"}), 400

    user = User.query.filter_by(email=current_email).first()
    if not user:
        return jsonify({"error": "User not found."}), 404

    # Ensures the new email is not already taken
    if User.query.filter_by(email=new_email).first():
        return jsonify({"error": "New email is already in use."}), 400

    code = generate_4_digit_code()
    user.pending_email = new_email
    user.pending_email_token = code
    db.session.commit()

    subject = "Verify New Email (MAGMA)"
    body = (
        f"You requested an email change.\n\n"
        f"Your 4-digit verification code is: {code}\n\n"
        f"Please enter this code in the app to confirm your new email address."
    )
    send_email(subject, [new_email], body)

    return jsonify({"message": "A 4-digit code has been sent to your new email."}), 200

@auth.route("/change_email_verify", methods=["POST"])
def change_email_verify():

# Verifies the new email address.

# If the code is valid, updates the user's email address.

    data = request.get_json() or {}
    current_email = data.get("current_email")
    code = data.get("code")

    if not current_email or not code:
        return jsonify({"error": "Current email and code are required"}), 400

    user = User.query.filter_by(email=current_email).first()
    if not user:
        return jsonify({"error": "User not found."}), 404

    if not user.pending_email or not user.pending_email_token:
        return jsonify({"error": "No pending email change request found."}), 400

    if user.pending_email_token != code:
        return jsonify({"error": "Invalid verification code."}), 400

    user.email = user.pending_email
    user.pending_email = None
    user.pending_email_token = None
    db.session.commit()

    return jsonify({"message": "Email changed successfully."}), 200

@auth.route('/login', methods=['POST'])
def login():

    #Allows user to login. Returns user information if successful.
    data = request.json
    if not data:
        return jsonify({"error": "No data provided"}), 400

    email = data.get('email')
    password = data.get('password')
    if not email or not password:
        return jsonify({"error": "Email and password are required"}), 400

    user = User.query.filter_by(email=email).first()
    if user and user.check_password(password):
        if not user.is_verified:
            return jsonify({"error": "Please verify your email before logging in"}), 403
        return jsonify({"message": "Login successful", "user": {"id": user.id, "email": user.email, "theme_preference": user.theme_preference}}), 200
    else:
        return jsonify({"error": "Invalid credentials"}), 401

@auth.route("/forgot_password", methods=["POST"])
def forgot_password():
    """
    Helps users who forgot their password. Creates a 6-digit OTP code,
    saves it with a 15-minute expiration, and emails it to the user.
    They'll use this code with the reset_password endpoint to create a new password.
    """

    data = request.get_json() or {}
    email = data.get("email")
# Initiates the password reset process.
    if not email:
        return jsonify({"error": "Email is required"}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({"error": "No account found with that email."}), 404

    otp = generate_otp()
    user.otp_code = otp
    user.otp_expiration = dt.datetime.utcnow() + dt.timedelta(minutes=10)
    db.session.commit()

    subject = "Password Reset (MAGMA)"
    body = (
        f"You requested a password reset.\n\n"
        f"Use this One-Time Code (OTP) to reset your password: {otp}\n"
        f"This code expires in 10 minutes."
    )
    send_email(subject, [email], body)

    return jsonify({"message": "OTP sent to your email."}), 200

@auth.route("/reset_password", methods=["POST"])
def reset_password():
    """
    Resets a user's password using the OTP they received via email.
    Checks that the code is valid, not expired, and that the new password
    meets our security requirements before updating their account.
    """

    data = request.get_json() or {}
    email = data.get("email")
    otp = data.get("otp")
    new_password = data.get("new_password")

    if not email or not otp or not new_password:
        return jsonify({"error": "Email, OTP, and new password are required"}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({"error": "No account found with that email."}), 404

    if user.otp_code != otp:
        return jsonify({"error": "Invalid OTP"}), 400
    if dt.datetime.utcnow() > user.otp_expiration:
        return jsonify({"error": "OTP expired. Please request a new one."}), 400

    if not validate_password(new_password):
        return jsonify({"error": (
            "Password must be at least 8 characters long, "
            "contain one uppercase letter, one lowercase letter, "
            "one digit, and one special character (@#$%^&*()!?)"
        )}), 400

    user.set_password(new_password)
    user.otp_code = None
    user.otp_expiration = None
    db.session.commit()
    # Validates the OTP and password complexity before updating.
    return jsonify({"message": "Password reset successful. You can now log in."}), 200

@auth.route("/change_password", methods=["POST"])
def change_password():
    """
    Updates a user's password when they know their current one.
    Verifies their old password is correct first as a security measure,
    then checks that the new password meets our strength requirements.
    """
    
    data = request.get_json() or {}
    email = data.get("email")
    old_password = data.get("old_password")
    new_password = data.get("new_password")

    if not email or not old_password or not new_password:
        return jsonify({"error": "Email, old password, and new password are required"}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({"error": "User not found."}), 404

    if not user.check_password(old_password):
        return jsonify({"error": "Old password is incorrect."}), 400

    if not validate_password(new_password):
        return jsonify({"error": (
            "Password must be at least 8 characters long, "
            "contain one uppercase letter, one lowercase letter, "
            "one digit, and one special character (@#$%^&*()!?)"
        )}), 400

    user.set_password(new_password)
    db.session.commit()

    return jsonify({"message": "Password changed successfully."}), 200

@auth.route("/delete_account", methods=["POST"])
def delete_account():
    """
    Permanently removes a user's account from our database.
    Requires their password as confirmation to prevent unauthorized deletions.
    Completely erases their data if credentials match.
    """
 
    data = request.get_json() or {}
    email = data.get("email")
    password = data.get("password")

    if not email or not password:
        return jsonify({"error": "Email and password are required"}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({"error": "User not found."}), 404

    if not user.check_password(password):
        return jsonify({"error": "Incorrect password. Account deletion aborted."}), 400

    db.session.delete(user)
    db.session.commit()

    return jsonify({"message": "Account deleted successfully."}), 200

@auth.route("/change_theme", methods=["POST"])
def change_theme():
    """
    Saves the user's theme preference (dark or light mode).
    Updates their account settings and syncs across all their devices.
    """
    data = request.get_json() or {}
    email = data.get("email")
    theme_preference = data.get("theme_preference")
    
    if not email or not theme_preference:
        return jsonify({"error": "Missing required fields."}), 400
    
    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({"error": "User not found."}), 404
    
    user.theme_preference = theme_preference
    db.session.commit()
    
    return jsonify({"message": "Theme updated successfully"}), 200

@auth.route('/send_feedback', methods=['POST'])
def send_feedback():
    """
    Collects user suggestions and bug reports through the app.
    Forwards their feedback to our team email so we can improve MAGMA.
    Includes their email address so we can follow up if needed.
    """
    data = request.get_json() or {}
    email = data.get('email')
    message = data.get('message')
    
    if not email or not message:
        return jsonify({"error": "Email and message are required"}), 400
        
    try:
        # Send email to the app's email address
        send_email(
            subject=f"Feedback from {email}",
            recipients=["teammagma242@gmail.com"],
            body=message
        )
        return jsonify({"message": "Feedback sent successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
