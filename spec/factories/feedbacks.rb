FactoryBot.define do
  factory :feedback do
    association :giver, factory: :employee
    association :receiver, factory: :employee
    message { "Great work on the recent project. Shows excellent collaboration skills and attention to detail." }
    feedback_type { :peer }
    rating { 4.2 }
    anonymous { false }

    trait :peer_feedback do
      feedback_type { :peer }
      message { "Great teamwork and communication skills. Always reliable and delivers quality work on time." }
      rating { 4.0 }
    end

    trait :subordinate_feedback do
      feedback_type { :subordinate }
      message { "Supportive manager who provides clear direction and constructive feedback. Creates a positive work environment." }
      rating { 4.5 }
      
      after(:build) do |feedback|
        feedback.receiver.update(manager: feedback.giver) if feedback.receiver.manager != feedback.giver
      end
    end

    trait :manager_feedback do
      feedback_type { :manager }
      message { "Demonstrates strong leadership potential and technical skills. Consistently exceeds expectations and mentors junior team members effectively." }
      rating { 4.3 }
      
      after(:build) do |feedback|
        feedback.receiver.update(manager: feedback.giver) if feedback.receiver.manager != feedback.giver
      end
    end

    trait :self_feedback do
      feedback_type { 'self_evaluation' }
      giver { receiver }
    end

    trait :upward_feedback do
      feedback_type { :upward }
      message { "Provides excellent guidance and support. Could improve on providing more frequent feedback and recognition for team achievements." }
      rating { 3.9 }
    end

    trait :client_feedback do
      feedback_type { :client }
      message { "Professional, responsive, and delivers high-quality results. Always goes above and beyond to meet our needs and deadlines." }
      rating { 4.7 }
    end

    trait :anonymous do
      anonymous { true }
    end

    trait :positive_feedback do
      message { "Outstanding performance! Excellent work quality and amazing teamwork skills!" }
      feedback_type { :peer }
      rating { 4.8 }
    end

    trait :constructive_feedback do
      message { "Good work overall, but could improve communication with stakeholders and time management." }
      feedback_type { :peer }
      rating { 3.5 }
    end

    trait :negative_feedback do
      message { "Performance has been below expectations. Significant improvement needed in multiple areas." }
      feedback_type { :peer }
      rating { 2.2 }
    end

    trait :neutral_feedback do
      message { "Solid contributor who meets expectations. Competent in assigned tasks and follows procedures well." }
      rating { 3.0 }
    end

    # Feedback with different content themes
    trait :leadership_feedback do
      message { "Demonstrates natural leadership abilities. Effectively guides team members and makes sound decisions under pressure. Could work on delegation skills." }
      rating { 4.1 }
    end

    trait :technical_feedback do
      message { "Excellent technical expertise in Ruby on Rails and system architecture. Writes clean, maintainable code and follows best practices consistently." }
      rating { 4.4 }
    end

    trait :communication_feedback do
      message { "Strong verbal and written communication skills. Effectively presents complex technical concepts to non-technical stakeholders." }
      rating { 4.0 }
    end

    trait :collaboration_feedback do
      message { "Works exceptionally well in cross-functional teams. Always willing to share knowledge and help colleagues solve problems." }
      rating { 4.3 }
    end

    trait :innovation_feedback do
      message { "Brings creative solutions to complex problems. Actively suggests process improvements and implements new technologies effectively." }
      rating { 4.2 }
    end

    # Feedback for different performance levels
    trait :high_performer_feedback do
      message { "Consistently exceeds expectations and delivers exceptional results. Strong leadership skills and mentors others effectively." }
      rating { 4.6 }
    end

    trait :average_performer_feedback do
      message { "Meets job expectations and completes assigned tasks satisfactorily. Shows potential for growth with additional development." }
      rating { 3.0 }
    end

    trait :underperformer_feedback do
      message { "Performance falls below expectations. Needs significant improvement in productivity and quality of work output." }
      rating { 1.8 }
    end

    # Factory for review-specific feedback
    factory :review_feedback do
      association :performance_review
      receiver { performance_review.employee }
    end

    # Factory for 360-degree feedback set
    factory :comprehensive_feedback do
      transient do
        review { nil }
        employee { nil }
      end

      after(:create) do |feedback, evaluator|
        target_employee = evaluator.employee || feedback.receiver
        target_review = evaluator.review

        # Create peer feedback (3 peers)
        3.times do
          peer = create(:employee, department: target_employee.department)
          create(:feedback, :peer_feedback, 
            giver: peer, 
            receiver: target_employee, 
            performance_review: target_review
          )
        end

        # Create manager feedback
        if target_employee.manager
          create(:feedback, :manager_feedback,
            giver: target_employee.manager,
            receiver: target_employee,
            performance_review: target_review
          )
        end

        # Create subordinate feedback (if applicable)
        subordinates = Employee.where(manager: target_employee).limit(2)
        subordinates.each do |subordinate|
          create(:feedback, :subordinate_feedback,
            giver: subordinate,
            receiver: target_employee,
            performance_review: target_review
          )
        end

        # Create self feedback
        create(:feedback, :self_feedback,
          giver: target_employee,
          receiver: target_employee,
          performance_review: target_review
        )
      end
    end

    # Factory for cross-department feedback
    factory :cross_department_feedback do
      after(:build) do |feedback|
        # Ensure giver and receiver are from different departments
        different_dept = create(:department)
        feedback.giver.update(department: different_dept) if feedback.giver.department == feedback.receiver.department
      end
      
      message { "Great cross-team collaboration. Effectively communicates across departments and helps bridge technical and business requirements." }
      rating { 4.1 }
    end
  end
end 