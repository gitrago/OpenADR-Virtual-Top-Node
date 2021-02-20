# encoding: UTF-8

require 'base64'
module EpriSheet
  class Bot
    QUERY_URL = "https://api.met3r.com:443/v0.1/grid"
    GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"

    class << self
      def entry(params)
        new(params).entry
      end

      def receive(params)
        new(params).receive
      end
    end

    def initialize(params)
      @params = params
    end

    def entry
      puts @params.inspect
      @address = @params['text']
      geocode

      query if coordinates_valid?
      return {error: send(@error)} if @error.present?

      Thread.new {
        token = Base64.encode64(@data.to_yaml).gsub("\n", "")
        res = open_mm_dialog("#{@address}|||#{token}")
      }

      nil
    end

    def receive
      @address, @token = @params['state'].split("|||", 2)
      @data = YAML.load(Base64.decode64(@token))
      @sheet = EpriSheet::Main.run(@params['submission'], @data)

      message = "Load simulation for address: `#{@address}`  \n"
      message += format_voltage_results
      message += "\n![Voltage Profile](#{chart_for(:voltage_profile)} \"Voltage Profile Chart\")"
      message += "![Voltage Change](#{chart_for(:voltage_change)} \"Voltage Change Chart\")"

      headers = { 'content_type' => 'application/json', 'Authorization' =>  "Bearer #{ENV['MATTERMOST_BOT_TOKEN']}" }
      post = { message: message, channel_id: @params['channel_id'] }

      if ENV['EPRI_USE_EPHEMERAL_POSTS'].to_i.zero?
        url = "#{ENV['MATTERMOST_SERVER_URL']}/api/v4/posts"
        res = agent.post(url, body: post.to_json, header: headers)
      else
        post = { post: post, user_id: @params['user_id'] }
        url = "#{ENV['MATTERMOST_SERVER_URL']}/api/v4/posts/ephemeral"
        res = agent.post(url, body: post.to_json, header: headers)
      end

      nil
    end

    protected

    def open_mm_dialog(state)
      dialog = {
        url: "#{ENV['RAILS_SERVER_URL']}/callback/mattermost",
        trigger_id: @params['trigger_id'],
        dialog: {
          title: 'Load Flow Simulation -- /lfs',
          state: state,
          elements: [
            {
              display_name: "Névleges teljesítmény: (kVA)",
              name: "capacity",
              type: "text",
              subtype: "number",
              placeholder: "4"
            },
            {
              display_name: "Távolság a tápponttól: (m)",
              name: "distance",
              type: "text",
              subtype: "number",
              placeholder: "655"
            },
            {
              display_name: "Csatlakozási mód:",
              name: "connection",
              type: "select",
              default: "1 fázisú csatlakozás",
              options: [
                { text: "1 fázisú csatlakozás", value: "1 fázisú csatlakozás" },
                { text: "2 fázisú csatlakozás", value: "2 fázisú csatlakozás" },
                { text: "3 fázisú csatlakozás", value: "3 fázisú csatlakozás" },
              ]
            },
            {
              display_name: "Csatlakozás fázisa:",
              name: "connect2phase",
              type: "select",
              default: "L1",
              options: [
                { text: "L1", value: "L1" },
                { text: "L2", value: "L2" },
                { text: "L3", value: "L3" },
              ]
            }
          ]
        }
      }
      url = "#{ENV['MATTERMOST_SERVER_URL']}/api/v4/actions/dialogs/open"
      agent.post(url, body: dialog.to_json, header: { 'content_type' => 'application/json' })
    end

    def chart_for(name)

      name = "#{Digest::MD5.hexdigest(@token)}-#{name}.png"
      path = Rails.root.join("public", "charts", name).to_s
      unless File.exist?(path)
        g = Gruff::Line.new
        g.title = name.to_s.titleize
        g.theme = { colors: %w[#00ff00 #ffff00 #ff0000 #000000 #000000 #000000],
          marker_color: 'gray', font_color: 'black', background_colors: 'white' }
        @sheet.result.send(name).each.with_index{|(k,v),i| g.data(i <= 2 ? k : '', v.values)}
        g.labels = Hash[@sheet.result.send(name)['L1'].map.with_index{|k,i| [i, k[0]] if i % 10 == 0}.compact]
        g.write(path)
      end
      "#{ENV['RAILS_SERVER_URL']}/charts/#{name}"
    end

    def format_voltage_results
      res = @sheet.result.data
      
      text = []
      text << "\n---"
      text << "Maximum Voltage Change: #{'**%0.2f%%**' % (res[:vol_change_max][:val] * 100)} #{res[:vol_change_max][:label]}"
      text << "#{res[:vol_change_1][:label]}: #{"**%0.2f%%**" % (res[:vol_change_1][:val] * 100)} Min."
      text << "#{res[:vol_change_2][:label]}: #{"**%0.2f%%**" % (res[:vol_change_2][:val] * 100)} Max."
      text << "\n---"
      text << "Starting Voltage: #{"**%0.2f V**" % res[:starting_voltage]}"
      text << "Max. Line Beam Voltage (max. 248.4V): #{'**%0.2f V**' % res[:max_line_voltage][:val]} #{res[:max_line_voltage][:label]}"
      text << "Min. Line Beam Voltage (min. 211.6V): #{'**%0.2f V**' % res[:min_line_voltage][:val]} #{res[:min_line_voltage][:label]}"
      text << "Rapid Voltage Change (max. 3%): #{'**%0.2f%%**' % (res[:rapid_vol_change][:val]*100)} #{res[:rapid_vol_change][:label]}"
      text << "\n---"

      text.join("  \n")
    end

    def geocode
      url = "#{GEOCODE_URL}?address=#{URI.escape(@address)}&key=#{ENV['GOOGLE_API_KEY']}"
      @data = JSON.parse(agent.get(url).body)
      @coords = @data.try(:[], 'results').try(:first).try(:[], 'geometry').try(:[], 'location')
      @coords = [@coords.try(:[], 'lat'), @coords.try(:[], 'lng')].compact
    rescue
      @error = :geocoding_error
    end

    def query
      body = {"type" => "loadflow", "coordinates" => @coords }.to_json
      @data = JSON.parse(agent.post(QUERY_URL, body: body, header: {'content-type' => 'application/json'}).body)
    rescue
      @error = :api_error
    end

    def coordinates_valid?
      return false if @error.present?

      case
      when @coords[0].nil? || @coords[1].nil? then @error = :geocoding_error 
      when !within_bound?(@coords[0], :latitude) then @error = :out_of_bounds
      when !within_bound?(@coords[1], :longitude) then @error = :out_of_bounds
      end

      @error.blank?
    end

    private

    def within_bound?(position, kind = :latitude)
      bounds = ENV["allowed_#{kind}s".upcase].split(",").map(&:to_f)
      position >= bounds.min && position <= bounds.max
    end

    # NOTE: Fixup needed to allow communication on deprecated
    #       ciphers required for this integration with Google APIs
    def agent(version = 'TLSv1.2', ciphers=nil)
      client = HTTPClient.new
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      client.ssl_config.ssl_version = version
      client.ssl_config.ciphers = ciphers if ciphers.present?
      client
    end

    def api_error
      text  = []
      text << "**Error: Unknown Error**"
      text << "Address: `#{@address}` was geocoded correctly."
      text << "However, we recieved an unknown error when trying to process it."
      text.join("\n")
    end
    alias unknown_error api_error

    def geocoding_error
      text  = []
      text << "**Error: Geocoding Error**"
      text << "Address: `#{@address}` could not be geocoded properly."
      text << "Please, re-check the address being provided."
      text.join("\n")
    end

    def out_of_bounds
      text  = []
      text << "**Error: Out of bounds**"
      text << "Address: `#{@address}` was geocoded to: `[#{@coords.join(",")}]` coordinates"
      text << "which is out of bounds for the location served by this server."
      text.join("\n")
    end
  end
end