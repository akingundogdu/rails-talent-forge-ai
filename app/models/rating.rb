class Rating < ApplicationRecord
  include Cacheable

  # Associations
  belongs_to :performance_review

  # Validations
  validates :competency_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :score, presence: true, inclusion: { in: 1..5 }
  validates :weight, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 5 }
  validates :competency_name, uniqueness: { scope: :performance_review_id }

  # Soft delete
  acts_as_paranoid

  # Scopes
  scope :for_review, ->(review_id) { where(performance_review_id: review_id) }
  scope :by_competency, ->(competency) { where(competency_name: competency) }
  scope :high_scores, -> { where('score >= ?', 4) }
  scope :low_scores, -> { where('score <= ?', 2) }
  scope :by_score, ->(score) { where(score: score) }
  scope :weighted_average, -> { select('AVG(score * weight) / AVG(weight) as weighted_avg') }

  # Callbacks
  after_commit :invalidate_caches
  after_touch :invalidate_caches
  after_save :update_review_completion

  # Business Methods
  def weighted_score
    (score * weight).round(2)
  end

  def score_label
    case score
    when 1
      'Poor'
    when 2
      'Below Expectation'
    when 3
      'Meets Expectation'
    when 4
      'Exceeds Expectation'
    when 5
      'Outstanding'
    end
  end

  def performance_level
    case score
    when 1..2
      'needs_improvement'
    when 3
      'satisfactory'
    when 4..5
      'excellent'
    end
  end

  def is_strength?
    score >= 4
  end

  def is_development_area?
    score <= 2
  end

  def weight_percentage(total_weight)
    return 0 if total_weight.zero?
    (weight / total_weight * 100).round(2)
  end

  # Class methods for analytics
  def self.competency_averages_for_review(review_id)
    for_review(review_id)
      .group(:competency_name)
      .average(:score)
      .transform_values { |avg| avg.round(2) }
  end

  def self.weighted_average_for_review(review_id)
    ratings = for_review(review_id)
    return 0 if ratings.empty?
    
    total_weighted_score = ratings.sum { |r| r.score * r.weight }
    total_weight = ratings.sum(&:weight)
    
    return 0 if total_weight.zero?
    (total_weighted_score / total_weight).round(2)
  end

  def self.competency_benchmarks(competency_name, department_id = nil)
    query = joins(performance_review: { employee: :position })
            .where(competency_name: competency_name)
    
    if department_id
      query = query.where(positions: { department_id: department_id })
    end
    
    {
      average_score: query.average(:score)&.round(2) || 0,
      score_distribution: query.group(:score).count,
      total_ratings: query.count,
      top_performers: query.high_scores.count,
      development_needed: query.low_scores.count
    }
  end

  def self.employee_competency_profile(employee_id, months = 12)
    start_date = months.months.ago
    
    joins(:performance_review)
      .where(performance_reviews: { employee_id: employee_id })
      .where('performance_reviews.created_at >= ?', start_date)
      .group(:competency_name)
      .average(:score)
      .transform_values { |avg| avg.round(2) }
      .sort_by { |_, score| -score }
  end

  def self.trending_competencies(department_id = nil, months = 6)
    start_date = months.months.ago
    
    query = joins(performance_review: { employee: :position })
            .where('performance_reviews.created_at >= ?', start_date)
    
    if department_id
      query = query.where(positions: { department_id: department_id })
    end
    
    monthly_trends = query
      .group(:competency_name)
      .group("DATE_TRUNC('month', performance_reviews.created_at)")
      .average(:score)
    
    # Group by competency and calculate trend
    competency_trends = {}
    monthly_trends.each do |(competency, month), avg_score|
      competency_trends[competency] ||= []
      competency_trends[competency] << {
        month: month.strftime('%Y-%m'),
        average_score: avg_score.round(2)
      }
    end
    
    # Calculate trend direction for each competency
    competency_trends.transform_values do |monthly_data|
      sorted_data = monthly_data.sort_by { |d| d[:month] }
      trend_direction = if sorted_data.length > 1
        first_score = sorted_data.first[:average_score]
        last_score = sorted_data.last[:average_score]
        
        if last_score > first_score + 0.2
          'improving'
        elsif last_score < first_score - 0.2
          'declining'
        else
          'stable'
        end
      else
        'insufficient_data'
      end
      
      {
        monthly_data: sorted_data,
        trend_direction: trend_direction,
        current_average: sorted_data.last&.dig(:average_score) || 0
      }
    end
  end

  def self.department_competency_gaps(department_id, target_score = 3.5)
    employee_ids = Employee.joins(:position)
                          .where(positions: { department_id: department_id })
                          .pluck(:id)
    
    competency_averages = joins(:performance_review)
                         .where(performance_reviews: { employee_id: employee_ids })
                         .group(:competency_name)
                         .average(:score)
    
    gaps = competency_averages.select { |_, avg| avg < target_score }
                             .transform_values { |avg| (target_score - avg).round(2) }
                             .sort_by { |_, gap| -gap }
    
    {
      competency_gaps: gaps,
      total_competencies: competency_averages.count,
      gaps_count: gaps.count,
      department_average: competency_averages.values.sum / competency_averages.count
    }
  end

  # Bulk operations
  def self.bulk_create_for_review(review_id, competency_ratings)
    transaction do
      competency_ratings.each do |competency_data|
        create!(
          performance_review_id: review_id,
          competency_name: competency_data[:name],
          score: competency_data[:score],
          comments: competency_data[:comments],
          weight: competency_data[:weight] || 1.0
        )
      end
    end
  end

  def self.standard_competencies
    [
      'Communication Skills',
      'Leadership',
      'Problem Solving',
      'Teamwork',
      'Technical Skills',
      'Initiative',
      'Adaptability',
      'Customer Focus',
      'Quality of Work',
      'Time Management'
    ]
  end

  private

  def update_review_completion
    # Trigger review recalculation when ratings change
    performance_review.touch if performance_review.present?
  end

  def invalidate_caches
    return unless performance_review&.employee_id
    
    CacheService.invalidate_performance_caches(performance_review.employee_id)
  end
end 