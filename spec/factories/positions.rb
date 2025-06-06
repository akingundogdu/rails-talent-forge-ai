FactoryBot.define do
  factory :position do
    association :department
    sequence(:title) { |n| "Position #{n}" }
    sequence(:level) { |n| n }
    description { "Test position description" }

    trait :with_parent do
      transient do
        parent_level { nil }
      end

      after(:build) do |position, evaluator|
        parent = create(:position, department: position.department, level: evaluator.parent_level || (position.level + 1))
        position.parent_position = parent
      end
    end

    trait :with_subordinate do
      after(:create) do |position|
        create(:position, parent_position: position, department: position.department, level: position.level - 1)
      end
    end

    trait :with_employees do
      after(:create) do |position|
        create_list(:employee, 2, position: position)
      end
    end

    trait :with_hierarchy do
      after(:create) do |position|
        subordinate = create(:position, :with_employees, parent_position: position, 
                           department: position.department, level: position.level - 1)
        create(:position, parent_position: subordinate, department: position.department, 
               level: subordinate.level - 1)
      end
    end
  end
end 