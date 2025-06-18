FactoryBot.define do
  factory :rating do
    association :performance_review
    sequence(:competency_name) { |n| "Competency #{n}" }
    score { 4 }
    weight { 1.0 }
    comments { "Strong technical abilities and problem-solving skills." }

    trait :excellent_rating do
      score { 5 }
      sequence(:competency_name) { |n| "Leadership #{n}" }
      comments { "Exceptional leadership skills and team management." }
    end

    trait :poor_rating do
      score { 2 }
      sequence(:competency_name) { |n| "Communication #{n}" }
      comments { "Needs improvement in communication and collaboration." }
    end

    trait :technical_competency do
      sequence(:competency_name) { |n| "Technical Skills #{n}" }
      score { 4 }
      comments { "Strong programming and system design skills." }
    end

    trait :leadership_competency do
      sequence(:competency_name) { |n| "Leadership #{n}" }
      score { 4 }
      comments { "Good leadership potential and team collaboration." }
    end

    trait :communication_competency do
      sequence(:competency_name) { |n| "Communication #{n}" }
      score { 3 }
      comments { "Adequate communication skills with room for improvement." }
    end

    trait :problem_solving_competency do
      competency_name { "Problem Solving" }
      score { 4.3 }
      comments { "Excellent analytical skills. Quickly identifies issues and develops effective solutions." }
      weight { 1.3 }
    end

    trait :collaboration_competency do
      competency_name { "Teamwork & Collaboration" }
      score { 4.1 }
      comments { "Works exceptionally well with others. Builds strong relationships across teams." }
      weight { 1.0 }
    end

    trait :innovation_competency do
      competency_name { "Innovation & Creativity" }
      score { 3.9 }
      comments { "Brings creative solutions and suggests process improvements. Open to new technologies." }
      weight { 0.9 }
    end

    trait :customer_focus_competency do
      competency_name { "Customer Focus" }
      score { 4.4 }
      comments { "Strong customer orientation. Consistently delivers solutions that meet client needs." }
      weight { 1.1 }
    end

    trait :adaptability_competency do
      competency_name { "Adaptability" }
      score { 4.0 }
      comments { "Adapts well to changing requirements and new technologies. Flexible approach to work." }
      weight { 0.8 }
    end

    trait :quality_focus_competency do
      competency_name { "Quality & Attention to Detail" }
      score { 4.6 }
      comments { "Consistently delivers high-quality work. Meticulous attention to detail and thorough testing." }
      weight { 1.2 }
    end

    trait :time_management_competency do
      competency_name { "Time Management" }
      score { 3.7 }
      comments { "Generally meets deadlines but could improve in prioritization and planning." }
      weight { 0.9 }
    end

    # Weight-based traits
    trait :high_weight do
      weight { 1.5 }
      competency_name { "Core Technical Skills" }
      score { 4.2 }
      comments { "Critical competency with high impact on overall performance." }
    end

    trait :medium_weight do
      weight { 1.0 }
      competency_name { "Communication Skills" }
      score { 3.8 }
      comments { "Important competency for effective collaboration." }
    end

    trait :low_weight do
      weight { 0.5 }
      competency_name { "Presentation Skills" }
      score { 3.5 }
      comments { "Supporting competency with moderate impact." }
    end

    # Rater type traits
    trait :manager_rating do
      competency_name { "Overall Performance" }
      score { 4.1 }
      comments { "Strong overall performance with consistent delivery and good team collaboration." }
      weight { 1.3 }
      
      after(:build) do |rating|
        # Ensure rater is the manager of the performance review employee
        rating.performance_review.employee.update(manager: rating.rater)
      end
    end

    trait :peer_rating do
      competency_name { "Peer Collaboration" }
      score { 4.0 }
      comments { "Excellent team player. Always willing to help and share knowledge." }
      weight { 1.0 }
    end

    trait :self_rating do
      competency_name { "Self Assessment" }
      score { 3.8 }
      comments { "I believe I have performed well this period, with room for growth in leadership skills." }
      weight { 0.8 }
      
      after(:build) do |rating|
        rating.rater = rating.performance_review.employee
      end
    end

    # Department-specific competencies
    trait :engineering_competency do
      competency_name { "Software Engineering" }
      score { 4.3 }
      comments { "Strong engineering practices. Writes scalable and maintainable code." }
      weight { 1.4 }
    end

    trait :sales_competency do
      competency_name { "Sales Performance" }
      score { 4.5 }
      comments { "Consistently exceeds sales targets and builds strong client relationships." }
      weight { 1.5 }
    end

    trait :marketing_competency do
      competency_name { "Marketing Strategy" }
      score { 4.0 }
      comments { "Develops effective marketing campaigns and analyzes performance metrics well." }
      weight { 1.2 }
    end

    trait :hr_competency do
      competency_name { "People Management" }
      score { 4.2 }
      comments { "Excellent people skills and effectively manages employee relations." }
      weight { 1.3 }
    end

    trait :finance_competency do
      competency_name { "Financial Analysis" }
      score { 4.1 }
      comments { "Strong analytical skills and attention to detail in financial reporting." }
      weight { 1.2 }
    end

    # Factory for complete competency set
    factory :comprehensive_rating_set do
      transient do
        review { nil }
        rater_employee { nil }
      end

      after(:create) do |rating, evaluator|
        target_review = evaluator.review || rating.performance_review
        target_rater = evaluator.rater_employee || rating.rater

        competencies = [
          { name: "Technical Skills", score: 4.2, weight: 1.3 },
          { name: "Communication", score: 4.0, weight: 1.0 },
          { name: "Leadership", score: 3.8, weight: 1.1 },
          { name: "Problem Solving", score: 4.3, weight: 1.2 },
          { name: "Teamwork", score: 4.1, weight: 1.0 },
          { name: "Innovation", score: 3.9, weight: 0.9 },
          { name: "Quality Focus", score: 4.4, weight: 1.1 }
        ]

        competencies.each do |comp|
          create(:rating,
            performance_review: target_review,
            rater: target_rater,
            competency_name: comp[:name],
            score: comp[:score],
            weight: comp[:weight],
            comments: "#{comp[:name]} assessment for #{target_review.employee.name}."
          )
        end
      end
    end

    # Factory for ratings from multiple sources
    factory :multi_source_ratings do
      transient do
        review { nil }
      end

      after(:create) do |rating, evaluator|
        target_review = evaluator.review || rating.performance_review
        employee = target_review.employee

        # Manager ratings
        if employee.manager
          create_list(:rating, 5, :manager_rating,
            performance_review: target_review,
            rater: employee.manager
          )
        end

        # Peer ratings (3 peers, each rating 3 competencies)
        3.times do
          peer = create(:employee, department: employee.department)
          create_list(:rating, 3, :peer_rating,
            performance_review: target_review,
            rater: peer
          )
        end

        # Self ratings
        create_list(:rating, 4, :self_rating,
          performance_review: target_review,
          rater: employee
        )
      end
    end
  end
end 