class ForecastsController < ApplicationController
  def index
    zipcode = index_params[:zipcode]
    if !zipcode.present?
      return render(json: {error: "zip_code parameter is required"}, status: :bad_request)
    end

    forecast = ForecastService.get_forecast(zipcode)
    render(json: forecast.to_json, status: :ok)
  end

  private

  def index_params
    params.permit(:zipcode)
  end
end
