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

    trait :manager do
      after(:build) do |employee|
        # Ensure manager has a position with level > 1 so subordinates can have level >= 1
        employee.position = create(:position, department: employee.position.department, level: 3)
      end
      
      after(:create) do |employee|
        # Create subordinate positions with lower level
        subordinate_position = create(:position, 
                                    department: employee.position.department,
                                    level: employee.position.level - 1)
        # Create a few subordinates for this manager
        create_list(:employee, 3, manager: employee, position: subordinate_position)
      end
    end

    trait :senior_manager do
      manager
      after(:create) do |employee|
        # Create manager positions with lower level
        manager_position = create(:position, 
                                department: employee.position.department,
                                level: employee.position.level - 1)
        # Create managers reporting to this senior manager
        create_list(:employee, 2, :manager, manager: employee, position: manager_position)
      end
    end
  end
end 