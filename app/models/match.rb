class Match < ApplicationRecord
  # Constants
  MIN_PLAYERS = 2
  MAX_PLAYERS = 8

  # Associations
  belongs_to :current_player, class_name: 'Player', optional: true
  has_one :match_state, dependent: :destroy
  has_one :map, dependent: :destroy
  has_many :match_players, dependent: :destroy
  has_many :players, through: :match_players
  has_many :turns, dependent: :destroy

  # Validations
  validates :status, presence: true, inclusion: { in: %w[setup in_progress completed abandoned] }
  validates :lobby_code, presence: true, uniqueness: true, length: { is: 6 }

  # Callbacks
  before_validation :generate_lobby_code, on: :create
  after_create :initialize_match_state
  after_create :initialize_map

  # Scopes
  scope :in_setup, -> { where(status: 'setup') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :active, -> { where(status: %w[setup in_progress]) }

  # Public methods

  def add_player!(player, loadout, is_host: false)
    raise MatchException, "Match is not in setup phase" unless status == 'setup'
    raise MatchException, "Match is full" if match_players.count >= MAX_PLAYERS
    raise MatchException, "Player already in match" if players.include?(player)

    turn_order = match_players.count
    match_players.create!(
      player: player,
      player_loadout: loadout,
      turn_order: turn_order,
      is_host: is_host
    )
  end

  def start!
    raise MatchException, "Match already started" unless status == 'setup'
    raise MatchException, "Need at least #{MIN_PLAYERS} players" if match_players.count < MIN_PLAYERS

    transaction do
      # Set first player in turn order as current player
      first_player = match_players.by_turn_order.first
      update!(status: 'in_progress', current_player: first_player.player)
    end
  end

  def complete!
    raise MatchException, "Match is not in progress" unless status == 'in_progress'
    update!(status: 'completed')
  end

  def abandon!
    raise MatchException, "Match already completed" if status == 'completed'
    update!(status: 'abandoned')
  end

  # TODO: Integrate with ballistic engine (ballistic_3d or future engines)
  # Currently this method accepts pre-calculated input_data and result_data
  # Future enhancement: Call engine here and calculate trajectory/hits
  # The result_data should contain the full ballistic calculation results
  # Points calculation should happen externally and be passed in via result_data[:points]
  def submit_turn!(match_player, input_data, result_data)
    raise MatchException, "Match is not in progress" unless status == 'in_progress'
    raise MatchException, "Not this player's turn" unless current_player == match_player.player

    transaction do
      # Create the turn record with final calculated points
      # Note: We don't track individual target hits here - just final score
      turn = turns.create!(
        match_player: match_player,
        turn_number: match_state.current_turn_number,
        input_data: input_data,
        result_data: result_data,
        points_earned: result_data[:points] || 0
      )

      # Update player score if points earned
      if turn.points_earned > 0
        match_player.increment!(:score, turn.points_earned)
      end

      # Advance to next player
      advance_to_next_player!

      turn
    end
  end

  def advance_to_next_player!
    current_match_player = match_players.find_by(player: current_player)
    next_match_player = match_players.by_turn_order
                                     .where('turn_order > ?', current_match_player.turn_order)
                                     .first

    # If we've cycled through all players, increment turn and start over
    if next_match_player.nil?
      match_state.increment_turn!
      next_match_player = match_players.by_turn_order.first

      # Check if game is over
      if match_state.game_over?
        complete!
        return
      end
    end

    update!(current_player: next_match_player.player)
  end

  def current_match_player
    match_players.find_by(player: current_player)
  end

  private

  def generate_lobby_code
    return if lobby_code.present?

    loop do
      self.lobby_code = SecureRandom.alphanumeric(6).upcase
      break unless Match.exists?(lobby_code: lobby_code)
    end
  end

  def initialize_match_state
    create_match_state!(
      current_turn_number: 0,
      turn_limit: 10
    )
  end

  def initialize_map
    create_map!(
      name: "Default Map",
      width: 1000,
      height: 1000,
      terrain_data: { type: 'flat' }
    )
  end
end
