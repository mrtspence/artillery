FactoryBot.define do
  factory :map do
    match { nil }
    name { "MyString" }
    width { 1 }
    height { 1 }
    terrain_data { "" }
  end
end
