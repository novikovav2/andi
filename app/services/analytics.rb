# app/services/analytics.rb

class Analytics
  def self.track(event_type, eventable: nil, metadata: {})
    AnalyticsEvent.create!(
      event_type: event_type,
      eventable: eventable,
      metadata: metadata
    )
  rescue => e
    Rails.logger.error("Analytics error: #{e.message}")
  end
end