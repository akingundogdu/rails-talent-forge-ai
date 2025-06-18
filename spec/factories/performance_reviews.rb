FactoryBot.define do
  factory :performance_review do
    association :employee
    association :reviewer, factory: :employee
    title { "Performance Review #{Faker::Number.unique.number(digits: 3)}" }
    description { "Annual performance review for #{employee&.full_name || 'employee'}" }
    start_date { 1.month.ago }
    end_date { 1.month.from_now }
    review_type { 'annual' }
    status { 'draft' }

    # Ensure reviewer is manager with admin privileges
    after(:build) do |review|
      if review.employee && review.reviewer
        # Make reviewer the manager of employee
        review.employee.update(manager: review.reviewer)
        # Give reviewer admin privileges
        review.reviewer.user.update(role: 'admin')
      end
    end

    trait :draft do
      status { 'draft' }
    end

    trait :in_progress do
      status { 'in_progress' }
    end

    trait :completed do
      status { 'completed' }
      completed_at { 1.week.ago }
    end

    trait :archived do
      status { :archived }
      completed_at { 2.months.ago }
    end

    trait :mid_year do
      review_type { :mid_year }
      title { "#{Date.current.year} Mid-Year Performance Review" }
      start_date { Date.current.beginning_of_year + 5.months }
      end_date { Date.current.beginning_of_year + 7.months }
    end

    trait :quarterly do
      review_type { :quarterly }
      title { "Q#{((Date.current.month - 1) / 3) + 1} #{Date.current.year} Quarterly Review" }
      start_date { Date.current.beginning_of_quarter }
      end_date { Date.current.end_of_quarter }
    end

    trait :probation do
      review_type { :probation }
      title { "Probation Performance Review" }
      start_date { 2.months.ago }
      end_date { 1.week.ago }
    end

    trait :promotion do
      review_type { :promotion }
      title { "Promotion Performance Review" }
    end

    trait :overdue do
      start_date { 2.months.ago }
      end_date { 1.month.ago }
      status { :in_progress }
    end

    trait :with_goals do
      after(:create) do |review|
        create_list(:goal, 3, employee: review.employee, performance_review: review)
      end
    end

    trait :with_feedback do
      after(:create) do |review|
        create_list(:feedback, 5, receiver: review.employee, performance_review: review)
      end
    end

    trait :with_ratings do
      after(:create) do |review|
        create_list(:rating, 4, performance_review: review)
      end
    end

    trait :comprehensive do
      with_goals
      with_feedback
      with_ratings
      status { :completed }
      completed_at { 1.week.ago }
    end

    # Factory for specific manager-employee relationship
    factory :manager_review do
      transient do
        manager { nil }
        subordinate { nil }
      end

      employee { subordinate || association(:employee) }
      reviewer { manager || association(:employee, :manager) }
      
      after(:build) do |review, evaluator|
        if evaluator.manager && evaluator.subordinate
          evaluator.subordinate.update(manager: evaluator.manager)
        end
      end
    end
  end
end 