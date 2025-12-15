# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /matches/:match_id/abandon", type: :request do
  describe "create" do
    let(:match) { create(:match, status: 'setup') }

    it "abandons the match" do
      post match_abandon_path(match)
      expect(match.reload.status).to eq('abandoned')
    end

    it "redirects to matches index" do
      post match_abandon_path(match)
      expect(response).to redirect_to(matches_path)
    end

    it "sets a success notice" do
      post match_abandon_path(match)
      expect(flash[:notice]).to eq("Match abandoned")
    end

    context "when match is already completed" do
      let(:match) { create(:match, status: 'completed') }

      it "does not abandon the match" do
        post match_abandon_path(match)
        expect(match.reload.status).to eq('completed')
      end

      it "sets an error alert" do
        post match_abandon_path(match)
        expect(flash[:alert]).to include("already completed")
      end
    end
  end
end
