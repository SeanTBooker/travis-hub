require 'travis/addons/handlers/base'
require 'travis/addons/config'

module Travis
  module Addons
    module Handlers
      class Billing < Base
        EVENTS = /job:(canceled|finished)/.freeze
        KEY = :billing

        MSGS = {
          failed: 'Failed to push stats to billing-v2: %s'
        }

        def handle?
          billing_url && billing_auth
        end

        def handle
          publish
        end

        private

        def billing_url
          @billing_url ||= Travis::Hub.context.config.billing.url if Travis::Hub.context.config.billing
        end

        def billing_auth
          @billing_auth ||= Travis::Hub.context.config.billing.auth if Travis::Hub.context.config.billing
        end

        def publish
          send_usage(data)
        rescue => e
          logger.error MSGS[:failed] % e.message
        end

        def send_usage(data)
          response = connection.post('/usage/executions', data)
          handle_usage_executions_response(response)
        end

        def data
          @data ||= serialize_data
        end

        def serialize_data
          {
            job: job_data,
            repository: repository_data,
            owner: owner_data,
            build: build_data
          }
        end

        def job_data
          {
            id: object.id,
            os: nil, # TODO
            instance_size: nil, # TODO
            arch: nil, # TODO
            started_at: object.started_at,
            finished_at: object.finished_at,
            virt_type: nil, # TODO
            queue: object.queue
          }
        end

        def repository_data
          {
            id: repository.id,
            slug: repository.slug,
            private: repository.private
          }
        end

        def owner_data
          {
            type: object.owner_type,
            id: object.owner_id,
            login: object.owner ? object.owner.login : nil
          }
        end

        def build_data
          {
            id: object.build.id,
            type: object.build.event_type,
            number: object.build.number,
            branch: object.build.branch,
            sender: build_data_sender
          }
        end

        def build_data_sender
          {
            id: object.build.sender_id,
            type: object.build.sender_type
          }
        end

        def connection
          @connection ||= Faraday.new(url: billing_url, ssl: { ca_path: '/usr/lib/ssl/certs' }) do |conn|
            conn.headers['Content-Type'] = 'application/json'
            conn.request :authorization, :token, billing_auth
            conn.request :retry, max: 5, interval: 0.05, interval_randomness: 0.5, backoff_factor: 2
            conn.request :json
            conn.response :json
            conn.adapter :net_http
          end
        end

        def handle_usage_executions_response(response)
          case response.status
          when 404
            raise StandardError, `Not found #{response.body['error']}`
          when 400
            raise StandardError, `Client error #{response.body['error']}`
          when 422
            raise StandardError, `Unprocessable entity #{response.body['error']}`
          else
            raise StandardError, `Server error #{response.body['error']}`
          end
        end

        def logger
          Addons.logger
        end

        # EventHandler
        class EventHandler < Addons::Instrument
          def notify_completed
            publish
          end
        end
        EventHandler.attach_to(self)
      end
    end
  end
end
