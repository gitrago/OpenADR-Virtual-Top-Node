require 'action_view'

class EventObserver < ActiveRecord::Observer
  include EventHelper
  include ActionView::Helpers::TextHelper

  def after_create(event)
    reply_with format_to_str(event), ENV['MATTERMOST_EVENT_CHANNEL']
  end

  private

    def format_to_str(event)
      str = []
      event.reload

      str << "##### Event: ##{event.event_id}"
      str << "**#{event.dtstart.in_time_zone(event.time_zone).strftime("%A, %b %e %Y")}**"
      str << "#{ event.dtstart.in_time_zone(event.time_zone).strftime("%-l:%M%P") } - #{ event.dtend.in_time_zone(event.time_zone).strftime("%-l:%M%P (%Z)") } - #{minutes_to_words(event.duration)}"
      str << ""
      str << "Status: #{event.event_status.name}"
      str << "Targetted Devices: #{event.vens.count}"
      str << "Market Context: #{event.market_context.name}"
      str << "Comment: #{event.vtn_comment}"

      str.join("  \n")
    end

    def reply_with(message, channel_id = nil)
      post = { message: message, channel_id: channel_id }
      headers = { 'content_type' => 'application/json', 'Authorization' => "Bearer #{ENV['MATTERMOST_BOT_TOKEN']}" }

      url = "#{ENV['MATTERMOST_SERVER_URL']}/api/v4/posts"
      res = agent.post(url, body: post.to_json, header: headers)

      res
    end

    # NOTE: Fixup needed to allow communication on deprecated
    #       ciphers required for this integration with Google APIs
    def agent(version = 'TLSv1.2', ciphers = nil)
      client = HTTPClient.new
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      client.ssl_config.ssl_version = version
      client.ssl_config.ciphers = ciphers if ciphers.present?
      client
    end
end