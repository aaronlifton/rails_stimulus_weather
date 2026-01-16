import { Controller } from "@hotwired/stimulus";

class ForecastController extends Controller {
  static targets = [
    "form",
    "address",
    "submit",
    "error",
    "result",
    "currentTemp",
    "cacheIndicator",
  ];
  static errors = {
    address_required: "Address is required",
    address_not_found:
      "Address not found. Please ensure you added the city and state, and optionally zipcode.",
    parse_geocode_response_failure: "Unable to load forecast",
    unknown_error: "Unable to load forecast",
    geocode_address_errors:
      "Unable to load forecast. Please check the address and try again.",
  };

  connect() {
    this.clearError();
  }

  submit(event) {
    event.preventDefault();
    this.fetchForecast();
  }

  async fetchForecast() {
    const address = this.addressTarget.value.trim();
    if (!address) {
      this.showError(ForecastController.errors.address_required);
      return;
    }

    const url = new URL("/forecasts", window.location.origin);
    url.searchParams.set("address", address);

    this.clearError();

    try {
      this.submitTarget.disabled = true;
      this.currentTempTarget.textContent = "--";
      this.showCacheIndicator(false);

      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
      });
      const data = await response.json();

      if (response.ok) {
        this.updateResult(data);
      } else {
        this.showError(
          ForecastController.errors[data?.error?.code || "unknown_error"],
        );
      }
    } catch (error) {
      console.debug(error);

      this.showError(ForecastController.errors.unknown_error);
    } finally {
      this.submitTarget.disabled = false;
    }
  }

  updateResult(data) {
    this.currentTempTarget.textContent = this.formatTemp(
      data.temperature_current,
    );
    if (data.cached) {
      this.showCacheIndicator(true);
    }
  }

  formatTemp(value) {
    // Prevent 0 from showing as "--" (Would happen with !value)
    if (value === null || value === undefined || value === "") return "--";
    const number = Number(value);
    return Number.isNaN(number) ? "--" : Math.round(number);
  }

  showError(message) {
    if (!this.hasErrorTarget) return;

    this.errorTarget.textContent = message;
    this.errorTarget.classList.remove("hidden");
  }

  clearError() {
    if (!this.hasErrorTarget) return;

    this.errorTarget.textContent = "";
    this.errorTarget.classList.add("hidden");
  }

  showCacheIndicator(show) {
    if (!this.hasCacheIndicatorTarget) return;

    if (show) {
      this.cacheIndicatorTarget.classList.remove("hidden");
    } else {
      this.cacheIndicatorTarget.classList.add("hidden");
    }
  }
}

export default ForecastController;
