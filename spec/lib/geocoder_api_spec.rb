require "spec_helper"

require("geocoder_api")

RSpec.describe GeocoderApi do
  subject(:geocoder_api) { described_class.new }

  let(:address) { "4600 Silver Hill Rd, Washington, DC" }
  let(:lat) { -76.927487242301 }
  let(:long) { 38.846016223866 }
  let(:zipcode) { "20233" }

  let(:headers) {
    {
      "Accept" => "*/*",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
      "Content-Type" => "application/json",
      "User-Agent" => "Ruby"
    }
  }
  let(:response_headers) {
    {
      "date" => ["Thu, 15 Jan 2026 22:34:53 GMT"],
      "content-type" => ["application/json"],
      "content-length" => ["701"],
      "connection" => ["close"],
      "x-frame-options" => ["DENY"],
      "cache-control" => ["private, no-store"],
      "strict-transport-security" => ["max-age=31536000"],
      "x-content-type-options" => ["nosniff"],
      "x-xss-protection" => ["1;mode=block"],
      "vary" => ["Origin"],
      "set-cookie" => [
        "TS0193e6a1=01283c52a4d29ddf99b16fb2ff97be5132f35a2c381d544d90bb9beed6598a44d26bb1daf0318aa19f038ac08bed0f9fe6148a3519; Path=/; Domain=.geocoding.geo.census.gov; Secure; HttpOnly"
      ]
    }
  }

  before do
    stub_request(:get, "#{described_class.base_uri}#{described_class::GEOLOCATION_PATH}")
      .with(
        query: {"address" => address, "benchmark" => described_class::DEFAULT_BENCHMARK, "format" => "json"},
        headers: headers
      )
      .to_return(
        {
          body: {
            "result" => {
              "input" => {
                "address" => {
                  "address" => "4600 Silver Hill Rd, Washington, DC"
                },
                "benchmark" => {
                  "isDefault" => true,
                  "benchmarkDescription" => "Public Address Ranges - Current Benchmark",
                  "id" => "4",
                  "benchmarkName" => "Public_AR_Current"
                }
              },
              "addressMatches" => [
                {
                  "tigerLine" => {"side" => "L", "tigerLineId" => "76355984"},
                  "coordinates" => {"x" => long, "y" => lat},
                  "addressComponents" => {
                    "zip" => zipcode,
                    "streetName" => "SILVER HILL",
                    "preType" => "",
                    "city" => "WASHINGTON",
                    "preDirection" => "",
                    "suffixDirection" => "",
                    "fromAddress" => "4600",
                    "state" => "DC",
                    "suffixType" => "RD",
                    "toAddress" => "4700",
                    "suffixQualifier" => "",
                    "preQualifier" => ""
                  },
                  "matchedAddress" => "4600 SILVER HILL RD, WASHINGTON, DC, 20233"
                }
              ]
            }
          }.to_json,
          status: 200,
          headers: response_headers
        }
      )
  end

  it "gets the lat, long, and zipcode" do
    data = geocoder_api.geocode(address)
    expect(data).to(
      eq(
        {
          lat: lat.round(7),
          long: long.round(7),
          zipcode: zipcode
        }
      )
    )
  end

  context("when the api returns an error") do
    before do
      stub_request(:get, "#{described_class.base_uri}#{described_class::GEOLOCATION_PATH}")
        .with(
          query: {"address" => address, "benchmark" => described_class::DEFAULT_BENCHMARK, "format" => "json"},
          headers: headers
        )
        .to_return(
          {
            body: {:"errors" => ["Address cannot be empty and cannot exceed 100 characters"], :"status" => "400"}.to_json,
            status: 400,
            headers: response_headers
          }
        )
    end

    it "handles the error" do
      # Use begin..rescue instead of raise_error() to test error instance variables
      begin
        geocoder_api.geocode(address)
      rescue StandardError => e
        expect(e.class).to(be(described_class::Error))
        expect(e.message).to(eq("Failed to geocode address"))
        expect(e.reasons).to(match_array(["Address cannot be empty and cannot exceed 100 characters"]))
      end
    end
  end

  context("when the api returns no matching adresses") do
    before do
      stub_request(:get, "#{described_class.base_uri}#{described_class::GEOLOCATION_PATH}")
        .with(
          query: {"address" => address, "benchmark" => described_class::DEFAULT_BENCHMARK, "format" => "json"},
          headers: headers
        )
        .to_return(
          {
            body: {
              "result" => {
                "input" => {
                  "address" => {
                    "address" => "4600 Silver Hill Rd, Washington, DC"
                  },
                  "benchmark" => {
                    "isDefault" => true,
                    "benchmarkDescription" => "Public Address Ranges - Current Benchmark",
                    "id" => "4",
                    "benchmarkName" => "Public_AR_Current"
                  }
                },
                "addressMatches" => []
              }
            }.to_json,
            status: 200,
            headers: response_headers
          }
        )
    end

    it "handles the error" do
      # Use begin..rescue instead of raise_error() to test error instance variables
      begin
        geocoder_api.geocode(address)
      rescue StandardError => e
        expect(e.class).to(be(described_class::Error))
        expect(e.message).to(eq("No matches found for address"))
        expect(e.code).to(eq(:address_not_found))
      end
    end
  end
end
