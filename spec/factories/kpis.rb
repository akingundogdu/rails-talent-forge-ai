FactoryBot.define do
  factory :kpi do
    association :employee
    sequence(:name) { |n| "KPI #{n}" }
    description { "Test KPI description for measuring performance" }
    target_value { 100.0 }
    actual_value { 75.0 }
    measurement_unit { :number }
    period_start { Date.current.beginning_of_month }
    period_end { Date.current.end_of_month }
    status { :active }

    trait :currency_kpi do
      measurement_unit { :currency }
      name { "Revenue Generation" }
      description { "Total revenue generated in the measurement period." }
      target_value { 25000.0 }
      actual_value { 22500.0 }
    end

    trait :percentage_kpi do
      measurement_unit { :percentage }
      name { "Customer Retention Rate" }
      description { "Percentage of customers retained over the measurement period." }
      target_value { 90.0 }
      actual_value { 87.5 }
    end

    trait :hours_kpi do
      measurement_unit { :hours }
      name { "Training Hours Completed" }
      description { "Total professional development hours completed." }
      target_value { 40.0 }
      actual_value { 35.0 }
    end

    trait :days_kpi do
      measurement_unit { :days }
      name { "Average Resolution Time" }
      description { "Average time to resolve customer support tickets." }
      target_value { 2.0 }
      actual_value { 3.5 }
      is_higher_better { false }
    end

    trait :ratio_kpi do
      measurement_unit { :ratio }
      name { "Conversion Rate" }
      description { "Lead to customer conversion ratio." }
      target_value { 0.15 }
      actual_value { 0.12 }
    end

    trait :count_kpi do
      measurement_unit { :count }
      name { "New Clients Acquired" }
      description { "Number of new clients acquired in the period." }
      target_value { 5.0 }
      actual_value { 7.0 }
    end

    # Achievement level traits
    trait :poor_performance do
      actual_value { target_value * 0.3 }
    end

    trait :below_average_performance do
      actual_value { target_value * 0.6 }
    end

    trait :average_performance do
      actual_value { target_value * 0.8 }
    end

    trait :good_performance do
      actual_value { target_value * 0.95 }
    end

    trait :excellent_performance do
      actual_value { target_value * 1.2 }
    end

    # Measurement period traits
    trait :daily do
      measurement_period { :daily }
      name { "Daily Task Completion" }
      description { "Number of tasks completed per day." }
      target_value { 8.0 }
      actual_value { 7.0 }
      measurement_unit { :count }
    end

    trait :weekly do
      measurement_period { :weekly }
      name { "Weekly Code Reviews" }
      description { "Number of code reviews completed per week." }
      target_value { 10.0 }
      actual_value { 12.0 }
      measurement_unit { :count }
    end

    trait :monthly do
      measurement_period { :monthly }
      name { "Monthly Sales Target" }
      description { "Monthly sales revenue target achievement." }
      target_value { 50000.0 }
      actual_value { 48000.0 }
      measurement_unit { :currency }
    end

    trait :quarterly do
      measurement_period { :quarterly }
      name { "Quarterly Growth Rate" }
      description { "Revenue growth percentage per quarter." }
      target_value { 15.0 }
      actual_value { 18.5 }
      measurement_unit { :percentage }
      period_start { Date.current.beginning_of_quarter }
      period_end { Date.current.end_of_quarter }
    end

    trait :annually do
      measurement_period { :annually }
      name { "Annual Performance Score" }
      description { "Overall annual performance rating." }
      target_value { 4.0 }
      actual_value { 4.2 }
      measurement_unit { :ratio }
    end

    # Specialized KPI types
    trait :sales_kpi do
      name { "Monthly Sales Revenue" }
      description { "Total sales revenue generated monthly." }
      measurement_unit { :currency }
      measurement_period { :monthly }
      target_value { 75000.0 }
      actual_value { 72000.0 }
      is_higher_better { true }
    end

    trait :quality_kpi do
      name { "Bug Resolution Rate" }
      description { "Percentage of bugs resolved within SLA." }
      measurement_unit { :percentage }
      measurement_period { :weekly }
      target_value { 95.0 }
      actual_value { 92.0 }
      is_higher_better { true }
    end

    trait :efficiency_kpi do
      name { "Task Completion Time" }
      description { "Average time to complete assigned tasks." }
      measurement_unit { :hours }
      measurement_period { :weekly }
      target_value { 4.0 }
      actual_value { 5.2 }
      is_higher_better { false }
    end

    trait :customer_satisfaction_kpi do
      name { "Customer Satisfaction Score" }
      description { "Average customer satisfaction rating." }
      measurement_unit { :ratio }
      measurement_period { :monthly }
      target_value { 4.5 }
      actual_value { 4.3 }
      is_higher_better { true }
    end

    trait :innovation_kpi do
      name { "Process Improvements Implemented" }
      description { "Number of process improvements successfully implemented." }
      measurement_unit { :count }
      measurement_period { :quarterly }
      target_value { 3.0 }
      actual_value { 4.0 }
      is_higher_better { true }
    end

    # Factory for standalone KPIs (not tied to performance reviews)
    factory :standalone_kpi do
      performance_review { nil }
      name { "Individual Performance Metric" }
      description { "Personal performance tracking metric." }
    end

    # Factory for department benchmarking
    factory :benchmarked_kpi do
      name { "Department Average KPI" }
      description { "KPI measured against department average." }
      
      after(:create) do |kpi|
        # Create some department peers for benchmarking
        3.times do
          peer = create(:employee, department: kpi.employee.department, position: kpi.employee.position)
          create(:kpi, 
            employee: peer, 
            name: kpi.name,
            measurement_unit: kpi.measurement_unit,
            target_value: kpi.target_value,
            actual_value: kpi.target_value * rand(0.7..1.3)
          )
        end
      end
    end
  end
end 