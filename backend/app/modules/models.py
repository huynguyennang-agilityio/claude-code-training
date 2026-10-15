"""Every module's database models, imported in one place.

SQLAlchemy only knows a table once its model class is imported, and
cross-module relationships are resolved by class name. Import this module
wherever the full schema is needed (tests, `create_all`, Alembic) instead
of importing single model files.
"""

from app.modules.challenges.models import Challenge, Quest
from app.modules.medals.models import Medal
from app.modules.runs.models import Run, StepSample

__all__ = ["Challenge", "Medal", "Quest", "Run", "StepSample"]
