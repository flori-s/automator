# frozen_string_literal: true

module Automator
  module Actions
    module EmailAction
      module_function

      def call(action, payload, _job = nil)
        opts = Interpolator.call(action.options || {}, payload)
        message = build_message(action, opts, payload)

        if (delivery = resolve_email_delivery(action))
          invoke_delivery(delivery, message)
        else
          deliver_via_mailer(action, message, opts)
        end

        true
      end

      def build_message(action, opts, payload)
        {
          action: (opts["action"] || opts["template"] || "notify").to_s,
          to: opts["to"],
          subject: opts["subject"],
          template: opts["template"],
          vars: opts["vars"] || {},
          body: opts["body"],
          from: opts["from"],
          cc: opts["cc"],
          bcc: opts["bcc"],
          attachments: opts["attachments"],
          options: opts,
          payload: payload,
          record: Payload.reload_record(payload),
          flow_action: action
        }.compact
      end

      def resolve_email_delivery(action)
        override = action&.options.is_a?(Hash) && action.options["email_delivery"]
        raw = override.presence || Automator.config.email_delivery
        case raw
        when nil then nil
        when Proc then raw
        when String, Symbol then raw.to_s.constantize
        when Class then raw
        else
          raw
        end
      end

      def invoke_delivery(delivery, message)
        if delivery.respond_to?(:call)
          delivery.call(message)
        elsif delivery.respond_to?(:deliver)
          delivery.deliver(message)
        else
          raise ArgumentError, "Automator email_delivery must respond to #call or #deliver"
        end
      end

      def deliver_via_mailer(action, message, opts)
        mailer = Automator.config.resolve_mailer(action)
        raise "Automator mailer is not configured (set c.mailer or c.email_delivery)" unless mailer

        method_name = message[:action].to_s
        raise "Mailer #{mailer} does not implement ##{method_name}" unless mailer.respond_to?(method_name)

        kwargs = message.slice(:to, :subject, :template, :vars, :payload, :record, :body, :from, :cc, :bcc, :attachments)

        mail_message =
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
        if mail_message.respond_to?(deliver)
          mail_message.public_send(deliver)
        elsif mail_message.respond_to?(:deliver_now)
          mail_message.deliver_now
        elsif mail_message.respond_to?(:deliver)
          mail_message.deliver
        end
      end
    end
  end
end
