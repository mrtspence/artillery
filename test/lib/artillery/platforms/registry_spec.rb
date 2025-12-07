# frozen_string_literal: true

require "test_helper"

RSpec.describe Artillery::Platforms::Registry do
  describe ".register" do
    it "registers a platform class" do
      test_platform = Class.new(Artillery::Platforms::Base)
      described_class.register("test_platform", test_platform)

      expect(described_class.get("test_platform")).to eq(test_platform)
    end

    it "accepts symbol keys" do
      test_platform = Class.new(Artillery::Platforms::Base)
      described_class.register(:test_symbol_platform, test_platform)

      expect(described_class.get(:test_symbol_platform)).to eq(test_platform)
    end
  end

  describe ".get" do
    it "retrieves registered platform" do
      # QF 18-pounder should be pre-registered
      platform = described_class.get("qf_18_pounder")

      expect(platform).to eq(Artillery::Platforms::Qf18Pounder)
    end

    it "raises error for unknown platform" do
      expect {
        described_class.get("nonexistent_platform")
      }.to raise_error(Artillery::Platforms::UnknownPlatformError, /Unknown platform: 'nonexistent_platform'/)
    end
  end

  describe ".all" do
    it "returns all registered platforms" do
      platforms = described_class.all

      expect(platforms).to be_an(Array)
      expect(platforms).to include(Artillery::Platforms::Qf18Pounder)
    end
  end

  describe ".all_keys" do
    it "returns all platform keys" do
      keys = described_class.all_keys

      expect(keys).to be_an(Array)
      expect(keys).to include("qf_18_pounder")
    end
  end

  describe ".registered?" do
    it "returns true for registered platform" do
      expect(described_class.registered?("qf_18_pounder")).to be true
    end

    it "returns false for unregistered platform" do
      expect(described_class.registered?("nonexistent")).to be false
    end

    it "accepts symbol keys" do
      expect(described_class.registered?(:qf_18_pounder)).to be true
    end
  end
end
