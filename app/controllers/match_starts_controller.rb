class MatchStartsController < ApplicationController
  before_action :set_match

  rescue_from MatchException, with: :handle_match_exception

  def create
    @match.start!

    respond_to do |format|
      format.html { redirect_to @match, notice: "Match started!" }
      format.turbo_stream
    end
  end

  private

  def set_match
    @match = Match.find(params[:match_id])
  end

  def handle_match_exception(exception)
    respond_to do |format|
      format.html { redirect_to @match, alert: exception.message }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { alert: exception.message }) }
    end
  end
end
