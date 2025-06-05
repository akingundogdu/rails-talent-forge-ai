FactoryBot.define do
  factory :department do
    sequence(:name) { |n| "Department #{n}" }
    description { "Test department description" }

    trait :with_parent do
      association :parent_department, factory: :department
    end

    trait :with_manager do
      association :manager, factory: :employee
    end
  end
end 