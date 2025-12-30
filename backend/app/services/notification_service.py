import firebase_admin
from firebase_admin import credentials, messaging
import os
from typing import Optional
import logging

logger = logging.getLogger(__name__)


class NotificationService:
    _instance = None
    _initialized = False

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(NotificationService, cls).__new__(cls)
        return cls._instance

    def initialize(self):
        if self._initialized:
            return

        cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
        if cred_path and os.path.exists(cred_path):
            try:
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
                self._initialized = True
                logger.info("Firebase Admin initialized successfully.")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase Admin: {e}")
        else:
            logger.warning(
                "FIREBASE_CREDENTIALS_PATH not set or file not found. "
                "Push notifications will be disabled."
            )

    async def send_new_message_notification(
        self,
        push_token: str,
        sender_id: int,
        group_id: Optional[int] = None,
    ):
        if not self._initialized:
            logger.debug("NotificationService not initialized. Skipping push.")
            return

        # Privacy-centric: data-only notification
        # This triggers FirebaseMessaging.onBackgroundMessage on the client
        message = messaging.Message(
            data={
                "type": "new_message",
                "sender_id": str(sender_id),
                "group_id": str(group_id) if group_id else "",
            },
            token=push_token,
            # If we want a visible notification even if the app process is killed
            notification=messaging.Notification(
                title="New Secure Message",
                body="Unlock to read.",
            ),
            android=messaging.AndroidConfig(
                priority="high",
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True))
            ),
        )

        try:
            response = messaging.send(message)
            logger.info(f"Successfully sent message: {response}")
        except Exception as e:
            logger.error(f"Error sending push notification: {e}")


notification_service = NotificationService()
