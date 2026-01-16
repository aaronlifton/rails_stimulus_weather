class ForecastsController < ApplicationController
  def index
    respond_to do |format|
      # Frontend weather page
      format.html { render }
      # Public API which returns forecast data
      format.json do
        # Address is required for getting the user's weather forecast
        address = index_params[:address]
        unless address.present?
          return render(json: {error: "address parameter is required", code: :address_required}, status: :bad_request)
        end

        begin
          forecast = ForecastService.get_forecast(address)
        rescue BaseApi::Error => e
          # Handle known service class errors, that have frontend recognizable codes and possibly reasons.
          # Service class errors extend BaseApi::Error, so they are all rescued here.
          return render(
            json: {error: {message: e.message, code: e.code, reasons: e.reasons || []}},
            status: :internal_server_error
          )
        rescue StandardError => e
          # Catch-all for unknown errors
          return render(json: {error: {message: e.message, code: :unknown_error}}, status: :internal_server_error)
        end

        render(json: forecast, status: :ok)
      end
    end
  end

  private

  def index_params
    params.permit(:address)
  end
end
