from app.models.user import User
from app.models.plan import Plan
from app.models.other import Room, Community, CommunityMember, Conversation, ConversationMember, Message

class base:
    pass

from app.db.database import Base
base.Base = Base
