import { Controller } from "@hotwired/stimulus";

class ForecastController extends Controller {
  static targets = [
    "form",
    "zipcode",
    "submit",
    "error",
    "result",
    "currentTemp",
    "status",
    "cacheIndicator",
  ];
  static errors = {
    missing_zip_code: "ZIP code is required.",
  };

  connect() {
    this.clearError();
    this.setStatus();
  }

  submit(event) {
    event.preventDefault();
    this.fetchForecast();
  }

  async fetchForecast() {
    const zipcode = this.zipcodeTarget.value.trim();
    if (!zipcode) {
      this.showError("ZIP code is required.");
      // return;
    }

    const url = new URL("/forecasts", window.location.origin);
    url.searchParams.set("zipcode", zipcode);

    this.clearError();

    try {
      // Only show loader on slow connections/API calls
      this.onFetch(true);
      const loadingTimeout = setTimeout(() => {
        this.setStatus("Loading...");
      }, 200);

      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
      });
      const data = await response.json();

      window.clearTimeout(loadingTimeout);

      if (response.ok) {
        this.updateResult(data);
      } else {
        this.handleError(data);
      }
    } catch (error) {
      console.debug(error);

      this.handleError();
    } finally {
      this.onFetch(false);
      this.setStatus();
    }
  }

  updateResult(data) {
    this.currentTempTarget.textContent = this.formatTemp(
      data.temperature_current,
    );
    if (data.cached) {
      this.setStatus("cached");
      this.toggleCacheIndicator(true);
    }
  }

  formatTemp(value) {
    // Prevent 0 from showing as "--" (Would happen with !value)
    if (value === null || value === undefined || value === "") return "--";
    const number = Number(value);
    return Number.isNaN(number) ? "--" : Math.round(number);
  }

  onFetch(isLoading) {
    this.submitTarget.disabled = isLoading;
  }

  handleError(error) {
    // console.debug(error);

    if (error?.code && ForecastController.errors[error.code]) {
      this.showError(ForecastController.errors[error.code]);
    } else {
      this.showError("Unable to load forecast.");
    }
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

  setStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message;
    }
  }

  toggleCacheIndicator(show) {
    if (!this.hasCacheIndicatorTarget) return;

    if (show) {
      this.cacheIndicatorTarget.classList.remove("hidden");
    } else {
      this.cacheIndicatorTarget.classList.add("hidden");
    }
  }
}

export default ForecastController;
