from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import generate_password_hash, check_password_hash
import datetime as dt

# Sets up our main database connection that the whole app uses
db = SQLAlchemy()

class User(db.Model):
    __tablename__ = "users"

    # Gives each user a unique ID number for primary key for lookups
    id = db.Column(db.Integer, primary_key=True)
    # Stores user's email to be unique so nobody can register twice
    email = db.Column(db.String(120), unique=True, nullable=False)
    # Keeps the password safe by only storing the hashed version
    password_hash = db.Column(db.String(128), nullable=False)

    # Tracks if the user clicked the email verification link
    is_verified = db.Column(db.Boolean, default=False)
    # Holds the 4-digit code we email during signup
    verification_token = db.Column(db.String(128), nullable=True)

    # Stores temporary 6 digit code for password resets
    otp_code = db.Column(db.String(6), nullable=True)
    # Keeps track of when the reset code expires (usually 15 mins)
    otp_expiration = db.Column(db.DateTime, nullable=True)

    # Temporarily holds new email when user wants to change it
    pending_email = db.Column(db.String(120), nullable=True)
    # Verification code sent to confirm email change
    pending_email_token = db.Column(db.String(4), nullable=True)
    
    # Controls if user prefers dark or light mode in the app
    theme_preference = db.Column(db.String(10), nullable=False, default="dark")
    
    def set_password(self, password):
    # Takes the raw password and converts it to a secure hash before saving. This will protect user data if our database ever leaks
        self.password_hash = generate_password_hash(password).decode("utf-8")

    def check_password(self, password):
    #Compares login attempt with stored password hash. Returns true if password matches, false otherwise
        return check_password_hash(self.password_hash, password)
