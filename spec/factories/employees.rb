FactoryBot.define do
  factory :employee do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.email }
    association :position
    association :user

    trait :with_manager do
      association :manager, factory: :employee
    end

    trait :with_subordinates do
      after(:create) do |employee|
        create_list(:employee, 2, manager: employee)
      end
    end
  end
end 