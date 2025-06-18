FactoryBot.define do
  factory :feedback_request do
    association :requester, factory: :employee
    association :recipient, factory: :employee
    message { "Please provide feedback on my recent project work and collaboration skills." }
    feedback_type { :peer }
    status { :pending }
    
    trait :upward do
      feedback_type { :upward }
      message { "Please provide feedback on my management and leadership performance." }
    end
    
    trait :downward do
      feedback_type { :downward }
      message { "Please provide feedback on your experience working under my supervision." }
    end
    
    trait :completed do
      status { :completed }
    end
    
    trait :accepted do
      status { :accepted }
    end
    
    trait :declined do
      status { :declined }
    end
  end
end
