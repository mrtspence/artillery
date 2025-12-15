# frozen_string_literal: true

require "test_helper"

RSpec.describe MapTarget, type: :model do
  let(:map) { create(:match).map }

  describe "associations" do
    subject { create(:map_target, map: map) }

    it { is_expected.to belong_to(:map) }
  end

  describe "validations" do
    subject { create(:map_target, map: map) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:target_type) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_presence_of(:points_value) }
    it { is_expected.to validate_numericality_of(:points_value).is_greater_than_or_equal_to(0) }
  end

  describe "scopes" do
    let!(:hit_target) { create(:map_target, map: map, is_hit: true) }
    let!(:unhit_target) { create(:map_target, map: map, is_hit: false) }

    describe ".hit" do
      it "returns only hit targets" do
        expect(MapTarget.hit).to contain_exactly(hit_target)
      end
    end

    describe ".unhit" do
      it "returns only unhit targets" do
        expect(MapTarget.unhit).to contain_exactly(unhit_target)
      end
    end
  end

  describe "#mark_as_hit!" do
    let(:target) { create(:map_target, map: map, is_hit: false) }

    it "marks target as hit" do
      expect {
        target.mark_as_hit!
      }.to change(target, :is_hit).from(false).to(true)
    end

    it "persists the change to the database" do
      target.mark_as_hit!
      expect(target.reload.is_hit).to be true
    end
  end
end
