class ForecastsController < ApplicationController
  def index
    respond_to do |format|
      format.html { render }
      format.json do
        zipcode = index_params[:zipcode]
        unless zipcode.present?
          render(json: {error: "zip_code parameter is required", code: :missing_zip_code}, status: :bad_request)
          next
        end

        forecast = ForecastService.get_forecast(zipcode)
        render(json: forecast, status: :ok)
      end
    end
  end

  private

  def index_params
    params.permit(:zipcode)
  end
end
