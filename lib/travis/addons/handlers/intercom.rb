require 'travis/addons/handlers/base'
require 'travis/addons/handlers/task'

module Travis
  module Addons
    module Handlers
      class Intercom < Notifiers
        EVENTS = 'build:finished'
        KEY = :intercom

        class Notifier < Notifier
          def setup
            Raven.capture do
              "Intercom addon setup"
            end
          end

          def handle?
            p "handle? call"
            p payload
            payload.owner && payload.owner.type.downcase == 'user' # currently Intercom makes sense only for users, not for orgs
          end

          def handle
            p "handle call"
            run_task(:intercom, payload)
          end

          class Instrument < Addons::Instrument
            def notify_completed
              p "publish call"
              publish
            end
          end
          Instrument.attach_to(self)
        end
      end
    end
  end
end
