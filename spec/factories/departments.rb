FactoryBot.define do
  factory :department do
    sequence(:name) { |n| "Department #{n}" }
    description { "Description for #{name}" }
    parent_department { nil }
    manager { nil }

    trait :with_parent do
      after(:build) do |department|
        parent = create(:department) unless department.parent_department
        department.parent_department = parent
      end
    end

    trait :with_manager do
      after(:build) do |department|
        position = create(:position, department: department)
        department.manager = create(:employee, position: position)
      end
    end

    trait :with_employees do
      after(:create) do |department|
        create_list(:position, 2, department: department).each do |position|
          create_list(:employee, 2, position: position)
        end
      end
    end
  end
end 