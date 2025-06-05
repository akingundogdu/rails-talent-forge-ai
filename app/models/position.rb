class Position < ApplicationRecord
  # Associations
  belongs_to :department
  belongs_to :parent_position, class_name: 'Position', optional: true
  has_many :subordinate_positions, class_name: 'Position', foreign_key: 'parent_position_id'
  has_many :employees

  # Validations
  validates :title, presence: true, uniqueness: true
  validates :level, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :no_circular_hierarchy
  validate :parent_position_level_check

  # Soft delete
  acts_as_paranoid

  # Scopes
  scope :top_level, -> { where(parent_position_id: nil) }

  # Callbacks for cache invalidation
  after_commit :invalidate_caches
  after_touch :invalidate_caches

  # Custom methods
  def ancestors
    return [] unless parent_position
    parent_position.ancestors + [parent_position]
  end

  def descendants
    subordinate_positions.flat_map { |child| [child] + child.descendants }
  end

  def hierarchy
    Position.where(id: [id] + ancestors.map(&:id) + descendants.map(&:id))
           .includes(:department, :employees)
  end

  def ancestors_and_descendants
    [self] + ancestors + descendants
  end

  private

  def no_circular_hierarchy
    return unless parent_position_id_changed? && parent_position_id.present?

    visited = Set.new
    current = parent_position_id

    while current.present?
      if visited.include?(current)
        errors.add(:parent_position_id, 'circular hierarchy is not allowed')
        break
      end

      visited.add(current)
      current = Position.find_by(id: current)&.parent_position_id
    end
  end

  def parent_position_level_check
    return unless parent_position && level
    unless level < parent_position.level
      errors.add(:level, 'must be less than parent position level')
    end
  end

  def invalidate_caches
    CacheService.invalidate_position_caches(self)
  end
end 