from app.models.user import User, UserFCMToken, Friendship
from app.models.plan import Plan
from app.models.notification import Notification
from app.models.other import Room, RoomImage, Community, CommunityMember, Conversation, ConversationMember, Message

class base:
    pass

from app.db.database import Base
base.Base = Base
