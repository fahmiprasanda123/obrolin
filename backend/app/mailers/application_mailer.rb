class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Obrolin <no-reply@obrolin.local>")
  layout "mailer"
end
