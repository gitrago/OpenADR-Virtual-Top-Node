class MattermostController < BaseController
  skip_before_filter :verify_authenticity_token

  def lfs
    check(:lfs) do |method, params|
      res = EpriSheet::Bot.send(method, params)
      res && res.key?(:error) ? res[:error] : ''
    end
  end

  def schedules
    text = "I found the following TOU Schedules:  \n"
    check(:schedules) do |method, params|
      TouSchedule.find_each do |ts|
        text += "- [#{ts.id}] #{ts.name}  \n"
      end

      "#{text}\nYou can grab more details about a TOU Schedule by issuing `/schedule [id]`."
    end
  end

  def schedule
    check(:schedule_id) do |method, params|
      scope = TouSchedule.includes(:payload_unit, :target, :market_context)

      if (ts = scope.find(params['text'].to_i))
        format_tou_schedule(ts)
      else
        "TOU Schedule with ID: #{params['text']} could not be found."
      end
    end
  end

  private

  def check(command)
    method = params['type'] == 'dialog_submission' ? :receive : :entry

    expected_token = ENV["MATTERMOST_TOKEN_#{command.to_s.upcase}_COMMAND"]
    raise ArgumentError, "Invalid API Token" if method == :entry && params['token'] != expected_token

    text = yield(method, params)
    json = {response_type: 'ephemeral', username: 'Met3r', text: text}
    render json: json
  end

  def format_tou_schedule(ts)
    text = []
    text << "#### Time of Use Schedule: #{ts.id}"

    text << "| Name | Payload Type | Program | Target | Time Zone | Active |"
    text << "|------|--------------|---------|--------|-----------|--------|"
    row = "| #{ts.name} | #{ts.payload_unit.name || ts.payload_unit.id} |"
    row += " #{ts.market_context.name || ts.market_context.id} |"
    row += " #{ts.target.name || ts.target.id} | #{ts.time_zone} | #{ts.is_active ? "Yes" : "No"} |"
    text << row

    text << "\n##### Hourly Settings"
    text << "| Hour of day | Winter Setting | Summer Setting | Hour of day | Winter Setting | Summer Setting |"
    text << "| :---------- | -------------: | -------------: | :---------- | -------------: | -------------: |"

    12.times do |i|
      row = "| #{hour_to_human(i)} | #{ts["hour_#{'%02d' % i}_winter"]} | #{ts["hour_#{'%02d' % i}_summer"]} |"
      row += " #{hour_to_human(i+12)} | #{ts["hour_#{'%02d' % (i+12)}_winter"]} | #{ts["hour_#{'%02d' % (i+12)}_summer"]} |"
      text << row
    end

    text.join("  \n")
  end

  def hour_to_human(n)
    case
    when n.zero? then "Midnight"
    when n == 12 then "Noon"
    when n < 12 then "#{n}am"
    else "#{n-12}pm"
    end
  end
end