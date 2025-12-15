# frozen_string_literal: true

FactoryBot.define do
  factory :player do
    sequence(:username) { |n| "player_#{n}" }
  end
end
