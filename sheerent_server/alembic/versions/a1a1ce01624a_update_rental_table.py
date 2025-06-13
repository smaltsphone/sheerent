"""remove deposit_amount add has_insurance to rentals

Revision ID: a1a1ce01624a
Revises: b4e8d8b67a12
Create Date: 2025-05-22 00:00:00
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'a1a1ce01624a'
down_revision: Union[str, None] = 'b4e8d8b67a12'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.add_column('rentals', sa.Column('has_insurance', sa.Boolean(), nullable=True, server_default=sa.text('0')))
    op.drop_column('rentals', 'deposit_amount')

def downgrade() -> None:
    op.add_column('rentals', sa.Column('deposit_amount', sa.Integer(), nullable=True, server_default='0'))
    op.drop_column('rentals', 'has_insurance')
