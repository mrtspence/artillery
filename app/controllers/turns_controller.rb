class TurnsController < ApplicationController
  before_action :set_match
  before_action :set_match_player

  rescue_from MatchException, with: :handle_match_exception

  def create
    # TODO: Integrate with ballistic engine to calculate result_data
    # For now, accepting result_data from params for testing
    input_data = turn_params[:input_data] || {}
    result_data = turn_params[:result_data] || {}

    @turn = @match.submit_turn!(@match_player, input_data, result_data)

    respond_to do |format|
      format.html { redirect_to @match, notice: "Turn submitted!" }
      format.turbo_stream
    end
  end

  private

  def set_match
    @match = Match.find(params[:match_id])
  end

  def set_match_player
    # TODO: Get current_player from session/authentication
    # For now, using player_id from params for testing
    if params[:player_id]
      player = Player.find(params[:player_id])
      @match_player = @match.match_players.find_by!(player: player)
    end
  end

  def turn_params
    params.require(:turn).permit(:input_data, :result_data)
  end

  def handle_match_exception(exception)
    respond_to do |format|
      format.html { redirect_to @match, alert: exception.message }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { alert: exception.message }) }
    end
  end
end
