# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Automator
  module Notifiers
    class Webhook
      def initialize(url: Automator.config.webhook_url)
        @url = url
      end

      def deliver(job_or_payload, event: FIRED, url: nil)
        target = url.presence || @url
        return false if target.nil? || target.to_s.strip.empty?

        body = Notifiers.payload(job_or_payload, event: event)
        response = post_json(target, body)
        success = response.is_a?(Net::HTTPSuccess)
        unless success
          Automator.logger.warn("[Automator] Webhook failed: HTTP #{response&.code} #{response&.body}")
        end
        success
      rescue StandardError => e
        Automator.logger.warn("[Automator] Webhook error: #{e.message}")
        false
      end

      private

      def post_json(url, payload)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 5
        http.read_timeout = 10

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "automator/#{Automator::VERSION}"
        request.body = JSON.generate(payload)
        http.request(request)
      end
    end
  end
end
