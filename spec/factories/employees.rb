FactoryBot.define do
  factory :employee do
    sequence(:first_name) { |n| "First#{n}" }
    sequence(:last_name) { |n| "Last#{n}" }
    sequence(:email) { |n| "employee#{n}@example.com" }
    association :position
    association :user

    trait :with_manager do
      after(:build) do |employee|
        manager = create(:employee, position: create(:position, department: employee.position.department))
        employee.manager = manager
      end
    end

    trait :with_subordinate do
      after(:create) do |employee|
        create(:employee, manager: employee, position: create(:position, department: employee.position.department))
      end
    end

    trait :with_subordinates do
      after(:create) do |employee|
        create_list(:employee, 2, manager: employee, position: create(:position, department: employee.position.department))
      end
    end

    trait :with_hierarchy do
      after(:create) do |employee|
        subordinate = create(:employee, :with_subordinates, manager: employee, 
                           position: create(:position, department: employee.position.department))
        create(:employee, manager: subordinate, 
               position: create(:position, department: employee.position.department))
      end
    end
  end
end 