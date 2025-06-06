FactoryBot.define do
  factory :permission do
    association :user
    resource { 'department' }  # Default to department
    action { 'read' }         # Default to read
    resource_id { create(:department).id }  # Default to a department id

    trait :global do
      action { 'manage' }
      resource_id { nil }
    end

    trait :department do
      resource { 'department' }
      resource_id { create(:department).id }
    end

    trait :position do
      resource { 'position' }
      resource_id { create(:position).id }
    end

    trait :employee do
      resource { 'employee' }
      resource_id { create(:employee).id }
    end

    trait :user do
      resource { 'user' }
      resource_id { create(:user).id }
    end
  end
end 