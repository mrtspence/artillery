# frozen_string_literal: true

require "test_helper"

RSpec.describe Map, type: :model do
  describe "associations" do
    subject { create(:match).map }

    it { is_expected.to belong_to(:match) }
    it { is_expected.to have_many(:map_targets).dependent(:destroy) }
  end

  describe "validations" do
    subject { create(:match).map }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:width) }
    it { is_expected.to validate_numericality_of(:width).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:height) }
    it { is_expected.to validate_numericality_of(:height).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:terrain_data) }
  end
end
