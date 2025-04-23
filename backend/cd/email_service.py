from flask_mail import Mail, Message
from flask import current_app

# Creates a global mail instance 
mail = Mail()

def init_mail(app):
    """
    Sets up our flask-mail with the app we pass in. 
    Gets called when the server first boots up. Links the mail instance to our Flask app.
    """
    mail.init_app(app)

def send_email(subject, recipients, body):
    #Sends out emails to users. Takes the email subject, who gets it, and what it says.
    
    msg = Message(
        subject=subject,
        recipients=recipients,
        body=body,
        sender=current_app.config.get("MAIL_DEFAULT_SENDER")
    )
    # Grabs the sender address from our app settings so we don't have to type it every time.
    mail.send(msg)
