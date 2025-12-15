class MatchesController < ApplicationController
  before_action :set_match, only: [:show]

  rescue_from MatchException, with: :handle_match_exception

  def index
    @active_matches = Match.active.includes(:players, :match_state)
  end

  def show
    @match_players = @match.match_players.by_turn_order.includes(:player, :player_loadout)
    @current_match_player = @match.current_match_player if @match.current_player
    @map = @match.map
    @turns = @match.turns.by_turn_number.includes(:match_player).limit(10)
  end

  def new
    @match = Match.new
    # TODO: Load available player loadouts for current user
  end

  def create
    @match = Match.create!

    # TODO: Get current_player from session/authentication
    # For now, we'll need a player_id param for testing
    if params[:player_id] && params[:loadout_id]
      player = Player.find(params[:player_id])
      loadout = PlayerLoadout.find(params[:loadout_id])
      @match.add_player!(player, loadout, is_host: true)
    end

    respond_to do |format|
      format.html { redirect_to @match, notice: "Match created! Lobby code: #{@match.lobby_code}" }
      format.turbo_stream
    end
  end

  private

  def set_match
    @match = Match.find(params[:id])
  end

  def handle_match_exception(exception)
    flash.now[:alert] = exception.message
    render :new, status: :unprocessable_entity
  end
end
