class ForecastsController < ApplicationController
  def index
    respond_to do |format|
      format.html { render }
      format.json do
        address = index_params[:address]
        unless address.present?
          return render(json: {error: "address parameter is required", code: :address_required}, status: :bad_request)
        end

        begin
          forecast = ForecastService.get_forecast(address)
        rescue WeatherApi::Error, GeocoderApi::Error => e
          return render(
            json: {error: {message: e.message, code: e.code, reasons: e.reasons || []}},
            status: :internal_server_error
          )
        rescue StandardError => e
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
