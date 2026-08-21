# frozen_string_literal: true

module Automator
  module Actions
    module EmailAction
      module_function

      def call(action, payload, job = nil)
        opts = Interpolator.call(action.options || {}, payload)
        context = { action: action, job: job, flow: action.flow }

        if Automator.config.email_sender
          Automator.config.email_sender.call(opts, payload, context)
          return true
        end

        mailer = Automator.config.resolve_mailer(action)
        raise "Automator mailer is not configured" unless mailer

        method_name = (opts["action"] || opts["template"] || "notify").to_s
        raise "Mailer #{mailer} does not implement ##{method_name}" unless mailer.respond_to?(method_name)

        kwargs = {
          to: opts["to"],
          subject: opts["subject"],
          template: opts["template"],
          vars: opts["vars"] || {},
          payload: payload,
          record: Payload.reload_record(payload)
        }.compact

        message =
          if mailer.method(method_name).arity == 0
            mailer.public_send(method_name)
          else
            begin
              mailer.public_send(method_name, **kwargs)
            rescue ArgumentError
              mailer.public_send(method_name, kwargs)
            end
          end

        deliver = Automator.config.email_deliver_later ? :deliver_later : :deliver_now
        if message.respond_to?(deliver)
          message.public_send(deliver)
        elsif message.respond_to?(:deliver_now)
          message.deliver_now
        end
        true
      end
    end
  end
end
