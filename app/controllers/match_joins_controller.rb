class MatchJoinsController < ApplicationController
  rescue_from MatchException, with: :handle_match_exception
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

  def create
    # Find match by lobby code
    @match = Match.find_by!(lobby_code: params[:lobby_code]&.upcase)

    # TODO: Get current_player from session/authentication
    # For now, we'll need player_id and loadout_id params for testing
    if params[:player_id] && params[:loadout_id]
      player = Player.find(params[:player_id])
      loadout = PlayerLoadout.find(params[:loadout_id])
      @match.add_player!(player, loadout)
    end

    respond_to do |format|
      format.html { redirect_to @match, notice: "Joined match!" }
      format.turbo_stream
    end
  end

  private

  def handle_match_exception(exception)
    respond_to do |format|
      format.html { redirect_to matches_path, alert: exception.message }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { alert: exception.message }) }
    end
  end

  def handle_not_found(exception)
    respond_to do |format|
      format.html { redirect_to matches_path, alert: "Match not found with code: #{params[:lobby_code]}" }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { alert: "Match not found" }) }
    end
  end
end
