FactoryBot.define do
  factory :goal do
    association :employee
    sequence(:title) { |n| "Goal #{n}" }
    description { "Test goal description for performance improvement" }
    target_value { 100.0 }
    actual_value { 0.0 }
    due_date { 3.months.from_now }
    status { :active }
    priority { :medium }

    trait :active do
      status { :active }
      completed_at { nil }
    end

    trait :completed do
      status { :completed }
      actual_value { 100.0 }
      completed_at { 1.week.ago }
    end

    trait :cancelled do
      status { :cancelled }
      completed_at { nil }
    end

    trait :overdue do
      due_date { 1.week.ago }
      status { 'active' }
      
      after(:build) do |goal|
        # Skip validation for overdue goals
        goal.define_singleton_method(:due_date_in_future) { true }
      end
    end

    trait :paused do
      status { :paused }
      completed_at { nil }
    end

    trait :low_priority do
      priority { :low }
      title { "Improve Documentation" }
      description { "Update and maintain comprehensive project documentation." }
    end

    trait :high_priority do
      priority { :high }
    end

    trait :critical_priority do
      priority { :critical }
      title { "System Migration" }
      description { "Complete critical system migration with zero downtime." }
      due_date { 1.month.from_now }
    end

    trait :standalone do
      title { "Personal Development Goal" }
      description { "Complete professional certification course." }
    end

    trait :with_progress do
      actual_value { target_value * 0.6 }
    end

    trait :near_completion do
      actual_value { target_value * 0.9 }
    end

    trait :exceeded do
      actual_value { target_value * 1.2 }
      status { :completed }
      completed_at { 3.days.ago }
    end

    trait :sales_goal do
      title { "Quarterly Sales Target" }
      description { "Achieve $50,000 in sales revenue for Q#{((Date.current.month - 1) / 3) + 1}." }
      target_value { 50000.0 }
      priority { :high }
    end

    trait :skill_development do
      title { "Technical Skills Enhancement" }
      description { "Complete advanced Ruby on Rails certification and build 2 practice projects." }
      target_value { 2.0 }
      priority { :medium }
    end

    trait :leadership_goal do
      title { "Team Leadership Development" }
      description { "Mentor 3 junior developers and lead 1 major project successfully." }
      target_value { 3.0 }
      priority { :high }
    end

    trait :process_improvement do
      title { "Process Optimization" }
      description { "Reduce deployment time by 50% through automation and improved CI/CD." }
      target_value { 50.0 }
      priority { :medium }
    end

    # Goals with different measurement types
    trait :percentage_goal do
      title { "Customer Satisfaction Improvement" }
      description { "Increase customer satisfaction score to 95%." }
      target_value { 95.0 }
      actual_value { 87.0 }
    end

    trait :count_goal do
      title { "Code Review Participation" }
      description { "Participate in 20 code reviews per month." }
      target_value { 20.0 }
      actual_value { 12.0 }
    end

    trait :time_based_goal do
      title { "Response Time Optimization" }
      description { "Reduce average API response time to under 200ms." }
      target_value { 200.0 }
      actual_value { 350.0 }
    end

    # Factory for goals with specific relationships
    factory :review_goal do
      association :performance_review
      employee { performance_review.employee }
    end

    factory :overdue_goal do
      status { :active }
      due_date { 2.weeks.ago }
      actual_value { target_value * 0.3 }
    end

    trait :smart_goal do
      title { "Increase sales revenue by 25% in Q4 2024" }
      description { "Achieve $125,000 in sales revenue by December 31, 2024, measured monthly through CRM reports" }
      target_value { 125000 }
      due_date { 3.months.from_now }
      priority { 'high' }
    end

    # Create a factory alias for smart_goal
    factory :smart_goal, traits: [:smart_goal]
  end
end 