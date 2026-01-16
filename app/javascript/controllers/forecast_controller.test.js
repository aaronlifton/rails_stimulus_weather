import { Application } from "@hotwired/stimulus";
import ForecastController from "./forecast_controller";

const getTargetElement = (name) => {
  return document.querySelector(`[data-forecast-target='${name}']`);
};

describe("ForecastController", () => {
  let controller;

  beforeEach(async () => {
    document.body.innerHTML = `
      <div data-controller="forecast">
        <form data-forecast-target="form">
          <input data-forecast-target="address">
          <button data-forecast-target="submit"></button>
        </form>
        <div data-forecast-target="error" class="hidden"></div>
        <div>
          <span data-forecast-target="currentTemp"></span>
        </div>
      </div>
      `;

    const application = Application.start();
    application.register("forecast", ForecastController);

    // Need to wait for a tick for stimulus to instantiate
    await new Promise((resolve) => setTimeout(resolve, 0));

    const element = document.querySelector("[data-controller='forecast']");
    controller = application.getControllerForElementAndIdentifier(
      element,
      "forecast",
    );

    global.fetch = jest.fn();
  });

  describe("DOM interactions", () => {
    it("should fetch forecast and update DOM on form submission", async () => {
      const address = "4600 Silver Hill Rd, Washington, DC";
      const addressParam = new URLSearchParams();
      addressParam.append("address", address);

      const currentTemp = 79;
      const addressInput = getTargetElement("address");

      addressInput.value = address;

      const mockFetch = jest.fn().mockResolvedValue({
        status: 200,
        ok: true,
        json: jest.fn().mockResolvedValue({ temperature_current: currentTemp }),
      });
      global.fetch = mockFetch;

      const currentTempSpan = getTargetElement("currentTemp");
      expect(currentTempSpan.textContent).toHaveLength(0);

      await controller.fetchForecast();

      expect(global.fetch).toHaveBeenCalledWith(
        `http://localhost/forecasts?${addressParam}`,
        { headers: { Accept: "application/json" } },
      );
      expect(currentTempSpan.textContent).toBe(currentTemp.toString());
    });

    it("should display errors based on error codes from the backend", async () => {
      const address = "4600 Silver Hill Rd, Washington, DC";
      const addressParam = new URLSearchParams();
      addressParam.append("address", address);

      const addressInput = getTargetElement("address");

      addressInput.value = address;

      const mockFetch = jest.fn().mockResolvedValue({
        status: 400,
        ok: false,
        json: jest.fn().mockResolvedValue({
          error: {
            message: "api error message",
            code: "address_required",
          },
        }),
      });
      global.fetch = mockFetch;

      const errorDiv = getTargetElement("error");
      expect(errorDiv.textContent).toHaveLength(0);

      await controller.fetchForecast();

      expect(global.fetch).toHaveBeenCalledWith(
        `http://localhost/forecasts?${addressParam}`,
        { headers: { Accept: "application/json" } },
      );

      expect(errorDiv.textContent).toEqual(
        ForecastController.errors.address_required,
      );
    });
  });
});
